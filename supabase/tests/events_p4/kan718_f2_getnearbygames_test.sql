-- KAN-855 (KAN-718 F2): proof for supabase/migrations/20261104112300_kan718_f2_getnearbygames.sql.
--
-- DECISION RECORDED: RETIRE getnearbygames(double precision,double precision,double precision) (inventory #8). Not
-- rewritten, and no DROP here (DROP is F8).
-- REASON: (1) no caller: lib/ and supabase/ contain no `.rpc('getnearbygames'` and no SupabaseConfig constant for it
-- (lib/ hits for "getNearbyGames" are Dart method names that call get_nearby_games / rpc_get_nearby_games); no SQL
-- function or view calls it (T6). (2) it has never returned a row: the LANGUAGE sql body joins public.geolocations
-- and reads g.sport, g.lat, g.lng, g.areaid, g.geolocationid, none of which exist in the repo schema; the baseline
-- dump created it with check_function_bodies = false, so the error surfaces at call time (T4). (3) a working rewrite
-- over public.events (FORCE RLS, no API grant) would need SECURITY DEFINER to revive dead code. Full evidence: the
-- migration header. Ruling dreq-8ae9bcfa (C) is respected: nothing here reads or removes a games column.
--
-- LOCAL OR DISPOSABLE DATABASES ONLY (guard below). Runs in one transaction and ROLLS BACK; it changes nothing.
-- Exit status is non-zero when any case fails.
--
-- Cases:
--   T0 the function exists.
--   T1 result signature is byte-identical to the baseline (regression guard; passes before and after).
--   T2 body md5, language, volatility, security, search_path, owner and ACL are the baseline ones: nothing replaced.
--   T3 the retirement is recorded (COMMENT 'KAN-855 RETIRED%').  RED before the migration.
--   T4 the retirement reason holds: a call raises 42P01 on public.geolocations (the code path is dead today).
--   T5 no pg_depend row ties it to public.games and it has no SQL-standard body, so it does not block Z01.
--   T6 no other function body or view in this catalogue calls getnearbygames.
--
-- Chain (throwaway PG16 from tracked repo files, as F1/KAN-854): events_p1 harness + seed, events_p2 harness,
-- events_p2_kan713 harness, events_p2_kan714 harness, 20261101140000, 20261102110000, 20261102120000 (+ backfill +
-- validate), 20261103100000, then the PRE-IMAGE verbatim from 20260829080500_baseline_schema.sql lines 7823-7847
-- (function + owner) and 35483-35485 (grants), loaded with check_function_bodies=off as the dump does.
-- Database k855 = pre-image (RED); k855_post = TEMPLATE k855 + the migration (GREEN).
--   psql -X -h /tmp -p <port> -U postgres -d k855      -v ON_ERROR_STOP=1 -f supabase/tests/events_p4/kan718_f2_getnearbygames_test.sql
--   psql -X -h /tmp -p <port> -U postgres -d k855_post -v ON_ERROR_STOP=1 -f supabase/migrations/20261104112300_kan718_f2_getnearbygames.sql
--   psql -X -h /tmp -p <port> -U postgres -d k855_post -v ON_ERROR_STOP=1 -f supabase/tests/events_p4/kan718_f2_getnearbygames_test.sql
\set ON_ERROR_STOP 1
SET client_min_messages = notice;

DO $g$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'supabase_admin')
     OR EXISTS (SELECT 1 FROM pg_namespace WHERE nspname IN ('storage', 'realtime', 'supabase_functions')) THEN
    RAISE EXCEPTION 'KAN-855: this looks like a Supabase database; local or disposable database only';
  END IF;
  IF current_database() !~ '^k855' THEN
    RAISE EXCEPTION 'KAN-855: database % is not a throwaway k855 database; refusing', current_database();
  END IF;
END $g$;

BEGIN;
CREATE TEMP TABLE k855_res (case_id text, pass boolean, detail text);

