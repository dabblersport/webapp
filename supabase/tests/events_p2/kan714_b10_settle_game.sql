-- KAN-729 (KAN-714 piece B10) test: public.settle_game reads organiser (creator_user_id) and sport (sport_id) from
-- public.events. MONEY PATH (T-049).
-- LOCAL THROWAWAY POSTGRES ONLY. NEVER RUN AGAINST SUPABASE. Run as postgres (superuser), psql -v ON_ERROR_STOP=1.
--
-- Load order:
--   tests/events_p1/local_harness_kan711.sql, tests/events_p1/local_seed_kan711.sql,
--   tests/events_p2/local_harness_kan712.sql, tests/events_p2_kan713/local_harness_kan713.sql,
--   tests/events_p2_kan714/local_harness_kan714.sql,
--   migrations 20261101140000, 20261102110000, 20261102120000,
--     CALL public.kan711_events_backfill_run(200); SELECT public.kan711_events_validate_links();
--   migrations 20261103100000, 20261103110000, 20261104100000, 20261104110000, 20261104110300,
--   psql -v fixture_only=1 -f THIS FILE          (money objects + the pre-image settle_game; stops there),
--   migrations/20261104101000_kan714_b10_settle_game_reads.sql,
--   psql -f THIS FILE                            (fixture is a no-op now; then every assertion).
--
-- Flow: seed (idempotent) -> NEW snapshot + probes -> rollback block (verbatim copy of the migration's
-- KAN729-ROLLBACK section) -> LEGACY snapshot + the same probes -> compare -> re-apply the migration with \ir ->
-- verify round trip and data intact. Every settle_game call runs in a rolled-back subtransaction, so the file
-- commits only its seed rows and leaves the database migrated.
-- Assertions: T0 precondition, A shape/return, B ledger = legacy + nothing doubled, C provenance from events (and
-- the probe fails on legacy), D refusals = legacy, E replay writes nothing new, F zero/negative earnings = legacy,
-- G rollback md5 + data intact + re-apply, H plan (one added join, no SubPlan).

\set ON_ERROR_STOP 1
SET client_min_messages = warning;

-- ---------------------------------------------------------------------------------------------------------
-- FIXTURE (idempotent). The KAN-711..714 local harness carries none of the money objects settle_game touches.
-- This section creates them with their production shapes (sources cited per object) and, only when absent,
-- the PRE-IMAGE settle_game copied verbatim from 20260911114500_kan169_settle_game_zero_and_negative_earnings.sql
-- :28-204 with its comment and ACL from 20260911113000_kan169_settle_game_derive_inputs.sql:222-228.
-- Load with `psql -v fixture_only=1 -f THIS_FILE` BEFORE the migration; the run stops after this section.
-- ---------------------------------------------------------------------------------------------------------
DO $fx$
BEGIN
  -- baseline 20260829080500: enums
  IF to_regtype('public.settlement_status') IS NULL THEN
    CREATE TYPE public.settlement_status AS ENUM ('pending', 'settled', 'refunded', 'cancelled');
  END IF;
  IF to_regtype('public.ledger_direction') IS NULL THEN
    CREATE TYPE public.ledger_direction AS ENUM ('credit', 'debit');
  END IF;
  IF to_regtype('public.ledger_status') IS NULL THEN
    CREATE TYPE public.ledger_status AS ENUM ('pending', 'posted', 'voided');
  END IF;
END
$fx$;

-- baseline: game_settlements + idx_game_settlement_unique + gs_block_dml
CREATE TABLE IF NOT EXISTS public.game_settlements (
  id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
  game_id uuid NOT NULL REFERENCES public.games(id) ON DELETE CASCADE,
  organiser_user_id uuid NOT NULL,
  sport text NOT NULL,
  gross_collected_aed numeric(12,2) DEFAULT 0 NOT NULL CHECK (gross_collected_aed >= 0),
  app_fee_rate numeric(5,2) NOT NULL,
  app_fee_aed numeric(12,2) NOT NULL,
  organiser_earnings_aed numeric(12,2) NOT NULL,
  status public.settlement_status DEFAULT 'pending' NOT NULL,
  notes text,
  meta jsonb DEFAULT '{}'::jsonb NOT NULL,
  created_at timestamptz DEFAULT now() NOT NULL,
  settled_at timestamptz
);
CREATE UNIQUE INDEX IF NOT EXISTS idx_game_settlement_unique ON public.game_settlements (game_id);
ALTER TABLE public.game_settlements ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS gs_block_dml ON public.game_settlements;
CREATE POLICY gs_block_dml ON public.game_settlements USING (false) WITH CHECK (false);   -- baseline :32408

-- baseline + kan130/kan131: wallets (owner_type / owner_id)
CREATE TABLE IF NOT EXISTS public.wallets (
  user_id uuid NOT NULL PRIMARY KEY,
  currency text DEFAULT 'AED' NOT NULL,
  balance_aed numeric(12,2) DEFAULT 0 NOT NULL,
  held_aed numeric(12,2) DEFAULT 0 NOT NULL,
  updated_at timestamptz DEFAULT now() NOT NULL,
  created_at timestamptz DEFAULT now() NOT NULL,
  owner_type text NOT NULL CHECK (owner_type IN ('user', 'venue', 'platform')),
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  owner_id uuid NOT NULL
);

-- baseline + kan128: wallet_ledger, ref_id NOT NULL, wallet_ledger_ref_key_unique
CREATE SEQUENCE IF NOT EXISTS public.wallet_ledger_id_seq;
CREATE TABLE IF NOT EXISTS public.wallet_ledger (
  id bigint DEFAULT nextval('public.wallet_ledger_id_seq') NOT NULL PRIMARY KEY,
  user_id uuid NOT NULL,
  direction public.ledger_direction NOT NULL,
  amount_aed numeric(12,2) NOT NULL CONSTRAINT wallet_ledger_amount_aed_check CHECK (amount_aed > 0),
  status public.ledger_status DEFAULT 'posted' NOT NULL,
  ref_type text NOT NULL,
  ref_id uuid NOT NULL,
  memo text,
  meta jsonb DEFAULT '{}'::jsonb NOT NULL,
  created_at timestamptz DEFAULT now() NOT NULL
);
CREATE UNIQUE INDEX IF NOT EXISTS wallet_ledger_ref_key_unique ON public.wallet_ledger (ref_type, ref_id, direction);
ALTER TABLE public.wallet_ledger ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS ledger_block_dml ON public.wallet_ledger;
CREATE POLICY ledger_block_dml ON public.wallet_ledger USING (false) WITH CHECK (false);   -- baseline :32458

-- kan173: _wallet_recalc (full recompute, never an increment); baseline: _wallet_after_ledger + trigger
CREATE OR REPLACE FUNCTION public._wallet_recalc(p_user uuid)
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  avail numeric(12,2);
  held  numeric(12,2);
begin
  select
    coalesce(sum(case when status='posted' and direction='credit' then amount_aed
                      when status='posted' and direction='debit'  then -amount_aed
                      else 0 end),0),
    coalesce(sum(case when status='pending' and direction='credit' then amount_aed
                      when status='pending' and direction='debit'  then -amount_aed
                      else 0 end),0)
  into avail, held
  from public.wallet_ledger
  where user_id = p_user;

  insert into public.wallets (user_id, owner_type, owner_id, balance_aed, held_aed)
  values (p_user, 'user', p_user, avail, held)
  on conflict (user_id)
  do update set balance_aed = excluded.balance_aed,
                held_aed    = excluded.held_aed,
                updated_at  = now();
end;
$function$;
CREATE OR REPLACE FUNCTION public._wallet_after_ledger() RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  perform public._wallet_recalc(coalesce(new.user_id, old.user_id));
  return null;
end;
$function$;
DROP TRIGGER IF EXISTS trg_wallet_ledger_recalc ON public.wallet_ledger;
CREATE TRIGGER trg_wallet_ledger_recalc AFTER INSERT OR DELETE OR UPDATE ON public.wallet_ledger
  FOR EACH ROW EXECUTE FUNCTION public._wallet_after_ledger();

