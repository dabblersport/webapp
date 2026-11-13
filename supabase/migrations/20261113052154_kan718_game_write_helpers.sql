-- KAN-718 (Epic KAN-708, phase 2): the game write contract's two helpers.
--
-- public.kan718_game_derive(n games, o games)
--   What the games BEFORE-trigger chain did to the location facts, as a function the writers call
--   themselves. o IS NULL (o.id IS NULL) means INSERT; otherwise UPDATE with venue_space_id in the
--   SET list. Body = kan713_games_location (a) -> kan713_games_joining (b) -> kan713_games_venue_geo (c),
--   verbatim (2026-11-13 live prosrc). On INSERT it first replays, in trigger order, the checks that
--   sorted before (a): trgfn_games_block_frozen, trg_fn_games_inherit_sport_from_space,
--   trg_fn_games_require_challenge_sport, trgfn_games_set_host_user, kan611_stamp_request_id,
--   kan711_assign_event_id, so a doubly-invalid insert raises the same error first. Those triggers
--   stay on games and fire again on the real INSERT with the same result.
--
-- public.kan718_game_event_sync(g games, p_insert boolean)
--   Writes the final games row's shared facts to its events parent (what kan712_legacy_guard 2b-2d
--   did): INSERT the parent (p_insert) with the guard's unique-violation translation, or UPDATE it
--   (missing parent -> 23503 kan712_missing_parent, as the guard). A no-op when the parent already
--   holds the same values (while the guard is still attached it has already routed them).
--
-- Both: owner postgres, SECURITY INVOKER, search_path '', EXECUTE for postgres only. They are
-- called from SECURITY DEFINER writers owned by postgres.

CREATE OR REPLACE FUNCTION public.kan718_game_derive(n public.games, o public.games DEFAULT NULL)
 RETURNS public.games
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
DECLARE
  v_insert          boolean := (o).id IS NULL;
  v_uid             uuid;
  v_sport_id        uuid;
  v_capacity        integer;
  v_req             text;
  v_geo_location_id uuid;
  v_area_id         uuid;
  v_space_found     boolean;
  v_space_venue     uuid;
  v_space_changed   boolean;
  v_venue_changed   boolean;
  v_joining_rule    text;
  v_venue_id        uuid;
  v_geo_id          uuid;
