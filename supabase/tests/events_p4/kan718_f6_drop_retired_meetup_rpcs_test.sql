-- KAN-859 (KAN-718 F6) probe: the retired RPCs public.rpc_meetup_invite_user(uuid, uuid, timestamptz) and
-- public.rpc_meetup_mint_link(uuid, timestamptz, integer) exist (exact pre-image) BEFORE, and are absent AFTER
-- 20261104112400_kan718_f6_drop_retired_meetup_rpcs.sql.
--
-- LOCAL THROWAWAY PG16 ONLY (refuses any database not named k859*, and anything that looks like Supabase).
-- Output is TAP (plan + ok / not ok lines), so it runs under a TAP harness without the pgTAP extension:
--   prove -v --exec 'psql -X -q -tA -h /tmp -p <port> -U postgres -d k859 -v phase=pre -f' <this file>
--   prove -v --exec 'psql -X -q -tA -h /tmp -p <port> -U postgres -d k859 -v phase=post -f' <this file>
--   prove -v --exec 'psql -X -q -tA -h /tmp -p <port> -U postgres -d k859 -v phase=drift -v mig=<migration path> -f' <this file>
--
-- CHAIN (tracked files only, the build_kan851.sh green path: bootstrap superuser pgboot, owner postgres):
--   events_p1/local_harness_kan711.sql, events_p1/local_seed_kan711.sql, events_p2/local_harness_kan712.sql,
--   events_p2_kan713/local_harness_kan713.sql, events_p2_kan714/local_harness_kan714.sql, then migrations
--   20261101140000, 20261102110000, 20261102120000 (+ CALL kan711_events_backfill_run(); kan711_events_validate_links()),
--   20261103100000, and with postgres NOSUPERUSER BYPASSRLS: 20261103104000, 20261103105000, 20261103110000.
--   Then the PRE-IMAGE, verbatim from the repo: SET check_function_bodies = false; + baseline
--   20260829080500:13792-13832 (CREATE + OWNER), :36493-36495, :36499-36501 (GRANTs), and
--   20260915120000:749-753 (the hardening REVOKE/GRANT). No harness defines either function.
--
-- RUN ORDER:
--   1. phase=pre  -> GREEN on the pre-image.   phase=post -> RED on the pre-image.
--   2. apply 20261104112400_kan718_f6_drop_retired_meetup_rpcs.sql (as postgres).
--   3. phase=post -> GREEN.                    phase=pre  -> RED.
--   phase=drift runs on the pre-image (before step 2). It is NOT read-only: it commits ALTER FUNCTION ... RESET ALL on
--   one function at a time, runs the migration (-v mig=<path>) in a child psql against the same database, then
--   restores SET search_path TO 'public'. GREEN only if the migration refuses both times and nothing is dropped.
--
-- Tests (read-only; one transaction, ROLLBACK at the end):
--   phase=pre
--     T1 rpc_meetup_invite_user(uuid, uuid, timestamptz) exists, the only overload of its name.
--     T2 rpc_meetup_mint_link(uuid, timestamptz, integer) exists, the only overload of its name.
--     T3 both match the migration's drift pin (md5(prosrc), plpgsql, SECURITY DEFINER, search_path=public).
--     T4 both carry the hardened ACL {postgres, authenticated, service_role} (no PUBLIC, no anon).
--     T5 nothing depends on either (pg_depend, triggers, other functions' prosrc).
--   phase=post
--     T1 rpc_meetup_invite_user absent under any signature.
--     T2 rpc_meetup_mint_link absent under any signature.
--     T3 public.meetups is still present (no CASCADE side effect). The full "nothing else dropped" check is the
--        before/after catalogue fingerprint in the run notes (pg_proc + pg_class counts), not this file.
--   phase=drift (KAN-859 C2: the drift guard must be null-safe; a NULL proconfig used to pass it)
--     T1 precondition: rpc_meetup_invite_user proconfig IS NULL after RESET ALL.
--     T2 the migration RAISES its invite_user drift-guard exception (non-zero psql exit).
--     T3 both functions still exist afterwards.
--     T4 precondition: rpc_meetup_mint_link proconfig IS NULL after RESET ALL (invite_user restored).
--     T5 the migration RAISES its mint_link drift-guard exception (non-zero psql exit).
--     T6 both functions still exist afterwards.
--     T7 after restoring, both match the drift pin again (the database is back on the clean pre-image).
\set ON_ERROR_STOP 1

DO $g$ BEGIN
  IF current_database() !~ '^k859' THEN
    RAISE EXCEPTION 'kan718_f6 probe: refusing database % (local k859* only)', current_database();
  END IF;
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'supabase_admin')
     OR EXISTS (SELECT 1 FROM pg_namespace WHERE nspname IN ('storage', 'realtime', 'supabase_functions')) THEN
    RAISE EXCEPTION 'kan718_f6 probe: this looks like a Supabase database; refusing';
  END IF;