CREATE TEMP VIEW k855_fn AS
SELECT to_regprocedure('public.getnearbygames(double precision,double precision,double precision)') AS oid,
       '69ad4a9016477af16c938e12272234d7'::text AS src_md5,
       'TABLE(id uuid, title text, sport text, start_at timestamp with time zone, lat double precision, lng double precision, areaid uuid, distance_m double precision)'::text AS result;

-- T0
INSERT INTO k855_res SELECT 'T0', oid IS NOT NULL, coalesce(oid::regprocedure::text, '<absent>') FROM k855_fn;

-- T1
INSERT INTO k855_res SELECT 'T1', pg_get_function_result(f.oid) = f.result, pg_get_function_result(f.oid) FROM k855_fn f;

-- T2
INSERT INTO k855_res
SELECT 'T2',
       md5(p.prosrc) = f.src_md5 AND l.lanname = 'sql' AND p.provolatile = 's' AND NOT p.prosecdef
       AND p.proconfig = '{"search_path=public, pg_temp"}'::text[]
       AND pg_get_userbyid(p.proowner) = 'postgres'
       AND p.proacl::text = '{=X/postgres,postgres=X/postgres,anon=X/postgres,authenticated=X/postgres,service_role=X/postgres}',
       format('md5=%s lang=%s vol=%s secdef=%s cfg=%s acl=%s', md5(p.prosrc), l.lanname, p.provolatile, p.prosecdef,
              p.proconfig, p.proacl)
  FROM k855_fn f JOIN pg_proc p ON p.oid = f.oid JOIN pg_language l ON l.oid = p.prolang;

-- T3 (RED before the migration)
INSERT INTO k855_res
SELECT 'T3', coalesce(obj_description(f.oid, 'pg_proc') LIKE 'KAN-855 RETIRED%', false),
       coalesce(left(obj_description(f.oid, 'pg_proc'), 40), '<no comment>')
  FROM k855_fn f;

-- T4
DO $t4$
DECLARE st text; msg text;
BEGIN
  BEGIN
    PERFORM * FROM public.getnearbygames(25.20::float8, 55.27::float8, 5000::float8);
    st := 'none'; msg := 'returned';
  EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS st = RETURNED_SQLSTATE, msg = MESSAGE_TEXT;
  END;
  INSERT INTO k855_res VALUES ('T4', st = '42P01' AND msg LIKE '%geolocations%', st || ' ' || msg);
END $t4$;

-- T5
INSERT INTO k855_res
SELECT 'T5',
       NOT EXISTS (SELECT 1 FROM pg_depend d
                    WHERE d.classid = 'pg_proc'::regclass AND d.objid = f.oid
                      AND d.refclassid = 'pg_class'::regclass AND d.refobjid = 'public.games'::regclass)
       AND p.prosqlbody IS NULL,
       format('prosqlbody null=%s', p.prosqlbody IS NULL)
  FROM k855_fn f JOIN pg_proc p ON p.oid = f.oid;

-- T6
INSERT INTO k855_res
SELECT 'T6', count(*) = 0, coalesce(string_agg(o, ', '), 'none')
  FROM (SELECT p.oid::regprocedure::text AS o FROM pg_proc p
         WHERE p.prosrc ~* '(^|[^a-z_])getnearbygames\s*\(' AND p.proname <> 'getnearbygames'
        UNION ALL
        SELECT schemaname || '.' || viewname FROM pg_views
         WHERE definition ~* '(^|[^a-z_])getnearbygames\s*\(' AND schemaname !~ '^pg_temp') s;

SELECT case_id, CASE WHEN pass THEN 'PASS' ELSE 'FAIL' END AS result, detail FROM k855_res ORDER BY case_id;

DO $v$
DECLARE n int;
BEGIN
  SELECT count(*) INTO n FROM k855_res WHERE NOT pass;
  IF n > 0 THEN RAISE EXCEPTION 'KAN-855: % case(s) FAIL', n; END IF;
  RAISE NOTICE 'KAN-855: ALL PASS (% cases)', (SELECT count(*) FROM k855_res);
END $v$;
ROLLBACK;
