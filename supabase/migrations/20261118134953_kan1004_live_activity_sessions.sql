-- KAN-1004 [W3-B1] Live Activity sessions and sender.
--
-- * live_activity_sessions: one row per (event, user, installation). Server-only: RLS on, no policies, no client grants.
-- * live_activity_optouts:  per-installation opt-out. Server-only.
-- * live_activity_sends:    the sender outbox. One row per state_version per session. The payload never carries the
--                           ActivityKit token, a score, an ETA or a location; the token is joined at send time.
-- * Planner (live_activity_plan_event): at check-in open (start_at - 30 minutes, the KAN-994 window) one session per
--   eligible participant (public.attendance_participants: active roster player / RSVP going; waitlist, left, removed
--   and the organiser are not in it) x supported installation (fcm_tokens installation row, iOS or android, not
--   legacy) x not opted out.
-- * State builder (live_activity_build_state): reuses rpc_event_lifecycle_read (KAN-1002) for the lifecycle state
--   mapping and is_cancelled by calling it as the session's user; it is not re-derived here. It also gives loss of
--   access: event_not_found ends the session.
-- * live_activity_session_step: one higher state_version per real change (a fingerprint of state, schedule, venue,
--   check-in), never on an unchanged run. Ends the session with a reason on cancel, end, leave, removal, sign-out
--   (installation unregistered), opt-out and loss of access.
-- * Sender (live_activity_send): STUB. The send needs Live Activity credentials that do not exist (see the function).
--   It records the payload and marks the row 'unsent: no credentials'. It is separate from the W1-B1 push
--   (notification_push_dispatch / send-push-notification) and never calls notify_v2: the 30m reminder stays a normal
--   notification and there is no extra starting-soon push.
-- * live_activity_record_result: provider outcome; token_rejected -> stale, gone -> ended 'provider_rejected'.
-- * Client RPCs (authenticated): rpc_live_activity_sessions, rpc_live_activity_register, rpc_live_activity_opt_out.
-- * Cron: live_activity_sweep every minute; each event and each session in its own BEGIN..EXCEPTION, failures counted.

-- 0. Pre-image guard ------------------------------------------------------------------------------------------------
DO $guard$
BEGIN
  IF to_regclass('public.live_activity_sessions') IS NOT NULL OR to_regclass('public.live_activity_sends') IS NOT NULL
     OR to_regclass('public.live_activity_optouts') IS NOT NULL THEN
    RAISE EXCEPTION 'kan1004 guard: live_activity tables already exist';
  END IF;
  IF md5(pg_get_functiondef('public.rpc_event_lifecycle_read(uuid)'::regprocedure)) <> 'bbc40d399aa83982cfa44d1c2debd9d9' THEN
    RAISE EXCEPTION 'kan1004 guard: rpc_event_lifecycle_read changed since 20261118124211';
  END IF;
  IF md5(pg_get_functiondef('public.attendance_participants(uuid)'::regprocedure)) <> '3cec271333042fcd2e564bbb50b23afe' THEN
    RAISE EXCEPTION 'kan1004 guard: attendance_participants changed';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'fcm_tokens'
                  AND column_name = 'device_platform') THEN
    RAISE EXCEPTION 'kan1004 guard: fcm_tokens.device_platform missing (KAN-977)';
  END IF;
  IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'kan1004_live_activity_every_minute') THEN
    RAISE EXCEPTION 'kan1004 guard: cron job already exists';
  END IF;
END
$guard$;