BEGIN
  IF v_insert THEN
    -- trgfn_games_block_frozen
    SELECT user_id INTO v_uid FROM public.profiles WHERE id = n.creator_profile_id;
    PERFORM public.guard_user_not_frozen(v_uid);
    -- trg_fn_games_inherit_sport_from_space
    IF n.venue_space_id IS NOT NULL THEN
      SELECT vs.sport_id, vs.capacity INTO v_sport_id, v_capacity
        FROM public.venue_spaces vs WHERE vs.id = n.venue_space_id;
      n.sport_id := COALESCE(n.sport_id, v_sport_id);
      n.capacity := COALESCE(n.capacity, v_capacity);
    END IF;
    IF n.capacity IS NULL AND n.sport_variant_id IS NOT NULL THEN
      SELECT sv.required_players INTO v_capacity FROM public.sport_variants sv WHERE sv.id = n.sport_variant_id;
      n.capacity := v_capacity;
    END IF;
    -- trg_fn_games_require_challenge_sport
    IF NOT EXISTS (SELECT 1 FROM public.sports s
                    WHERE s.id = n.sport_id AND s.is_challenge_sport = true AND s.is_active = true) THEN
      RAISE EXCEPTION USING errcode = 'P0001', message = 'sport_not_challenge';
    END IF;
    -- trgfn_games_set_host_user
    SELECT user_id INTO v_uid FROM public.profiles WHERE id = n.creator_profile_id;
    IF v_uid IS NULL THEN
      RAISE EXCEPTION USING errcode = 'P0001', message = 'creator_profile_not_found';
    END IF;
    n.creator_user_id := v_uid;
    -- kan611_stamp_request_id
    v_req := nullif(current_setting('thebes.create_request_id', true), '');
    IF v_req IS NOT NULL AND n.request_id IS NULL THEN
      n.request_id := v_req::uuid;
    END IF;
    -- kan711_assign_event_id
    IF n.event_id IS NULL THEN
      n.event_id := n.id;
    END IF;
  END IF;

  -- (a) kan713_games_location
  v_space_changed := v_insert OR n.venue_space_id IS DISTINCT FROM o.venue_space_id;
  v_venue_changed := v_insert OR n.venue_id IS DISTINCT FROM o.venue_id;
  IF n.venue_space_id IS NOT NULL THEN
    SELECT true, vs.venue_id INTO v_space_found, v_space_venue
      FROM public.venue_spaces vs WHERE vs.id = n.venue_space_id;
    IF v_space_found IS NULL THEN
      IF v_space_changed THEN
        RAISE EXCEPTION USING ERRCODE = '23503', MESSAGE = 'kan713_space_not_found',
          DETAIL = format('games %s: venue_space_id %s does not exist', n.id, n.venue_space_id);
      END IF;
    ELSIF v_space_venue IS NOT NULL THEN
      IF n.venue_id IS NULL OR (v_space_changed AND NOT v_venue_changed) THEN
        n.venue_id := v_space_venue;
      ELSIF n.venue_id <> v_space_venue AND (v_space_changed OR v_venue_changed) THEN
        RAISE EXCEPTION USING ERRCODE = '23514', MESSAGE = 'kan713_space_venue_mismatch',
          DETAIL = format('games %s: venue %s is not the venue (%s) of space %s', n.id, n.venue_id, v_space_venue, n.venue_space_id);
      END IF;
    END IF;
  END IF;
  IF n.venue_space_id IS NOT NULL THEN
    SELECT v.geo_location_id, gl.area_id INTO v_geo_location_id, v_area_id
      FROM public.venue_spaces  vs
      JOIN public.venues        v  ON v.id  = vs.venue_id
      JOIN public.geo_locations gl ON gl.id = v.geo_location_id
     WHERE vs.id = n.venue_space_id;
  ELSIF n.venue_id IS NOT NULL THEN
    SELECT v.geo_location_id, gl.area_id INTO v_geo_location_id, v_area_id
      FROM public.venues        v
      JOIN public.geo_locations gl ON gl.id = v.geo_location_id
     WHERE v.id = n.venue_id;
  END IF;
  IF v_geo_location_id IS NOT NULL THEN
    n.geo_location_id := v_geo_location_id;
    n.area_id         := v_area_id;
  END IF;

  -- (b) kan713_games_joining
  IF n.venue_space_id IS NOT NULL THEN
    SELECT vs.joining_rule INTO v_joining_rule FROM public.venue_spaces vs WHERE vs.id = n.venue_space_id;
    n.joining_rule := COALESCE(v_joining_rule, 'free');
    IF v_insert THEN
      n.cost_cover := n.joining_rule;
    ELSIF o.joining_rule <> n.joining_rule THEN
      n.cost_cover := n.joining_rule;
    END IF;
  ELSE
    n.joining_rule := 'free';
    IF v_insert THEN n.cost_cover := 'free'; END IF;
  END IF;

  -- (c) kan713_games_venue_geo
  IF n.venue_space_id IS NOT NULL THEN
    SELECT v.id, v.geo_location_id, v.area_id INTO v_venue_id, v_geo_id, v_area_id
      FROM public.venue_spaces vs
      JOIN public.venues v ON v.id = vs.venue_id
     WHERE vs.id = n.venue_space_id;
    n.venue_id        := COALESCE(n.venue_id,        v_venue_id);
    n.geo_location_id := COALESCE(n.geo_location_id, v_geo_id);
    n.area_id         := COALESCE(n.area_id,         v_area_id);
  END IF;

  RETURN n;
END
$function$;

CREATE OR REPLACE FUNCTION public.kan718_game_event_sync(g public.games, p_insert boolean DEFAULT false)
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
DECLARE
  v_con text;
