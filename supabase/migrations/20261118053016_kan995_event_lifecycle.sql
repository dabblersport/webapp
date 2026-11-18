-- KAN-995 [W2-B2] Lifecycle (Epic KAN-973; plan W2-B2; F-9; G.9 LIVE-04 / LIVE-06 / END-02, END-05, END-06, END-08).
-- Decisions (coordinator, 2026-11-17): own one-minute cron worker (not the KAN-983 queue, whose job_type/rung checks
-- only allow reminders); a meetup with no end_at ends at start + 2h; the reminder 2h after the end, the auto-close 2h
-- after the reminder (4h after the end); the kinds stay breaks_quiet = false; activity.confirm_end,
-- activity.confirm_end_reminder and activity.auto_closed go to the organiser, activity.ended to the participants when
-- the organiser confirms "played", nothing for "did not happen"; KAN-994 reads only event_lifecycle_state().
--
-- 1. public.event_lifecycle: one row per event, created on first use (Start, Confirm end, or the worker at the end).
--    state scheduled -> started -> ended | auto_closed | did_not_happen (the last three are closed, final).
--    Cancellation stays on events.is_cancelled; a cancelled event gets no lifecycle step.
--    end_revision is the events.schedule_revision the request/reminder markers belong to: a reschedule (new
--    revision, KAN-976) resets them, so the request, the reminder and the auto-close follow the new end.
-- 2. public.event_lifecycle_transitions: audit of every transition (from, to, actor, reason, time).
-- 3. RPCs for the organiser (events.creator_user_id) or an admin, authenticated:
--      rpc_event_start(p_event_id)                   at or after the scheduled start; repeat = idempotent
--      rpc_event_confirm_end(p_event_id, p_outcome)  'played' | 'did_not_happen'; repeat with the same outcome =
--                                                    idempotent; a closed event is not reopened
--    Both refuse a cancelled event and anyone else.
-- 4. kan995_lifecycle_worker(p_now): cron every minute. For each non-cancelled event whose scheduled end
--    (coalesce(end_at, start_at + 2h)) passed in the last day and is not closed:
--      at the end                                        -> activity.confirm_end to the organiser (once)
--      max(end + 2h, request + 2h)                       -> activity.confirm_end_reminder (once)
--      max(end + 4h, reminder + 2h), still unconfirmed   -> state auto_closed ("scheduled time ended"),
--                                                           activity.auto_closed to the organiser
--    The max() spaces the steps if the worker was down. Each send has a dedupe key with the revision.
-- 5. event_lifecycle_state(p_event_id) -> (state, effective_end_at, scheduled_end_at, actual_started_at,
--    actual_ended_at, closed_at, closed_reason). Server-only (service_role); the KAN-994 contract. No row ->
--    'scheduled'. effective_end_at = actual_ended_at, else the scheduled end.
-- 6. Seed: the 2 non-cancelled events whose scheduled end passed in the last day before this migration get a closed
--    row (auto_closed, closed_reason 'pre_lifecycle', no notice), so the first worker run does not ask their
--    organisers about events that ended before lifecycle existed.
-- No trigger on events. No attendance is decided here (KAN-994 owns event_attendance).
-- Pre-image guard: none of the new objects exist; the 4 kinds exist and are inactive; the helpers exist.
-- Live test: supabase/tests/notifications_v2/kan995_event_lifecycle.sql.

