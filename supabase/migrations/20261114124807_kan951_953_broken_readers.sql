-- KAN-951 / KAN-953: four broken public readers, found by KAN-948 and the KAN-866 plpgsql_check run.
--
-- Authored from the live pg_get_functiondef, 2026-11-14, project wtncuzcskpigqpmnxwws. Pre-image (functiondef md5):
--   get_nearby_games(f8,f8,int)                          c01ffbb781912708b3401b7bc2aaaca9
--   get_nearby_games(f8,f8,f8)                           3f1a5224171513a86f9c14b42c033653
--   get_home_feed(int,int)                               095afae0545a8b39ecfd308b1e02c002
--   rpc_autocomplete_entities(text,text[],text,int)      7296e86f3f4ef9cb20a83fe726912bf8
--
-- 1. KAN-951 get_nearby_games, both overloads: still named by two Dart call sites
--    (lib/data/repositories/nearby_games_repository_impl.dart:23, lib/features/games/data/datasources/
--    supabase_games_datasource.dart:666), so re-authored rather than dropped. They selected g.lat / g.lng, which
--    public.games never had (42703 for every caller). lat / lng now come from geo_locations through
--    events.geo_location_id (st_y / st_x of gl.location::geometry), as rpc_get_nearby_games reads them. Nothing
--    else changes: same signature, OUT columns, filters (the int overload keeps its missing start_at filter),
--    order, limit, SECURITY INVOKER, volatility and search_path. CREATE OR REPLACE keeps owner and ACL.
-- 2. KAN-953 DROP get_home_feed(int,int): joins post_reposts.original_post_id, which does not exist. The app calls
--    get_home_feed with p_limit / p_cursor only (feed_notifier.dart:457), which resolves to (int,timestamptz);
--    no caller in lib/, workers/, supabase/functions/ or pg_proc sends p_offset.
-- 3. KAN-953 DROP rpc_autocomplete_entities(text,text[],text,int): reads venues.district, which does not exist.
--    No caller in lib/, workers/, supabase/functions/ or pg_proc.
-- Test: supabase/tests/events_p4/kan951_953_broken_readers_live_test.sql.

do $pre$
declare
  k record;
begin
  for k in select * from (values
    ('public.get_nearby_games(double precision,double precision,integer)', 'c01ffbb781912708b3401b7bc2aaaca9'),
    ('public.get_nearby_games(double precision,double precision,double precision)', '3f1a5224171513a86f9c14b42c033653'),
    ('public.get_home_feed(integer,integer)', '095afae0545a8b39ecfd308b1e02c002'),
    ('public.rpc_autocomplete_entities(text,text[],text,integer)', '7296e86f3f4ef9cb20a83fe726912bf8')) v(fn, pre)
  loop
    if md5(pg_get_functiondef(to_regprocedure(k.fn))) is distinct from k.pre then
      raise exception 'KAN-951/953 pre: % absent or drifted', k.fn;
    end if;
  end loop;
  if exists (select 1 from pg_proc p where p.pronamespace not in ('pg_catalog'::regnamespace, 'information_schema'::regnamespace)
              and p.proname not in ('get_nearby_games', 'get_home_feed', 'rpc_autocomplete_entities')
              and p.prosrc ~ 'get_home_feed|rpc_autocomplete_entities|(^|[^_])get_nearby_games') then
    raise exception 'KAN-951/953 pre: another function names a target';
  end if;
end
$pre$;

CREATE OR REPLACE FUNCTION public.get_nearby_games(p_lat double precision, p_lng double precision, p_radius integer DEFAULT 5000)
 RETURNS TABLE(id uuid, title text, lat double precision, lng double precision, start_at timestamp with time zone, capacity integer, distance_meters double precision)
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  -- KAN-951: shared facts from events (KAN-948); lat / lng from geo_locations through events.geo_location_id.
  RETURN QUERY
  SELECT
    g.id,
    e.title,
    st_y(gl.location::geometry) AS lat,
    st_x(gl.location::geometry) AS lng,
    e.start_at,
    e.capacity,

    ST_Distance(
      gl.location,
      ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326)::geography
    ) AS distance_meters

  FROM games g
  JOIN events e ON e.id = g.event_id AND e.event_type = 'game'
  JOIN geo_locations gl ON e.geo_location_id = gl.id

  WHERE
    e.is_cancelled = false
    -- 🔥 TEMP REMOVE THIS
    -- AND e.start_at > now()

    AND ST_DWithin(
      gl.location,
      ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326)::geography,
      p_radius
    )

  ORDER BY
    distance_meters ASC,
    e.start_at ASC

  LIMIT 20;
END;
$function$;

CREATE OR REPLACE FUNCTION public.get_nearby_games(p_lat double precision, p_lng double precision, p_radius double precision DEFAULT 5000)
 RETURNS TABLE(id uuid, title text, lat double precision, lng double precision, start_at timestamp with time zone, capacity integer, sport_id uuid, area_id uuid, distance_meters double precision)
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  -- KAN-951: shared facts from events (KAN-948); lat / lng from geo_locations through events.geo_location_id.
  RETURN QUERY
  SELECT
    g.id,
    e.title,
    st_y(gl.location::geometry) AS lat,
    st_x(gl.location::geometry) AS lng,
    e.start_at,
    e.capacity,
    e.sport_id,
    e.area_id,
    ST_Distance(
      gl.location,
      ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326)::geography
    ) AS distance_meters
  FROM games g
  JOIN events e ON e.id = g.event_id AND e.event_type = 'game'
  JOIN geo_locations gl ON e.geo_location_id = gl.id
  WHERE
    e.is_cancelled = false
    AND e.start_at > now()
    AND ST_DWithin(
      gl.location,
      ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326)::geography,
      p_radius
    )
  ORDER BY
    distance_meters ASC,
    e.start_at ASC
  LIMIT 20;
END;
$function$;

DROP FUNCTION public.get_home_feed(integer, integer);
DROP FUNCTION public.rpc_autocomplete_entities(text, text[], text, integer);

do $post$
declare
  k record;
  p record;
begin
  for k in select * from (values
    ('public.get_nearby_games(double precision,double precision,integer)', 'v'),
    ('public.get_nearby_games(double precision,double precision,double precision)', 's')) v(fn, vol)
  loop
    select * into p from pg_proc where oid = to_regprocedure(k.fn);
    if p.oid is null
       or pg_get_userbyid(p.proowner) <> 'postgres'
       or p.prosecdef
       or p.provolatile <> k.vol
       or p.proconfig is distinct from array['search_path=public, pg_temp']
       or p.proacl::text <> '{=X/postgres,postgres=X/postgres,anon=X/postgres,authenticated=X/postgres,service_role=X/postgres}'
       or p.prosrc ~ 'g\.(lat|lng)\M' then
      raise exception 'KAN-951 post: % attributes drifted (owner %, secdef %, vol %, config %, acl %)',
        k.fn, pg_get_userbyid(p.proowner), p.prosecdef, p.provolatile, p.proconfig, p.proacl;
    end if;
  end loop;
  if to_regprocedure('public.get_home_feed(integer,integer)') is not null
     or to_regprocedure('public.rpc_autocomplete_entities(text,text[],text,integer)') is not null then
    raise exception 'KAN-953 post: a dropped function is still present';
  end if;
  if md5(pg_get_functiondef(to_regprocedure('public.get_home_feed(integer,timestamp with time zone)')))
       is distinct from 'b19dc3488f562fab32603cf415c0415e' then
    raise exception 'KAN-953 post: get_home_feed(int,timestamptz) changed';
  end if;
end
$post$;