-- 1. Tables ---------------------------------------------------------------------------------------------------------
CREATE TABLE public.live_activity_sessions (
  id                      uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id                uuid NOT NULL REFERENCES public.events(id) ON DELETE CASCADE,
  user_id                 uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  installation_id         text NOT NULL CHECK (char_length(installation_id) BETWEEN 1 AND 128),
  platform                text NOT NULL CHECK (platform IN ('iOS', 'android')),
  provider                text NOT NULL CHECK (provider IN ('fcm_apns_live_activity', 'fcm_android_data')),
  activity_id             text CHECK (activity_id IS NULL OR char_length(activity_id) <= 256),
  push_token              text CHECK (push_token IS NULL OR char_length(push_token) <= 4096),
  push_token_updated_at   timestamptz,
  android_notification_id integer,
  status                  text NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'stale', 'ended')),
  last_state              text,
  last_state_version      integer NOT NULL DEFAULT 0,
  last_fingerprint        text,
  last_basis              jsonb,
  last_updated_at         timestamptz,
  stale_at                timestamptz,
  ended_at                timestamptz,
  end_reason              text CHECK (end_reason IS NULL OR end_reason IN ('cancelled', 'event_ended',
                            'scheduled_time_ended', 'left', 'removed', 'signed_out', 'opted_out', 'access_lost',
                            'provider_rejected')),
  created_at              timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT live_activity_sessions_key UNIQUE (event_id, user_id, installation_id),
  CONSTRAINT live_activity_sessions_end_check CHECK ((status = 'ended') = (ended_at IS NOT NULL AND end_reason IS NOT NULL)),
  CONSTRAINT live_activity_sessions_token_platform CHECK (push_token IS NULL OR platform = 'iOS'),
  CONSTRAINT live_activity_sessions_android_id_platform CHECK (android_notification_id IS NULL OR platform = 'android')
);
CREATE INDEX live_activity_sessions_open_idx ON public.live_activity_sessions (event_id) WHERE status <> 'ended';
CREATE INDEX live_activity_sessions_user_idx ON public.live_activity_sessions (user_id, installation_id);

CREATE TABLE public.live_activity_optouts (
  user_id         uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  installation_id text NOT NULL CHECK (char_length(installation_id) BETWEEN 1 AND 128),
  opted_out_at    timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, installation_id)
);

CREATE TABLE public.live_activity_sends (
  id            bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  session_id    uuid NOT NULL REFERENCES public.live_activity_sessions(id) ON DELETE CASCADE,
  state_version integer NOT NULL,
  la_event      text NOT NULL CHECK (la_event IN ('start', 'update', 'end')),
  state         text NOT NULL,
  payload       jsonb NOT NULL,
  status        text NOT NULL DEFAULT 'queued' CHECK (status IN ('queued', 'unsent: no credentials', 'unsent: no token',
                  'unsent: stale', 'sent', 'token_rejected', 'gone', 'failed')),
  error_class   text,
  created_at    timestamptz NOT NULL DEFAULT now(),
  result_at     timestamptz,
  CONSTRAINT live_activity_sends_version_key UNIQUE (session_id, state_version)
);

ALTER TABLE public.live_activity_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.live_activity_optouts  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.live_activity_sends    ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.live_activity_sessions, public.live_activity_optouts, public.live_activity_sends
  FROM PUBLIC, anon, authenticated;
GRANT ALL ON TABLE public.live_activity_sessions, public.live_activity_optouts, public.live_activity_sends TO service_role;

COMMENT ON TABLE public.live_activity_sessions IS
  'KAN-1004: one Live Activity per event x user x installation. Server-only (tokens). Clients use rpc_live_activity_*.';
COMMENT ON COLUMN public.live_activity_sessions.last_basis IS
  'KAN-1004: internal change basis (start/end/venue id). Never sent to a device.';

