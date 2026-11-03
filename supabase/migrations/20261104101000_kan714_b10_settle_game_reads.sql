-- KAN-729 (Events P2, KAN-714 piece B10): public.settle_game reads its SHARED facts from public.events.
-- MONEY PATH (T-049). Only the read that derives organiser and sport moves; every write is untouched.
--
-- AUTHORED, NOT APPLIED. Applied only under G-002 by the applying seat after PEER review (backend-N).
-- Local proof: supabase/tests/events_p2/kan714_b10_settle_game.sql.
--
-- Pre-image: settle_game(uuid,boolean) from 20260911114500_kan169_settle_game_zero_and_negative_earnings.sql:28-204
-- (comment 20260911113000_kan169_settle_game_derive_inputs.sql:222, ACL :227-228). Nothing later in migrations/
-- redefines it in this branch. md5(prosrc) of that body = 9357b0e9dc93ba715811aa0ae101cd76.
--
-- Not KAN-712-wrapped: KAN-712 wraps only the 11 UPDATE-path RPCs (20261103110000_kan712_cutover.sql:102-112) and
-- settle_game is not among them. The guard below refuses if public.kan712_wrapped_rpcs lists it or a
-- settle_game_kan712_inner exists, because a bare CREATE OR REPLACE would then clobber the wrapper.
--
-- The one change (lines 160-171 of this file; the comment above it is updated to match):
--   legacy:  select g.creator_user_id, s.sport_key ... from public.games g
--              join public.sports s on s.id = g.sport_id where g.id = p_game_id;
--   now:     select e.creator_user_id, s.sport_key ... from public.games g
--              join public.events e on e.id = g.event_id and e.event_type = 'game'
--              join public.sports s on s.id = e.sport_id where g.id = p_game_id;
--   INNER join: games.event_id is NOT NULL + FK-validated since the KAN-712 cutover (asserted below), events.id is
--   the PK, so a game always has exactly one parent and no row is lost or duplicated; `not found` still means
--   game_not_found. events.creator_user_id is NOT NULL; events.sport_id is NOT NULL for games
--   (events_game_sport_required). Shared columns switched: creator_user_id, sport_id. settle_game reads no other
--   games column (gross comes from public.charges, keyed by p_game_id = games.id, unchanged).
--
-- Unchanged, byte for byte: signature, return type, every error code and its order, the commission resolution,
-- the zero (no credit) and negative (fee_exceeds_gross) earnings branches, the game_settlements upsert
-- ON CONFLICT (game_id) DO UPDATE, the wallet_ledger credit keyed ('game_settlement', gs.id, 'credit')
-- ON CONFLICT DO NOTHING, and the attributes (SECURITY DEFINER, search_path=public, owner postgres,
-- ACL {postgres=X/postgres,service_role=X/postgres}, comment). CREATE OR REPLACE with an unchanged signature keeps
-- owner, ACL and comment; all are asserted against a pre-image. No GRANT, no REVOKE, no policy, no DROP, no data
-- mutation. SECURITY DEFINER (owner postgres, BYPASSRLS) means no API role needs a grant on public.events
-- (FORCE RLS, no API grants) and none is added.

BEGIN;

