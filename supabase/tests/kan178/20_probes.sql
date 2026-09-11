-- KAN-178 probe pack — public.role_grants read containment.
-- T-079 (behavioural, as a non-owner role) + Amendment 2 §4 (both directions).
-- backend-5 (Heka), 2026-09-11. Run against wtncuzcskpigqpmnxwws.
--
-- ===========================================================================
-- HOW TO RUN THIS, AND THE ONE WAY TO RUN IT WRONG
-- ===========================================================================
-- EVERY probe below sets a role that is SUBJECT TO RLS before it reads.
-- Run any of them as `postgres` and they PASS VACUOUSLY — postgres owns
-- role_grants and `relforcerowsecurity` is false, so the owner exemption makes
-- every row visible regardless of policy. The exemption is the very property
-- under test (T-079 §3). If you "simplify" these by dropping the
-- SET LOCAL ROLE, you have deleted the test and kept the output.
--
-- Each probe is wrapped begin/rollback. Nothing here writes.
--
-- ===========================================================================
-- EVERY PROBE WAS DEMONSTRATED FAILING BEFORE IT WAS TRUSTED
-- ===========================================================================
-- Run against live on 2026-09-11 BEFORE the migration, recorded verbatim.
-- A probe nobody has watched fail is not evidence (and see the KAN-175 trap:
-- an assertion whose comparison can never match passes while the hole is open).
--
--   P1  authenticated non-admin   -> 1 row   (target 0)  ** FAILED, fail-open **
--   P3  anon                      -> 1 row   (target 0)  ** FAILED, fail-open **
--   P6  in-transaction guard      -> raised
--         'KAN-178: 2 legacy policy/policies still present'
--   P5  raw INVOKER read          -> true    (became false after; that IS the
--                                             regression this pack records)
--
-- P2 and P4 could not be shown failing pre-change by construction: P2's
-- fail-closed mode does not exist while USING(true) stands, and P4's writes
-- were already denied. They are recorded as such rather than claimed as
-- demonstrated. P2 is nonetheless the probe that catches fail-closed, which is
-- the mode the migration's own ordering rule exists to prevent.
--
-- ===========================================================================
-- P1 — non-admin authenticated sees ZERO rows, and it is not an error
-- ===========================================================================
-- Amendment 2 §4: "zero rows — not an error, and not every row." Together with
-- P2 this single pair discriminates all three failure modes:
--   recursion  -> 42P17 raised here
--   fail-open  -> P1 returns rows (the T-075 defect returning)
--   fail-closed-> P2 returns zero
begin;
set local role authenticated;
set local request.jwt.claims = '{"sub":"11111111-2222-3333-4444-555555555555","role":"authenticated"}';
select 'P1 non-admin authenticated' as probe,
       count(*) as rows_visible,
       (count(*) = 0) as pass
  from public.role_grants;
rollback;

-- ===========================================================================
-- P2 — an ADMIN still sees rows. This is the fail-closed detector.
-- ===========================================================================
-- Replace the sub with a uuid holding role 'admin' in role_grants.
-- If this returns zero, the table has failed closed and `is_admin` is STILL
-- WORKING everywhere else (it is SECURITY DEFINER owned by postgres), so the
-- damage shows up as a partial outage across the seven T-079 tables rather
-- than as an obvious break here. That is the scenario Amendment 2 §1 forbids.
begin;
set local role authenticated;
set local request.jwt.claims = '{"sub":"2d7024f7-198a-45aa-a64d-f52916b6b6c1","role":"authenticated"}';
select 'P2 admin authenticated' as probe,
       count(*) as rows_visible,
       (count(*) >= 1) as pass
  from public.role_grants;
rollback;

-- ===========================================================================
-- P3 — anon sees ZERO rows
-- ===========================================================================
-- The read policy is TO authenticated, so anon matches no permissive SELECT
-- policy and is denied without ever evaluating an admin predicate.
begin;
set local role anon;
set local request.jwt.claims = '{"role":"anon"}';
select 'P3 anon' as probe, count(*) as rows_visible, (count(*) = 0) as pass
  from public.role_grants;
rollback;

