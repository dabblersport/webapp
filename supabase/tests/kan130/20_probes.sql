-- ============================================================================
-- KAN-130 — probe pack. Run UNCHANGED before and after the migration.
--
-- Every probe prints an OBSERVED value and the EXPECTED value for BOTH sides,
-- so the pre-run failure and the post-run pass are read from the same output.
-- A probe nobody has seen fail is not evidence, so this file is designed to be
-- run twice and judged on the DIFFERENCE.
--
-- FALSIFIABILITY CONDITION 3 IS APPLIED FIRST, EVERY TIME (T-055 / T-058):
-- before a probe is allowed to count, the target path must be shown capable of
-- executing at all. P0 does this for the whole pack; each probe that depends on
-- an upstream path re-states it. KAN-128's pack found a function that raised
-- before reaching the code under test; that is the failure mode this ordering
-- exists to prevent.
--
-- ROWS ONLY: no probe creates a relation.
--
-- THE RECALC TRIGGER IS NOT DISABLED FOR P2 OR P3. KAN-128's pack had to
-- disable it and declared that as a weakening; T-058 Decision 4 makes a
-- trigger-ENABLED, end-to-end wallet_ledger write a MANDATORY criterion of this
-- ticket, so P2 asserts the trigger is enabled before it writes and the pass is
-- void without that assertion.
-- ============================================================================
set client_min_messages to notice;
\set A     'a1111111-1111-1111-1111-111111111111'
\set B     'b2222222-2222-2222-2222-222222222222'
\set VENUE 'c3333333-3333-3333-3333-333333333333'
\set PLAT  '00000000-0000-0000-0000-000000000000'

-- ---------------------------------------------------------------------------
-- Clean slate between runs (rows only).
-- The recalc trigger fires on DELETE as well as INSERT and is defective before
-- the migration, so the cleanup itself is blocked pre-run — hence the
-- disable/enable bracket. It is restored immediately, BEFORE P0 runs, so every
-- probe below measures the schema exactly as it stands.
-- ---------------------------------------------------------------------------
alter table public.wallet_ledger disable trigger trg_wallet_ledger_recalc;
delete from public.wallet_ledger;
alter table public.wallet_ledger enable trigger trg_wallet_ledger_recalc;
delete from public.financial_ledger;
delete from public.payouts;
delete from public.payout_beneficiaries;
delete from public.wallets;

\echo ''
\echo '=== P0  FALSIFIABILITY CONDITION 3 — what shape is wallets in right now? ==='
\echo '    pre  EXPECT: user_id present+NOT NULL, id NULLABLE, owner_type NULLABLE,'
\echo '                 pkey=(user_id), wallets_user_id_fkey PRESENT'
\echo '    post EXPECT: user_id ABSENT, id NOT NULL, owner_type NOT NULL,'
\echo '                 pkey=(id), wallets_user_id_fkey ABSENT'
do $$
declare
  has_user_id bool; id_nn bool; ot_nn bool; pk text; fk bool; trig char;
begin
  select exists(select 1 from pg_attribute
                where attrelid='public.wallets'::regclass and attname='user_id'
                  and attnum>0 and not attisdropped) into has_user_id;
  select attnotnull into id_nn from pg_attribute
    where attrelid='public.wallets'::regclass and attname='id';
  select attnotnull into ot_nn from pg_attribute
    where attrelid='public.wallets'::regclass and attname='owner_type';
  select coalesce(pg_get_constraintdef(oid),'(none)') into pk from pg_constraint
    where conrelid='public.wallets'::regclass and contype='p';
  select exists(select 1 from pg_constraint
                where conrelid='public.wallets'::regclass and conname='wallets_user_id_fkey')
    into fk;
  select tgenabled into trig from pg_trigger
    where tgrelid='public.wallet_ledger'::regclass and tgname='trg_wallet_ledger_recalc';

  raise notice 'P0 OBSERVED: wallets.user_id present=%  id NOT NULL=%  owner_type NOT NULL=%',
    has_user_id, id_nn, ot_nn;
  raise notice 'P0 OBSERVED: primary key = %', pk;
  raise notice 'P0 OBSERVED: wallets_user_id_fkey present=%  (post EXPECT false)', fk;
  raise notice 'P0 OBSERVED: trg_wallet_ledger_recalc tgenabled=%  (EXPECT O on BOTH sides — if this is not O, P2 and P3 prove nothing)', trig;
end $$;

