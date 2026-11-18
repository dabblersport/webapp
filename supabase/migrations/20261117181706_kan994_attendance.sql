-- KAN-994 [W2-B1] Attendance (Epic KAN-973). F-8, G-04..G-07, I (design-check conflicts 1 and 6).
--
-- * event_attendance: one row per participant and event (unique). Participants are a game's active roster players and
--   a meetup's 'going' RSVPs; the organiser (events.creator_user_id) is never a participant. No location is stored.
-- * Check-in: the participant, from 30 minutes before to 15 minutes after the start, server-side window, not on a
--   cancelled or finalized event. Twice keeps one row.
-- * Organiser: the list, corrections (attended / no_show) only after the window, each with a reason and audited in
--   event_attendance_corrections, then Finalize. Only the event's organiser.
-- * Finalize (organiser): attended stays attended; everyone else becomes no_show_pending with a 48h deadline and is told
--   ("confirms in 48h unless you ask for a review"). Not counted yet.
-- * Review: the player asks within 48h (optional note); the organiser accepts (attended) or keeps (no_show_confirmed).
--   An unanswered request is accepted in the player's favour after 48h. No request within 48h: no_show_confirmed.
-- * Auto-finalize: 24h after the end (end_at, else start_at) with check-ins as recorded and nobody marked no-show:
--   not checked in -> unknown (never counted). Only for events that start after this migration (no backfill).
-- * Show-up rate: attended / (attended + no_show_confirmed) over non-cancelled events; NULL rate below 3 confirmed.
-- * Timed work runs in attendance_sweep(), every 5 minutes on cron (not KAN-983's notification_jobs).
-- * Notices through notify_v2 (EN/AR templates from KAN-974): activity.no_show_pending, review_requested,
--   review_accepted, review_kept, no_show_confirmed are activated. activity.checkin_open stays inactive: the
--   check-in-open notice is the 30-minute reminder rung (KAN-983).

-- 0. Pre-image guard -------------------------------------------------------------------------------------------------
DO $guard$
BEGIN
  IF to_regclass('public.event_attendance') IS NOT NULL OR to_regclass('public.event_attendance_corrections') IS NOT NULL
     OR to_regclass('public.event_attendance_finalizations') IS NOT NULL
     OR to_regproc('public.rpc_attendance_check_in') IS NOT NULL OR to_regproc('public.attendance_sweep') IS NOT NULL THEN
    RAISE EXCEPTION 'kan994 pre-image: an attendance object already exists';
  END IF;
  IF (SELECT count(*) FROM public.notification_kinds
       WHERE key IN ('activity.no_show_pending','activity.review_requested','activity.review_accepted',
                     'activity.review_kept','activity.no_show_confirmed','activity.checkin_open') AND NOT is_active) <> 6 THEN
    RAISE EXCEPTION 'kan994 pre-image: attendance kinds are not all inactive';
  END IF;
  IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'kan994_attendance_sweep') THEN
    RAISE EXCEPTION 'kan994 pre-image: cron job exists';
  END IF;
END
$guard$;

