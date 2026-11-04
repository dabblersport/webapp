-- KAN-859 (KAN-718 F6) probe: the retired RPCs public.rpc_meetup_invite_user(uuid, uuid, timestamptz) and
-- public.rpc_meetup_mint_link(uuid, timestamptz, integer) exist (exact pre-image) BEFORE, and are absent AFTER
-- 20261104112400_kan718_f6_drop_retired_meetup_rpcs.sql.
--
-- LOCAL THROWAWAY PG16 ONLY (refuses any database not named k859*, and anything that looks like Supabase).
-- Output is TAP (plan + ok / not ok lines), so it runs under a TAP harness without the pgTAP extension:
--   prove -v --exec 'psql -X -q -tA -h /tmp -p <port> -U postgres -d k859 -v phase=pre -f' <this file>
--   prove -v --exec 'psql -X -q -tA -h /tmp -p <port> -U postgres -d k859 -v phase=post -f' <this file>
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

BEGIN;

CREATE TEMP TABLE _tap (n int, ok boolean, label text);

\if :{?phase}
\else
\set phase pre
\endif

SELECT :'phase' = 'pre' AS is_pre \gset

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
