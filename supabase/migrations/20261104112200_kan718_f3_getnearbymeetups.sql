-- KAN-856 (KAN-718 follow-up F3, Epic KAN-708): public.getnearbymeetups(double precision, double precision,
-- double precision) reads the shared facts from public.events instead of legacy meetups columns.
-- AUTHORED, NOT APPLIED. Review + apply through the normal Thebes path (PEER route, backend-N reviewer).
-- No DROP, no table/column/grant/policy change, no row written. One function body is replaced in place.
--
-- WHY CONVERT, NOT RETIRE. The app calls it: lib/core/config/supabase_config.dart:200 (getNearbyMeetupsFn) ->
-- lib/features/meetups/data/datasources/supabase_meetup_datasource.dart:37 (nearby) -> meetup_repository_impl /
-- nearbyMeetupsProvider (meetup_filters.dart:119, distance per meetup id).
--
-- WHY IT MUST CHANGE. The pre-image (baseline 20260829080500:7850-7874) reads meetups.title and
-- meetups.is_cancelled, both in the KAN-719 Z01 drop set (seq 703, 710), and also m.starts_at, m.lat, m.lng,
-- m.areaid, m.geolocationid and public.geolocations, none of which exist in any migration (KAN718_D04_DISPOSITION
-- row 9: broken on every chain). Every call errors today.
--
-- WHAT CHANGES. The body joins public.events e ON e.id = m.event_id AND e.event_type = 'meetup' (KAN-710 FK +
-- KAN-711 backfill: one parent per meetup; the precondition refuses if any meetup lacks it) and
-- public.geo_locations gl ON gl.id = e.geo_location_id. From meetups it reads only m.id and m.event_id (neither
-- is slated). Shared facts from e: title, start_at (-> starts_at), area_id (-> areaid), is_cancelled,
-- geo_location_id. lat / lng come from gl.location (st_y / st_x), the same derivation v_game_card uses. Distance
-- and radius are the pre-image's expressions on gl.location. ORDER BY distance_m keeps the pre-image's key and adds
-- e.start_at, m.id as tie-breaks (deterministic; no row is added or removed by them).
-- RETURN SIGNATURE UNCHANGED: same name, same three arguments and default (p_radius 10000), same RETURNS TABLE
-- (id uuid, title text, starts_at timestamptz, lat float8, lng float8, areaid uuid, distance_m float8). id is
-- still the meetups id (the app's route key). LANGUAGE sql, STABLE, search_path unchanged.
-- ONE ATTRIBUTE CHANGES: SECURITY INVOKER -> SECURITY DEFINER. public.events is FORCE RLS with zero policies and
-- no anon/authenticated grant (KAN-710:96-102), so an INVOKER body reading events raises 42501 for every client
-- caller (observed locally: kan718_f3 probe T8 on an INVOKER draft). The pre-image has no working client branch
-- to fall back to (KAN-727 B08 / KAN-772 pattern), because it never ran. So this follows meetup_counts (KAN-772,
-- 20261104110100) and v_meetup_counts (KAN-721 B02): owner-run, with the visibility gate evaluated in the body,
-- public.can_view_owner(e.creator_user_id, e.listing_visibility). That is exactly the events half of the
-- meetups_select_visible policy (KAN-713: kan713_meetup_visible), which is what an INVOKER caller would have been
-- filtered by on meetups; its legacy half reads meetups.creator_user_id / listing_visibility (Z01 seq 702, 705)
-- and is not repeated (KAN-712 keeps them equal; events is authoritative). can_view_owner reads auth.uid(), not
-- current_user, so the caller's identity still decides. Proven per role in the probe (T8: anon sees public only).
-- CREATE OR REPLACE keeps owner and ACL; the post-condition asserts both, and every other attribute, unchanged.
--
-- KAN-712 INTERACTION: read-only, not on the KAN-712 wrap list; the precondition refuses if it has been wrapped.
--
-- T-058 SUBSTITUTE: production is not read by this ticket. The replacement starts from the repo definition
-- (baseline 20260829080500:7850-7874), and the precondition pins md5(prosrc) of the LIVE function to that body
-- (37cd2aeed02a1c4ba6c0c5666137d693), plus SECURITY INVOKER, STABLE, sql and search_path. Any drift fails closed;
-- re-author from pg_get_functiondef on the live catalogue in that case.
--
-- ORDER: 20261104112200 sorts after 20261104112100 (KAN-834, the last D04 conversion) and BEFORE 20261105100000
-- (KAN-719 Z01). F3 is a prerequisite of Z01's re-scope (F8), so on any replay this body is already events-based
-- when Z01 drops the meetups columns.
--
-- ROLLBACK (data-neutral, one transaction): re-run the CREATE OR REPLACE at baseline 20260829080500:7850-7872
-- verbatim (with SET check_function_bodies = false, as the baseline runs it); it has no SECURITY clause, so it
-- restores SECURITY INVOKER. Owner and ACL are untouched.
--
-- LOCAL PROOF: supabase/tests/events_p4/kan718_f3_getnearbymeetups_test.sql (red before, green after).

begin;
set local lock_timeout = '10s';

-- ---------------------------------------------------------------------------------------------------------
-- 0. Preconditions. Refuse; never repair.
-- ---------------------------------------------------------------------------------------------------------
do $pre$
declare
  v_unlinked bigint;
  p record;
begin
  if not exists (select 1 from pg_roles where rolname = current_user and (rolsuper or rolbypassrls)) then
    raise exception 'KAN-856 pre: applying role % must be superuser or BYPASSRLS (public.events is FORCE RLS)', current_user;
  end if;
  if to_regclass('public.events') is null
     or not exists (select 1 from pg_constraint where conrelid = 'public.meetups'::regclass
                     and conname = 'meetups_event_id_fkey') then
    raise exception 'KAN-856 pre: KAN-710/KAN-711 not applied (public.events, meetups_event_id_fkey)';
  end if;
  if to_regclass('public.kan712_wrapped_rpcs') is not null
     and exists (select 1 from public.kan712_wrapped_rpcs w where w::text ~ 'getnearbymeetups') then
    raise exception 'KAN-856 pre: getnearbymeetups is KAN-712-wrapped; change it through kan712_unwrap_rpc / kan712_wrap_rpc';
  end if;
  select * into p from pg_proc
   where oid = to_regprocedure('public.getnearbymeetups(double precision,double precision,double precision)');
  if not found then
    raise exception 'KAN-856 pre: public.getnearbymeetups(float8,float8,float8) is absent';
  end if;
  if p.prosrc like '%KAN-856%' then
    raise exception 'KAN-856 pre: already applied';
  end if;
  if md5(p.prosrc) <> '37cd2aeed02a1c4ba6c0c5666137d693' or p.prosecdef or p.provolatile <> 's'
     or p.prolang <> (select oid from pg_language where lanname = 'sql')
     or p.proconfig::text is distinct from '{"search_path=public, pg_temp"}' then
    raise exception 'KAN-856 pre: live getnearbymeetups differs from the reviewed pre-image (re-author from pg_get_functiondef): md5 % secdef % volatile % config %',
      md5(p.prosrc), p.prosecdef, p.provolatile, p.proconfig;
  end if;
  select count(*) into v_unlinked
    from public.meetups m left join public.events e on e.id = m.event_id and e.event_type = 'meetup'
   where e.id is null;
  if v_unlinked > 0 then
    raise exception 'KAN-856 pre: % meetup(s) without a meetup events parent; reconcile first', v_unlinked;
  end if;
end
$pre$;

create temp table kan856_attr on commit drop as
select p.oid, p.proowner, p.proacl, p.prosecdef, p.proconfig, p.provolatile, p.prolang, p.proretset,
       pg_get_function_result(p.oid) as res, pg_get_function_arguments(p.oid) as args
  from pg_proc p
 where p.oid = 'public.getnearbymeetups(double precision,double precision,double precision)'::regprocedure;

-- ---------------------------------------------------------------------------------------------------------
-- 1. getnearbymeetups -- from baseline 20260829080500:7850-7872
-- ---------------------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.getnearbymeetups(p_lat double precision, p_lng double precision, p_radius double precision DEFAULT 10000)
 RETURNS TABLE(id uuid, title text, starts_at timestamp with time zone, lat double precision, lng double precision, areaid uuid, distance_m double precision)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  -- KAN-856: shared facts and the visibility gate from events e; meetups m supplies only its id (the route key).
  select
    m.id,
    e.title,
    e.start_at                             as starts_at,
    st_y(gl.location::geometry)            as lat,
    st_x(gl.location::geometry)            as lng,
    e.area_id                              as areaid,
    st_distance(
      gl.location,
      st_setsrid(st_makepoint(p_lng, p_lat), 4326)::geography
    )                                      as distance_m
  from public.meetups m
  join public.events e on e.id = m.event_id and e.event_type = 'meetup'
  join public.geo_locations gl on gl.id = e.geo_location_id
  where e.is_cancelled = false
    and e.start_at > now()
    and public.can_view_owner(e.creator_user_id, e.listing_visibility)
    and st_dwithin(
      gl.location,
      st_setsrid(st_makepoint(p_lng, p_lat), 4326)::geography,
      p_radius
    )
  order by distance_m asc, e.start_at asc, m.id asc;
$function$;

-- ---------------------------------------------------------------------------------------------------------
-- 2. Post-conditions.
-- ---------------------------------------------------------------------------------------------------------
do $post$
declare
  a record;
  p record;
begin
  select * into a from kan856_attr;
  select pp.*, pg_get_function_result(pp.oid) as res, pg_get_function_arguments(pp.oid) as args into p
    from pg_proc pp where pp.oid = a.oid;
  if not found then
    raise exception 'KAN-856 post: function oid changed (replaced, not altered in place)';
  end if;
  if not p.prosecdef then
    raise exception 'KAN-856 post: not SECURITY DEFINER';
  end if;
  if p.proowner <> a.proowner or p.proacl is distinct from a.proacl
     or p.proconfig is distinct from a.proconfig or p.provolatile <> a.provolatile or p.prolang <> a.prolang
     or p.proretset <> a.proretset or p.res <> a.res or p.args <> a.args then
    raise exception 'KAN-856 post: attributes changed (owner/acl/config/volatile/lang/result/args)';
  end if;
  if p.prosrc !~ 'KAN-856' then
    raise exception 'KAN-856 post: body not replaced';
  end if;
end
$post$;

commit;
