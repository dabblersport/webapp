-- KAN-723 (KAN-714 B04, Epic KAN-708): the nearby/discovery game RPCs and rpc_games_following_joined read the
-- shared facts from public.events instead of the legacy games columns.
-- AUTHORED, NOT APPLIED. Review + apply through the normal Thebes path (PEER route, backend-N reviewer).
-- No DROP, no table/column/grant/policy change, no row written. Three function bodies are replaced in place.
--
-- WHAT CHANGES. Each body joins public.events e ON e.id = g.event_id AND e.event_type = 'game' (KAN-710's
-- validated FK + games_event_id_not_null: exactly one parent per game, so the inner join neither drops nor
-- doubles a row -- the precondition below refuses if any game lacks its parent). Every SHARED fact is read
-- from e: title, start_at, end_at, capacity, listing_visibility, is_cancelled, sport_id, geo_location_id,
-- venue_id, min_skill, max_skill, joining_rule, cost_cover, creator_user_id, creator_profile_id.
-- Game-only fields stay on games (they are not parent columns, KAN-710:22-46): game_type, squad_id,
-- sport_variant_id, venue_space_id, price_aed.
--   * min_skill / max_skill are smallint on events (KAN-710:39-40) and integer in the result: cast ::int, so
--     the result type is byte-identical (asserted in the post-conditions).
--   * title: events.title is nullable for games exactly like games.title; coalesce(.., 'Untitled Game') kept.
--   * end_at: NOT NULL for games on both sides (events_game_end_required). capacity: NOT NULL for games on
--     both sides (events_game_capacity_check). No nullability conflict blocks an equivalent read.
--
-- ACCESS PREDICATES: KAN-713's rule, INTERSECTION, NEVER WIDEN (20261104100000:12-20). The visibility +
-- block-guard predicate is kept verbatim on the legacy fields AND evaluated again on the events fields; while
-- KAN-712 keeps the two in sync they are equal, and if they ever diverge the narrower answer wins. Per-type
-- vocabulary is unchanged (games: public/followers/private on both sides, KAN-710:77). Meetups are NOT unioned
-- in: the legacy RPCs never returned meetups and the event_type = 'game' pin keeps it that way.
-- rpc_games_following_joined keeps public._can_view_game(g.id), which KAN-713 already intersects with events.
-- Selection filters (is_cancelled, start_at > now(), radius via geo_location_id, sport, price) and ordering
-- (distance, price, start_at) read events where the field is shared. Result columns and ORDER BY are unchanged.
--
-- KAN-712 INTERACTION: none of these RPCs writes, and none is on the KAN-712 wrap list
-- (supabase/tests/events_p2/KAN712_CONTRACT.md:68-89); the precondition refuses if one has been wrapped
-- (a plain CREATE OR REPLACE would otherwise overwrite a wrapper).
--
-- T-058 SUBSTITUTE (as KAN-713): production is not read here. The body each replacement starts from is the repo
-- definition named below, and the precondition pins md5(prosrc) of the LIVE function to that body, plus
-- SECURITY DEFINER and search_path. Any drift fails closed instead of being overwritten -- re-author from
-- pg_get_functiondef on the live catalogue in that case.
--   rpc_get_nearby_games(6 args, p_max_price)  20261008140000_game_price_meetup_setting.sql:360-442  REQUIRED
--   rpc_get_nearby_games(5 args)               20261008160000_games_nearby_block_guard.sql:25-104   ONLY IF PRESENT
--       (a repo replay creates this second overload; the live record says one overload exists --
--        supabase/tests/anon_block_grants/CALLERS.md note on row 5. Converted when present, so a replayed
--        database does not keep a legacy-reading twin.)
--   rpc_games_following_joined(uuid[])         20261008170000_games_following_joined.sql:39-80      REQUIRED
-- CREATE OR REPLACE keeps owner, ACL, SECURITY DEFINER and search_path; the post-conditions assert each equal.
--
-- ROLLBACK (data-neutral, one transaction): re-run the three CREATE OR REPLACE statements named above, verbatim
-- from those repo files (20261008160000 only if the 5-arg overload exists). They restore the pinned bodies;
-- owner and ACL are untouched by CREATE OR REPLACE. Proven locally in
-- supabase/tests/events_p2/kan714_b04_nearby_following.sql probe R1-R4.

begin;
set local lock_timeout = '10s';

