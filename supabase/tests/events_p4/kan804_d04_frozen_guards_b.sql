-- KAN-804 (KAN-718 D04 blockers, frozen guards part b): local proof for
-- supabase/migrations/20261104110900_kan804_d04_blockers_frozen_guards_b.sql.
--
-- LOCAL DISPOSABLE DATABASE ONLY. The guard refuses any database whose name does not start with 'k804', anything
-- that looks like Supabase, and a non-superuser. Never point this at a hosted project.
--
-- Built on the KAN-788 local chain (supabase/tests/events_p2/build_kan788.sh, database k788 cloned to k804<x>).
-- The two trigger functions and their triggers are absent from that chain, so this file installs them itself.
-- Two phases, run in this order by the caller (the migration in between):
--
--   psql ... -d k804<x> -v ON_ERROR_STOP=1 -v phase=setup -f supabase/tests/events_p4/kan804_d04_frozen_guards_b.sql
--   psql ... -d k804<x> -v ON_ERROR_STOP=1 -f supabase/migrations/20261104110900_kan804_d04_blockers_frozen_guards_b.sql
--   [optionally KAN-719 Z01 here]
--   psql ... -d k804<x> -v ON_ERROR_STOP=1 -v phase=check -f supabase/tests/events_p4/kan804_d04_frozen_guards_b.sql
--
-- phase=setup (ONE transaction, committed, so the migration can run against it):
--   S0 local stand-ins (marked STAND-IN): posts venue/game/geo columns (baseline shape), public.kan804_frozen +
--      guard_user_not_frozen(uuid) (only if absent), the posts INSERT/SELECT grant to authenticated
--      (baseline 34975 / kan86:149). DELIBERATELY NO games SELECT policy: the baseline has none (games has RLS
--      enabled, 0 policies), and a stand-in policy would hide the very gate under test.
--   S1 the two PRE-IMAGES, VERBATIM from baseline 20260829080500 (:19384-19488, :19668-19685), their triggers
--      (:30059, :30139) and grants (:37361, :37393; 20261013135000:152,160). md5(prosrc) asserted equal to the
--      migration's pins; proacl asserted = {postgres=X/postgres,authenticated=X/postgres,service_role=X/postgres}.
--   S2 fixture check: game G1 (10000000-...-0001) has events host a1, geo d1, area c1; geo d1 = (25.2, 55.27).
--   S3 BEFORE: every case run against the pre-image as postgres, service_role and authenticated (anon for d),
--      each inside a rolled-back sub-transaction. Outcomes stored in kan804_t.result (stage 'before');
--      catalogue stored in kan804_t.cat.
-- phase=check (ONE transaction, ROLLED BACK; read-only in effect):
--   C1 no case raises 42703 (undefined_column) or 42501 (insufficient_privilege), except d where 42501 is the
--      expected answer for a client role.
--   C2 every case a*/b*: outcome = BEFORE, and = the expected matrix below.
--   C3 pg_get_functiondef of both triggers and the helper: no Z01-removed games column read through games
--      (g.<col> / games.<col>; list = 20261105100000 seq 601-623).
--   C4 catalogue: oid, signature, prosecdef, proconfig, proacl, owner, pg_get_triggerdef = BEFORE; helper is
--      STABLE, SECURITY DEFINER, search_path=public, pg_temp, owner postgres, proacl
--      {postgres=X/postgres,service_role=X/postgres}.
--   D  the helper: authenticated and anon get 42501; service_role and postgres get the G1 row. D-neg: the same
--      probe with EXECUTE temporarily granted to authenticated returns the row (the probe seen failing).
-- Expected matrix (all stages):
--   a1 roster insert a2 into G1              postgres allowed | service_role allowed | authenticated game_not_found
--   a2 same, host a1 frozen                  postgres user_frozen | service_role user_frozen | authenticated game_not_found
--   a3 same, joiner a2 frozen                user_frozen for all three (the joiner check runs first)
--   b1 post tied to G1                       postgres/service_role d1|c1|25.2|55.27 | authenticated null|null|null|null
--   b2 post tied to G1 with lat/lng 1,2      same as b1 (PATH 2 overwrites what the client sent)
-- Exit: 0 and 'KAN-804 TOTAL pass=N fail=0'; any failed check raises 'KAN-804 test FAILED'.
\set ON_ERROR_STOP 1
SET client_min_messages = notice;

