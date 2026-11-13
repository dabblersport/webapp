-- KAN-718 (Epic KAN-708, phase 2): the create writers write the events parent themselves.
-- Authored from the live pg_get_functiondef (2026-11-13). Signatures, return shapes, SECURITY DEFINER,
-- search_path, owner and ACL unchanged (CREATE OR REPLACE keeps owner and ACL).
-- Only the INSERT INTO public.games statement changes:
--   1. the row is assembled in v_g, given its id, and passed through public.kan718_game_derive (the
--      venue_space_id -> venue / geo / area / joining_rule / cost_cover derivation that kan713 a/b/c did);
--   2. the INSERT carries the derived values (and, for rpc_challenge_spawn_game, the five location columns
--      it used to leave to the triggers) and RETURNING * INTO v_g;
--   3. public.kan718_game_event_sync(v_g, true) inserts the events parent from the final row.
-- Order: games row first, parent second, in the same statement sequence. games_event_id_fkey and
-- trg_games_event_link_check are DEFERRABLE INITIALLY DEFERRED and hold at commit; the parent cannot be
-- inserted first while trg_zz_kan712_games_guard is attached (it inserts the parent itself and would
-- collide on events_pkey). trg_kan718_games_series_occurrence handles games-first explicitly.
-- Ordered behaviour change (coordinator, KAN-717 F3): rpc_challenge_spawn_game could not create a game (no space:
-- sport_not_challenge, as it never set sport_id; with a space: 23514 events_game_join_policy_check on 'squad').
-- It now writes sport_id from the challenge (the space's sport still wins on COALESCE only when sport_id is NULL,
-- so the challenge's sport is the value) and join_policy 'invite'.

CREATE OR REPLACE FUNCTION public.rpc_create_game_legacy_v2(p_actor_type text, p_sport_id uuid, p_sport_variant_id uuid, p_title text DEFAULT NULL::text, p_venue_space_id uuid DEFAULT NULL::uuid, p_start_at timestamp with time zone DEFAULT NULL::timestamp with time zone, p_end_at timestamp with time zone DEFAULT NULL::timestamp with time zone, p_bench_slots integer DEFAULT 0, p_listing_visibility text DEFAULT 'public'::text, p_join_policy text DEFAULT 'open'::text, p_min_skill integer DEFAULT NULL::integer, p_max_skill integer DEFAULT NULL::integer, p_rules jsonb DEFAULT NULL::jsonb, p_squad_id uuid DEFAULT NULL::uuid, p_allow_spectators boolean DEFAULT false, p_allows_waitlist boolean DEFAULT false, p_sport_specific_data jsonb DEFAULT NULL::jsonb, p_cost_cover text DEFAULT NULL::text, p_geo_location_id uuid DEFAULT NULL::uuid, p_area_id uuid DEFAULT NULL::uuid, p_lat double precision DEFAULT NULL::double precision, p_lng double precision DEFAULT NULL::double precision, p_min_players integer DEFAULT NULL::integer, p_max_players integer DEFAULT NULL::integer, p_price_aed numeric DEFAULT NULL::numeric)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  pid uuid; uid uuid; gid uuid; gtype text;
  v_sport record; v_variant record;
  v_required integer; v_players_per_side integer;
  v_geo_id uuid; v_area_id uuid; v_venue_id uuid;
  v_joining_rule text; v_cost_cover text;
  v_capacity integer; v_rules jsonb;
  v_g public.games;
BEGIN
  pid := public.choose_actor(p_actor_type);
  -- KAN-440 persona gate (CEO ruling 2026-10-06): player and organiser may create a game;
  -- socialiser and host may not. Also re-asserts that the caller owns the acting profile.
  -- Tests persona_type directly (the profile_type based organiser helper never matches).
  IF NOT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = pid
      AND (persona_type IN ('player', 'organiser')
           OR (persona_type = 'contributor' AND (
                 (p_actor_type = 'player' AND EXISTS (SELECT 1 FROM public.player x WHERE x.profile_id = pid))
              OR (p_actor_type = 'organiser' AND EXISTS (SELECT 1 FROM public.organiser x WHERE x.profile_id = pid)))))
      AND is_active
      AND user_id = public.effective_actor_uid()
  ) THEN
    RAISE EXCEPTION USING errcode='P0001', message='persona_not_allowed';
  END IF;
  IF p_end_at <= p_start_at THEN RAISE EXCEPTION USING errcode='P0001', message='invalid_time_range'; END IF;
  -- CEO 2026-10-08: a game cannot be created without a price (0 is "Free").
  IF p_price_aed IS NULL OR p_price_aed < 0 THEN RAISE EXCEPTION USING errcode='P0001', message='price_required'; END IF;
  SELECT * INTO v_sport FROM public.sports WHERE id = p_sport_id AND is_active = true;
  IF NOT FOUND THEN RAISE EXCEPTION USING errcode='P0001', message='invalid_sport'; END IF;
  IF v_sport.is_challenge_sport IS DISTINCT FROM true THEN RAISE EXCEPTION USING errcode='P0001', message='sport_not_challenge_eligible'; END IF;
  SELECT * INTO v_variant FROM public.sport_variants WHERE id = p_sport_variant_id AND sport_id = p_sport_id AND is_active = true;
  IF NOT FOUND THEN RAISE EXCEPTION USING errcode='P0001', message='invalid_sport_variant'; END IF;
  v_required := v_variant.required_players;
  v_players_per_side := v_variant.players_per_side;
  IF p_bench_slots < 0 OR p_bench_slots > v_players_per_side THEN RAISE EXCEPTION USING errcode='P0001', message='invalid_bench_slots'; END IF;

  -- Optional player-count overrides (UI-editable Min/Max players)
  IF p_max_players IS NOT NULL AND p_max_players < 1 THEN
    RAISE EXCEPTION USING errcode='P0001', message='invalid_max_players';
  END IF;
  IF p_min_players IS NOT NULL AND p_min_players < 1 THEN
    RAISE EXCEPTION USING errcode='P0001', message='invalid_min_players';
  END IF;
  IF p_min_players IS NOT NULL AND p_max_players IS NOT NULL AND p_min_players > p_max_players THEN
    RAISE EXCEPTION USING errcode='P0001', message='invalid_player_range';
  END IF;
  v_capacity := COALESCE(p_max_players, v_required);
  v_rules := COALESCE(p_rules, '{}'::jsonb);
  IF p_min_players IS NOT NULL THEN
    v_rules := v_rules || jsonb_build_object('min_players', p_min_players);
  END IF;
  IF p_max_players IS NOT NULL THEN
    v_rules := v_rules || jsonb_build_object('max_players', p_max_players);
  END IF;

  SELECT user_id INTO uid FROM public.profiles WHERE id = pid;
  IF uid IS NULL THEN RAISE EXCEPTION USING errcode='P0001', message='creator_profile_not_found'; END IF;
  IF p_venue_space_id IS NOT NULL THEN
    SELECT v.geo_location_id, v.area_id, v.id INTO v_geo_id, v_area_id, v_venue_id
      FROM public.venue_spaces vs JOIN public.venues v ON v.id = vs.venue_id
     WHERE vs.id = p_venue_space_id;
  END IF;
  IF v_geo_id IS NULL AND p_geo_location_id IS NOT NULL THEN
    v_geo_id := p_geo_location_id; v_area_id := p_area_id;
  END IF;
  IF v_geo_id IS NULL AND p_lat IS NOT NULL AND p_lng IS NOT NULL THEN
    SELECT id, area_id INTO v_geo_id, v_area_id FROM public.geo_locations
     ORDER BY ST_Distance(location, ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326)) LIMIT 1;
  END IF;
  IF v_geo_id IS NULL THEN
    SELECT id, area_id INTO v_geo_id, v_area_id FROM public.geo_locations ORDER BY created_at LIMIT 1;
  END IF;
  IF p_venue_space_id IS NOT NULL THEN
    SELECT joining_rule INTO v_joining_rule FROM public.venue_spaces WHERE id = p_venue_space_id;
    v_cost_cover := COALESCE(p_cost_cover, v_joining_rule);
  ELSE
    v_joining_rule := 'free'; v_cost_cover := COALESCE(p_cost_cover, 'free');
  END IF;
  gtype := CASE WHEN p_actor_type = 'organiser' THEN 'hosted' ELSE 'casual' END;
  -- KAN-718: location facts derived here, events parent written here (not by triggers on games).
  v_g.id := gen_random_uuid();
  v_g.game_type := gtype; v_g.sport_id := p_sport_id; v_g.sport_variant_id := p_sport_variant_id;
  v_g.creator_profile_id := pid; v_g.creator_user_id := uid; v_g.venue_space_id := p_venue_space_id;
  v_g.venue_id := v_venue_id; v_g.capacity := v_capacity; v_g.joining_rule := v_joining_rule;
  v_g.cost_cover := v_cost_cover; v_g.geo_location_id := v_geo_id; v_g.area_id := COALESCE(v_area_id, p_area_id);
  v_g := public.kan718_game_derive(v_g, NULL);
  INSERT INTO public.games (
    id, game_type, sport_id, sport_variant_id, title,
    creator_profile_id, creator_user_id, venue_space_id, venue_id,
    start_at, end_at, capacity, bench_slots,
    listing_visibility, join_policy, min_skill, max_skill, rules,
    squad_id, allow_spectators, allows_waitlist,
    sport_specific_data, joining_rule, cost_cover,
    geo_location_id, area_id, price_aed
  ) VALUES (
    v_g.id, gtype, p_sport_id, p_sport_variant_id, p_title,
    pid, uid, p_venue_space_id, v_g.venue_id,
    p_start_at, p_end_at, v_capacity, p_bench_slots,
    p_listing_visibility, p_join_policy, p_min_skill, p_max_skill, v_rules,
    p_squad_id, p_allow_spectators, p_allows_waitlist,
    COALESCE(p_sport_specific_data, '{}'), v_g.joining_rule, v_g.cost_cover,
    v_g.geo_location_id, v_g.area_id, round(p_price_aed, 2)
  ) RETURNING * INTO v_g;
  PERFORM public.kan718_game_event_sync(v_g, true);
  gid := v_g.id;
  INSERT INTO public.game_roster (game_id, profile_id, user_id, role, status)
  VALUES (gid, pid, uid, 'host', 'active')
  ON CONFLICT (game_id, profile_id) DO UPDATE SET status='active', left_at=NULL;
  RETURN gid;
