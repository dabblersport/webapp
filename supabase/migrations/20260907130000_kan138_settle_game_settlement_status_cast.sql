-- SUPERSEDED AND DEAD -- DO NOT APPLY. Flagged 2026-09-11 (team-lead/po), verified
-- against this file and against KAN-169's own log.
--
-- This migration reproduces the PRE-T-069 vulnerable settle_game body verbatim: a
-- 5-parameter signature settle_game(p_game_id uuid, p_organiser_user_id uuid,
-- p_sport text, p_gross_collected numeric, p_finalize boolean) in which
-- p_organiser_user_id is caller-supplied, never validated against the game's
-- actual organiser. The function's own guard -- "if not (public.is_admin(me) or
-- me = p_organiser_user_id)" -- is satisfied by any authenticated caller simply
-- passing their own auth.uid() as p_organiser_user_id; this file's own comment at
-- line 69-70 states the exploit outright as its probe's reachability proof.
-- backend-4 demonstrated this live against the pre-fix body on 2026-09-11: a
-- non-organiser settled a game they did not own and credited themselves
-- 899,999.10 AED.
--
-- KAN-169 (T-069) is APPLIED and supersedes this file. It changed settle_game's
-- signature to (p_game_id uuid, p_finalize boolean) -- organiser, sport and gross
-- are now derived server-side from the game's own data, not accepted as
-- caller-supplied arguments. Landed via apply_migration as
-- 20260911113000_kan169_settle_game_derive_organiser_sport_gross.sql and
-- 20260911114500_kan169_settle_game_zero_and_negative_earnings.sql.
--
-- APPLYING THIS FILE WOULD SILENTLY REVERT THE KAN-169 FIX AND RESTORE THE
-- PRIVILEGE-ESCALATION BUG. Do not run it.
--
-- ============================================================================
--
-- KAN-138 / T-058 Decision 4: settle_game raises 42804 before reaching its
-- wallet_ledger credit insert. Cast the status CASE to settlement_status.
--
-- ============================================================================
-- THE DEFECT, REPRODUCED LIVE 2026-09-07 -- not argued from the source
-- ============================================================================
-- game_settlements.status is public.settlement_status (enum: pending, settled,
-- refunded, cancelled). The insert supplies it as:
--
--     case when p_finalize then 'settled' else 'pending' end
--
-- Both branches are untyped literals, so the CASE resolves to `text`, and there
-- is NO cast from text to settlement_status at all -- not implicit, not even
-- explicit-only. Measured: SELECT count(*) FROM pg_cast WHERE castsource =
-- 'text'::regtype AND casttarget = 'public.settlement_status'::regtype -> 0.
--
-- I did not stop at reading the source. I built a reachable caller (see below)
-- and executed it. The live failure, verbatim:
--
--   ERROR: 42804: column "status" is of type settlement_status but expression
--          is of type text
--   HINT:  You will need to rewrite or cast the expression.
--   CONTEXT: PL/pgSQL function settle_game(uuid,uuid,text,numeric,boolean)
--            line 39 at SQL statement
--
-- Line 39 is the game_settlements insert. Execution reaches it and dies there,
-- BEFORE the wallet_ledger credit insert further down. That is exactly the
-- claim T-058 Decision 4 makes, now confirmed by execution rather than by
-- reading.
--
-- ============================================================================
-- AC2 IS THE REAL WORK: "the path reaches the credit insert -- NOT that the
-- function compiles." Compiling is necessary and not sufficient.
-- ============================================================================
-- A probe cannot reach this code by accident, and the reason is itself the
-- T-055 trap in its ORIGINAL form (raises before reaching the code under test):
--
--     me uuid := auth.uid();
--     if me is null then raise ... 'auth_required'; end if;
--     if not (public.is_admin(me) or me = p_organiser_user_id) then
--       raise ... 'forbidden'; end if;
--
-- Any ordinary call from a service-role or postgres session has auth.uid() =
-- NULL and dies at `auth_required` -- three guards and a commission lookup
-- before the insert. A probe that stopped there would report "settle_game
-- raises" and prove NOTHING about the type error.
--
-- No game has ever settled (game_settlements = 0 rows) and no payment has ever
-- completed, so no natural caller exists to borrow. The caller must be
-- constructed. This is the one that works, and it is what the post-apply
-- verification re-runs:
--
--   DO $probe$
--   DECLARE v_uid uuid; v_game uuid; gs public.game_settlements;
--   BEGIN
--     SELECT id INTO v_uid  FROM auth.users   LIMIT 1;
--     SELECT id INTO v_game FROM public.games LIMIT 1;
--     -- make auth.uid() resolve so the function's OWN guards pass and
--     -- execution actually reaches the insert under test
--     PERFORM set_config('request.jwt.claims',
--                        json_build_object('sub', v_uid::text)::text, true);
--     IF auth.uid() IS DISTINCT FROM v_uid THEN
--       RAISE EXCEPTION 'PROBE_SETUP_FAILED';   -- assert the setup, don't assume it
--     END IF;
--     gs := public.settle_game(v_game, v_uid, 'football', 100.00, true);
--     RAISE EXCEPTION 'PROBE_RESULT=SETTLE_GAME_SUCCEEDED id=%', gs.id;
--   END $probe$;
--
--   Passing p_organiser_user_id = auth.uid() satisfies the `me =
--   p_organiser_user_id` branch without needing an admin.
--
--   NOTHING COMMITS. The trailing RAISE aborts the block on the success path,
--   and on the failure path the error aborts it. Both game_settlements and
--   wallet_ledger hold 0 rows before and after; the probe writes no row that
--   survives, and touches NO existing row -- so it is not the user-data
--   mutation 019 reserves to the CEO.
--
--   BEFORE this migration:  42804 at line 39, as quoted above.
--   AFTER this migration:   must reach the wallet_ledger insert and return a
--                           settlement id via PROBE_RESULT=SETTLE_GAME_SUCCEEDED.
--   The flip from "42804 at the game_settlements insert" to "reached the credit
--   insert" is the AC2 evidence. A green CREATE OR REPLACE is not.
--
-- ============================================================================
-- AUTHORED FROM THE LIVE CATALOGUE AFTER KAN-128 APPLIED -- CONVENTIONS.md 6g
-- ============================================================================
-- Body taken from pg_get_functiondef('public.settle_game(uuid,uuid,text,
-- numeric,boolean)'::regprocedure) read AFTER KAN-128 landed
-- (20260907064216 kan128_ledger_unique_keys_and_on_conflict, confirmed in the
-- applied ledger). NEVER from the baseline dump and never from KAN-128's
-- migration file.
--
-- This is not a formality on this ticket -- it is the failure mode. KAN-128
-- added the two ON CONFLICT clauses now present in this body:
--   * `on conflict (game_id) do update ...` on game_settlements
--   * `on conflict do nothing` on the wallet_ledger credit, with KAN-128's own
--     explanatory comment above it, preserved verbatim below
-- Authoring this fix from the baseline would silently drop BOTH while the
-- unique constraints stayed, and NOTHING would error at apply time. The next
-- duplicate webhook would then raise a unique violation instead of being
-- absorbed -- the outcome T-049 Decision 2 forbids. I verified their presence
-- in the live body before copying it (prosrc ILIKE '%on conflict%' -> true).
--
-- ATTRIBUTES, measured and restated exactly -- NOT inferred (AC4):
--   prosecdef   = true   -> SECURITY DEFINER kept. It is required: the function
--                           writes game_settlements and wallet_ledger, and its
--                           authorisation is internal (auth_required, then
--                           is_admin or self), not RLS.
--   provolatile = 'v'    -> VOLATILE, so pg_get_functiondef emits NO volatility
--                           keyword and neither does this file. Adding STABLE
--                           to "tidy" it would be a silent behavioural change.
--   proconfig   = search_path=public
--                        -> 'public' ALONE. NOT 'public', 'pg_temp'. The two
--                           functions in KAN-150 carry public+pg_temp and this
--                           one does not; there is no shared search_path string
--                           across these tickets. Restated per-function from its
--                           own header, never copied from a sibling migration.
--   RETURNS public.game_settlements (composite row type) -- unchanged.
--
-- AC5 -- NO DROP IS NEEDED, so its grant clause does not engage.
--   The signature is unchanged, so CREATE OR REPLACE suffices and grants
--   survive. Measured proacl before:
--     {=X/postgres, postgres=X/postgres, anon=X/postgres,
--      authenticated=X/postgres, service_role=X/postgres}
--   The bare `=X/postgres` entry is PUBLIC. Verification below asserts this ACL
--   is UNCHANGED after -- per T-058, assert the resulting proacl rather than
--   that a revoke ran.
--
--   NOT A FINDING, and I checked before saying so: a PUBLIC- and anon-executable
--   SECURITY DEFINER function would normally be the KAN-79/113/141 class. It is
--   not, because this one gates itself internally -- `auth.uid()` NULL raises
--   `auth_required`, and a non-admin caller who is not the organiser raises
--   `forbidden`. anon cannot pass either. Read the body before classifying the
--   grant; the grant alone does not tell you.
--
-- SCOPE: one expression. The `case when excluded.status='settled' ...` in the
-- DO UPDATE is deliberately NOT touched -- there `excluded.status` is already
-- settlement_status and the literal coerces to it correctly. Nothing else in
-- the body changes.

