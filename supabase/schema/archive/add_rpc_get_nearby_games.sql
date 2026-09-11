-- Migration: add_rpc_get_nearby_games
-- Returns nearby upcoming/live games within a given radius using PostGIS ST_DWithin.
-- Games are located via their venue_space_id → venue_spaces → venues.location.
-- Only games that have a resolved venue location are returned.
-- Requires: PostGIS extension, venues table with geography(Point,4326) column.

create or replace function rpc_get_nearby_games(
  p_lat           double precision,
  p_lng           double precision,
  p_radius_meters integer,
  p_sport_id      uuid    default null,
  p_sort          text    default 'distance'
)
returns table (
  id               uuid,
  title            text,
  sport_name       text,
  scheduled_at     timestamptz,
  status           text,
  venue_name       text,
  latitude         double precision,
  longitude        double precision,
  distance_meters  double precision,
  player_count     integer,
  spots_remaining  integer,
  is_public        boolean
)
language sql
stable
security definer
set search_path = public
as $$
  with
  -- Resolve active player count per game in one pass
  roster_counts as (
    select
      game_id,
      count(*)::integer as active_count
    from game_roster
    where status = 'active'
    group by game_id
  )
  select
    g.id,
    g.title,
    g.sport                                                  as sport_name,
    g.start_at                                               as scheduled_at,
    case
      when g.is_cancelled                           then 'ended'
      when now() between g.start_at and g.end_at   then 'live'
      when g.start_at > now()                       then 'upcoming'
      else 'ended'
    end                                                      as status,
    v.name_en                                                as venue_name,
    st_y(v.location::geometry)                               as latitude,
    st_x(v.location::geometry)                               as longitude,
    st_distance(
      v.location::geography,
      st_point(p_lng, p_lat)::geography
    )                                                        as distance_meters,
    coalesce(rc.active_count, 0)                             as player_count,
    greatest(g.capacity - coalesce(rc.active_count, 0), 0)  as spots_remaining,
    g.is_public
  from games g
  -- Resolve venue location via venue_spaces
  join venue_spaces vs on vs.id  = g.venue_space_id
  join venues       v  on v.id   = vs.venue_id
  -- Active player count (may be null → treated as 0)
  left join roster_counts rc on rc.game_id = g.id
  where
    -- Only non-cancelled, non-ended games (allow live + upcoming)
    g.is_cancelled = false
    and g.end_at > now()
    -- Only public games
    and g.is_public = true
    -- Venue must have a location
    and v.location is not null
    -- PostGIS radius filter
    and st_dwithin(
      v.location::geography,
      st_point(p_lng, p_lat)::geography,
      p_radius_meters
    )
    -- Optional sport filter: match sport name against sports table
    and (
      p_sport_id is null
      or exists (
        select 1 from sports sp
        where sp.id = p_sport_id
          and lower(sp.name) = lower(g.sport)
      )
    )
  order by
    case when lower(p_sort) = 'distance'
      then st_distance(
             v.location::geography,
             st_point(p_lng, p_lat)::geography
           )
    end asc nulls last,
    -- default: soonest first
    case when lower(p_sort) != 'distance'
      then g.start_at
    end asc nulls last
$$;

-- Allow authenticated and anonymous callers through PostgREST
grant execute on function rpc_get_nearby_games(
  double precision, double precision, integer, uuid, text
) to authenticated, anon;