-- 1. Tables ----------------------------------------------------------------------------------------------------------
CREATE TABLE public.event_attendance (
  id                  uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id            uuid        NOT NULL REFERENCES public.events (id) ON DELETE CASCADE,
  event_type          text        NOT NULL,
  user_id             uuid        NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
  checked_in_at       timestamptz,
  mark                text,                     -- attended | no_show (self check-in or organiser correction)
  mark_method         text,                     -- self | organiser
  corrected_by        uuid,
  corrected_at        timestamptz,
  correction_reason   text,
  outcome             text,                     -- NULL until finalized
  finalized_at        timestamptz,
  no_show_deadline    timestamptz,
  review_requested_at timestamptz,
  review_note         text,
  review_deadline     timestamptz,
  review_decision     text,                     -- accepted | kept | expired_accepted
  review_decided_at   timestamptz,
  created_at          timestamptz NOT NULL DEFAULT now(),
  updated_at          timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT event_attendance_unique UNIQUE (event_id, user_id),
  CONSTRAINT event_attendance_type_chk CHECK (event_type IN ('game', 'meetup')),
  CONSTRAINT event_attendance_mark_chk CHECK (mark IS NULL OR mark IN ('attended', 'no_show')),
  CONSTRAINT event_attendance_method_chk CHECK (mark_method IS NULL OR mark_method IN ('self', 'organiser')),
  CONSTRAINT event_attendance_outcome_chk CHECK (outcome IS NULL OR outcome IN
    ('attended', 'no_show_pending', 'no_show_review', 'no_show_confirmed', 'unknown')),
  CONSTRAINT event_attendance_decision_chk CHECK (review_decision IS NULL OR review_decision IN
    ('accepted', 'kept', 'expired_accepted')),
  CONSTRAINT event_attendance_reason_len_chk CHECK (correction_reason IS NULL OR char_length(correction_reason) BETWEEN 1 AND 300),
  CONSTRAINT event_attendance_note_len_chk CHECK (review_note IS NULL OR char_length(review_note) <= 500)
);
CREATE INDEX event_attendance_user_idx ON public.event_attendance (user_id, outcome);
CREATE INDEX event_attendance_pending_idx ON public.event_attendance (no_show_deadline) WHERE outcome = 'no_show_pending';
CREATE INDEX event_attendance_review_idx ON public.event_attendance (review_deadline) WHERE outcome = 'no_show_review';
COMMENT ON TABLE public.event_attendance IS
  'KAN-994: who attended each game or meetup. Written only by the attendance RPCs and attendance_sweep. No location.';