\echo ''
\echo '=== P1  fn_get_wallet(''venue'', <uuid>, ''AED'') on a ZERO-ROW wallets ====='
\echo '    This is the criterion in the ticket''s own Verification section, and it'
\echo '    is the whole point of the ruling: a venue id is not an auth.users id,'
\echo '    so no value of user_id could ever have made this call legal.'
\echo '    pre  EXPECT: error 23502 on wallets.user_id (probe FAILS)'
\echo '    post EXPECT: returns a uuid, exactly 1 row created (probe PASSES)'
do $$
declare w1 uuid; w2 uuid; n int; msg text;
begin
  begin
    w1 := public.fn_get_wallet('venue','c3333333-3333-3333-3333-333333333333','AED');
    -- Called a SECOND time with the same arguments: it must LOOK UP, not mint.
    -- A pass on the first call alone would not distinguish a working lookup
    -- from the fresh-uuid-per-call defect T-052 exists to fix.
    w2 := public.fn_get_wallet('venue','c3333333-3333-3333-3333-333333333333','AED');
    select count(*) into n from public.wallets where owner_type='venue';
    raise notice 'P1 OBSERVED: call1=%  call2=%  same=%  venue wallet rows=%  (post EXPECT same=true, rows=1)',
      w1, w2, (w1 = w2), n;
  exception when others then
    get stacked diagnostics msg = message_text;
    raise notice 'P1 OBSERVED: fn_get_wallet BLOCKED (%) -- %', sqlstate, msg;
    raise notice 'P1 CONSEQUENCE: no venue or platform wallet can exist at all on this schema.';
  end;
end $$;

\echo ''
\echo '=== P2  T-058 Decision 4 (MANDATORY): trigger-ENABLED, end-to-end =========='
\echo '    A wallet_ledger insert for a user with NO existing wallets row must'
\echo '    drive trg_wallet_ledger_recalc -> _wallet_recalc -> create that row.'
\echo '    owner_id is NOT NULL with no default and the NOT NULL check runs BEFORE'
\echo '    the ON CONFLICT arbiter, so an insert naming only the conflict target'
\echo '    still dies 23502. That is what this probe is looking for.'
\echo '    pre  EXPECT: error 23502 on wallets.owner_id, via the trigger (FAILS)'
\echo '    post EXPECT: ledger row written AND a (''user'', A, ''AED'') wallet exists (PASSES)'
do $$
declare trig char; n int; wn int; msg text;
begin
  select tgenabled into trig from pg_trigger
    where tgrelid='public.wallet_ledger'::regclass and tgname='trg_wallet_ledger_recalc';
  if trig is distinct from 'O' then
    raise notice 'P2 OBSERVED: VOID — trigger tgenabled=%, not O. This probe proves nothing.', trig;
    return;
  end if;
  raise notice 'P2 OBSERVED: precondition ok — trigger is ENABLED (tgenabled=O)';

  select count(*) into wn from public.wallets
    where owner_type='user' and owner_id='a1111111-1111-1111-1111-111111111111';
  raise notice 'P2 OBSERVED: wallets rows for user A BEFORE the write = %  (EXPECT 0 on both sides)', wn;

  begin
    insert into public.wallet_ledger(user_id, direction, amount_aed, status, ref_type, ref_id, memo)
      values ('a1111111-1111-1111-1111-111111111111','credit', 10, 'posted','probe',
              'd0000000-0000-0000-0000-000000000002'::uuid, 'p2 seed');
    select count(*) into n from public.wallet_ledger where ref_type='probe';
    select count(*) into wn from public.wallets
      where owner_type='user' and owner_id='a1111111-1111-1111-1111-111111111111';
    raise notice 'P2 OBSERVED: ledger rows=%  wallets rows for user A=%  (post EXPECT 1 and 1)', n, wn;
  exception when others then
    get stacked diagnostics msg = message_text;
    raise notice 'P2 OBSERVED: ledger write BLOCKED (%) -- %', sqlstate, msg;
    raise notice 'P2 CONSEQUENCE: EVERY wallet_ledger write in the product fails on this schema, and P3 cannot run.';
  end;
end $$;

