-- Migration: add_rpc_get_nearby_venues
-- Returns nearby active venues within a given radius using PostGIS ST_DWithin.
-- One row per venue (sports aggregated into an array).
-- Requires: PostGIS extension, venues table with geography(Point,4326) column.

create or replace function rpc_get_nearby_venues(
  p_lat          double precision,
  p_lng          double precision,
  p_radius_meters integer,
  p_sport_id     uuid    default null,
  p_sort         text    default 'distance'
)
returns table (
  id               uuid,
  name_en          text,
  name_ar          text,
  city             text,
  area             text,
  is_indoor        boolean,
  price_per_hour   numeric,
  latitude         double precision,
  longitude        double precision,
  distance_meters  double precision,
  sport_names      text[]
)
language sql
stable
security definer
set search_path = public
as $$
  select
    v.id,
    v.name_en,
    v.name_ar,
    v.city,
    v.area,
    v.is_indoor,
    v.price_per_hour,
    -- Extract lat/lng from the stored geography point
    st_y(v.location::geometry)  as latitude,
    st_x(v.location::geometry)  as longitude,
    st_distance(
      v.location::geography,
      st_point(p_lng, p_lat)::geography
    )                             as distance_meters,
    -- Aggregate all sport names for this venue
    coalesce(
      array_agg(distinct s.name order by s.name)
        filter (where s.name is not null),
      '{}'::text[]
    )                             as sport_names
  from venues v
  left join venue_sports vs on vs.venue_id = v.id
  left join sports      s  on s.id         = vs.sport_id
  where
    v.is_active = true
    -- PostGIS indexed radius filter (geography, so units are metres)
    and st_dwithin(
      v.location::geography,
      st_point(p_lng, p_lat)::geography,
      p_radius_meters
    )
    -- Optional sport filter: when p_sport_id is provided, the venue must
    -- support that sport (but we still return all sport names for display).
    and (
      p_sport_id is null
      or exists (
        select 1
        from venue_sports vs2
        where vs2.venue_id = v.id
          and vs2.sport_id = p_sport_id
      )
    )
  group by
    v.id, v.name_en, v.name_ar, v.city, v.area,
    v.is_indoor, v.price_per_hour, v.location
  order by
    case when lower(p_sort) = 'distance'
      then st_distance(
             v.location::geography,
             st_point(p_lng, p_lat)::geography
           )
    end asc nulls last,
    -- default ordering: composite score descending, then name
    case when lower(p_sort) != 'distance'
      then v.composite_score
    end desc nulls last,
    v.name_en asc
$$;

-- Allow authenticated and anonymous callers through PostgREST
grant execute on function rpc_get_nearby_venues(
  double precision, double precision, integer, uuid, text
) to authenticated, anon;