-- ---------------------------------------------------------------------------------------------------------
-- 0. Stage guard
-- ---------------------------------------------------------------------------------------------------------
DO $guard$
DECLARE
  r record;
  v_drift bigint;
  f oid := to_regprocedure('public.settle_game(uuid,boolean)');
  p record;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = current_user AND (rolsuper OR rolbypassrls)) THEN
    RAISE EXCEPTION 'KAN-729: applying role % must be superuser or BYPASSRLS', current_user;
  END IF;

  IF to_regclass('public.events') IS NULL THEN
    RAISE EXCEPTION 'KAN-729: public.events missing (KAN-710 not applied)';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_class WHERE oid = 'public.events'::regclass AND relrowsecurity AND relforcerowsecurity) THEN
    RAISE EXCEPTION 'KAN-729: public.events is not RLS-enabled + FORCE (KAN-710 security model changed; stop)';
  END IF;

  -- KAN-712 stage B (cutover) markers.
  FOR r IN SELECT * FROM (VALUES
      ('public.events',  'trg_zz_kan712_events_compat_mirror'),
      ('public.games',   'trg_zz_kan712_games_guard'),
      ('public.meetups', 'trg_zz_kan712_meetups_guard')) AS t(tbl, tg)
  LOOP
    IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgrelid = r.tbl::regclass AND tgname = r.tg AND tgenabled = 'O') THEN
      RAISE EXCEPTION 'KAN-729: KAN-712 cutover not live (% on % missing or disabled)', r.tg, r.tbl;
    END IF;
  END LOOP;
  IF to_regclass('public.kan712_wrapped_rpcs') IS NULL THEN
    RAISE EXCEPTION 'KAN-729: KAN-712 write contract not applied (public.kan712_wrapped_rpcs missing)';
  END IF;
  IF (SELECT count(*) FROM pg_constraint
       WHERE conrelid = 'public.games'::regclass
         AND conname IN ('games_event_id_not_null', 'games_event_id_fkey') AND convalidated) <> 2 THEN
    RAISE EXCEPTION 'KAN-729: games.event_id NOT NULL / FK not validated (KAN-711 validate_links)';
  END IF;
  IF EXISTS (SELECT 1 FROM public.games WHERE event_id IS NULL) THEN
    RAISE EXCEPTION 'KAN-729: games rows with NULL event_id; the INNER join would turn them into game_not_found';
  END IF;

  -- KAN-713 live: access helpers (20261104100000), the same dependency marker B01/B02/B07 use.
  IF to_regprocedure('public._can_view_game(uuid)') IS NULL
     OR to_regprocedure('public.kan713_meetup_visible(uuid)') IS NULL THEN
    RAISE EXCEPTION 'KAN-729: KAN-713 access helpers not live (20261104100000 not applied)';
  END IF;

  -- settle_game: present, unwrapped, definer, expected attributes, expected body.
  IF f IS NULL THEN
    RAISE EXCEPTION 'KAN-729: public.settle_game(uuid,boolean) missing (20260911113000/20260911114500 not applied)';
  END IF;
  IF EXISTS (SELECT 1 FROM public.kan712_wrapped_rpcs WHERE name = 'settle_game')
     OR EXISTS (SELECT 1 FROM pg_proc WHERE pronamespace = 'public'::regnamespace AND proname = 'settle_game_kan712_inner') THEN
    RAISE EXCEPTION 'KAN-729: settle_game is KAN-712-wrapped; change it via kan712_unwrap_rpc/kan712_wrap_rpc — decision_required, stop';
  END IF;
  SELECT pr.prosecdef, pr.provolatile, pr.proconfig, l.lanname, pg_get_userbyid(pr.proowner) AS owner,
         pr.proacl::text AS acl, md5(pr.prosrc) AS h
    INTO p FROM pg_proc pr JOIN pg_language l ON l.oid = pr.prolang WHERE pr.oid = f;
  IF NOT p.prosecdef OR p.provolatile <> 'v' OR p.lanname <> 'plpgsql' OR p.owner <> 'postgres'
     OR p.proconfig IS DISTINCT FROM ARRAY['search_path=public']
     OR p.acl IS DISTINCT FROM '{postgres=X/postgres,service_role=X/postgres}' THEN
    RAISE EXCEPTION 'KAN-729: settle_game attributes drifted from 20260911114500 (secdef %, volatility %, language %, owner %, config %, acl %); stop',
      p.prosecdef, p.provolatile, p.lanname, p.owner, p.proconfig, p.acl;
  END IF;
  -- 9357b0... = prosrc of 20260911114500:28-204; ee6212... = prosrc of this file (idempotent re-apply).
  IF p.h NOT IN ('9357b0e9dc93ba715811aa0ae101cd76', 'ee62121d87bee5c6dd1109e6ad11d8b4') THEN
    RAISE EXCEPTION 'KAN-729: settle_game body (md5 %) is neither 20260911114500 nor this file; it was redefined elsewhere — stop', p.h;
  END IF;

  -- Value equivalence on the two columns this file moves to events. A disagreement would change who is paid.
  SELECT count(*) INTO v_drift
    FROM public.games g
    LEFT JOIN public.events e ON e.id = g.event_id AND e.event_type = 'game'
   WHERE e.id IS NULL
      OR (g.creator_user_id, g.sport_id) IS DISTINCT FROM (e.creator_user_id, e.sport_id);
  IF v_drift <> 0 THEN
    RAISE EXCEPTION 'KAN-729: % games rows disagree with (or lack) their events parent on creator_user_id/sport_id; reconcile first', v_drift;
  END IF;
END
$guard$;

