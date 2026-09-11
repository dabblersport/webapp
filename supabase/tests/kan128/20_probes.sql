-- ============================================================================
-- KAN-128 AC 3 — probe pack. Run UNCHANGED before and after the migration.
-- Every probe prints an OBSERVED value and the EXPECTED value for each side, so
-- the pre-run failure and the post-run pass are read from the same output.
-- ROWS ONLY: no probe creates a relation (cto, T-055 addendum).
-- ============================================================================
set client_min_messages to notice;
\set ORGANISER '11111111-1111-1111-1111-111111111111'
\set ADMIN     '22222222-2222-2222-2222-222222222222'
\set GAME      '77777777-7777-7777-7777-777777777777'

-- Clean slate between runs (rows only). The recalc trigger fires on DELETE as
-- well as INSERT, and is defective (see P0), so the cleanup is blocked too --
-- hence the disable/enable bracket here. It is restored before P0 runs, so P0
-- still measures the schema as deployed.
alter table public.wallet_ledger disable trigger trg_wallet_ledger_recalc;
delete from public.wallet_ledger;
alter table public.wallet_ledger enable trigger trg_wallet_ledger_recalc;
delete from public.financial_ledger;
delete from public.game_settlements;
delete from public.payouts;
delete from public.payout_beneficiaries;
delete from public.role_grants where user_id = :'ADMIN';
insert into public.roles(role) values ('admin') on conflict do nothing;
insert into public.role_grants(user_id, role) values (:'ADMIN','admin');

-- REQUIRED FIXTURE, and itself a finding (see the KAN-128 report):
-- trg_wallet_ledger_recalc fires _wallet_recalc on EVERY wallet_ledger write,
-- and _wallet_recalc's upsert omits wallets.owner_id, which is NOT NULL with no
-- default. So on the deployed schema NO wallet_ledger insert can succeed unless
-- a wallets row for that user already exists -- and wallets holds 0 rows.
-- This is a row, not a relation. It is the minimum that makes any wallet_ledger
-- writer executable at all, and it is KAN-130/T-051's territory to fix.
insert into public.wallets(user_id, owner_type, owner_id, currency, balance_aed, held_aed)
  values (:'ORGANISER','user', :'ORGANISER', 'AED', 0, 0)
  on conflict (user_id) do update set balance_aed = 0, held_aed = 0;

-- P0 -- FALSIFIABILITY CONDITION 3, applied first: can the target path execute?
-- Answer for every wallet_ledger probe below: NO, and no fixture fixes it.
-- Postgres enforces NOT NULL during tuple formation, BEFORE the ON CONFLICT
-- arbiter is consulted, so _wallet_recalc's upsert dies on owner_id even when a
-- wallets row for that user already exists. Demonstrated, not argued:
\echo ''
\echo '=== P0  can a wallet_ledger row be written AT ALL on the deployed schema?'
\echo '    EXPECT: no -- error 23502 on wallets.owner_id, via trg_wallet_ledger_recalc'
do $$
declare msg text;
begin
  insert into public.wallet_ledger(user_id, direction, amount_aed, status, ref_type, ref_id, memo)
    values ('11111111-1111-1111-1111-111111111111','credit', 1, 'posted','p0', gen_random_uuid(), 'p0');
  raise notice 'P0 OBSERVED: write SUCCEEDED -- the recalc defect is gone, re-read this report';
exception when others then
  get stacked diagnostics msg = message_text;
  raise notice 'P0 OBSERVED: write BLOCKED (%) -- %', sqlstate, msg;
  raise notice 'P0 CONSEQUENCE: probes P1-P4 cannot run against the schema as deployed.';
end $$;

-- HARNESS DEVIATION, declared. Everything below this line runs with
-- trg_wallet_ledger_recalc disabled. This is the ONLY way to exercise the
-- wallet_ledger key at all, and it is a deviation from "the schema as deployed"
-- (falsifiability condition 2). It is safe for what is being tested: the recalc
-- trigger recomputes wallets.balance_aed and has no bearing on whether a UNIQUE
-- index on wallet_ledger holds. It is declared rather than hidden because the
-- result is weaker than an unqualified pass, and a reader must know that.
alter table public.wallet_ledger disable trigger trg_wallet_ledger_recalc;

