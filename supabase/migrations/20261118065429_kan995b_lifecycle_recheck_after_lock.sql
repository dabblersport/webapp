-- KAN-995b: PEER fix (Jira KAN-995 comment 16517, backend-7). The worker built its candidate list on one snapshot,
-- then locked each row (FOR UPDATE SKIP LOCKED returns the latest commit) and acted without re-checking it, so a
-- confirm, a "did not happen" or a cancel that committed mid-run could still be reminded or auto-closed, and
-- kan995_transition would overwrite a closed row (probe E1).
--   1. kan995_lifecycle_worker: right after the lock, skip a row that is no longer scheduled/started and an event that
--      is now cancelled.
--   2. kan995_transition: raise 'lifecycle_closed' when the row is already ended / auto_closed / did_not_happen.
-- CREATE OR REPLACE of both, from the applied bodies (20261118053016); nothing else changes, ACLs kept.
-- Pre-image guard: md5(pg_get_functiondef) of both as applied. Post asserts: ACLs, the new checks in the bodies.
-- Live test: supabase/tests/notifications_v2/kan995_event_lifecycle.sql (14 probes + E1).

DO $pre$
BEGIN
  IF md5(pg_get_functiondef('public.kan995_lifecycle_worker(timestamptz)'::regprocedure)) <> '17db932c878b61e3460a466696d9a4ae'
     OR md5(pg_get_functiondef('public.kan995_transition(uuid,text,uuid,text,timestamptz,text,timestamptz)'::regprocedure))
        <> '0c11f7c24fae566c235ff8699dd8d29e' THEN
    RAISE EXCEPTION 'kan995b pre: the worker or kan995_transition changed since 20261118053016';
  END IF;
END $pre$;

CREATE OR REPLACE FUNCTION public.kan995_transition(p_event_id uuid, p_to text, p_actor uuid, p_reason text, p_now timestamptz,
                                         p_closed_reason text DEFAULT NULL, p_ended_at timestamptz DEFAULT NULL)
  RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
DECLARE v_from text; v_rev int;
BEGIN
  SELECT l.state INTO v_from FROM public.event_lifecycle l WHERE l.event_id = p_event_id;
  -- KAN-995b: a closed row is final. Refuse instead of overwriting it (PEER 16517, probe E1).
  IF v_from IN ('ended', 'auto_closed', 'did_not_happen') THEN
    RAISE EXCEPTION USING errcode = 'P0001', message = 'lifecycle_closed',
      detail = format('event %s is already %s; refusing %s', p_event_id, v_from, p_to);
  END IF;
  UPDATE public.event_lifecycle l
     SET state = p_to,
         actual_started_at = CASE WHEN p_to = 'started' THEN p_now ELSE l.actual_started_at END,
         started_by        = CASE WHEN p_to = 'started' THEN p_actor ELSE l.started_by END,
         actual_ended_at   = CASE WHEN p_to = 'ended' THEN p_ended_at ELSE l.actual_ended_at END,
         closed_at         = CASE WHEN p_to IN ('ended', 'auto_closed', 'did_not_happen') THEN p_now ELSE l.closed_at END,
         closed_by         = CASE WHEN p_to IN ('ended', 'did_not_happen') THEN p_actor ELSE l.closed_by END,
         closed_reason     = coalesce(p_closed_reason, l.closed_reason),
         revision = l.revision + 1, updated_at = p_now
   WHERE l.event_id = p_event_id
  RETURNING l.revision INTO v_rev;
  INSERT INTO public.event_lifecycle_transitions (event_id, from_state, to_state, actor_user_id, reason, revision, at)
  VALUES (p_event_id, v_from, p_to, p_actor, p_reason, v_rev, p_now);
END
$function$;

CREATE OR REPLACE FUNCTION public.kan995_lifecycle_worker(p_now timestamptz DEFAULT now())
  RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
DECLARE
  r record; l public.event_lifecycle; v_args jsonb;
  n_req int := 0; n_rem int := 0; n_closed int := 0;
