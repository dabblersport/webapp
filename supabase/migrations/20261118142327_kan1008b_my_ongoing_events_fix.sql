-- KAN-1008b: rpc_my_ongoing_events after PEER review.
-- 1. Cancelled with cancelled_at NULL (6 live events): the 2h retention runs from coalesce(cancelled_at, start_at).
--    start_at, not updated_at: trg_events_touch bumps updated_at on any edit, which would keep a cancelled event alive.
-- 2. Live state with auto_close_at NULL (no event_lifecycle row, or reminder not sent): out at scheduled end + 6h.
-- Every other line is the live body verbatim (md5 guarded).

DO $guard$
BEGIN
  IF md5(pg_get_functiondef('public.rpc_my_ongoing_events(integer)'::regprocedure)) <> '69be06de514da8e5e335c3cfcd24f286' THEN
    RAISE EXCEPTION 'kan1008b pre-image: rpc_my_ongoing_events changed since 20261118141117';
  END IF;
END
$guard$;

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
    WITH cand AS (
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
         WHEN w.is_cancelled THEN coalesce(w.cancelled_at, w.start_at) > v_now - interval '2 hours'
         WHEN w.state IN ('confirmed', 'auto_closed', 'did_not_happen') THEN w.closed_at > v_now - interval '2 hours'
         WHEN w.state IN ('scheduled', 'started', 'awaiting_confirmation') THEN
           CASE WHEN w.auto_close_at IS NULL THEN coalesce(w.scheduled_end_at, w.start_at) + interval '6 hours' > v_now
                ELSE w.auto_close_at > v_now END
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

DO $post$
DECLARE p record;
BEGIN
  SELECT pg_get_userbyid(f.proowner) o, f.prosecdef s, f.proconfig c, (SELECT array_agg(x ORDER BY x) FROM unnest(f.proacl::text[]) x)::text a INTO p
    FROM pg_proc f WHERE f.oid = 'public.rpc_my_ongoing_events(integer)'::regprocedure;
  IF p.o <> 'postgres' OR NOT p.s OR p.c <> ARRAY['search_path=public, pg_temp']
     OR p.a <> '{authenticated=X/postgres,postgres=X/postgres,service_role=X/postgres}' THEN
    RAISE EXCEPTION 'kan1008b post-image: rpc_my_ongoing_events ACL/attributes: % % % %', p.o, p.s, p.c, p.a;
  END IF;
END
$post$;
