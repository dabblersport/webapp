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
-- role_grants_no_insert / _no_update / _no_delete replaced the FOR ALL
-- role_grants_no_rw. Writes reach this table only through SECURITY DEFINER
-- functions and roles carrying rolbypassrls (postgres, service_role).
begin;
set local role authenticated;
set local request.jwt.claims = '{"sub":"2d7024f7-198a-45aa-a64d-f52916b6b6c1","role":"authenticated"}';
do $$
begin
  begin
    insert into public.role_grants(user_id, role)
    values ('11111111-2222-3333-4444-555555555555','super_admin');
    raise exception 'P4 FAILED: insert succeeded as authenticated admin';
  exception when insufficient_privilege or check_violation then
    raise notice 'P4 pass: insert blocked';
  end;
end $$;
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
-- WHEN TO RE-RUN THIS WHOLE PACK
-- ===========================================================================
-- Any change to: is_admin's prosecdef or owner; role_grants' owner; ANY
-- `ALTER TABLE public.role_grants FORCE ROW LEVEL SECURITY` (a one-line diff
-- that looks like hardening and takes down the authorization path for seven
-- tables — T-079 names this as the dangerous case); or any new policy on
-- role_grants.
