-- KAN-718 (Epic KAN-708, phase 2): the single-game update writers write the events parent themselves.
-- Authored from the live pg_get_functiondef (2026-11-13). Signatures, return shapes, SECURITY DEFINER,
-- search_path, owner and ACL unchanged (CREATE OR REPLACE keeps owner and ACL).
-- Per writer, the games UPDATE is unchanged except:
--   * RETURNING <alias>.* INTO v_g, so the final row (after every games BEFORE trigger) is in hand;
--   * the NOT FOUND check stays directly after the UPDATE (PERFORM would reset FOUND);
--   * PERFORM public.kan718_game_event_sync(v_g) writes that row's shared facts to the events parent;
--   * a writer that has venue_space_id in its SET list also sets venue_id, geo_location_id, area_id,
--     joining_rule and cost_cover from public.kan718_game_derive(<row with the new space>, <old row>):
--     the derivation trg_kan713_games_a/b/c did. While those triggers stay attached they recompute the
--     same values (idempotent), so the result is identical with and without them.
-- Ordered behaviour change (coordinator, KAN-717 F4): rpc_cancel_game_kan712_inner gains the KAN-810 repeat-cancel
-- guard (the intended "post B" of 20261111121500, md5 39f49623...): a second cancel returns 'cancelled' and keeps the
-- first cancel's cancelled_at / reason. 20261104112000_kan810_cancel_game_idempotent.sql is stale and NOT applied.

CREATE OR REPLACE FUNCTION public.rpc_cancel_game_kan712_inner(p_game_id uuid, p_reason text DEFAULT NULL::text)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_g public.games;
BEGIN
  UPDATE public.games
  SET is_cancelled = true, cancelled_at = now(), cancelled_reason = p_reason
  WHERE id = p_game_id
    AND event_id IN (SELECT e.id FROM public.events e   -- KAN-913: host / cancel predicate read from the parent
                      WHERE e.event_type = 'game'
                        AND (e.creator_user_id = auth.uid() OR public.is_admin(auth.uid()))
                        AND e.is_cancelled IS NOT TRUE)   -- KAN-810: a repeat cancel keeps the first cancel's cancelled_at / reason
  RETURNING * INTO v_g;
  IF NOT FOUND THEN
    -- KAN-810: already cancelled, and the caller may cancel it: same result as before, nothing rewritten.
    IF EXISTS (SELECT 1 FROM public.games g
                 JOIN public.events e ON e.id = g.event_id AND e.event_type = 'game'   -- KAN-913
                WHERE g.id = p_game_id
                  AND e.is_cancelled IS TRUE
                  AND (e.creator_user_id = auth.uid() OR public.is_admin(auth.uid()))) THEN
      RETURN 'cancelled';
    END IF;
    RAISE EXCEPTION USING errcode='P0001', message='not_host_or_not_found';
  END IF;
  PERFORM public.kan718_game_event_sync(v_g);   -- KAN-718: the parent is written here
  RETURN 'cancelled';
END$function$;

CREATE OR REPLACE FUNCTION public.rpc_reschedule_game_kan712_inner(p_game_id uuid, p_start_at timestamp with time zone, p_end_at timestamp with time zone)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_g public.games;
BEGIN
  IF p_end_at <= p_start_at THEN
    RAISE EXCEPTION USING errcode='P0001', message='invalid_time_range';
  END IF;
  UPDATE public.games
  SET start_at = p_start_at, end_at = p_end_at
  WHERE id = p_game_id
    AND (creator_user_id = auth.uid() OR public.is_admin(auth.uid()))
  RETURNING * INTO v_g;
  IF NOT FOUND THEN
    RAISE EXCEPTION USING errcode='P0001', message='not_host_or_not_found';
  END IF;
  PERFORM public.kan718_game_event_sync(v_g);   -- KAN-718: the parent is written here
  RETURN 'rescheduled';
END$function$;

