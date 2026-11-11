-- KAN-910: proof for supabase/migrations/20261111121200_kan714_r_nearby_games_6arg_drop.sql.
--
-- LOCAL THROWAWAY DATABASES ONLY. The guard refuses anything that looks like Supabase and any database whose name
-- does not start with k910. Never point this at a hosted project.
--
-- TAP output (ok / not ok lines, plan 1..6). The pgTAP extension is not installed on the local toolchain, so the
-- assertions are plain SQL that print TAP; any "not ok" makes the last statement raise, so psql exits non-zero.
--
-- Precondition: the tracked chain through 20261105110000_kan714_events_parent_reads_2.sql (the 6-arg overload at
-- its part 2 post-image, md5(prosrc) 4132dec1...). Reproduced locally (2026-11-11) by
-- supabase/tests/events_p4/kan887_part2_after_kan794_test.sh with its cleanup removed (database k887_ok), then
-- 20261105120000_kan865, 20261105130000_kan865 and 20261105140000_kan715 applied; each run uses a fresh copy:
--   CREATE DATABASE k910_<x> TEMPLATE k887_ok;
-- Run from the repository root:
--   psql -X -h /tmp -p <port> -U postgres -d k910_<x> -P pager=off \
--        -f supabase/tests/events_p4/kan714_r_nearby_games_6arg_drop_test.sql
-- RED evidence: add -v skip_migration=1; the migration is not applied and T3 must report "not ok".
--
-- The local chain carries no other nearby_games overload and no get_nearby_games / rpc_get_nearby_games (PostGIS
-- readers absent from the harness). So that T4/T5 compare something real, F creates same-name neighbours where
-- absent (throwaway database only): nearby_games(float8,float8), get_nearby_games(float8,float8,integer),
-- rpc_get_nearby_games(float8,float8,integer,uuid,text,numeric). Existing ones are left as they are.
--   T1 the 6-arg overload exists before, md5(prosrc) = 4132dec168331c547f299f1cccd04804 (part 2 post-image)
--   T2 no pg_depend row references it before (so the plain DROP cannot be blocked or cascade)
--   T3 it is absent after the migration
--   T4 every other nearby_games overload: same signatures and md5(prosrc) before and after
--   T5 every get_nearby_games / rpc_get_nearby_games overload: same signatures and md5(prosrc) before and after
--   T6 the neighbour set is not empty (T4/T5 compared at least one function each)
\set ON_ERROR_STOP 1
SET client_min_messages = warning;

DO $g$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'supabase_admin')
     OR EXISTS (SELECT 1 FROM pg_namespace WHERE nspname IN ('storage', 'realtime', 'supabase_functions')) THEN
    RAISE EXCEPTION 'KAN-910 test: this looks like a Supabase database; refusing';
  END IF;
  IF current_database() !~ '^k910' THEN
    RAISE EXCEPTION 'KAN-910 test: database % does not start with k910; refusing', current_database();
  END IF;
END $g$;

-- F: neighbours, created only where absent.
DO $f$ BEGIN
  IF to_regprocedure('public.nearby_games(double precision,double precision)') IS NULL THEN
    CREATE FUNCTION public.nearby_games(p_lat double precision, p_lng double precision) RETURNS integer
      LANGUAGE sql IMMUTABLE AS 'SELECT 910';
  END IF;
  IF to_regprocedure('public.get_nearby_games(double precision,double precision,integer)') IS NULL THEN
    CREATE FUNCTION public.get_nearby_games(p_lat double precision, p_lng double precision, p_radius integer) RETURNS integer
      LANGUAGE sql IMMUTABLE AS 'SELECT 911';
  END IF;
  IF to_regprocedure('public.rpc_get_nearby_games(double precision,double precision,integer,uuid,text,numeric)') IS NULL THEN
    CREATE FUNCTION public.rpc_get_nearby_games(p_lat double precision, p_lng double precision, p_radius_meters integer,
      p_sport_id uuid, p_sort text, p_min numeric) RETURNS integer LANGUAGE sql IMMUTABLE AS 'SELECT 912';
  END IF;
END $f$;

CREATE TEMP TABLE k910_tap (n int PRIMARY KEY, ok boolean NOT NULL, label text NOT NULL);
CREATE TEMP TABLE k910_snap (phase text, grp text, sig text, h text);