BEGIN;

CREATE OR REPLACE FUNCTION public.settle_game(p_game_id uuid, p_organiser_user_id uuid, p_sport text, p_gross_collected numeric, p_finalize boolean DEFAULT true)
 RETURNS game_settlements
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  me uuid := auth.uid();
  r record;
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

  -- Only admin or organiser can settle
  if not (public.is_admin(me) or me = p_organiser_user_id) then
    raise exception using errcode='P0001', message='forbidden';
  end if;

  if p_gross_collected is null or p_gross_collected < 0 then
    raise exception using errcode='P0001', message='invalid_gross';
  end if;

  -- fetch correct commission rule
  select * into r
  from public.resolve_commission(p_organiser_user_id, p_sport, now());

  fee_rate := coalesce(r.rate, 10.00);
  min_fee  := coalesce(r.min_fee, 0);
  max_fee  := coalesce(r.max_fee, null);

  fee := round(p_gross_collected * (fee_rate/100.0), 2);
  if fee < min_fee then fee := min_fee; end if;
  if max_fee is not null and fee > max_fee then fee := max_fee; end if;

  earnings := round(p_gross_collected - fee, 2);

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
      p_organiser_user_id,
      p_sport,
      p_gross_collected,
      fee_rate,
      fee,
      earnings,
      -- KAN-138: cast added. Both branches are untyped literals, so the bare
      -- CASE resolved to `text`, and there is no text -> settlement_status cast
      -- of any kind (pg_cast count 0). Every call raised 42804 here, before
      -- reaching the wallet_ledger credit below.
      (case when p_finalize then 'settled' else 'pending' end)::public.settlement_status,
      jsonb_build_object('resolved_at', now())
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
    -- KAN-128: a re-settle returns the same gs.id from the upsert above, so
    -- before this clause a second finalize posted a second identical credit for
    -- ('game_settlement', gs.id, 'credit'). Now it is absorbed.
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
      p_organiser_user_id,
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

