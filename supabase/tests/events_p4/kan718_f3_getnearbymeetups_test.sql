-- KAN-856 (KAN-718 F3) probe: public.getnearbymeetups(float8, float8, float8) reads no KAN-719 Z01 slated column,
-- returns the events-based answer, and keeps its signature. Migration: 20261104112200_kan718_f3_getnearbymeetups.sql.
--
-- LOCAL THROWAWAY PG16 ONLY (refuses any database not named k856*, and anything that looks like Supabase).
-- Output is TAP (plan + ok / not ok lines), so it runs under a TAP harness without the pgTAP extension:
--   prove -v --exec 'psql -X -q -tA -h /tmp -p <port> -U postgres -d k856 -f' supabase/tests/events_p4/kan718_f3_getnearbymeetups_test.sql
--
-- CHAIN (tracked files only, as supabase/tests/events_p4/build_kan851.sh: bootstrap superuser pgboot, owner postgres):
--   events_p1/local_harness_kan711.sql, events_p1/local_seed_kan711.sql, events_p2/local_harness_kan712.sql,
--   events_p2_kan713/local_harness_kan713.sql, events_p2_kan714/local_harness_kan714.sql, then migrations
--   20261101140000, 20261102110000, 20261102120000 (+ CALL kan711_events_backfill_run(); kan711_events_validate_links()),
--   20261103100000, and with postgres NOSUPERUSER BYPASSRLS: 20261103104000, 20261103105000, 20261103110000.
--   Then the PRE-IMAGE, verbatim from the repo: SET check_function_bodies = false; + baseline 20260829080500:7850-7874.
--   (No harness defines getnearbymeetups; the baseline is its only repo definition.)
--
-- RUN ORDER:
--   1. psql -v mode=stub -f <this file>   once: installs the local PostGIS geography stub (below). The harness
--      stubs geometry only; the migration's LANGUAGE sql body is validated at CREATE, so geography, st_makepoint,
--      st_setsrid, st_distance and st_dwithin must exist before it is applied.
--   2. TAP run (no mode)                  RED: on the pre-image, T3-T8 fail.
--   3. apply 20261104112200_kan718_f3_getnearbymeetups.sql (as postgres).
--   4. TAP run (no mode)                  GREEN: all pass.
--
-- Tests (one transaction, ROLLBACK at the end; no data survives):
--   T1 identity arguments and result are exactly the pre-image's.
--   T2 SECURITY DEFINER (events is FORCE RLS, no client grant: see the migration header), STABLE, sql,
--      search_path=public, pg_temp.
--   T3 body scan: no read of a Z01-slated meetups column through alias m (the three retained columns
--      description, location_name, is_indoor are allowed), no public.games, no public.geolocations.
--   T4 Z01 simulation: every Z01-slated column of meetups (21) and games (23) RENAMED inside a subtransaction
--      (no DROP), then the function is called. Any read of a slated column raises 42703 and fails the test.
--   T5 result set at the seeded point (lat 25.2, lng 55.27, radius 10 km) equals the independent events answer:
--      meetups whose events parent is not cancelled, starts in the future, has a geo location and passes
--      can_view_owner for the caller (here no JWT: the anonymous identity).
--   T6 radius: geo location d2 moved 1 degree north (~111 km); 10 km returns only the d1 rows, 200 km returns
--      all, d1 rows first (distance order).
--   T7 lat / lng are the location's y / x.
--   T8 anon and authenticated can still EXECUTE; as role anon (no JWT) the result is exactly the eligible
--      'public' meetups (no hidden / circle / link / invite row leaks).
--   T9 as role authenticated with the JWT sub of a hidden meetup's creator, that meetup is returned; as anon it
--      is not.
\set ON_ERROR_STOP 1
\pset pager off
\if :{?mode}
\else
  \set mode tap