\echo ''
\echo '=== P1  wallet_ledger: duplicate (ref_type, ref_id, direction) ==========='
\echo '--- P1a  raw duplicate inserts (is the KEY enforced at all?)'
\echo '    pre-migration EXPECT rows=2 (probe FAILS: no index)'
\echo '    post-migration EXPECT error 23505 on the second (probe PASSES)'
do $$
declare k uuid := '0a000000-0000-0000-0000-00000000a001'::uuid; n int;
begin
  insert into public.wallet_ledger(user_id, direction, amount_aed, status, ref_type, ref_id, memo)
    values ('11111111-1111-1111-1111-111111111111','credit', 10, 'posted','probe', k, 'first');
  begin
    insert into public.wallet_ledger(user_id, direction, amount_aed, status, ref_type, ref_id, memo)
      values ('11111111-1111-1111-1111-111111111111','credit', 10, 'posted','probe', k, 'second');
  exception when unique_violation then
    raise notice 'P1a OBSERVED: second insert rejected, sqlstate 23505';
  end;
  select count(*) into n from public.wallet_ledger where ref_id = k;
  raise notice 'P1a OBSERVED: rows for key = %  (pre EXPECT 2 / post EXPECT 1)', n;
end $$;

\echo ''
\echo '--- P1b  the same duplicate through a WRITER (is it CONFLICT-HANDLED,'
\echo '         i.e. absorbed silently rather than raising?)'
\echo '    pre-migration EXPECT rows=2, no error (probe FAILS)'
\echo '    post-migration EXPECT rows=1, no error (probe PASSES)'
do $$
declare k uuid := '0b000000-0000-0000-0000-00000000b001'::uuid; n int; msg text;
begin
  perform set_config('request.jwt.claim.sub','22222222-2222-2222-2222-222222222222', true);
  begin
    -- Signature differs pre/post: pre-migration there is no p_ref_id, so the
    -- pre-run exercises the 5-arg form and shows it writing ref_id = NULL,
    -- which is exactly the hole T-049 closed.
    if exists (select 1 from pg_proc p join pg_namespace n2 on n2.oid=p.pronamespace
               where n2.nspname='public' and p.proname='admin_wallet_adjust' and p.pronargs=6) then
      perform public.admin_wallet_adjust('11111111-1111-1111-1111-111111111111','credit', 5, k, 'adj', '{}'::jsonb);
      perform public.admin_wallet_adjust('11111111-1111-1111-1111-111111111111','credit', 5, k, 'adj', '{}'::jsonb);
      select count(*) into n from public.wallet_ledger where ref_id = k;
      raise notice 'P1b OBSERVED: 6-arg admin_wallet_adjust x2 same ref_id -> rows = %  (post EXPECT 1)', n;
    else
      perform public.admin_wallet_adjust('11111111-1111-1111-1111-111111111111','credit', 5, 'adj', '{}'::jsonb);
      perform public.admin_wallet_adjust('11111111-1111-1111-1111-111111111111','credit', 5, 'adj', '{}'::jsonb);
      select count(*) into n from public.wallet_ledger where ref_type='adjustment' and ref_id is null;
      raise notice 'P1b OBSERVED: 5-arg admin_wallet_adjust x2 -> rows with ref_id NULL = %  (pre EXPECT 2)', n;
    end if;
  exception when others then
    get stacked diagnostics msg = message_text;
    raise notice 'P1b OBSERVED: unexpected error: % (%)', msg, sqlstate;
  end;
end $$;

