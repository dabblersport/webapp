-- KAN-947 P-c: the series writers write events first, with the P-a pattern
-- (20261114114127_kan947_pa_game_create_events_first.sql): shared fields on public.events, retained columns on
-- games (written first, so the mirror's copy of events.updated_at lands last), games kept in parity by
-- trg_zz_kan947_events_game_mirror until KAN-866.
--
-- Authored from the live pg_get_functiondef, 2026-11-14, project wtncuzcskpigqpmnxwws. Pre-image (functiondef md5):
--   fn_generate_game_series_occurrences_kan712_inner(uuid)                9e4dde309244a0d105170949654af096
--   rpc_edit_game_series_occurrence_kan712_inner(uuid,text,tstz,tstz,int,uuid) d562a825042703f17fa426d5e981c5ff
--   rpc_edit_game_series_future_kan712_inner(uuid,text,int,time,int,uuid,date,bool) 6b66b6206a30497b382c822dffe10c53
-- CREATE OR REPLACE keeps owner, ACL, SECURITY, volatility and search_path; all are re-asserted below.
--
-- 1. generator: each occurrence is created by rpc_create_game (events-first since P-a); the series link is a
--    retained column (UPDATE games SET series_id). The kan718_game_event_sync that followed it is gone: games and
--    events are already equal (the games touch sets updated_at to now(), which is the events value in the same
--    transaction). The series occurrence guard on games (series_id) checks the parent's start_at, as before.
-- 2. occurrence edit: same checks and errors in the same order; games gets venue_space_id, events gets title,
--    start_at, end_at, capacity and the derived location facts (kan947_game_derive(old events, new space, -, old
--    events, old space)). unique_violation (kan718_series_occurrence_unique from the events trigger, or the games
--    series index on the mirrored row) is still reported as occurrence_time_taken.
-- 3. future edit: per kept row, games gets venue_space_id = the series space and events the series title,
--    capacity, start/end and location facts. Cancels still go through rpc_cancel_game; the top-up still calls
--    fn_generate_game_series_occurrences.
-- Test: supabase/tests/events_p4/kan947_pc_game_series_live_test.sql.

do $pre$
declare
  k record;
begin
  for k in select * from (values
    ('public.fn_generate_game_series_occurrences_kan712_inner(uuid)', '9e4dde309244a0d105170949654af096'),
    ('public.rpc_edit_game_series_occurrence_kan712_inner(uuid,text,timestamp with time zone,timestamp with time zone,integer,uuid)', 'd562a825042703f17fa426d5e981c5ff'),
    ('public.rpc_edit_game_series_future_kan712_inner(uuid,text,integer,time without time zone,integer,uuid,date,boolean)', '6b66b6206a30497b382c822dffe10c53')) v(fn, pre)
  loop
    if md5(pg_get_functiondef(to_regprocedure(k.fn))) is distinct from k.pre then
      raise exception 'KAN-947 P-c pre: % absent or drifted', k.fn;
    end if;
  end loop;
  if to_regprocedure('public.kan947_game_derive(public.events,uuid,uuid,public.events,uuid)') is null
     or not exists (select 1 from pg_trigger where tgrelid = 'public.events'::regclass and tgname = 'trg_zz_kan947_events_game_mirror' and tgenabled = 'O') then
    raise exception 'KAN-947 P-c pre: P-a is not applied';
  end if;
end
$pre$;

CREATE OR REPLACE FUNCTION public.fn_generate_game_series_occurrences_kan712_inner(p_series_id uuid DEFAULT NULL::uuid)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  s record; v_persona text; v_step int; v_n int; v_day date; v_start timestamptz; v_end timestamptz;
  v_future int; v_created int := 0; v_prev_sub text; v_gid uuid;
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
      -- KAN-947: the series link is a games-only column; rpc_create_game already wrote the events parent.
      UPDATE public.games SET series_id = s.id WHERE id = v_gid;
      v_future := v_future + 1;
      v_created := v_created + 1;
    END LOOP;
  END LOOP;
  RETURN v_created;
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
  v_o public.events; v_d public.events; v_space uuid; v_old_space uuid; v_variant uuid;
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
    -- KAN-947: games first (venue_space_id, retained), then the events parent (title, time, capacity, location
    -- facts from the KAN-718 derive on the events row). series_id deliberately not in either SET list (T-099).
    SELECT g0.venue_space_id, g0.sport_variant_id INTO v_old_space, v_variant FROM public.games g0 WHERE g0.id = g.id;
    SELECT * INTO v_o FROM public.events e WHERE e.id = g.id AND e.event_type = 'game' FOR UPDATE;
    v_space := COALESCE(p_venue_space_id, v_old_space);
    v_d := public.kan947_game_derive(v_o, v_space, v_variant, v_o, v_old_space);
    UPDATE public.games g1 SET venue_space_id = v_space WHERE g1.id = g.id;
    UPDATE public.events e
       SET title = COALESCE(p_title, e.title), start_at = v_start, end_at = v_end,
           capacity = COALESCE(p_capacity, e.capacity),
           venue_id = v_d.venue_id, geo_location_id = v_d.geo_location_id, area_id = v_d.area_id,
           joining_rule = v_d.joining_rule, cost_cover = v_d.cost_cover,
           updated_at = now()
     WHERE e.id = v_o.id;
  EXCEPTION WHEN unique_violation THEN
    RAISE EXCEPTION USING errcode = 'P0001', message = 'occurrence_time_taken';
  END;

  RETURN jsonb_build_object('game_id', g.id, 'series_id', g.series_id);
END;
$function$;

CREATE OR REPLACE FUNCTION public.rpc_edit_game_series_future_kan712_inner(p_series_id uuid, p_title text DEFAULT NULL::text, p_capacity integer DEFAULT NULL::integer, p_start_time_local time without time zone DEFAULT NULL::time without time zone, p_duration_minutes integer DEFAULT NULL::integer, p_venue_space_id uuid DEFAULT NULL::uuid, p_ends_on date DEFAULT NULL::date, p_clear_ends_on boolean DEFAULT false)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_uid uuid; s public.game_series%ROWTYPE; g record; v_updated int := 0; v_cancelled int := 0;
  v_kept uuid[] := '{}'; v_time_changed boolean; v_topup int := 0; v_start timestamptz;
  v_o public.events; v_d public.events; v_old_space uuid; v_variant uuid;
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
      -- KAN-947: games first (venue_space_id), then the events parent (title, capacity, time, location facts
      -- from the KAN-718 derive on the events row with the series space).
      SELECT g0.venue_space_id, g0.sport_variant_id INTO v_old_space, v_variant FROM public.games g0 WHERE g0.id = g.id;
      SELECT * INTO v_o FROM public.events e WHERE e.id = g.id AND e.event_type = 'game' FOR UPDATE;
      v_d := public.kan947_game_derive(v_o, s.venue_space_id, v_variant, v_o, v_old_space);
      UPDATE public.games gg SET venue_space_id = s.venue_space_id WHERE gg.id = g.id;
      UPDATE public.events e
         SET title = s.title, capacity = s.capacity,
             venue_id = v_d.venue_id, geo_location_id = v_d.geo_location_id, area_id = v_d.area_id,
             joining_rule = v_d.joining_rule, cost_cover = v_d.cost_cover,
             start_at = v_start, end_at = v_start + make_interval(mins => s.duration_minutes), updated_at = now()
       WHERE e.id = v_o.id;
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

do $post$
declare
  r record;
  n int := 0;
begin
  for r in
    select p.oid::regprocedure::text fn, p.proacl::text acl, p.prosecdef, p.provolatile::text vol,
           array_to_string(p.proconfig, ',') cfg, pg_get_userbyid(p.proowner) own, p.prosrc
      from pg_proc p
     where p.oid in ('public.fn_generate_game_series_occurrences_kan712_inner(uuid)'::regprocedure,
                     'public.rpc_edit_game_series_occurrence_kan712_inner(uuid,text,timestamp with time zone,timestamp with time zone,integer,uuid)'::regprocedure,
                     'public.rpc_edit_game_series_future_kan712_inner(uuid,text,integer,time without time zone,integer,uuid,date,boolean)'::regprocedure)
  loop
    n := n + 1;
    if r.acl <> '{postgres=X/postgres}' or r.prosecdef is not true or r.vol <> 'v'
       or r.cfg <> 'search_path=public, pg_temp' or r.own <> 'postgres' then
      raise exception 'KAN-947 P-c post: % attributes drifted: %', r.fn, r;
    end if;
    if r.prosrc ~ 'kan718_game_event_sync|kan718_game_derive' then
      raise exception 'KAN-947 P-c post: % still calls a games-typed helper', r.fn;
    end if;
  end loop;
  if n <> 3 then raise exception 'KAN-947 P-c post: % of 3 functions found', n; end if;
end
$post$;
