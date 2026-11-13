-- KAN-718 (Epic KAN-708, phase 2): the series writers write the events parent themselves.
-- Authored from the live pg_get_functiondef (2026-11-13). Signatures, return shapes, SECURITY DEFINER,
-- search_path, owner and ACL unchanged (CREATE OR REPLACE keeps owner and ACL).
--   * rpc_edit_game_series_future_kan712_inner: the per-game UPDATE gains an alias (gg, because g is the
--     loop record), the kan718_game_derive location columns (venue_space_id is in its SET list),
--     RETURNING gg.* INTO v_g and a kan718_game_event_sync.
--   * rpc_edit_game_series_occurrence_kan712_inner: the same, inside the existing unique_violation block
--     so a clash raised by the parent write still reads occurrence_time_taken.
--   * fn_generate_game_series_occurrences_kan712_inner: the series_id UPDATE (which moves updated_at)
--     gains RETURNING * INTO v_g and a kan718_game_event_sync. The create itself goes through
--     rpc_create_game -> rpc_create_game_legacy_v1/v2, converted in 20261113100100.

CREATE OR REPLACE FUNCTION public.rpc_edit_game_series_future_kan712_inner(p_series_id uuid, p_title text DEFAULT NULL::text, p_capacity integer DEFAULT NULL::integer, p_start_time_local time without time zone DEFAULT NULL::time without time zone, p_duration_minutes integer DEFAULT NULL::integer, p_venue_space_id uuid DEFAULT NULL::uuid, p_ends_on date DEFAULT NULL::date, p_clear_ends_on boolean DEFAULT false)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_uid uuid; s public.game_series%ROWTYPE; g record; v_updated int := 0; v_cancelled int := 0;
  v_kept uuid[] := '{}'; v_time_changed boolean; v_topup int := 0; v_start timestamptz;
  v_g public.games;
BEGIN
  v_uid := public.effective_actor_uid();
  IF v_uid IS NULL THEN RAISE EXCEPTION USING errcode = 'P0001', message = 'not_authenticated'; END IF;

  SELECT * INTO s FROM public.game_series WHERE id = p_series_id AND creator_user_id = v_uid FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION USING errcode = 'P0001', message = 'not_host_or_not_found'; END IF;
  IF s.status <> 'active' THEN RAISE EXCEPTION USING errcode = 'P0001', message = 'series_not_active'; END IF;
  IF p_capacity IS NOT NULL AND (p_capacity < 2 OR p_capacity > 64) THEN
    RAISE EXCEPTION USING errcode = 'P0001', message = 'series_capacity_invalid';
  END IF;
  IF p_duration_minutes IS NOT NULL AND (p_duration_minutes <= 0 OR p_duration_minutes > 1440) THEN
    RAISE EXCEPTION USING errcode = 'P0001', message = 'series_schedule_invalid';
  END IF;
  IF p_ends_on IS NOT NULL AND p_ends_on < s.starts_on THEN
    RAISE EXCEPTION USING errcode = 'P0001', message = 'series_schedule_invalid';
  END IF;

  v_time_changed := (p_start_time_local IS NOT NULL AND p_start_time_local <> s.start_time_local)
                 OR (p_duration_minutes IS NOT NULL AND p_duration_minutes <> s.duration_minutes);

  UPDATE public.game_series
     SET title = COALESCE(p_title, title), capacity = COALESCE(p_capacity, capacity),
         start_time_local = COALESCE(p_start_time_local, start_time_local),
         duration_minutes = COALESCE(p_duration_minutes, duration_minutes),
         venue_space_id = COALESCE(p_venue_space_id, venue_space_id),
         ends_on = CASE WHEN p_clear_ends_on THEN NULL ELSE COALESCE(p_ends_on, ends_on) END,
         updated_at = now()
   WHERE id = s.id
   RETURNING * INTO s;

  FOR g IN
    -- KAN-733: start, cancel state and host come from the events parent; the games rows are still locked.
    SELECT games.id, e.start_at,
           EXISTS (SELECT 1 FROM public.game_roster r WHERE r.game_id = games.id AND r.user_id <> e.creator_user_id) AS has_players
      FROM public.games
      JOIN public.events e ON e.id = games.event_id AND e.event_type = 'game'
     WHERE games.series_id = s.id AND e.start_at > now() AND NOT COALESCE(e.is_cancelled, false)
     ORDER BY e.start_at
       FOR UPDATE OF games
  LOOP
    IF g.has_players THEN
      v_kept := v_kept || g.id;   -- never rewritten silently; returned to the client
    ELSIF s.ends_on IS NOT NULL AND (g.start_at AT TIME ZONE s.timezone)::date > s.ends_on THEN
      PERFORM public.rpc_cancel_game(g.id, 'series_ended_earlier');
      v_cancelled := v_cancelled + 1;
    ELSE
      v_start := ((g.start_at AT TIME ZONE s.timezone)::date + s.start_time_local) AT TIME ZONE s.timezone;
      -- KAN-718: location facts derived from the series space (kan718_game_derive); the parent is written here.
      UPDATE public.games gg
         SET title = s.title, capacity = s.capacity, venue_space_id = s.venue_space_id,
             (venue_id, geo_location_id, area_id, joining_rule, cost_cover)
               = (SELECT d.venue_id, d.geo_location_id, d.area_id, d.joining_rule, d.cost_cover
                    FROM public.kan718_game_derive(
                           jsonb_populate_record(gg, jsonb_build_object('venue_space_id', s.venue_space_id)), gg) d),
             start_at = v_start, end_at = v_start + make_interval(mins => s.duration_minutes), updated_at = now()
       WHERE gg.id = g.id
      RETURNING gg.* INTO v_g;
      PERFORM public.kan718_game_event_sync(v_g);
      v_updated := v_updated + 1;
    END IF;
  END LOOP;

  -- Top up the rolling window. Skipped when the time of day changed and a joined row kept its old time, because the
  -- generator matches existing rows by exact start_at and would add a second game on that day.
  IF NOT (v_time_changed AND cardinality(v_kept) > 0) THEN
    v_topup := public.fn_generate_game_series_occurrences(s.id);
  END IF;

  RETURN jsonb_build_object(
    'series_id', s.id, 'updated', v_updated, 'cancelled_after_end_date', v_cancelled, 'created', v_topup,
    'topup_skipped', (v_time_changed AND cardinality(v_kept) > 0),
    'kept_with_players', to_jsonb(v_kept));
