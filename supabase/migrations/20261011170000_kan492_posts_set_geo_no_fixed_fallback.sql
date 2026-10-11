-- KAN-492: feed posts show "Nad Al Sheba". NEEDS-OPS — NOT APPLIED. Authored by backend-3 (Shed),
-- who has no database access; the operations team (Memphis) applies it.
--
-- ============================== READ BEFORE APPLYING ==============================
-- 1. This replacement is authored from the BASELINE text of public.trgfn_posts_set_geo
--    (supabase/migrations/20260829080500_baseline_schema.sql:19383-19485). No later repo
--    migration redefines it (grep, 2026-10-11). The live definition could NOT be read by this
--    team. BEFORE APPLYING, ops must run
--        SELECT pg_get_functiondef('public.trgfn_posts_set_geo()'::regprocedure);
--    and compare it with the ROLLBACK text at the bottom of this file. If they differ in
--    anything but whitespace, STOP: this migration assumes no live drift and must be re-authored.
--    Also confirm: the function is NOT SECURITY DEFINER, has search_path 'public','pg_temp', owner
--    postgres; trigger trg_posts_set_geo is BEFORE INSERT OR UPDATE ON public.posts FOR EACH ROW.
-- 2. Step 1 relaxes NOT NULL on four posts columns. In the baseline, posts.area_id, geo_lat,
--    geo_lng and geo_location_id are NOT NULL — which is WHY the old trigger fabricated a place
--    (PATH 5) for a post with none. The CEO rule "no chosen place => area NULL or the author's
--    actual area" cannot hold while those columns are NOT NULL. Ops: check
--        SELECT column_name, is_nullable FROM information_schema.columns
--        WHERE table_schema='public' AND table_name='posts'
--          AND column_name IN ('area_id','geo_lat','geo_lng','geo_location_id');
--    DROP NOT NULL changes no row and drops no object. Readers that assumed non-null (feed views,
--    the app's post mapper) must tolerate NULL — the app seat (frontend-3) is handling the client.
-- 3. NO existing row is changed. No backfill, no UPDATE. CEO decision 2026-10-11.
-- ==================================================================================
--
-- Behaviour change vs baseline (everything else identical, incl. PATH 1/2/3 text):
--   (a) PATH 5 removed: no "first active area" is ever stamped and coordinates are never
--       overwritten with an area centre.
--   (b) PATH 4 (author profile coordinates) now only sets area_id to the nearest area of the
--       author's REAL profile coordinates. It no longer writes geo_lat/geo_lng, and no longer
--       inserts a geo_locations row for the profile point. Profile without coordinates => NULL.
--   (c) A client-sent area_id is respected: on INSERT a non-null NEW.area_id is kept (venue/game/
--       coordinate paths still fill geo fields, but area_id is restored to the client value);
--       on UPDATE a non-null area_id that differs from OLD.area_id is likewise kept.
--   (d) On UPDATE the geo is recomputed ONLY when venue_id, game_id, geo_lat or geo_lng changed.
--       Editing body, likes, counters etc. never re-stamps the area.

BEGIN;

-- Step 1: allow "no place" to be stored as NULL (no row is touched) ---------------------------
ALTER TABLE public.posts ALTER COLUMN area_id         DROP NOT NULL;
ALTER TABLE public.posts ALTER COLUMN geo_lat         DROP NOT NULL;
ALTER TABLE public.posts ALTER COLUMN geo_lng         DROP NOT NULL;
ALTER TABLE public.posts ALTER COLUMN geo_location_id DROP NOT NULL;

-- Step 2: replace the trigger function (CREATE OR REPLACE, no DROP; attributes as baseline) ---
CREATE OR REPLACE FUNCTION "public"."trgfn_posts_set_geo"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
DECLARE
  v_geo_id      uuid;
  v_area_id     uuid;
  v_lat         double precision;
  v_lng         double precision;
  v_client_area uuid;  -- KAN-492
BEGIN
  -- KAN-492 (d): on UPDATE only recompute when the place inputs changed.
  IF TG_OP = 'UPDATE'
     AND NEW.venue_id IS NOT DISTINCT FROM OLD.venue_id
     AND NEW.game_id  IS NOT DISTINCT FROM OLD.game_id
     AND NEW.geo_lat  IS NOT DISTINCT FROM OLD.geo_lat
     AND NEW.geo_lng  IS NOT DISTINCT FROM OLD.geo_lng THEN
    RETURN NEW;
  END IF;

  -- KAN-492 (c): remember an explicit client-sent area.
  IF TG_OP = 'INSERT' THEN
    v_client_area := NEW.area_id;
  ELSIF NEW.area_id IS DISTINCT FROM OLD.area_id THEN
    v_client_area := NEW.area_id;
  END IF;

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

  -- PATH 4 (KAN-492): no place chosen. The client's area wins; otherwise the author's REAL
  -- area from real profile coordinates; otherwise NULL. Never a fixed fallback, never writes
  -- geo_lat/geo_lng/geo_location_id. (Baseline PATH 5 "first active area" removed.)
  ELSE
    IF v_client_area IS NULL THEN
      SELECT p.latitude, p.longitude
      INTO v_lat, v_lng
      FROM profiles p
      WHERE p.id = NEW.author_profile_id
        AND p.latitude IS NOT NULL AND p.longitude IS NOT NULL;

      IF v_lat IS NOT NULL AND v_lng IS NOT NULL THEN
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
      END IF;

      NEW.area_id := v_area_id;  -- NULL when the author's area is unknown
    END IF;
  END IF;

  -- KAN-492 (c): an explicit client area is never recomputed away.
  IF v_client_area IS NOT NULL THEN
    NEW.area_id := v_client_area;
  END IF;

  RETURN NEW;
END;
$$;

ALTER FUNCTION "public"."trgfn_posts_set_geo"() OWNER TO "postgres";

COMMIT;

-- Post-apply verification (read-only), expected values in comments:
--   SELECT p.prosecdef, p.proconfig, pg_get_userbyid(p.proowner)
--     FROM pg_proc p WHERE p.oid = 'public.trgfn_posts_set_geo()'::regprocedure;
--     -- f | {search_path=public, pg_temp} | postgres
--   SELECT pg_get_functiondef('public.trgfn_posts_set_geo()'::regprocedure) ~ 'is_active = true';  -- f
--   Then run supabase/tests/kan492/probes.sql on a NON-PRODUCTION database (BEGIN/ROLLBACK).

-- ================================ ROLLBACK ======================================
-- Restoring the baseline brings back the fixed-area fallback (the bug). Restoring NOT NULL will
-- FAIL once any post was stored with NULL area/geo after this migration — that is expected; do
-- not "fix" it by backfilling without a CEO decision.
--
-- BEGIN;
-- CREATE OR REPLACE FUNCTION "public"."trgfn_posts_set_geo"() RETURNS "trigger"
--     LANGUAGE "plpgsql"
--     SET "search_path" TO 'public', 'pg_temp'
--     AS $$
-- DECLARE
--   v_geo_id  uuid;
--   v_area_id uuid;
--   v_lat     double precision;
--   v_lng     double precision;
-- BEGIN
--   -- PATH 1: Inherit from venue
--   IF NEW.venue_id IS NOT NULL THEN
--     SELECT v.geo_location_id, v.area_id,
--            ST_Y(gl.location::geometry), ST_X(gl.location::geometry)
--     INTO NEW.geo_location_id, NEW.area_id, NEW.geo_lat, NEW.geo_lng
--     FROM venues v
--     JOIN geo_locations gl ON gl.id = v.geo_location_id
--     WHERE v.id = NEW.venue_id;
--
--   -- PATH 2: Inherit from game
--   ELSIF NEW.game_id IS NOT NULL THEN
--     SELECT g.geo_location_id, g.area_id,
--            ST_Y(gl.location::geometry), ST_X(gl.location::geometry)
--     INTO NEW.geo_location_id, NEW.area_id, NEW.geo_lat, NEW.geo_lng
--     FROM games g
--     JOIN geo_locations gl ON gl.id = g.geo_location_id
--     WHERE g.id = NEW.game_id;
--
--   -- PATH 3: Manual lat/lng supplied
--   ELSIF NEW.geo_lat IS NOT NULL AND NEW.geo_lng IS NOT NULL THEN
--     v_lat := NEW.geo_lat;
--     v_lng := NEW.geo_lng;
--
--     SELECT id INTO v_area_id
--     FROM areas
--     ORDER BY ST_Distance(
--       ST_SetSRID(ST_MakePoint(v_lng, v_lat), 4326)::geography,
--       ST_SetSRID(ST_MakePoint(
--         (SELECT ST_X(location::geometry) FROM geo_locations WHERE area_id = areas.id LIMIT 1),
--         (SELECT ST_Y(location::geometry) FROM geo_locations WHERE area_id = areas.id LIMIT 1)
--       ), 4326)::geography
--     )
--     LIMIT 1;
--
--     INSERT INTO geo_locations (location, area_id, geohash)
--     VALUES (
--       ST_SetSRID(ST_MakePoint(v_lng, v_lat), 4326)::geography,
--       v_area_id,
--       encode(sha256((v_lat::text || ',' || v_lng::text)::bytea), 'hex')
--     )
--     RETURNING id INTO v_geo_id;
--
--     NEW.geo_location_id := v_geo_id;
--     NEW.area_id         := v_area_id;
--
--   -- PATH 4: Fallback to author profile's last known location
--   ELSE
--     SELECT p.latitude, p.longitude
--     INTO v_lat, v_lng
--     FROM profiles p
--     WHERE p.id = NEW.author_profile_id
--       AND p.latitude IS NOT NULL AND p.longitude IS NOT NULL;
--
--     -- PATH 5: Last resort — use the most active area's center
--     IF v_lat IS NULL THEN
--       SELECT a.center_lat, a.center_lng
--       INTO v_lat, v_lng
--       FROM areas a
--       WHERE a.is_active = true
--       ORDER BY a.is_verified DESC, a.id
--       LIMIT 1;
--     END IF;
--
--     -- Resolve nearest area
--     SELECT id INTO v_area_id
--     FROM areas
--     ORDER BY ST_Distance(
--       ST_SetSRID(ST_MakePoint(v_lng, v_lat), 4326)::geography,
--       ST_SetSRID(ST_MakePoint(
--         (SELECT ST_X(location::geometry) FROM geo_locations WHERE area_id = areas.id LIMIT 1),
--         (SELECT ST_Y(location::geometry) FROM geo_locations WHERE area_id = areas.id LIMIT 1)
--       ), 4326)::geography
--     )
--     LIMIT 1;
--
--     INSERT INTO geo_locations (location, area_id, geohash)
--     VALUES (
--       ST_SetSRID(ST_MakePoint(v_lng, v_lat), 4326)::geography,
--       v_area_id,
--       encode(sha256((v_lat::text || ',' || v_lng::text)::bytea), 'hex')
--     )
--     RETURNING id INTO v_geo_id;
--
--     NEW.geo_location_id := v_geo_id;
--     NEW.area_id         := v_area_id;
--     NEW.geo_lat         := v_lat;
--     NEW.geo_lng         := v_lng;
--   END IF;
--
--   RETURN NEW;
-- END;
-- $$;
-- ALTER FUNCTION "public"."trgfn_posts_set_geo"() OWNER TO "postgres";
-- -- Only if no NULL rows exist (check first; never backfill without a CEO decision):
-- -- ALTER TABLE public.posts ALTER COLUMN area_id SET NOT NULL;  (likewise geo_lat, geo_lng, geo_location_id)
-- COMMIT;