\echo ''
\echo '=== P2  compensating reversal: same (ref_type, ref_id), OPPOSITE direction'
\echo '    must SUCCEED on both sides — this probe guards against a fix that'
\echo '    breaks the one reversal path already doing the right thing (T-049 Inv 2)'
\echo '    pre EXPECT 2 rows / post EXPECT 2 rows'
do $$
declare k uuid := '0c000000-0000-0000-0000-00000000c001'::uuid; n int; msg text;
begin
  begin
    insert into public.wallet_ledger(user_id, direction, amount_aed, status, ref_type, ref_id, memo)
      values ('11111111-1111-1111-1111-111111111111','debit', 20, 'posted','payout', k, 'hold');
    insert into public.wallet_ledger(user_id, direction, amount_aed, status, ref_type, ref_id, memo)
      values ('11111111-1111-1111-1111-111111111111','credit', 20, 'posted','payout', k, 'reversal');
  exception when others then
    get stacked diagnostics msg = message_text;
    raise notice 'P2 OBSERVED: REGRESSION — reversal rejected: % (%)', msg, sqlstate;
  end;
  select count(*) into n from public.wallet_ledger where ref_id = k;
  raise notice 'P2 OBSERVED: rows for key = %  (pre AND post EXPECT 2)', n;
end $$;

\echo ''
\echo '=== P3  settle_game re-settle: the one LIVE duplicate this migration fixes'
\echo '    pre EXPECT 2 credit rows for the same gs.id (probe FAILS)'
\echo '    post EXPECT 1 credit row (probe PASSES)'
do $$
declare gs public.game_settlements; n int; refs int; msg text;
begin
  perform set_config('request.jwt.claim.sub','11111111-1111-1111-1111-111111111111', true);
  begin
    gs := public.settle_game('77777777-7777-7777-7777-777777777777',
                             '11111111-1111-1111-1111-111111111111','kan128_sport', 100, true);
    gs := public.settle_game('77777777-7777-7777-7777-777777777777',
                             '11111111-1111-1111-1111-111111111111','kan128_sport', 100, true);
    select count(*) into n from public.wallet_ledger
      where ref_type='game_settlement' and ref_id = gs.id and direction='credit';
    select count(distinct ref_id) into refs from public.wallet_ledger where ref_type='game_settlement';
    raise notice 'P3 OBSERVED: credit rows for settlement % = %  (pre EXPECT 2 / post EXPECT 1); distinct settlement ref_ids = %', gs.id, n, refs;
  exception when others then
    get stacked diagnostics msg = message_text;
    raise notice 'P3 OBSERVED: settle_game CANNOT EXECUTE (%) -- %', sqlstate, msg;
    raise notice 'P3 CONSEQUENCE: falsifiability condition 3 fails for this probe on BOTH sides.';
  end;
end $$;

\echo ''
\echo '=== P4  admin_wallet_adjust: the new caller-supplied ref_id'
\echo '    pre EXPECT the 6-arg form ABSENT and adjustments writing ref_id NULL'
\echo '    post EXPECT distinct non-null key per call, and NO 5-arg overload left'
do $$
declare k1 uuid := gen_random_uuid(); k2 uuid := gen_random_uuid();
        n1 int; n2 int; nulls int; arities text;
begin
  perform set_config('request.jwt.claim.sub','22222222-2222-2222-2222-222222222222', true);
  select string_agg(p.pronargs::text, ',' order by p.pronargs) into arities
    from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public' and p.proname='admin_wallet_adjust';
  raise notice 'P4 OBSERVED: admin_wallet_adjust arities present = %  (pre EXPECT 5 / post EXPECT 6, and 6 ONLY)', arities;

  if arities = '6' then
    perform public.admin_wallet_adjust('11111111-1111-1111-1111-111111111111','credit', 7, k1, 'a1', '{}'::jsonb);
    perform public.admin_wallet_adjust('11111111-1111-1111-1111-111111111111','credit', 7, k2, 'a2', '{}'::jsonb);
    select count(*) into n1 from public.wallet_ledger where ref_id = k1;
    select count(*) into n2 from public.wallet_ledger where ref_id = k2;
    raise notice 'P4 OBSERVED: two DISTINCT keys -> rows %, %  (post EXPECT 1, 1 — distinct keys are not collapsed)', n1, n2;
    begin
      perform public.admin_wallet_adjust('11111111-1111-1111-1111-111111111111','credit', 7, null, 'a3', '{}'::jsonb);
      raise notice 'P4 OBSERVED: null ref_id ACCEPTED — WRONG';
    exception when others then
      raise notice 'P4 OBSERVED: null ref_id rejected (%), as ruled', sqlstate;
    end;
  else
    select count(*) into nulls from public.wallet_ledger where ref_type='adjustment' and ref_id is null;
    raise notice 'P4 OBSERVED: adjustment rows with ref_id NULL = %  (pre EXPECT > 0 — the hole T-049 closed)', nulls;
  end if;
