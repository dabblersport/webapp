-- KAN-943: app users can post about a game they are allowed to see.
-- No SELECT policy on public.games. trgfn_posts_set_geo keeps its RLS probe (service_role/postgres
-- path unchanged) and, for a caller RLS hides the games row from, gates on _can_view_game
-- (same predicate as v_game_card) and reads geo through a SECURITY DEFINER helper.
-- A game the caller cannot see still raises P0001 game_not_found.

DO $guard$
BEGIN
  IF (SELECT md5(prosrc) FROM pg_proc WHERE oid = 'public.trgfn_posts_set_geo()'::regprocedure)
     <> 'cfdcaddff22d7ec82594f6448bccc1f4' THEN
    RAISE EXCEPTION 'KAN-943 pre-image guard: trgfn_posts_set_geo changed since KAN-936';
  END IF;
END
$guard$;

CREATE FUNCTION public.kan943_visible_game_geo(p_game_id uuid)
 RETURNS TABLE(geo_location_id uuid, area_id uuid)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  -- KAN-943: geo of a game only when the caller may see it (_can_view_game = v_game_card predicate).
  SELECT f.geo_location_id, f.area_id
    FROM public.kan804_game_event_facts(p_game_id) f
   WHERE public._can_view_game(p_game_id);
$function$;

ALTER FUNCTION public.kan943_visible_game_geo(uuid) OWNER TO postgres;
REVOKE ALL ON FUNCTION public.kan943_visible_game_geo(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.kan943_visible_game_geo(uuid) TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.trgfn_posts_set_geo()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_geo_id  uuid;
  v_area_id uuid;
  v_lat     double precision;
  v_lng     double precision;
  v_game_visible boolean;
BEGIN
  -- KAN-804: games RLS gate as the calling role; geo/area come from events only for a caller that sees the game.
  PERFORM 1 FROM public.games g WHERE g.id = NEW.game_id;
  v_game_visible := FOUND;

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
    IF v_game_visible THEN
      SELECT f.geo_location_id, f.area_id,
             ST_Y(gl.location::geometry), ST_X(gl.location::geometry)
      INTO NEW.geo_location_id, NEW.area_id, NEW.geo_lat, NEW.geo_lng
      FROM public.kan804_game_event_facts(NEW.game_id) f
      JOIN geo_locations gl ON gl.id = f.geo_location_id;
    ELSIF public._can_view_game(NEW.game_id) THEN
      -- KAN-943: an app user RLS hides games from, but who may see this game (v_game_card predicate).
      SELECT f.geo_location_id, f.area_id,
             ST_Y(gl.location::geometry), ST_X(gl.location::geometry)
      INTO NEW.geo_location_id, NEW.area_id, NEW.geo_lat, NEW.geo_lng
      FROM public.kan943_visible_game_geo(NEW.game_id) f
      JOIN geo_locations gl ON gl.id = f.geo_location_id;
    ELSE
      -- KAN-936: the caller cannot see the game (or it does not exist); refuse clearly instead
      -- of leaving geo_lat NULL for the NOT NULL check (23502).
      RAISE EXCEPTION USING errcode = 'P0001', message = 'game_not_found';
    END IF;

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
$function$;

-- Post-asserts: attributes and ACL of both functions.
DO $post$
DECLARE r record;
BEGIN
  SELECT prosecdef, proconfig, proacl::text acl, pg_get_userbyid(proowner) own INTO r
    FROM pg_proc WHERE oid = 'public.trgfn_posts_set_geo()'::regprocedure;
  IF r.prosecdef OR r.proconfig <> ARRAY['search_path=public, pg_temp'] OR r.own <> 'postgres'
     OR r.acl <> '{postgres=X/postgres,service_role=X/postgres}' THEN
    RAISE EXCEPTION 'KAN-943 post-assert trgfn_posts_set_geo: % % % %', r.prosecdef, r.proconfig, r.acl, r.own;
  END IF;
  SELECT prosecdef, proconfig, proacl::text acl, pg_get_userbyid(proowner) own INTO r
    FROM pg_proc WHERE oid = 'public.kan943_visible_game_geo(uuid)'::regprocedure;
  IF NOT r.prosecdef OR r.proconfig <> ARRAY['search_path=public, pg_temp'] OR r.own <> 'postgres'
     OR r.acl <> '{postgres=X/postgres,authenticated=X/postgres,service_role=X/postgres}' THEN
    RAISE EXCEPTION 'KAN-943 post-assert kan943_visible_game_geo: % % % %', r.prosecdef, r.proconfig, r.acl, r.own;
  END IF;
END
$post$;
