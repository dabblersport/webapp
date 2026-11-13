-- KAN-931: four public functions referenced objects that do not exist on the live schema.
--
-- Callers (lib/ on staging ab6bb229, supabase/functions, every pg_proc body, pg_policies, pg_views, cron.job):
--   rpc_search_entities(text,text[],text,integer)  none. The app searches with rpc_unified_search_sectioned.
--                                                  Raised 42P01 (v_person_card) on every call.            DROP
--   rpc_meetup_visible()                           none. Raised 42703 (m.starts_at) on every call.          DROP
--   getnearbymeetups(float8,float8,float8)         lib/features/meetups/data/datasources/supabase_meetup_datasource.dart
--                                                  (every meetups screen). Raised 42P01 (geolocations).   RE-AUTHOR
--   are_synced(uuid,uuid)                          _can_view_with_scope_canonical, can_view_with_scope,
--                                                  can_view_with_scope3, can_current_user_join_game,
--                                                  kan713_meetup_attendee_visible, can_current_user_rsvp_meetup.
--                                                  Read public.friendships (absent).                       RE-AUTHOR
--
-- Re-authored from live pg_get_functiondef. CREATE OR REPLACE with the same signature, OUT columns, LANGUAGE,
-- volatility, SECURITY INVOKER and search_path keeps owner and ACL; the post-assert checks them.
--
-- getnearbymeetups: same OUT shape the app parses (id, title, starts_at, lat, lng, areaid, distance_m). Reads
--   public.kan718_meetups_compat (security_barrier view whose row filter is the meetups SELECT policy; events itself
--   is closed to anon/authenticated) joined to public.geo_locations. lat/lng come from the point; areaid is the
--   event's area, else the geo location's.
-- are_synced: no friendship relation exists live (public.friendships and public.friend_edges are both absent).
--   "Synced" is now a mutual follow on public.profile_follows: a profile of user a follows a profile of user b
--   and that profile of b follows it back. Symmetric, false for a = b and for NULL, like the pre-image.
--
-- Pre-image md5(prosrc): rpc_search_entities eb9caf7615e0787cf8bfe028629a3143, rpc_meetup_visible
-- cf7a30d7f712e2179873f18a4fe8c562, getnearbymeetups 11a596ce050fc44a14eff1f6dd3204da, are_synced
-- f5851855d548c7aab8ceb916379754d2. Proof: supabase/tests/events_p4/kan931_broken_functions_test.sql.

DO $guard$
DECLARE r record;
BEGIN
  FOR r IN SELECT * FROM (VALUES
    ('public.rpc_search_entities(text,text[],text,integer)', 'eb9caf7615e0787cf8bfe028629a3143'),
    ('public.rpc_meetup_visible()',                          'cf7a30d7f712e2179873f18a4fe8c562'),
    ('public.getnearbymeetups(double precision,double precision,double precision)', '11a596ce050fc44a14eff1f6dd3204da'),
    ('public.are_synced(uuid,uuid)',                         'f5851855d548c7aab8ceb916379754d2')) v(sig, md5)
  LOOP
    IF to_regprocedure(r.sig) IS NULL THEN
      RAISE EXCEPTION 'KAN-931 guard: % is absent', r.sig;
    END IF;
    IF (SELECT md5(prosrc) FROM pg_proc WHERE oid = to_regprocedure(r.sig)) <> r.md5 THEN
      RAISE EXCEPTION 'KAN-931 guard: % is not the pinned pre-image', r.sig;
    END IF;
  END LOOP;
  IF to_regclass('public.kan718_meetups_compat') IS NULL OR to_regclass('public.geo_locations') IS NULL
     OR to_regclass('public.profile_follows') IS NULL THEN
    RAISE EXCEPTION 'KAN-931 guard: a relation the new bodies read is absent';
  END IF;
END $guard$;

DROP FUNCTION public.rpc_search_entities(text, text[], text, integer);
DROP FUNCTION public.rpc_meetup_visible();

CREATE OR REPLACE FUNCTION public.getnearbymeetups(p_lat double precision, p_lng double precision, p_radius double precision DEFAULT 10000)
 RETURNS TABLE(id uuid, title text, starts_at timestamp with time zone, lat double precision, lng double precision, areaid uuid, distance_m double precision)
 LANGUAGE sql
 STABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
  select
    c.id, c.title, c.start_at as starts_at,
    st_y(gl.location::geometry) as lat, st_x(gl.location::geometry) as lng,
    coalesce(c.area_id, gl.area_id) as areaid,
    st_distance(
      gl.location,
      st_setsrid(st_makepoint(p_lng, p_lat), 4326)::geography
    ) as distance_m
  from public.kan718_meetups_compat c
  join public.geo_locations gl on gl.id = c.geo_location_id
  where c.is_cancelled = false
    and c.start_at > now()
    and st_dwithin(
      gl.location,
      st_setsrid(st_makepoint(p_lng, p_lat), 4326)::geography,
      p_radius
    )
  order by distance_m asc;
$function$;

CREATE OR REPLACE FUNCTION public.are_synced(a uuid, b uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
  select a <> b and exists(
    select 1
    from public.profile_follows f
    join public.profiles pa on pa.id = f.follower_profile_id and pa.user_id = a
    join public.profiles pb on pb.id = f.following_profile_id and pb.user_id = b
    where exists (
      select 1 from public.profile_follows r
      where r.follower_profile_id = f.following_profile_id
        and r.following_profile_id = f.follower_profile_id
    )
  )
$function$;

DO $post$
DECLARE r record;
BEGIN
  IF to_regprocedure('public.rpc_search_entities(text,text[],text,integer)') IS NOT NULL
     OR to_regprocedure('public.rpc_meetup_visible()') IS NOT NULL THEN
    RAISE EXCEPTION 'KAN-931 post: a dropped function still exists';
  END IF;
  FOR r IN SELECT p.oid::regprocedure::text sig, pg_get_userbyid(p.proowner) own, p.prosecdef, p.proconfig::text cfg, p.proacl::text acl
           FROM pg_proc p WHERE p.oid IN (to_regprocedure('public.getnearbymeetups(double precision,double precision,double precision)'),
                                          to_regprocedure('public.are_synced(uuid,uuid)'))
  LOOP
    IF r.own <> 'postgres' OR r.prosecdef OR r.cfg <> '{"search_path=public, pg_temp"}'
       OR r.acl <> '{=X/postgres,postgres=X/postgres,anon=X/postgres,authenticated=X/postgres,service_role=X/postgres}' THEN
      RAISE EXCEPTION 'KAN-931 post: % attributes changed: % % % %', r.sig, r.own, r.prosecdef, r.cfg, r.acl;
    END IF;
  END LOOP;
END $post$;
