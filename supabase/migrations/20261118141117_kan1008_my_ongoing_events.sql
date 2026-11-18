-- KAN-1008: rpc_my_ongoing_events, the caller's ongoing/imminent events for the in-app ongoing card.
-- Shares the lifecycle state mapping and the check-in state with rpc_event_lifecycle_read / rpc_attendance_my
-- through two helpers; both RPCs are re-authored (from pg_get_functiondef) to call them, behaviour unchanged.

-- 1. lifecycle view: the one copy of the state CASE and the auto_close_at rule
CREATE OR REPLACE FUNCTION public.kan1008_lifecycle_view(p_event_id uuid)
 RETURNS TABLE(state text, raw_state text, scheduled_end_at timestamptz, actual_started_at timestamptz,
               actual_ended_at timestamptz, closed_at timestamptz, closed_reason text, auto_close_at timestamptz)
 LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE ev record; l record; lr record;
BEGIN
  SELECT e.is_cancelled, e.schedule_revision INTO ev FROM public.events e WHERE e.id = p_event_id;
  SELECT * INTO l FROM public.event_lifecycle_state(p_event_id);
  IF l.state IS NULL THEN RETURN; END IF;
  state := CASE l.state
    WHEN 'scheduled' THEN CASE WHEN now() > l.scheduled_end_at THEN 'awaiting_confirmation' ELSE 'scheduled' END
    WHEN 'started' THEN CASE WHEN now() > l.scheduled_end_at THEN 'awaiting_confirmation' ELSE 'started' END
    WHEN 'ended' THEN 'confirmed'
    ELSE l.state END;
  raw_state := l.state; scheduled_end_at := l.scheduled_end_at; actual_started_at := l.actual_started_at;
  actual_ended_at := l.actual_ended_at; closed_at := l.closed_at; closed_reason := l.closed_reason;
  SELECT x.reminder_sent_at, x.end_revision INTO lr FROM public.event_lifecycle x WHERE x.event_id = p_event_id;
  IF l.state IN ('scheduled', 'started') AND NOT ev.is_cancelled AND lr.reminder_sent_at IS NOT NULL
     AND lr.end_revision IS NOT DISTINCT FROM ev.schedule_revision THEN
    auto_close_at := greatest(l.scheduled_end_at + interval '4 hours', lr.reminder_sent_at + interval '2 hours');
  END IF;
  RETURN NEXT;
END;
$function$;

-- 2. check-in state: the one copy of rpc_attendance_my's state CASE
CREATE OR REPLACE FUNCTION public.kan1008_check_in_state(p_event_id uuid, p_uid uuid)
 RETURNS text
 LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE ev record; r public.event_attendance%ROWTYPE; v_elig boolean;
BEGIN
  SELECT * INTO ev FROM public.attendance_event(p_event_id);
  v_elig := EXISTS (SELECT 1 FROM public.attendance_participants(p_event_id) x WHERE x = p_uid);
  SELECT * INTO r FROM public.event_attendance a WHERE a.event_id = p_event_id AND a.user_id = p_uid;
  RETURN CASE
    WHEN NOT v_elig AND r.id IS NULL THEN 'not_eligible'
    WHEN r.outcome IS NOT NULL THEN r.outcome
    WHEN r.checked_in_at IS NOT NULL THEN 'checked_in'
    WHEN ev.is_cancelled THEN 'cancelled'
    WHEN now() < ev.start_at - interval '30 minutes' THEN 'before_window'
    WHEN now() <= ev.start_at + interval '15 minutes' THEN 'open'
    ELSE 'closed' END;
END;
$function$;

