-- KAN-173 probe pack — `_wallet_recalc` owner_id fix.
-- Migration version 20260910171433 (kan173_wallet_recalc_owner_id).
--
-- WHY THESE PROBES LOOK LIKE THIS. `wallets` and `wallet_ledger` both hold 0 rows, so a
-- probe that returns "no error" proves nothing. The evidence is THE IDENTITY OF THE ERROR,
-- flipping across the apply: 23502 before, P0001 (our own deliberate abort) after. Both
-- states are errors; the flip is the proof.
--
-- MONEY-PATH CONSTRAINT: no persistent rows. Every probe is a DO block ending in RAISE, so
-- the transaction aborts and nothing commits. Verified after the pack: wallets,
-- wallet_ledger, payouts, payout_beneficiaries and game_settlements all back at 0.
-- Disclosed, not discovered: `wallet_ledger_id_seq` DOES advance (sequences are
-- non-transactional; last_value 9 after this pack). Harmless. The probes reference REAL
-- `auth.users` ids because the FK admits nothing else — read-only reference, aborted
-- write, no user row mutated.
--
-- RUN AS `postgres`. This is a PRECONDITION, not an incidental. `_wallet_recalc` is
-- SECURITY INVOKER and anon/authenticated hold SELECT ONLY on `wallets`, so the same probe
-- run as `authenticated` returns 42501, not 23502 — a different error that would misreport
-- where the defect is.

-- ===========================================================================
-- P0 — VOID-THE-PACK PRECONDITION. If any row is wrong, nothing below counts.
-- Check the target path can execute at all before trusting a probe (T-055).
-- ===========================================================================
select
  current_user::text                                                           as running_role,          -- expect postgres
  (select prosecdef  from pg_proc where oid='public._wallet_recalc(uuid)'::regprocedure) as secdef,      -- expect false (INVOKER)
  (select proconfig::text from pg_proc where oid='public._wallet_recalc(uuid)'::regprocedure) as config, -- expect {"search_path=public, pg_temp"}
  (select proacl::text from pg_proc where oid='public._wallet_recalc(uuid)'::regprocedure)  as acl,
  (select tgenabled from pg_trigger where tgname='trg_wallet_ledger_recalc')   as trigger_enabled,       -- expect O
  (select is_nullable  from information_schema.columns
     where table_schema='public' and table_name='wallets' and column_name='owner_id') as owner_id_nullable, -- expect NO
  (select column_default from information_schema.columns
     where table_schema='public' and table_name='wallets' and column_name='owner_id') as owner_id_default,  -- expect NULL
  (select count(*) from public.wallets)       as wallets_rows,   -- expect 0
  (select count(*) from public.wallet_ledger) as ledger_rows;    -- expect 0

-- proacl must be IDENTICAL before and after. CREATE OR REPLACE preserves it; the KAN-128
-- DROP+CREATE trap (pg_default_acl re-granting anon BY NAME) does not apply here.
-- Measured both sides:
--   {=X/postgres,postgres=X/postgres,anon=X/postgres,authenticated=X/postgres,service_role=X/postgres}

-- ===========================================================================
-- P1 — THE DEFECT AND THE FLIP.
--   PRE  expect: 23502, null value in column "owner_id" of relation "wallets"
--   POST expect: P0001 PROBE_REACHED_END
-- Anything else on the PRE side (including reaching our raise) fails the precondition:
-- it would mean the defect is not where we think.
-- ===========================================================================
do $$
declare u uuid;
begin
  select id into u from auth.users order by id limit 1;
  insert into public.wallet_ledger(user_id, direction, amount_aed, status, ref_type, ref_id, memo)
  values (u, 'credit', 10.00, 'posted', 'kan173_probe', gen_random_uuid(), 'KAN-173 P1');
  raise exception using errcode='P0001', message='PROBE_REACHED_END';
end $$;
-- PRE  RESULT: 23502 owner_id. CONTEXT _wallet_recalc line 17 <- _wallet_after_ledger
--              line 3 <- inline_code_block line 5. DETAIL showed owner_type AND owner_id
--              both null — the two columns the fix supplies.
-- POST RESULT: P0001 PROBE_REACHED_END.  ** THE FLIP. **