DO $g$ BEGIN
  IF current_database() NOT LIKE 'k804%' THEN
    RAISE EXCEPTION 'KAN-804: refusing database %: local disposable k804* databases only', current_database();
  END IF;
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'supabase_admin')
     OR EXISTS (SELECT 1 FROM pg_namespace WHERE nspname IN ('storage', 'realtime', 'supabase_functions')) THEN
    RAISE EXCEPTION 'KAN-804: this looks like a Supabase database; local or disposable database only';
  END IF;
  IF NOT (SELECT rolsuper FROM pg_roles WHERE rolname = current_user) THEN
    RAISE EXCEPTION 'KAN-804: run as a superuser';
  END IF;
END $g$;

SELECT coalesce(:'phase', '') = 'setup' AS k804_setup, coalesce(:'phase', '') = 'check' AS k804_check \gset
\if :k804_setup
\elif :k804_check
\else
  \echo 'KAN-804: pass -v phase=setup or -v phase=check'
  SELECT 1/0;
\endif

\if :k804_setup
BEGIN;

-- ===================================================================================== S0 stand-ins
CREATE SCHEMA kan804_t;  -- fails on a second setup run: one setup per disposable database
ALTER TABLE public.posts ADD COLUMN IF NOT EXISTS venue_id uuid, ADD COLUMN IF NOT EXISTS game_id uuid,  -- STAND-IN
  ADD COLUMN IF NOT EXISTS geo_location_id uuid, ADD COLUMN IF NOT EXISTS area_id uuid,
  ADD COLUMN IF NOT EXISTS geo_lat double precision, ADD COLUMN IF NOT EXISTS geo_lng double precision;
DO $s0$
BEGIN
  IF to_regprocedure('public.guard_user_not_frozen(uuid)') IS NULL THEN  -- STAND-IN
    EXECUTE 'CREATE TABLE public.kan804_frozen (user_id uuid PRIMARY KEY)';
    EXECUTE $f$CREATE FUNCTION public.guard_user_not_frozen(p uuid) RETURNS void LANGUAGE plpgsql AS $b$
               BEGIN IF EXISTS (SELECT 1 FROM public.kan804_frozen WHERE user_id = p) THEN
                 RAISE EXCEPTION USING errcode='P0001', message='user_frozen'; END IF; END $b$$f$;
    EXECUTE 'GRANT SELECT ON public.kan804_frozen TO authenticated, service_role';
    RAISE NOTICE 'KAN-804 S0 STAND-IN created: public.kan804_frozen + public.guard_user_not_frozen(uuid)';
  ELSE
    RAISE EXCEPTION 'KAN-804 S0: a real guard_user_not_frozen exists; this harness freezes through kan804_frozen only';
  END IF;
END
$s0$;
GRANT INSERT, SELECT ON public.posts TO authenticated;   -- baseline 34975 / kan86:149

DO $s0b$ BEGIN
  IF (SELECT relrowsecurity FROM pg_class WHERE oid = 'public.games'::regclass) IS NOT TRUE
     OR EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'public.games'::regclass) THEN
    RAISE EXCEPTION 'KAN-804 S0: public.games must have RLS enabled and NO policy (baseline 32378, 0 CREATE POLICY)';
  END IF;
END $s0b$;

-- ===================================================================================== S1 pre-images, VERBATIM
-- baseline 20260829080500_baseline_schema.sql:19384-19488
CREATE OR REPLACE FUNCTION "public"."trgfn_posts_set_geo"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
DECLARE
  v_geo_id  uuid;
  v_area_id uuid;
  v_lat     double precision;
  v_lng     double precision;