\endif
DO $g$ BEGIN
  IF current_database() NOT LIKE 'k856%' THEN RAISE EXCEPTION 'kan856 test: database % is not k856*; refusing', current_database(); END IF;
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'supabase_admin')
     OR EXISTS (SELECT 1 FROM pg_namespace WHERE nspname IN ('storage', 'realtime', 'supabase_functions')) THEN
    RAISE EXCEPTION 'kan856 test: this looks like a Supabase database; refusing';
  END IF;
END $g$;

SELECT :'mode' = 'stub' AS k856_stub \gset
\if :k856_stub
-- Local PostGIS geography stub. geometry is the harness composite (x = lng, y = lat). Distance is haversine metres.
CREATE DOMAIN public.geography AS public.geometry;
CREATE FUNCTION public.st_makepoint(double precision, double precision) RETURNS public.geometry
  LANGUAGE sql IMMUTABLE AS $$ SELECT ROW($1, $2)::public.geometry $$;
CREATE FUNCTION public.st_setsrid(public.geometry, integer) RETURNS public.geometry
  LANGUAGE sql IMMUTABLE AS $$ SELECT $1 $$;
CREATE FUNCTION public.st_distance(public.geometry, public.geometry) RETURNS double precision
  LANGUAGE sql IMMUTABLE AS $$
  SELECT 2 * 6371008.8 * asin(sqrt(power(sin(radians(($2).y - ($1).y) / 2), 2)
         + cos(radians(($1).y)) * cos(radians(($2).y)) * power(sin(radians(($2).x - ($1).x) / 2), 2))) $$;
CREATE FUNCTION public.st_dwithin(public.geometry, public.geometry, double precision) RETURNS boolean
  LANGUAGE sql IMMUTABLE AS $$ SELECT public.st_distance($1, $2) <= $3 $$;
\echo kan856 stub installed
\quit
\endif

BEGIN;
SET LOCAL TimeZone = 'UTC';
CREATE TEMP TABLE tap (n int PRIMARY KEY, ok boolean NOT NULL, descr text NOT NULL, detail text);
GRANT INSERT, SELECT, UPDATE ON tap TO anon;

DO $pre$ BEGIN
  IF to_regtype('public.geography') IS NULL THEN
    RAISE EXCEPTION 'kan856 test: geography stub absent; run with -v mode=stub first';
  END IF;
END $pre$;

-- T1 signature
INSERT INTO tap
SELECT 1,
       coalesce(pg_get_function_identity_arguments(p.oid) = 'p_lat double precision, p_lng double precision, p_radius double precision'
                AND pg_get_function_arguments(p.oid) = 'p_lat double precision, p_lng double precision, p_radius double precision DEFAULT 10000'
                AND pg_get_function_result(p.oid) = 'TABLE(id uuid, title text, starts_at timestamp with time zone, lat double precision, lng double precision, areaid uuid, distance_m double precision)', false),
       'signature unchanged (identity args, defaults, RETURNS TABLE)',
       coalesce(pg_get_function_arguments(p.oid) || ' -> ' || pg_get_function_result(p.oid), 'function absent')
  FROM (SELECT to_regprocedure('public.getnearbymeetups(double precision,double precision,double precision)') AS oid) p;

-- T2 attributes
INSERT INTO tap
SELECT 2,
       coalesce(p.prosecdef AND p.provolatile = 's' AND l.lanname = 'sql'
                AND p.proconfig::text = '{"search_path=public, pg_temp"}', false),
       'SECURITY DEFINER, STABLE, sql, search_path public, pg_temp',
       format('secdef=%s volatile=%s lang=%s config=%s', p.prosecdef, p.provolatile, l.lanname, p.proconfig)
  FROM pg_proc p JOIN pg_language l ON l.oid = p.prolang
 WHERE p.oid = 'public.getnearbymeetups(double precision,double precision,double precision)'::regprocedure;