-- ===========================================================================
-- P2 (DO-UPDATE branch recomputes — AC-3 / T-049 Invariant 3) + P3 (new columns written).
-- P1 only ever exercises the INSERT branch, because 0 rows means every write is a first
-- write. P2 forces the DO UPDATE by writing three ledger rows for one user.
--   POST expect: P0001 PROBE_REACHED_END ... balance=35.00 held=-4.00 rows=1
-- ===========================================================================
do $$
declare u uuid; w public.wallets; n int;
begin
  select id into u from auth.users order by id limit 1;

  insert into public.wallet_ledger(user_id,direction,amount_aed,status,ref_type,ref_id,memo)
  values (u,'credit',10.00,'posted','kan173_probe',gen_random_uuid(),'P2a');

  select * into w from public.wallets where user_id=u;
  if w.owner_type is distinct from 'user' then raise exception using errcode='P0001', message='P3_FAIL owner_type='||coalesce(w.owner_type,'<null>'); end if;
  if w.owner_id  is distinct from u      then raise exception using errcode='P0001', message='P3_FAIL owner_id'; end if;
  if w.currency  is distinct from 'AED'  then raise exception using errcode='P0001', message='P3_FAIL currency='||coalesce(w.currency,'<null>'); end if;
  if w.balance_aed <> 10.00 then raise exception using errcode='P0001', message='P2_FAIL first balance='||w.balance_aed; end if;

  insert into public.wallet_ledger(user_id,direction,amount_aed,status,ref_type,ref_id,memo)
  values (u,'credit',25.00,'posted','kan173_probe',gen_random_uuid(),'P2b');
  insert into public.wallet_ledger(user_id,direction,amount_aed,status,ref_type,ref_id,memo)
  values (u,'debit',4.00,'pending','kan173_probe',gen_random_uuid(),'P2c');

  select * into w from public.wallets where user_id=u;
  select count(*) into n from public.wallets;

  -- rows=1 is the assertion that DO UPDATE fired rather than a duplicate INSERT.
  if n <> 1 then raise exception using errcode='P0001', message='P2_FAIL wallets rowcount='||n||' (DO UPDATE did not fire)'; end if;
  -- 35.00 = 10 + 25 recomputed from the ledger, NOT incremented. T-049 Invariant 3.
  if w.balance_aed <> 35.00 then raise exception using errcode='P0001', message='P2_FAIL recompute balance='||w.balance_aed; end if;
  if w.held_aed <> -4.00 then raise exception using errcode='P0001', message='P2_FAIL held='||w.held_aed; end if;

  raise exception using errcode='P0001',
    message='PROBE_REACHED_END P2/P3 OK balance='||w.balance_aed||' held='||w.held_aed||' rows='||n||' owner_id=user_id';
end $$;
-- POST RESULT: P0001 PROBE_REACHED_END P2/P3 OK balance=35.00 held=-4.00 rows=1 owner_id=user_id
-- NOTE on the held sign: a pending DEBIT recomputes to a NEGATIVE held_aed. That is the
-- pre-existing semantics of this function (request_payout books a hold as a pending
-- debit), unchanged by KAN-173. Recorded as an observation, not a defect fixed here.

-- ===========================================================================
-- P4 — DELIBERATE NEGATIVE CASE. The limit `cto` asked be VERIFIED, not inherited.
-- `ON CONFLICT (user_id)` binds `wallets_pkey` ONLY. Construct a row where
-- owner_id <> user_id and the arbiter misses it.
--   POST expect: 23505 on wallets_unique_idx  (this probe PASSES by failing)
-- ===========================================================================
do $$
declare a uuid; b uuid;
begin
  select id into a from auth.users order by id limit 1;
  select id into b from auth.users order by id desc limit 1;
  insert into public.wallets(user_id, owner_type, owner_id, balance_aed, held_aed)
  values (a, 'user', b, 0, 0);
  perform public._wallet_recalc(b);
  raise exception using errcode='P0001', message='P4_UNEXPECTED_no_conflict';
end $$;
-- POST RESULT: 23505 duplicate key value violates unique constraint "wallets_unique_idx"
--   DETAIL: Key (owner_type, owner_id, currency)=(user, ff8e1b42-..., AED) already exists.
--   CONTEXT: _wallet_recalc(uuid) line 20
-- CONCLUSION: the ruled ON CONFLICT is safe under an UNENFORCED invariant
-- (owner_id = user_id), held only because this function is the sole writer producing it.
-- Unreachable today. A documented limit, not a blocker. KAN-130 must not assume it free.

-- ===========================================================================
-- P6 — THE HALF-PATH. `fn_get_wallet`'s mirror defect, NOT fixed by KAN-173.
--   PRE and POST expect: IDENTICAL 23502 on "user_id"
-- This is what stops the wallet path being reported as closed (ticket AC scope boundary).
-- ===========================================================================
do $$
begin
  perform public.fn_get_wallet('venue', gen_random_uuid(), 'AED');
  raise exception using errcode='P0001', message='PROBE_REACHED_END';
end $$;
-- PRE  RESULT: 23502 null value in column "user_id" of relation "wallets"
--              CONTEXT fn_get_wallet(text,uuid,text) line 13
-- POST RESULT: IDENTICAL. Unchanged by this migration, exactly as intended.

