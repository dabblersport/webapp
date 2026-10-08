-- Venues listing match (Listings.dc.html VENUES): cover, aggregate rating, badges inputs,
-- open-now, amenities and all sports on both the view path and the nearby RPC, plus
-- RPC filters and sorts (distance / rating / price).
-- Security is unchanged: view stays security_invoker, RPC stays SECURITY INVOKER with
-- search_path public,pg_temp, anon+authenticated+service_role keep EXECUTE/SELECT.

-- 1. Open now, computed in the venue's own timezone from opening_hours.
--    day_group: weekdays = Mon-Thu, fri, sat, sun. A window whose close <= open runs past
--    midnight. A previous day's overnight spill into today is not counted.
CREATE OR REPLACE FUNCTION public.venue_is_open_now(p_venue_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SET search_path TO 'public', 'pg_temp'
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM   venues v
    JOIN   opening_hours oh ON oh.venue_id = v.id
    WHERE  v.id = p_venue_id
      AND  COALESCE(oh.is_open, true)
      AND  NOT COALESCE(oh.is_closed, false)
      AND  oh.open_time IS NOT NULL
      AND  oh.close_time IS NOT NULL
      AND  oh.day_group = CASE extract(isodow FROM (now() AT TIME ZONE COALESCE(v.timezone, 'Asia/Dubai')))
                            WHEN 5 THEN 'fri'
                            WHEN 6 THEN 'sat'
                            WHEN 7 THEN 'sun'
                            ELSE 'weekdays'
                          END
      AND  CASE
             WHEN oh.open_time < oh.close_time
               THEN (now() AT TIME ZONE COALESCE(v.timezone, 'Asia/Dubai'))::time >= oh.open_time
                AND (now() AT TIME ZONE COALESCE(v.timezone, 'Asia/Dubai'))::time <  oh.close_time
             ELSE (now() AT TIME ZONE COALESCE(v.timezone, 'Asia/Dubai'))::time >= oh.open_time
               OR (now() AT TIME ZONE COALESCE(v.timezone, 'Asia/Dubai'))::time <  oh.close_time
           END
  );
$$;

GRANT EXECUTE ON FUNCTION public.venue_is_open_now(uuid) TO anon, authenticated, service_role;

-- 2. View: existing columns keep their order; new ones are appended.
CREATE OR REPLACE VIEW public.v_venues_with_sports WITH (security_invoker = true) AS
 SELECT v.id,
    vs.sport_id,
    v.name_en,
    v.name_ar,
    a.city,
    COALESCE(a.name, v.area) AS area,
    v.is_active,
    vs.indoor AS is_indoor,
    min(vs.price_per_hour) AS price_per_hour,
    v.lat AS latitude,
    v.lng AS longitude,
    v.address_en AS address,
    v.phone AS phone_number,
    v.description_en AS description,
    v.amenities,
    v.app_rating AS composite_score,
    v.created_at,
    (SELECT p.url FROM venue_photos p WHERE p.venue_id = v.id
       ORDER BY p.sort_order, p.created_at LIMIT 1) AS cover_url,
    (SELECT r.composite_score FROM venue_rating_aggregate r WHERE r.venue_id = v.id) AS rating,
    COALESCE((SELECT r.event_count FROM venue_rating_aggregate r WHERE r.venue_id = v.id), 0) AS rating_count,
    COALESCE(v.is_verified, false) AS is_verified,
    public.venue_is_open_now(v.id) AS is_open_now,
    COALESCE((SELECT array_agg(DISTINCT s.name_en) FILTER (WHERE s.name_en IS NOT NULL)
                FROM venue_spaces x JOIN sports s ON s.id = x.sport_id
               WHERE x.venue_id = v.id AND x.is_active), '{}'::text[]) AS sports,
    COALESCE((SELECT array_agg(DISTINCT COALESCE(s.name_ar, s.name_en)) FILTER (WHERE s.name_en IS NOT NULL)
                FROM venue_spaces x JOIN sports s ON s.id = x.sport_id
               WHERE x.venue_id = v.id AND x.is_active), '{}'::text[]) AS sports_ar
   FROM venues v
     JOIN venue_spaces vs ON vs.venue_id = v.id AND vs.is_active = true
     LEFT JOIN areas a ON a.id = v.area_id
  GROUP BY v.id, vs.sport_id, v.name_en, v.name_ar, a.city, a.name, v.area, v.is_active, vs.indoor,
           v.lat, v.lng, v.address_en, v.phone, v.description_en, v.amenities, v.app_rating,
           v.created_at, v.is_verified;