-- ===========================================================================
-- P4 — writes are refused even for an admin
-- ===========================================================================
-- !! READ THIS BEFORE CITING P4 AS EVIDENCE FOR THE WRITE POLICIES. IT IS NOT. !!
--
-- P4 is a true CONTAINMENT assertion — writes are refused — and a FALSE
-- assertion about role_grants_no_insert / _no_update / _no_delete. Measured
-- 2026-09-11 by capturing the SQLSTATE instead of trusting the handler:
--
--   authenticated, uuid absent from auth.users -> 42501 permission denied
--   authenticated, real uuid + real role value -> 42501 permission denied
--   has_table_privilege('authenticated','public.role_grants','INSERT') = FALSE
--   relacl = {... anon=rm/postgres, authenticated=rm/postgres ...}   (r,m only)
--
-- `authenticated` holds NO INSERT GRANT, so the denial happens at the GRANT
-- layer and the RLS write policies ARE NEVER REACHED. The code under test is
-- not executed (T-055). Exercising them needs a role that HOLDS the write
-- grant and is still subject to RLS; no such role exists on this project, so
-- those three policies are untested here and are belt-and-braces by design —
-- with RLS enabled and no permissive policy for a command, the command is
-- denied anyway.
--
-- The original form of this probe caught `insufficient_privilege or
-- check_violation` and would ALSO have passed on a foreign-key violation going
-- uncaught, since role_grants.role is FK -> roles and role_grants.user_id is
-- FK -> auth.users. Rewritten below to capture and REPORT the SQLSTATE rather
-- than swallow it, so a future run cannot pass for a reason nobody looked at.
begin;
create temp table _p4(scenario text, sqlstate text, msg text);
grant all on _p4 to authenticated;
set local role authenticated;
set local request.jwt.claims = '{"sub":"2d7024f7-198a-45aa-a64d-f52916b6b6c1","role":"authenticated"}';
do $$
declare s text; m text;
begin
  begin
    insert into public.role_grants(user_id, role)
    values ('2d7024f7-198a-45aa-a64d-f52916b6b6c1','admin');
    insert into _p4 values ('insert as authenticated admin','NONE - INSERT SUCCEEDED','');
  exception when others then
    get stacked diagnostics s = returned_sqlstate, m = message_text;
    insert into _p4 values ('insert as authenticated admin', s, m);
  end;
end $$;
reset role;
-- expect sqlstate 42501. Anything else — especially 23503 — means the write
-- was stopped by something other than access control; read the message.
select 'P4 write containment' as probe, scenario, sqlstate, msg,
       (sqlstate = '42501') as pass
  from _p4;
rollback;

-- ===========================================================================
-- P5 — the DEFINER/INVOKER asymmetry. NOT a pass/fail probe: a RECORD.
-- ===========================================================================
-- This documents the consequence T-079 does not cover. As a non-admin:
--   is_admin(uuid)        SECURITY DEFINER -> still true. Unaffected.
--   raw read of role_grants (the literal body shape of the two INVOKER
--   helpers)                               -> false. Affected.
--
-- READ THE NEXT SENTENCE BEFORE CITING THIS PROBE. is_moderator() and
-- is_venue_admin() returning false below is NOT by itself evidence of the
-- regression — the uuid passed holds role 'admin', so both would return false
-- on the data regardless. The evidence is `raw_invoker_read`, which is the
-- same SELECT those two functions run, executed under the same role and the
-- same policy. Measured true before the migration, false after.
--
-- Consequence: a user holding venue_admin but not admin loses the three
-- storage.objects venue-bucket policies. Latent only because role_grants holds
-- one row, role 'admin' — ZERO venue_admin and ZERO moderator grants, counted.
begin;
set local role authenticated;
set local request.jwt.claims = '{"sub":"11111111-2222-3333-4444-555555555555","role":"authenticated"}';
select 'P5 DEFINER vs INVOKER (record, not pass/fail)' as probe,
       public.is_admin('2d7024f7-198a-45aa-a64d-f52916b6b6c1'::uuid) as is_admin_definer,
       exists(select 1 from public.role_grants where role = 'admin') as raw_invoker_read;
rollback;

