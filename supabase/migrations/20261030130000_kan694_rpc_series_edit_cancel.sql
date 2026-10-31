-- KAN-694 (B3): edit one occurrence, edit all future occurrences, and cancel a series.
--
-- STATUS: AUTHORED, NOT APPLIED. Memphis applies it AFTER, in this order (execute_sql only, never apply_migration):
--   1. 20261027120000_kan671_game_series.sql   (KAN-671; exists only on branch alpha-671-habu, cherry-pick with NO edits)
--   2. 20261030120000_kan693_rpc_create_game_series.sql
--   3. this file
-- Project wtncuzcskpigqpmnxwws only. Additive: three new functions, no DROP, no existing object altered, no games row deleted.
--
-- Decisions (T-099, epic KAN-692 v1):
--   * "This game" changes one games row and leaves games.series_id as is.
--   * "All future" updates the game_series template and applies it, IN PLACE, only to future non-cancelled occurrences that
--     have no joined players. Occurrences with joined players are never rewritten; they are returned in the result.
--   * Cancelling a series sets status = 'ended', cancels every future non-cancelled occurrence through the existing
--     public.rpc_cancel_game (so trg_game_updated_notify reaches every joined player), and leaves past rows untouched.
--   * Paid games stay blocked in a series (v1); nothing here touches price.
-- "Joined player" = a game_roster row for the game whose user_id is not the game's creator (the same set
-- trg_game_updated_notify notifies). Host = effective_actor_uid() = game_series.creator_user_id / games.creator_user_id;
-- no caller-supplied identity. A non-host and an unknown id both get 'not_host_or_not_found' (no existence leak).

DO $pre$
BEGIN
  IF to_regclass('public.game_series') IS NULL THEN
    RAISE EXCEPTION 'KAN694 pre-check: public.game_series missing; apply KAN-671 then KAN-693 first';
  END IF;
  IF to_regprocedure('public.fn_generate_game_series_occurrences(uuid)') IS NULL THEN
    RAISE EXCEPTION 'KAN694 pre-check: fn_generate_game_series_occurrences missing; apply KAN-693 first';
  END IF;
  IF to_regprocedure('public.rpc_cancel_game(uuid,text)') IS NULL THEN
    RAISE EXCEPTION 'KAN694 pre-check: rpc_cancel_game missing';
  END IF;
END
$pre$;

-- 1. Edit THIS occurrence only. NULL argument = leave that field unchanged. series_id is never written.
CREATE OR REPLACE FUNCTION public.rpc_edit_game_series_occurrence(
  p_game_id uuid, p_title text DEFAULT NULL, p_start_at timestamptz DEFAULT NULL, p_end_at timestamptz DEFAULT NULL,
  p_capacity integer DEFAULT NULL, p_venue_space_id uuid DEFAULT NULL)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_uid uuid; g public.games%ROWTYPE; v_players int; v_start timestamptz; v_end timestamptz;
BEGIN
  v_uid := public.effective_actor_uid();
  IF v_uid IS NULL THEN RAISE EXCEPTION USING errcode = 'P0001', message = 'not_authenticated'; END IF;

  SELECT * INTO g FROM public.games WHERE id = p_game_id AND series_id IS NOT NULL AND creator_user_id = v_uid FOR UPDATE;
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
    UPDATE public.games
       SET title = COALESCE(p_title, title), start_at = v_start, end_at = v_end,
           capacity = COALESCE(p_capacity, capacity), venue_space_id = COALESCE(p_venue_space_id, venue_space_id),
           updated_at = now()
     WHERE id = g.id;   -- series_id deliberately not in the SET list (T-099)
  EXCEPTION WHEN unique_violation THEN
    RAISE EXCEPTION USING errcode = 'P0001', message = 'occurrence_time_taken';
  END;

  RETURN jsonb_build_object('game_id', g.id, 'series_id', g.series_id);
END;
$function$;