-- baseline: commission_rules + resolve_commission (verbatim body)
CREATE TABLE IF NOT EXISTS public.commission_rules (
  id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
  organiser_user_id uuid,
  sport text,
  commission_rate numeric(5,2) NOT NULL,
  min_app_fee_aed numeric(12,2) DEFAULT 0 NOT NULL,
  max_app_fee_aed numeric(12,2),
  starts_at timestamptz DEFAULT now(),
  ends_at timestamptz,
  is_active boolean DEFAULT true NOT NULL,
  created_at timestamptz DEFAULT now() NOT NULL
);
CREATE OR REPLACE FUNCTION public.resolve_commission(p_organiser_user_id uuid, p_sport text, p_at timestamptz DEFAULT now())
 RETURNS TABLE(rate numeric, min_fee numeric, max_fee numeric)
 LANGUAGE sql STABLE
 SET search_path TO 'public', 'pg_temp'
AS $$
  with ranked as (
    select
      commission_rate as rate,
      min_app_fee_aed as min_fee,
      max_app_fee_aed as max_fee,
      row_number() over (
        order by
          (organiser_user_id is null)::int asc,   -- prefer specific organiser
          (sport is null)::int asc,               -- prefer specific sport
          starts_at desc
      ) as rnk
    from public.commission_rules
    where is_active = true
      and (organiser_user_id is null or organiser_user_id = p_organiser_user_id)
      and (sport is null or sport = p_sport)
      and (starts_at is null or starts_at <= p_at)
      and (ends_at   is null or ends_at   >  p_at)
  )
  select rate, min_fee, max_fee
  from ranked
  where rnk = 1;
$$;

-- kan171: charges (shape, CHECKs, purpose index)
CREATE TABLE IF NOT EXISTS public.charges (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_type text NOT NULL CONSTRAINT charges_owner_type_valid CHECK (owner_type IN ('user','venue','platform')),
  owner_id uuid NOT NULL,
  purpose_type text NOT NULL CONSTRAINT charges_purpose_type_valid CHECK (purpose_type IN ('game')),
  purpose_id uuid NOT NULL,
  kind text NOT NULL CONSTRAINT charges_kind_valid CHECK (kind IN ('charge','refund')),
  amount numeric NOT NULL,
  currency text NOT NULL CONSTRAINT charges_currency_valid CHECK (currency = upper(currency) AND char_length(currency) = 3),
  vat_amount numeric NOT NULL,
  status text NOT NULL DEFAULT 'pending' CONSTRAINT charges_status_valid
    CHECK (status IN ('pending','succeeded','failed','cancelled','refunded')),
  provider text NOT NULL,
  provider_charge_id text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT charges_amount_sign_matches_kind CHECK ((kind = 'charge' AND amount >= 0 AND vat_amount >= 0)
                                                  OR (kind = 'refund' AND amount <= 0 AND vat_amount <= 0)),
  CONSTRAINT charges_vat_within_amount CHECK (abs(vat_amount) <= abs(amount))
);
CREATE UNIQUE INDEX IF NOT EXISTS charges_natural_key_unique ON public.charges (provider, provider_charge_id, kind);
CREATE INDEX IF NOT EXISTS charges_purpose_idx ON public.charges (purpose_type, purpose_id);
ALTER TABLE public.charges ENABLE ROW LEVEL SECURITY;

-- PRE-IMAGE settle_game, only when absent (never overwrites a later definition).
SELECT to_regprocedure('public.settle_game(uuid,boolean)') IS NULL AS kan729_need_sg \gset
\if :kan729_need_sg
create or replace function public.settle_game(p_game_id uuid, p_finalize boolean default true)
returns game_settlements
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  me uuid := auth.uid();
  r record;
  v_organiser_user_id uuid;
  v_sport text;
  v_gross numeric(12,2);
  v_charge_count bigint;
  v_currency_count bigint;
  v_currency text;
  fee_rate numeric(5,2);
  min_fee numeric(12,2);
  max_fee numeric(12,2);
  fee numeric(12,2);
  earnings numeric(12,2);
  gs public.game_settlements;
begin
  if me is null then
    raise exception using errcode='P0001', message='auth_required';
  end if;

  -- T-069 Q1: organiser and sport are DERIVED, never accepted. games.creator_user_id is the
  -- authoritative identity (profiles.id is a surrogate and is not an auth uid); the sport text key
  -- is sports.sport_key, reached through games.sport_id (NOT NULL, FK -> sports).
  select g.creator_user_id, s.sport_key
    into v_organiser_user_id, v_sport
  from public.games g
  join public.sports s on s.id = g.sport_id
  where g.id = p_game_id;

  if not found then
    raise exception using errcode='P0001', message='game_not_found';
  end if;

  if v_organiser_user_id is null then
    -- games_creator_user_id_fkey is ON DELETE SET NULL while the column is declared NOT NULL, so
    -- this is unreachable today. It is checked anyway: settling a game with no organiser would
    -- otherwise credit wallet_ledger.user_id = null.
    raise exception using errcode='P0001', message='organiser_unresolved';
  end if;

  -- Gate, now against the DERIVED organiser. The old body compared auth.uid() to the caller's own
  -- p_organiser_user_id, which is satisfied by any authenticated caller for any game.
  if not (public.is_admin(me) or me = v_organiser_user_id) then
    raise exception using errcode='P0001', message='forbidden';
  end if;

  -- T-069 Q2: gross is an aggregate over the game's charges rows. Refunds are compensating rows
  -- with kind='refund' and a negative amount (KAN-171/T-049), so sum(amount) is the NET collected.
  -- charges_purpose_idx (purpose_type, purpose_id) serves this predicate exactly.
  select coalesce(sum(c.amount), 0), count(*), count(distinct c.currency), min(c.currency)
    into v_gross, v_charge_count, v_currency_count, v_currency
  from public.charges c
  where c.purpose_type = 'game'
    and c.purpose_id   = p_game_id
    and c.status       = 'succeeded';

  -- DECISION 2, enforced: detect, never sum across currencies into an AED-named column.
  if v_currency_count > 1 then
    raise exception using errcode='P0001', message='mixed_currency_charges';
  end if;

  if v_currency_count = 1 and v_currency <> 'AED' then
    raise exception using errcode='P0001', message='non_aed_charges';
  end if;

  -- Preserved error code. Refunds can drive the net below zero, and
  -- game_settlements_gross_collected_aed_check requires >= 0.
  if v_gross is null or v_gross < 0 then
    raise exception using errcode='P0001', message='invalid_gross';
  end if;

  -- fetch correct commission rule
  select * into r
  from public.resolve_commission(v_organiser_user_id, v_sport, now());

  fee_rate := coalesce(r.rate, 10.00);
  min_fee  := coalesce(r.min_fee, 0);
  max_fee  := coalesce(r.max_fee, null);

  fee := round(v_gross * (fee_rate/100.0), 2);
  if fee < min_fee then fee := min_fee; end if;
  if max_fee is not null and fee > max_fee then fee := max_fee; end if;

  earnings := round(v_gross - fee, 2);

  -- SITTING 2: min_app_fee_aed can exceed what the game collected. That is a debit, and this
  -- function has no authority to invent one. Raised before the settlement row is written.
  if earnings < 0 then
    raise exception using errcode='P0001', message='fee_exceeds_gross';
  end if;

  insert into public.game_settlements(
      game_id,
      organiser_user_id,
      sport,
      gross_collected_aed,
      app_fee_rate,
      app_fee_aed,
      organiser_earnings_aed,
      status,
      meta
  )
  values (
      p_game_id,
      v_organiser_user_id,
      v_sport,
      v_gross,
      fee_rate,
      fee,
      earnings,
      -- KAN-138: cast added. Both branches are untyped literals, so the bare CASE resolved to
      -- `text`, and there is no text -> settlement_status cast of any kind (pg_cast count 0).
      -- Every call raised 42804 here, before reaching the wallet_ledger credit below.
      (case when p_finalize then 'settled' else 'pending' end)::public.settlement_status,
      -- DECISION 1: the admin/organiser discriminator lives here (game_settlements has no column
      -- for it; `meta` IS on the row, satisfying T-069 without widening a money table).
      jsonb_build_object(
        'resolved_at',        now(),
        'settled_by',         me,
        'settled_via',        case when me = v_organiser_user_id then 'organiser' else 'admin' end,
        'gross_source',       'charges',
        'gross_charge_count', v_charge_count,
        'gross_currency',     coalesce(v_currency, 'AED')
      )
  )
  on conflict (game_id) do update
    set gross_collected_aed   = excluded.gross_collected_aed,
        app_fee_rate          = excluded.app_fee_rate,
        app_fee_aed           = excluded.app_fee_aed,
        organiser_earnings_aed = excluded.organiser_earnings_aed,
        status                 = excluded.status,
        meta                   = excluded.meta,
        settled_at             = case when excluded.status='settled' then now() else null end
  returning * into gs;

  -- finalize -> post wallet credit
  -- SITTING 2: `earnings > 0` guard. wallet_ledger_amount_aed_check is `amount_aed > 0`, so a
  -- zero-earnings settlement must post no credit rather than abort the settlement.
  if p_finalize and gs.organiser_earnings_aed > 0 then
    -- KAN-128: a re-settle returns the same gs.id from the upsert above, so before this clause a
    -- second finalize posted a second identical credit for ('game_settlement', gs.id, 'credit').
    -- Now it is absorbed.
    insert into public.wallet_ledger(
      user_id,
      direction,
      amount_aed,
      status,
      ref_type,
      ref_id,
      memo,
      meta
    )
    values (
      v_organiser_user_id,
      'credit',
      gs.organiser_earnings_aed,
      'posted',
      'game_settlement',
      gs.id,
      'Game settlement earnings',
      jsonb_build_object(
        'game_id', gs.game_id,
        'sport', gs.sport
      )
    )
    on conflict do nothing;
  end if;

  return gs;