\echo ''
\echo '=== P3  T-049 Invariant 3 — recompute, never increment (NO REGRESSION) ====='
\echo '    Adds a second posted credit and a pending debit on top of P2''s row,'
\echo '    then calls _wallet_recalc AGAIN directly. A recomputing function is'
\echo '    idempotent; an incrementing one doubles on the second call.'
\echo '    pre  EXPECT: cannot execute (P2 blocked)'
\echo '    post EXPECT: balance_aed=15, held_aed=-3, and UNCHANGED after re-run'
do $$
declare b numeric; h numeric; b2 numeric; h2 numeric; msg text;
begin
  begin
    insert into public.wallet_ledger(user_id, direction, amount_aed, status, ref_type, ref_id, memo)
      values ('a1111111-1111-1111-1111-111111111111','credit', 5, 'posted','probe',
              'd0000000-0000-0000-0000-000000000003'::uuid, 'p3 posted credit');
    insert into public.wallet_ledger(user_id, direction, amount_aed, status, ref_type, ref_id, memo)
      values ('a1111111-1111-1111-1111-111111111111','debit', 3, 'pending','probe',
              'd0000000-0000-0000-0000-000000000004'::uuid, 'p3 pending debit');

    select balance_aed, held_aed into b, h from public.wallets
      where owner_type='user' and owner_id='a1111111-1111-1111-1111-111111111111' and currency='AED';
    raise notice 'P3 OBSERVED: after ledger writes balance_aed=%  held_aed=%  (post EXPECT 15.00 and -3.00)', b, h;

    perform public._wallet_recalc('a1111111-1111-1111-1111-111111111111');
    select balance_aed, held_aed into b2, h2 from public.wallets
      where owner_type='user' and owner_id='a1111111-1111-1111-1111-111111111111' and currency='AED';
    raise notice 'P3 OBSERVED: after a REDUNDANT recalc balance_aed=%  held_aed=%  idempotent=%  (post EXPECT true)',
      b2, h2, (b = b2 and h = h2);

    if (select count(*) from public.wallets
        where owner_type='user' and owner_id='a1111111-1111-1111-1111-111111111111') <> 1 then
      raise notice 'P3 OBSERVED: REGRESSION — recalc minted a SECOND wallet for the same owner';
    end if;
  exception when others then
    get stacked diagnostics msg = message_text;
    raise notice 'P3 OBSERVED: CANNOT EXECUTE (%) -- %', sqlstate, msg;
  end;
end $$;

\echo ''
\echo '=== P4  wallets_self_read is owner-keyed, and RLS actually enforces it ====='
\echo '    Run as role `authenticated` — as the table owner RLS is bypassed and'
\echo '    this probe would pass vacuously on both sides.'
\echo '    The pre-run builds the case the old policy gets WRONG: a wallet whose'
\echo '    owner_id is A but whose user_id is B. A owns it and cannot see it.'
\echo '    pre  EXPECT: A sees 0 of its own wallets (probe FAILS)'
\echo '    post EXPECT: A sees exactly 1, and does NOT see the venue wallet (PASSES)'
do $$
declare has_user_id bool; seen int; seen_venue int; msg text;
begin
  select exists(select 1 from pg_attribute
                where attrelid='public.wallets'::regclass and attname='user_id'
                  and attnum>0 and not attisdropped) into has_user_id;

  if has_user_id then
    -- Pre-migration only. owner_id = A, user_id = B: legal today, and exactly
    -- the two-columns-one-fact state T-051 removes.
    delete from public.wallets;
    execute $q$insert into public.wallets(user_id, owner_type, owner_id, currency, balance_aed, held_aed)
              values ('b2222222-2222-2222-2222-222222222222','user',
                      'a1111111-1111-1111-1111-111111111111','AED', 99, 0)$q$;
  else
    delete from public.wallets;
    perform public.fn_get_wallet('user','a1111111-1111-1111-1111-111111111111','AED');
    perform public.fn_get_wallet('venue','c3333333-3333-3333-3333-333333333333','AED');
  end if;

  begin
    set local role authenticated;
    perform set_config('request.jwt.claim.sub','a1111111-1111-1111-1111-111111111111', true);
    perform set_config('request.jwt.claims',
      '{"sub":"a1111111-1111-1111-1111-111111111111","role":"authenticated"}', true);
    select count(*) into seen from public.wallets
      where owner_id = 'a1111111-1111-1111-1111-111111111111';
    select count(*) into seen_venue from public.wallets where owner_type = 'venue';
    reset role;
    raise notice 'P4 OBSERVED: as authenticated A — own wallets visible=%  (pre EXPECT 0 / post EXPECT 1)', seen;
    raise notice 'P4 OBSERVED: as authenticated A — venue wallets visible=%  (EXPECT 0 on BOTH sides)', seen_venue;
  exception when others then
    get stacked diagnostics msg = message_text;
    reset role;
    raise notice 'P4 OBSERVED: CANNOT EXECUTE (%) -- %', sqlstate, msg;
  end;
end $$;