BEGIN
  -- PATH 1: Inherit from venue
  IF NEW.venue_id IS NOT NULL THEN
    SELECT v.geo_location_id, v.area_id,
           ST_Y(gl.location::geometry), ST_X(gl.location::geometry)
    INTO NEW.geo_location_id, NEW.area_id, NEW.geo_lat, NEW.geo_lng
    FROM venues v
    JOIN geo_locations gl ON gl.id = v.geo_location_id
    WHERE v.id = NEW.venue_id;

  -- PATH 2: Inherit from game
  ELSIF NEW.game_id IS NOT NULL THEN
    SELECT g.geo_location_id, g.area_id,
           ST_Y(gl.location::geometry), ST_X(gl.location::geometry)
    INTO NEW.geo_location_id, NEW.area_id, NEW.geo_lat, NEW.geo_lng
    FROM games g
    JOIN geo_locations gl ON gl.id = g.geo_location_id
    WHERE g.id = NEW.game_id;

  -- PATH 3: Manual lat/lng supplied
  ELSIF NEW.geo_lat IS NOT NULL AND NEW.geo_lng IS NOT NULL THEN
    v_lat := NEW.geo_lat;
    v_lng := NEW.geo_lng;

    SELECT id INTO v_area_id
    FROM areas
    ORDER BY ST_Distance(
      ST_SetSRID(ST_MakePoint(v_lng, v_lat), 4326)::geography,
      ST_SetSRID(ST_MakePoint(
        (SELECT ST_X(location::geometry) FROM geo_locations WHERE area_id = areas.id LIMIT 1),
        (SELECT ST_Y(location::geometry) FROM geo_locations WHERE area_id = areas.id LIMIT 1)
      ), 4326)::geography
    )
    LIMIT 1;

    INSERT INTO geo_locations (location, area_id, geohash)
    VALUES (
      ST_SetSRID(ST_MakePoint(v_lng, v_lat), 4326)::geography,
      v_area_id,
      encode(sha256((v_lat::text || ',' || v_lng::text)::bytea), 'hex')
    )
    RETURNING id INTO v_geo_id;

    NEW.geo_location_id := v_geo_id;
    NEW.area_id         := v_area_id;

  -- PATH 4: Fallback to author profile's last known location
  ELSE
    SELECT p.latitude, p.longitude
    INTO v_lat, v_lng
    FROM profiles p
    WHERE p.id = NEW.author_profile_id
      AND p.latitude IS NOT NULL AND p.longitude IS NOT NULL;

    -- PATH 5: Last resort — use the most active area's center
    IF v_lat IS NULL THEN
      SELECT a.center_lat, a.center_lng
      INTO v_lat, v_lng
      FROM areas a
      WHERE a.is_active = true
      ORDER BY a.is_verified DESC, a.id
      LIMIT 1;
    END IF;

    -- Resolve nearest area
    SELECT id INTO v_area_id
    FROM areas
    ORDER BY ST_Distance(
      ST_SetSRID(ST_MakePoint(v_lng, v_lat), 4326)::geography,
      ST_SetSRID(ST_MakePoint(
        (SELECT ST_X(location::geometry) FROM geo_locations WHERE area_id = areas.id LIMIT 1),
        (SELECT ST_Y(location::geometry) FROM geo_locations WHERE area_id = areas.id LIMIT 1)
      ), 4326)::geography
    )
    LIMIT 1;

    INSERT INTO geo_locations (location, area_id, geohash)
    VALUES (
      ST_SetSRID(ST_MakePoint(v_lng, v_lat), 4326)::geography,
      v_area_id,
      encode(sha256((v_lat::text || ',' || v_lng::text)::bytea), 'hex')
    )
    RETURNING id INTO v_geo_id;

    NEW.geo_location_id := v_geo_id;
    NEW.area_id         := v_area_id;
    NEW.geo_lat         := v_lat;
    NEW.geo_lng         := v_lng;
  END IF;

  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."trgfn_posts_set_geo"() OWNER TO "postgres";
-- baseline 20260829080500_baseline_schema.sql:19668-19685
CREATE OR REPLACE FUNCTION "public"."trgfn_roster_block_frozen_guard"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
declare host_uid uuid;
begin
  perform public.guard_user_not_frozen(new.user_id);
  select g.creator_user_id into host_uid from public.games g where g.id = new.game_id;
  if host_uid is null then
    raise exception using errcode='P0001', message='game_not_found';
  end if;
  perform public.guard_user_not_frozen(host_uid);
  return new;
end;
$$;