CREATE TABLE public.event_attendance_corrections (
  id             uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  attendance_id  uuid        NOT NULL REFERENCES public.event_attendance (id) ON DELETE CASCADE,
  event_id       uuid        NOT NULL,
  user_id        uuid        NOT NULL,
  actor_user_id  uuid        NOT NULL,
  from_mark      text,
  to_mark        text        NOT NULL,
  reason         text        NOT NULL,
  created_at     timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX event_attendance_corrections_event_idx ON public.event_attendance_corrections (event_id, created_at);
COMMENT ON TABLE public.event_attendance_corrections IS 'KAN-994: audit of every organiser correction, with its reason.';

CREATE TABLE public.event_attendance_finalizations (
  event_id      uuid        PRIMARY KEY REFERENCES public.events (id) ON DELETE CASCADE,
  finalized_at  timestamptz NOT NULL DEFAULT now(),
  finalized_by  uuid,                      -- NULL = auto-finalized
  auto          boolean     NOT NULL DEFAULT false
);
COMMENT ON TABLE public.event_attendance_finalizations IS 'KAN-994: one row once an event''s attendance is final.';

-- Server-only tables: RLS on, no policy, no client grant. Clients use the RPCs below (T-020).
ALTER TABLE public.event_attendance ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.event_attendance_corrections ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.event_attendance_finalizations ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.event_attendance, public.event_attendance_corrections, public.event_attendance_finalizations
  FROM PUBLIC, anon, authenticated;
GRANT ALL ON public.event_attendance, public.event_attendance_corrections, public.event_attendance_finalizations TO service_role;

-- 2. Helpers ---------------------------------------------------------------------------------------------------------
-- The event's facts: type, organiser, times, cancelled, and the subtype id (games.id / meetups.id) for notices.
CREATE FUNCTION public.attendance_event(p_event_id uuid,
  OUT event_type text, OUT organiser uuid, OUT start_at timestamptz, OUT end_at timestamptz,
  OUT is_cancelled boolean, OUT title text, OUT entity_id uuid)
RETURNS record
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT e.event_type, e.creator_user_id, e.start_at, COALESCE(e.end_at, e.start_at), COALESCE(e.is_cancelled, false),
         e.title,
         CASE e.event_type WHEN 'game' THEN (SELECT g.id FROM public.games g WHERE g.event_id = e.id LIMIT 1)
                           WHEN 'meetup' THEN (SELECT m.id FROM public.meetups m WHERE m.event_id = e.id LIMIT 1) END
    FROM public.events e WHERE e.id = p_event_id;
$function$;

-- Participants: game active roster players (not the host/organiser), meetup 'going' RSVPs (not the organiser).
CREATE FUNCTION public.attendance_participants(p_event_id uuid)
RETURNS SETOF uuid
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT DISTINCT r.user_id
    FROM public.games g JOIN public.game_roster r ON r.game_id = g.id
    JOIN public.events e ON e.id = g.event_id
   WHERE g.event_id = p_event_id AND r.status = 'active' AND r.role = 'player'
     AND r.user_id IS NOT NULL AND r.user_id IS DISTINCT FROM e.creator_user_id
  UNION
  SELECT DISTINCT rv.user_id
    FROM public.meetups m JOIN public.meetup_rsvps rv ON rv.meetup_id = m.id
    JOIN public.events e ON e.id = m.event_id
   WHERE m.event_id = p_event_id AND rv.status = 'going'
     AND rv.user_id IS NOT NULL AND rv.user_id IS DISTINCT FROM e.creator_user_id;
$function$;

CREATE FUNCTION public.attendance_notify(p_event_id uuid, p_to uuid, p_kind text, p_actor uuid, p_extra jsonb DEFAULT '{}'::jsonb)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE ev record;
BEGIN
  SELECT * INTO ev FROM public.attendance_event(p_event_id);
  RETURN public.notify_v2(
    p_to, p_kind,
    jsonb_strip_nulls(jsonb_build_object('title', ev.title, 'event_id', p_event_id::text)) || COALESCE(p_extra, '{}'::jsonb),
    ev.event_type, ev.entity_id, p_actor,
    'attendance:' || p_event_id::text,
    p_kind || ':' || p_event_id::text || ':' || p_to::text,
    NULL, NULL);
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'attendance_notify % failed (sqlstate %)', p_kind, SQLSTATE;
  RETURN NULL;
END;
$function$;

-- Finalize one event: p_auto = false (organiser) or true (24h after the end). Idempotent: a finalized event is skipped.
CREATE FUNCTION public.attendance_finalize_event(p_event_id uuid, p_by uuid, p_auto boolean, p_now timestamptz DEFAULT now())
RETURNS integer
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE ev record; v_uid uuid; v_mark text; v_n integer := 0;
BEGIN
  INSERT INTO public.event_attendance_finalizations (event_id, finalized_at, finalized_by, auto)
  VALUES (p_event_id, p_now, p_by, p_auto) ON CONFLICT (event_id) DO NOTHING;
  IF NOT FOUND THEN
    RETURN 0;
  END IF;
  SELECT * INTO ev FROM public.attendance_event(p_event_id);
  FOR v_uid IN SELECT public.attendance_participants(p_event_id) LOOP
    INSERT INTO public.event_attendance (event_id, event_type, user_id)
    VALUES (p_event_id, ev.event_type, v_uid) ON CONFLICT (event_id, user_id) DO NOTHING;
    SELECT a.mark INTO v_mark FROM public.event_attendance a WHERE a.event_id = p_event_id AND a.user_id = v_uid FOR UPDATE;
    IF v_mark = 'attended' THEN
      UPDATE public.event_attendance SET outcome = 'attended', finalized_at = p_now, updated_at = p_now
       WHERE event_id = p_event_id AND user_id = v_uid;
    ELSIF p_auto THEN
      -- assumption: auto-finalize marks nobody no-show
      UPDATE public.event_attendance SET outcome = 'unknown', finalized_at = p_now, updated_at = p_now
       WHERE event_id = p_event_id AND user_id = v_uid;
    ELSE
      UPDATE public.event_attendance
         SET outcome = 'no_show_pending', finalized_at = p_now, no_show_deadline = p_now + interval '48 hours',
             updated_at = p_now
       WHERE event_id = p_event_id AND user_id = v_uid;
      PERFORM public.attendance_notify(p_event_id, v_uid, 'activity.no_show_pending', p_by,
        jsonb_strip_nulls(jsonb_build_object('reason',
          (SELECT a.correction_reason FROM public.event_attendance a WHERE a.event_id = p_event_id AND a.user_id = v_uid))));
    END IF;
    v_n := v_n + 1;
  END LOOP;
  RETURN v_n;
END;
$function$;

-- 3. Player RPCs -----------------------------------------------------------------------------------------------------
CREATE FUNCTION public.rpc_attendance_check_in(p_event_id uuid)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_uid uuid := auth.uid(); ev record; r public.event_attendance%ROWTYPE;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION USING errcode = '42501', message = 'not_authenticated';
  END IF;
  SELECT * INTO ev FROM public.attendance_event(p_event_id);
  IF ev.event_type IS NULL THEN
    RAISE EXCEPTION USING errcode = 'P0002', message = 'event_not_found';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.attendance_participants(p_event_id) x WHERE x = v_uid) THEN
    RAISE EXCEPTION USING errcode = '42501', message = 'not_eligible';
  END IF;
  IF ev.is_cancelled THEN
    RAISE EXCEPTION USING errcode = '22023', message = 'event_cancelled';
  END IF;
  IF EXISTS (SELECT 1 FROM public.event_attendance_finalizations f WHERE f.event_id = p_event_id) THEN
    RAISE EXCEPTION USING errcode = '22023', message = 'attendance_finalized';
  END IF;
  IF now() < ev.start_at - interval '30 minutes' OR now() > ev.start_at + interval '15 minutes' THEN
    RAISE EXCEPTION USING errcode = '22023', message = 'check_in_closed',
      detail = format('opens %s, closes %s', ev.start_at - interval '30 minutes', ev.start_at + interval '15 minutes');
  END IF;
  INSERT INTO public.event_attendance (event_id, event_type, user_id, checked_in_at, mark, mark_method)
  VALUES (p_event_id, ev.event_type, v_uid, now(), 'attended', 'self')
  ON CONFLICT (event_id, user_id) DO UPDATE
     SET checked_in_at = COALESCE(public.event_attendance.checked_in_at, EXCLUDED.checked_in_at),
         mark = CASE WHEN public.event_attendance.mark_method = 'organiser' THEN public.event_attendance.mark ELSE 'attended' END,
         mark_method = COALESCE(public.event_attendance.mark_method, 'self'),
         updated_at = now()
  RETURNING * INTO r;
  RETURN jsonb_build_object('event_id', p_event_id, 'checked_in_at', r.checked_in_at, 'state', 'checked_in');