\echo ''
\echo '=== P5  delete_my_account: the erasure guarantee survives the dropped FK ==='
\echo '    A.6 removes wallets_user_id_fkey ON DELETE CASCADE. Without A.9''s'
\echo '    explicit delete, account deletion would silently ORPHAN the wallet.'
\echo '    Two independent readings, because the outcome alone does not separate'
\echo '    them: pre-migration the cascade produces the same visible result.'
\echo '      P5a MECHANISM  pre EXPECT: FK present AND no wallets delete in the body'
\echo '                     post EXPECT: FK absent AND an explicit wallets delete'
\echo '      P5b OUTCOME    B deletes their account; A''s wallet must SURVIVE.'
\echo '                     pre EXPECT: A''s wallet is destroyed by B''s deletion (FAILS)'
\echo '                     post EXPECT: B''s wallet gone, A''s wallet intact (PASSES)'
do $$
declare fk bool; body_has_delete bool; a_left int; b_left int; users_left int;
        has_user_id bool; msg text;
begin
  select exists(select 1 from pg_constraint
                where conrelid='public.wallets'::regclass and conname='wallets_user_id_fkey') into fk;
  select prosrc ~* 'delete\s+from\s+public\.wallets' into body_has_delete
    from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public' and p.proname='delete_my_account';
  raise notice 'P5a OBSERVED: wallets_user_id_fkey present=%  explicit wallets delete in delete_my_account=%',
    fk, body_has_delete;
  raise notice 'P5a EXPECT:   pre (true, false) / post (false, true)';

  select exists(select 1 from pg_attribute
                where attrelid='public.wallets'::regclass and attname='user_id'
                  and attnum>0 and not attisdropped) into has_user_id;

  begin
    alter table public.wallet_ledger disable trigger trg_wallet_ledger_recalc;
    delete from public.wallet_ledger;
    alter table public.wallet_ledger enable trigger trg_wallet_ledger_recalc;
    delete from public.wallets;

    if has_user_id then
      -- A's wallet, but carrying B's user_id — the state the cascade keys on,
      -- and the reason the cascade was always wrong. Exactly ONE row: the
      -- pre-migration primary key is (user_id), so a second row for B would
      -- violate it and the probe would fail for an unrelated reason.
      execute $q$insert into public.wallets(user_id, owner_type, owner_id, currency, balance_aed, held_aed)
                 values ('b2222222-2222-2222-2222-222222222222','user',
                         'a1111111-1111-1111-1111-111111111111','AED', 42, 0)$q$;
    else
      perform public.fn_get_wallet('user','a1111111-1111-1111-1111-111111111111','AED');
      perform public.fn_get_wallet('user','b2222222-2222-2222-2222-222222222222','AED');
    end if;

    perform set_config('request.jwt.claim.sub','b2222222-2222-2222-2222-222222222222', true);
    perform set_config('request.jwt.claims',
      '{"sub":"b2222222-2222-2222-2222-222222222222","role":"authenticated"}', true);
    perform public.delete_my_account();

    select count(*) into a_left from public.wallets
      where owner_type='user' and owner_id='a1111111-1111-1111-1111-111111111111';
    select count(*) into b_left from public.wallets
      where owner_type='user' and owner_id='b2222222-2222-2222-2222-222222222222';
    select count(*) into users_left from auth.users
      where id='b2222222-2222-2222-2222-222222222222';
    raise notice 'P5b OBSERVED: after B deleted their account — A''s wallets=%  B''s wallets=%  B in auth.users=%',
      a_left, b_left, users_left;
    raise notice 'P5b EXPECT:   pre (0, 0, 0) — A''s wallet wrongly destroyed / post (1, 0, 0)';
  exception when others then
    get stacked diagnostics msg = message_text;
    raise notice 'P5b OBSERVED: CANNOT EXECUTE (%) -- %', sqlstate, msg;
  end;
end $$;

\echo ''
\echo '=== P6  request_payout reads the balance by OWNER, not by user_id =========='
\echo '    P6a MECHANISM  the body must no longer key on wallets.user_id — a column'
\echo '                   that does not exist after this migration.'
\echo '                   pre EXPECT: (true, false) / post EXPECT: (false, true)'
\echo '    P6b BEHAVIOUR  post only: 100 available -> 50 succeeds, 500 refuses.'
do $$
declare keys_user_id bool; keys_owner bool; scoped_currency bool;
        p public.payouts; msg text; has_user_id bool;