-- T3 body scan
WITH src AS (
  SELECT prosrc AS s FROM pg_proc
   WHERE oid = 'public.getnearbymeetups(double precision,double precision,double precision)'::regprocedure
), hits AS (
  SELECT m[1] AS hit FROM src, regexp_matches(src.s,
    '\m(m\.(creator_profile_id|creator_user_id|title|listing_visibility|rsvp_policy|capacity|start_at|end_at|is_cancelled|created_at|updated_at|search_tsv|geo_location_id|sport_id|area_id|venue_id|min_skill|max_skill|joining_rule|cost_cover|request_id)|public\.games|public\.geolocations)\M', 'gi') m
)
INSERT INTO tap
SELECT 3, NOT EXISTS (SELECT 1 FROM hits),
       'body reads no Z01-slated meetups column, no games, no geolocations',
       (SELECT 'hits: ' || string_agg(DISTINCT hit, ', ') FROM hits);

-- T4 Z01 simulation (renames, never DROP; undone by the subtransaction)
DO $t4$
DECLARE
  c text;
  v_err text;
  v_n bigint;
BEGIN
  BEGIN
    FOREACH c IN ARRAY ARRAY['creator_profile_id','creator_user_id','title','listing_visibility','rsvp_policy','capacity',
      'start_at','end_at','is_cancelled','created_at','updated_at','search_tsv','geo_location_id','sport_id','area_id',
      'venue_id','min_skill','max_skill','joining_rule','cost_cover','request_id'] LOOP
      EXECUTE format('ALTER TABLE public.meetups RENAME COLUMN %I TO %I', c, 'z01_' || c);
    END LOOP;
    FOREACH c IN ARRAY ARRAY['title','creator_profile_id','creator_user_id','start_at','end_at','capacity',
      'listing_visibility','join_policy','min_skill','max_skill','is_cancelled','cancelled_at','cancelled_reason',
      'created_at','updated_at','search_tsv','sport_id','geo_location_id','area_id','venue_id','joining_rule',
      'cost_cover','request_id'] LOOP
      EXECUTE format('ALTER TABLE public.games RENAME COLUMN %I TO %I', c, 'z01_' || c);
    END LOOP;
    SELECT count(*) INTO v_n FROM public.getnearbymeetups(25.2, 55.27, 10000);
    RAISE EXCEPTION 'k856_t4_ok:%', v_n;
  EXCEPTION WHEN OTHERS THEN
    v_err := SQLSTATE || ' ' || SQLERRM;
  END;
  INSERT INTO tap VALUES (4, v_err LIKE 'P0001 k856\_t4\_ok:%' AND split_part(v_err, ':', 2)::bigint > 0,
    'runs with every Z01-slated meetups (21) and games (23) column renamed away, and returns rows', v_err);
END $t4$;

-- T5 result set at the seeded point equals the independent events answer
DO $t5$
DECLARE
  v_got text; v_exp text; v_n bigint; v_err text;
BEGIN
  BEGIN
    SELECT md5(string_agg(concat_ws('|', r.id, r.title, r.starts_at, r.areaid), ',' ORDER BY r.id)), count(*)
      INTO v_got, v_n FROM public.getnearbymeetups(25.2, 55.27, 10000) r;
  EXCEPTION WHEN OTHERS THEN v_err := SQLSTATE || ' ' || SQLERRM;
  END;
  SELECT md5(string_agg(concat_ws('|', m.id, e.title, e.start_at, e.area_id), ',' ORDER BY m.id))
    INTO v_exp
    FROM public.meetups m JOIN public.events e ON e.id = m.event_id AND e.event_type = 'meetup'
   WHERE NOT e.is_cancelled AND e.start_at > now() AND e.geo_location_id IS NOT NULL
     AND public.can_view_owner(e.creator_user_id, e.listing_visibility);
  INSERT INTO tap VALUES (5, v_err IS NULL AND v_n > 0 AND v_got = v_exp,
    'result set equals events: not cancelled, future, located (id, title, starts_at, areaid)',
    coalesce(v_err, format('rows=%s got=%s expected=%s', v_n, v_got, v_exp)));