BEGIN
  IF g.id IS NULL THEN
    RETURN;
  END IF;
  IF p_insert AND NOT EXISTS (SELECT 1 FROM public.events e WHERE e.id = g.id) THEN
    BEGIN
      INSERT INTO public.events (id, event_type, creator_profile_id, creator_user_id, title, start_at, end_at,
             capacity, listing_visibility, join_policy, is_cancelled, cancelled_at, cancelled_reason, sport_id,
             area_id, geo_location_id, venue_id, min_skill, max_skill, joining_rule, cost_cover, request_id,
             created_at, updated_at)
      VALUES (g.id, 'game', g.creator_profile_id, g.creator_user_id, g.title, g.start_at, g.end_at,
             g.capacity, g.listing_visibility, g.join_policy, g.is_cancelled, g.cancelled_at, g.cancelled_reason,
             g.sport_id, g.area_id, g.geo_location_id, g.venue_id, g.min_skill::smallint, g.max_skill::smallint,
             g.joining_rule, g.cost_cover, g.request_id, g.created_at, g.updated_at);
    EXCEPTION WHEN unique_violation THEN
      GET STACKED DIAGNOSTICS v_con = CONSTRAINT_NAME;
      IF v_con = 'events_type_creator_request_id_key' THEN
        RAISE EXCEPTION USING ERRCODE = '23505',
          CONSTRAINT = 'games_creator_user_request_id_key',
          MESSAGE = 'duplicate key value violates unique constraint "games_creator_user_request_id_key"',
          DETAIL = format('kan712: events parent for request_id %s already exists', g.request_id);
      END IF;
      RAISE;
    END;
    RETURN;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.events e WHERE e.id = g.id AND e.event_type = 'game') THEN
    RAISE EXCEPTION USING ERRCODE = '23503', MESSAGE = 'kan712_missing_parent', DETAIL = format('games %s', g.id);
  END IF;

  PERFORM set_config('kan711.src_updated_at', g.updated_at::text, true);   -- the parent keeps the row's updated_at
  UPDATE public.events e SET
    creator_profile_id = g.creator_profile_id, creator_user_id = g.creator_user_id, title = g.title,
    start_at = g.start_at, end_at = g.end_at, capacity = g.capacity, listing_visibility = g.listing_visibility,
    join_policy = g.join_policy, is_cancelled = g.is_cancelled, cancelled_at = g.cancelled_at,
    cancelled_reason = g.cancelled_reason, sport_id = g.sport_id, area_id = g.area_id,
    geo_location_id = g.geo_location_id, venue_id = g.venue_id, min_skill = g.min_skill::smallint,
    max_skill = g.max_skill::smallint, joining_rule = g.joining_rule, cost_cover = g.cost_cover,
    request_id = g.request_id, created_at = g.created_at, updated_at = g.updated_at
  WHERE e.id = g.id
    AND ROW(e.creator_profile_id, e.creator_user_id, e.title, e.start_at, e.end_at, e.capacity,
            e.listing_visibility, e.join_policy, e.is_cancelled, e.cancelled_at, e.cancelled_reason,
            e.sport_id, e.area_id, e.geo_location_id, e.venue_id, e.min_skill, e.max_skill,
            e.joining_rule, e.cost_cover, e.request_id, e.created_at, e.updated_at)
        IS DISTINCT FROM
        ROW(g.creator_profile_id, g.creator_user_id, g.title, g.start_at, g.end_at, g.capacity,
            g.listing_visibility, g.join_policy, g.is_cancelled, g.cancelled_at, g.cancelled_reason,
            g.sport_id, g.area_id, g.geo_location_id, g.venue_id, g.min_skill::smallint, g.max_skill::smallint,
            g.joining_rule, g.cost_cover, g.request_id, g.created_at, g.updated_at);
  PERFORM set_config('kan711.src_updated_at', '', true);
END
$function$;

ALTER FUNCTION public.kan718_game_derive(public.games, public.games) OWNER TO postgres;
ALTER FUNCTION public.kan718_game_event_sync(public.games, boolean) OWNER TO postgres;
REVOKE ALL ON FUNCTION public.kan718_game_derive(public.games, public.games) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.kan718_game_event_sync(public.games, boolean) FROM PUBLIC, anon, authenticated, service_role;
