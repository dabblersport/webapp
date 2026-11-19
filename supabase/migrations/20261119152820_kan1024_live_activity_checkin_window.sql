-- KAN-1024: the Live Activity keeps its "Check in" action until check-in closes (start + 15 min) and drops it then.
--
-- PAYLOAD CONTRACT addendum (to 20261118140810_kan1004b_live_activity_fixes.sql, content-state):
--   checkin_closes_at  int      Unix seconds: when self check-in closes (attendance start_at + 15 min, the same
--                               window rpc_attendance_my returns as closes_at and rpc_attendance_check_in enforces)
--   checkin_open       bool     true while this user can still check in (kan1008_check_in_state = 'open');
--                               false once checked in, before the window, after it closes, or when not eligible
--   Show the "Check in" action iff checkin_open = true. It is not tied to `state`: state may already be
--   scheduled_time_running or started while checkin_open is still true.
--
-- Push at close: live_activity_session_step now also wakes a session just after checkin_closes_at. checkin_open
-- flips there, so the content fingerprint changes and the existing "changed -> enqueue next version" path sends
-- exactly one update; the next run finds the same fingerprint and sends nothing.
-- Both functions are rebuilt from pg_get_functiondef of the live catalogue; only the marked lines change.

CREATE OR REPLACE FUNCTION public.live_activity_build_state(p_event_id uuid, p_user_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE l jsonb; v_state text; v_checked boolean; ev record; v_org boolean; v_action text;
        v_ci_state text; v_ci_closes timestamptz;   -- KAN-1024
BEGIN
  l := public.live_activity_lifecycle_as(p_event_id, p_user_id);
  SELECT e.title, e.start_at, e.end_at, e.venue_id, e.creator_user_id INTO ev FROM public.events e WHERE e.id = p_event_id;
  v_org := ev.creator_user_id IS NOT DISTINCT FROM p_user_id;
  v_checked := EXISTS (SELECT 1 FROM public.event_attendance a WHERE a.event_id = p_event_id AND a.user_id = p_user_id
                         AND a.checked_in_at IS NOT NULL);
  -- KAN-1024: the check-in window, from the same source as rpc_attendance_my
  v_ci_state := public.kan1008_check_in_state(p_event_id, p_user_id);
  SELECT a.start_at + interval '15 minutes' INTO v_ci_closes FROM public.attendance_event(p_event_id) a;
  v_state := CASE
    WHEN (l->>'is_cancelled')::boolean THEN 'cancelled'
    WHEN l->>'state' = 'auto_closed' THEN 'scheduled_time_ended'
    WHEN l->>'state' IN ('confirmed', 'did_not_happen') THEN 'ended'
    WHEN l->>'state' = 'started' THEN 'started'
    WHEN now() >= (l->>'start_at')::timestamptz THEN 'scheduled_time_running'   -- scheduled / awaiting_confirmation
    WHEN v_checked THEN 'checked_in'
    ELSE 'checkin_open' END;
  IF v_org AND v_state NOT IN ('cancelled', 'ended', 'scheduled_time_ended') THEN
    v_action := CASE WHEN l->>'state' = 'awaiting_confirmation' THEN 'confirm_end'
                     WHEN l->>'state' = 'scheduled' AND now() >= (l->>'start_at')::timestamptz THEN 'start' END;
  END IF;
  RETURN jsonb_build_object(
    'state', v_state,
    'final', v_state IN ('cancelled', 'ended', 'scheduled_time_ended'),
    'content', jsonb_strip_nulls(jsonb_build_object(
      'state', v_state, 'event_id', p_event_id, 'event_type', l->>'event_type', 'title', ev.title,
      'start_at', floor(extract(epoch FROM (l->>'start_at')::timestamptz))::bigint,
      'end_at', floor(extract(epoch FROM (l->>'end_at')::timestamptz))::bigint,
      'scheduled_end_at', floor(extract(epoch FROM (l->>'scheduled_end_at')::timestamptz))::bigint,
      'actual_started_at', floor(extract(epoch FROM (l->>'actual_started_at')::timestamptz))::bigint,
      'checked_in', v_checked,
      'checkin_closes_at', floor(extract(epoch FROM v_ci_closes))::bigint,   -- KAN-1024
      'checkin_open', v_ci_state = 'open',                                   -- KAN-1024
      'role', CASE WHEN v_org THEN 'organiser' ELSE 'participant' END,
      'organiser_action', v_action)),
    'basis', jsonb_build_object('start_at', ev.start_at, 'end_at', ev.end_at, 'venue_id', ev.venue_id));
END;
$function$;

CREATE OR REPLACE FUNCTION public.live_activity_session_step(p_session_id uuid)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE s public.live_activity_sessions%ROWTYPE; b jsonb; v_reason text; v_fp text; v_change text; v_cu uuid;
        v_next timestamptz;
BEGIN
  SELECT * INTO s FROM public.live_activity_sessions WHERE id = p_session_id FOR UPDATE SKIP LOCKED;
  IF s.id IS NULL OR s.status = 'ended' THEN RETURN 'skipped'; END IF;
  SELECT e.creator_user_id INTO v_cu FROM public.events e WHERE e.id = s.event_id;

  IF NOT EXISTS (SELECT 1 FROM public.fcm_tokens f WHERE f.user_id = s.user_id AND f.installation_id = s.installation_id) THEN
    v_reason := 'signed_out';
  ELSIF EXISTS (SELECT 1 FROM public.live_activity_optouts o WHERE o.user_id = s.user_id AND o.installation_id = s.installation_id) THEN
    v_reason := 'opted_out';
  ELSIF s.user_id IS DISTINCT FROM v_cu
        AND NOT EXISTS (SELECT 1 FROM public.attendance_participants(s.event_id) p WHERE p = s.user_id) THEN
    v_reason := CASE
      WHEN EXISTS (SELECT 1 FROM public.games g JOIN public.game_roster r ON r.game_id = g.id
                    WHERE g.event_id = s.event_id AND r.user_id = s.user_id AND r.status = 'kicked')
        OR EXISTS (SELECT 1 FROM public.meetups m JOIN public.meetup_rsvps v ON v.meetup_id = m.id
                    WHERE m.event_id = s.event_id AND v.user_id = s.user_id AND v.status = 'removed')
      THEN 'removed' ELSE 'left' END;
  END IF;
  IF v_reason IS NOT NULL THEN
    PERFORM public.live_activity_end(s.id, v_reason);
    RETURN 'ended:' || v_reason;
  END IF;

  BEGIN
    b := public.live_activity_build_state(s.event_id, s.user_id);
  EXCEPTION WHEN SQLSTATE 'P0002' THEN
    PERFORM public.live_activity_end(s.id, 'access_lost');
    RETURN 'ended:access_lost';
  END;

  SELECT min(t) INTO v_next FROM unnest(ARRAY[to_timestamp((b->'content'->>'start_at')::bigint),
                                              to_timestamp((b->'content'->>'scheduled_end_at')::bigint),
                                              -- KAN-1024: wake just after check-in closes (the window is inclusive)
                                              to_timestamp((b->'content'->>'checkin_closes_at')::bigint + 1)]) t
   WHERE t > now();
  v_next := least(coalesce(v_next, now() + interval '10 minutes'), now() + interval '10 minutes');
  UPDATE public.live_activity_sessions SET due_at = v_next, is_organiser = (s.user_id = v_cu) WHERE id = s.id;

  v_fp := md5((b->'content')::text || (b->'basis')::text);
  IF v_fp IS NOT DISTINCT FROM s.last_fingerprint THEN RETURN 'unchanged'; END IF;

  IF s.last_basis IS NOT NULL THEN
    v_change := CASE
      WHEN s.last_basis->'start_at' IS DISTINCT FROM b->'basis'->'start_at'
        OR s.last_basis->'end_at' IS DISTINCT FROM b->'basis'->'end_at' THEN 'time'
      WHEN s.last_basis->'venue_id' IS DISTINCT FROM b->'basis'->'venue_id' THEN 'venue' END;
  END IF;
  UPDATE public.live_activity_sessions SET last_fingerprint = v_fp, last_basis = b->'basis' WHERE id = s.id;

  IF (b->>'final')::boolean THEN
    PERFORM public.live_activity_end(s.id,
      CASE b->>'state' WHEN 'cancelled' THEN 'cancelled' WHEN 'scheduled_time_ended' THEN 'scheduled_time_ended'
                       ELSE 'event_ended' END, b->'content');
    RETURN 'ended:' || (b->>'state');
  END IF;
  PERFORM public.live_activity_enqueue(s.id, CASE WHEN s.status = 'planned' THEN 'start' ELSE 'update' END,
            b->>'state', (b->'content') || jsonb_strip_nulls(jsonb_build_object('change', v_change)));
  RETURN 'sent';
END;
$function$;