-- ===========================================================================
-- P6 — diagnostics. NOT the criterion (T-079 §4).
-- ===========================================================================
-- A bare 42P17 says the property broke; these say WHICH of the three
-- owner-exemption conditions flipped. All three must hold together.
select 'P6 diagnostics' as probe,
       (select p.prosecdef from pg_proc p join pg_namespace n on n.oid = p.pronamespace
         where n.nspname='public' and p.proname='is_admin'
           and pg_get_function_identity_arguments(p.oid)='p_user uuid')      as is_admin_prosecdef,
       (select pg_get_userbyid(p.proowner) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
         where n.nspname='public' and p.proname='is_admin'
           and pg_get_function_identity_arguments(p.oid)='p_user uuid')      as is_admin_owner,
       (select pg_get_userbyid(relowner) from pg_class
         where oid='public.role_grants'::regclass)                           as role_grants_owner,
       (select relforcerowsecurity from pg_class
         where oid='public.role_grants'::regclass)                           as force_rls,
       (select count(*) from pg_policy
         where polrelid='public.role_grants'::regclass and polcmd='*')       as for_all_policy_count;

-- ===========================================================================
-- P7 — assert the PREDICATE, not the existence. With its discrimination pair.
-- ===========================================================================
-- The defect being fixed is a predicate (`USING (true)`) and the fix is a
-- different predicate, potentially under a similar name. A check shaped
-- `IF NOT EXISTS (select 1 from pg_policies where policyname = ...)` passes on
-- a policy of the right NAME with entirely the wrong PREDICATE, which is the
-- exact failure mode this ticket exists to remove.
--
-- Both columns below run the SAME join against the SAME schema with different
-- expected values. A single number is not evidence — `0` is also what a blind
-- predicate returns. The PAIR (1 and 0) is what proves the comparison really
-- compares. Measured live 2026-09-11: 1 and 0.
select 'P7 predicate assertion' as probe,
       (select count(*) from pg_policy
         where polrelid='public.role_grants'::regclass and polcmd='r'
           and pg_get_expr(polqual,polrelid) = 'is_admin(auth.uid())') as matches_intended_predicate,
       (select count(*) from pg_policy
         where polrelid='public.role_grants'::regclass and polcmd='r'
           and pg_get_expr(polqual,polrelid) = 'true')                 as matches_old_defect_predicate,
       (select count(*) from pg_policy
         where polrelid='public.role_grants'::regclass and polcmd='*') as for_all_policies,
       'expect 1, 0, 0' as criterion;

-- ===========================================================================
-- P8 — prove the behavioural test is actually testing (role discrimination)
-- ===========================================================================
-- P1's pass condition is ZERO ROWS — which is also exactly what a test that
-- has stopped working returns. If an empty answer came back for BOTH an
-- RLS-exempt role and an RLS-subject role, P1 would be measuring nothing.
--
-- Same query, same schema, same session, two roles. Measured live 2026-09-11:
--   postgres (table owner, RLS-exempt)      -> 1
--   authenticated non-admin (RLS applies)   -> 0
-- The two MUST differ. If they ever match, stop and fix the harness before
-- reading anything else in this file.
begin;
create temp table _disc(ctx text, n int);
grant all on _disc to authenticated;
insert into _disc values ('1. postgres (owner, RLS-EXEMPT)', (select count(*) from public.role_grants));
set local role authenticated;
set local request.jwt.claims = '{"sub":"11111111-2222-3333-4444-555555555555","role":"authenticated"}';
insert into _disc values ('2. authenticated non-admin (RLS applies)', (select count(*) from public.role_grants));
reset role;
select 'P8 discrimination' as probe, ctx, n,
       ((select n from _disc where ctx like '1.%') <> (select n from _disc where ctx like '2.%')) as pass
  from _disc order by ctx;
rollback;