ALTER FUNCTION "public"."trgfn_roster_block_frozen_guard"() OWNER TO "postgres";
-- baseline :30059, :30139
CREATE OR REPLACE TRIGGER "trg_posts_set_geo" BEFORE INSERT OR UPDATE ON "public"."posts" FOR EACH ROW EXECUTE FUNCTION "public"."trgfn_posts_set_geo"();
CREATE OR REPLACE TRIGGER "trg_roster_block_frozen_guard" BEFORE INSERT ON "public"."game_roster" FOR EACH ROW EXECUTE FUNCTION "public"."trgfn_roster_block_frozen_guard"();
-- 20261013135000:152,160 and baseline :37361, :37393 (authenticated=X comes from the chain's default privileges,
-- as on production; asserted below)
REVOKE EXECUTE ON FUNCTION public.trgfn_posts_set_geo() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.trgfn_roster_block_frozen_guard() FROM PUBLIC, anon;
GRANT ALL ON FUNCTION "public"."trgfn_posts_set_geo"() TO "service_role";
GRANT ALL ON FUNCTION "public"."trgfn_roster_block_frozen_guard"() TO "service_role";

DO $s1$
DECLARE v_bad text;
BEGIN
  SELECT string_agg(t.f || '=' || coalesce(md5(p.prosrc) || ' ' || p.proacl::text, 'absent'), '; ') INTO v_bad
    FROM (VALUES ('public.trgfn_roster_block_frozen_guard()', 'e9e1d50b5a46d1daefc73f295b8c0b70'),
                 ('public.trgfn_posts_set_geo()', 'a99a85249f7a15e5564a88a2afa163ba')) t(f, pin)
    LEFT JOIN pg_proc p ON p.oid = to_regprocedure(t.f)
   WHERE p.oid IS NULL OR md5(p.prosrc) <> t.pin
      OR p.proacl::text <> '{postgres=X/postgres,authenticated=X/postgres,service_role=X/postgres}';
  IF v_bad IS NOT NULL THEN
    RAISE EXCEPTION 'KAN-804 S1: pre-image md5/proacl does not match the migration pins: %', v_bad;
  END IF;
END $s1$;

-- ===================================================================================== S2 fixture check
DO $s2$
DECLARE v text;
BEGIN
  SELECT e.creator_user_id || '|' || e.geo_location_id || '|' || e.area_id || '|'
         || ST_Y(gl.location::geometry) || '|' || ST_X(gl.location::geometry) INTO v
    FROM public.games g
    JOIN public.events e ON e.id = g.event_id AND e.event_type = 'game'
    JOIN public.geo_locations gl ON gl.id = e.geo_location_id
   WHERE g.id = '10000000-0000-0000-0000-000000000001';
  IF v IS DISTINCT FROM '00000000-0000-0000-0000-0000000000a1|00000000-0000-0000-0000-0000000000d1|'
                        '00000000-0000-0000-0000-0000000000c1|25.2|55.27' THEN
    RAISE EXCEPTION 'KAN-804 S2: fixture G1 is not a1/d1/c1/25.2/55.27: %', v;
  END IF;
END $s2$;

-- ===================================================================================== case runner
CREATE TABLE kan804_t.result (stage text, kase text, role text, outcome text, PRIMARY KEY (stage, kase, role));
CREATE TABLE kan804_t.cat (stage text, item text, val text, PRIMARY KEY (stage, item));

-- One case as one role, inside a sub-transaction that is always rolled back (sentinel KAN04). Returns the outcome.
CREATE FUNCTION kan804_t.run_case(p_kase text, p_role text) RETURNS text LANGUAGE plpgsql AS $f$
DECLARE
  g1  constant uuid := '10000000-0000-0000-0000-000000000001';
  a1  constant uuid := '00000000-0000-0000-0000-0000000000a1';
  a2  constant uuid := '00000000-0000-0000-0000-0000000000a2';
  b2  constant uuid := '00000000-0000-0000-0000-0000000000b2';
  v_out text;
  r record;
