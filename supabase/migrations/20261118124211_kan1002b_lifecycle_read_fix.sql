-- KAN-1002b: rpc_event_lifecycle_read after PEER review.
-- 1. raw 'scheduled' (also no lifecycle row) with now() > scheduled end -> 'awaiting_confirmation', as raw 'started'.
--    The KAN-995 worker keeps the row 'scheduled' at the end and sends confirm_end; rpc_event_confirm_end accepts it.
-- 2. 'is_cancelled' (events.is_cancelled).
-- 3. 'auto_close_at': the KAN-995 worker auto-closes at greatest(sched_end + 4h, reminder_sent_at + 2h), evaluated
--    on the row whose end_revision equals events.schedule_revision. It is exact only once the reminder is sent for the
--    current revision; before that, reminder_sent_at is not known (it is the worker run time), so null. Also null when
--    closed or cancelled (the worker skips both). Delivery is the first worker run at or after that instant.
-- Every other key is the live body verbatim (md5 guarded).

DO $guard$
BEGIN
  IF md5(pg_get_functiondef('public.rpc_event_lifecycle_read(uuid)'::regprocedure)) <> '4fd5d87f4f2c35899f42517776f850eb' THEN
    RAISE EXCEPTION 'kan1002b pre-image: rpc_event_lifecycle_read changed since 20261118123714';
  END IF;
END
$guard$;

CREATE OR REPLACE FUNCTION public.rpc_event_lifecycle_read(p_event_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_uid uuid := auth.uid(); ev record; l record; lr record; v_state text; v_auto timestamptz;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION USING errcode = '42501', message = 'not_authenticated';
  END IF;
  SELECT e.id, e.event_type, e.creator_user_id, e.start_at, e.end_at, e.is_cancelled, e.schedule_revision
    INTO ev FROM public.events e WHERE e.id = p_event_id;
  IF ev.id IS NULL OR NOT public.kan1002_event_visible(p_event_id) THEN
    RAISE EXCEPTION USING errcode = 'P0002', message = 'event_not_found';
  END IF;
  SELECT * INTO l FROM public.event_lifecycle_state(p_event_id);
  v_state := CASE l.state
    WHEN 'scheduled' THEN CASE WHEN now() > l.scheduled_end_at THEN 'awaiting_confirmation' ELSE 'scheduled' END
    WHEN 'started' THEN CASE WHEN now() > l.scheduled_end_at THEN 'awaiting_confirmation' ELSE 'started' END
    WHEN 'ended' THEN 'confirmed'
    ELSE l.state END;
  SELECT x.reminder_sent_at, x.end_revision INTO lr FROM public.event_lifecycle x WHERE x.event_id = p_event_id;
  IF l.state IN ('scheduled', 'started') AND NOT ev.is_cancelled AND lr.reminder_sent_at IS NOT NULL
     AND lr.end_revision IS NOT DISTINCT FROM ev.schedule_revision THEN
    v_auto := greatest(l.scheduled_end_at + interval '4 hours', lr.reminder_sent_at + interval '2 hours');
  END IF;
  RETURN jsonb_build_object(
    'event_id', p_event_id, 'event_type', ev.event_type,
    'state', v_state, 'raw_state', l.state,
    'start_at', ev.start_at, 'end_at', ev.end_at, 'scheduled_end_at', l.scheduled_end_at,
    'actual_started_at', l.actual_started_at, 'actual_ended_at', l.actual_ended_at,
    'closed_at', l.closed_at, 'closed_reason', l.closed_reason,
    'is_organiser', ev.creator_user_id = v_uid,
    'is_cancelled', ev.is_cancelled,
    'auto_close_at', v_auto);
END;
$function$;
REVOKE ALL ON FUNCTION public.rpc_event_lifecycle_read(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rpc_event_lifecycle_read(uuid) TO authenticated;

DO $post$
DECLARE p record;
BEGIN
  SELECT pg_get_userbyid(f.proowner) o, f.prosecdef s, f.proconfig c, (SELECT array_agg(x ORDER BY x) FROM unnest(f.proacl::text[]) x)::text a INTO p
    FROM pg_proc f WHERE f.oid = 'public.rpc_event_lifecycle_read(uuid)'::regprocedure;
  IF p.o <> 'postgres' OR NOT p.s OR p.c <> ARRAY['search_path=public, pg_temp']
     OR p.a <> '{authenticated=X/postgres,postgres=X/postgres,service_role=X/postgres}' THEN
    RAISE EXCEPTION 'kan1002b post-image: rpc_event_lifecycle_read ACL/attributes: % % % %', p.o, p.s, p.c, p.a;
  END IF;
END
$post$;