end;
$function$;

comment on function public.settle_game(uuid, boolean) is
  'KAN-169/T-069. Organiser (games.creator_user_id), sport (sports.sport_key via games.sport_id) and gross (sum over public.charges where purpose_type=''game'' and status=''succeeded'') are all DERIVED from p_game_id; none is accepted as a parameter. Mixed-currency or non-AED charges RAISE rather than sum into the AED-named column. meta.settled_via records admin vs organiser. EXECUTE is service_role only and permanently so (T-069 Q3): a future client path is a new, narrower object, never a restored grant on this one.';

-- pg_default_acl names anon and authenticated, so both must be revoked explicitly; revoking
-- PUBLIC alone leaves anon executable (T-078).
revoke all on function public.settle_game(uuid, boolean) from public, anon, authenticated;
grant execute on function public.settle_game(uuid, boolean) to service_role;
\endif

SELECT 'fixture' AS t, md5(prosrc) AS settle_game_md5, proacl::text AS acl
  FROM pg_proc WHERE oid = 'public.settle_game(uuid,boolean)'::regprocedure;

\if :{?fixture_only}
\echo 'KAN-729 fixture loaded (fixture_only); stopping before the assertions.'
\quit
\endif

-- =========================================================================================================
-- ASSERTIONS (database must hold the fixture above AND migration 20261104101000)
-- =========================================================================================================
SET client_min_messages = notice;

-- ---------------------------------------------------------------------------------------------------------
-- T0. Preconditions
-- ---------------------------------------------------------------------------------------------------------
DO $t0$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = current_user AND rolsuper) THEN
    RAISE EXCEPTION 'T0 FAIL: run as a superuser (local harness)';
  END IF;
  IF (SELECT md5(prosrc) FROM pg_proc WHERE oid = 'public.settle_game(uuid,boolean)'::regprocedure)
       IS DISTINCT FROM 'ee62121d87bee5c6dd1109e6ad11d8b4' THEN
    RAISE EXCEPTION 'T0 FAIL: migration 20261104101000 not applied (settle_game body md5 %)',
      (SELECT md5(prosrc) FROM pg_proc WHERE oid = 'public.settle_game(uuid,boolean)'::regprocedure);
  END IF;
  IF EXISTS (SELECT 1 FROM public.kan712_wrapped_rpcs WHERE name = 'settle_game')
     OR to_regprocedure('public.settle_game_kan712_inner(uuid,boolean)') IS NOT NULL THEN
    RAISE EXCEPTION 'T0 FAIL: settle_game is KAN-712-wrapped';
  END IF;
  IF (SELECT count(*) FROM public.games) = 0 OR (SELECT count(*) FROM public.meetups) = 0 THEN
    RAISE EXCEPTION 'T0 FAIL: harness must hold games and meetups';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.meetups WHERE id = '30000000-0000-0000-0000-000000000001') THEN
    RAISE EXCEPTION 'T0 FAIL: harness meetup 30000000-...-0001 missing';
  END IF;
  RAISE NOTICE 'T0 PASS preconditions (games=%, meetups=%, events=%, wrapped_rpcs=% and settle_game not among them)',
    (SELECT count(*) FROM public.games), (SELECT count(*) FROM public.meetups), (SELECT count(*) FROM public.events),
    (SELECT count(*) FROM public.kan712_wrapped_rpcs);
END
$t0$;

-- ---------------------------------------------------------------------------------------------------------
-- Seed (idempotent, fixed ids). Games go through the KAN-712 guard, so each gets its events parent.
--   g1 a7 football  +100 / -20 refund AED -> gross 80, 10% -> fee 8, earnings 72 (credit)
--   g2 a7 football  no charges           -> gross 0 -> earnings 0 (settle, NO credit)
--   g3 a2 football  +30 AED, a2 rule min fee 50 -> earnings -20 -> fee_exceeds_gross
--   g4 a1 football  +50 AED (a1 blocks a6: blocked caller probe)
--   g5 a5 football  +40 USD -> non_aed_charges
--   g6 a7 football  +200 AED (provenance probe target: events parent changed to a5 / padel)
--   g7 a7 football  +10 AED +10 EUR -> mixed_currency_charges
-- Commission rules: global 10% min 0 (the live shape), padel 20% min 0, organiser a2 10% min 50.
-- ---------------------------------------------------------------------------------------------------------
INSERT INTO public.sports (id, sport_key, name_en, is_challenge_sport, is_active, can_solo)
VALUES ('00000000-0000-0000-0000-0000000000e2', 'padel', 'Padel', true, true, true)
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.games (id, title, creator_profile_id, creator_user_id, start_at, end_at, capacity, listing_visibility,
                          join_policy, sport_id, geo_location_id, area_id, min_skill, max_skill, game_type, is_cancelled)
SELECT ('72900000-0000-0000-0000-00000000000' || f.n)::uuid, 'B10 game ' || f.n,
       ('00000000-0000-0000-0000-0000000000b' || f.who)::uuid, ('00000000-0000-0000-0000-0000000000a' || f.who)::uuid,
       date_trunc('minute', now()) - interval '2 days', date_trunc('minute', now()) - interval '2 days' + interval '1 hour',
       10, 'public', 'open', '00000000-0000-0000-0000-0000000000e1'::uuid,
       '00000000-0000-0000-0000-0000000000d1'::uuid, '00000000-0000-0000-0000-0000000000c1'::uuid, 1, 6, 'pickup', false
  FROM (VALUES (1, '7'), (2, '7'), (3, '2'), (4, '1'), (5, '5'), (6, '7'), (7, '7')) AS f(n, who)
 -- NOT EXISTS, not ON CONFLICT: the KAN-712 guard creates the events parent before the games conflict check.
 WHERE NOT EXISTS (SELECT 1 FROM public.games x WHERE x.id = ('72900000-0000-0000-0000-00000000000' || f.n)::uuid);

INSERT INTO public.charges (id, owner_type, owner_id, purpose_type, purpose_id, kind, amount, currency, vat_amount,
                            status, provider, provider_charge_id)