-- ---------------------------------------------------------------------------------------------------------
-- 1. Pre-image
-- ---------------------------------------------------------------------------------------------------------
CREATE TEMP TABLE kan729_fpre ON COMMIT DROP AS
SELECT pg_get_function_identity_arguments(p.oid) AS args, pg_get_function_arguments(p.oid) AS full_args,
       pg_get_function_result(p.oid) AS result, p.prolang, p.prosecdef, p.provolatile, p.proparallel, p.proleakproof,
       p.proisstrict, p.procost, p.prorows, p.proconfig, pg_get_userbyid(p.proowner) AS owner, p.proacl::text AS acl,
       obj_description(p.oid, 'pg_proc') AS comment
  FROM pg_proc p WHERE p.oid = 'public.settle_game(uuid,boolean)'::regprocedure;

-- ---------------------------------------------------------------------------------------------------------
-- 2. settle_game (identical to 20260911114500 except the organiser/sport read and its comment)
-- ---------------------------------------------------------------------------------------------------------
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

  -- T-069 Q1: organiser and sport are DERIVED, never accepted. KAN-729 (KAN-714 B10): both are
  -- SHARED facts and are read from the game's events parent — events.creator_user_id is the
  -- authoritative identity (profiles.id is a surrogate and is not an auth uid); the sport text key
  -- is sports.sport_key, reached through events.sport_id (events_game_sport_required holds it
  -- NOT NULL for event_type='game', FK -> sports). games stays the lookup key: p_game_id is a
  -- games.id, games.event_id is NOT NULL + FK-validated (KAN-712), events.id is the PK.
  select e.creator_user_id, s.sport_key
    into v_organiser_user_id, v_sport
  from public.games g
  join public.events e on e.id = g.event_id and e.event_type = 'game'
  join public.sports s on s.id = e.sport_id
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

-- ---------------------------------------------------------------------------------------------------------
-- 3. Post-conditions
-- ---------------------------------------------------------------------------------------------------------
DO $post$
DECLARE
  pre kan729_fpre%ROWTYPE;
  now_f record;
BEGIN
  SELECT * INTO pre FROM kan729_fpre;
  IF NOT FOUND THEN RAISE EXCEPTION 'KAN-729 post: pre-image missing'; END IF;
  SELECT pg_get_function_identity_arguments(p.oid) AS args, pg_get_function_arguments(p.oid) AS full_args,
         pg_get_function_result(p.oid) AS result, p.prolang, p.prosecdef, p.provolatile, p.proparallel, p.proleakproof,
         p.proisstrict, p.procost, p.prorows, p.proconfig, pg_get_userbyid(p.proowner) AS owner, p.proacl::text AS acl,
         obj_description(p.oid, 'pg_proc') AS comment, p.prosrc
    INTO now_f FROM pg_proc p WHERE p.oid = 'public.settle_game(uuid,boolean)'::regprocedure;
  IF (now_f.args, now_f.full_args, now_f.result, now_f.prolang, now_f.prosecdef, now_f.provolatile, now_f.proparallel,
      now_f.proleakproof, now_f.proisstrict, now_f.procost, now_f.prorows, now_f.proconfig, now_f.owner, now_f.acl, now_f.comment)
     IS DISTINCT FROM
     (pre.args, pre.full_args, pre.result, pre.prolang, pre.prosecdef, pre.provolatile, pre.proparallel,
      pre.proleakproof, pre.proisstrict, pre.procost, pre.prorows, pre.proconfig, pre.owner, pre.acl, pre.comment) THEN
    RAISE EXCEPTION 'KAN-729 post: settle_game signature/result/attributes/owner/ACL/comment changed';
  END IF;
  IF now_f.args <> 'p_game_id uuid, p_finalize boolean' OR now_f.result <> 'game_settlements'
     OR NOT now_f.prosecdef OR now_f.proconfig IS DISTINCT FROM ARRAY['search_path=public']
     OR now_f.owner <> 'postgres' OR now_f.acl <> '{postgres=X/postgres,service_role=X/postgres}' THEN
    RAISE EXCEPTION 'KAN-729 post: settle_game identity/attributes are not the expected ones (%)', row_to_json(now_f)::text;
  END IF;
  IF has_function_privilege('anon', 'public.settle_game(uuid,boolean)'::regprocedure, 'EXECUTE')
     OR has_function_privilege('authenticated', 'public.settle_game(uuid,boolean)'::regprocedure, 'EXECUTE') THEN
    RAISE EXCEPTION 'KAN-729 post: anon or authenticated can EXECUTE settle_game';
  END IF;
  IF md5(now_f.prosrc) <> 'ee62121d87bee5c6dd1109e6ad11d8b4' THEN
    RAISE EXCEPTION 'KAN-729 post: settle_game body md5 % is not this file''s', md5(now_f.prosrc);
  END IF;
  IF position('join public.events e on e.id = g.event_id and e.event_type = ''game''' IN now_f.prosrc) = 0
     OR position('join public.sports s on s.id = e.sport_id' IN now_f.prosrc) = 0 THEN
    RAISE EXCEPTION 'KAN-729 post: settle_game does not read organiser/sport from public.events';
  END IF;
  IF now_f.prosrc ~ '\mg\.(creator_user_id|creator_profile_id|sport_id|start_at|end_at|is_cancelled|listing_visibility|area_id|capacity)\M' THEN
    RAISE EXCEPTION 'KAN-729 post: settle_game still reads a shared games column';
  END IF;
  RAISE NOTICE 'KAN-729: settle_game reads creator_user_id and sport_id from public.events; writes and attributes unchanged';