-- ---------------------------------------------------------------------------------------------------------
-- 0. Preconditions. Refuse; never repair.
-- ---------------------------------------------------------------------------------------------------------
do $pre$
declare
  v_bad text;
  v_unlinked bigint;
begin
  if not exists (select 1 from pg_roles where rolname = current_user and (rolsuper or rolbypassrls)) then
    raise exception 'KAN-723 pre: applying role % must be superuser or BYPASSRLS (public.events is FORCE RLS)', current_user;
  end if;
  -- KAN-710 / KAN-711
  if to_regclass('public.events') is null
     or not exists (select 1 from pg_constraint where conrelid = 'public.games'::regclass
                     and conname = 'games_event_id_fkey')
     or not exists (select 1 from pg_constraint where conrelid = 'public.games'::regclass
                     and conname = 'games_event_id_not_null' and convalidated) then
    raise exception 'KAN-723 pre: KAN-710/KAN-711 not applied (events, games_event_id_fkey, validated games_event_id_not_null)';
  end if;
  -- KAN-712 stage B live
  if (select count(*) from pg_trigger where tgname like 'trg\_zz\_kan712\_%' and tgenabled = 'O') <> 5
     or to_regclass('public.kan712_wrapped_rpcs') is null then
    raise exception 'KAN-723 pre: KAN-712 stage B (20261103110000) not live';
  end if;
  -- KAN-713 (the write-side conversion these reads follow): both migrations' objects present
  if to_regprocedure('public.kan713_meetup_visible(uuid)') is null
     or to_regclass('public.kan713_preimage') is null
     or to_regprocedure('public.kan713_games_location()') is null
     or not exists (select 1 from pg_trigger where tgrelid = 'public.events'::regclass
                     and tgname = 'trg_kan713_events_location' and tgenabled = 'O')
     or (select prosrc from pg_proc where oid = to_regprocedure('public._can_view_game(uuid)'))
          not like '%join public.events e on e.id = g.event_id and e.event_type = ''game''%' then
    raise exception 'KAN-723 pre: KAN-713 (20261104100000 + 20261104110000) not applied';
  end if;
  -- Not wrapped by KAN-712
  if exists (select 1 from public.kan712_wrapped_rpcs w where w::text ~ '(rpc_get_nearby_games|rpc_games_following_joined)')
     or exists (select 1 from pg_proc where pronamespace = 'public'::regnamespace
                 and proname in ('rpc_get_nearby_games_kan712_inner', 'rpc_games_following_joined_kan712_inner')) then
    raise exception 'KAN-723 pre: a target RPC is KAN-712-wrapped; change it through kan712_unwrap_rpc / kan712_wrap_rpc';
  end if;
  -- Already applied?
  if exists (select 1 from pg_proc where pronamespace = 'public'::regnamespace
              and proname in ('rpc_get_nearby_games', 'rpc_games_following_joined') and prosrc like '%KAN-723%') then
    raise exception 'KAN-723 pre: already applied';
  end if;
  -- Every game has exactly its game parent (the inner join must not drop a row)
  select count(*) into v_unlinked
    from public.games g left join public.events e on e.id = g.event_id and e.event_type = 'game'
   where e.id is null;
  if v_unlinked > 0 then
    raise exception 'KAN-723 pre: % game(s) without a game events parent; reconcile first', v_unlinked;
  end if;
  -- Live bodies are exactly the repo bodies these replacements were authored from (T-058 substitute)
  select string_agg(x.sig || ' expected ' || x.md5 || ' live ' || coalesce(md5(p.prosrc), '<absent>')
                    || ' secdef ' || coalesce(p.prosecdef::text, '?') || ' config ' || coalesce(p.proconfig::text, '-'), '; ')
    into v_bad
    from (values
      ('public.rpc_get_nearby_games(double precision,double precision,integer,uuid,text,numeric)', 'e14430bad3dedb8540287f70ccfaa208', true),
      ('public.rpc_get_nearby_games(double precision,double precision,integer,uuid,text)',         '11c52abd9873a93cf71db5ca6b29c480', false),
      ('public.rpc_games_following_joined(uuid[])',                                                'd3b31f55b000b4991be313f4c96d88d9', true)
    ) as x(sig, md5, required)
    left join pg_proc p on p.oid = to_regprocedure(x.sig)
   where (p.oid is null and x.required)
      or (p.oid is not null and (md5(p.prosrc) <> x.md5 or not p.prosecdef
                                 or p.proconfig::text <> '{"search_path=public, pg_temp"}'));
  if v_bad is not null then
    raise exception 'KAN-723 pre: live RPC differs from the reviewed pre-image (re-author from pg_get_functiondef): %', v_bad;
  end if;