SELECT ('72900000-0000-0000-00cc-00000000000' || c.n)::uuid, 'user', '00000000-0000-0000-0000-0000000000a4'::uuid, 'game',
       ('72900000-0000-0000-0000-00000000000' || c.g)::uuid, c.kind, c.amt, c.ccy, 0, c.st, 'kan729', 'kan729-' || c.n
  FROM (VALUES (1, 1, 'charge', 100::numeric, 'AED', 'succeeded'),
               (2, 1, 'refund', -20,  'AED', 'succeeded'),
               (3, 1, 'charge', 999,  'AED', 'failed'),      -- not succeeded: never counted
               (4, 3, 'charge', 30,   'AED', 'succeeded'),
               (5, 4, 'charge', 50,   'AED', 'succeeded'),
               (6, 5, 'charge', 40,   'USD', 'succeeded'),
               (7, 6, 'charge', 200,  'AED', 'succeeded'),
               (8, 7, 'charge', 10,   'AED', 'succeeded'),
               (9, 7, 'charge', 10,   'EUR', 'succeeded')) AS c(n, g, kind, amt, ccy, st)
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.commission_rules (id, organiser_user_id, sport, commission_rate, min_app_fee_aed, max_app_fee_aed,
                                     starts_at, is_active)
VALUES ('72900000-0000-0000-00ee-000000000001', NULL, NULL, 10.00, 0, NULL, '2020-01-01', true),
       ('72900000-0000-0000-00ee-000000000002', NULL, 'padel', 20.00, 0, NULL, '2020-01-01', true),
       ('72900000-0000-0000-00ee-000000000003', '00000000-0000-0000-0000-0000000000a2', NULL, 10.00, 50.00, NULL, '2020-01-01', true)
ON CONFLICT (id) DO NOTHING;

SELECT 'seed' AS t,
       (SELECT count(*) FROM public.games g JOIN public.events e ON e.id = g.event_id AND e.event_type = 'game'
         WHERE g.id::text LIKE '72900000-0000-0000-0000-%') AS b10_games_with_parent,
       (SELECT count(*) FROM public.charges WHERE provider = 'kan729') AS b10_charges,
       (SELECT count(*) FROM public.commission_rules WHERE id::text LIKE '72900000-%') AS b10_rules,
       (SELECT count(*) FROM public.game_settlements) AS settlements,
       (SELECT count(*) FROM public.wallet_ledger) AS ledger_rows;

-- ---------------------------------------------------------------------------------------------------------
-- Probe machinery. Every settle_game call runs inside a plpgsql subtransaction that is ALWAYS rolled back (the
-- result is smuggled out through a private SQLSTATE), so no settlement, ledger or wallet row survives a probe and
-- NEW and LEGACY each start from the same committed state.
-- ---------------------------------------------------------------------------------------------------------
CREATE TEMP TABLE kan729_res  (phase text, label text, res jsonb, PRIMARY KEY (phase, label));
CREATE TEMP TABLE kan729_meta (phase text PRIMARY KEY, args text, full_args text, result text, ret_cols text, lang text,
                               secdef boolean, vol "char", config text[], owner text, acl text, comment text, src_md5 text);
CREATE TEMP TABLE kan729_data (phase text PRIMARY KEY, games text, events text, meetups text, harness_meetup text,
                               settlements text, ledger text, wallets text, charges text, rules text);
CREATE TEMP TABLE kan729_plan (phase text PRIMARY KEY, rels text[], events_scans int, events_node text, subplans int,
                               plan_rows numeric);

CREATE FUNCTION pg_temp.kan729_proj(gs jsonb) RETURNS jsonb LANGUAGE sql IMMUTABLE AS $f$
  SELECT CASE WHEN gs IS NULL THEN NULL ELSE
    (gs - 'id' - 'created_at' - 'settled_at' - 'meta')
    || jsonb_build_object('settled_at_set', gs->>'settled_at' IS NOT NULL, 'meta', (gs->'meta') - 'resolved_at') END
$f$;

-- One case. p_times > 1 replays the identical call; p_prov rewrites g6's events parent ONLY (mirror disabled).
CREATE FUNCTION pg_temp.kan729_try(p_uid uuid, p_game uuid, p_fin boolean, p_times int, p_prov boolean)
RETURNS jsonb LANGUAGE plpgsql AS $f$
DECLARE
  v_out jsonb := '{}'::jsonb;
  v_ret jsonb;
  v_calls jsonb := '[]'::jsonb;
  v_ev uuid;
  i int;
BEGIN
  BEGIN
    PERFORM set_config('request.jwt.claim.sub', coalesce(p_uid::text, ''), true);
    IF p_prov THEN
      SELECT event_id INTO v_ev FROM public.games WHERE id = p_game;
      ALTER TABLE public.events DISABLE TRIGGER trg_zz_kan712_events_compat_mirror;
      UPDATE public.events SET creator_user_id = '00000000-0000-0000-0000-0000000000a5',
                               sport_id = '00000000-0000-0000-0000-0000000000e2'
       WHERE id = v_ev;
      v_out := v_out || jsonb_build_object('prov_games_side',
                 (SELECT jsonb_build_object('creator', creator_user_id, 'sport', sport_id) FROM public.games WHERE id = p_game),
               'prov_events_side',
                 (SELECT jsonb_build_object('creator', creator_user_id, 'sport', sport_id) FROM public.events WHERE id = v_ev));
    END IF;
    FOR i IN 1 .. p_times LOOP
      SELECT to_jsonb(x) INTO v_ret FROM public.settle_game(p_game, p_fin) x;
      v_calls := v_calls || jsonb_build_array(jsonb_build_object(
        'ret', pg_temp.kan729_proj(v_ret),
        'settlements_for_game', (SELECT count(*) FROM public.game_settlements WHERE game_id = p_game),
        'ledger_total', (SELECT count(*) FROM public.wallet_ledger),
        'ledger_for_game', (SELECT coalesce(jsonb_agg(jsonb_build_object(
              'user_id', l.user_id, 'direction', l.direction, 'amount_aed', l.amount_aed, 'status', l.status,
              'ref_type', l.ref_type, 'ref_is_settlement', l.ref_id = gs.id, 'memo', l.memo, 'meta', l.meta)
              ORDER BY l.id), '[]'::jsonb)
            FROM public.wallet_ledger l JOIN public.game_settlements gs ON gs.id = l.ref_id
           WHERE l.ref_type = 'game_settlement' AND gs.game_id = p_game),
        'wallets', (SELECT coalesce(jsonb_object_agg(w.user_id, w.balance_aed::text || '/' || w.held_aed::text), '{}'::jsonb)
                      FROM public.wallets w),
        'ret_equals_row', (SELECT pg_temp.kan729_proj(to_jsonb(gs)) = pg_temp.kan729_proj(v_ret)
                             FROM public.game_settlements gs WHERE gs.game_id = p_game)));
    END LOOP;
    v_out := v_out || jsonb_build_object('ok', true, 'calls', v_calls);
    RAISE EXCEPTION USING ERRCODE = 'KX729', MESSAGE = v_out::text;
  EXCEPTION
    WHEN SQLSTATE 'KX729' THEN RETURN SQLERRM::jsonb;
    WHEN OTHERS THEN RETURN v_out || jsonb_build_object('ok', false, 'sqlstate', SQLSTATE, 'error', SQLERRM);
  END;
END
$f$;