END $g$;

\if :{?phase}
\else
\set phase pre
\endif

SELECT :'phase' = 'pre' AS is_pre, :'phase' = 'drift' AS is_drift \gset

\if :is_drift
\if :{?mig}
\else
\echo 'Bail out! phase=drift needs -v mig=<path to 20261104112400_kan718_f6_drop_retired_meetup_rpcs.sql>'
\quit
\endif
CREATE TEMP TABLE _tap (n int, ok boolean, label text);

-- Case A: invite_user loses its proconfig.
ALTER FUNCTION public.rpc_meetup_invite_user(uuid, uuid, timestamp with time zone) RESET ALL;
INSERT INTO _tap VALUES
 (1, (SELECT p.proconfig IS NULL FROM pg_proc p
       WHERE p.oid = to_regprocedure('public.rpc_meetup_invite_user(uuid, uuid, timestamp with time zone)')) IS TRUE,
  'T1 precondition: rpc_meetup_invite_user proconfig IS NULL (RESET ALL)');
\set out_a `psql -X -q -v ON_ERROR_STOP=1 -h :'HOST' -p :'PORT' -U :'USER' -d :'DBNAME' -f :'mig' 2>&1; echo "rc=$?"`
INSERT INTO _tap VALUES
 (2, :'out_a' ~ 'KAN-859 pre: rpc_meetup_invite_user drifted from the retired pre-image' AND :'out_a' ~ 'rc=[1-9][0-9]*$',
  'T2 migration RAISES on invite_user with NULL proconfig'),
 (3, to_regprocedure('public.rpc_meetup_invite_user(uuid, uuid, timestamp with time zone)') IS NOT NULL
     AND to_regprocedure('public.rpc_meetup_mint_link(uuid, timestamp with time zone, integer)') IS NOT NULL,
  'T3 both functions still exist after the refused run (invite_user case)');
DO $r$ BEGIN
  IF to_regprocedure('public.rpc_meetup_invite_user(uuid, uuid, timestamp with time zone)') IS NOT NULL THEN
    ALTER FUNCTION public.rpc_meetup_invite_user(uuid, uuid, timestamp with time zone) SET search_path TO 'public';
  END IF;
END $r$;

-- Case B: mint_link loses its proconfig.
DO $r$ BEGIN
  IF to_regprocedure('public.rpc_meetup_mint_link(uuid, timestamp with time zone, integer)') IS NOT NULL THEN
    ALTER FUNCTION public.rpc_meetup_mint_link(uuid, timestamp with time zone, integer) RESET ALL;
  END IF;
END $r$;
INSERT INTO _tap VALUES
 (4, (SELECT p.proconfig IS NULL FROM pg_proc p
       WHERE p.oid = to_regprocedure('public.rpc_meetup_mint_link(uuid, timestamp with time zone, integer)')) IS TRUE,
  'T4 precondition: rpc_meetup_mint_link proconfig IS NULL (RESET ALL)');
\set out_b `psql -X -q -v ON_ERROR_STOP=1 -h :'HOST' -p :'PORT' -U :'USER' -d :'DBNAME' -f :'mig' 2>&1; echo "rc=$?"`
INSERT INTO _tap VALUES
 (5, :'out_b' ~ 'KAN-859 pre: rpc_meetup_mint_link drifted from the retired pre-image' AND :'out_b' ~ 'rc=[1-9][0-9]*$',
  'T5 migration RAISES on mint_link with NULL proconfig'),
 (6, to_regprocedure('public.rpc_meetup_invite_user(uuid, uuid, timestamp with time zone)') IS NOT NULL
     AND to_regprocedure('public.rpc_meetup_mint_link(uuid, timestamp with time zone, integer)') IS NOT NULL,
  'T6 both functions still exist after the refused run (mint_link case)');
DO $r$ BEGIN
  IF to_regprocedure('public.rpc_meetup_mint_link(uuid, timestamp with time zone, integer)') IS NOT NULL THEN
    ALTER FUNCTION public.rpc_meetup_mint_link(uuid, timestamp with time zone, integer) SET search_path TO 'public';
  END IF;
END $r$;
INSERT INTO _tap VALUES
 (7, (SELECT count(*) FROM pg_proc p
       WHERE p.pronamespace = 'public'::regnamespace
         AND ((p.proname = 'rpc_meetup_invite_user' AND md5(p.prosrc) = '08d8cc7c0d7b99653b81d9cbeaf33b82')
           OR (p.proname = 'rpc_meetup_mint_link'   AND md5(p.prosrc) = '2364638777f63f9f8fe6fa9e704b4153'))
         AND p.prolang = (SELECT oid FROM pg_language WHERE lanname = 'plpgsql')
         AND p.prosecdef AND p.proconfig = ARRAY['search_path=public']) = 2,
  'T7 restored: both match the drift pin again');