end
$pre$;

-- Attributes before, for the post-condition (temp: dropped at commit).
create temp table kan723_attr on commit drop as
select p.oid, p.oid::regprocedure::text as sig, p.proowner, p.proacl, p.prosecdef, p.proconfig, p.provolatile,
       p.prolang, pg_get_function_result(p.oid) as res, pg_get_function_arguments(p.oid) as args
  from pg_proc p
 where p.pronamespace = 'public'::regnamespace and p.proname in ('rpc_get_nearby_games', 'rpc_games_following_joined');

-- ---------------------------------------------------------------------------------------------------------
-- 1. rpc_get_nearby_games (6 args) -- from 20261008140000:360-442
-- ---------------------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.rpc_get_nearby_games(p_lat double precision, p_lng double precision, p_radius_meters integer DEFAULT 10000, p_sport_id uuid DEFAULT NULL::uuid, p_sort text DEFAULT 'distance'::text, p_max_price numeric DEFAULT NULL::numeric)
 RETURNS TABLE(id uuid, title text, sport_name text, scheduled_at timestamp with time zone, status text, venue_name text, latitude double precision, longitude double precision, distance_meters double precision, player_count integer, spots_remaining integer, is_public boolean, min_skill integer, max_skill integer, end_at timestamp with time zone, variant_name_en text, variant_name_ar text, cost_cover text, joining_rule text, host_verified boolean, favorite_count integer, favourited_by_me boolean, price_aed numeric)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  -- KAN-723: shared facts from events e (authoritative); game-only fields from g; access intersected.
  select
    g.id,
    coalesce(e.title, 'Untitled Game')    as title,
    s.name_en                              as sport_name,
    e.start_at                             as scheduled_at,
    case
      when e.is_cancelled         then 'cancelled'
      when now() >= e.end_at      then 'ended'
      when now() >= e.start_at    then 'live'
      else                             'upcoming'
    end                                    as status,
    ven.name_en                            as venue_name,
    st_y(gl.location::geometry)            as latitude,
    st_x(gl.location::geometry)            as longitude,
    st_distance(
      gl.location,
      st_setsrid(st_makepoint(p_lng, p_lat), 4326)::geography
    )                                      as distance_meters,
    coalesce(roster.cnt, 0)::int           as player_count,
    greatest(e.capacity - coalesce(roster.cnt, 0), 0)::int as spots_remaining,
    (e.listing_visibility = 'public')      as is_public,
    e.min_skill::int                       as min_skill,
    e.max_skill::int                       as max_skill,
    e.end_at,
    sv.name_en                             as variant_name_en,
    sv.name_ar                             as variant_name_ar,
    e.cost_cover,
    e.joining_rule,
    (coalesce((select pv.verified from profile_verifications pv
                where pv.profile_id = e.creator_profile_id), false)
     or exists (select 1 from organiser o
                where o.profile_id = e.creator_profile_id and o.sport = s.sport_key
                  and o.is_verified and o.is_active)) as host_verified,
    (select count(*) from public.favorites f where f.game_id = g.id)::int as favorite_count,
    exists (select 1 from public.favorites f
            where f.game_id = g.id and f.user_id = auth.uid()) as favourited_by_me,
    g.price_aed
  from   games g
  join public.events e on e.id = g.event_id and e.event_type = 'game'
  join   geo_locations gl on e.geo_location_id = gl.id
  join   sports s         on s.id = e.sport_id
  left   join sport_variants sv on sv.id = g.sport_variant_id
  left   join venue_spaces vs on vs.id = g.venue_space_id
  left   join venues ven      on ven.id = coalesce(vs.venue_id, e.venue_id)
  left   join lateral (
    select count(*) as cnt
    from   game_roster gr
    where  gr.game_id = g.id
      and  gr.status  = 'active'
      and  (gr.role = 'player' or (gr.role = 'host' and g.game_type = 'hosted'))
  ) roster on true
  where  e.is_cancelled = false
    and  e.start_at > now()
    and  st_dwithin(
           gl.location,
           st_setsrid(st_makepoint(p_lng, p_lat), 4326)::geography,
           p_radius_meters
         )
    and  (p_sport_id is null or e.sport_id = p_sport_id)
    and  (p_max_price is null or g.price_aed <= p_max_price)
    and  (
           (g.listing_visibility = 'public' and not public.is_blocked(auth.uid(), g.creator_user_id))
           or g.creator_user_id = auth.uid()
           or public.can_view_with_scope(
                auth.uid(), g.creator_user_id, g.listing_visibility, g.squad_id
              )
         )
    and  (
           (e.listing_visibility = 'public' and not public.is_blocked(auth.uid(), e.creator_user_id))
           or e.creator_user_id = auth.uid()
           or public.can_view_with_scope(
                auth.uid(), e.creator_user_id, e.listing_visibility, g.squad_id
              )
         )
  order  by
    case when p_sort = 'distance'
         then st_distance(
                gl.location,
                st_setsrid(st_makepoint(p_lng, p_lat), 4326)::geography
              )
    end asc nulls last,
    case when p_sort = 'price' then g.price_aed end asc nulls last,
    e.start_at asc
  limit 50;