END;
$function$;

CREATE OR REPLACE FUNCTION public.rpc_edit_game_series_occurrence_kan712_inner(p_game_id uuid, p_title text DEFAULT NULL::text, p_start_at timestamp with time zone DEFAULT NULL::timestamp with time zone, p_end_at timestamp with time zone DEFAULT NULL::timestamp with time zone, p_capacity integer DEFAULT NULL::integer, p_venue_space_id uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_uid uuid; g record; v_players int; v_start timestamptz; v_end timestamptz;
  v_g public.games;
BEGIN
  v_uid := public.effective_actor_uid();
  IF v_uid IS NULL THEN RAISE EXCEPTION USING errcode = 'P0001', message = 'not_authenticated'; END IF;

  -- KAN-733: owner, cancel state, start and end come from the events parent; the games row is still locked.
  SELECT g0.id, g0.series_id, e.is_cancelled, e.start_at, e.end_at INTO g
    FROM public.games g0
    JOIN public.events e ON e.id = g0.event_id AND e.event_type = 'game'
   WHERE g0.id = p_game_id AND g0.series_id IS NOT NULL AND e.creator_user_id = v_uid
     FOR UPDATE OF g0;
  IF NOT FOUND THEN RAISE EXCEPTION USING errcode = 'P0001', message = 'not_host_or_not_found'; END IF;
  IF g.is_cancelled OR g.start_at <= now() THEN
    RAISE EXCEPTION USING errcode = 'P0001', message = 'occurrence_not_editable';
  END IF;

  v_start := COALESCE(p_start_at, g.start_at);
  v_end := COALESCE(p_end_at, v_start + (g.end_at - g.start_at));
  IF v_start <= now() OR v_end <= v_start THEN
    RAISE EXCEPTION USING errcode = 'P0001', message = 'occurrence_time_invalid';
  END IF;
  IF p_capacity IS NOT NULL THEN
    SELECT count(*) INTO v_players FROM public.game_roster r
     WHERE r.game_id = g.id AND r.status = 'active' AND r.role IN ('player', 'sub');
    IF p_capacity < 2 OR p_capacity > 64 OR p_capacity < v_players THEN
      RAISE EXCEPTION USING errcode = 'P0001', message = 'occurrence_capacity_invalid';
    END IF;
  END IF;

  BEGIN
    -- KAN-917: the title / capacity fallbacks read the events parent e (authoritative); SET targets unchanged.
    -- KAN-718: location facts derived from the new space (kan718_game_derive); the parent is written here.
    UPDATE public.games g1
       SET title = COALESCE(p_title, e.title), start_at = v_start, end_at = v_end,
           capacity = COALESCE(p_capacity, e.capacity), venue_space_id = COALESCE(p_venue_space_id, venue_space_id),
           (venue_id, geo_location_id, area_id, joining_rule, cost_cover)
             = (SELECT d.venue_id, d.geo_location_id, d.area_id, d.joining_rule, d.cost_cover
                  FROM public.kan718_game_derive(
                         jsonb_populate_record(g1, jsonb_build_object('venue_space_id',
                           COALESCE(p_venue_space_id, g1.venue_space_id))), g1) d),
           updated_at = now()
      FROM public.events e
     WHERE e.id = g1.event_id AND e.event_type = 'game'
       AND g1.id = g.id   -- series_id deliberately not in the SET list (T-099)
    RETURNING g1.* INTO v_g;
    PERFORM public.kan718_game_event_sync(v_g);
  EXCEPTION WHEN unique_violation THEN
    RAISE EXCEPTION USING errcode = 'P0001', message = 'occurrence_time_taken';
  END;

  RETURN jsonb_build_object('game_id', g.id, 'series_id', g.series_id);
END;
$function$;

CREATE OR REPLACE FUNCTION public.fn_generate_game_series_occurrences_kan712_inner(p_series_id uuid DEFAULT NULL::uuid)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  s record; v_persona text; v_step int; v_n int; v_day date; v_start timestamptz; v_end timestamptz;
  v_future int; v_created int := 0; v_prev_sub text; v_gid uuid;
  v_g public.games;
BEGIN
  FOR s IN
    SELECT * FROM public.game_series
     WHERE status = 'active' AND (p_series_id IS NULL OR id = p_series_id)
     ORDER BY id
       FOR UPDATE   -- serialises two generators on the same series
  LOOP
    SELECT persona_type INTO v_persona FROM public.profiles WHERE id = s.creator_profile_id;
    v_step := CASE WHEN s.rrule LIKE '%INTERVAL=2%' THEN 14 ELSE 7 END;

    SELECT count(*) INTO v_future FROM public.kan714_games_read g
     WHERE g.series_id = s.id AND g.start_at > now() AND NOT COALESCE(g.is_cancelled, false);

    v_n := 0;
    WHILE v_n < 52 AND v_future < s.occurrences_ahead LOOP   -- 52 = hard cap on occurrence slots per series
      v_day := s.starts_on + (v_n * v_step);
      EXIT WHEN s.ends_on IS NOT NULL AND v_day > s.ends_on;
      v_n := v_n + 1;   -- the slot is consumed even when its date is already held (counts once toward the cap)
      v_start := (v_day + s.start_time_local) AT TIME ZONE s.timezone;
      v_end := v_start + make_interval(mins => s.duration_minutes);
      CONTINUE WHEN v_start <= now();
      -- A kept row on this local date (any time) already counts in v_future; do not add a second one.
      CONTINUE WHEN EXISTS (SELECT 1 FROM public.kan714_games_read g
                             WHERE g.series_id = s.id AND NOT COALESCE(g.is_cancelled, false)
                               AND (g.start_at AT TIME ZONE s.timezone)::date = v_day);
      -- Cancelled rows keep their (series_id, start_at) slot in the unique index; never re-create them.
      CONTINUE WHEN EXISTS (SELECT 1 FROM public.kan714_games_read g WHERE g.series_id = s.id AND g.start_at = v_start);

      v_prev_sub := current_setting('request.jwt.claim.sub', true);
      PERFORM set_config('request.jwt.claim.sub', s.creator_user_id::text, true);
      v_gid := public.rpc_create_game(
        v_persona, s.sport_id, s.sport_variant_id, s.title, s.venue_space_id, v_start, v_end, 0,
        s.listing_visibility, s.join_policy, NULL, NULL, NULL, NULL, false, false, NULL, NULL,
        s.geo_location_id, s.area_id, NULL, NULL, NULL, s.capacity, 0::numeric, NULL);
      PERFORM set_config('request.jwt.claim.sub', COALESCE(v_prev_sub, ''), true);
      UPDATE public.games SET series_id = s.id WHERE id = v_gid
      RETURNING * INTO v_g;
      PERFORM public.kan718_game_event_sync(v_g);   -- KAN-718: the parent follows the row (updated_at)
      v_future := v_future + 1;
      v_created := v_created + 1;
    END LOOP;
  END LOOP;
  RETURN v_created;
END;
$function$;
