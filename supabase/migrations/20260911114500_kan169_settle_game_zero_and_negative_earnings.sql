-- KAN-169 SITTING 2 — settle_game: zero-earnings and negative-earnings settlements.
-- Forward-only (T-068). Signature unchanged, so CREATE OR REPLACE preserves proacl; sitting 1's
-- revoke is not restated and must still read {postgres=X/postgres,service_role=X/postgres} after.
-- T-058: attributes carried from the live catalogue read after sitting 1 applied —
-- prosecdef = true, proconfig = {search_path=public}.
--
-- DEFECT FOUND BY PROBE B, not by inspection. Sitting 1 made gross DERIVED, so gross = 0 stopped
-- being something a caller opts into and became the DEFAULT state of every game with no succeeded
-- charges — which today is every game, since public.charges is empty. The credit then hits
--   wallet_ledger_amount_aed_check  CHECK (amount_aed > 0)
-- and the whole settlement aborts with 23514. Measured: settling a real game as its own organiser
-- raised 23514 on a 0.00 credit. Sitting 1 alone leaves settle_game unable to settle ANY game.
--
-- RULING — the two cases are NOT the same and must not share a branch:
--   earnings = 0  -> settle, post NO credit. A zero credit moves no money and the ledger's own
--                    invariant forbids the row. The settlement row is still written: "this game
--                    collected nothing" is a real, recordable outcome (a free game, or one whose
--                    charges all refunded to zero).
--   earnings < 0  -> RAISE 'fee_exceeds_gross'. Reachable when commission_rules.min_app_fee_aed
--                    exceeds what the game collected (today the single active rule has min = 0.00,
--                    so this is latent, not live). A credit cannot carry a negative amount, and
--                    this function has no authority to invent a debit. Skipping it silently would
--                    hide an organiser who owes the platform money — the exact class of silent
--                    money defect T-049 exists to prevent. Checked BEFORE the settlement insert,
--                    because a stored negative organiser_earnings_aed is wrong whether or not
--                    p_finalize was passed.

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