END;
$function$;

CREATE OR REPLACE FUNCTION public.rpc_create_game_legacy_v1(p_actor_type text, p_sport_id uuid, p_sport_variant_id uuid, p_title text DEFAULT NULL::text, p_venue_space_id uuid DEFAULT NULL::uuid, p_start_at timestamp with time zone DEFAULT NULL::timestamp with time zone, p_end_at timestamp with time zone DEFAULT NULL::timestamp with time zone, p_bench_slots integer DEFAULT 0, p_listing_visibility text DEFAULT 'public'::text, p_join_policy text DEFAULT 'open'::text, p_min_skill integer DEFAULT NULL::integer, p_max_skill integer DEFAULT NULL::integer, p_rules jsonb DEFAULT NULL::jsonb, p_squad_id uuid DEFAULT NULL::uuid, p_allow_spectators boolean DEFAULT false, p_allows_waitlist boolean DEFAULT false, p_sport_specific_data jsonb DEFAULT NULL::jsonb, p_cost_cover text DEFAULT NULL::text, p_geo_location_id uuid DEFAULT NULL::uuid, p_area_id uuid DEFAULT NULL::uuid, p_lat double precision DEFAULT NULL::double precision, p_lng double precision DEFAULT NULL::double precision, p_min_players integer DEFAULT NULL::integer, p_max_players integer DEFAULT NULL::integer)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  pid uuid; uid uuid; gid uuid; gtype text;
  v_sport record; v_variant record;
  v_required integer; v_players_per_side integer;
  v_geo_id uuid; v_area_id uuid; v_venue_id uuid;
  v_joining_rule text; v_cost_cover text;
  v_capacity integer; v_rules jsonb;
  v_g public.games;