-- 2. Lifecycle read as the user (reuses KAN-1002, does not re-derive the mapping) ----------------------------------
CREATE FUNCTION public.live_activity_lifecycle_as(p_event_id uuid, p_user_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_claims text := current_setting('request.jwt.claims', true);
        v_sub text := current_setting('request.jwt.claim.sub', true);
        v jsonb;
BEGIN
  PERFORM set_config('request.jwt.claims', json_build_object('sub', p_user_id, 'role', 'authenticated')::text, true);
  PERFORM set_config('request.jwt.claim.sub', p_user_id::text, true);
  BEGIN
    v := public.rpc_event_lifecycle_read(p_event_id);
  EXCEPTION WHEN OTHERS THEN
    PERFORM set_config('request.jwt.claims', coalesce(v_claims, ''), true);
    PERFORM set_config('request.jwt.claim.sub', coalesce(v_sub, ''), true);
    RAISE;
  END;
  PERFORM set_config('request.jwt.claims', coalesce(v_claims, ''), true);
  PERFORM set_config('request.jwt.claim.sub', coalesce(v_sub, ''), true);
  RETURN v;
END;
$function$;

-- 3. State builder --------------------------------------------------------------------------------------------------
-- Returns {state, final, content, basis}. content is what the device sees: no score, ETA or location.
CREATE FUNCTION public.live_activity_build_state(p_event_id uuid, p_user_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE l jsonb; v_state text; v_checked boolean; ev record;
BEGIN
  l := public.live_activity_lifecycle_as(p_event_id, p_user_id);
  SELECT e.title, e.start_at, e.end_at, e.venue_id INTO ev FROM public.events e WHERE e.id = p_event_id;
  v_checked := EXISTS (SELECT 1 FROM public.event_attendance a WHERE a.event_id = p_event_id AND a.user_id = p_user_id
                         AND a.checked_in_at IS NOT NULL);
  v_state := CASE
    WHEN (l->>'is_cancelled')::boolean THEN 'cancelled'
    WHEN l->>'state' = 'auto_closed' THEN 'scheduled_time_ended'
    WHEN l->>'state' IN ('confirmed', 'did_not_happen') THEN 'ended'
    WHEN l->>'state' = 'started' THEN 'started'
    WHEN now() >= (l->>'start_at')::timestamptz THEN 'scheduled_time_running'   -- scheduled / awaiting_confirmation
    WHEN v_checked THEN 'checked_in'
    ELSE 'checkin_open' END;
  RETURN jsonb_build_object(
    'state', v_state,
    'final', v_state IN ('cancelled', 'ended', 'scheduled_time_ended'),
    'content', jsonb_build_object(
      'state', v_state, 'event_id', p_event_id, 'event_type', l->>'event_type', 'title', ev.title,
      'start_at', l->'start_at', 'end_at', l->'end_at', 'scheduled_end_at', l->'scheduled_end_at',
      'actual_started_at', l->'actual_started_at', 'checked_in', v_checked),
    'basis', jsonb_build_object('start_at', ev.start_at, 'end_at', ev.end_at, 'venue_id', ev.venue_id));
END;
$function$;

-- 4. Sender (stub) --------------------------------------------------------------------------------------------------
-- MISSING to send for real, nothing invented here:
--   iOS:     FCM HTTP v1 'apns.live_activity_token' needs a token-based APNs auth key (.p8) uploaded to Firebase
--            project dabblersportapp (Live Activities refuse certificate auth), and a sender edge function that reads
--            FIREBASE_SERVICE_ACCOUNT. Not confirmed present; no Live Activity sender function exists.
--   Android: an FCM data message would use the existing FIREBASE_SERVICE_ACCOUNT; it waits for the same sender function.
-- When the sender function exists, this becomes a net.http_post to it (vault push_trigger_secret, as W1-B1 does).
CREATE FUNCTION public.live_activity_send(p_send_id bigint)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE s record;
BEGIN
  SELECT x.id, ss.status, ss.platform, ss.push_token INTO s
    FROM public.live_activity_sends x JOIN public.live_activity_sessions ss ON ss.id = x.session_id
   WHERE x.id = p_send_id AND x.status = 'queued' FOR UPDATE OF x;
  IF s.id IS NULL THEN RETURN false; END IF;
  UPDATE public.live_activity_sends SET status = 'unsent: no credentials', result_at = now() WHERE id = p_send_id;
  RETURN false;
END;
$function$;

-- 5. One send per real change ---------------------------------------------------------------------------------------
CREATE FUNCTION public.live_activity_enqueue(p_session_id uuid, p_la_event text, p_state text, p_content jsonb)
 RETURNS bigint
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE s public.live_activity_sessions%ROWTYPE; v_ver int; v_payload jsonb; v_id bigint; v_c jsonb;
BEGIN
  SELECT * INTO s FROM public.live_activity_sessions WHERE id = p_session_id FOR UPDATE;
  v_ver := s.last_state_version + 1;
  v_c := p_content || jsonb_build_object('state_version', v_ver);
  v_payload := CASE s.platform
    WHEN 'iOS' THEN jsonb_build_object('apns', jsonb_build_object(
        'headers', jsonb_build_object('apns-push-type', 'liveactivity', 'apns-priority', '10'),
        'payload', jsonb_build_object('aps', jsonb_strip_nulls(jsonb_build_object(
          'timestamp', floor(extract(epoch FROM now()))::bigint,
          'event', p_la_event,
          'content-state', v_c,
          'dismissal-date', CASE WHEN p_la_event = 'end' THEN floor(extract(epoch FROM now() + interval '1 hour'))::bigint END)))))
    ELSE jsonb_build_object('android', jsonb_build_object('priority', 'high'),
        'data', jsonb_build_object('type', 'live_activity', 'la_event', p_la_event, 'session_id', s.id::text,
          'state_version', v_ver::text, 'content', v_c::text)) END;
  INSERT INTO public.live_activity_sends (session_id, state_version, la_event, state, payload,
                                         status)
  VALUES (s.id, v_ver, p_la_event, p_state, v_payload,
          CASE WHEN s.status = 'stale' THEN 'unsent: stale' ELSE 'queued' END)
  RETURNING id INTO v_id;
  UPDATE public.live_activity_sessions SET last_state_version = v_ver, last_state = p_state, last_updated_at = now()
   WHERE id = s.id;
  PERFORM public.live_activity_send(v_id);
  RETURN v_id;
END;
$function$;

CREATE FUNCTION public.live_activity_end(p_session_id uuid, p_reason text, p_content jsonb DEFAULT NULL)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE s public.live_activity_sessions%ROWTYPE;
BEGIN
  SELECT * INTO s FROM public.live_activity_sessions WHERE id = p_session_id FOR UPDATE;
  IF s.id IS NULL OR s.status = 'ended' THEN RETURN; END IF;
  PERFORM public.live_activity_enqueue(s.id, 'end', coalesce(p_content->>'state', 'ended'),
            coalesce(p_content, jsonb_build_object('state', 'ended', 'event_id', s.event_id))
            || jsonb_build_object('end_reason', p_reason));
  UPDATE public.live_activity_sessions SET status = 'ended', ended_at = now(), end_reason = p_reason WHERE id = s.id;
END;
$function$;

-- 6. Planner --------------------------------------------------------------------------------------------------------
CREATE FUNCTION public.live_activity_plan_event(p_event_id uuid)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE ev record; v_n int := 0; v_k int; u uuid; b jsonb;
BEGIN
  SELECT e.id, e.start_at, coalesce(e.is_cancelled, false) c INTO ev FROM public.events e WHERE e.id = p_event_id;
  IF ev.id IS NULL OR ev.c OR now() < ev.start_at - interval '30 minutes' THEN RETURN 0; END IF;
  FOR u IN SELECT p FROM public.attendance_participants(p_event_id) p LOOP
    b := public.live_activity_build_state(p_event_id, u);
    CONTINUE WHEN (b->>'final')::boolean;
    INSERT INTO public.live_activity_sessions (event_id, user_id, installation_id, platform, provider)
    SELECT p_event_id, u, f.installation_id, f.device_platform,
           CASE f.device_platform WHEN 'iOS' THEN 'fcm_apns_live_activity' ELSE 'fcm_android_data' END
      FROM public.fcm_tokens f
     WHERE f.user_id = u AND f.device_platform IN ('iOS', 'android') AND f.installation_id NOT LIKE 'legacy:%'
       AND NOT EXISTS (SELECT 1 FROM public.live_activity_optouts o WHERE o.user_id = u AND o.installation_id = f.installation_id)
    ON CONFLICT (event_id, user_id, installation_id) DO NOTHING;
    GET DIAGNOSTICS v_k = ROW_COUNT;
    v_n := v_n + v_k;
  END LOOP;
  RETURN v_n;
END;
$function$;

-- 7. Session step: end with reason, or one higher version per real change ------------------------------------------
-- Returns 'ended:<reason>', 'sent', 'unchanged' or 'skipped'.
CREATE FUNCTION public.live_activity_session_step(p_session_id uuid)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE s public.live_activity_sessions%ROWTYPE; b jsonb; v_reason text; v_fp text; v_change text; v_type text;
BEGIN
  SELECT * INTO s FROM public.live_activity_sessions WHERE id = p_session_id FOR UPDATE SKIP LOCKED;
  IF s.id IS NULL OR s.status = 'ended' THEN RETURN 'skipped'; END IF;

  IF NOT EXISTS (SELECT 1 FROM public.fcm_tokens f WHERE f.user_id = s.user_id AND f.installation_id = s.installation_id) THEN
    v_reason := 'signed_out';
  ELSIF EXISTS (SELECT 1 FROM public.live_activity_optouts o WHERE o.user_id = s.user_id AND o.installation_id = s.installation_id) THEN
    v_reason := 'opted_out';
  ELSIF NOT EXISTS (SELECT 1 FROM public.attendance_participants(s.event_id) p WHERE p = s.user_id) THEN
    SELECT e.event_type INTO v_type FROM public.events e WHERE e.id = s.event_id;
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
  PERFORM public.live_activity_enqueue(s.id, CASE WHEN s.last_state_version = 0 THEN 'start' ELSE 'update' END,
            b->>'state', (b->'content') || jsonb_build_object('change', v_change));
  RETURN 'sent';
END;
$function$;

-- 8. Sweep ----------------------------------------------------------------------------------------------------------
CREATE FUNCTION public.live_activity_sweep()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_e uuid; v_s uuid; v_r text; v_planned int := 0; v_sent int := 0; v_ended int := 0; v_same int := 0;
        v_fail int := 0;
BEGIN
  FOR v_e IN SELECT e.id FROM public.events e
              WHERE e.event_type IN ('game', 'meetup') AND NOT coalesce(e.is_cancelled, false)
                AND e.start_at >= timestamptz '2026-11-18 13:30:00+00'
                AND e.start_at - interval '30 minutes' <= now()
                AND e.start_at > now() - interval '1 day' LOOP
    BEGIN
      v_planned := v_planned + public.live_activity_plan_event(v_e);
    EXCEPTION WHEN OTHERS THEN
      v_fail := v_fail + 1;
      RAISE WARNING 'live_activity_sweep: plan failed for event %: % %', v_e, SQLSTATE, SQLERRM;
    END;
  END LOOP;
  FOR v_s IN SELECT s.id FROM public.live_activity_sessions s WHERE s.status <> 'ended' LOOP
    BEGIN
      v_r := public.live_activity_session_step(v_s);
      IF v_r = 'sent' THEN v_sent := v_sent + 1;
      ELSIF v_r LIKE 'ended:%' THEN v_ended := v_ended + 1;
      ELSIF v_r = 'unchanged' THEN v_same := v_same + 1;
      END IF;
    EXCEPTION WHEN OTHERS THEN
      v_fail := v_fail + 1;
      RAISE WARNING 'live_activity_sweep: step failed for session %: % %', v_s, SQLSTATE, SQLERRM;
    END;
  END LOOP;
  RETURN jsonb_build_object('planned', v_planned, 'sent', v_sent, 'ended', v_ended, 'unchanged', v_same,
                            'failed', v_fail);
END;
$function$;

-- 9. Provider result ------------------------------------------------------------------------------------------------
CREATE FUNCTION public.live_activity_record_result(p_send_id bigint, p_outcome text, p_error_class text DEFAULT NULL)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_session uuid;
BEGIN
  IF p_outcome NOT IN ('sent', 'token_rejected', 'gone', 'failed') THEN
    RAISE EXCEPTION USING errcode = '22023', message = 'invalid_outcome';
  END IF;
  UPDATE public.live_activity_sends SET status = p_outcome, error_class = p_error_class, result_at = now()
   WHERE id = p_send_id RETURNING session_id INTO v_session;
  IF v_session IS NULL THEN RAISE EXCEPTION USING errcode = 'P0002', message = 'send_not_found'; END IF;
  IF p_outcome = 'token_rejected' THEN
    UPDATE public.live_activity_sessions SET status = 'stale', stale_at = now()
     WHERE id = v_session AND status = 'active';
  ELSIF p_outcome = 'gone' THEN
    UPDATE public.live_activity_sessions SET status = 'ended', ended_at = now(), end_reason = 'provider_rejected'
     WHERE id = v_session AND status <> 'ended';
  END IF;
END;
$function$;

-- 10. Client RPCs ---------------------------------------------------------------------------------------------------
-- The caller's open sessions on this installation, with the latest content and version. Never a token.
CREATE FUNCTION public.rpc_live_activity_sessions(p_installation_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_uid uuid := auth.uid();
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION USING errcode = '42501', message = 'not_authenticated'; END IF;
  RETURN coalesce((
    SELECT jsonb_agg(jsonb_build_object(
             'session_id', s.id, 'event_id', s.event_id, 'platform', s.platform, 'status', s.status,
             'state', s.last_state, 'state_version', s.last_state_version, 'activity_id', s.activity_id,
             'has_push_token', s.push_token IS NOT NULL,
             'content', (SELECT x.payload FROM public.live_activity_sends x WHERE x.session_id = s.id
                          ORDER BY x.state_version DESC LIMIT 1)) ORDER BY s.created_at)
      FROM public.live_activity_sessions s
     WHERE s.user_id = v_uid AND s.installation_id = p_installation_id AND s.status <> 'ended'), '[]'::jsonb);
END;
$function$;

-- Register the ActivityKit push token (iOS) or the Android notification id for a session the server planned.
-- Calling again with a new token replaces the old one (rotation) and revives a stale session.
CREATE FUNCTION public.rpc_live_activity_register(p_session_id uuid, p_activity_id text DEFAULT NULL,
                                                  p_push_token text DEFAULT NULL,
                                                  p_android_notification_id integer DEFAULT NULL)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_uid uuid := auth.uid(); s public.live_activity_sessions%ROWTYPE;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION USING errcode = '42501', message = 'not_authenticated'; END IF;
  SELECT * INTO s FROM public.live_activity_sessions WHERE id = p_session_id AND user_id = v_uid FOR UPDATE;
  IF s.id IS NULL THEN RAISE EXCEPTION USING errcode = 'P0002', message = 'session_not_found'; END IF;
  IF s.status = 'ended' THEN RAISE EXCEPTION USING errcode = '55000', message = 'session_ended'; END IF;
  IF p_push_token IS NOT NULL AND (s.platform <> 'iOS' OR btrim(p_push_token) = '' OR char_length(p_push_token) > 4096) THEN
    RAISE EXCEPTION USING errcode = '22023', message = 'invalid_push_token';
  END IF;
  IF p_android_notification_id IS NOT NULL AND s.platform <> 'android' THEN
    RAISE EXCEPTION USING errcode = '22023', message = 'invalid_android_notification_id';
  END IF;
  IF p_activity_id IS NOT NULL AND char_length(p_activity_id) > 256 THEN
    RAISE EXCEPTION USING errcode = '22023', message = 'invalid_activity_id';
  END IF;
  UPDATE public.live_activity_sessions SET
         activity_id = coalesce(p_activity_id, activity_id),
         push_token = coalesce(p_push_token, push_token),
         push_token_updated_at = CASE WHEN p_push_token IS DISTINCT FROM push_token AND p_push_token IS NOT NULL
                                      THEN now() ELSE push_token_updated_at END,
         android_notification_id = coalesce(p_android_notification_id, android_notification_id),
         status = CASE WHEN status = 'stale' AND p_push_token IS NOT NULL AND p_push_token IS DISTINCT FROM push_token
                       THEN 'active' ELSE status END,
         stale_at = CASE WHEN status = 'stale' AND p_push_token IS NOT NULL AND p_push_token IS DISTINCT FROM push_token
                         THEN NULL ELSE stale_at END
   WHERE id = s.id RETURNING * INTO s;
  RETURN jsonb_build_object('session_id', s.id, 'status', s.status, 'state', s.last_state,
                            'state_version', s.last_state_version);
END;
$function$;

-- Opt this installation out (ends its open sessions, reason opted_out) or back in.
CREATE FUNCTION public.rpc_live_activity_opt_out(p_installation_id text, p_opted_out boolean DEFAULT true)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_uid uuid := auth.uid(); v_s uuid; v_n int := 0;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION USING errcode = '42501', message = 'not_authenticated'; END IF;
  IF p_installation_id IS NULL OR btrim(p_installation_id) = '' OR char_length(p_installation_id) > 128 THEN
    RAISE EXCEPTION USING errcode = '22023', message = 'invalid_installation_id';
  END IF;
  IF NOT coalesce(p_opted_out, true) THEN
    DELETE FROM public.live_activity_optouts WHERE user_id = v_uid AND installation_id = p_installation_id;
    RETURN 0;
  END IF;
  INSERT INTO public.live_activity_optouts (user_id, installation_id) VALUES (v_uid, p_installation_id)
  ON CONFLICT DO NOTHING;
  FOR v_s IN SELECT id FROM public.live_activity_sessions
              WHERE user_id = v_uid AND installation_id = p_installation_id AND status <> 'ended' LOOP
    PERFORM public.live_activity_end(v_s, 'opted_out');
    v_n := v_n + 1;
  END LOOP;
  RETURN v_n;
END;
$function$;

-- 11. Grants --------------------------------------------------------------------------------------------------------
REVOKE ALL ON FUNCTION public.live_activity_lifecycle_as(uuid, uuid), public.live_activity_build_state(uuid, uuid),
  public.live_activity_send(bigint), public.live_activity_enqueue(uuid, text, text, jsonb),
  public.live_activity_end(uuid, text, jsonb), public.live_activity_plan_event(uuid),
  public.live_activity_session_step(uuid), public.live_activity_sweep(),
  public.live_activity_record_result(bigint, text, text)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.live_activity_lifecycle_as(uuid, uuid), public.live_activity_build_state(uuid, uuid),
  public.live_activity_send(bigint), public.live_activity_enqueue(uuid, text, text, jsonb),
  public.live_activity_end(uuid, text, jsonb), public.live_activity_plan_event(uuid),
  public.live_activity_session_step(uuid), public.live_activity_sweep(),
  public.live_activity_record_result(bigint, text, text)
  TO service_role;
REVOKE ALL ON FUNCTION public.rpc_live_activity_sessions(text), public.rpc_live_activity_register(uuid, text, text, integer),
  public.rpc_live_activity_opt_out(text, boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rpc_live_activity_sessions(text), public.rpc_live_activity_register(uuid, text, text, integer),
  public.rpc_live_activity_opt_out(text, boolean) TO authenticated;

-- 12. Cron ----------------------------------------------------------------------------------------------------------
SELECT cron.schedule('kan1004_live_activity_every_minute', '* * * * *', 'SELECT public.live_activity_sweep()');

-- 13. Post-image ----------------------------------------------------------------------------------------------------
DO $post$
DECLARE r record;
BEGIN
  FOR r IN SELECT p.oid::regprocedure f, p.proname, (SELECT array_agg(x ORDER BY x) FROM unnest(p.proacl::text[]) x)::text a,
                  p.prosecdef s, p.proconfig c
             FROM pg_proc p WHERE p.pronamespace = 'public'::regnamespace
              AND (p.proname LIKE 'live_activity\_%' OR p.proname LIKE 'rpc_live_activity\_%') LOOP
    IF NOT r.s OR r.c IS DISTINCT FROM ARRAY['search_path=public, pg_temp'] THEN
      RAISE EXCEPTION 'kan1004 post-image: % attributes % %', r.f, r.s, r.c;
    END IF;
    IF r.proname LIKE 'rpc_%' AND r.a <> '{authenticated=X/postgres,postgres=X/postgres,service_role=X/postgres}' THEN
      RAISE EXCEPTION 'kan1004 post-image: % acl %', r.f, r.a;
    ELSIF r.proname NOT LIKE 'rpc_%' AND r.a <> '{postgres=X/postgres,service_role=X/postgres}' THEN
      RAISE EXCEPTION 'kan1004 post-image: % acl %', r.f, r.a;
    END IF;
  END LOOP;
  IF EXISTS (SELECT 1 FROM information_schema.role_table_grants WHERE table_schema = 'public'
              AND table_name LIKE 'live_activity\_%' AND grantee IN ('anon', 'authenticated', 'PUBLIC')) THEN
    RAISE EXCEPTION 'kan1004 post-image: client grant on a live_activity table';
  END IF;
END
$post$;