END $t5$;

-- T6 radius and distance order (d2 moved ~111 km north; undone at ROLLBACK)
UPDATE public.geo_locations SET location = ROW(55.27, 26.2)::public.geometry
 WHERE id = '00000000-0000-0000-0000-0000000000d2';
DO $t6$
DECLARE
  v_near bigint; v_far bigint; v_exp_d1 bigint; v_exp_all bigint; v_ordered boolean; v_err text;
BEGIN
  BEGIN
    SELECT count(*) INTO v_near FROM public.getnearbymeetups(25.2, 55.27, 10000);
    SELECT count(*), bool_and(ok) INTO v_far, v_ordered FROM (
      SELECT (lag(distance_m) OVER (ORDER BY ord) IS NULL OR lag(distance_m) OVER (ORDER BY ord) <= distance_m) AS ok
        FROM public.getnearbymeetups(25.2, 55.27, 200000) WITH ORDINALITY AS r(id, title, starts_at, lat, lng, areaid, distance_m, ord)
    ) x;
  EXCEPTION WHEN OTHERS THEN v_err := SQLSTATE || ' ' || SQLERRM;
  END;
  SELECT count(*) FILTER (WHERE e.geo_location_id = '00000000-0000-0000-0000-0000000000d1'),
         count(*) FILTER (WHERE e.geo_location_id IS NOT NULL)
    INTO v_exp_d1, v_exp_all
    FROM public.meetups m JOIN public.events e ON e.id = m.event_id AND e.event_type = 'meetup'
   WHERE NOT e.is_cancelled AND e.start_at > now() AND public.can_view_owner(e.creator_user_id, e.listing_visibility);
  INSERT INTO tap VALUES (6, v_err IS NULL AND v_near = v_exp_d1 AND v_far = v_exp_all AND v_exp_d1 < v_exp_all AND v_ordered,
    'radius filters (10 km: d1 only; 200 km: all) and rows come in distance order',
    coalesce(v_err, format('near=%s exp_d1=%s far=%s exp_all=%s ordered=%s', v_near, v_exp_d1, v_far, v_exp_all, v_ordered)));
END $t6$;

-- T7 lat / lng
DO $t7$
DECLARE v_bad bigint; v_n bigint; v_err text;
BEGIN
  BEGIN
    SELECT count(*) FILTER (WHERE NOT (abs(r.lat - 25.2) < 1e-9 AND abs(r.lng - 55.27) < 1e-9 AND r.distance_m < 1e-6)
                             AND NOT (abs(r.lat - 26.2) < 1e-9 AND abs(r.lng - 55.27) < 1e-9)), count(*)
      INTO v_bad, v_n FROM public.getnearbymeetups(25.2, 55.27, 200000) r;
  EXCEPTION WHEN OTHERS THEN v_err := SQLSTATE || ' ' || SQLERRM;
  END;
  INSERT INTO tap VALUES (7, v_err IS NULL AND v_n > 0 AND v_bad = 0, 'lat / lng are the location y / x',
    coalesce(v_err, format('rows=%s bad=%s', v_n, v_bad)));
END $t7$;

-- T8 access unchanged: anon / authenticated EXECUTE, and the call runs as anon
INSERT INTO tap
SELECT 8, has_function_privilege('anon', 'public.getnearbymeetups(double precision,double precision,double precision)', 'EXECUTE')
          AND has_function_privilege('authenticated', 'public.getnearbymeetups(double precision,double precision,double precision)', 'EXECUTE'),
       'anon and authenticated can EXECUTE; as anon exactly the eligible public meetups', NULL;