$function$;

-- ---------------------------------------------------------------------------------------------------------
-- 2. rpc_get_nearby_games (5 args) -- from 20261008160000:25-104, ONLY where that overload exists
-- ---------------------------------------------------------------------------------------------------------
do $n5$
begin
  if to_regprocedure('public.rpc_get_nearby_games(double precision,double precision,integer,uuid,text)') is null then
    raise notice 'KAN-723: 5-argument rpc_get_nearby_games absent; nothing to convert (expected on live)';
    return;
  end if;
  execute $ddl$
CREATE OR REPLACE FUNCTION public.rpc_get_nearby_games(p_lat double precision, p_lng double precision, p_radius_meters integer DEFAULT 10000, p_sport_id uuid DEFAULT NULL::uuid, p_sort text DEFAULT 'distance'::text)
 RETURNS TABLE(id uuid, title text, sport_name text, scheduled_at timestamp with time zone, status text, venue_name text, latitude double precision, longitude double precision, distance_meters double precision, player_count integer, spots_remaining integer, is_public boolean, min_skill integer, max_skill integer, end_at timestamp with time zone, variant_name_en text, variant_name_ar text, cost_cover text, joining_rule text, host_verified boolean, favorite_count integer, favourited_by_me boolean)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  -- KAN-723: shared facts from events e (authoritative); game-only fields from g; access intersected.
  select
    g.id,
    coalesce(e.title, 'Untitled Game')    as title,
    s.name_en                              as sport_name,
    e.start_at                             as scheduled_at,
    case
      when e.is_cancelled         then 'cancelled'
      when now() >= e.end_at      then 'ended'
      when now() >= e.start_at    then 'live'
      else                             'upcoming'
    end                                    as status,
    ven.name_en                            as venue_name,
    st_y(gl.location::geometry)            as latitude,
    st_x(gl.location::geometry)            as longitude,
    st_distance(
      gl.location,
      st_setsrid(st_makepoint(p_lng, p_lat), 4326)::geography
    )                                      as distance_meters,
    coalesce(roster.cnt, 0)::int           as player_count,
    greatest(e.capacity - coalesce(roster.cnt, 0), 0)::int as spots_remaining,
    (e.listing_visibility = 'public')      as is_public,
    e.min_skill::int                       as min_skill,
    e.max_skill::int                       as max_skill,
    e.end_at,
    sv.name_en                             as variant_name_en,
    sv.name_ar                             as variant_name_ar,
    e.cost_cover,
    e.joining_rule,
    (coalesce((select pv.verified from profile_verifications pv
                where pv.profile_id = e.creator_profile_id), false)
     or exists (select 1 from organiser o
                where o.profile_id = e.creator_profile_id and o.sport = s.sport_key
                  and o.is_verified and o.is_active)) as host_verified,
    (select count(*) from public.favorites f where f.game_id = g.id)::int as favorite_count,
    exists (select 1 from public.favorites f
            where f.game_id = g.id and f.user_id = auth.uid()) as favourited_by_me
  from   games g
  join public.events e on e.id = g.event_id and e.event_type = 'game'
  join   geo_locations gl on e.geo_location_id = gl.id
  join   sports s         on s.id = e.sport_id
  left   join sport_variants sv on sv.id = g.sport_variant_id
  left   join venue_spaces vs on vs.id = g.venue_space_id
  left   join venues ven      on ven.id = coalesce(vs.venue_id, e.venue_id)
  left   join lateral (
    select count(*) as cnt
    from   game_roster gr
    where  gr.game_id = g.id
      and  gr.status  = 'active'
      and  (gr.role = 'player' or (gr.role = 'host' and g.game_type = 'hosted'))
  ) roster on true
  where  e.is_cancelled = false
    and  e.start_at > now()
    and  st_dwithin(
           gl.location,
           st_setsrid(st_makepoint(p_lng, p_lat), 4326)::geography,
           p_radius_meters
         )
    and  (p_sport_id is null or e.sport_id = p_sport_id)
    and  (
           (g.listing_visibility = 'public' and not public.is_blocked(auth.uid(), g.creator_user_id))
           or g.creator_user_id = auth.uid()
           or public.can_view_with_scope(
                auth.uid(), g.creator_user_id, g.listing_visibility, g.squad_id
              )
         )
    and  (
           (e.listing_visibility = 'public' and not public.is_blocked(auth.uid(), e.creator_user_id))
           or e.creator_user_id = auth.uid()
           or public.can_view_with_scope(
                auth.uid(), e.creator_user_id, e.listing_visibility, g.squad_id
              )
         )
  order  by
    case when p_sort = 'distance'
         then st_distance(
                gl.location,
                st_setsrid(st_makepoint(p_lng, p_lat), 4326)::geography
              )
    end asc nulls last,
    e.start_at asc
  limit 50;