ALTER VIEW public.v_venues_with_sports OWNER TO postgres;
GRANT SELECT, REFERENCES, TRIGGER, MAINTAIN ON TABLE public.v_venues_with_sports TO anon, authenticated;
GRANT ALL ON TABLE public.v_venues_with_sports TO service_role;

-- 3. Nearby RPC: new return columns, filters and sorts. The old 5-argument signature is replaced.
DROP FUNCTION IF EXISTS public.rpc_get_nearby_venues(double precision, double precision, integer, uuid, text);

CREATE FUNCTION public.rpc_get_nearby_venues(
  p_lat double precision,
  p_lng double precision,
  p_radius_meters integer DEFAULT 10000,
  p_sport_id uuid DEFAULT NULL::uuid,
  p_sort text DEFAULT 'distance'::text,
  p_indoor boolean DEFAULT NULL::boolean,
  p_max_price numeric DEFAULT NULL::numeric,
  p_min_rating numeric DEFAULT NULL::numeric
) RETURNS TABLE(
  id uuid, name_en text, name_ar text, city text, area text, is_indoor boolean,
  price_per_hour numeric, latitude double precision, longitude double precision,
  distance_meters double precision, sport_names text[],
  cover_url text, rating numeric, rating_count integer, is_verified boolean,
  is_open_now boolean, amenities text[], sports text[], sports_ar text[]
)
LANGUAGE sql
STABLE
SET search_path TO 'public', 'pg_temp'
AS $function$
  WITH origin AS (
    SELECT ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326)::geography AS g
  ),
  base AS (
    SELECT
      v.id,
      v.name_en,
      v.name_ar,
      a.city                          AS city,
      a.name                          AS area,
      bool_or(vs.indoor)              AS is_indoor,
      min(vs.price_per_hour)          AS price_per_hour,
      ST_Y(gl.location::geometry)     AS latitude,
      ST_X(gl.location::geometry)     AS longitude,
      ST_Distance(gl.location, (SELECT g FROM origin)) AS distance_meters,
      COALESCE(array_agg(DISTINCT s.name_en) FILTER (WHERE s.name_en IS NOT NULL), '{}'::text[]) AS sports,
      COALESCE(array_agg(DISTINCT COALESCE(s.name_ar, s.name_en)) FILTER (WHERE s.name_en IS NOT NULL), '{}'::text[]) AS sports_ar,
      v.amenities,
      COALESCE(v.is_verified, false)  AS is_verified,
      vra.composite_score             AS rating,
      COALESCE(vra.event_count, 0)    AS rating_count
    FROM   venues v
    JOIN   geo_locations gl ON v.geo_location_id = gl.id
    LEFT   JOIN areas a          ON v.area_id = a.id
    LEFT   JOIN venue_spaces vs  ON vs.venue_id = v.id AND vs.is_active = true
    LEFT   JOIN sports s         ON s.id = vs.sport_id
    LEFT   JOIN venue_rating_aggregate vra ON vra.venue_id = v.id
    WHERE  v.is_active = true
      AND  ST_DWithin(gl.location, (SELECT g FROM origin), p_radius_meters)
      AND  (p_sport_id IS NULL OR EXISTS (
             SELECT 1 FROM venue_spaces vs2
             WHERE  vs2.venue_id = v.id AND vs2.sport_id = p_sport_id AND vs2.is_active = true))
      AND  (p_indoor IS NULL OR EXISTS (
             SELECT 1 FROM venue_spaces vs3
             WHERE  vs3.venue_id = v.id AND vs3.is_active = true AND vs3.indoor = p_indoor))
      AND  (p_min_rating IS NULL OR COALESCE(vra.composite_score, 0) >= p_min_rating)
    GROUP  BY v.id, v.name_en, v.name_ar, a.city, a.name, gl.location, v.amenities, v.is_verified,
              vra.composite_score, vra.event_count
    HAVING p_max_price IS NULL OR min(vs.price_per_hour) <= p_max_price
  )
  SELECT
    b.id, b.name_en, b.name_ar, b.city, b.area, b.is_indoor, b.price_per_hour,
    b.latitude, b.longitude, b.distance_meters,
    b.sports AS sport_names,
    (SELECT p.url FROM venue_photos p WHERE p.venue_id = b.id
       ORDER BY p.sort_order, p.created_at LIMIT 1) AS cover_url,
    b.rating, b.rating_count::integer, b.is_verified,
    public.venue_is_open_now(b.id) AS is_open_now,
    b.amenities, b.sports, b.sports_ar
  FROM base b
  ORDER BY
    CASE WHEN p_sort = 'distance' THEN b.distance_meters END ASC NULLS LAST,
    CASE WHEN p_sort = 'rating'   THEN b.rating END DESC NULLS LAST,
    CASE WHEN p_sort = 'price'    THEN b.price_per_hour END ASC NULLS LAST,
    b.distance_meters ASC,
    b.name_en ASC
  LIMIT 50;