-- ============================================================================
-- VERIFICATION -- run by backend-4 immediately after applying (G-028), posted
-- to KAN-138. That posting closes G-002 condition 4.
-- ============================================================================
-- AC1  The cast is present in the live body:
--        SELECT prosrc ILIKE '%::public.settlement_status%' FROM pg_proc
--         WHERE oid = 'public.settle_game(uuid,uuid,text,numeric,boolean)'::regprocedure;
--        -> true
--
-- AC2  THE CRITERION. Re-run the probe block quoted above.
--        BEFORE (recorded 2026-09-07): 42804 "column status is of type
--          settlement_status but expression is of type text", at line 39.
--        AFTER (required): PROBE_RESULT=SETTLE_GAME_SUCCEEDED with a settlement
--          id -- meaning execution passed the game_settlements insert AND the
--          wallet_ledger credit insert and returned. Still nothing committed.
--        A green CREATE OR REPLACE does NOT satisfy this criterion.
--        Then confirm nothing persisted:
--          SELECT count(*) FROM public.game_settlements; -> 0
--          SELECT count(*) FROM public.wallet_ledger;    -> 0
--
-- AC3  KAN-128's P3 re-settle probe becomes demonstrable. Not re-specified
--      here; cited on KAN-128 as blocked-until-this-ticket. Note for whoever
--      runs it: calling settle_game twice inside one probe block exercises both
--      the `on conflict (game_id) do update` upsert and the wallet_ledger
--      `on conflict do nothing`, which is the double-credit check.
--
-- AC4  Attributes unchanged -- assert, do not assume:
--        SELECT prosecdef, provolatile, array_to_string(proconfig,', ')
--          FROM pg_proc
--         WHERE oid = 'public.settle_game(uuid,uuid,text,numeric,boolean)'::regprocedure;
--        -> prosecdef = true, provolatile = 'v', search_path=public
--           (NOT 'public, pg_temp' -- this function's path is 'public' alone)
--
-- AC5  No DROP was performed, so grants must be untouched. Assert the ACL
--      itself rather than the absence of a revoke:
--        SELECT array_to_string(proacl,' | ') FROM pg_proc
--         WHERE oid = 'public.settle_game(uuid,uuid,text,numeric,boolean)'::regprocedure;
--        -> {=X/postgres, postgres=X/postgres, anon=X/postgres,
--            authenticated=X/postgres, service_role=X/postgres} -- UNCHANGED
--
--      Also re-confirm KAN-128's clauses survived this replacement:
--        SELECT prosrc ILIKE '%on conflict (game_id) do update%'
--             , prosrc ILIKE '%on conflict do nothing%'
--          FROM pg_proc WHERE oid = 'public.settle_game(...)'::regprocedure;
--        -> true, true.  If either is false, this migration reverted KAN-128.
