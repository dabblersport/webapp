-- KAN-717 F5b: a series created as organiser yields hosted occurrences, the same as a single
-- rpc_create_game('organiser', ...) call. rpc_create_game_series now stores game_series.game_type
-- ('hosted' for organiser, else 'casual', the column default every existing row already has), and the
-- generator passes actor 'organiser' for a hosted series. Bodies authored from pg_get_functiondef on the
-- live catalogue; attributes and ACL unchanged (CREATE OR REPLACE keeps proacl).
DO $pin$
BEGIN
  IF (SELECT md5(prosrc) FROM pg_proc WHERE oid = 'public.rpc_create_game_series(text,uuid,uuid,uuid,uuid,date,time without time zone,integer,text,text,integer,text,uuid,date,text,text,integer,numeric)'::regprocedure)
     IS DISTINCT FROM '7027ec32f46775670ab9b9499d4d6dcf' THEN
    RAISE EXCEPTION 'kan717_f5b: rpc_create_game_series drifted from the pinned body';
  END IF;
  IF (SELECT md5(prosrc) FROM pg_proc WHERE oid = 'public.fn_generate_game_series_occurrences_kan712_inner(uuid)'::regprocedure)
     IS DISTINCT FROM '6139fd5519f32580ab14b7a4caa487ad' THEN
    RAISE EXCEPTION 'kan717_f5b: fn_generate_game_series_occurrences_kan712_inner drifted from the pinned body';
  END IF;
END $pin$;

CREATE OR REPLACE FUNCTION public.rpc_create_game_series(p_actor_type text, p_sport_id uuid, p_sport_variant_id uuid, p_geo_location_id uuid, p_area_id uuid, p_starts_on date, p_start_time_local time without time zone, p_duration_minutes integer, p_timezone text, p_frequency text, p_capacity integer, p_title text DEFAULT NULL::text, p_venue_space_id uuid DEFAULT NULL::uuid, p_ends_on date DEFAULT NULL::date, p_listing_visibility text DEFAULT 'public'::text, p_join_policy text DEFAULT 'open'::text, p_occurrences_ahead integer DEFAULT 4, p_price_aed numeric DEFAULT 0)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_uid uuid; v_pid uuid; v_sid uuid; v_rrule text;
BEGIN
  v_uid := public.effective_actor_uid();
  IF v_uid IS NULL THEN RAISE EXCEPTION USING errcode = 'P0001', message = 'not_authenticated'; END IF;
  v_pid := public.choose_actor(p_actor_type);   -- raises no_profile_of_requested_type
  IF COALESCE(p_price_aed, 0) <> 0 THEN
    RAISE EXCEPTION USING errcode = 'P0001', message = 'series_paid_not_supported';
  END IF;
  v_rrule := CASE p_frequency WHEN 'weekly' THEN 'FREQ=WEEKLY' WHEN 'biweekly' THEN 'FREQ=WEEKLY;INTERVAL=2'
             ELSE NULL END;
  IF v_rrule IS NULL THEN RAISE EXCEPTION USING errcode = 'P0001', message = 'series_frequency_invalid'; END IF;
  IF p_starts_on IS NULL OR p_start_time_local IS NULL OR p_duration_minutes IS NULL OR p_timezone IS NULL THEN
    RAISE EXCEPTION USING errcode = 'P0001', message = 'series_schedule_required';
  END IF;

  -- KAN-717 F5b: keep the actor the creator chose; rpc_create_game maps organiser -> hosted, else casual.
  INSERT INTO public.game_series (creator_user_id, creator_profile_id, sport_id, sport_variant_id, venue_space_id,
         geo_location_id, area_id, title, capacity, listing_visibility, join_policy, start_time_local,
         duration_minutes, rrule, timezone, starts_on, ends_on, occurrences_ahead, game_type)
  VALUES (v_uid, v_pid, p_sport_id, p_sport_variant_id, p_venue_space_id, p_geo_location_id, p_area_id, p_title,
          p_capacity, p_listing_visibility, p_join_policy, p_start_time_local, p_duration_minutes, v_rrule,
          p_timezone, p_starts_on, p_ends_on, p_occurrences_ahead,
          CASE WHEN p_actor_type = 'organiser' THEN 'hosted' ELSE 'casual' END)
  RETURNING id INTO v_sid;

  PERFORM public.fn_generate_game_series_occurrences(v_sid);
  RETURN v_sid;
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
    -- KAN-717 F5: rpc_create_game takes an actor type, not a persona. A KAN-646 contributor acts as player
    -- (player row) or else organiser (organiser row); passing 'contributor' failed the KAN-440 gate.
    -- KAN-717 F5b: a hosted series (created as organiser) acts as organiser, so its occurrences are hosted.
    IF s.game_type = 'hosted' THEN
      v_persona := 'organiser';
    ELSIF v_persona = 'contributor' THEN
      v_persona := CASE
        WHEN EXISTS (SELECT 1 FROM public.player x WHERE x.profile_id = s.creator_profile_id) THEN 'player'
        WHEN EXISTS (SELECT 1 FROM public.organiser x WHERE x.profile_id = s.creator_profile_id) THEN 'organiser'
        ELSE v_persona END;
    END IF;
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

DO $post$
BEGIN
  IF (SELECT p.proacl::text || '|' || p.prosecdef || '|' || array_to_string(p.proconfig, ',') || '|' || pg_get_userbyid(p.proowner)
        FROM pg_proc p WHERE p.oid = 'public.rpc_create_game_series(text,uuid,uuid,uuid,uuid,date,time without time zone,integer,text,text,integer,text,uuid,date,text,text,integer,numeric)'::regprocedure)
     IS DISTINCT FROM '{postgres=X/postgres,authenticated=X/postgres,service_role=X/postgres}|true|search_path=public, pg_temp|postgres' THEN
    RAISE EXCEPTION 'kan717_f5b: rpc_create_game_series attributes/ACL changed';
  END IF;
  IF (SELECT p.proacl::text || '|' || p.prosecdef || '|' || array_to_string(p.proconfig, ',') || '|' || pg_get_userbyid(p.proowner)
        FROM pg_proc p WHERE p.oid = 'public.fn_generate_game_series_occurrences_kan712_inner(uuid)'::regprocedure)
     IS DISTINCT FROM '{postgres=X/postgres}|true|search_path=public, pg_temp|postgres' THEN
    RAISE EXCEPTION 'kan717_f5b: inner generator attributes/ACL changed';
  END IF;
END $post$;
