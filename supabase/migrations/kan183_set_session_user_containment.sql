-- KAN-183 -- public.set_session_user(uuid): session-scope identity-poisoning primitive.
--
-- ============================================================================
-- NOT APPLIED. This file carries no timestamp prefix ON PURPOSE.
-- ============================================================================
-- The KAN-183 continuation environment is locality=local, runtime=none,
-- ref=/Users/moatazmustapha/Desktop/Thebes-Canonical/Dabbler/dabbler-code --
-- i.e. the authoritative target is this repository, not the deployed project.
-- Read-only SELECTs were run against wtncuzcskpigqpmnxwws to gather the
-- evidence recorded below, but NO DDL was applied and therefore NO
-- apply_migration version exists for this file yet.
--
-- Per the KAN-186 provenance lesson (commit fe7b4be), a migration file MUST NOT
-- carry a version prefix it did not actually receive back from apply_migration.
-- On apply, rename this file to the exact returned version and commit it under
-- that name in the same change.
--
-- ----------------------------------------------------------------------------
-- The defect
-- ----------------------------------------------------------------------------
-- Baseline body (supabase/migrations/20260829080500_baseline_schema.sql:17024):
--
--   perform set_config(
--     'request.jwt.claims',
--     json_build_object('sub', p_user::text, 'role', 'authenticated')::text,
--     false                      -- <-- SESSION scope, not transaction scope
--   );
--
-- SECURITY DEFINER, owner postgres, search_path=public -- all four confirmed
-- live 2026-09-14 via pg_proc (prosecdef=true, proconfig={search_path=public}).
--
-- p_user is a caller-supplied AUTHORIZATION SUBJECT, not a filter: it becomes
-- auth.uid(), hence effective_actor_uid(), hence is_admin(),
-- admin_cleanup_user_data, admin_take_action and rpc_admin_freeze_user. It does
-- NOT poison whoami_effective(), which reads only the singular legacy GUC -- so
-- the admin_actor() family resists this specifically. Partial mitigation, not a
-- reason to close.
--
-- Because the third argument is false, the poisoned GUC OUTLIVES the
-- transaction and persists for the life of the backend session.
--
-- ============================================================================
-- AC1 -- SETTLED 2026-09-14, AND IT RESOLVES THE UNSAFE WAY.
-- ============================================================================
-- AC1 asked whether PostgREST's actual pooling behaviour could ever let an
-- unauthenticated or low-privilege request share a session with a subsequent
-- privileged one. It can. Measured live, read-only:
--
--   select usename, application_name, count(*), min(backend_start),
--          max(now()-backend_start), count(*) filter (where state='idle')
--   from pg_stat_activity where backend_type='client backend' group by 1,2;
--
--   usename       | application_name | conns | oldest_backend            | max_age  | idle
--   authenticator | postgrest        |     2 | 2026-08-28 16:34:36.845+00| 17 days  |    2
--
-- PostgREST holds TWO PERSISTENT `authenticator` BACKENDS, 17 DAYS OLD. Every
-- REST request this project serves -- anon and authenticated alike -- is
-- multiplexed onto those two long-lived sessions. A session-scoped set_config
-- executed on one of them therefore PERSISTS ACROSS SUBSEQUENT REQUESTS on that
-- same backend. That is exactly the session-sharing AC1 was asked to rule out.
--
-- THE 6543 / TRANSACTION-MODE EVIDENCE DOES NOT APPLY AND MUST NOT BE CITED
-- HERE. supabase/.temp/pooler-url (CLI-generated at link time) points at
-- aws-1-eu-central-1.pooler.supabase.com:6543, Supavisor's fixed
-- transaction-mode port -- the po-recorded PARTIAL evidence of 2026-09-11. That
-- describes the DIRECT/CLI connection path. PostgREST does not connect through
-- Supavisor; it maintains its own pool, which is what pg_stat_activity shows
-- above. Transaction-mode pooling on 6543 is true and irrelevant to this
-- question. The partial evidence pointed the right way for the wrong path, and
-- had it been accepted alone it would have closed this ticket wrongly.
--
-- So AC2's root-fix branch applies, not AC1's "unreachable, close it" branch.
--
-- ----------------------------------------------------------------------------
-- What actually prevents exploitation today: AC3 containment, confirmed live
-- ----------------------------------------------------------------------------
-- Measured 2026-09-14, using has_function_privilege, never a proacl text match:
--
--   proacl        : {postgres=X/postgres,service_role=X/postgres}
--   anon          : has_function_privilege = false
--   authenticated : has_function_privilege = false
--   service_role  : has_function_privilege = true
--
-- There is NO bare =X/postgres PUBLIC entry, so nothing is inherited silently.
-- This confirms the containment applied live on 2026-09-10 and recorded in
-- docs/SCHEMA.md 2g.1 -- which until now existed only in a session transcript
-- and in that prose block, with NO migration file anywhere. This file closes
-- that gap in committed, replayable form.
--
-- Also confirmed live, same date -- the two remaining arming mechanisms named
-- on the ticket are both absent:
--   * NO db-pre-request hook. pg_db_role_setting contains no pgrst.db_pre_request
--     (nor any pgrst.* setting) at role or database level, and no such hook
--     exists anywhere in this repository.
--   * ZERO CALLERS, live and in-repo. No pg_proc body, view/matview definition,
--     column default, or constraint references set_session_user; and it appears
--     nowhere in this repository outside the baseline definition and
--     docs/SCHEMA.md -- no migration, edge function, test or Dart call site.
--
-- NET: a live escalation primitive whose ONLY remaining barrier is the EXECUTE
-- ACL. Containment is load-bearing, not belt-and-braces. Restoring anon or
-- authenticated EXECUTE on this function, with the session-scope body intact,
-- would be directly exploitable against the PostgREST pool measured above.
--
-- ----------------------------------------------------------------------------
-- What this migration does
-- ----------------------------------------------------------------------------
-- (1) ROOT FIX (AC2): set_config(..., true) -- TRANSACTION scope. The poisoned
--     identity can no longer outlive the transaction that set it, so it can no
--     longer leak onto the shared PostgREST backend. AC2 names this as a
--     structural fix independent of the reachability question; given AC1's
--     actual answer it is the required one, and it removes the hazard even if
--     the ACL is later widened by mistake.
--
--     CREATE OR REPLACE, not DROP+CREATE: replace PRESERVES the existing ACL,
--     whereas DROP+CREATE re-derives it from pg_default_acl, which still grants
--     anon EXECUTE on new public functions (KAN-189/KAN-194, unfixed) -- i.e.
--     would re-open the exact hole this file is closing. Same reasoning as the
--     KAN-181 migration.
--
-- (2) CONTAINMENT RE-ASSERTED (AC3). The REVOKEs are idempotent and match the
--     live ACL measured above; they exist so the state is replayable from the
--     repository rather than resting on a transcript. PUBLIC is named
--     explicitly: a bare =X/postgres entry is a PUBLIC grant that anon inherits
--     without ever being named, so a REVOKE ... FROM anon, authenticated that
--     leaves PUBLIC standing looks like containment and is not.