INSERT INTO k910_snap
SELECT 'pre', CASE WHEN p.proname = 'nearby_games' THEN 'nearby' ELSE 'get' END, p.oid::regprocedure::text, md5(p.prosrc)
  FROM pg_proc p WHERE p.pronamespace = 'public'::regnamespace
   AND p.proname IN ('nearby_games', 'get_nearby_games', 'rpc_get_nearby_games')
   AND p.oid IS DISTINCT FROM to_regprocedure('public.nearby_games(double precision,double precision,integer,text,integer,integer)');

INSERT INTO k910_tap VALUES (1,
  coalesce((SELECT md5(prosrc) = '4132dec168331c547f299f1cccd04804' FROM pg_proc
             WHERE oid = to_regprocedure('public.nearby_games(double precision,double precision,integer,text,integer,integer)')), false),
  'T1 6-arg nearby_games present before, md5(prosrc) 4132dec1 (part 2 post-image)');
INSERT INTO k910_tap VALUES (2,
  to_regprocedure('public.nearby_games(double precision,double precision,integer,text,integer,integer)') IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM pg_depend WHERE refclassid = 'pg_proc'::regclass
     AND refobjid = to_regprocedure('public.nearby_games(double precision,double precision,integer,text,integer,integer)')),
  'T2 no pg_depend row references the 6-arg overload before');

\if :{?skip_migration}
\echo '# skip_migration set: migration NOT applied (RED run)'
\else
\i supabase/migrations/20261111121200_kan714_r_nearby_games_6arg_drop.sql
\endif

INSERT INTO k910_snap
SELECT 'post', CASE WHEN p.proname = 'nearby_games' THEN 'nearby' ELSE 'get' END, p.oid::regprocedure::text, md5(p.prosrc)
  FROM pg_proc p WHERE p.pronamespace = 'public'::regnamespace
   AND p.proname IN ('nearby_games', 'get_nearby_games', 'rpc_get_nearby_games')
   AND p.oid IS DISTINCT FROM to_regprocedure('public.nearby_games(double precision,double precision,integer,text,integer,integer)');

INSERT INTO k910_tap VALUES (3,
  to_regprocedure('public.nearby_games(double precision,double precision,integer,text,integer,integer)') IS NULL,
  'T3 6-arg nearby_games absent after the migration');
INSERT INTO k910_tap SELECT 4, NOT EXISTS (
    (SELECT sig, h FROM k910_snap WHERE phase = 'pre' AND grp = 'nearby'
     EXCEPT SELECT sig, h FROM k910_snap WHERE phase = 'post' AND grp = 'nearby')
    UNION ALL
    (SELECT sig, h FROM k910_snap WHERE phase = 'post' AND grp = 'nearby'
     EXCEPT SELECT sig, h FROM k910_snap WHERE phase = 'pre' AND grp = 'nearby')),
  'T4 other nearby_games overloads unchanged (' || (SELECT string_agg(sig || ' ' || left(h, 8), '; ' ORDER BY sig)
     FROM k910_snap WHERE phase = 'post' AND grp = 'nearby') || ')';
INSERT INTO k910_tap SELECT 5, NOT EXISTS (
    (SELECT sig, h FROM k910_snap WHERE phase = 'pre' AND grp = 'get'
     EXCEPT SELECT sig, h FROM k910_snap WHERE phase = 'post' AND grp = 'get')
    UNION ALL
    (SELECT sig, h FROM k910_snap WHERE phase = 'post' AND grp = 'get'
     EXCEPT SELECT sig, h FROM k910_snap WHERE phase = 'pre' AND grp = 'get')),
  'T5 get_nearby_games / rpc_get_nearby_games overloads unchanged (' || (SELECT string_agg(sig || ' ' || left(h, 8), '; ' ORDER BY sig)
     FROM k910_snap WHERE phase = 'post' AND grp = 'get') || ')';
INSERT INTO k910_tap VALUES (6,
  (SELECT count(*) FROM k910_snap WHERE phase = 'pre' AND grp = 'nearby') >= 1
  AND (SELECT count(*) FROM k910_snap WHERE phase = 'pre' AND grp = 'get') >= 1,
  'T6 neighbour set compared is not empty');

\pset tuples_only on
\pset format unaligned
SELECT '1..6';
SELECT CASE WHEN ok THEN 'ok ' ELSE 'not ok ' END || n || ' - ' || label FROM k910_tap ORDER BY n;
DO $end$ BEGIN
  IF EXISTS (SELECT 1 FROM k910_tap WHERE NOT ok) THEN
    RAISE EXCEPTION 'KAN-910: FAIL (% not ok)', (SELECT count(*) FROM k910_tap WHERE NOT ok);
  END IF;
END $end$;
SELECT '# KAN-910: ALL PASS';