CREATE OR REPLACE FUNCTION public.rpc_update_game_kan712_inner(p_game_id uuid, p_start_at timestamp with time zone, p_end_at timestamp with time zone, p_title text DEFAULT NULL::text, p_venue_space_id uuid DEFAULT NULL::uuid, p_clear_venue boolean DEFAULT false, p_listing_visibility text DEFAULT NULL::text, p_join_policy text DEFAULT NULL::text, p_allow_spectators boolean DEFAULT NULL::boolean, p_allows_waitlist boolean DEFAULT NULL::boolean, p_min_skill integer DEFAULT NULL::integer, p_max_skill integer DEFAULT NULL::integer, p_clear_skill boolean DEFAULT false, p_rules jsonb DEFAULT NULL::jsonb, p_min_players integer DEFAULT NULL::integer, p_max_players integer DEFAULT NULL::integer, p_price_aed numeric DEFAULT NULL::numeric)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_roster_count integer;
  v_g public.games;
begin
  if p_end_at <= p_start_at then
    raise exception using errcode='P0001', message='invalid_time_range';
  end if;
  -- CEO 2026-10-08: saving a game needs a price (0 is "Free"); an old game with no
  -- price gets one the first time its host saves it.
  if p_price_aed is null or p_price_aed < 0 then
    raise exception using errcode='P0001', message='price_required';
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

  -- KAN-912: shared facts read from events e (authoritative); game-only columns from g; SET targets unchanged.
  -- KAN-718: location facts derived from the new space (kan718_game_derive); the parent is written below.
  update public.games g
  set start_at           = p_start_at,
      end_at             = p_end_at,
      title              = coalesce(nullif(p_title, ''), e.title),
      venue_space_id     = case
                             when p_clear_venue then null
                             else coalesce(p_venue_space_id, g.venue_space_id)
                           end,
      (venue_id, geo_location_id, area_id, joining_rule, cost_cover)
                         = (select d.venue_id, d.geo_location_id, d.area_id, d.joining_rule, d.cost_cover
                              from public.kan718_game_derive(
                                     jsonb_populate_record(g, jsonb_build_object('venue_space_id',
                                       case when p_clear_venue then null
                                            else coalesce(p_venue_space_id, g.venue_space_id) end)),
                                     g) d),
      listing_visibility = coalesce(p_listing_visibility, e.listing_visibility),
      join_policy        = coalesce(p_join_policy, e.join_policy),
      allow_spectators   = coalesce(p_allow_spectators, g.allow_spectators),
      allows_waitlist    = coalesce(p_allows_waitlist, g.allows_waitlist),
      min_skill          = case when p_clear_skill then null
                                else coalesce(p_min_skill, e.min_skill) end,
      max_skill          = case when p_clear_skill then null
                                else coalesce(p_max_skill, e.max_skill) end,
      capacity           = greatest(
                             coalesce(p_max_players, e.capacity),
                             v_roster_count
                           ),
      rules              = coalesce(p_rules, g.rules, '{}'::jsonb)
                           || case when p_min_players is not null
                                then jsonb_build_object('min_players', p_min_players)
                                else '{}'::jsonb end
                           || case when p_max_players is not null
                                then jsonb_build_object('max_players', p_max_players)
                                else '{}'::jsonb end,
      price_aed          = round(p_price_aed, 2)
  from public.events e
  where e.id = g.event_id
    and e.event_type = 'game'
    and g.id = p_game_id
    and e.is_cancelled = false
    and e.end_at > now()
    and (e.creator_user_id = auth.uid() or public.is_admin(auth.uid()))
  returning g.* into v_g;

  if not found then
    raise exception using errcode='P0001', message='not_host_or_not_found';
  end if;
  perform public.kan718_game_event_sync(v_g);

  return 'updated';
end$function$;