BEGIN
  BEGIN
    IF p_kase = 'a2_host_frozen' THEN INSERT INTO public.kan804_frozen VALUES (a1); END IF;
    IF p_kase = 'a3_joiner_frozen' THEN INSERT INTO public.kan804_frozen VALUES (a2); END IF;
    IF p_kase = 'd_neg_granted' THEN
      EXECUTE 'GRANT EXECUTE ON FUNCTION public.kan804_game_event_facts(uuid) TO authenticated';
    END IF;
    IF p_role <> 'postgres' THEN
      PERFORM set_config('request.jwt.claim.sub', a2::text, true);
      PERFORM set_config('request.jwt.claims', json_build_object('sub', a2, 'role', p_role)::text, true);
      EXECUTE format('SET LOCAL ROLE %I', p_role);
    END IF;
    IF p_kase LIKE 'a%' THEN
      INSERT INTO public.game_roster (game_id, user_id, profile_id) VALUES (g1, a2, b2);
      v_out := 'allowed';
    ELSIF p_kase = 'b1_post' THEN
      INSERT INTO public.posts (author_profile_id, author_user_id, game_id) VALUES (b2, a2, g1)
      RETURNING geo_location_id, area_id, geo_lat, geo_lng INTO r;
      v_out := concat_ws('|', coalesce(r.geo_location_id::text, 'null'), coalesce(r.area_id::text, 'null'),
                         coalesce(r.geo_lat::text, 'null'), coalesce(r.geo_lng::text, 'null'));
    ELSIF p_kase = 'b2_post_latlng' THEN
      INSERT INTO public.posts (author_profile_id, author_user_id, game_id, geo_lat, geo_lng) VALUES (b2, a2, g1, 1, 2)
      RETURNING geo_location_id, area_id, geo_lat, geo_lng INTO r;
      v_out := concat_ws('|', coalesce(r.geo_location_id::text, 'null'), coalesce(r.area_id::text, 'null'),
                         coalesce(r.geo_lat::text, 'null'), coalesce(r.geo_lng::text, 'null'));
    ELSIF p_kase LIKE 'd%' THEN
      SELECT * INTO r FROM public.kan804_game_event_facts(g1);
      v_out := 'row:' || concat_ws('|', r.creator_user_id, r.geo_location_id, r.area_id);
    ELSE
      RAISE EXCEPTION 'KAN-804: unknown case %', p_kase;
    END IF;
    RAISE EXCEPTION USING errcode = 'KAN04', message = v_out;
  EXCEPTION
    WHEN sqlstate 'KAN04' THEN RETURN SQLERRM;
    WHEN OTHERS THEN RETURN SQLSTATE || ':' || SQLERRM;
  END;
END
$f$;

CREATE FUNCTION kan804_t.run_all(p_stage text) RETURNS void LANGUAGE plpgsql AS $f$
DECLARE k text; ro text;
BEGIN
  FOREACH k IN ARRAY array['a1_roster', 'a2_host_frozen', 'a3_joiner_frozen', 'b1_post', 'b2_post_latlng',
                           'd_helper', 'd_neg_granted'] LOOP
    FOREACH ro IN ARRAY array['postgres', 'service_role', 'authenticated', 'anon'] LOOP
      CONTINUE WHEN ro = 'anon' AND k NOT LIKE 'd%';
      CONTINUE WHEN k = 'd_neg_granted' AND ro <> 'authenticated';
      INSERT INTO kan804_t.result VALUES (p_stage, k, ro, kan804_t.run_case(k, ro));
    END LOOP;
  END LOOP;
END
$f$;

CREATE FUNCTION kan804_t.snap_cat(p_stage text) RETURNS void LANGUAGE sql AS $f$
  INSERT INTO kan804_t.cat
  SELECT p_stage, p.proname || '.' || x.k, x.v
    FROM pg_proc p
    CROSS JOIN LATERAL (VALUES
      ('oid', p.oid::text), ('md5', md5(p.prosrc)), ('prosecdef', p.prosecdef::text),
      ('provolatile', p.provolatile::text), ('proconfig', coalesce(p.proconfig::text, 'null')),
      ('proacl', coalesce(p.proacl::text, 'null')), ('owner', p.proowner::regrole::text),
      ('identity_args', pg_get_function_identity_arguments(p.oid)), ('result', pg_get_function_result(p.oid)),
      ('triggerdefs', coalesce((SELECT string_agg(pg_get_triggerdef(t.oid), ' ;; ' ORDER BY t.tgname)
                                  FROM pg_trigger t WHERE t.tgfoid = p.oid AND NOT t.tgisinternal), 'none'))) x(k, v)
   WHERE p.oid IN (SELECT to_regprocedure(f) FROM unnest(array['public.trgfn_roster_block_frozen_guard()',
                     'public.trgfn_posts_set_geo()', 'public.kan804_game_event_facts(uuid)']) f);