end $$;

\echo ''
\echo '=== P5  financial_ledger: two direct inserts sharing'
\echo '        (payment_intent_id, entity_type, entry_type)'
\echo '    NOT through trgfn_payment_to_ledger — that path is dead (T-055) and'
\echo '    its EXISTS guard would absorb a sequential call and prove nothing.'
\echo '    pre EXPECT 2 rows (probe FAILS) / post EXPECT 1 (probe PASSES)'
do $$
declare pi uuid := gen_random_uuid(); n int;
begin
  insert into public.financial_ledger(entity_type, entity_id, booking_id, payment_intent_id,
                                      entry_type, amount, currency, reason)
    values ('user','11111111-1111-1111-1111-111111111111', null, pi, 'debit', 50, 'AED', 'booking_payment');
  begin
    insert into public.financial_ledger(entity_type, entity_id, booking_id, payment_intent_id,
                                        entry_type, amount, currency, reason)
      values ('user','11111111-1111-1111-1111-111111111111', null, pi, 'debit', 50, 'AED', 'booking_payment')
      on conflict do nothing;
  exception when others then
    raise notice 'P5 OBSERVED: unexpected error %', sqlstate;
  end;
  select count(*) into n from public.financial_ledger where payment_intent_id = pi;
  raise notice 'P5 OBSERVED: rows for key = %  (pre EXPECT 2 / post EXPECT 1)', n;

  -- The partial index must NOT collapse rows whose payment_intent_id is NULL.
  insert into public.financial_ledger(entity_type, entity_id, booking_id, payment_intent_id,
                                      entry_type, amount, currency, reason)
    values ('user','11111111-1111-1111-1111-111111111111', null, null, 'debit', 1, 'AED', 'adjustment');
  insert into public.financial_ledger(entity_type, entity_id, booking_id, payment_intent_id,
                                      entry_type, amount, currency, reason)
    values ('user','11111111-1111-1111-1111-111111111111', null, null, 'debit', 1, 'AED', 'adjustment');
  select count(*) into n from public.financial_ledger where payment_intent_id is null;
  raise notice 'P5b OBSERVED: NULL-payment_intent rows = %  (pre AND post EXPECT 2 — partial index must not collapse these)', n;
end $$;

\echo ''
\echo '=== CATALOGUE ASSERTIONS ==================================================='
select 'index' as kind, indexname as name, indexdef as detail
from pg_indexes where schemaname='public'
  and indexname in ('wallet_ledger_ref_key_unique','financial_ledger_payment_entry_unique')
union all
select 'ref_id notnull', 'wallet_ledger.ref_id', attnotnull::text
from pg_attribute where attrelid='public.wallet_ledger'::regclass and attname='ref_id'
union all
select 'function', p.proname||'('||pg_get_function_identity_arguments(p.oid)||')',
       'secdef='||p.prosecdef||' cfg='||coalesce(p.proconfig::text,'-')||' acl='||coalesce(p.proacl::text,'(default: PUBLIC)')
from pg_proc p join pg_namespace n on n.oid=p.pronamespace
where n.nspname='public' and p.proname in ('admin_cancel_payout','admin_wallet_adjust','request_payout','settle_game','trgfn_payment_to_ledger')
order by 1,2;

\echo ''
\echo '--- harness deviation ends'
alter table public.wallet_ledger enable trigger trg_wallet_ledger_recalc;