CREATE OR REPLACE FUNCTION public.set_session_user(p_user uuid) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
begin
  perform set_config(
    'request.jwt.claims',
    json_build_object('sub', p_user::text, 'role', 'authenticated')::text,
    true   -- KAN-183: TRANSACTION scope. Was false (session scope). PostgREST
           -- serves every request on a small set of long-lived `authenticator`
           -- backends (2 measured, 17 days old, 2026-09-14), so a session-scoped
           -- write here persisted across later requests on the same backend and
           -- poisoned auth.uid() for whoever landed on it next.
  );
end;
$$;

REVOKE ALL ON FUNCTION public.set_session_user(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.set_session_user(uuid) FROM anon;
REVOKE ALL ON FUNCTION public.set_session_user(uuid) FROM authenticated;

GRANT EXECUTE ON FUNCTION public.set_session_user(uuid) TO service_role;

COMMENT ON FUNCTION public.set_session_user(uuid) IS
'KAN-183. Sets request.jwt.claims from a CALLER-SUPPLIED identity, so p_user is '
'an authorization subject, not a filter: it becomes auth.uid(), '
'effective_actor_uid(), is_admin() and everything downstream of them. It does '
'not affect whoami_effective(), which reads only the singular legacy GUC. '
'NOT INDEPENDENTLY CALLABLE by any untrusted caller: EXECUTE is held only by '
'postgres, service_role and supabase_admin (narrowed live 2026-09-10, recorded '
'in docs/SCHEMA.md 2g.1, re-asserted in committed form by this migration, and '
'reconfirmed live 2026-09-14 via has_function_privilege). Zero callers as of '
'2026-09-14 -- no function body, view, column default, constraint, trigger, '
'edge function, test or client call site, live or in repo. '
'The set_config scope argument is TRANSACTION (true) and MUST STAY true: '
'PostgREST serves all requests over a small pool of long-lived `authenticator` '
'sessions, so a session-scoped write here outlives its transaction and is '
'visible to whichever request next lands on that backend -- a '
'privilege-escalation primitive. Never grant this to anon or authenticated, '
'and never restore session scope.';