$function$
$ddl$;
end
$n5$;

-- ---------------------------------------------------------------------------------------------------------
-- 3. rpc_games_following_joined -- from 20261008170000:39-80. Only the visible-games CTE reads a shared fact.
-- ---------------------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.rpc_games_following_joined(p_game_ids uuid[])
RETURNS TABLE(game_id uuid, following_count integer)
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $function$
  -- KAN-723: is_cancelled from events e (authoritative); visibility via _can_view_game (KAN-713, intersected).
  with me as (
    select auth.uid() as uid
  ),
  my_following as (
    select distinct pf.following_profile_id as profile_id
    from public.profile_follows pf
    join public.profiles p on p.id = pf.follower_profile_id
    where p.user_id = (select uid from me)
  ),
  blocked as (
    select case when ub.blocker_user_id = (select uid from me)
                then ub.blocked_user_id else ub.blocker_user_id end as other_user_id
    from public.user_blocks ub
    where ub.blocker_user_id = (select uid from me)
       or ub.blocked_user_id = (select uid from me)
  ),
  visible as (
    select g.id
    from public.games g
    join public.events e on e.id = g.event_id and e.event_type = 'game'
    where (select uid from me) is not null
      and g.id = any (p_game_ids[1:200])
      and e.is_cancelled = false
      and public._can_view_game(g.id)
  )
  select gr.game_id, count(distinct gr.user_id)::int as following_count
  from public.game_roster gr
  join visible v on v.id = gr.game_id
  join my_following mf on mf.profile_id = gr.profile_id
  where gr.status = 'active'
    and gr.role in ('host', 'player', 'sub')
    and gr.user_id <> (select uid from me)
    and not exists (select 1 from blocked b where b.other_user_id = gr.user_id)
    and not exists (select 1 from public.privacy_settings ps
                    where ps.user_id = gr.user_id and ps.show_game_history = false)
  group by gr.game_id;
$function$;

-- ---------------------------------------------------------------------------------------------------------
-- 4. Post-conditions: same overload set, every attribute unchanged, every body reads events.
-- ---------------------------------------------------------------------------------------------------------
do $post$
declare
  v_bad text;
begin
  select string_agg(coalesce(a.sig, p.oid::regprocedure::text), ', ') into v_bad
    from kan723_attr a
    full join (select * from pg_proc where pronamespace = 'public'::regnamespace
                and proname in ('rpc_get_nearby_games', 'rpc_games_following_joined')) p on p.oid = a.oid
   where a.oid is null or p.oid is null
      or p.proowner <> a.proowner or p.proacl is distinct from a.proacl or p.prosecdef <> a.prosecdef
      or p.proconfig is distinct from a.proconfig or p.provolatile <> a.provolatile or p.prolang <> a.prolang
      or pg_get_function_result(p.oid) <> a.res or pg_get_function_arguments(p.oid) <> a.args
      or p.prosrc not like '%KAN-723%'
      or p.prosrc not like '%join public.events e%on e.id = g.event_id and e.event_type = ''game''%';
  if v_bad is not null then
    raise exception 'KAN-723 post: overload set, attributes or body differ from expectation: %', v_bad;
  end if;
end
$post$;

commit;