$f$;

-- ===================================================================================== S3 BEFORE
SELECT kan804_t.run_all('before');
SELECT kan804_t.snap_cat('before');

\echo '== S3 BEFORE outcomes (pre-image)'
SELECT kase, role, outcome FROM kan804_t.result WHERE stage = 'before' ORDER BY kase, role;
\echo '== S3 BEFORE catalogue'
SELECT item, val FROM kan804_t.cat WHERE stage = 'before' ORDER BY item;

DO $s3$
DECLARE v_bad text;
BEGIN
  SELECT string_agg(e.kase || '/' || e.role || ' got ' || coalesce(r.outcome, 'nothing') || ' want ' || e.want, '; ')
    INTO v_bad
    FROM (VALUES
      ('a1_roster', 'postgres', 'allowed'), ('a1_roster', 'service_role', 'allowed'),
      ('a1_roster', 'authenticated', 'P0001:game_not_found'),
      ('a2_host_frozen', 'postgres', 'P0001:user_frozen'), ('a2_host_frozen', 'service_role', 'P0001:user_frozen'),
      ('a2_host_frozen', 'authenticated', 'P0001:game_not_found'),
      ('a3_joiner_frozen', 'postgres', 'P0001:user_frozen'), ('a3_joiner_frozen', 'service_role', 'P0001:user_frozen'),
      ('a3_joiner_frozen', 'authenticated', 'P0001:user_frozen'),
      ('b1_post', 'postgres', '00000000-0000-0000-0000-0000000000d1|00000000-0000-0000-0000-0000000000c1|25.2|55.27'),
      ('b1_post', 'service_role', '00000000-0000-0000-0000-0000000000d1|00000000-0000-0000-0000-0000000000c1|25.2|55.27'),
      ('b1_post', 'authenticated', 'null|null|null|null'),
      ('b2_post_latlng', 'postgres', '00000000-0000-0000-0000-0000000000d1|00000000-0000-0000-0000-0000000000c1|25.2|55.27'),
      ('b2_post_latlng', 'service_role', '00000000-0000-0000-0000-0000000000d1|00000000-0000-0000-0000-0000000000c1|25.2|55.27'),
      ('b2_post_latlng', 'authenticated', 'null|null|null|null')
    ) e(kase, role, want)
    LEFT JOIN kan804_t.result r ON r.stage = 'before' AND r.kase = e.kase AND r.role = e.role
   WHERE r.outcome IS DISTINCT FROM e.want;
  IF v_bad IS NOT NULL THEN
    RAISE EXCEPTION 'KAN-804 S3: BEFORE does not match the measured pre-image matrix: %', v_bad;
  END IF;
  RAISE NOTICE 'KAN-804 S3 BEFORE matrix = measured pre-image (15 cells)';
END $s3$;

COMMIT;
\echo 'KAN-804 setup committed'
\endif

\if :k804_check
BEGIN;
CREATE TEMP TABLE kan804_chk (n serial, name text, ok boolean, detail text);

SELECT kan804_t.run_all('after');
SELECT kan804_t.snap_cat('after');

\echo '== AFTER outcomes'
SELECT a.kase, a.role, a.outcome, b.outcome AS before_outcome, a.outcome IS NOT DISTINCT FROM b.outcome AS same
  FROM kan804_t.result a LEFT JOIN kan804_t.result b ON b.stage = 'before' AND b.kase = a.kase AND b.role = a.role
 WHERE a.stage = 'after' ORDER BY a.kase, a.role;
\echo '== AFTER catalogue vs BEFORE'
SELECT a.item, b.val AS before_val, a.val AS after_val, a.val IS NOT DISTINCT FROM b.val AS same
  FROM kan804_t.cat a LEFT JOIN kan804_t.cat b ON b.stage = 'before' AND b.item = a.item
 WHERE a.stage = 'after' ORDER BY a.item;
\echo '== games columns present now'
SELECT string_agg(attname, ',' ORDER BY attnum) AS games_columns FROM pg_attribute
 WHERE attrelid = 'public.games'::regclass AND attnum > 0 AND NOT attisdropped;

