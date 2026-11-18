-- KAN-1002 / KAN-998: the app reads an event's lifecycle, and the check-in read carries title and venue.
--
-- 1. public.kan1002_event_visible(uuid): the existing read rule, nothing wider.
--    game   -> public._can_view_game(games.id)            (creator, admin, active roster, waitlist, listing scope)
--    meetup -> public.kan713_meetup_visible(event_id)     (the meetups_select_visible RLS predicate)
--    Internal helper: executable by nobody but the owner.
-- 2. public.kan1002_venue_name(uuid): the venue name as entered (name_en, else name_ar; no translation) from
--    events.venue_id, else the game's venue_space -> venue, else meetups.location_name; null when none.
-- 3. public.rpc_event_lifecycle_read(uuid) -> jsonb, authenticated only. Raises event_not_found when the event does
--    not exist OR the caller cannot see it (one error, so existence does not leak).
--    'state' maps event_lifecycle_state's raw value for the app:
--      scheduled                              -> scheduled
--      started, now() <= scheduled end        -> started
--      started, now() >  scheduled end        -> awaiting_confirmation
--      ended   (closed_reason 'played')       -> confirmed
--      auto_closed                            -> auto_closed
--      did_not_happen                         -> did_not_happen
--    'raw_state' carries the unmapped value. Who confirmed is not stored in the output.
-- 4. rpc_attendance_my gains 'title' and 'venue_name' (additive). Both are null unless the caller can see the event,
--    is a participant or already has an attendance row, so the check-in read cannot be used to read a private
--    event's title. Every other key and behaviour is the live body verbatim (md5 guarded).

DO $guard$
BEGIN
  IF md5(pg_get_functiondef('public.rpc_attendance_my(uuid)'::regprocedure)) <> '67ab1830e32acda47a2955e1d99122d7' THEN
    RAISE EXCEPTION 'kan1002 pre-image: rpc_attendance_my changed since 20261118112225';
  END IF;
END
$guard$;

CREATE OR REPLACE FUNCTION public.kan1002_event_visible(p_event_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT coalesce((
    SELECT CASE e.event_type
             WHEN 'game'   THEN coalesce((SELECT public._can_view_game(g.id) FROM public.games g WHERE g.event_id = e.id LIMIT 1), false)
             WHEN 'meetup' THEN public.kan713_meetup_visible(e.id)
             ELSE false END
      FROM public.events e WHERE e.id = p_event_id), false);
$function$;
REVOKE ALL ON FUNCTION public.kan1002_event_visible(uuid) FROM PUBLIC, anon, authenticated, service_role;

CREATE OR REPLACE FUNCTION public.kan1002_venue_name(p_event_id uuid)
 RETURNS text
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT coalesce(
           (SELECT coalesce(nullif(v.name_en, ''), nullif(v.name_ar, '')) FROM public.venues v WHERE v.id = e.venue_id),
           (SELECT coalesce(nullif(v.name_en, ''), nullif(v.name_ar, ''))
              FROM public.games g JOIN public.venue_spaces s ON s.id = g.venue_space_id JOIN public.venues v ON v.id = s.venue_id
             WHERE g.event_id = e.id LIMIT 1),
           (SELECT nullif(m.location_name, '') FROM public.meetups m WHERE m.event_id = e.id LIMIT 1))
    FROM public.events e WHERE e.id = p_event_id;
$function$;
REVOKE ALL ON FUNCTION public.kan1002_venue_name(uuid) FROM PUBLIC, anon, authenticated, service_role;

CREATE OR REPLACE FUNCTION public.rpc_event_lifecycle_read(p_event_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_uid uuid := auth.uid(); ev record; l record; v_state text;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION USING errcode = '42501', message = 'not_authenticated';
  END IF;
  SELECT e.id, e.event_type, e.creator_user_id, e.start_at, e.end_at INTO ev FROM public.events e WHERE e.id = p_event_id;
  IF ev.id IS NULL OR NOT public.kan1002_event_visible(p_event_id) THEN
    RAISE EXCEPTION USING errcode = 'P0002', message = 'event_not_found';
  END IF;
  SELECT * INTO l FROM public.event_lifecycle_state(p_event_id);
  v_state := CASE l.state
    WHEN 'started' THEN CASE WHEN now() > l.scheduled_end_at THEN 'awaiting_confirmation' ELSE 'started' END
    WHEN 'ended' THEN 'confirmed'
    ELSE l.state END;
  RETURN jsonb_build_object(
    'event_id', p_event_id, 'event_type', ev.event_type,
    'state', v_state, 'raw_state', l.state,
    'start_at', ev.start_at, 'end_at', ev.end_at, 'scheduled_end_at', l.scheduled_end_at,
    'actual_started_at', l.actual_started_at, 'actual_ended_at', l.actual_ended_at,
    'closed_at', l.closed_at, 'closed_reason', l.closed_reason,
    'is_organiser', ev.creator_user_id = v_uid);
END;
$function$;
REVOKE ALL ON FUNCTION public.rpc_event_lifecycle_read(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rpc_event_lifecycle_read(uuid) TO authenticated;

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
  v_state := CASE
    WHEN NOT v_elig AND r.id IS NULL THEN 'not_eligible'
    WHEN r.outcome IS NOT NULL THEN r.outcome
    WHEN r.checked_in_at IS NOT NULL THEN 'checked_in'
    WHEN ev.is_cancelled THEN 'cancelled'
    WHEN now() < ev.start_at - interval '30 minutes' THEN 'before_window'
    WHEN now() <= ev.start_at + interval '15 minutes' THEN 'open'
    ELSE 'closed' END;
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

DO $post$
DECLARE p record;
BEGIN
  SELECT pg_get_userbyid(f.proowner) o, f.prosecdef s, f.proconfig c, (SELECT array_agg(x ORDER BY x) FROM unnest(f.proacl::text[]) x)::text a INTO p
    FROM pg_proc f WHERE f.oid = 'public.rpc_attendance_my(uuid)'::regprocedure;
  IF p.o <> 'postgres' OR NOT p.s OR p.c <> ARRAY['search_path=public, pg_temp']
     OR p.a <> '{authenticated=X/postgres,postgres=X/postgres,service_role=X/postgres}' THEN
    RAISE EXCEPTION 'kan1002 post-image: rpc_attendance_my attributes drifted: % % % %', p.o, p.s, p.c, p.a;
  END IF;
  SELECT pg_get_userbyid(f.proowner) o, f.prosecdef s, f.proconfig c, (SELECT array_agg(x ORDER BY x) FROM unnest(f.proacl::text[]) x)::text a INTO p
    FROM pg_proc f WHERE f.oid = 'public.rpc_event_lifecycle_read(uuid)'::regprocedure;
  IF p.o <> 'postgres' OR NOT p.s OR p.c <> ARRAY['search_path=public, pg_temp']
     OR p.a <> '{authenticated=X/postgres,postgres=X/postgres,service_role=X/postgres}' THEN
    RAISE EXCEPTION 'kan1002 post-image: rpc_event_lifecycle_read ACL/attributes: % % % %', p.o, p.s, p.c, p.a;
  END IF;
  IF EXISTS (SELECT 1 FROM pg_proc f WHERE f.oid IN ('public.kan1002_event_visible(uuid)'::regprocedure,
                                                    'public.kan1002_venue_name(uuid)'::regprocedure)
              AND f.proacl::text <> '{postgres=X/postgres}') THEN
    RAISE EXCEPTION 'kan1002 post-image: helper ACL is not owner-only';
  END IF;
END
$post$;
