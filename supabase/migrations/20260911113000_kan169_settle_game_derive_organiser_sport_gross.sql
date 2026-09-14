-- KAN-169 — public.settle_game: organiser, sport and gross derived server-side from p_game_id.
-- Ruling: T-069 (Q1 organiser+sport, Q2 gross, Q3 role model). Unblocked by KAN-171 (public.charges).
-- Author: backend-4 (Min). Route PEER. Landing: apply_migration per T-068 step 1, never db push.
--
-- T-058: the body below was authored from pg_get_functiondef() on the live catalogue, not from a
-- migration file, so SECURITY DEFINER and SET search_path TO 'public' are carried verbatim.
--
-- SIGNATURE CHANGE, therefore DROP + CREATE, not CREATE OR REPLACE:
--   settle_game(uuid, uuid, text, numeric, boolean) -> settle_game(uuid, boolean)
-- p_organiser_user_id, p_sport and p_gross_collected are REMOVED. T-069 Q1: a parameter that must
-- equal a derived value carries no information and adds a mismatch failure mode. Deriving once
-- makes the gate, the commission lookup and the credit recipient the same value by construction.
--
-- CARRIED FORWARD (T-069 "What must not be regressed"):
--   KAN-128 — `on conflict do nothing` on the wallet_ledger credit (absorbs the re-settle duplicate
--             against wallet_ledger_ref_key_unique (ref_type, ref_id, direction)).
--   KAN-138 — the ::public.settlement_status cast on the CASE. Both branches are untyped literals,
--             the bare CASE resolves to text, and no text -> settlement_status cast exists.
--
-- ACL: pg_default_acl for functions in `public` grants anon AND authenticated BY NAME
-- ({postgres=X,anon=X,authenticated=X,service_role=X}), so this CREATE re-grants both (T-078).
-- Revoking PUBLIC alone would leave anon executable. Both are named explicitly below. T-069 Q3:
-- service_role is permanent posture, not containment to be lifted when payments ship.

-- ---------------------------------------------------------------------------
-- DECISION 1 — admin-settlement discriminator. RULED, not deferred.
--   T-069 Q1 requires that "an admin settlement must be recorded as one on the row, not made
--   indistinguishable from an organiser's". game_settlements has no such column — measured:
--   information_schema.columns lists id, game_id, organiser_user_id, sport, gross_collected_aed,
--   app_fee_rate, app_fee_aed, organiser_earnings_aed, status, notes, meta, created_at, settled_at.
--   RULING: record it in `meta`, which IS on the row and which this function already writes.
--   Adding a column to a money table is a shape change reserved to cto (021); `meta` satisfies
--   T-069's requirement literally without taking that decision here. meta.settled_by is the acting
--   auth.uid() and meta.settled_via is 'admin' or 'organiser'. An admin settling their own game
--   records 'organiser', which is what happened.
--   FLAGGED for cto: if the discriminator needs to be indexable or constrainable it must be
--   promoted to a typed column — that is a separate ticket, not this one.
--
-- DECISION 2 — AED vs multi-currency. RULED, not deferred.
--   charges.currency is per-row and no CHECK pins it to 'AED' (KAN-171 left it open deliberately,
--   so that a mixed-currency game is DETECTABLE). The destination is gross_collected_aed, AED-only
--   by name, and T-063 bars converting a *_aed column inside a billing ticket.
--   RULING: detect and fail loudly; never sum across currencies.
--     > 1 distinct currency  -> raise 'mixed_currency_charges'
--     = 1 and not 'AED'      -> raise 'non_aed_charges'
--     0 succeeded rows       -> gross 0 (a game that collected nothing settles to nothing)
--   Writing a non-AED sum into an AED-named column is the silent defect this exists to prevent.
--   Conversion needs an FX-rate source and a rate-at-time policy; neither exists. That is a ticket.
-- ---------------------------------------------------------------------------

drop function public.settle_game(uuid, uuid, text, numeric, boolean);

create function public.settle_game(p_game_id uuid, p_finalize boolean default true)
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

  -- DECISION 2, enforced.
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
      -- DECISION 1: the admin/organiser discriminator lives here.
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
  if p_finalize then
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
