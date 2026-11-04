-- KAN-854 (KAN-718 F1): proof for supabase/migrations/20261104112200_kan718_f1_get_nearby_games.sql.
--
-- DECISION RECORDED: RETIRE get_nearby_games x2 (inventory #5 and #6). Not rewritten, and no DROP here (DROP is F8).
-- REASON: both overloads have raised 42703 (column g.lat does not exist) on every call since the baseline, because
-- public.games has no lat/lng column; the two lib/ .rpc('get_nearby_games' callers are unreachable (one sends
-- parameter names no overload has, the other sits behind a provider no screen watches); no SQL caller exists; and a
-- working rewrite would need SECURITY DEFINER over public.events (FORCE RLS, no API grant). Full evidence: the
-- migration header.
--
-- LOCAL OR DISPOSABLE DATABASES ONLY (guard below). Runs in one transaction and ROLLS BACK; it changes nothing.
-- Exit status is non-zero when any case fails.
--
-- Cases:
--   T0 both overloads exist.
--   T1 result signatures are byte-identical to the baseline (regression guard; passes before and after).
--   T2 body, volatility, security, search_path and ACL are the baseline ones: the migration replaced nothing.
--   T3 the retirement is recorded on both overloads (COMMENT 'KAN-854 RETIRED%').  RED before the migration.
--   T4 the retirement reason holds: calling each overload raises 42703 on g.lat (the code path is dead today).
--   T5 no pg_depend row ties either overload to a games column, so the retained bodies do not block Z01.
--   T6 no other function body or view in this catalogue calls get_nearby_games.
--
-- Chain (throwaway PG16 from the tracked repo files, as build_kan851.sh up to KAN-712 stage A): events_p1 harness
-- + seed, events_p2 harness, events_p2_kan713 harness, events_p2_kan714 harness, 20261101140000, 20261102110000,
-- 20261102120000 (+ backfill + validate), 20261103100000, then the PRE-IMAGE verbatim from
-- 20260829080500_baseline_schema.sql lines 7381-7463 (both functions + owner) and 35418-35426 (grants), which no
-- harness carries. Database k854 = pre-image (RED); k854_post = TEMPLATE k854 + the migration (GREEN).
--   psql -X -h /tmp -p <port> -U postgres -d k854      -v ON_ERROR_STOP=1 -f supabase/tests/events_p4/kan718_f1_get_nearby_games_test.sql
--   psql -X -h /tmp -p <port> -U postgres -d k854_post -v ON_ERROR_STOP=1 -f supabase/migrations/20261104112200_kan718_f1_get_nearby_games.sql
--   psql -X -h /tmp -p <port> -U postgres -d k854_post -v ON_ERROR_STOP=1 -f supabase/tests/events_p4/kan718_f1_get_nearby_games_test.sql
\set ON_ERROR_STOP 1
SET client_min_messages = notice;

DO $g$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'supabase_admin')
     OR EXISTS (SELECT 1 FROM pg_namespace WHERE nspname IN ('storage', 'realtime', 'supabase_functions')) THEN
    RAISE EXCEPTION 'KAN-854: this looks like a Supabase database; local or disposable database only';
  END IF;
  IF current_database() !~ '^k854' THEN
    RAISE EXCEPTION 'KAN-854: database % is not a throwaway k854 database; refusing', current_database();
  END IF;
END $g$;

BEGIN;
CREATE TEMP TABLE k854_res (case_id text, pass boolean, detail text);

CREATE TEMP VIEW k854_fn AS
SELECT v.ord, v.sig, to_regprocedure(v.sig) AS oid, v.src_md5, v.result, v.volatile
  FROM (VALUES
    (1, 'public.get_nearby_games(double precision,double precision,double precision)', 'be73f2aefdf274c057b57908203ea8e5',
     'TABLE(id uuid, title text, lat double precision, lng double precision, start_at timestamp with time zone, capacity integer, sport_id uuid, area_id uuid, distance_meters double precision)', 's'),
    (2, 'public.get_nearby_games(double precision,double precision,integer)', 'f1bd3be9053559637086fdad82dffd90',
     'TABLE(id uuid, title text, lat double precision, lng double precision, start_at timestamp with time zone, capacity integer, distance_meters double precision)', 'v')
  ) v(ord, sig, src_md5, result, volatile);

-- T0
INSERT INTO k854_res SELECT 'T0.' || ord, oid IS NOT NULL, sig FROM k854_fn;

-- T1
INSERT INTO k854_res
SELECT 'T1.' || f.ord, pg_get_function_result(f.oid) = f.result, pg_get_function_result(f.oid) FROM k854_fn f;

-- T2
INSERT INTO k854_res
SELECT 'T2.' || f.ord,
       md5(p.prosrc) = f.src_md5 AND p.provolatile = f.volatile AND NOT p.prosecdef
       AND p.proconfig = '{"search_path=public, pg_temp"}'::text[]
       AND pg_get_userbyid(p.proowner) = 'postgres'
       AND p.proacl::text = '{=X/postgres,postgres=X/postgres,anon=X/postgres,authenticated=X/postgres,service_role=X/postgres}',
       format('md5=%s vol=%s secdef=%s acl=%s', md5(p.prosrc), p.provolatile, p.prosecdef, p.proacl)
  FROM k854_fn f JOIN pg_proc p ON p.oid = f.oid;

-- T3 (RED before the migration)
INSERT INTO k854_res
SELECT 'T3.' || f.ord, coalesce(obj_description(f.oid, 'pg_proc') LIKE 'KAN-854 RETIRED%', false),
       coalesce(left(obj_description(f.oid, 'pg_proc'), 40), '<no comment>')
  FROM k854_fn f;

-- T4
DO $t4$
DECLARE st text; msg text;
BEGIN
  BEGIN
    PERFORM * FROM public.get_nearby_games(25.20::float8, 55.27::float8, 5000::float8);
    st := 'none'; msg := 'returned';
  EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS st = RETURNED_SQLSTATE, msg = MESSAGE_TEXT;
  END;
  INSERT INTO k854_res VALUES ('T4.1', st = '42703' AND msg LIKE '%g.lat%', st || ' ' || msg);
  BEGIN
    PERFORM * FROM public.get_nearby_games(25.20::float8, 55.27::float8, 5000);
    st := 'none'; msg := 'returned';
  EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS st = RETURNED_SQLSTATE, msg = MESSAGE_TEXT;
  END;
  INSERT INTO k854_res VALUES ('T4.2', st = '42703' AND msg LIKE '%g.lat%', st || ' ' || msg);
END $t4$;

-- T5
INSERT INTO k854_res
SELECT 'T5.' || f.ord,
       NOT EXISTS (SELECT 1 FROM pg_depend d
                    WHERE d.classid = 'pg_proc'::regclass AND d.objid = f.oid
                      AND d.refclassid = 'pg_class'::regclass AND d.refobjid = 'public.games'::regclass),
       'pg_depend rows on public.games'
  FROM k854_fn f;

-- T6
INSERT INTO k854_res
SELECT 'T6', count(*) = 0, coalesce(string_agg(o, ', '), 'none')
  FROM (SELECT p.oid::regprocedure::text AS o FROM pg_proc p
         WHERE p.prosrc ~ '(^|[^a-z_])get_nearby_games\s*\(' AND p.proname <> 'get_nearby_games'
        UNION ALL
        SELECT schemaname || '.' || viewname FROM pg_views
         WHERE definition ~ '(^|[^a-z_])get_nearby_games\s*\(' AND schemaname !~ '^pg_temp') s;  -- not this test's own view

SELECT case_id, CASE WHEN pass THEN 'PASS' ELSE 'FAIL' END AS result, detail FROM k854_res ORDER BY case_id;

DO $v$
DECLARE n int;
BEGIN
  SELECT count(*) INTO n FROM k854_res WHERE NOT pass;
  IF n > 0 THEN RAISE EXCEPTION 'KAN-854: % case(s) FAIL', n; END IF;
  RAISE NOTICE 'KAN-854: ALL PASS (% cases)', (SELECT count(*) FROM k854_res);
END $v$;
ROLLBACK;