BEGIN
  IF NOT pg_try_advisory_xact_lock(hashtext('kan995_lifecycle_worker')) THEN
    RETURN jsonb_build_object('skipped', 'locked');
  END IF;

  FOR r IN
    SELECT e.id, e.event_type, e.creator_user_id, e.schedule_revision,
           public.kan995_scheduled_end(e.start_at, e.end_at) AS sched_end
      FROM public.events e
     WHERE NOT e.is_cancelled AND e.creator_user_id IS NOT NULL
       AND public.kan995_scheduled_end(e.start_at, e.end_at) <= p_now
       AND public.kan995_scheduled_end(e.start_at, e.end_at) > p_now - interval '1 day'
       AND NOT EXISTS (SELECT 1 FROM public.event_lifecycle x
                        WHERE x.event_id = e.id AND x.state IN ('ended', 'auto_closed', 'did_not_happen'))
  LOOP
    PERFORM public.kan995_ensure(r.id);
    SELECT * INTO l FROM public.event_lifecycle WHERE event_id = r.id FOR UPDATE SKIP LOCKED;
    CONTINUE WHEN NOT FOUND;
    -- KAN-995b: the candidate list is one snapshot; the locked row is the latest commit. Re-check both: an
    -- organiser's confirm or a cancel that landed during this run wins.
    CONTINUE WHEN l.state NOT IN ('scheduled', 'started');
    CONTINUE WHEN (SELECT e.is_cancelled FROM public.events e WHERE e.id = r.id);

    -- a reschedule (KAN-976 schedule_revision) restarts the end steps from the new end
    IF l.end_revision IS DISTINCT FROM r.schedule_revision THEN
      UPDATE public.event_lifecycle
         SET end_revision = r.schedule_revision, confirm_requested_at = NULL, reminder_sent_at = NULL, updated_at = p_now
       WHERE event_id = r.id
      RETURNING * INTO l;
    END IF;

    v_args := jsonb_build_object('title_en', public.kan981_event_title(r.id, 'en'),
                                 'title_ar', public.kan981_event_title(r.id, 'ar'));

    IF l.confirm_requested_at IS NULL THEN
      PERFORM public.notify_v2(r.creator_user_id, 'activity.confirm_end', v_args, r.event_type, r.id, NULL,
                               'event_lifecycle:' || r.id,
                               'lifecycle:confirm_end:' || r.id || ':' || r.schedule_revision, 'event:' || r.id, NULL);
      UPDATE public.event_lifecycle SET confirm_requested_at = p_now, updated_at = p_now WHERE event_id = r.id;
      n_req := n_req + 1;
    ELSIF l.reminder_sent_at IS NULL THEN
      IF p_now >= greatest(r.sched_end + interval '2 hours', l.confirm_requested_at + interval '2 hours') THEN
        PERFORM public.notify_v2(r.creator_user_id, 'activity.confirm_end_reminder', v_args, r.event_type, r.id, NULL,
                                 'event_lifecycle:' || r.id,
                                 'lifecycle:confirm_end_reminder:' || r.id || ':' || r.schedule_revision,
                                 'event:' || r.id, NULL);
        UPDATE public.event_lifecycle SET reminder_sent_at = p_now, updated_at = p_now WHERE event_id = r.id;
        n_rem := n_rem + 1;
      END IF;
    ELSIF p_now >= greatest(r.sched_end + interval '4 hours', l.reminder_sent_at + interval '2 hours') THEN
      PERFORM public.kan995_transition(r.id, 'auto_closed', NULL, 'time_ended', p_now, 'time_ended');
      PERFORM public.notify_v2(r.creator_user_id, 'activity.auto_closed', v_args, r.event_type, r.id, NULL,
                               'event_lifecycle:' || r.id, 'lifecycle:auto_closed:' || r.id, 'event:' || r.id, NULL);
      n_closed := n_closed + 1;
    END IF;
  END LOOP;

  RETURN jsonb_build_object('requests', n_req, 'reminders', n_rem, 'auto_closed', n_closed);
END
$function$;

DO $post$
DECLARE w oid := 'public.kan995_lifecycle_worker(timestamptz)'::regprocedure;
        t oid := 'public.kan995_transition(uuid,text,uuid,text,timestamptz,text,timestamptz)'::regprocedure;
BEGIN
  IF (SELECT proacl::text FROM pg_proc WHERE oid = w) IS DISTINCT FROM '{postgres=X/postgres,service_role=X/postgres}'
     OR (SELECT proacl::text FROM pg_proc WHERE oid = t) IS DISTINCT FROM '{postgres=X/postgres,service_role=X/postgres}'
     OR NOT (SELECT bool_and(prosecdef AND proconfig = ARRAY['search_path=""']) FROM pg_proc WHERE oid IN (w, t))
     OR position('CONTINUE WHEN l.state NOT IN' IN pg_get_functiondef(w)) = 0
     OR position('lifecycle_closed' IN pg_get_functiondef(t)) = 0 THEN
    RAISE EXCEPTION 'kan995b post: attributes, ACLs or new checks not as intended';
  END IF;
END $post$;
