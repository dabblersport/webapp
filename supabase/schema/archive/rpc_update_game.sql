-- rpc_update_game — host edits a game from the Quick Game composer.
--
-- Auth model mirrors rpc_reschedule_game: SECURITY DEFINER with an explicit
-- creator-or-admin check in the WHERE clause (public.games has RLS enabled
-- with no policies — all writes go through RPCs).
--
-- Sport / format (sport_id, sport_variant_id) are intentionally NOT
-- editable: the roster derives from the variant chosen at creation. Venue
-- changes are allowed — the composer only offers spaces matching the game's
-- sport + variant, and the geo-inheritance triggers keep geo columns in sync.
--
-- Player counts follow rpc_create_game's semantics: p_max_players drives
-- `capacity` (never below the current active roster) and both values are
-- mirrored into the rules jsonb. p_rules replaces the whole rules jsonb
-- first (the composer owns it: duration_minutes + notes), then the player
-- keys are merged on top.

create or replace function public.rpc_update_game(
  p_game_id uuid,
  p_start_at timestamptz,
  p_end_at timestamptz,
  p_title text default null,
  p_venue_space_id uuid default null,
  p_clear_venue boolean default false,
  p_listing_visibility text default null,
  p_join_policy text default null,
  p_allow_spectators boolean default null,
  p_allows_waitlist boolean default null,
  p_min_skill integer default null,
  p_max_skill integer default null,
  p_clear_skill boolean default false,
  p_rules jsonb default null,
  p_min_players integer default null,
  p_max_players integer default null
) returns text
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_roster_count integer;
  v_rules jsonb;
begin
  if p_end_at <= p_start_at then
    raise exception using errcode='P0001', message='invalid_time_range';
  end if;
  if p_max_players is not null and p_max_players < 1 then
    raise exception using errcode='P0001', message='invalid_max_players';
  end if;
  if p_min_players is not null and p_min_players < 1 then
    raise exception using errcode='P0001', message='invalid_min_players';
  end if;
  if p_min_players is not null and p_max_players is not null
     and p_min_players > p_max_players then
    raise exception using errcode='P0001', message='invalid_player_range';
  end if;

  select count(*) into v_roster_count
  from public.game_roster
  where game_id = p_game_id and status = 'active';

  update public.games g
  set start_at           = p_start_at,
      end_at             = p_end_at,
      title              = coalesce(nullif(p_title, ''), g.title),
      venue_space_id     = case
                             when p_clear_venue then null
                             else coalesce(p_venue_space_id, g.venue_space_id)
                           end,
      listing_visibility = coalesce(p_listing_visibility, g.listing_visibility),
      join_policy        = coalesce(p_join_policy, g.join_policy),
      allow_spectators   = coalesce(p_allow_spectators, g.allow_spectators),
      allows_waitlist    = coalesce(p_allows_waitlist, g.allows_waitlist),
      min_skill          = case when p_clear_skill then null
                                else coalesce(p_min_skill, g.min_skill) end,
      max_skill          = case when p_clear_skill then null
                                else coalesce(p_max_skill, g.max_skill) end,
      capacity           = greatest(
                             coalesce(p_max_players, g.capacity),
                             v_roster_count
                           ),
      rules              = coalesce(p_rules, g.rules, '{}'::jsonb)
                           || case when p_min_players is not null
                                then jsonb_build_object('min_players', p_min_players)
                                else '{}'::jsonb end
                           || case when p_max_players is not null
                                then jsonb_build_object('max_players', p_max_players)
                                else '{}'::jsonb end
  where g.id = p_game_id
    and g.is_cancelled = false
    and g.end_at > now()
    and (g.creator_user_id = auth.uid() or public.is_admin(auth.uid()));

  if not found then
    raise exception using errcode='P0001', message='not_host_or_not_found';
  end if;

  return 'updated';
end$$;