CREATE OR REPLACE FUNCTION public.rpc_update_game_legacy_v1_kan712_inner(p_game_id uuid, p_start_at timestamp with time zone, p_end_at timestamp with time zone, p_title text DEFAULT NULL::text, p_venue_space_id uuid DEFAULT NULL::uuid, p_clear_venue boolean DEFAULT false, p_listing_visibility text DEFAULT NULL::text, p_join_policy text DEFAULT NULL::text, p_allow_spectators boolean DEFAULT NULL::boolean, p_allows_waitlist boolean DEFAULT NULL::boolean, p_min_skill integer DEFAULT NULL::integer, p_max_skill integer DEFAULT NULL::integer, p_clear_skill boolean DEFAULT false, p_rules jsonb DEFAULT NULL::jsonb, p_min_players integer DEFAULT NULL::integer, p_max_players integer DEFAULT NULL::integer)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_roster_count integer;
  v_g public.games;
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

  -- KAN-718: location facts derived from the new space (kan718_game_derive); the parent is written below.
  update public.games g
  set start_at           = p_start_at,
      end_at             = p_end_at,
      title              = coalesce(nullif(p_title, ''), g.title),
      venue_space_id     = case
                             when p_clear_venue then null
                             else coalesce(p_venue_space_id, g.venue_space_id)
                           end,
      (venue_id, geo_location_id, area_id, joining_rule, cost_cover)
                         = (select d.venue_id, d.geo_location_id, d.area_id, d.joining_rule, d.cost_cover
                              from public.kan718_game_derive(
                                     jsonb_populate_record(g, jsonb_build_object('venue_space_id',
                                       case when p_clear_venue then null
                                            else coalesce(p_venue_space_id, g.venue_space_id) end)),
                                     g) d),
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
    and (g.creator_user_id = auth.uid() or public.is_admin(auth.uid()))
  returning g.* into v_g;

  if not found then
    raise exception using errcode='P0001', message='not_host_or_not_found';
  end if;
  perform public.kan718_game_event_sync(v_g);

  return 'updated';
end$function$;

CREATE OR REPLACE FUNCTION public.rpc_booking_hold_for_game_kan712_inner(p_game_id uuid, p_space_id uuid, p_start timestamp with time zone, p_end timestamp with time zone)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  g   record;
  vid uuid;
  bid uuid;
  v_g public.games;
BEGIN
  SELECT * INTO g FROM public.kan714_games_read WHERE id = p_game_id;
  IF NOT FOUND THEN RAISE EXCEPTION USING errcode='P0001', message='game_not_found'; END IF;

  SELECT s.venue_id INTO vid FROM public.venue_spaces s WHERE s.id = p_space_id;
  IF vid IS NULL THEN RAISE EXCEPTION USING errcode='P0001', message='space_not_found'; END IF;

  IF NOT (g.creator_user_id = auth.uid()
          OR public.is_venue_admin(auth.uid(), vid)
          OR public.is_admin(auth.uid())) THEN
    RAISE EXCEPTION USING errcode='P0001', message='not_authorized';
  END IF;

  INSERT INTO public.venue_bookings(venue_space_id, starts_at, ends_at, source_type, source_id, status, created_by)
  VALUES (p_space_id, p_start, p_end, 'game', p_game_id, 'confirmed', auth.uid())
  RETURNING id INTO bid;

  -- KAN-718: location facts derived from the new space (kan718_game_derive); the parent is written here.
  UPDATE public.games gm
     SET venue_space_id = p_space_id,
         (venue_id, geo_location_id, area_id, joining_rule, cost_cover)
           = (SELECT d.venue_id, d.geo_location_id, d.area_id, d.joining_rule, d.cost_cover
                FROM public.kan718_game_derive(
                       jsonb_populate_record(gm, jsonb_build_object('venue_space_id', p_space_id)), gm) d)
   WHERE gm.id = p_game_id
  RETURNING gm.* INTO v_g;
  PERFORM public.kan718_game_event_sync(v_g);

  RETURN bid;
END;
$function$;