-- ===========================================================================
-- AC-2 — ALL FOUR CALLERS, END TO END, REAL ENTRY POINTS, TRIGGER ENABLED.
-- auth.uid() reads request.jwt.claims (verified live), so set_config drives each
-- function's OWN authorization gate properly rather than bypassing it. One chained
-- aborted transaction, because the callers depend on each other's state:
--   admin_wallet_adjust -> creates the wallet
--   settle_game         -> independent credit
--   request_payout      -> needs a funded wallet + a default beneficiary
--   admin_cancel_payout -> needs that payout; fires the trigger on UPDATE, not INSERT
-- ===========================================================================
do $$
declare
  v_admin uuid := '2d7024f7-198a-45aa-a64d-f52916b6b6c1';  -- the one role_grants admin
  v_user  uuid := 'ec959ff7-46ef-4bf2-aab4-3515b81f5846';  -- a real game creator
  v_game  uuid := 'cf04fdbb-77eb-42e9-a050-d18f7ff22592';
  w public.wallets; po public.payouts; ben uuid; n int;
  r1 numeric; r2 numeric; r3 numeric; r4 numeric;
begin
  perform set_config('request.jwt.claims', json_build_object('sub',v_admin,'role','authenticated')::text, true);
  perform public.admin_wallet_adjust(v_user,'credit',100.00,gen_random_uuid(),'KAN-173 AC2 adjust');
  select * into w from public.wallets where user_id=v_user;
  if w.user_id  is null then raise exception using errcode='P0001', message='AC2_FAIL adjust: no wallet row'; end if;
  if w.owner_id is null then raise exception using errcode='P0001', message='AC2_FAIL adjust: owner_id NULL'; end if;
  r1 := w.balance_aed;

  perform public.settle_game(v_game, v_user, 'padel', 200.00, true);
  select * into w from public.wallets where user_id=v_user;
  if w.owner_id is null then raise exception using errcode='P0001', message='AC2_FAIL settle: owner_id NULL'; end if;
  r2 := w.balance_aed;
  if r2 <= r1 then raise exception using errcode='P0001', message='AC2_FAIL settle did not credit: '||r1||' -> '||r2; end if;

  insert into public.payout_beneficiaries(user_id,destination,details,is_default,is_verified)
  values (v_user,'bank','{"iban":"KAN173-PROBE"}'::jsonb,true,true) returning id into ben;
  perform set_config('request.jwt.claims', json_build_object('sub',v_user,'role','authenticated')::text, true);
  po := public.request_payout(50.00, ben);
  select * into w from public.wallets where user_id=v_user;
  if w.owner_id is null then raise exception using errcode='P0001', message='AC2_FAIL payout: owner_id NULL'; end if;
  r3 := w.held_aed;

  perform set_config('request.jwt.claims', json_build_object('sub',v_admin,'role','authenticated')::text, true);
  perform public.admin_cancel_payout(po.id,'KAN-173 AC2 probe');
  select * into w from public.wallets where user_id=v_user;
  if w.owner_id is null then raise exception using errcode='P0001', message='AC2_FAIL cancel: owner_id NULL'; end if;
  r4 := w.held_aed;

  select count(*) into n from public.wallets;
  raise exception using errcode='P0001', message=
    'PROBE_REACHED_END AC2 ALL FOUR OK | wallets_rows='||n
    ||' | owner_id='||w.owner_id||' user_id='||w.user_id||' owner_type='||w.owner_type
    ||' | bal adjust='||r1||' settle='||r2||' final='||w.balance_aed
    ||' | held afterPayout='||r3||' afterCancel='||r4;
end $$;
-- POST RESULT: P0001 PROBE_REACHED_END AC2 ALL FOUR OK | wallets_rows=1
--   | owner_id=ec959ff7-... user_id=ec959ff7-... owner_type=user
--   | bal adjust=100.00 settle=280.00 final=280.00
--   | held afterPayout=-50.00 afterCancel=0.00
-- Reading: adjust created the wallet (100); settle_game credited 180 earnings on 200 gross
-- at a 20.00 fee (280); request_payout booked a 50 hold (held -50.00); admin_cancel_payout
-- voided it via UPDATE and the trigger recomputed held back to 0.00. All four callers
-- completed a wallet_ledger write and the resulting wallets row carried a non-null
-- owner_id. PRE-fix this block cannot run at all — it dies at the first caller on 23502.

-- ===========================================================================
-- CLOSING ASSERTION — nothing committed.
-- ===========================================================================
select (select count(*) from public.wallets)              as wallets,               -- expect 0
       (select count(*) from public.wallet_ledger)        as wallet_ledger,         -- expect 0
       (select count(*) from public.payouts)              as payouts,               -- expect 0
       (select count(*) from public.payout_beneficiaries) as beneficiaries,         -- expect 0
       (select count(*) from public.game_settlements)     as game_settlements,      -- expect 0
       (select last_value from public.wallet_ledger_id_seq) as ledger_seq;          -- advances; non-transactional
-- RESULT: 0, 0, 0, 0, 0, seq=9.