BEGIN
  pid := public.choose_actor(p_actor_type);
  -- KAN-440 persona gate (CEO ruling 2026-10-06): player and organiser may create a game;
  -- socialiser and host may not. Also re-asserts that the caller owns the acting profile.
  -- Tests persona_type directly (the profile_type based organiser helper never matches).
  IF NOT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = pid
      AND persona_type IN ('player', 'organiser')
      AND is_active
      AND user_id = public.effective_actor_uid()
  ) THEN
    RAISE EXCEPTION USING errcode='P0001', message='persona_not_allowed';
  END IF;
  IF p_end_at <= p_start_at THEN RAISE EXCEPTION USING errcode='P0001', message='invalid_time_range'; END IF;
  SELECT * INTO v_sport FROM public.sports WHERE id = p_sport_id AND is_active = true;
  IF NOT FOUND THEN RAISE EXCEPTION USING errcode='P0001', message='invalid_sport'; END IF;
  IF v_sport.is_challenge_sport IS DISTINCT FROM true THEN RAISE EXCEPTION USING errcode='P0001', message='sport_not_challenge_eligible'; END IF;
  SELECT * INTO v_variant FROM public.sport_variants WHERE id = p_sport_variant_id AND sport_id = p_sport_id AND is_active = true;
  IF NOT FOUND THEN RAISE EXCEPTION USING errcode='P0001', message='invalid_sport_variant'; END IF;
  v_required := v_variant.required_players;
  v_players_per_side := v_variant.players_per_side;
  IF p_bench_slots < 0 OR p_bench_slots > v_players_per_side THEN RAISE EXCEPTION USING errcode='P0001', message='invalid_bench_slots'; END IF;

  -- Optional player-count overrides (UI-editable Min/Max players)
  IF p_max_players IS NOT NULL AND p_max_players < 1 THEN
    RAISE EXCEPTION USING errcode='P0001', message='invalid_max_players';
  END IF;
  IF p_min_players IS NOT NULL AND p_min_players < 1 THEN
    RAISE EXCEPTION USING errcode='P0001', message='invalid_min_players';
  END IF;
  IF p_min_players IS NOT NULL AND p_max_players IS NOT NULL AND p_min_players > p_max_players THEN
    RAISE EXCEPTION USING errcode='P0001', message='invalid_player_range';
  END IF;
  v_capacity := COALESCE(p_max_players, v_required);
  v_rules := COALESCE(p_rules, '{}'::jsonb);
  IF p_min_players IS NOT NULL THEN
    v_rules := v_rules || jsonb_build_object('min_players', p_min_players);
  END IF;
  IF p_max_players IS NOT NULL THEN
    v_rules := v_rules || jsonb_build_object('max_players', p_max_players);
  END IF;

  SELECT user_id INTO uid FROM public.profiles WHERE id = pid;
  IF uid IS NULL THEN RAISE EXCEPTION USING errcode='P0001', message='creator_profile_not_found'; END IF;
  IF p_venue_space_id IS NOT NULL THEN
    SELECT v.geo_location_id, v.area_id, v.id INTO v_geo_id, v_area_id, v_venue_id
      FROM public.venue_spaces vs JOIN public.venues v ON v.id = vs.venue_id
     WHERE vs.id = p_venue_space_id;
  END IF;
  IF v_geo_id IS NULL AND p_geo_location_id IS NOT NULL THEN
    v_geo_id := p_geo_location_id; v_area_id := p_area_id;
  END IF;
  IF v_geo_id IS NULL AND p_lat IS NOT NULL AND p_lng IS NOT NULL THEN
    SELECT id, area_id INTO v_geo_id, v_area_id FROM public.geo_locations
     ORDER BY ST_Distance(location, ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326)) LIMIT 1;
  END IF;
  IF v_geo_id IS NULL THEN
    SELECT id, area_id INTO v_geo_id, v_area_id FROM public.geo_locations ORDER BY created_at LIMIT 1;
  END IF;
  IF p_venue_space_id IS NOT NULL THEN
    SELECT joining_rule INTO v_joining_rule FROM public.venue_spaces WHERE id = p_venue_space_id;
    v_cost_cover := COALESCE(p_cost_cover, v_joining_rule);
  ELSE
    v_joining_rule := 'free'; v_cost_cover := COALESCE(p_cost_cover, 'free');
  END IF;
  gtype := CASE WHEN p_actor_type = 'organiser' THEN 'hosted' ELSE 'casual' END;
  -- KAN-718: location facts derived here, events parent written here (not by triggers on games).
  v_g.id := gen_random_uuid();
  v_g.game_type := gtype; v_g.sport_id := p_sport_id; v_g.sport_variant_id := p_sport_variant_id;
  v_g.creator_profile_id := pid; v_g.creator_user_id := uid; v_g.venue_space_id := p_venue_space_id;
  v_g.venue_id := v_venue_id; v_g.capacity := v_capacity; v_g.joining_rule := v_joining_rule;
  v_g.cost_cover := v_cost_cover; v_g.geo_location_id := v_geo_id; v_g.area_id := COALESCE(v_area_id, p_area_id);
  v_g := public.kan718_game_derive(v_g, NULL);
  INSERT INTO public.games (
    id, game_type, sport_id, sport_variant_id, title,
    creator_profile_id, creator_user_id, venue_space_id, venue_id,
    start_at, end_at, capacity, bench_slots,
    listing_visibility, join_policy, min_skill, max_skill, rules,
    squad_id, allow_spectators, allows_waitlist,
    sport_specific_data, joining_rule, cost_cover,
    geo_location_id, area_id
  ) VALUES (
    v_g.id, gtype, p_sport_id, p_sport_variant_id, p_title,
    pid, uid, p_venue_space_id, v_g.venue_id,
    p_start_at, p_end_at, v_capacity, p_bench_slots,
    p_listing_visibility, p_join_policy, p_min_skill, p_max_skill, v_rules,
    p_squad_id, p_allow_spectators, p_allows_waitlist,
    COALESCE(p_sport_specific_data, '{}'), v_g.joining_rule, v_g.cost_cover,
    v_g.geo_location_id, v_g.area_id
  ) RETURNING * INTO v_g;
  PERFORM public.kan718_game_event_sync(v_g, true);
  gid := v_g.id;
  INSERT INTO public.game_roster (game_id, profile_id, user_id, role, status)
  VALUES (gid, pid, uid, 'host', 'active')
  ON CONFLICT (game_id, profile_id) DO UPDATE SET status='active', left_at=NULL;
  RETURN gid;