-- 0. pre-image guard ---------------------------------------------------------------------------------------------------
DO $pre$
BEGIN
  IF to_regclass('public.event_lifecycle') IS NOT NULL OR to_regclass('public.event_lifecycle_transitions') IS NOT NULL
     OR to_regprocedure('public.event_lifecycle_state(uuid)') IS NOT NULL
     OR to_regprocedure('public.rpc_event_start(uuid)') IS NOT NULL
     OR to_regprocedure('public.rpc_event_confirm_end(uuid,text)') IS NOT NULL
     OR to_regprocedure('public.kan995_lifecycle_worker(timestamptz)') IS NOT NULL
     OR EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'kan995_lifecycle_every_minute') THEN
    RAISE EXCEPTION 'kan995 pre: a KAN-995 object already exists';
  END IF;
  IF (SELECT count(*) FROM public.notification_kinds
       WHERE key IN ('activity.confirm_end', 'activity.confirm_end_reminder', 'activity.auto_closed', 'activity.ended')
         AND NOT is_active AND NOT breaks_quiet) <> 4 THEN
    RAISE EXCEPTION 'kan995 pre: the 4 lifecycle kinds are not all present, inactive and breaks_quiet = false';
  END IF;
  IF to_regprocedure('public.notify_v2(uuid,text,jsonb,text,uuid,uuid,text,text,text,text)') IS NULL
     OR to_regprocedure('public.kan981_event_title(uuid,text)') IS NULL OR to_regprocedure('public.is_admin(uuid)') IS NULL THEN
    RAISE EXCEPTION 'kan995 pre: notify_v2, kan981_event_title or is_admin missing';
  END IF;
END $pre$;

-- 1. tables ------------------------------------------------------------------------------------------------------------
CREATE TABLE public.event_lifecycle (
  event_id             uuid        PRIMARY KEY REFERENCES public.events (id) ON DELETE CASCADE,
  event_type           text        NOT NULL CHECK (event_type IN ('game', 'meetup')),
  state                text        NOT NULL DEFAULT 'scheduled'
                                   CHECK (state IN ('scheduled', 'started', 'ended', 'auto_closed', 'did_not_happen')),
  actual_started_at    timestamptz,
  started_by           uuid,
  actual_ended_at      timestamptz,
  closed_at            timestamptz,
  closed_by            uuid,
  closed_reason        text        CHECK (closed_reason IN ('played', 'did_not_happen', 'time_ended', 'pre_lifecycle')),
  end_revision         integer,
  confirm_requested_at timestamptz,
  reminder_sent_at     timestamptz,
  revision             integer     NOT NULL DEFAULT 0,
  created_at           timestamptz NOT NULL DEFAULT now(),
  updated_at           timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT event_lifecycle_closed_chk
    CHECK ((state IN ('ended', 'auto_closed', 'did_not_happen')) = (closed_at IS NOT NULL AND closed_reason IS NOT NULL))
);
CREATE INDEX event_lifecycle_open_idx ON public.event_lifecycle (event_id) WHERE state IN ('scheduled', 'started');

