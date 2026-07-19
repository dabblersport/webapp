-- Add min_skill / max_skill to rpc_get_nearby_games so the games list can
-- filter by skill level (Beginner 1-3, Intermediate 4-6, Advanced 7-8,
-- Pro 9-10 — same mapping as the game composer). Return-type changes need
-- a drop + recreate; body is otherwise identical to
-- game_visibility_followers.sql (visibility gate included).

drop function if exists public.rpc_get_nearby_games(double precision, double precision, integer, uuid, text);

create function public.rpc_get_nearby_games(
  p_lat double precision,
  p_lng double precision,
  p_radius_meters integer default 10000,
  p_sport_id uuid default null::uuid,
  p_sort text default 'distance'::text
) returns table(
  id uuid, title text, sport_name text, scheduled_at timestamptz,
  status text, venue_name text, latitude double precision,
  longitude double precision, distance_meters double precision,
  player_count integer, spots_remaining integer, is_public boolean,
  min_skill integer, max_skill integer
)
language sql
stable
security definer
set search_path to 'public', 'pg_temp'
as $$
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
    (g.capacity - coalesce(roster.cnt, 0))::int as spots_remaining,
    (g.listing_visibility = 'public')      as is_public,
    g.min_skill,
    g.max_skill
  from   games g
  join   geo_locations gl on g.geo_location_id = gl.id
  join   sports s         on s.id = g.sport_id
  left   join venue_spaces vs on vs.id = g.venue_space_id
  left   join venues ven      on ven.id = vs.venue_id
  left   join lateral (
    select count(*) as cnt
    from   game_roster gr
    where  gr.game_id = g.id
      and  gr.status  = 'active'
      and  gr.role    = 'player'
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
           g.listing_visibility = 'public'
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
$$;