-- ===========================================================================
-- P9 — AC5: the oracle is CLOSED and the policy path SURVIVED
-- ===========================================================================
-- After 20260911081512, util.is_moderator(uuid) and util.is_venue_admin(uuid)
-- are SECURITY DEFINER and live in `util`. The containment is the reverse of
-- the usual one: EXECUTE is KEPT for anon/authenticated, and `util` withholds
-- USAGE. PostgREST resolves an RPC BY NAME and so needs USAGE -> denied. A
-- policy qual stores the OID and resolves no name -> only EXECUTE is checked
-- -> it still runs.
--
-- Measured as `authenticated` 2026-09-11. BEFORE this migration both were
-- "REACHABLE, returned false" by name — that is the pre-state these replace.
--
--   util.is_venue_admin(uuid)  by name -> 42501 permission denied for schema util
--   util.is_moderator(uuid)    by name -> 42501 permission denied for schema util
--   public.is_venue_admin(uuid) 1-arg  -> 42883 function does not exist
--   public.is_venue_admin(uuid,uuid)   -> REACHABLE, returned true   << 2-arg
--                                          untouched and MUST stay reachable
--
-- The last line is the over-reach guard. If it ever returns 42883 or 42501,
-- someone converted or moved the 2-arg overload, and venue_spaces /
-- venue_blackouts / venue_price_rules writes are broken.
begin;
create temp table _p9(scenario text, result text);
grant all on _p9 to authenticated;
set local role authenticated;
set local request.jwt.claims = '{"sub":"11111111-2222-3333-4444-555555555555","role":"authenticated"}';
do $$
declare s text; m text; b boolean;
begin
  begin
    select util.is_venue_admin('2d7024f7-198a-45aa-a64d-f52916b6b6c1'::uuid) into b;
    insert into _p9 values ('A util.is_venue_admin by name','REACHABLE - ORACLE OPEN, returned '||b::text);
  exception when others then
    get stacked diagnostics s=returned_sqlstate, m=message_text;
    insert into _p9 values ('A util.is_venue_admin by name', s||' '||m);
  end;
  begin
    select util.is_moderator('2d7024f7-198a-45aa-a64d-f52916b6b6c1'::uuid) into b;
    insert into _p9 values ('B util.is_moderator by name','REACHABLE - ORACLE OPEN, returned '||b::text);
  exception when others then
    get stacked diagnostics s=returned_sqlstate, m=message_text;
    insert into _p9 values ('B util.is_moderator by name', s||' '||m);
  end;
  begin
    select public.is_venue_admin('2d7024f7-198a-45aa-a64d-f52916b6b6c1'::uuid,
                                 '00000000-0000-0000-0000-000000000000'::uuid) into b;
    insert into _p9 values ('C 2-ARG must STAY reachable','REACHABLE returned '||b::text);
  exception when others then
    get stacked diagnostics s=returned_sqlstate, m=message_text;
    insert into _p9 values ('C 2-ARG must STAY reachable','BROKEN: '||s||' '||m);
  end;
end $$;
reset role;
select 'P9 oracle closure' as probe, scenario, result from _p9 order by scenario;
rollback;

-- ===========================================================================
-- P10 — AC5 no-regression, plus the OID/qual survival that makes it true
-- ===========================================================================
-- AC5 asks only that both still return false today. They do — and because they
-- are now DEFINER, false is the TRUE answer rather than a fail-closed artifact:
-- 0 moderator grants and 0 venue_admin grants of 1 total row.
--
-- The OID assertions are the load-bearing half. ALTER … SET SCHEMA preserves
-- the OID; a DROP + CREATE would not, and the three storage.objects quals are
-- OID-bound, so they would have been silently orphaned. Measured: both OIDs
-- unchanged at 20147 / 20148 across the move, and all three quals now render
-- `util.is_venue_admin(auth.uid())` — the binding followed the function.
select 'P10 AC5 no-regression' as probe,
       util.is_moderator('2d7024f7-198a-45aa-a64d-f52916b6b6c1'::uuid)   as is_moderator_false,
       util.is_venue_admin('2d7024f7-198a-45aa-a64d-f52916b6b6c1'::uuid) as is_venue_admin_false,
       (select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace
         where n.nspname='util' and p.proname in ('is_moderator','is_venue_admin')
           and p.prosecdef and p.oid in (20147,20148))                    as both_definer_in_util_same_oid,
       (select count(*) from pg_policy
         where polrelid='storage.objects'::regclass
           and coalesce(pg_get_expr(polqual,polrelid),pg_get_expr(polwithcheck,polrelid))
               ~ 'util\.is_venue_admin')                                  as storage_quals_rebound,
       (select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace
         where n.nspname='public' and p.proname='is_venue_admin'
           and pg_get_function_identity_arguments(p.oid)='p_user uuid, p_venue uuid'
           and not p.prosecdef)                                           as two_arg_untouched,
       'expect false,false,2,3,1' as criterion;