CREATE TABLE public.event_lifecycle_transitions (
  id            bigint      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  event_id      uuid        NOT NULL REFERENCES public.events (id) ON DELETE CASCADE,
  from_state    text,
  to_state      text        NOT NULL,
  actor_user_id uuid,
  reason        text        NOT NULL,
  revision      integer     NOT NULL,
  at            timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX event_lifecycle_transitions_event_idx ON public.event_lifecycle_transitions (event_id, id);

COMMENT ON TABLE public.event_lifecycle IS
  'KAN-995: actual start/end of an event, the end confirmation and its 2h reminder, auto-close as "scheduled time '
  'ended", "did not happen". Server only; read through event_lifecycle_state() (KAN-994 contract).';
COMMENT ON TABLE public.event_lifecycle_transitions IS 'KAN-995: audit of event_lifecycle transitions with the actor.';

ALTER TABLE public.event_lifecycle ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.event_lifecycle_transitions ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.event_lifecycle, public.event_lifecycle_transitions FROM PUBLIC, anon, authenticated;
REVOKE ALL ON SEQUENCE public.event_lifecycle_transitions_id_seq FROM PUBLIC, anon, authenticated;
GRANT SELECT ON TABLE public.event_lifecycle, public.event_lifecycle_transitions TO service_role;

-- 2. helpers -----------------------------------------------------------------------------------------------------------
CREATE FUNCTION public.kan995_scheduled_end(p_start timestamptz, p_end timestamptz)
  RETURNS timestamptz LANGUAGE sql IMMUTABLE SET search_path TO ''
AS $function$ SELECT coalesce(p_end, p_start + interval '2 hours') $function$;

-- Moves a lifecycle row to a new state and audits it. The caller holds the row lock.
CREATE FUNCTION public.kan995_transition(p_event_id uuid, p_to text, p_actor uuid, p_reason text, p_now timestamptz,
                                         p_closed_reason text DEFAULT NULL, p_ended_at timestamptz DEFAULT NULL)
  RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
DECLARE v_from text; v_rev int;
BEGIN
  SELECT l.state INTO v_from FROM public.event_lifecycle l WHERE l.event_id = p_event_id;
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

CREATE FUNCTION public.kan995_ensure(p_event_id uuid)
  RETURNS void LANGUAGE sql SECURITY DEFINER SET search_path TO ''
AS $function$
  INSERT INTO public.event_lifecycle (event_id, event_type, end_revision)
  SELECT e.id, e.event_type, e.schedule_revision FROM public.events e WHERE e.id = p_event_id
  ON CONFLICT (event_id) DO NOTHING
$function$;

-- 3. the read contract (KAN-994) ---------------------------------------------------------------------------------------
CREATE FUNCTION public.event_lifecycle_state(p_event_id uuid)
  RETURNS TABLE (state text, effective_end_at timestamptz, scheduled_end_at timestamptz, actual_started_at timestamptz,
                 actual_ended_at timestamptz, closed_at timestamptz, closed_reason text)
  LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO ''
AS $function$
  SELECT coalesce(l.state, 'scheduled'),
         coalesce(l.actual_ended_at, public.kan995_scheduled_end(e.start_at, e.end_at)),
         public.kan995_scheduled_end(e.start_at, e.end_at),
         l.actual_started_at, l.actual_ended_at, l.closed_at, l.closed_reason
    FROM public.events e
    LEFT JOIN public.event_lifecycle l ON l.event_id = e.id
   WHERE e.id = p_event_id
$function$;

-- 4. organiser RPCs ----------------------------------------------------------------------------------------------------
CREATE FUNCTION public.rpc_event_start(p_event_id uuid)
  RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
DECLARE v_uid uuid := auth.uid(); e public.events; l public.event_lifecycle;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION USING errcode = 'P0001', message = 'auth_required'; END IF;
  SELECT * INTO e FROM public.events WHERE id = p_event_id;
  IF NOT FOUND THEN RAISE EXCEPTION USING errcode = 'P0001', message = 'event_not_found'; END IF;
  IF e.creator_user_id IS DISTINCT FROM v_uid AND NOT public.is_admin(v_uid) THEN
    RAISE EXCEPTION USING errcode = 'P0001', message = 'not_organiser';
  END IF;
  IF e.is_cancelled THEN RAISE EXCEPTION USING errcode = 'P0001', message = 'cancelled'; END IF;
  IF now() < e.start_at THEN RAISE EXCEPTION USING errcode = 'P0001', message = 'not_started_yet'; END IF;

  PERFORM public.kan995_ensure(p_event_id);
  SELECT * INTO l FROM public.event_lifecycle WHERE event_id = p_event_id FOR UPDATE;
  IF l.state = 'started' THEN
    RETURN jsonb_build_object('result', 'already_started', 'state', l.state, 'actual_started_at', l.actual_started_at);
  END IF;
  IF l.state <> 'scheduled' THEN RAISE EXCEPTION USING errcode = 'P0001', message = 'already_closed'; END IF;

  PERFORM public.kan995_transition(p_event_id, 'started', v_uid, 'organiser_start', now());
  SELECT * INTO l FROM public.event_lifecycle WHERE event_id = p_event_id;
  RETURN jsonb_build_object('result', 'started', 'state', l.state, 'actual_started_at', l.actual_started_at);
END
$function$;

CREATE FUNCTION public.rpc_event_confirm_end(p_event_id uuid, p_outcome text)
  RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
DECLARE
  v_uid uuid := auth.uid(); e public.events; l public.event_lifecycle; v_to text; u uuid; v_args jsonb;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION USING errcode = 'P0001', message = 'auth_required'; END IF;
  IF p_outcome IS NULL OR p_outcome NOT IN ('played', 'did_not_happen') THEN
    RAISE EXCEPTION USING errcode = 'P0001', message = 'invalid_outcome';
  END IF;
  SELECT * INTO e FROM public.events WHERE id = p_event_id;
  IF NOT FOUND THEN RAISE EXCEPTION USING errcode = 'P0001', message = 'event_not_found'; END IF;
  IF e.creator_user_id IS DISTINCT FROM v_uid AND NOT public.is_admin(v_uid) THEN
    RAISE EXCEPTION USING errcode = 'P0001', message = 'not_organiser';
  END IF;
  IF e.is_cancelled THEN RAISE EXCEPTION USING errcode = 'P0001', message = 'cancelled'; END IF;
  IF now() < e.start_at THEN RAISE EXCEPTION USING errcode = 'P0001', message = 'not_started_yet'; END IF;

  v_to := CASE p_outcome WHEN 'played' THEN 'ended' ELSE 'did_not_happen' END;
  PERFORM public.kan995_ensure(p_event_id);
  SELECT * INTO l FROM public.event_lifecycle WHERE event_id = p_event_id FOR UPDATE;
  IF l.state = v_to THEN
    RETURN jsonb_build_object('result', 'already_' || v_to, 'state', l.state, 'closed_at', l.closed_at);
  END IF;
  IF l.state NOT IN ('scheduled', 'started') THEN
    RAISE EXCEPTION USING errcode = 'P0001', message = 'already_closed';
  END IF;

  PERFORM public.kan995_transition(p_event_id, v_to, v_uid, 'organiser_' || p_outcome, now(), p_outcome,
                                   CASE WHEN v_to = 'ended' THEN now() END);

  -- "played": the participants get activity.ended. "did not happen": nobody is told.
  IF v_to = 'ended' THEN
    v_args := jsonb_build_object('title_en', public.kan981_event_title(e.id, 'en'),
                                 'title_ar', public.kan981_event_title(e.id, 'ar'));
    FOR u IN
      SELECT r.user_id FROM public.game_roster r
       WHERE e.event_type = 'game' AND r.game_id = e.id AND r.status = 'active'
         AND r.user_id IS NOT NULL AND r.user_id <> e.creator_user_id
      UNION
      SELECT s.user_id FROM public.meetup_rsvps s
       WHERE e.event_type = 'meetup' AND s.meetup_id = e.id AND s.status = 'going'
         AND s.user_id IS NOT NULL AND s.user_id <> e.creator_user_id
    LOOP
      PERFORM public.notify_v2(u, 'activity.ended', v_args, e.event_type, e.id, v_uid, 'event_lifecycle:' || e.id,
                               'lifecycle:ended:' || e.id, 'event:' || e.id, NULL);
    END LOOP;
  END IF;

  SELECT * INTO l FROM public.event_lifecycle WHERE event_id = p_event_id;
  RETURN jsonb_build_object('result', v_to, 'state', l.state, 'closed_at', l.closed_at);
END
$function$;

-- 5. the worker --------------------------------------------------------------------------------------------------------
CREATE FUNCTION public.kan995_lifecycle_worker(p_now timestamptz DEFAULT now())
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

-- 6. kinds -------------------------------------------------------------------------------------------------------------
UPDATE public.notification_kinds SET is_active = true
 WHERE key IN ('activity.confirm_end', 'activity.confirm_end_reminder', 'activity.auto_closed', 'activity.ended');

-- 7. grants ------------------------------------------------------------------------------------------------------------
REVOKE ALL ON FUNCTION public.kan995_scheduled_end(timestamptz, timestamptz) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.kan995_transition(uuid, text, uuid, text, timestamptz, text, timestamptz) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.kan995_ensure(uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.event_lifecycle_state(uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.kan995_lifecycle_worker(timestamptz) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.rpc_event_start(uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.rpc_event_confirm_end(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.event_lifecycle_state(uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.kan995_lifecycle_worker(timestamptz) TO service_role;
GRANT EXECUTE ON FUNCTION public.rpc_event_start(uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.rpc_event_confirm_end(uuid, text) TO authenticated, service_role;

-- 8. seed: events that ended in the last day before lifecycle existed are closed quietly --------------------------------
INSERT INTO public.event_lifecycle (event_id, event_type, state, closed_at, closed_reason, end_revision)
SELECT e.id, e.event_type, 'auto_closed', now(), 'pre_lifecycle', e.schedule_revision
  FROM public.events e
 WHERE NOT e.is_cancelled
   AND public.kan995_scheduled_end(e.start_at, e.end_at) <= now()
   AND public.kan995_scheduled_end(e.start_at, e.end_at) > now() - interval '1 day';

SELECT cron.schedule('kan995_lifecycle_every_minute', '* * * * *', $cron$SELECT public.kan995_lifecycle_worker()$cron$);

-- 9. post asserts ------------------------------------------------------------------------------------------------------
DO $post$
DECLARE t text; f text;
BEGIN
  FOREACH t IN ARRAY ARRAY['public.event_lifecycle', 'public.event_lifecycle_transitions'] LOOP
    IF NOT (SELECT relrowsecurity FROM pg_class WHERE oid = t::regclass)
       OR EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = t::regclass)
       OR has_table_privilege('anon', t, 'SELECT') OR has_table_privilege('authenticated', t, 'SELECT')
       OR has_table_privilege('authenticated', t, 'INSERT') OR has_table_privilege('authenticated', t, 'UPDATE') THEN
      RAISE EXCEPTION 'kan995 post: % is not server-only', t;
    END IF;
  END LOOP;
  IF has_sequence_privilege('authenticated', 'public.event_lifecycle_transitions_id_seq', 'USAGE')
     OR has_sequence_privilege('anon', 'public.event_lifecycle_transitions_id_seq', 'USAGE') THEN
    RAISE EXCEPTION 'kan995 post: the audit sequence is open to clients';
  END IF;
  FOREACH f IN ARRAY ARRAY['public.event_lifecycle_state(uuid)', 'public.kan995_lifecycle_worker(timestamptz)',
                           'public.kan995_transition(uuid,text,uuid,text,timestamptz,text,timestamptz)',
                           'public.kan995_ensure(uuid)'] LOOP
    IF has_function_privilege('authenticated', f, 'EXECUTE') OR has_function_privilege('anon', f, 'EXECUTE') THEN
      RAISE EXCEPTION 'kan995 post: % is executable by a client', f;
    END IF;
  END LOOP;
  IF NOT has_function_privilege('authenticated', 'public.rpc_event_start(uuid)', 'EXECUTE')
     OR has_function_privilege('anon', 'public.rpc_event_start(uuid)', 'EXECUTE')
     OR NOT has_function_privilege('authenticated', 'public.rpc_event_confirm_end(uuid,text)', 'EXECUTE')
     OR has_function_privilege('anon', 'public.rpc_event_confirm_end(uuid,text)', 'EXECUTE') THEN
    RAISE EXCEPTION 'kan995 post: RPC grants not as intended';
  END IF;
  IF (SELECT count(*) FROM public.notification_kinds
       WHERE key IN ('activity.confirm_end', 'activity.confirm_end_reminder', 'activity.auto_closed', 'activity.ended')
         AND is_active AND NOT breaks_quiet) <> 4
     OR NOT EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'kan995_lifecycle_every_minute' AND active) THEN
    RAISE EXCEPTION 'kan995 post: kinds or cron job not as intended';
  END IF;
END $post$;