REVOKE ALL ON FUNCTION public.kan1008_lifecycle_view(uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.kan1008_check_in_state(uuid, uuid) FROM PUBLIC, anon, authenticated;

-- 3. rpc_event_lifecycle_read on the shared view (same output keys and values)
CREATE OR REPLACE FUNCTION public.rpc_event_lifecycle_read(p_event_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_uid uuid := auth.uid(); ev record; l record;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION USING errcode = '42501', message = 'not_authenticated';
  END IF;
  SELECT e.id, e.event_type, e.creator_user_id, e.start_at, e.end_at, e.is_cancelled, e.schedule_revision
    INTO ev FROM public.events e WHERE e.id = p_event_id;
  IF ev.id IS NULL OR NOT public.kan1002_event_visible(p_event_id) THEN
    RAISE EXCEPTION USING errcode = 'P0002', message = 'event_not_found';
  END IF;
  SELECT * INTO l FROM public.kan1008_lifecycle_view(p_event_id);   -- KAN-1008: shared mapping
  RETURN jsonb_build_object(
    'event_id', p_event_id, 'event_type', ev.event_type,
    'state', l.state, 'raw_state', l.raw_state,
    'start_at', ev.start_at, 'end_at', ev.end_at, 'scheduled_end_at', l.scheduled_end_at,
    'actual_started_at', l.actual_started_at, 'actual_ended_at', l.actual_ended_at,
    'closed_at', l.closed_at, 'closed_reason', l.closed_reason,
    'is_organiser', ev.creator_user_id = v_uid,
    'is_cancelled', ev.is_cancelled,
    'auto_close_at', l.auto_close_at);
END;
$function$;

-- 4. rpc_attendance_my on the shared check-in state
CREATE OR REPLACE FUNCTION public.rpc_attendance_my(p_event_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_uid uuid := auth.uid(); ev record; r public.event_attendance%ROWTYPE; v_state text; v_elig boolean; v_show boolean;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION USING errcode = '42501', message = 'not_authenticated';
  END IF;
  SELECT * INTO ev FROM public.attendance_event(p_event_id);
  IF ev.event_type IS NULL THEN
    RAISE EXCEPTION USING errcode = 'P0002', message = 'event_not_found';
  END IF;
  v_elig := EXISTS (SELECT 1 FROM public.attendance_participants(p_event_id) x WHERE x = v_uid);
  SELECT * INTO r FROM public.event_attendance a WHERE a.event_id = p_event_id AND a.user_id = v_uid;
  v_state := public.kan1008_check_in_state(p_event_id, v_uid);   -- KAN-1008: shared
  v_show := v_elig OR r.id IS NOT NULL OR public.kan1002_event_visible(p_event_id);   -- KAN-1002
  RETURN jsonb_build_object(
    'event_id', p_event_id, 'state', v_state,
    'opens_at', ev.start_at - interval '30 minutes', 'closes_at', ev.start_at + interval '15 minutes',
    'checked_in_at', r.checked_in_at, 'outcome', r.outcome, 'correction_reason', r.correction_reason,
    'no_show_deadline', r.no_show_deadline, 'review_deadline', r.review_deadline, 'review_decision', r.review_decision,
    'title', CASE WHEN v_show THEN ev.title END,
    'venue_name', CASE WHEN v_show THEN public.kan1002_venue_name(p_event_id) END);
END;
$function$;

-- 5. index for the RSVP leg of the candidate set (meetup_rsvps had only (meetup_id, user_id))
CREATE INDEX IF NOT EXISTS meetup_rsvps_user_going_idx ON public.meetup_rsvps (user_id, meetup_id) WHERE status = 'going';

-- 6. the read
CREATE OR REPLACE FUNCTION public.rpc_my_ongoing_events(p_window_minutes integer DEFAULT 30)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_uid uuid := auth.uid(); v_now timestamptz := now(); v_win int;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION USING errcode = '42501', message = 'not_authenticated';
  END IF;
  v_win := least(greatest(coalesce(p_window_minutes, 30), 0), 120);
  RETURN coalesce((
    WITH cand AS (   -- narrow set: the caller's own links, start in [now - 48h, now + window]
      SELECT g.event_id AS id FROM public.game_roster r JOIN public.games g ON g.id = r.game_id
       WHERE r.user_id = v_uid AND r.status = 'active' AND r.role = 'player'
      UNION
      SELECT m.event_id FROM public.meetup_rsvps rv JOIN public.meetups m ON m.id = rv.meetup_id
       WHERE rv.user_id = v_uid AND rv.status = 'going'
      UNION
      SELECT e.id FROM public.events e
       WHERE e.creator_user_id = v_uid AND e.start_at >= v_now - interval '48 hours'
         AND e.start_at <= v_now + make_interval(mins => v_win)
    ), ev AS (
      SELECT e.* FROM cand c JOIN public.events e ON e.id = c.id
       WHERE e.event_type IN ('game', 'meetup')
         AND e.start_at >= v_now - interval '48 hours' AND e.start_at <= v_now + make_interval(mins => v_win)
    ), rows AS (
      SELECT e.id, e.event_type, e.title, e.start_at, e.creator_user_id, coalesce(e.is_cancelled, false) AS is_cancelled,
             e.cancelled_at, e.schedule_revision, l.*
        FROM ev e CROSS JOIN LATERAL public.kan1008_lifecycle_view(e.id) l
       WHERE public.kan1002_event_visible(e.id)
    ), kept AS (
      SELECT * FROM rows w
       WHERE CASE
         WHEN w.is_cancelled THEN w.cancelled_at > v_now - interval '2 hours'
         WHEN w.state IN ('confirmed', 'auto_closed', 'did_not_happen') THEN w.closed_at > v_now - interval '2 hours'
         WHEN w.state IN ('scheduled', 'started', 'awaiting_confirmation') THEN w.auto_close_at IS NULL OR w.auto_close_at > v_now
         ELSE false END
       ORDER BY w.start_at, w.id
       LIMIT 10
    )
    SELECT jsonb_agg(jsonb_build_object(
             'event_id', k.id, 'kind', k.event_type, 'title', k.title,
             'start_at', k.start_at, 'scheduled_end_at', k.scheduled_end_at,
             'actual_started_at', k.actual_started_at, 'auto_close_at', k.auto_close_at,
             'state', k.state, 'is_cancelled', k.is_cancelled, 'is_organiser', k.creator_user_id = v_uid,
             'check_in_state', public.kan1008_check_in_state(k.id, v_uid),
             'schedule_revision', k.schedule_revision,
             'previous_start_at', (SELECT (c.old_value #>> '{}')::timestamptz FROM public.event_changes c
                                    WHERE c.event_id = k.id AND c.schedule_change AND c.field = 'start_at'
                                      AND c.revision = (SELECT max(c2.revision) FROM public.event_changes c2
                                                         WHERE c2.event_id = k.id AND c2.schedule_change)
                                    ORDER BY c.id DESC LIMIT 1),
             'previous_end_at', (SELECT (c.old_value #>> '{}')::timestamptz FROM public.event_changes c
                                  WHERE c.event_id = k.id AND c.schedule_change AND c.field = 'end_at'
                                    AND c.revision = (SELECT max(c2.revision) FROM public.event_changes c2
                                                       WHERE c2.event_id = k.id AND c2.schedule_change)
                                  ORDER BY c.id DESC LIMIT 1))
           ORDER BY k.start_at, k.id)
      FROM kept k), '[]'::jsonb);
END;
$function$;

REVOKE ALL ON FUNCTION public.rpc_my_ongoing_events(integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rpc_my_ongoing_events(integer) TO authenticated;