$function$;

ALTER FUNCTION public.rpc_get_nearby_venues(double precision, double precision, integer, uuid, text, boolean, numeric, numeric) OWNER TO postgres;
GRANT ALL ON FUNCTION public.rpc_get_nearby_venues(double precision, double precision, integer, uuid, text, boolean, numeric, numeric) TO anon, authenticated, service_role;

-- 4. Post-conditions: fail the migration if anything the app depends on is missing or weakened.
DO $$
DECLARE
  missing text[];
BEGIN
  SELECT array_agg(c) INTO missing
  FROM unnest(ARRAY['cover_url','rating','rating_count','is_verified','is_open_now','amenities','sports','sports_ar']) c
  WHERE NOT EXISTS (SELECT 1 FROM information_schema.columns
                    WHERE table_schema='public' AND table_name='v_venues_with_sports' AND column_name=c);
  IF missing IS NOT NULL THEN RAISE EXCEPTION 'view missing columns: %', missing; END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_class WHERE oid='public.v_venues_with_sports'::regclass
                 AND reloptions @> ARRAY['security_invoker=true']) THEN
    RAISE EXCEPTION 'v_venues_with_sports lost security_invoker';
  END IF;
  IF NOT has_table_privilege('anon','public.v_venues_with_sports','SELECT')
     OR NOT has_table_privilege('authenticated','public.v_venues_with_sports','SELECT') THEN
    RAISE EXCEPTION 'view grants missing';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_proc p WHERE p.oid = 'public.rpc_get_nearby_venues(double precision,double precision,integer,uuid,text,boolean,numeric,numeric)'::regprocedure
                 AND NOT p.prosecdef AND p.proconfig @> ARRAY['search_path=public, pg_temp']) THEN
    RAISE EXCEPTION 'rpc must be SECURITY INVOKER with search_path public, pg_temp';
  END IF;
  IF NOT has_function_privilege('anon','public.rpc_get_nearby_venues(double precision,double precision,integer,uuid,text,boolean,numeric,numeric)','EXECUTE')
     OR NOT has_function_privilege('authenticated','public.rpc_get_nearby_venues(double precision,double precision,integer,uuid,text,boolean,numeric,numeric)','EXECUTE') THEN
    RAISE EXCEPTION 'rpc grants missing';
  END IF;
END $$;