END;
$function$;

-- The caller's own check-in state for the G-04 screen.
CREATE FUNCTION public.rpc_attendance_my(p_event_id uuid)
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_uid uuid := auth.uid(); ev record; r public.event_attendance%ROWTYPE; v_state text; v_elig boolean;
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
  v_state := CASE
    WHEN NOT v_elig AND r.id IS NULL THEN 'not_eligible'
    WHEN r.outcome IS NOT NULL THEN r.outcome
    WHEN r.checked_in_at IS NOT NULL THEN 'checked_in'
    WHEN ev.is_cancelled THEN 'cancelled'
    WHEN now() < ev.start_at - interval '30 minutes' THEN 'before_window'
    WHEN now() <= ev.start_at + interval '15 minutes' THEN 'open'
    ELSE 'closed' END;
  RETURN jsonb_build_object(
    'event_id', p_event_id, 'state', v_state,
    'opens_at', ev.start_at - interval '30 minutes', 'closes_at', ev.start_at + interval '15 minutes',
    'checked_in_at', r.checked_in_at, 'outcome', r.outcome, 'correction_reason', r.correction_reason,
    'no_show_deadline', r.no_show_deadline, 'review_deadline', r.review_deadline, 'review_decision', r.review_decision);
END;
$function$;

CREATE FUNCTION public.rpc_attendance_request_review(p_event_id uuid, p_note text DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_uid uuid := auth.uid(); r public.event_attendance%ROWTYPE; ev record; v_note text;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION USING errcode = '42501', message = 'not_authenticated';
  END IF;
  SELECT * INTO r FROM public.event_attendance a WHERE a.event_id = p_event_id AND a.user_id = v_uid FOR UPDATE;
  IF r.id IS NULL OR r.outcome IS DISTINCT FROM 'no_show_pending' THEN
    RAISE EXCEPTION USING errcode = '22023', message = 'no_pending_no_show';
  END IF;
  IF now() > r.no_show_deadline THEN
    RAISE EXCEPTION USING errcode = '22023', message = 'review_window_closed';
  END IF;
  v_note := NULLIF(left(btrim(regexp_replace(COALESCE(p_note, ''), '[[:cntrl:]]', ' ', 'g')), 500), '');
  UPDATE public.event_attendance
     SET outcome = 'no_show_review', review_requested_at = now(), review_note = v_note,
         review_deadline = now() + interval '48 hours', updated_at = now()
   WHERE id = r.id;
  SELECT * INTO ev FROM public.attendance_event(p_event_id);
  PERFORM public.attendance_notify(p_event_id, ev.organiser, 'activity.review_requested', v_uid,
    jsonb_build_object('player_user_id', v_uid::text));
  RETURN jsonb_build_object('event_id', p_event_id, 'state', 'no_show_review', 'review_deadline', now() + interval '48 hours');
END;
$function$;

-- Show-up rate for any user (own view or public profile). Aggregates only.
CREATE FUNCTION public.rpc_showup_rate(p_user_id uuid DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_uid uuid := COALESCE(p_user_id, auth.uid()); v_att int; v_ns int;
BEGIN
  IF auth.uid() IS NULL AND p_user_id IS NULL THEN
    RAISE EXCEPTION USING errcode = '42501', message = 'not_authenticated';
  END IF;
  SELECT count(*) FILTER (WHERE a.outcome = 'attended'), count(*) FILTER (WHERE a.outcome = 'no_show_confirmed')
    INTO v_att, v_ns
    FROM public.event_attendance a JOIN public.events e ON e.id = a.event_id
   WHERE a.user_id = v_uid AND NOT COALESCE(e.is_cancelled, false);
  RETURN jsonb_build_object(
    'user_id', v_uid, 'confirmed', v_att + v_ns, 'attended', v_att, 'no_shows', v_ns,
    'enough', (v_att + v_ns) >= 3,
    'rate', CASE WHEN (v_att + v_ns) >= 3 THEN round(100.0 * v_att / (v_att + v_ns))::int END);
END;
$function$;

-- 4. Organiser RPCs --------------------------------------------------------------------------------------------------
CREATE FUNCTION public.rpc_attendance_list(p_event_id uuid)
RETURNS TABLE (user_id uuid, display_name text, checked_in_at timestamptz, mark text, mark_method text,
               correction_reason text, outcome text, review_requested_at timestamptz, review_note text,
               review_deadline timestamptz, no_show_deadline timestamptz, finalized boolean)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE ev record;
BEGIN
  SELECT * INTO ev FROM public.attendance_event(p_event_id);
  IF auth.uid() IS NULL OR ev.organiser IS DISTINCT FROM auth.uid() THEN
    RAISE EXCEPTION USING errcode = '42501', message = 'not_organiser';
  END IF;
  RETURN QUERY
    SELECT p.uid, (SELECT pr.display_name FROM public.profiles pr WHERE pr.user_id = p.uid AND pr.is_active
                    ORDER BY pr.updated_at DESC NULLS LAST LIMIT 1),
           a.checked_in_at, a.mark, a.mark_method, a.correction_reason, a.outcome, a.review_requested_at, a.review_note,
           a.review_deadline, a.no_show_deadline,
           EXISTS (SELECT 1 FROM public.event_attendance_finalizations f WHERE f.event_id = p_event_id)
      FROM (SELECT x AS uid FROM public.attendance_participants(p_event_id) x
            UNION SELECT a2.user_id FROM public.event_attendance a2 WHERE a2.event_id = p_event_id) p
      LEFT JOIN public.event_attendance a ON a.event_id = p_event_id AND a.user_id = p.uid;
END;
$function$;

CREATE FUNCTION public.rpc_attendance_correct(p_event_id uuid, p_user_id uuid, p_mark text, p_reason text)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_uid uuid := auth.uid(); ev record; v_reason text; r public.event_attendance%ROWTYPE;
BEGIN
  SELECT * INTO ev FROM public.attendance_event(p_event_id);
  IF v_uid IS NULL OR ev.organiser IS DISTINCT FROM v_uid THEN
    RAISE EXCEPTION USING errcode = '42501', message = 'not_organiser';
  END IF;
  IF p_mark IS NULL OR p_mark NOT IN ('attended', 'no_show') THEN
    RAISE EXCEPTION USING errcode = '22023', message = 'invalid_mark';
  END IF;
  v_reason := NULLIF(left(btrim(regexp_replace(COALESCE(p_reason, ''), '[[:cntrl:]]', ' ', 'g')), 300), '');
  IF v_reason IS NULL THEN
    RAISE EXCEPTION USING errcode = '22023', message = 'reason_required';
  END IF;
  IF ev.is_cancelled THEN
    RAISE EXCEPTION USING errcode = '22023', message = 'event_cancelled';
  END IF;
  IF now() <= ev.start_at + interval '15 minutes' THEN
    RAISE EXCEPTION USING errcode = '22023', message = 'window_not_closed';
  END IF;
  IF EXISTS (SELECT 1 FROM public.event_attendance_finalizations f WHERE f.event_id = p_event_id) THEN
    RAISE EXCEPTION USING errcode = '22023', message = 'attendance_finalized';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.attendance_participants(p_event_id) x WHERE x = p_user_id) THEN
    RAISE EXCEPTION USING errcode = '22023', message = 'not_a_participant';
  END IF;
  INSERT INTO public.event_attendance (event_id, event_type, user_id)
  VALUES (p_event_id, ev.event_type, p_user_id) ON CONFLICT (event_id, user_id) DO NOTHING;
  SELECT * INTO r FROM public.event_attendance a WHERE a.event_id = p_event_id AND a.user_id = p_user_id FOR UPDATE;
  INSERT INTO public.event_attendance_corrections (attendance_id, event_id, user_id, actor_user_id, from_mark, to_mark, reason)
  VALUES (r.id, p_event_id, p_user_id, v_uid, r.mark, p_mark, v_reason);
  UPDATE public.event_attendance
     SET mark = p_mark, mark_method = 'organiser', corrected_by = v_uid, corrected_at = now(),
         correction_reason = v_reason, updated_at = now()
   WHERE id = r.id;
  RETURN jsonb_build_object('event_id', p_event_id, 'user_id', p_user_id, 'mark', p_mark);
END;
$function$;

CREATE FUNCTION public.rpc_attendance_finalize(p_event_id uuid)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_uid uuid := auth.uid(); ev record; v_n int;
BEGIN
  SELECT * INTO ev FROM public.attendance_event(p_event_id);
  IF v_uid IS NULL OR ev.organiser IS DISTINCT FROM v_uid THEN
    RAISE EXCEPTION USING errcode = '42501', message = 'not_organiser';
  END IF;
  IF ev.is_cancelled THEN
    RAISE EXCEPTION USING errcode = '22023', message = 'event_cancelled';
  END IF;
  IF now() <= ev.start_at + interval '15 minutes' THEN
    RAISE EXCEPTION USING errcode = '22023', message = 'window_not_closed';
  END IF;
  IF EXISTS (SELECT 1 FROM public.event_attendance_finalizations f WHERE f.event_id = p_event_id) THEN
    RAISE EXCEPTION USING errcode = '22023', message = 'attendance_finalized';
  END IF;
  v_n := public.attendance_finalize_event(p_event_id, v_uid, false, now());
  RETURN jsonb_build_object('event_id', p_event_id, 'finalized', true, 'participants', v_n);
END;
$function$;

CREATE FUNCTION public.rpc_attendance_decide_review(p_event_id uuid, p_user_id uuid, p_decision text)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_uid uuid := auth.uid(); ev record; r public.event_attendance%ROWTYPE;
BEGIN
  SELECT * INTO ev FROM public.attendance_event(p_event_id);
  IF v_uid IS NULL OR ev.organiser IS DISTINCT FROM v_uid THEN
    RAISE EXCEPTION USING errcode = '42501', message = 'not_organiser';
  END IF;
  IF p_decision IS NULL OR p_decision NOT IN ('accept', 'keep') THEN
    RAISE EXCEPTION USING errcode = '22023', message = 'invalid_decision';
  END IF;
  SELECT * INTO r FROM public.event_attendance a WHERE a.event_id = p_event_id AND a.user_id = p_user_id FOR UPDATE;
  IF r.id IS NULL OR r.outcome IS DISTINCT FROM 'no_show_review' THEN
    RAISE EXCEPTION USING errcode = '22023', message = 'no_open_review';
  END IF;
  IF p_decision = 'accept' THEN
    UPDATE public.event_attendance SET outcome = 'attended', review_decision = 'accepted', review_decided_at = now(),
           updated_at = now() WHERE id = r.id;
    PERFORM public.attendance_notify(p_event_id, p_user_id, 'activity.review_accepted', v_uid);
  ELSE
    UPDATE public.event_attendance SET outcome = 'no_show_confirmed', review_decision = 'kept', review_decided_at = now(),
           updated_at = now() WHERE id = r.id;
    PERFORM public.attendance_notify(p_event_id, p_user_id, 'activity.review_kept', v_uid);
  END IF;
  RETURN jsonb_build_object('event_id', p_event_id, 'user_id', p_user_id,
    'outcome', CASE WHEN p_decision = 'accept' THEN 'attended' ELSE 'no_show_confirmed' END);
END;
$function$;

-- 5. Timed work ------------------------------------------------------------------------------------------------------
-- Ship cutoff: auto-finalize only events that start after KAN-994 shipped (no backfill of past events).
CREATE FUNCTION public.attendance_sweep(p_now timestamptz DEFAULT now())
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_e uuid; r record; v_auto int := 0; v_conf int := 0; v_exp int := 0;
BEGIN
  -- 48h passed with no review request: the no-show is confirmed
  FOR r IN SELECT a.id, a.event_id, a.user_id FROM public.event_attendance a
            WHERE a.outcome = 'no_show_pending' AND a.no_show_deadline <= p_now FOR UPDATE SKIP LOCKED LOOP
    UPDATE public.event_attendance SET outcome = 'no_show_confirmed', updated_at = p_now WHERE id = r.id;
    PERFORM public.attendance_notify(r.event_id, r.user_id, 'activity.no_show_confirmed', NULL);
    v_conf := v_conf + 1;
  END LOOP;
  -- an unanswered review request after 48h is accepted in the player's favour
  FOR r IN SELECT a.id, a.event_id, a.user_id FROM public.event_attendance a
            WHERE a.outcome = 'no_show_review' AND a.review_deadline <= p_now FOR UPDATE SKIP LOCKED LOOP
    UPDATE public.event_attendance SET outcome = 'attended', review_decision = 'expired_accepted',
           review_decided_at = p_now, updated_at = p_now WHERE id = r.id;
    PERFORM public.attendance_notify(r.event_id, r.user_id, 'activity.review_accepted', NULL);
    v_exp := v_exp + 1;
  END LOOP;
  -- never finalized: 24h after the end, with check-ins as recorded and nobody marked no-show
  FOR v_e IN SELECT e.id FROM public.events e
              WHERE e.event_type IN ('game', 'meetup') AND NOT COALESCE(e.is_cancelled, false)
                AND e.start_at >= timestamptz '2026-11-17 18:00:00+00'
                AND COALESCE(e.end_at, e.start_at) + interval '24 hours' <= p_now
                AND NOT EXISTS (SELECT 1 FROM public.event_attendance_finalizations f WHERE f.event_id = e.id) LOOP
    PERFORM public.attendance_finalize_event(v_e, NULL, true, p_now);
    v_auto := v_auto + 1;
  END LOOP;
  RETURN jsonb_build_object('no_show_confirmed', v_conf, 'review_expired_accepted', v_exp, 'auto_finalized', v_auto);
END;
$function$;

-- 6. Grants ----------------------------------------------------------------------------------------------------------
REVOKE ALL ON FUNCTION public.attendance_event(uuid), public.attendance_participants(uuid),
  public.attendance_notify(uuid, uuid, text, uuid, jsonb), public.attendance_finalize_event(uuid, uuid, boolean, timestamptz),
  public.attendance_sweep(timestamptz),
  public.rpc_attendance_check_in(uuid), public.rpc_attendance_my(uuid), public.rpc_attendance_request_review(uuid, text),
  public.rpc_showup_rate(uuid), public.rpc_attendance_list(uuid), public.rpc_attendance_correct(uuid, uuid, text, text),
  public.rpc_attendance_finalize(uuid), public.rpc_attendance_decide_review(uuid, uuid, text)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.attendance_event(uuid), public.attendance_participants(uuid),
  public.attendance_notify(uuid, uuid, text, uuid, jsonb), public.attendance_finalize_event(uuid, uuid, boolean, timestamptz),
  public.attendance_sweep(timestamptz) TO service_role;
GRANT EXECUTE ON FUNCTION
  public.rpc_attendance_check_in(uuid), public.rpc_attendance_my(uuid), public.rpc_attendance_request_review(uuid, text),
  public.rpc_showup_rate(uuid), public.rpc_attendance_list(uuid), public.rpc_attendance_correct(uuid, uuid, text, text),
  public.rpc_attendance_finalize(uuid), public.rpc_attendance_decide_review(uuid, uuid, text)
  TO authenticated, service_role;

-- 7. Kinds and the sweep job -----------------------------------------------------------------------------------------
UPDATE public.notification_kinds SET is_active = true
 WHERE key IN ('activity.no_show_pending', 'activity.review_requested', 'activity.review_accepted',
               'activity.review_kept', 'activity.no_show_confirmed');

SELECT cron.schedule('kan994_attendance_sweep', '*/5 * * * *', 'SELECT public.attendance_sweep()');

-- 8. Post-image guard ------------------------------------------------------------------------------------------------
DO $post$
DECLARE v text;
BEGIN
  IF has_table_privilege('authenticated', 'public.event_attendance', 'SELECT')
     OR has_table_privilege('anon', 'public.event_attendance', 'SELECT')
     OR has_table_privilege('authenticated', 'public.event_attendance_corrections', 'SELECT') THEN
    RAISE EXCEPTION 'kan994 post-image: attendance tables readable by a client role';
  END IF;
  IF has_function_privilege('authenticated', 'public.attendance_sweep(timestamptz)', 'EXECUTE')
     OR has_function_privilege('anon', 'public.rpc_attendance_check_in(uuid)', 'EXECUTE')
     OR NOT has_function_privilege('authenticated', 'public.rpc_attendance_check_in(uuid)', 'EXECUTE') THEN
    RAISE EXCEPTION 'kan994 post-image: function grants';
  END IF;
  IF (SELECT is_active FROM public.notification_kinds WHERE key = 'activity.checkin_open') THEN
    RAISE EXCEPTION 'kan994 post-image: activity.checkin_open must stay inactive';
  END IF;
  SELECT string_agg(column_name, ',') INTO v FROM information_schema.columns
   WHERE table_schema = 'public' AND table_name LIKE 'event_attendance%'
     AND (column_name ~* '(lat|lng|lon|location|geo|ip)' OR data_type IN ('point', 'inet', 'USER-DEFINED'));
  IF v IS NOT NULL THEN
    RAISE EXCEPTION 'kan994 post-image: location-like column %', v;
  END IF;
END
$post$;
