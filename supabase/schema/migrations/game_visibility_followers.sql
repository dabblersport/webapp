-- Game visibility: public | followers | private
--
-- The composer used to offer 'friends', but the games check constraint only
-- allowed ('public','private') — picking Friends failed at insert. The app's
-- social graph is followers (public.profile_follows), so the middle tier is
-- now 'followers': visible/joinable only by people who follow the host.
--
-- Three pieces:
-- 1. games_listing_visibility_check gains 'followers'.
-- 2. can_view_with_scope gains 'followers' (viewer follows owner, mapped
--    through profiles user_id → profile id) and an explicit 'private'
--    (owner-only) branch. can_current_user_join_game / rpc_join_game and
--    _can_view_game_for_join all route through this, so join gating follows.
-- 3. rpc_get_nearby_games becomes SECURITY DEFINER with a visibility gate.
--    It was invoker-rights against RLS-locked games (returned nothing for
--    app users) and had no visibility filter at all.

alter table public.games drop constraint if exists games_listing_visibility_check;
alter table public.games add constraint games_listing_visibility_check
  check (listing_visibility = any (array['public'::text, 'followers'::text, 'private'::text]));

create or replace function public.can_view_with_scope(
  viewer_user_id uuid,
  owner_user_id uuid,
  scope text,
  p_squad_id uuid default null::uuid
) returns boolean
language plpgsql
stable
set search_path to 'public', 'pg_temp'
as $$
begin
  if viewer_user_id is not null and public.is_blocked(viewer_user_id, owner_user_id) then return false; end if;
  case scope
    when 'public' then return true;
    when 'followers' then
      if viewer_user_id is null then return false; end if;
      if viewer_user_id = owner_user_id then return true; end if;
      return exists (
        select 1
        from public.profile_follows pf
        join public.profiles fp on fp.id = pf.follower_profile_id
        join public.profiles op on op.id = pf.following_profile_id
        where fp.user_id = viewer_user_id
          and op.user_id = owner_user_id
      );
    when 'private' then
      if viewer_user_id is null then return false; end if;
      return viewer_user_id = owner_user_id;
    when 'circle' then
      if viewer_user_id is null then return false; end if;
      return public.are_synced(viewer_user_id, owner_user_id);
    when 'hidden' then
      if viewer_user_id is null then return false; end if;
      return viewer_user_id = owner_user_id;
    when 'invite' then
      if viewer_user_id is null then return false; end if;
      return viewer_user_id = owner_user_id or public.is_admin(viewer_user_id);
    when 'link' then
      if viewer_user_id is null then return false; end if;
      return viewer_user_id = owner_user_id or public.is_admin(viewer_user_id);
    when 'squad' then
      if viewer_user_id is null or p_squad_id is null then return false; end if;
      return public.is_in_squad(viewer_user_id, p_squad_id);
    else return false;
  end case;
end;
$$;

create or replace function public.rpc_get_nearby_games(
  p_lat double precision,
  p_lng double precision,
  p_radius_meters integer default 10000,
  p_sport_id uuid default null::uuid,
  p_sort text default 'distance'::text
) returns table(
  id uuid, title text, sport_name text, scheduled_at timestamptz,
  status text, venue_name text, latitude double precision,
  longitude double precision, distance_meters double precision,
  player_count integer, spots_remaining integer, is_public boolean
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
    (g.listing_visibility = 'public')      as is_public
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
    -- visibility gate: public to all, otherwise creator / scope check
    -- (followers → viewer follows the host; private → creator only)
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