SELECT '1..' || count(*) FROM _tap;
SELECT CASE WHEN ok THEN 'ok ' ELSE 'not ok ' END || n || ' - ' || label FROM _tap ORDER BY n;
\quit
\endif

BEGIN;

CREATE TEMP TABLE _tap (n int, ok boolean, label text);

\if :is_pre
INSERT INTO _tap VALUES
 (1, to_regprocedure('public.rpc_meetup_invite_user(uuid, uuid, timestamp with time zone)') IS NOT NULL
     AND (SELECT count(*) FROM pg_proc WHERE proname = 'rpc_meetup_invite_user') = 1,
  'T1 rpc_meetup_invite_user(uuid, uuid, timestamptz) exists, single overload'),
 (2, to_regprocedure('public.rpc_meetup_mint_link(uuid, timestamp with time zone, integer)') IS NOT NULL
     AND (SELECT count(*) FROM pg_proc WHERE proname = 'rpc_meetup_mint_link') = 1,
  'T2 rpc_meetup_mint_link(uuid, timestamptz, integer) exists, single overload'),
 (3, (SELECT count(*) FROM pg_proc p
       WHERE p.pronamespace = 'public'::regnamespace
         AND ((p.proname = 'rpc_meetup_invite_user' AND md5(p.prosrc) = '08d8cc7c0d7b99653b81d9cbeaf33b82')
           OR (p.proname = 'rpc_meetup_mint_link'   AND md5(p.prosrc) = '2364638777f63f9f8fe6fa9e704b4153'))
         AND p.prolang = (SELECT oid FROM pg_language WHERE lanname = 'plpgsql')
         AND p.prosecdef AND p.proconfig = ARRAY['search_path=public']) = 2,
  'T3 both match the drift pin (md5(prosrc), plpgsql, DEFINER, search_path=public)'),
 (4, (SELECT count(*) FROM pg_proc p
       WHERE p.proname IN ('rpc_meetup_invite_user', 'rpc_meetup_mint_link')
         AND p.proacl::text[] @> ARRAY['postgres=X/postgres', 'authenticated=X/postgres', 'service_role=X/postgres']
         AND cardinality(p.proacl) = 3
         AND NOT has_function_privilege('anon', p.oid, 'EXECUTE')) = 2,
  'T4 both carry the hardened ACL (postgres, authenticated, service_role; no PUBLIC, no anon)'),
 (5, NOT EXISTS (SELECT 1 FROM pg_depend d JOIN pg_proc p ON p.oid = d.refobjid
                  WHERE d.refclassid = 'pg_proc'::regclass
                    AND p.proname IN ('rpc_meetup_invite_user', 'rpc_meetup_mint_link'))
     AND NOT EXISTS (SELECT 1 FROM pg_trigger t JOIN pg_proc p ON p.oid = t.tgfoid
                      WHERE p.proname IN ('rpc_meetup_invite_user', 'rpc_meetup_mint_link'))
     AND NOT EXISTS (SELECT 1 FROM pg_proc p
                      WHERE p.proname NOT IN ('rpc_meetup_invite_user', 'rpc_meetup_mint_link')
                        AND p.prosrc ~ '(rpc_meetup_invite_user|rpc_meetup_mint_link)'),
  'T5 zero dependents (pg_depend, triggers, other functions'' prosrc)');
\else
INSERT INTO _tap VALUES
 (1, to_regprocedure('public.rpc_meetup_invite_user(uuid, uuid, timestamp with time zone)') IS NULL
     AND NOT EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'rpc_meetup_invite_user'),
  'T1 rpc_meetup_invite_user absent under any signature'),
 (2, to_regprocedure('public.rpc_meetup_mint_link(uuid, timestamp with time zone, integer)') IS NULL
     AND NOT EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'rpc_meetup_mint_link'),
  'T2 rpc_meetup_mint_link absent under any signature'),
 (3, (SELECT count(*) FROM pg_proc WHERE proname IN ('rpc_meetup_invite_user', 'rpc_meetup_mint_link')) = 0
     AND (to_regclass('public.meetups') IS NOT NULL),
  'T3 nothing else removed with them (public.meetups present; only the two names are gone)');
\endif

SELECT '1..' || count(*) FROM _tap;
SELECT CASE WHEN ok THEN 'ok ' ELSE 'not ok ' END || n || ' - ' || label FROM _tap ORDER BY n;

ROLLBACK;