-- 2. Edit ALL FUTURE occurrences: update the template, then apply it in place to future, non-cancelled, unjoined rows.
-- p_ends_on NULL = unchanged; p_clear_ends_on = true sets it to NULL (runs until ended). Unjoined future rows that now fall
-- after ends_on are cancelled through rpc_cancel_game (no player, so nobody is notified). Joined rows are listed, not changed.
CREATE OR REPLACE FUNCTION public.rpc_edit_game_series_future(
  p_series_id uuid, p_title text DEFAULT NULL, p_capacity integer DEFAULT NULL, p_start_time_local time DEFAULT NULL,
  p_duration_minutes integer DEFAULT NULL, p_venue_space_id uuid DEFAULT NULL, p_ends_on date DEFAULT NULL,
  p_clear_ends_on boolean DEFAULT false)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_uid uuid; s public.game_series%ROWTYPE; g record; v_updated int := 0; v_cancelled int := 0;
  v_kept uuid[] := '{}'; v_time_changed boolean; v_topup int := 0; v_start timestamptz;
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
    SELECT id, start_at,
           EXISTS (SELECT 1 FROM public.game_roster r WHERE r.game_id = games.id AND r.user_id <> games.creator_user_id) AS has_players
      FROM public.games
     WHERE series_id = s.id AND start_at > now() AND NOT COALESCE(is_cancelled, false)
     ORDER BY start_at
       FOR UPDATE
  LOOP
    IF g.has_players THEN
      v_kept := v_kept || g.id;   -- never rewritten silently; returned to the client
    ELSIF s.ends_on IS NOT NULL AND (g.start_at AT TIME ZONE s.timezone)::date > s.ends_on THEN
      PERFORM public.rpc_cancel_game(g.id, 'series_ended_earlier');
      v_cancelled := v_cancelled + 1;
    ELSE
      v_start := ((g.start_at AT TIME ZONE s.timezone)::date + s.start_time_local) AT TIME ZONE s.timezone;
      UPDATE public.games
         SET title = s.title, capacity = s.capacity, venue_space_id = s.venue_space_id,
             start_at = v_start, end_at = v_start + make_interval(mins => s.duration_minutes), updated_at = now()
       WHERE id = g.id;
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

-- 3. Cancel the whole series. status -> 'ended' FIRST (so the generator stops), then each future non-cancelled
-- occurrence goes through rpc_cancel_game, whose AFTER UPDATE trigger notifies every joined player. Past rows untouched.
CREATE OR REPLACE FUNCTION public.rpc_cancel_game_series(p_series_id uuid, p_reason text DEFAULT NULL)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_uid uuid; s public.game_series%ROWTYPE; g record; v_cancelled int := 0; v_players int := 0; v_past int;
BEGIN
  v_uid := public.effective_actor_uid();
  IF v_uid IS NULL THEN RAISE EXCEPTION USING errcode = 'P0001', message = 'not_authenticated'; END IF;

  SELECT * INTO s FROM public.game_series WHERE id = p_series_id AND creator_user_id = v_uid FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION USING errcode = 'P0001', message = 'not_host_or_not_found'; END IF;

  UPDATE public.game_series SET status = 'ended', updated_at = now() WHERE id = s.id;

  FOR g IN
    SELECT id, (SELECT count(DISTINCT r.user_id) FROM public.game_roster r
                 WHERE r.game_id = games.id AND r.user_id <> games.creator_user_id) AS players
      FROM public.games
     WHERE series_id = s.id AND start_at > now() AND NOT COALESCE(is_cancelled, false)
     ORDER BY start_at
       FOR UPDATE
  LOOP
    PERFORM public.rpc_cancel_game(g.id, COALESCE(p_reason, 'series_cancelled'));
    v_cancelled := v_cancelled + 1;
    v_players := v_players + g.players;
  END LOOP;

  SELECT count(*) INTO v_past FROM public.games WHERE series_id = s.id AND start_at <= now();

  RETURN jsonb_build_object('series_id', s.id, 'status', 'ended', 'cancelled', v_cancelled,
                            'player_notifications', v_players, 'past_kept', v_past);
END;
$function$;

ALTER FUNCTION public.rpc_edit_game_series_occurrence(uuid,text,timestamptz,timestamptz,integer,uuid) OWNER TO postgres;
ALTER FUNCTION public.rpc_edit_game_series_future(uuid,text,integer,time,integer,uuid,date,boolean) OWNER TO postgres;
ALTER FUNCTION public.rpc_cancel_game_series(uuid,text) OWNER TO postgres;
REVOKE ALL ON FUNCTION public.rpc_edit_game_series_occurrence(uuid,text,timestamptz,timestamptz,integer,uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.rpc_edit_game_series_future(uuid,text,integer,time,integer,uuid,date,boolean) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.rpc_cancel_game_series(uuid,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rpc_edit_game_series_occurrence(uuid,text,timestamptz,timestamptz,integer,uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.rpc_edit_game_series_future(uuid,text,integer,time,integer,uuid,date,boolean) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.rpc_cancel_game_series(uuid,text) TO authenticated, service_role;

DO $post$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_proc p, aclexplode(COALESCE(p.proacl, acldefault('f', p.proowner))) a
              WHERE p.proname IN ('rpc_edit_game_series_occurrence', 'rpc_edit_game_series_future', 'rpc_cancel_game_series')
                AND p.pronamespace = 'public'::regnamespace
                AND (a.grantee = 0 OR a.grantee = 'anon'::regrole)) THEN
    RAISE EXCEPTION 'KAN694 post-check: a series edit/cancel function is executable by PUBLIC or anon';
  END IF;
END
$post$;