begin
  select prosrc ~* 'from\s+public\.wallets\s+where\s+user_id\s*=\s*me',
         prosrc ~* 'owner_type\s*=\s*''user''',
         prosrc ~* 'currency\s*=\s*''AED'''
    into keys_user_id, keys_owner, scoped_currency
    from pg_proc p2 join pg_namespace n on n.oid=p2.pronamespace
    where n.nspname='public' and p2.proname='request_payout';
  raise notice 'P6a OBSERVED: keys on wallets.user_id=%  keys on owner_type=''user''=%  scoped by currency=%',
    keys_user_id, keys_owner, scoped_currency;
  raise notice 'P6a EXPECT:   pre (true, false, false) / post (false, true, true)';
  raise notice 'P6a NOTE:     currency is part of the post-migration lookup because wallets_unique_idx';
  raise notice 'P6a NOTE:     is (owner_type, owner_id, currency) — owner alone is NOT single-row.';

  select exists(select 1 from pg_attribute
                where attrelid='public.wallets'::regclass and attname='user_id'
                  and attnum>0 and not attisdropped) into has_user_id;
  if has_user_id then
    raise notice 'P6b OBSERVED: skipped pre-migration — a payout against a wallet this schema cannot create is not a test.';
    return;
  end if;

  begin
    alter table public.wallet_ledger disable trigger trg_wallet_ledger_recalc;
    delete from public.wallet_ledger;
    alter table public.wallet_ledger enable trigger trg_wallet_ledger_recalc;
    delete from public.payouts;
    delete from public.payout_beneficiaries;
    delete from public.wallets;

    insert into public.payout_beneficiaries(user_id, destination, details, is_default, is_verified)
      values ('a1111111-1111-1111-1111-111111111111','bank','{"iban":"AE000"}'::jsonb, true, true);

    -- Fund the wallet through the real path, trigger enabled.
    insert into public.wallet_ledger(user_id, direction, amount_aed, status, ref_type, ref_id, memo)
      values ('a1111111-1111-1111-1111-111111111111','credit', 100, 'posted','probe',
              'd0000000-0000-0000-0000-000000000006'::uuid, 'p6 funding');

    perform set_config('request.jwt.claim.sub','a1111111-1111-1111-1111-111111111111', true);
    perform set_config('request.jwt.claims',
      '{"sub":"a1111111-1111-1111-1111-111111111111","role":"authenticated"}', true);

    p := public.request_payout(50);
    raise notice 'P6b OBSERVED: request_payout(50) -> payout % status %  (EXPECT a row, status requested)', p.id, p.status;

    begin
      p := public.request_payout(500);
      raise notice 'P6b OBSERVED: request_payout(500) SUCCEEDED — WRONG, balance is 100';
    exception when others then
      get stacked diagnostics msg = message_text;
      raise notice 'P6b OBSERVED: request_payout(500) refused: %  (EXPECT insufficient_funds)', msg;
    end;
  exception when others then
    get stacked diagnostics msg = message_text;
    raise notice 'P6b OBSERVED: CANNOT EXECUTE (%) -- %', sqlstate, msg;
  end;
end $$;

\echo ''
\echo '=== CATALOGUE ASSERTIONS ==================================================='
\echo '    Function attributes are asserted as the CATALOGUE reports them, not as'
\echo '    the migration text claims. proacl is asserted rather than "no DROP was'
\echo '    needed, so no re-GRANT was needed" (T-058): all three are CREATE OR'
\echo '    REPLACE with unchanged signatures, so proacl must be IDENTICAL on both'
\echo '    sides of this run. A difference is a defect.'
select 'wallets column' as kind,
       attname as name,
       'notnull=' || attnotnull as detail
from pg_attribute
where attrelid='public.wallets'::regclass and attnum > 0 and not attisdropped
union all
select 'wallets constraint', conname, pg_get_constraintdef(oid)
from pg_constraint where conrelid='public.wallets'::regclass
union all
select 'wallets index', indexname, indexdef
from pg_indexes where schemaname='public' and tablename='wallets'
union all
select 'wallets policy', polname,
       coalesce(pg_get_expr(polqual, polrelid),'-') || ' / WITH CHECK ' ||
       coalesce(pg_get_expr(polwithcheck, polrelid),'-')
from pg_policy where polrelid='public.wallets'::regclass
union all
select 'wallets comment', 'public.wallets',
       left(coalesce(obj_description('public.wallets'::regclass,'pg_class'),'(none)'), 80) || '...'
union all
select 'inbound fk', conname, pg_get_constraintdef(oid)
from pg_constraint
where contype='f' and confrelid='public.wallets'::regclass
union all
select 'function', p.proname||'('||pg_get_function_identity_arguments(p.oid)||')',
       'secdef='||p.prosecdef||'  cfg='||coalesce(p.proconfig::text,'-')||
       '  acl='||coalesce(p.proacl::text,'(default: PUBLIC)')
from pg_proc p join pg_namespace n on n.oid=p.pronamespace
where n.nspname='public'
  and p.proname in ('_wallet_recalc','delete_my_account','request_payout','fn_get_wallet')
order by 1,2;