DO $c$
DECLARE
  v text;
  v_def text;
  -- 20261105100000_kan719_z01_remove_replaced_columns.sql seq 601-623 (ALTER TABLE public.games DROP COLUMN ...)
  z01_cols constant text := 'title|creator_profile_id|creator_user_id|start_at|end_at|capacity|listing_visibility|'
    'join_policy|min_skill|max_skill|is_cancelled|cancelled_at|cancelled_reason|created_at|updated_at|search_tsv|'
    'sport_id|geo_location_id|area_id|venue_id|joining_rule|cost_cover|request_id';
  pm constant text := 'postgres|service_role';
  geo constant text := '00000000-0000-0000-0000-0000000000d1|00000000-0000-0000-0000-0000000000c1|25.2|55.27';
BEGIN
  -- C1: no 42703 / 42501 outside the d cases
  SELECT string_agg(kase || '/' || role || '=' || outcome, '; ') INTO v FROM kan804_t.result
   WHERE stage = 'after' AND kase NOT LIKE 'd%' AND (outcome LIKE '42703:%' OR outcome LIKE '42501:%');
  INSERT INTO kan804_chk (name, ok, detail) VALUES ('C1 no 42703/42501 in a*/b*', v IS NULL, coalesce(v, 'none'));

  -- C2: a*/b* AFTER = BEFORE
  SELECT string_agg(a.kase || '/' || a.role || ' before=' || coalesce(b.outcome, '-') || ' after=' || a.outcome, '; ')
    INTO v
    FROM kan804_t.result a LEFT JOIN kan804_t.result b ON b.stage = 'before' AND b.kase = a.kase AND b.role = a.role
   WHERE a.stage = 'after' AND a.kase NOT LIKE 'd%' AND a.outcome IS DISTINCT FROM b.outcome;
  INSERT INTO kan804_chk (name, ok, detail) VALUES ('C2 a*/b* AFTER = BEFORE (15 cells)', v IS NULL, coalesce(v, 'all equal'));

  -- C2b: explicit expected cells (so an equal-but-wrong BEFORE cannot pass)
  SELECT string_agg(kase || '/' || role || '=' || outcome, '; ') INTO v FROM kan804_t.result
   WHERE stage = 'after' AND NOT (
         (kase = 'a1_roster' AND role ~ ('^(' || pm || ')$') AND outcome = 'allowed')
      OR (kase IN ('a1_roster', 'a2_host_frozen') AND role = 'authenticated' AND outcome = 'P0001:game_not_found')
      OR (kase = 'a2_host_frozen' AND role ~ ('^(' || pm || ')$') AND outcome = 'P0001:user_frozen')
      OR (kase = 'a3_joiner_frozen' AND outcome = 'P0001:user_frozen')
      OR (kase IN ('b1_post', 'b2_post_latlng') AND role ~ ('^(' || pm || ')$') AND outcome = geo)
      OR (kase IN ('b1_post', 'b2_post_latlng') AND role = 'authenticated' AND outcome = 'null|null|null|null')
      OR (kase = 'd_helper' AND role ~ ('^(' || pm || ')$')
          AND outcome = 'row:00000000-0000-0000-0000-0000000000a1|00000000-0000-0000-0000-0000000000d1|00000000-0000-0000-0000-0000000000c1')
      OR (kase = 'd_helper' AND role IN ('authenticated', 'anon') AND outcome LIKE '42501:permission denied for function kan804_game_event_facts%')
      OR (kase = 'd_neg_granted' AND outcome LIKE 'row:00000000-0000-0000-0000-0000000000a1|%'));
  INSERT INTO kan804_chk (name, ok, detail) VALUES ('C2b/D every AFTER cell = expected matrix', v IS NULL, coalesce(v, 'all expected'));

  -- D-neg must have been seen to differ from D (the 42501 probe can fail)
  SELECT outcome INTO v FROM kan804_t.result WHERE stage = 'after' AND kase = 'd_neg_granted' AND role = 'authenticated';
  INSERT INTO kan804_chk (name, ok, detail) VALUES ('D-neg probe seen failing (granted -> row, not 42501)',
    v LIKE 'row:%', coalesce(v, 'missing'));

  -- C3: no Z01-removed games column read through games, in any of the three bodies
  SELECT string_agg(p.proname || ': ' || m[1], ', ') INTO v
    FROM pg_proc p
    CROSS JOIN LATERAL regexp_matches(pg_get_functiondef(p.oid), '\m((g|games)\.(' || z01_cols || '))\M', 'g') m
   WHERE p.oid IN (to_regprocedure('public.trgfn_roster_block_frozen_guard()'),
                   to_regprocedure('public.trgfn_posts_set_geo()'),
                   to_regprocedure('public.kan804_game_event_facts(uuid)'));
  INSERT INTO kan804_chk (name, ok, detail) VALUES ('C3 no Z01-removed games column read', v IS NULL, coalesce(v, 'none'));
  SELECT count(*)::text INTO v FROM pg_proc p
   WHERE p.oid IN (to_regprocedure('public.trgfn_roster_block_frozen_guard()'), to_regprocedure('public.trgfn_posts_set_geo()'))
     AND p.prosrc ~* 'perform 1 from public\.games g where g\.id = new\.game_id;'
     AND p.prosrc ~* 'public\.kan804_game_event_facts\(new\.game_id\) f';
  INSERT INTO kan804_chk (name, ok, detail) VALUES ('C3b both bodies gate on games and read via the helper', v = '2', v || ' of 2');

  -- C4: trigger catalogue = BEFORE except md5
  SELECT string_agg(a.item || ' before=' || coalesce(b.val, '-') || ' after=' || a.val, '; ') INTO v
    FROM kan804_t.cat a LEFT JOIN kan804_t.cat b ON b.stage = 'before' AND b.item = a.item
   WHERE a.stage = 'after' AND a.item NOT LIKE 'kan804_game_event_facts.%' AND a.item NOT LIKE '%.md5'
     AND a.val IS DISTINCT FROM b.val;
  INSERT INTO kan804_chk (name, ok, detail) VALUES ('C4 trigger fns: oid/secdef/volatile/proconfig/proacl/owner/args/result/triggerdefs = BEFORE',
    v IS NULL, coalesce(v, 'all equal'));
  SELECT string_agg(a.item || '=' || a.val, '; ') INTO v FROM kan804_t.cat a
   WHERE a.stage = 'after' AND a.item LIKE 'trgfn_%.md5'
     AND a.val IN ('e9e1d50b5a46d1daefc73f295b8c0b70', 'a99a85249f7a15e5564a88a2afa163ba');
  INSERT INTO kan804_chk (name, ok, detail) VALUES ('C4b trigger bodies replaced (md5 differs from pre-image)', v IS NULL, coalesce(v, 'both replaced'));

  -- C4c: helper attributes
  SELECT string_agg(item || '=' || val, '; ') INTO v FROM kan804_t.cat
   WHERE stage = 'after' AND item LIKE 'kan804_game_event_facts.%' AND NOT (
         (item LIKE '%.prosecdef' AND val = 'true')
      OR (item LIKE '%.provolatile' AND val = 's')
      OR (item LIKE '%.proconfig' AND val = '{"search_path=public, pg_temp"}')
      OR (item LIKE '%.proacl' AND val = '{postgres=X/postgres,service_role=X/postgres}')
      OR (item LIKE '%.owner' AND val = 'postgres')
      OR (item LIKE '%.identity_args' AND val = 'p_game_id uuid')
      OR (item LIKE '%.triggerdefs' AND val = 'none')
      OR item LIKE '%.oid' OR item LIKE '%.md5' OR item LIKE '%.result');
  INSERT INTO kan804_chk (name, ok, detail) VALUES ('C4c helper STABLE DEFINER search_path owner proacl',
    v IS NULL AND EXISTS (SELECT 1 FROM kan804_t.cat WHERE stage = 'after' AND item = 'kan804_game_event_facts.proacl'),
    coalesce(v, 'as ruled'));
END $c$;

\echo '== checks'
SELECT n, name, ok, detail FROM kan804_chk ORDER BY n;
SELECT 'KAN-804 TOTAL pass=' || count(*) FILTER (WHERE ok) || ' fail=' || count(*) FILTER (WHERE NOT ok) AS total
  FROM kan804_chk;
DO $f$ BEGIN
  IF EXISTS (SELECT 1 FROM kan804_chk WHERE NOT ok) THEN RAISE EXCEPTION 'KAN-804 test FAILED'; END IF;
END $f$;
ROLLBACK;
\endif