END
$post$;

COMMIT;

-- ---------------------------------------------------------------------------------------------------------
-- ROLLBACK (manual; NOT executed by this migration). Restores 20260911114500_kan169_settle_game_zero_and_negative_
-- earnings.sql:28-204 verbatim (md5(prosrc) 9357b0e9dc93ba715811aa0ae101cd76). Same signature, so CREATE OR REPLACE
-- keeps owner, ACL and comment. No data is touched: settlements and ledger rows written in between stay as written.
-- Run as postgres: strip the leading "-- " (or "--" on blank lines) from the lines between the markers.
-- KAN729-ROLLBACK-BEGIN
-- BEGIN;
-- create or replace function public.settle_game(p_game_id uuid, p_finalize boolean default true)
-- returns game_settlements
-- language plpgsql
-- security definer
-- set search_path to 'public'
-- as $function$
-- declare
--   me uuid := auth.uid();
--   r record;
--   v_organiser_user_id uuid;
--   v_sport text;
--   v_gross numeric(12,2);
--   v_charge_count bigint;
--   v_currency_count bigint;
--   v_currency text;
--   fee_rate numeric(5,2);
--   min_fee numeric(12,2);
--   max_fee numeric(12,2);
--   fee numeric(12,2);
--   earnings numeric(12,2);
--   gs public.game_settlements;
-- begin
--   if me is null then
--     raise exception using errcode='P0001', message='auth_required';
--   end if;
--
--   -- T-069 Q1: organiser and sport are DERIVED, never accepted. games.creator_user_id is the
--   -- authoritative identity (profiles.id is a surrogate and is not an auth uid); the sport text key
--   -- is sports.sport_key, reached through games.sport_id (NOT NULL, FK -> sports).
--   select g.creator_user_id, s.sport_key
--     into v_organiser_user_id, v_sport
--   from public.games g
--   join public.sports s on s.id = g.sport_id
--   where g.id = p_game_id;
--
--   if not found then
--     raise exception using errcode='P0001', message='game_not_found';
--   end if;
--
--   if v_organiser_user_id is null then
--     -- games_creator_user_id_fkey is ON DELETE SET NULL while the column is declared NOT NULL, so
--     -- this is unreachable today. It is checked anyway: settling a game with no organiser would
--     -- otherwise credit wallet_ledger.user_id = null.
--     raise exception using errcode='P0001', message='organiser_unresolved';
--   end if;
--
--   -- Gate, now against the DERIVED organiser. The old body compared auth.uid() to the caller's own
--   -- p_organiser_user_id, which is satisfied by any authenticated caller for any game.
--   if not (public.is_admin(me) or me = v_organiser_user_id) then
--     raise exception using errcode='P0001', message='forbidden';
--   end if;
--
--   -- T-069 Q2: gross is an aggregate over the game's charges rows. Refunds are compensating rows
--   -- with kind='refund' and a negative amount (KAN-171/T-049), so sum(amount) is the NET collected.
--   -- charges_purpose_idx (purpose_type, purpose_id) serves this predicate exactly.
--   select coalesce(sum(c.amount), 0), count(*), count(distinct c.currency), min(c.currency)
--     into v_gross, v_charge_count, v_currency_count, v_currency
--   from public.charges c
--   where c.purpose_type = 'game'
--     and c.purpose_id   = p_game_id
--     and c.status       = 'succeeded';
--
--   -- DECISION 2, enforced: detect, never sum across currencies into an AED-named column.
--   if v_currency_count > 1 then
--     raise exception using errcode='P0001', message='mixed_currency_charges';
--   end if;
--
--   if v_currency_count = 1 and v_currency <> 'AED' then
--     raise exception using errcode='P0001', message='non_aed_charges';
--   end if;
--
--   -- Preserved error code. Refunds can drive the net below zero, and
--   -- game_settlements_gross_collected_aed_check requires >= 0.
--   if v_gross is null or v_gross < 0 then
--     raise exception using errcode='P0001', message='invalid_gross';
--   end if;
--
--   -- fetch correct commission rule
--   select * into r
--   from public.resolve_commission(v_organiser_user_id, v_sport, now());
--
--   fee_rate := coalesce(r.rate, 10.00);
--   min_fee  := coalesce(r.min_fee, 0);
--   max_fee  := coalesce(r.max_fee, null);
--
--   fee := round(v_gross * (fee_rate/100.0), 2);
--   if fee < min_fee then fee := min_fee; end if;
--   if max_fee is not null and fee > max_fee then fee := max_fee; end if;
--
--   earnings := round(v_gross - fee, 2);
--
--   -- SITTING 2: min_app_fee_aed can exceed what the game collected. That is a debit, and this
--   -- function has no authority to invent one. Raised before the settlement row is written.
--   if earnings < 0 then
--     raise exception using errcode='P0001', message='fee_exceeds_gross';
--   end if;
--
--   insert into public.game_settlements(
--       game_id,
--       organiser_user_id,
--       sport,
--       gross_collected_aed,
--       app_fee_rate,
--       app_fee_aed,
--       organiser_earnings_aed,
--       status,
--       meta
--   )
--   values (
--       p_game_id,
--       v_organiser_user_id,
--       v_sport,
--       v_gross,
--       fee_rate,
--       fee,
--       earnings,
--       -- KAN-138: cast added. Both branches are untyped literals, so the bare CASE resolved to
--       -- `text`, and there is no text -> settlement_status cast of any kind (pg_cast count 0).
--       -- Every call raised 42804 here, before reaching the wallet_ledger credit below.
--       (case when p_finalize then 'settled' else 'pending' end)::public.settlement_status,
--       -- DECISION 1: the admin/organiser discriminator lives here (game_settlements has no column
--       -- for it; `meta` IS on the row, satisfying T-069 without widening a money table).
--       jsonb_build_object(
--         'resolved_at',        now(),
--         'settled_by',         me,
--         'settled_via',        case when me = v_organiser_user_id then 'organiser' else 'admin' end,
--         'gross_source',       'charges',
--         'gross_charge_count', v_charge_count,
--         'gross_currency',     coalesce(v_currency, 'AED')
--       )
--   )
--   on conflict (game_id) do update
--     set gross_collected_aed   = excluded.gross_collected_aed,
--         app_fee_rate          = excluded.app_fee_rate,
--         app_fee_aed           = excluded.app_fee_aed,
--         organiser_earnings_aed = excluded.organiser_earnings_aed,
--         status                 = excluded.status,
--         meta                   = excluded.meta,
--         settled_at             = case when excluded.status='settled' then now() else null end
--   returning * into gs;
--
--   -- finalize -> post wallet credit
--   -- SITTING 2: `earnings > 0` guard. wallet_ledger_amount_aed_check is `amount_aed > 0`, so a
--   -- zero-earnings settlement must post no credit rather than abort the settlement.
--   if p_finalize and gs.organiser_earnings_aed > 0 then
--     -- KAN-128: a re-settle returns the same gs.id from the upsert above, so before this clause a
--     -- second finalize posted a second identical credit for ('game_settlement', gs.id, 'credit').
--     -- Now it is absorbed.
--     insert into public.wallet_ledger(
--       user_id,
--       direction,
--       amount_aed,
--       status,
--       ref_type,
--       ref_id,
--       memo,
--       meta
--     )
--     values (
--       v_organiser_user_id,
--       'credit',
--       gs.organiser_earnings_aed,
--       'posted',
--       'game_settlement',
--       gs.id,
--       'Game settlement earnings',
--       jsonb_build_object(
--         'game_id', gs.game_id,
--         'sport', gs.sport
--       )
--     )
--     on conflict do nothing;
--   end if;
--
--   return gs;
-- end;
-- $function$;
-- COMMIT;
-- KAN729-ROLLBACK-END