END;
$function$;

CREATE OR REPLACE FUNCTION public.rpc_challenge_spawn_game(p_fixture_id uuid, p_start_at timestamp with time zone, p_venue_space_id uuid DEFAULT NULL::uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  f record; c record; gid uuid; title text;
  v_g public.games;
BEGIN
  SELECT * INTO f FROM public.challenge_fixtures WHERE id = p_fixture_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION USING errcode='P0001', message='fixture_not_found'; END IF;

  SELECT * INTO c FROM public.challenges WHERE id = f.challenge_id;
  IF c.owner_user_id <> auth.uid() AND NOT public.is_admin(auth.uid()) THEN
    RAISE EXCEPTION USING errcode='P0001', message='not_owner';
  END IF;

  title := COALESCE(c.title, 'Challenge') || ' — Fixture ' || f.id::text;

  -- KAN-718: location facts derived here, events parent written here (not by triggers on games).
  -- The five location columns take the values the table defaults gave the kan713 triggers.
  v_g.id := gen_random_uuid();
  v_g.game_type := 'hosted'; v_g.title := title;
  v_g.creator_profile_id := c.owner_profile_id; v_g.creator_user_id := c.owner_user_id;
  v_g.start_at := p_start_at; v_g.end_at := p_start_at + interval '90 minutes'; v_g.capacity := 22;
  v_g.listing_visibility := 'hidden'; v_g.join_policy := 'invite';   -- KAN-717 F3: 'squad' fails events_game_join_policy_check
  v_g.sport_id := c.sport_id;   -- KAN-717 F3: without it the insert raised sport_not_challenge
  v_g.venue_space_id := p_venue_space_id; v_g.squad_id := null;
  v_g.joining_rule := 'free'; v_g.cost_cover := 'free';
  v_g := public.kan718_game_derive(v_g, NULL);
  INSERT INTO public.games(
    id, game_type, title, sport_id,
    creator_profile_id, creator_user_id,
    start_at, end_at, capacity,
    listing_visibility, join_policy,
    venue_space_id, squad_id,
    venue_id, geo_location_id, area_id, joining_rule, cost_cover
  )
  VALUES (
    v_g.id, 'hosted', title, v_g.sport_id,
    c.owner_profile_id, c.owner_user_id,
    p_start_at, p_start_at + interval '90 minutes', 22,
    'hidden', 'invite',
    p_venue_space_id, null,
    v_g.venue_id, v_g.geo_location_id, v_g.area_id, v_g.joining_rule, v_g.cost_cover
  )
  RETURNING * INTO v_g;
  PERFORM public.kan718_game_event_sync(v_g, true);
  gid := v_g.id;

  UPDATE public.challenge_fixtures
  SET game_id = gid, scheduled_at = p_start_at
  WHERE id = p_fixture_id;

  PERFORM public.emit_event('challenge.fixture_spawned', 'challenge', f.challenge_id, auth.uid(),
    jsonb_build_object('fixture_id', p_fixture_id, 'game_id', gid));

  RETURN gid;
END;
$function$;