-- ===========================================================================
-- P11 — row_security=off, and WHY it is the guard (PEER FAIL, backend-6)
-- ===========================================================================
-- 20260911081512 relocated both helpers and made them DEFINER but carried the
-- invoker-era proconfig through, so row_security=off was missing. Added in
-- 20260911105846.
--
-- The mechanism, measured live as `authenticated` (a non-exempt role) rather
-- than asserted:
--   default (row_security on) -> read of role_grants returns FALSE, silently
--   SET row_security = off    -> 42501 "query would be affected by row-level
--                                security policy for table role_grants"
--
-- So without it, the day any of the three owner-exemption conditions flips —
-- `ALTER TABLE role_grants FORCE ROW LEVEL SECURITY` is one line and looks
-- like hardening — these two quietly answer `false` again, which is the exact
-- regression AC5 removes. With it they raise. It is the guard against this
-- ticket's own bug returning, which is why a missing attribute was a FAIL.
--
-- The second column is the class check: ZERO SECURITY DEFINER functions in
-- util may lack row_security=off. An empty list is the pass.
select 'P11 row_security=off' as probe,
       (select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace
         where n.nspname='util' and p.proname in ('is_moderator','is_venue_admin')
           and pg_get_function_identity_arguments(p.oid)='p_user uuid'
           and p.proconfig::text ~ 'row_security=off')            as both_have_rs_off,
       (select coalesce(string_agg(p.proname,','),'(none)')
          from pg_proc p join pg_namespace n on n.oid=p.pronamespace
         where n.nspname='util' and p.prosecdef
           and not (p.proconfig::text ~ 'row_security=off'))      as util_definers_missing_rs_off,
       'expect 2, (none)' as criterion;

-- The mechanism demonstration itself, re-runnable. Neither row writes.
begin;
create temp table _rs(scenario text, result text);
grant all on _rs to authenticated;
set local role authenticated;
set local request.jwt.claims = '{"sub":"11111111-2222-3333-4444-555555555555","role":"authenticated"}';
do $$
declare s text; m text; b boolean;
begin
  begin
    select exists(select 1 from public.role_grants where role='admin') into b;
    insert into _rs values ('row_security ON (default)', 'returned '||b::text||' - SILENTLY FILTERED');
  exception when others then
    get stacked diagnostics s=returned_sqlstate, m=message_text;
    insert into _rs values ('row_security ON (default)', s||' '||m);
  end;
  begin
    set local row_security = off;
    select exists(select 1 from public.role_grants where role='admin') into b;
    insert into _rs values ('row_security OFF, non-exempt role', 'returned '||b::text||' - NO RAISE, UNEXPECTED');
  exception when others then
    get stacked diagnostics s=returned_sqlstate, m=message_text;
    insert into _rs values ('row_security OFF, non-exempt role', s||' '||m);
  end;
end $$;
reset role;
select 'P11b mechanism' as probe, scenario, result from _rs order by scenario;
rollback;

-- ===========================================================================
-- GUARD SHAPES IN THE MIGRATION — classified, not asserted to be fine
-- ===========================================================================
-- The migration's in-transaction DO block holds three guards. All three are
-- COUNT-shaped (`count(*)` into an int, then `IF n <> expected RAISE`), so
-- none can test NULL and all fail CLOSED. Their SUBSTANCE differs:
--
--   v_legacy <> 0   asserts ABSENCE by policy NAME. Adequate — name is the
--                   right key for "this specific old policy is gone".
--   v_forall <> 0   asserts ABSENCE by polcmd. Adequate — polcmd is the right
--                   key for "no FOR ALL policy exists".
--   v_read <> 1     asserts ARITY ONLY. ** UNDER-SPECIFIED. ** It counts SELECT
--                   policies and never inspects their predicate, so a policy
--                   with USING (true) satisfies it. It would NOT have caught
--                   the very defect this ticket fixes.
--
-- P7 above is the assertion v_read should have been. It is in this re-runnable
-- pack rather than in the applied migration because that migration has already
-- landed; the behavioural probes P1/P2 cover the same property more strongly
-- (they assert the predicate's EFFECT, not its text), so nothing is unguarded.
-- Recorded rather than quietly corrected.
--
-- ===========================================================================
-- WHEN TO RE-RUN THIS WHOLE PACK
-- ===========================================================================
-- Any change to: is_admin's prosecdef or owner; role_grants' owner; ANY
-- `ALTER TABLE public.role_grants FORCE ROW LEVEL SECURITY` (a one-line diff
-- that looks like hardening and takes down the authorization path for seven
-- tables — T-079 names this as the dangerous case); or any new policy on
-- role_grants.