SELECT count(*) AS k856_exp_public, string_agg(m.id::text, ',' ORDER BY m.id) AS k856_exp_public_ids
  FROM public.meetups m JOIN public.events e ON e.id = m.event_id AND e.event_type = 'meetup'
 WHERE NOT e.is_cancelled AND e.start_at > now() AND e.listing_visibility = 'public'
   AND e.geo_location_id = '00000000-0000-0000-0000-0000000000d1' \gset
SELECT m.id AS k856_hidden_id, e.creator_user_id AS k856_hidden_owner
  FROM public.meetups m JOIN public.events e ON e.id = m.event_id AND e.event_type = 'meetup'
 WHERE NOT e.is_cancelled AND e.start_at > now() AND e.listing_visibility = 'hidden'
   AND e.geo_location_id = '00000000-0000-0000-0000-0000000000d1'
 ORDER BY m.id LIMIT 1 \gset
SELECT set_config('k856.exp_public', :'k856_exp_public', true), set_config('k856.exp_public_ids', :'k856_exp_public_ids', true),
       set_config('k856.hidden_id', :'k856_hidden_id', true), set_config('k856.hidden_owner', :'k856_hidden_owner', true) \g /dev/null
INSERT INTO tap VALUES (9, false, 'hidden meetup: returned to its creator (authenticated), not to anon', NULL);
SET LOCAL ROLE anon;
DO $t8$
DECLARE v_err text; v_n bigint; v_ids text; v_hidden boolean;
BEGIN
  PERFORM set_config('request.jwt.claim.sub', '', true);
  BEGIN
    SELECT count(*), string_agg(r.id::text, ',' ORDER BY r.id), bool_or(r.id = current_setting('k856.hidden_id')::uuid)
      INTO v_n, v_ids, v_hidden FROM public.getnearbymeetups(25.2, 55.27, 10000) r;
  EXCEPTION WHEN OTHERS THEN v_err := SQLSTATE || ' ' || SQLERRM;
  END;
  IF v_err IS NOT NULL THEN
    UPDATE tap SET ok = false, detail = 'anon call: ' || v_err WHERE n IN (8, 9);
  ELSE
    UPDATE tap SET ok = ok AND v_n > 0 AND v_n = current_setting('k856.exp_public')::bigint
                       AND v_ids = current_setting('k856.exp_public_ids'),
                   detail = format('anon rows=%s expected public=%s ids_equal=%s', v_n, current_setting('k856.exp_public'),
                                   v_ids = current_setting('k856.exp_public_ids'))
     WHERE n = 8;
    UPDATE tap SET detail = format('anon sees hidden=%s', coalesce(v_hidden, false)), ok = NOT coalesce(v_hidden, false) WHERE n = 9;
  END IF;
END $t8$;
RESET ROLE;
GRANT SELECT, UPDATE ON tap TO authenticated;
SET LOCAL ROLE authenticated;
DO $t9$
DECLARE v_err text; v_hidden boolean;
BEGIN
  PERFORM set_config('request.jwt.claim.sub', current_setting('k856.hidden_owner'), true);
  BEGIN
    SELECT bool_or(r.id = current_setting('k856.hidden_id')::uuid) INTO v_hidden
      FROM public.getnearbymeetups(25.2, 55.27, 10000) r;
  EXCEPTION WHEN OTHERS THEN v_err := SQLSTATE || ' ' || SQLERRM;
  END;
  PERFORM set_config('request.jwt.claim.sub', '', true);
  UPDATE tap SET ok = ok AND v_err IS NULL AND coalesce(v_hidden, false),
                 detail = detail || '; ' || coalesce('owner call: ' || v_err, format('owner sees hidden=%s', coalesce(v_hidden, false)))
   WHERE n = 9;
END $t9$;
RESET ROLE;

\echo 1..9
SELECT CASE WHEN ok THEN 'ok ' ELSE 'not ok ' END || n || ' - ' || descr
       || CASE WHEN detail IS NOT NULL THEN ' # ' || replace(detail, E'\n', ' ') ELSE '' END
  FROM tap ORDER BY n;
ROLLBACK;
