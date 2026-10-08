-- rpc_get_nearby_games: close the block leak on the public branch (team Luxor).
--
-- Record of what was applied to project wtncuzcskpigqpmnxwws on 2026-10-08 with
-- a single execute_sql CREATE OR REPLACE (no DROP, no rename: signature, return
-- type, SECURITY DEFINER, search_path 'public, pg_temp' and grants are unchanged).
--
-- Problem: the WHERE clause had `g.listing_visibility = 'public' OR ...`. That
-- first branch short-circuits can_view_with_scope(), whose first step is
-- is_blocked(), so a viewer blocked by a host (or blocking the host) still saw
-- the host's public games through this RPC. v_game_card already hides them.
-- Fix: the public branch becomes
--   (g.listing_visibility = 'public' AND NOT public.is_blocked(auth.uid(), g.creator_user_id))
-- is_blocked(user_a, user_b) is symmetric (either direction) and returns false
-- for a NULL uid (anon: `blocker_user_id = NULL` is never true), so anon still
-- sees public games. The other branches (own games, can_view_with_scope) are as before.
--
-- Verified live (rolled-back blocks, no row left behind):
--   * one overload; grants PUBLIC, anon, authenticated, postgres, service_role; secdef=true;
--     search_path=public, pg_temp; the function body contains the guard.
--   * is_blocked(NULL, host) = false; anon sees the host's public game (1).
--   * viewer before the block sees the game (1); after host blocks viewer: 0.
--   * world-wide radius, same viewer: blocked host's games 2 -> 0, other hosts' games 1 -> 1.
--   * the host still sees their own game (1); anon still sees it after the block (1).

CREATE OR REPLACE FUNCTION public.rpc_get_nearby_games(p_lat double precision, p_lng double precision, p_radius_meters integer DEFAULT 10000, p_sport_id uuid DEFAULT NULL::uuid, p_sort text DEFAULT 'distance'::text)
 RETURNS TABLE(id uuid, title text, sport_name text, scheduled_at timestamp with time zone, status text, venue_name text, latitude double precision, longitude double precision, distance_meters double precision, player_count integer, spots_remaining integer, is_public boolean, min_skill integer, max_skill integer, end_at timestamp with time zone, variant_name_en text, variant_name_ar text, cost_cover text, joining_rule text, host_verified boolean, favorite_count integer, favourited_by_me boolean)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  select
    g.id,
    coalesce(g.title, 'Untitled Game')    as title,
    s.name_en                              as sport_name,
    g.start_at                             as scheduled_at,
    case
      when g.is_cancelled         then 'cancelled'
      when now() >= g.end_at      then 'ended'
      when now() >= g.start_at    then 'live'
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
    greatest(g.capacity - coalesce(roster.cnt, 0), 0)::int as spots_remaining,
    (g.listing_visibility = 'public')      as is_public,
    g.min_skill,
    g.max_skill,
    g.end_at,
    sv.name_en                             as variant_name_en,
    sv.name_ar                             as variant_name_ar,
    g.cost_cover,
    g.joining_rule,
    (coalesce((select pv.verified from profile_verifications pv
                where pv.profile_id = g.creator_profile_id), false)
     or exists (select 1 from organiser o
                where o.profile_id = g.creator_profile_id and o.sport = s.sport_key
                  and o.is_verified and o.is_active)) as host_verified,
    (select count(*) from public.favorites f where f.game_id = g.id)::int as favorite_count,
    exists (select 1 from public.favorites f
            where f.game_id = g.id and f.user_id = auth.uid()) as favourited_by_me
  from   games g
  join   geo_locations gl on g.geo_location_id = gl.id
  join   sports s         on s.id = g.sport_id
  left   join sport_variants sv on sv.id = g.sport_variant_id
  left   join venue_spaces vs on vs.id = g.venue_space_id
  left   join venues ven      on ven.id = coalesce(vs.venue_id, g.venue_id)
  left   join lateral (
    select count(*) as cnt
    from   game_roster gr
    where  gr.game_id = g.id
      and  gr.status  = 'active'
      and  (gr.role = 'player' or (gr.role = 'host' and g.game_type = 'hosted'))
  ) roster on true
  where  g.is_cancelled = false
    and  g.start_at > now()
    and  st_dwithin(
           gl.location,
           st_setsrid(st_makepoint(p_lng, p_lat), 4326)::geography,
           p_radius_meters
         )
    and  (p_sport_id is null or g.sport_id = p_sport_id)
    and  (
           (g.listing_visibility = 'public' and not public.is_blocked(auth.uid(), g.creator_user_id))
           or g.creator_user_id = auth.uid()
           or public.can_view_with_scope(
                auth.uid(), g.creator_user_id, g.listing_visibility, g.squad_id
              )
         )
  order  by
    case when p_sort = 'distance'
         then st_distance(
                gl.location,
                st_setsrid(st_makepoint(p_lng, p_lat), 4326)::geography
              )
    end asc nulls last,
    g.start_at asc
  limit 50;
$function$;