CREATE FUNCTION pg_temp.kan729_run(p_phase text) RETURNS void LANGUAGE plpgsql AS $f$
DECLARE c record;
BEGIN
  FOR c IN SELECT * FROM (VALUES
      -- label            uid (a<n>)                               game  fin    times prov
      ('B1_org_settle',   '00000000-0000-0000-0000-0000000000a7', 1, true,  1, false),
      ('B2_admin_settle', '00000000-0000-0000-0000-0000000000a3', 1, true,  1, false),
      ('B3_org_pending',  '00000000-0000-0000-0000-0000000000a7', 1, false, 1, false),
      ('B4_blocker_own',  '00000000-0000-0000-0000-0000000000a1', 4, true,  1, false),
      ('C1_prov_newcreator', '00000000-0000-0000-0000-0000000000a5', 6, true, 1, true),
      ('C2_prov_oldcreator', '00000000-0000-0000-0000-0000000000a7', 6, true, 1, true),
      ('D1_anon',         NULL,                                    1, true,  1, false),
      ('D2_stranger',     '72900000-0000-0000-00ff-000000000001', 1, true,  1, false),
      ('D3_blocked_on_blocker_game', '00000000-0000-0000-0000-0000000000a6', 4, true, 1, false),
      ('D4_other_creator','00000000-0000-0000-0000-0000000000a2', 1, true,  1, false),
      ('D5_no_such_game', '00000000-0000-0000-0000-0000000000a7', 0, true,  1, false),
      ('D6_non_aed',      '00000000-0000-0000-0000-0000000000a5', 5, true,  1, false),
      ('D7_mixed_ccy',    '00000000-0000-0000-0000-0000000000a7', 7, true,  1, false),
      ('E1_replay_x2',    '00000000-0000-0000-0000-0000000000a7', 1, true,  2, false),
      ('E2_replay_zero_x2','00000000-0000-0000-0000-0000000000a7', 2, true,  2, false),
      ('F1_zero',         '00000000-0000-0000-0000-0000000000a7', 2, true,  1, false),
      ('F2_negative',     '00000000-0000-0000-0000-0000000000a2', 3, true,  1, false),
      ('F3_negative_pending','00000000-0000-0000-0000-0000000000a2', 3, false, 1, false)
    ) AS t(label, uid, g, fin, times, prov)
  LOOP
    INSERT INTO kan729_res VALUES (p_phase, c.label,
      pg_temp.kan729_try(c.uid::uuid, ('72900000-0000-0000-0000-00000000000' || c.g)::uuid, c.fin, c.times, c.prov));
  END LOOP;
END
$f$;

CREATE FUNCTION pg_temp.kan729_snap(p_phase text) RETURNS void LANGUAGE plpgsql AS $f$
DECLARE v_plan jsonb; v_stmt text;
BEGIN
  INSERT INTO kan729_meta
  SELECT p_phase, pg_get_function_identity_arguments(p.oid), pg_get_function_arguments(p.oid), pg_get_function_result(p.oid),
         (SELECT string_agg(a.attname || ':' || format_type(a.atttypid, a.atttypmod), ',' ORDER BY a.attnum)
            FROM pg_attribute a WHERE a.attrelid = 'public.game_settlements'::regclass AND a.attnum > 0 AND NOT a.attisdropped),
         l.lanname, p.prosecdef, p.provolatile, p.proconfig, pg_get_userbyid(p.proowner), p.proacl::text,
         obj_description(p.oid, 'pg_proc'), md5(p.prosrc)
    FROM pg_proc p JOIN pg_language l ON l.oid = p.prolang
   WHERE p.oid = 'public.settle_game(uuid,boolean)'::regprocedure;

  INSERT INTO kan729_data SELECT p_phase,
    (SELECT md5(string_agg(t::text, '|' ORDER BY t.id)) FROM public.games t),
    (SELECT md5(string_agg(t::text, '|' ORDER BY t.id)) FROM public.events t),
    (SELECT md5(string_agg(t::text, '|' ORDER BY t.id)) FROM public.meetups t),
    (SELECT md5(t::text) FROM public.meetups t WHERE t.id = '30000000-0000-0000-0000-000000000001'),
    (SELECT coalesce(md5(string_agg(t::text, '|' ORDER BY t.id)), 'empty') FROM public.game_settlements t),
    (SELECT coalesce(md5(string_agg(t::text, '|' ORDER BY t.id)), 'empty') FROM public.wallet_ledger t),
    (SELECT coalesce(md5(string_agg(t::text, '|' ORDER BY t.user_id)), 'empty') FROM public.wallets t),
    (SELECT md5(string_agg(t::text, '|' ORDER BY t.id)) FROM public.charges t),
    (SELECT md5(string_agg(t::text, '|' ORDER BY t.id)) FROM public.commission_rules t);

  -- The organiser/sport read exactly as each body states it (post-condition / T0 pin the body text).
  v_stmt := CASE p_phase
    WHEN 'new' THEN 'select e.creator_user_id, s.sport_key from public.games g
                       join public.events e on e.id = g.event_id and e.event_type = ''game''
                       join public.sports s on s.id = e.sport_id where g.id = $1'
    ELSE 'select g.creator_user_id, s.sport_key from public.games g
            join public.sports s on s.id = g.sport_id where g.id = $1' END;
  EXECUTE 'EXPLAIN (FORMAT JSON) ' || replace(v_stmt, '$1', '''72900000-0000-0000-0000-000000000001''::uuid') INTO v_plan;
  INSERT INTO kan729_plan SELECT p_phase,
    ARRAY(SELECT x #>> '{}' FROM jsonb_path_query(v_plan, 'strict $.**."Relation Name"') x ORDER BY 1),
    (SELECT count(*) FROM jsonb_path_query(v_plan, 'strict $.** ? (@."Relation Name" == "events")') x),
    (SELECT string_agg((x->>'Node Type') || coalesce(' using ' || (x->>'Index Name'), ''), ',')
       FROM jsonb_path_query(v_plan, 'strict $.** ? (@."Relation Name" == "events")') x),
    (SELECT count(*) FROM jsonb_path_query(v_plan, 'strict $.** ? (@."Parent Relationship" == "SubPlan")') x),
    (v_plan->0->'Plan'->>'Plan Rows')::numeric;
END
$f$;

-- ---------------------------------------------------------------------------------------------------------
-- NEW phase
-- ---------------------------------------------------------------------------------------------------------
SELECT pg_temp.kan729_snap('new');
SELECT pg_temp.kan729_run('new');
SELECT label, res->>'ok' AS ok, res->>'error' AS error, jsonb_array_length(res->'calls') AS calls,
       res->'calls'->-1->'ret'->>'organiser_user_id' AS organiser, res->'calls'->-1->'ret'->>'sport' AS sport,
       res->'calls'->-1->'ret'->>'organiser_earnings_aed' AS earnings,
       jsonb_array_length(res->'calls'->-1->'ledger_for_game') AS credits
  FROM kan729_res WHERE phase = 'new' ORDER BY label;

-- ---------------------------------------------------------------------------------------------------------
-- G (part 1). ROLLBACK block: verbatim copy of the migration's KAN729-ROLLBACK section, uncommented.
-- ---------------------------------------------------------------------------------------------------------
BEGIN;
create or replace function public.settle_game(p_game_id uuid, p_finalize boolean default true)
returns game_settlements
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  me uuid := auth.uid();
  r record;
  v_organiser_user_id uuid;
  v_sport text;
  v_gross numeric(12,2);
  v_charge_count bigint;
  v_currency_count bigint;
  v_currency text;
  fee_rate numeric(5,2);
  min_fee numeric(12,2);
  max_fee numeric(12,2);
  fee numeric(12,2);
  earnings numeric(12,2);
  gs public.game_settlements;
begin
  if me is null then
    raise exception using errcode='P0001', message='auth_required';
  end if;

  -- T-069 Q1: organiser and sport are DERIVED, never accepted. games.creator_user_id is the
  -- authoritative identity (profiles.id is a surrogate and is not an auth uid); the sport text key
  -- is sports.sport_key, reached through games.sport_id (NOT NULL, FK -> sports).
  select g.creator_user_id, s.sport_key
    into v_organiser_user_id, v_sport
  from public.games g
  join public.sports s on s.id = g.sport_id
  where g.id = p_game_id;

  if not found then
    raise exception using errcode='P0001', message='game_not_found';
  end if;

  if v_organiser_user_id is null then
    -- games_creator_user_id_fkey is ON DELETE SET NULL while the column is declared NOT NULL, so
    -- this is unreachable today. It is checked anyway: settling a game with no organiser would
    -- otherwise credit wallet_ledger.user_id = null.
    raise exception using errcode='P0001', message='organiser_unresolved';
  end if;

  -- Gate, now against the DERIVED organiser. The old body compared auth.uid() to the caller's own
  -- p_organiser_user_id, which is satisfied by any authenticated caller for any game.
  if not (public.is_admin(me) or me = v_organiser_user_id) then
    raise exception using errcode='P0001', message='forbidden';
  end if;

  -- T-069 Q2: gross is an aggregate over the game's charges rows. Refunds are compensating rows
  -- with kind='refund' and a negative amount (KAN-171/T-049), so sum(amount) is the NET collected.
  -- charges_purpose_idx (purpose_type, purpose_id) serves this predicate exactly.
  select coalesce(sum(c.amount), 0), count(*), count(distinct c.currency), min(c.currency)
    into v_gross, v_charge_count, v_currency_count, v_currency
  from public.charges c
  where c.purpose_type = 'game'
    and c.purpose_id   = p_game_id
    and c.status       = 'succeeded';

  -- DECISION 2, enforced: detect, never sum across currencies into an AED-named column.
  if v_currency_count > 1 then
    raise exception using errcode='P0001', message='mixed_currency_charges';
  end if;

  if v_currency_count = 1 and v_currency <> 'AED' then
    raise exception using errcode='P0001', message='non_aed_charges';
  end if;

  -- Preserved error code. Refunds can drive the net below zero, and
  -- game_settlements_gross_collected_aed_check requires >= 0.
  if v_gross is null or v_gross < 0 then
    raise exception using errcode='P0001', message='invalid_gross';
  end if;

  -- fetch correct commission rule
  select * into r
  from public.resolve_commission(v_organiser_user_id, v_sport, now());

  fee_rate := coalesce(r.rate, 10.00);
  min_fee  := coalesce(r.min_fee, 0);
  max_fee  := coalesce(r.max_fee, null);

  fee := round(v_gross * (fee_rate/100.0), 2);
  if fee < min_fee then fee := min_fee; end if;
  if max_fee is not null and fee > max_fee then fee := max_fee; end if;

  earnings := round(v_gross - fee, 2);

  -- SITTING 2: min_app_fee_aed can exceed what the game collected. That is a debit, and this
  -- function has no authority to invent one. Raised before the settlement row is written.
  if earnings < 0 then
    raise exception using errcode='P0001', message='fee_exceeds_gross';
  end if;

  insert into public.game_settlements(
      game_id,
      organiser_user_id,
      sport,
      gross_collected_aed,
      app_fee_rate,
      app_fee_aed,
      organiser_earnings_aed,
      status,
      meta
  )
  values (
      p_game_id,
      v_organiser_user_id,
      v_sport,
      v_gross,
      fee_rate,
      fee,
      earnings,
      -- KAN-138: cast added. Both branches are untyped literals, so the bare CASE resolved to
      -- `text`, and there is no text -> settlement_status cast of any kind (pg_cast count 0).
      -- Every call raised 42804 here, before reaching the wallet_ledger credit below.
      (case when p_finalize then 'settled' else 'pending' end)::public.settlement_status,
      -- DECISION 1: the admin/organiser discriminator lives here (game_settlements has no column
      -- for it; `meta` IS on the row, satisfying T-069 without widening a money table).
      jsonb_build_object(
        'resolved_at',        now(),
        'settled_by',         me,
        'settled_via',        case when me = v_organiser_user_id then 'organiser' else 'admin' end,
        'gross_source',       'charges',
        'gross_charge_count', v_charge_count,
        'gross_currency',     coalesce(v_currency, 'AED')
      )
  )
  on conflict (game_id) do update
    set gross_collected_aed   = excluded.gross_collected_aed,
        app_fee_rate          = excluded.app_fee_rate,
        app_fee_aed           = excluded.app_fee_aed,
        organiser_earnings_aed = excluded.organiser_earnings_aed,
        status                 = excluded.status,
        meta                   = excluded.meta,
        settled_at             = case when excluded.status='settled' then now() else null end
  returning * into gs;

  -- finalize -> post wallet credit
  -- SITTING 2: `earnings > 0` guard. wallet_ledger_amount_aed_check is `amount_aed > 0`, so a
  -- zero-earnings settlement must post no credit rather than abort the settlement.
  if p_finalize and gs.organiser_earnings_aed > 0 then
    -- KAN-128: a re-settle returns the same gs.id from the upsert above, so before this clause a
    -- second finalize posted a second identical credit for ('game_settlement', gs.id, 'credit').
    -- Now it is absorbed.
    insert into public.wallet_ledger(
      user_id,
      direction,
      amount_aed,
      status,
      ref_type,
      ref_id,
      memo,
      meta
    )
    values (
      v_organiser_user_id,
      'credit',
      gs.organiser_earnings_aed,
      'posted',
      'game_settlement',
      gs.id,
      'Game settlement earnings',
      jsonb_build_object(
        'game_id', gs.game_id,
        'sport', gs.sport
      )
    )
    on conflict do nothing;
  end if;

  return gs;
end;
$function$;
COMMIT;

-- ---------------------------------------------------------------------------------------------------------
-- LEGACY phase (the same probes on the pre-image body)
-- ---------------------------------------------------------------------------------------------------------
SELECT pg_temp.kan729_snap('legacy');
SELECT pg_temp.kan729_run('legacy');

-- ---------------------------------------------------------------------------------------------------------
-- Assertions A-H
-- ---------------------------------------------------------------------------------------------------------
DO $asrt$
DECLARE
  n record; o record; r record;
  v_new jsonb; v_old jsonb; v_c jsonb;
  v_bad text;
BEGIN
  SELECT * INTO n FROM kan729_meta WHERE phase = 'new';
  SELECT * INTO o FROM kan729_meta WHERE phase = 'legacy';

  -- A. shape and return unchanged
  IF (n.args, n.full_args, n.result, n.ret_cols, n.lang, n.secdef, n.vol, n.config, n.owner, n.acl, n.comment)
     IS DISTINCT FROM
     (o.args, o.full_args, o.result, o.ret_cols, o.lang, o.secdef, o.vol, o.config, o.owner, o.acl, o.comment) THEN
    RAISE EXCEPTION 'A FAIL: signature/result/attributes differ: new % legacy %', row_to_json(n), row_to_json(o);
  END IF;
  IF n.args <> 'p_game_id uuid, p_finalize boolean' OR n.result <> 'game_settlements' OR NOT n.secdef
     OR n.config IS DISTINCT FROM ARRAY['search_path=public'] OR n.owner <> 'postgres'
     OR n.acl <> '{postgres=X/postgres,service_role=X/postgres}' THEN
    RAISE EXCEPTION 'A FAIL: unexpected identity/attributes %', row_to_json(n);
  END IF;
  IF has_function_privilege('anon', 'public.settle_game(uuid,boolean)'::regprocedure, 'EXECUTE')
     OR has_function_privilege('authenticated', 'public.settle_game(uuid,boolean)'::regprocedure, 'EXECUTE') THEN
    RAISE EXCEPTION 'A FAIL: anon/authenticated can EXECUTE settle_game';
  END IF;
  FOR r IN SELECT label FROM kan729_res WHERE phase = 'new' AND (res->>'ok')::boolean LOOP
    SELECT res INTO v_new FROM kan729_res WHERE phase = 'new' AND label = r.label;
    IF EXISTS (SELECT 1 FROM jsonb_array_elements(v_new->'calls') c WHERE NOT (c->>'ret_equals_row')::boolean) THEN
      RAISE EXCEPTION 'A FAIL: %: returned row is not the stored settlement row', r.label;
    END IF;
  END LOOP;
  RAISE NOTICE 'A PASS shape: (%) RETURNS % [%], SECURITY DEFINER, %, owner %, acl %, comment unchanged; returned row = stored row in every successful call',
    n.args, n.result, n.ret_cols, n.config, n.owner, n.acl;

  -- B. ledger rows equal legacy, nothing doubled
  FOR r IN SELECT unnest(ARRAY['B1_org_settle','B2_admin_settle','B3_org_pending','B4_blocker_own']) AS label LOOP
    SELECT res INTO v_new FROM kan729_res WHERE phase = 'new' AND label = r.label;
    SELECT res INTO v_old FROM kan729_res WHERE phase = 'legacy' AND label = r.label;
    IF v_new IS DISTINCT FROM v_old THEN
      RAISE EXCEPTION 'B FAIL: % differs from legacy: new % legacy %', r.label, v_new, v_old;
    END IF;
    IF NOT (v_new->>'ok')::boolean THEN RAISE EXCEPTION 'B FAIL: % did not settle: %', r.label, v_new; END IF;
    v_c := v_new->'calls'->0;
    IF (v_c->>'settlements_for_game')::int <> 1
       OR jsonb_array_length(v_c->'ledger_for_game') <> (CASE WHEN r.label = 'B3_org_pending' THEN 0 ELSE 1 END) THEN
      RAISE EXCEPTION 'B FAIL: % wrote % settlements / % ledger rows', r.label, v_c->>'settlements_for_game',
        jsonb_array_length(v_c->'ledger_for_game');
    END IF;
  END LOOP;
  v_c := (SELECT res FROM kan729_res WHERE phase = 'new' AND label = 'B1_org_settle')->'calls'->0;
  IF (v_c->'ret'->>'gross_collected_aed')::numeric <> 80 OR (v_c->'ret'->>'app_fee_aed')::numeric <> 8
     OR (v_c->'ret'->>'organiser_earnings_aed')::numeric <> 72
     OR v_c->'ret'->>'organiser_user_id' <> '00000000-0000-0000-0000-0000000000a7' OR v_c->'ret'->>'sport' <> 'football'
     OR (v_c->'ledger_for_game'->0->>'amount_aed')::numeric <> 72
     OR v_c->'ledger_for_game'->0->>'user_id' <> '00000000-0000-0000-0000-0000000000a7'
     OR NOT (v_c->'ledger_for_game'->0->>'ref_is_settlement')::boolean
     OR v_c->'wallets'->>'00000000-0000-0000-0000-0000000000a7' <> '72.00/0.00' THEN
    RAISE EXCEPTION 'B FAIL: B1 worked example (gross 80 = 100-20, fee 8, earnings 72 to a7) not met: %', v_c;
  END IF;
  RAISE NOTICE 'B PASS ledger = legacy for B1..B4 (byte-equal settlement projection, ledger rows, wallet balances); B1 a7 gross 80 fee 8 earnings 72, one credit 72.00 keyed (game_settlement, gs.id, credit), wallet 72.00; B3 pending posts no credit; one settlement row per game';

  -- C. provenance: events-only change drives settle_game
  SELECT res INTO v_new FROM kan729_res WHERE phase = 'new' AND label = 'C1_prov_newcreator';
  SELECT res INTO v_old FROM kan729_res WHERE phase = 'legacy' AND label = 'C1_prov_newcreator';
  IF v_new->'prov_games_side'->>'creator' <> '00000000-0000-0000-0000-0000000000a7'
     OR v_new->'prov_events_side'->>'creator' <> '00000000-0000-0000-0000-0000000000a5'
     OR v_new->'prov_events_side'->>'sport' <> '00000000-0000-0000-0000-0000000000e2' THEN
    RAISE EXCEPTION 'C FAIL: probe did not diverge games from events: %', v_new;
  END IF;
  v_c := v_new->'calls'->0;
  IF NOT (v_new->>'ok')::boolean OR v_c->'ret'->>'organiser_user_id' <> '00000000-0000-0000-0000-0000000000a5'
     OR v_c->'ret'->>'sport' <> 'padel' OR (v_c->'ret'->>'app_fee_rate')::numeric <> 20
     OR (v_c->'ret'->>'organiser_earnings_aed')::numeric <> 160
     OR v_c->'ledger_for_game'->0->>'user_id' <> '00000000-0000-0000-0000-0000000000a5' THEN
    RAISE EXCEPTION 'C FAIL: NEW did not use the events organiser/sport: %', v_new;
  END IF;
  IF (v_old->>'ok')::boolean OR v_old->>'error' <> 'forbidden' THEN
    RAISE EXCEPTION 'C FAIL: probe C1 does not fail on LEGACY (it would prove nothing): %', v_old;
  END IF;
  SELECT res INTO v_new FROM kan729_res WHERE phase = 'new' AND label = 'C2_prov_oldcreator';
  SELECT res INTO v_old FROM kan729_res WHERE phase = 'legacy' AND label = 'C2_prov_oldcreator';
  IF (v_new->>'ok')::boolean OR v_new->>'error' <> 'forbidden' THEN
    RAISE EXCEPTION 'C FAIL: NEW still lets the games-side creator settle: %', v_new;
  END IF;
  IF NOT (v_old->>'ok')::boolean OR v_old->'calls'->0->'ret'->>'sport' <> 'football'
     OR (v_old->'calls'->0->'ret'->>'organiser_earnings_aed')::numeric <> 180 THEN
    RAISE EXCEPTION 'C FAIL: LEGACY control (games-side creator/sport) did not behave as games says: %', v_old;
  END IF;
  RAISE NOTICE 'C PASS provenance (mirror disabled, events parent of g6 set to a5/padel, games row still a7/football): NEW pays a5 at padel 20%% (fee 40, earnings 160) and refuses a7 forbidden; LEGACY refuses a5 forbidden and pays a7 football 10%% (earnings 180) — the probe fails on legacy';

  -- D. refusals identical to legacy
  FOR r IN SELECT unnest(ARRAY['D1_anon','D2_stranger','D3_blocked_on_blocker_game','D4_other_creator','D5_no_such_game',
                               'D6_non_aed','D7_mixed_ccy']) AS label,
                  unnest(ARRAY['auth_required','forbidden','forbidden','forbidden','game_not_found',
                               'non_aed_charges','mixed_currency_charges']) AS want LOOP
    SELECT res INTO v_new FROM kan729_res WHERE phase = 'new' AND label = r.label;
    SELECT res INTO v_old FROM kan729_res WHERE phase = 'legacy' AND label = r.label;
    IF v_new IS DISTINCT FROM v_old OR (v_new->>'ok')::boolean OR v_new->>'error' <> r.want OR v_new->>'sqlstate' <> 'P0001' THEN
      RAISE EXCEPTION 'D FAIL: % new % legacy % (want P0001 %)', r.label, v_new, v_old, r.want;
    END IF;
  END LOOP;
  RAISE NOTICE 'D PASS refusals = legacy (P0001): anon auth_required, stranger forbidden, blocked a6 on blocker a1''s game forbidden, other creator forbidden, unknown game game_not_found, USD non_aed_charges, AED+EUR mixed_currency_charges';

  -- E. replay
  FOR r IN SELECT unnest(ARRAY['E1_replay_x2','E2_replay_zero_x2']) AS label, unnest(ARRAY[1, 0]) AS credits LOOP
    SELECT res INTO v_new FROM kan729_res WHERE phase = 'new' AND label = r.label;
    SELECT res INTO v_old FROM kan729_res WHERE phase = 'legacy' AND label = r.label;
    IF v_new IS DISTINCT FROM v_old OR NOT (v_new->>'ok')::boolean THEN
      RAISE EXCEPTION 'E FAIL: % new % legacy %', r.label, v_new, v_old;
    END IF;
    IF (v_new->'calls'->0->>'settlements_for_game')::int <> 1 OR (v_new->'calls'->1->>'settlements_for_game')::int <> 1
       OR jsonb_array_length(v_new->'calls'->0->'ledger_for_game') <> r.credits
       OR jsonb_array_length(v_new->'calls'->1->'ledger_for_game') <> r.credits
       OR v_new->'calls'->0->>'ledger_total' <> v_new->'calls'->1->>'ledger_total'
       OR v_new->'calls'->0->'wallets' <> v_new->'calls'->1->'wallets'
       OR (v_new->'calls'->0->'ret') - 'settled_at_set' <> (v_new->'calls'->1->'ret') - 'settled_at_set' THEN
      RAISE EXCEPTION 'E FAIL: % replay changed state: %', r.label, v_new;
    END IF;
    RAISE NOTICE 'E PASS % : call1 settlements=% ledger_for_game=% ledger_total=% wallets=% settled_at_set=% | call2 settlements=% ledger_for_game=% ledger_total=% wallets=% settled_at_set=% | returned money fields identical; = legacy',
      r.label,
      v_new->'calls'->0->>'settlements_for_game', jsonb_array_length(v_new->'calls'->0->'ledger_for_game'),
      v_new->'calls'->0->>'ledger_total', v_new->'calls'->0->'wallets', v_new->'calls'->0->'ret'->>'settled_at_set',
      v_new->'calls'->1->>'settlements_for_game', jsonb_array_length(v_new->'calls'->1->'ledger_for_game'),
      v_new->'calls'->1->>'ledger_total', v_new->'calls'->1->'wallets', v_new->'calls'->1->'ret'->>'settled_at_set';
  END LOOP;

  -- F. zero and negative earnings exactly as legacy
  FOR r IN SELECT unnest(ARRAY['F1_zero','F2_negative','F3_negative_pending']) AS label LOOP
    SELECT res INTO v_new FROM kan729_res WHERE phase = 'new' AND label = r.label;
    SELECT res INTO v_old FROM kan729_res WHERE phase = 'legacy' AND label = r.label;
    IF v_new IS DISTINCT FROM v_old THEN
      RAISE EXCEPTION 'F FAIL: % new % legacy %', r.label, v_new, v_old;
    END IF;
  END LOOP;
  v_c := (SELECT res FROM kan729_res WHERE phase = 'new' AND label = 'F1_zero')->'calls'->0;
  IF (v_c->'ret'->>'gross_collected_aed')::numeric <> 0 OR (v_c->'ret'->>'organiser_earnings_aed')::numeric <> 0
     OR v_c->'ret'->>'status' <> 'settled' OR (v_c->>'settlements_for_game')::int <> 1
     OR jsonb_array_length(v_c->'ledger_for_game') <> 0 THEN
    RAISE EXCEPTION 'F FAIL: zero earnings must settle with no credit: %', v_c;
  END IF;
  v_new := (SELECT res FROM kan729_res WHERE phase = 'new' AND label = 'F2_negative');
  IF (v_new->>'ok')::boolean OR v_new->>'error' <> 'fee_exceeds_gross' THEN
    RAISE EXCEPTION 'F FAIL: negative earnings must raise fee_exceeds_gross: %', v_new;
  END IF;
  v_new := (SELECT res FROM kan729_res WHERE phase = 'new' AND label = 'F3_negative_pending');
  IF (v_new->>'ok')::boolean OR v_new->>'error' <> 'fee_exceeds_gross' THEN
    RAISE EXCEPTION 'F FAIL: negative earnings must raise even with p_finalize=false: %', v_new;
  END IF;
  RAISE NOTICE 'F PASS zero/negative = legacy: g2 gross 0 -> settled row, earnings 0.00, no ledger credit; g3 gross 30 with min fee 50 -> fee_exceeds_gross (finalize and pending), no row';

  -- H. plan
  SELECT * INTO r FROM kan729_plan WHERE phase = 'new';
  SELECT * INTO o FROM kan729_plan WHERE phase = 'legacy';
  IF r.events_scans <> 1 OR r.subplans <> 0 OR o.subplans <> 0
     OR r.rels <> ARRAY['events','games','sports'] OR o.rels <> ARRAY['games','sports'] OR r.plan_rows > 1 THEN
    RAISE EXCEPTION 'H FAIL: plan new % legacy %', row_to_json(r), row_to_json(o);
  END IF;
  RAISE NOTICE 'H PASS plan: legacy relations % -> new % (exactly one added: events, scanned once via %), 0 SubPlans, est rows %; single-row lookup per call, no per-row repetition',
    o.rels, r.rels, r.events_node, r.plan_rows;
END
$asrt$;

-- ---------------------------------------------------------------------------------------------------------
-- G (part 2). Rollback restored the old body; data intact; re-apply the migration and verify the round trip.
-- ---------------------------------------------------------------------------------------------------------
DO $g1$
DECLARE n record; o record; dn record; dl record;
BEGIN
  SELECT * INTO n FROM kan729_meta WHERE phase = 'new';
  SELECT * INTO o FROM kan729_meta WHERE phase = 'legacy';
  SELECT * INTO dn FROM kan729_data WHERE phase = 'new';
  SELECT * INTO dl FROM kan729_data WHERE phase = 'legacy';
  IF o.src_md5 <> '9357b0e9dc93ba715811aa0ae101cd76' OR n.src_md5 <> 'ee62121d87bee5c6dd1109e6ad11d8b4' THEN
    RAISE EXCEPTION 'G FAIL: rollback md5 % (want 9357b0e9...), new md5 %', o.src_md5, n.src_md5;
  END IF;
  IF row(dn.games, dn.events, dn.meetups, dn.harness_meetup, dn.settlements, dn.ledger, dn.wallets, dn.charges, dn.rules)
     IS DISTINCT FROM
     row(dl.games, dl.events, dl.meetups, dl.harness_meetup, dl.settlements, dl.ledger, dl.wallets, dl.charges, dl.rules) THEN
    RAISE EXCEPTION 'G FAIL: data changed across rollback/probes: % vs %', row_to_json(dn), row_to_json(dl);
  END IF;
  RAISE NOTICE 'G PASS rollback block restores md5 9357b0e9dc93ba715811aa0ae101cd76 (20260911114500), ACL/comment unchanged; games/events/meetups/settlements/ledger/wallets/charges/rules byte-identical across the NEW probes, the rollback and the LEGACY probes (settlements %, ledger %)',
    dn.settlements, dn.ledger;
END
$g1$;

\ir ../../migrations/20261104101000_kan714_b10_settle_game_reads.sql

SELECT pg_temp.kan729_snap('reapplied');

DO $g2$
DECLARE n record; ra record; dn record; dr record;
BEGIN
  SELECT * INTO n FROM kan729_meta WHERE phase = 'new';
  SELECT * INTO ra FROM kan729_meta WHERE phase = 'reapplied';
  SELECT * INTO dn FROM kan729_data WHERE phase = 'new';
  SELECT * INTO dr FROM kan729_data WHERE phase = 'reapplied';
  IF (n.args, n.full_args, n.result, n.ret_cols, n.lang, n.secdef, n.vol, n.config, n.owner, n.acl, n.comment, n.src_md5)
     IS DISTINCT FROM
     (ra.args, ra.full_args, ra.result, ra.ret_cols, ra.lang, ra.secdef, ra.vol, ra.config, ra.owner, ra.acl, ra.comment, ra.src_md5) THEN
    RAISE EXCEPTION 'G FAIL: re-applied function differs from first apply: % vs %', row_to_json(n), row_to_json(ra);
  END IF;
  IF row(dn.games, dn.events, dn.meetups, dn.harness_meetup, dn.settlements, dn.ledger, dn.wallets, dn.charges, dn.rules)
     IS DISTINCT FROM
     row(dr.games, dr.events, dr.meetups, dr.harness_meetup, dr.settlements, dr.ledger, dr.wallets, dr.charges, dr.rules) THEN
    RAISE EXCEPTION 'G FAIL: data changed across re-apply';
  END IF;
  IF dn.harness_meetup IS NULL THEN
    RAISE EXCEPTION 'G FAIL: harness meetup missing';
  END IF;
  RAISE NOTICE 'G PASS re-apply: md5 % again, identical attributes/ACL/comment, data intact, harness meetup 30000000-...-0001 present and unchanged (md5 %)',
    ra.src_md5, dr.harness_meetup;
END
$g2$;

DO $done$ BEGIN RAISE NOTICE 'KAN-729 ALL PASS'; END $done$;
