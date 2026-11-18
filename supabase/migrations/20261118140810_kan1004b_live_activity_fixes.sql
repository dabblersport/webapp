-- KAN-1004b: Live Activity backend after PEER review.
--
-- 1. Cost bound: the planner only reads lifecycle state for users who have an installation without a live session
--    (or with a revivable ended one); the sweep caps events (live_activity.event_limit, default 200) and sessions
--    (live_activity.session_limit, default 500) per run and skips events more than 6h past their scheduled end
--    (coalesce(end_at, start_at) + 6h); a session is stepped only when due_at <= now(). due_at is set to now() by
--    triggers on events, event_lifecycle, event_attendance, game_roster, meetup_rsvps and fcm_tokens, and after each
--    step to the next time instant (start_at, scheduled_end_at) capped at now() + 10 minutes.
-- 2. live_activity_plan_event: each user in its own BEGIN..EXCEPTION; failures are counted in the transaction-local
--    setting live_activity.plan_failures, which the sweep adds to 'failed'.
-- 3. Revival: a session ended opted_out / left / removed / signed_out is revived in place (status planned, tokens
--    cleared, next step sends a start with a new, higher state_version) when the user is eligible again and the
--    event is not final.
-- 4. The organiser (events.creator_user_id) gets a Live Activity too, state from rpc_event_lifecycle_read as them,
--    plus role = 'organiser' and organiser_action ('start' | 'confirm_end' | absent).
-- 5. iOS push-to-start (17.2+): per-installation token in live_activity_push_to_start (server-only), registered by
--    rpc_live_activity_register_push_to_start. Without it the session is start_mode 'local' and no start is sent.
--    A session that never started (status planned) is ended silently: no 'end' is ever sent without a 'start'.
-- 6. rpc_live_activity_sessions returns content = the platform-neutral content-state only.
-- 7. rpc_live_activity_opt_out refuses (42501 unknown_installation) an installation the caller has no fcm_tokens row
--    for. There is no installations table; fcm_tokens is the installation registry.
--
-- ===================================== PAYLOAD CONTRACT (KAN-1005 / 1006 / 1007) =====================================
-- All dates are Unix seconds (integer JSON numbers), never ISO strings. Swift: decode them as Int / TimeInterval
-- since 1970 (ActivityKit's default Date decoding is seconds since 2001; do not declare them as Date).
-- Keys whose value is null are omitted (jsonb_strip_nulls).
--
-- content-state (identical on iOS, Android data.content, and rpc_live_activity_sessions[].content):
--   state              string   checkin_open | checked_in | scheduled_time_running | started | cancelled | ended
--                               | scheduled_time_ended
--   state_version      int      strictly increasing per session; ignore anything <= the version you hold
--   event_id           string   uuid
--   event_type         string   game | meetup
--   title              string?  events.title
--   start_at           int      Unix seconds
--   end_at             int?     Unix seconds
--   scheduled_end_at   int?     Unix seconds
--   actual_started_at  int?     Unix seconds
--   checked_in         bool
--   role               string   participant | organiser
--   organiser_action   string?  start | confirm_end   (organiser only: the control to show)
--   change             string?  time | venue           (update only: what changed)
--   end_reason         string?  (end only) cancelled | event_ended | scheduled_time_ended | left | removed |
--                               signed_out | opted_out | access_lost
--
-- iOS (FCM HTTP v1 message; the sender adds message.token and apns.live_activity_token at send time; the stored
-- payload never holds a token):
--   start  (to the installation's push-to-start token, iOS 17.2+)
--     apns.headers  {"apns-push-type":"liveactivity","apns-priority":"10"}
--     apns.payload.aps {
--       "timestamp": int, "event": "start",
--       "attributes-type": "DabblerActivityAttributes",
--       "attributes": {"event_id": string, "event_type": string, "title": string?},
--       "content-state": <content-state>,
--       "alert": {"title": string, "body": string},      EN or AR by fcm_tokens.locale, else profiles.language
--       "input-push-token": 1 }                           ask iOS for the per-activity token
--   update (to the per-activity token from rpc_live_activity_register)
--     apns.payload.aps {"timestamp": int, "event": "update", "content-state": <content-state>}
--   end    (to the per-activity token)
--     apns.payload.aps {"timestamp": int, "event": "end", "content-state": <content-state>, "dismissal-date": int}
--   No push-to-start token: no start push. rpc_live_activity_sessions shows start_mode 'local' and
--   needs_local_start = true; the app starts the activity on open with that content and registers its token.
-- Android: {"android":{"priority":"high"},"data":{"type":"live_activity","la_event":"start|update|end",
--   "session_id":string,"state_version":string,"content":<content-state as a JSON string>}}
-- Sender: still the stub (no Live Activity credentials); rows end as 'unsent: no credentials', 'unsent: no token'
-- (update/end with no per-activity token) or 'unsent: stale'.
-- =====================================================================================================================

-- 0. Pre-image guard ------------------------------------------------------------------------------------------------
DO $guard$
DECLARE r record;
BEGIN
  FOR r IN SELECT * FROM (VALUES
      ('public.live_activity_build_state(uuid,uuid)', 'c79140e9b7ff0fa6b992dd63c3963b2b'),
      ('public.live_activity_end(uuid,text,jsonb)', '9c8b788670eb55d208956dc784eddc22'),
      ('public.live_activity_enqueue(uuid,text,text,jsonb)', 'd338297d8b5bc344f0b2e79543f08c16'),
      ('public.live_activity_plan_event(uuid)', '14aa9c9c8dc06be5ef766d1b797c92a3'),
      ('public.live_activity_session_step(uuid)', '5abd0ee52c97dd757cbc2962e126fb2c'),
      ('public.live_activity_sweep()', '5e9e420f503a1fc71a3eb228c807d549'),
      ('public.rpc_live_activity_sessions(text)', 'b3d1c7b7752e17dfd961fd1476455596'),
      ('public.rpc_live_activity_opt_out(text,boolean)', 'e0ef24a9dea8c22b9b317a85ef94479e'),
      ('public.live_activity_lifecycle_as(uuid,uuid)', '6308c98ea48c9f1a7d3ee66e2b4e7418'),
      ('public.rpc_event_lifecycle_read(uuid)', 'bbc40d399aa83982cfa44d1c2debd9d9'),
      ('public.attendance_participants(uuid)', '3cec271333042fcd2e564bbb50b23afe')) q(f, h) LOOP
    IF md5(pg_get_functiondef(r.f::regprocedure)) <> r.h THEN
      RAISE EXCEPTION 'kan1004b guard: % changed since 20261118134953', r.f;
    END IF;
  END LOOP;
  IF to_regclass('public.live_activity_push_to_start') IS NOT NULL
     OR to_regprocedure('public.rpc_live_activity_register_push_to_start(text,text)') IS NOT NULL
     OR EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public'
                 AND table_name = 'live_activity_sessions' AND column_name IN ('due_at', 'start_mode', 'is_organiser', 'last_content')) THEN
    RAISE EXCEPTION 'kan1004b guard: already applied';
  END IF;
END
$guard$;

-- 1. Schema ---------------------------------------------------------------------------------------------------------
ALTER TABLE public.live_activity_sessions DROP CONSTRAINT live_activity_sessions_status_check;
ALTER TABLE public.live_activity_sessions ADD CONSTRAINT live_activity_sessions_status_check
  CHECK (status IN ('planned', 'active', 'stale', 'ended'));
ALTER TABLE public.live_activity_sessions ALTER COLUMN status SET DEFAULT 'planned';
UPDATE public.live_activity_sessions SET status = 'planned' WHERE status = 'active' AND last_state_version = 0;
ALTER TABLE public.live_activity_sessions
  ADD COLUMN due_at       timestamptz NOT NULL DEFAULT now(),
  ADD COLUMN start_mode   text CHECK (start_mode IS NULL OR start_mode IN ('push_to_start', 'local', 'android')),
  ADD COLUMN is_organiser boolean NOT NULL DEFAULT false,
  ADD COLUMN last_content jsonb;
CREATE INDEX live_activity_sessions_due_idx ON public.live_activity_sessions (due_at) WHERE status <> 'ended';
COMMENT ON COLUMN public.live_activity_sessions.last_content IS
  'KAN-1004b: last platform-neutral content-state (the contract in 20261118140810). Returned by rpc_live_activity_sessions.';

CREATE TABLE public.live_activity_push_to_start (
  user_id         uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  installation_id text NOT NULL CHECK (char_length(installation_id) BETWEEN 1 AND 128),
  token           text NOT NULL CHECK (char_length(token) BETWEEN 1 AND 4096),
  updated_at      timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, installation_id)
);
ALTER TABLE public.live_activity_push_to_start ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.live_activity_push_to_start FROM PUBLIC, anon, authenticated;
GRANT ALL ON TABLE public.live_activity_push_to_start TO service_role;
COMMENT ON TABLE public.live_activity_push_to_start IS
  'KAN-1004b: ActivityKit push-to-start token per iOS installation. Server-only. Written by rpc_live_activity_register_push_to_start.';

-- 2. State builder --------------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.live_activity_build_state(p_event_id uuid, p_user_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE l jsonb; v_state text; v_checked boolean; ev record; v_org boolean; v_action text;
BEGIN
  l := public.live_activity_lifecycle_as(p_event_id, p_user_id);
  SELECT e.title, e.start_at, e.end_at, e.venue_id, e.creator_user_id INTO ev FROM public.events e WHERE e.id = p_event_id;
  v_org := ev.creator_user_id IS NOT DISTINCT FROM p_user_id;
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
      'role', CASE WHEN v_org THEN 'organiser' ELSE 'participant' END,
      'organiser_action', v_action)),
    'basis', jsonb_build_object('start_at', ev.start_at, 'end_at', ev.end_at, 'venue_id', ev.venue_id));
END;
$function$;

-- 3. Enqueue: one version per real change; push-to-start or local start on iOS -------------------------------------
-- Returns the send id, or NULL when nothing is sent (iOS local start).
CREATE OR REPLACE FUNCTION public.live_activity_enqueue(p_session_id uuid, p_la_event text, p_state text, p_content jsonb)
 RETURNS bigint
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE s public.live_activity_sessions%ROWTYPE; v_ver int; v_payload jsonb; v_id bigint; v_c jsonb; v_mode text;
        v_status text; v_aps jsonb; v_ar boolean; v_title text; v_body text;
BEGIN
  SELECT * INTO s FROM public.live_activity_sessions WHERE id = p_session_id FOR UPDATE;
  v_ver := s.last_state_version + 1;
  v_c := jsonb_strip_nulls(p_content || jsonb_build_object('state_version', v_ver));
  v_mode := s.start_mode;
  IF p_la_event = 'start' THEN
    v_mode := CASE WHEN s.platform = 'android' THEN 'android'
                   WHEN EXISTS (SELECT 1 FROM public.live_activity_push_to_start t
                                 WHERE t.user_id = s.user_id AND t.installation_id = s.installation_id) THEN 'push_to_start'
                   ELSE 'local' END;
  END IF;
  UPDATE public.live_activity_sessions SET last_state_version = v_ver, last_state = p_state, last_content = v_c,
         last_updated_at = now(), start_mode = v_mode,
         status = CASE WHEN status = 'planned' THEN 'active' ELSE status END
   WHERE id = s.id;
  IF p_la_event = 'start' AND v_mode = 'local' THEN RETURN NULL; END IF;

  IF s.platform = 'iOS' THEN
    v_aps := jsonb_build_object('timestamp', floor(extract(epoch FROM now()))::bigint, 'event', p_la_event,
                                'content-state', v_c);
    IF p_la_event = 'start' THEN
      v_ar := coalesce((SELECT f.locale FROM public.fcm_tokens f WHERE f.user_id = s.user_id
                          AND f.installation_id = s.installation_id LIMIT 1),
                       (SELECT p.language FROM public.profiles p WHERE p.user_id = s.user_id
                         ORDER BY p.is_original DESC NULLS LAST, p.created_at LIMIT 1), 'en') ILIKE 'ar%';
      v_title := coalesce(v_c->>'title', CASE WHEN v_c->>'event_type' = 'meetup'
                   THEN CASE WHEN v_ar THEN 'لقاء' ELSE 'Meetup' END
                   ELSE CASE WHEN v_ar THEN 'مباراة' ELSE 'Game' END END);
      v_body := CASE p_state
        WHEN 'checkin_open' THEN CASE WHEN v_ar THEN 'تسجيل الحضور مفتوح' ELSE 'Check-in is open' END
        WHEN 'checked_in'   THEN CASE WHEN v_ar THEN 'تم تسجيل حضورك' ELSE 'You are checked in' END
        ELSE CASE WHEN v_ar THEN 'بدأ الموعد' ELSE 'It is time' END END;
      v_aps := v_aps || jsonb_build_object(
        'attributes-type', 'DabblerActivityAttributes',
        'attributes', jsonb_strip_nulls(jsonb_build_object('event_id', v_c->>'event_id', 'event_type', v_c->>'event_type',
                                                           'title', v_c->>'title')),
        'alert', jsonb_build_object('title', v_title, 'body', v_body),
        'input-push-token', 1);
    ELSIF p_la_event = 'end' THEN
      v_aps := v_aps || jsonb_build_object('dismissal-date', floor(extract(epoch FROM now() + interval '1 hour'))::bigint);
    END IF;
    v_payload := jsonb_build_object('apns', jsonb_build_object(
        'headers', jsonb_build_object('apns-push-type', 'liveactivity', 'apns-priority', '10'),
        'payload', jsonb_build_object('aps', v_aps)));
    v_status := CASE WHEN s.status = 'stale' THEN 'unsent: stale'
                     WHEN p_la_event <> 'start' AND s.push_token IS NULL THEN 'unsent: no token'
                     ELSE 'queued' END;
  ELSE
    v_payload := jsonb_build_object('android', jsonb_build_object('priority', 'high'),
        'data', jsonb_build_object('type', 'live_activity', 'la_event', p_la_event, 'session_id', s.id::text,
          'state_version', v_ver::text, 'content', v_c::text));
    v_status := CASE WHEN s.status = 'stale' THEN 'unsent: stale' ELSE 'queued' END;
  END IF;
  INSERT INTO public.live_activity_sends (session_id, state_version, la_event, state, payload, status)
  VALUES (s.id, v_ver, p_la_event, p_state, v_payload, v_status)
  RETURNING id INTO v_id;
  IF v_status = 'queued' THEN PERFORM public.live_activity_send(v_id); END IF;
  RETURN v_id;
END;
$function$;

-- 4. End: never an 'end' for a session that never started ----------------------------------------------------------
CREATE OR REPLACE FUNCTION public.live_activity_end(p_session_id uuid, p_reason text, p_content jsonb DEFAULT NULL)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE s public.live_activity_sessions%ROWTYPE;
BEGIN
  SELECT * INTO s FROM public.live_activity_sessions WHERE id = p_session_id FOR UPDATE;
  IF s.id IS NULL OR s.status = 'ended' THEN RETURN; END IF;
  IF s.status <> 'planned' THEN
    PERFORM public.live_activity_enqueue(s.id, 'end', coalesce(p_content->>'state', 'ended'),
              coalesce(p_content, coalesce(s.last_content, jsonb_build_object('event_id', s.event_id))
                                  || jsonb_build_object('state', 'ended'))
              || jsonb_build_object('end_reason', p_reason));
  END IF;
  UPDATE public.live_activity_sessions SET status = 'ended', ended_at = now(), end_reason = p_reason WHERE id = s.id;
END;
$function$;

-- 5. Planner: participants + organiser; only users with a new or revivable installation; per-user isolation -------
CREATE OR REPLACE FUNCTION public.live_activity_plan_event(p_event_id uuid)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE ev record; v_n int := 0; v_k int; u uuid; b jsonb; v_fail int := 0;
BEGIN
  SELECT e.id, e.start_at, coalesce(e.is_cancelled, false) c, e.creator_user_id cu INTO ev
    FROM public.events e WHERE e.id = p_event_id;
  IF ev.id IS NULL OR ev.c OR now() < ev.start_at - interval '30 minutes' THEN RETURN 0; END IF;
  FOR u IN
    SELECT q.uid FROM (SELECT p AS uid FROM public.attendance_participants(p_event_id) p
                       UNION SELECT ev.cu WHERE ev.cu IS NOT NULL) q
     WHERE EXISTS (
       SELECT 1 FROM public.fcm_tokens f
        WHERE f.user_id = q.uid AND f.device_platform IN ('iOS', 'android') AND f.installation_id NOT LIKE 'legacy:%'
          AND NOT EXISTS (SELECT 1 FROM public.live_activity_optouts o
                           WHERE o.user_id = q.uid AND o.installation_id = f.installation_id)
          AND NOT EXISTS (SELECT 1 FROM public.live_activity_sessions s
                           WHERE s.event_id = p_event_id AND s.user_id = q.uid AND s.installation_id = f.installation_id
                             AND NOT (s.status = 'ended' AND s.end_reason IN ('opted_out', 'left', 'removed', 'signed_out'))))
  LOOP
    BEGIN
      b := public.live_activity_build_state(p_event_id, u);
      IF NOT (b->>'final')::boolean THEN
        UPDATE public.live_activity_sessions s SET status = 'planned', ended_at = NULL, end_reason = NULL,
               last_fingerprint = NULL, last_basis = NULL, activity_id = NULL, push_token = NULL,
               push_token_updated_at = NULL, android_notification_id = NULL, stale_at = NULL, start_mode = NULL,
               is_organiser = (u = ev.cu), due_at = now()
          FROM public.fcm_tokens f
         WHERE s.event_id = p_event_id AND s.user_id = u AND s.status = 'ended'
           AND s.end_reason IN ('opted_out', 'left', 'removed', 'signed_out')
           AND f.user_id = u AND f.installation_id = s.installation_id AND f.device_platform = s.platform
           AND NOT EXISTS (SELECT 1 FROM public.live_activity_optouts o
                            WHERE o.user_id = u AND o.installation_id = s.installation_id);
        GET DIAGNOSTICS v_k = ROW_COUNT;
        v_n := v_n + v_k;
        INSERT INTO public.live_activity_sessions (event_id, user_id, installation_id, platform, provider, is_organiser)
        SELECT p_event_id, u, f.installation_id, f.device_platform,
               CASE f.device_platform WHEN 'iOS' THEN 'fcm_apns_live_activity' ELSE 'fcm_android_data' END, u = ev.cu
          FROM public.fcm_tokens f
         WHERE f.user_id = u AND f.device_platform IN ('iOS', 'android') AND f.installation_id NOT LIKE 'legacy:%'
           AND NOT EXISTS (SELECT 1 FROM public.live_activity_optouts o WHERE o.user_id = u AND o.installation_id = f.installation_id)
        ON CONFLICT (event_id, user_id, installation_id) DO NOTHING;
        GET DIAGNOSTICS v_k = ROW_COUNT;
        v_n := v_n + v_k;
      END IF;
    EXCEPTION WHEN OTHERS THEN
      v_fail := v_fail + 1;
      RAISE WARNING 'live_activity_plan_event: event % user % failed: % %', p_event_id, u, SQLSTATE, SQLERRM;
    END;
  END LOOP;
  PERFORM set_config('live_activity.plan_failures',
    (coalesce(nullif(current_setting('live_activity.plan_failures', true), ''), '0')::int + v_fail)::text, true);
  RETURN v_n;
END;
$function$;

-- 6. Session step ---------------------------------------------------------------------------------------------------
-- Returns 'ended:<reason>', 'sent', 'unchanged' or 'skipped'. Sets due_at to the next time instant (<= 10 minutes).
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
                                              to_timestamp((b->'content'->>'scheduled_end_at')::bigint)]) t
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

-- 7. Sweep: capped, age-cut, due-only -------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.live_activity_sweep()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_e uuid; v_s uuid; v_r text; v_planned int := 0; v_sent int := 0; v_ended int := 0; v_same int := 0;
        v_fail int := 0; v_events int := 0; v_steps int := 0; v_pf int;
        v_elim int := coalesce(nullif(current_setting('live_activity.event_limit', true), '')::int, 200);
        v_slim int := coalesce(nullif(current_setting('live_activity.session_limit', true), '')::int, 500);
BEGIN
  PERFORM set_config('live_activity.plan_failures', '0', true);
  FOR v_e IN SELECT e.id FROM public.events e
              WHERE e.event_type IN ('game', 'meetup') AND NOT coalesce(e.is_cancelled, false)
                AND e.start_at >= timestamptz '2026-11-18 13:30:00+00'
                AND e.start_at - interval '30 minutes' <= now()
                AND e.start_at > now() - interval '1 day'
                AND coalesce(e.end_at, e.start_at) + interval '6 hours' > now()
              ORDER BY e.start_at DESC LIMIT v_elim LOOP
    v_events := v_events + 1;
    BEGIN
      v_planned := v_planned + public.live_activity_plan_event(v_e);
    EXCEPTION WHEN OTHERS THEN
      v_fail := v_fail + 1;
      RAISE WARNING 'live_activity_sweep: plan failed for event %: % %', v_e, SQLSTATE, SQLERRM;
    END;
  END LOOP;
  v_pf := coalesce(nullif(current_setting('live_activity.plan_failures', true), ''), '0')::int;
  FOR v_s IN SELECT s.id FROM public.live_activity_sessions s WHERE s.status <> 'ended' AND s.due_at <= now()
              ORDER BY s.due_at LIMIT v_slim LOOP
    v_steps := v_steps + 1;
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
  RETURN jsonb_build_object('events', v_events, 'planned', v_planned, 'stepped', v_steps, 'sent', v_sent,
                            'ended', v_ended, 'unchanged', v_same, 'failed', v_fail + v_pf, 'plan_failed', v_pf);
END;
$function$;

-- 8. Inputs changed -> due now --------------------------------------------------------------------------------------
CREATE FUNCTION public.live_activity_mark_due()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE r jsonb := CASE WHEN TG_OP = 'DELETE' THEN to_jsonb(OLD) ELSE to_jsonb(NEW) END; v_event uuid;
BEGIN
  BEGIN
    IF TG_TABLE_NAME = 'fcm_tokens' THEN
      UPDATE public.live_activity_sessions SET due_at = now()
       WHERE user_id = (r->>'user_id')::uuid AND installation_id = r->>'installation_id' AND status <> 'ended' AND due_at > now();
      IF TG_OP = 'UPDATE' THEN
        UPDATE public.live_activity_sessions SET due_at = now()
         WHERE user_id = OLD.user_id AND installation_id = OLD.installation_id AND status <> 'ended' AND due_at > now();
      END IF;
      RETURN NULL;
    END IF;
    v_event := CASE TG_TABLE_NAME
      WHEN 'events' THEN (r->>'id')::uuid
      WHEN 'game_roster' THEN (SELECT g.event_id FROM public.games g WHERE g.id = (r->>'game_id')::uuid)
      WHEN 'meetup_rsvps' THEN (SELECT m.event_id FROM public.meetups m WHERE m.id = (r->>'meetup_id')::uuid)
      ELSE (r->>'event_id')::uuid END;
    IF v_event IS NULL THEN RETURN NULL; END IF;
    UPDATE public.live_activity_sessions SET due_at = now()
     WHERE event_id = v_event AND status <> 'ended' AND due_at > now()
       AND (TG_TABLE_NAME IN ('events', 'event_lifecycle') OR user_id = (r->>'user_id')::uuid);
  EXCEPTION WHEN OTHERS THEN
    RAISE WARNING 'live_activity_mark_due: % % %', TG_TABLE_NAME, SQLSTATE, SQLERRM;
  END;
  RETURN NULL;
END;
$function$;
CREATE TRIGGER trg_kan1004_la_due AFTER UPDATE ON public.events
  FOR EACH ROW EXECUTE FUNCTION public.live_activity_mark_due();
CREATE TRIGGER trg_kan1004_la_due AFTER INSERT OR UPDATE OR DELETE ON public.event_lifecycle
  FOR EACH ROW EXECUTE FUNCTION public.live_activity_mark_due();
CREATE TRIGGER trg_kan1004_la_due AFTER INSERT OR UPDATE OR DELETE ON public.event_attendance
  FOR EACH ROW EXECUTE FUNCTION public.live_activity_mark_due();
CREATE TRIGGER trg_kan1004_la_due AFTER INSERT OR UPDATE OR DELETE ON public.game_roster
  FOR EACH ROW EXECUTE FUNCTION public.live_activity_mark_due();
CREATE TRIGGER trg_kan1004_la_due AFTER INSERT OR UPDATE OR DELETE ON public.meetup_rsvps
  FOR EACH ROW EXECUTE FUNCTION public.live_activity_mark_due();
CREATE TRIGGER trg_kan1004_la_due AFTER UPDATE OR DELETE ON public.fcm_tokens
  FOR EACH ROW EXECUTE FUNCTION public.live_activity_mark_due();

-- 9. Client RPCs ----------------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.rpc_live_activity_sessions(p_installation_id text)
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
             'has_push_token', s.push_token IS NOT NULL, 'start_mode', s.start_mode,
             'needs_local_start', s.start_mode = 'local' AND s.push_token IS NULL AND s.activity_id IS NULL,
             'is_organiser', s.is_organiser,
             'content', s.last_content) ORDER BY s.created_at)
      FROM public.live_activity_sessions s
     WHERE s.user_id = v_uid AND s.installation_id = p_installation_id AND s.status <> 'ended'), '[]'::jsonb);
END;
$function$;

CREATE OR REPLACE FUNCTION public.rpc_live_activity_opt_out(p_installation_id text, p_opted_out boolean DEFAULT true)
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
  IF NOT EXISTS (SELECT 1 FROM public.fcm_tokens f WHERE f.user_id = v_uid AND f.installation_id = p_installation_id) THEN
    RAISE EXCEPTION USING errcode = '42501', message = 'unknown_installation';
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

-- Register (or clear, with a NULL/empty token) the ActivityKit push-to-start token of the caller's iOS installation.
CREATE FUNCTION public.rpc_live_activity_register_push_to_start(p_installation_id text, p_token text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_uid uuid := auth.uid();
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION USING errcode = '42501', message = 'not_authenticated'; END IF;
  IF p_installation_id IS NULL OR btrim(p_installation_id) = '' OR char_length(p_installation_id) > 128 THEN
    RAISE EXCEPTION USING errcode = '22023', message = 'invalid_installation_id';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.fcm_tokens f WHERE f.user_id = v_uid AND f.installation_id = p_installation_id
                  AND f.device_platform = 'iOS') THEN
    RAISE EXCEPTION USING errcode = '42501', message = 'unknown_installation';
  END IF;
  IF p_token IS NULL OR btrim(p_token) = '' THEN
    DELETE FROM public.live_activity_push_to_start WHERE user_id = v_uid AND installation_id = p_installation_id;
    RETURN jsonb_build_object('installation_id', p_installation_id, 'has_push_to_start', false);
  END IF;
  IF char_length(p_token) > 4096 THEN RAISE EXCEPTION USING errcode = '22023', message = 'invalid_push_token'; END IF;
  INSERT INTO public.live_activity_push_to_start (user_id, installation_id, token) VALUES (v_uid, p_installation_id, p_token)
  ON CONFLICT (user_id, installation_id) DO UPDATE SET token = EXCLUDED.token, updated_at = now();
  RETURN jsonb_build_object('installation_id', p_installation_id, 'has_push_to_start', true);
END;
$function$;

-- 10. Grants --------------------------------------------------------------------------------------------------------
REVOKE ALL ON FUNCTION public.live_activity_mark_due() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.live_activity_mark_due() TO service_role;
REVOKE ALL ON FUNCTION public.rpc_live_activity_register_push_to_start(text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rpc_live_activity_register_push_to_start(text, text) TO authenticated;

-- 11. Post-image ----------------------------------------------------------------------------------------------------
DO $post$
DECLARE r record;
BEGIN
  FOR r IN SELECT p.oid::regprocedure f, p.proname, pg_get_userbyid(p.proowner) o,
                  (SELECT array_agg(x ORDER BY x) FROM unnest(p.proacl::text[]) x)::text a, p.prosecdef s, p.proconfig c
             FROM pg_proc p WHERE p.pronamespace = 'public'::regnamespace
              AND (p.proname LIKE 'live_activity\_%' OR p.proname LIKE 'rpc_live_activity\_%') LOOP
    IF r.o <> 'postgres' OR NOT r.s OR r.c IS DISTINCT FROM ARRAY['search_path=public, pg_temp'] THEN
      RAISE EXCEPTION 'kan1004b post-image: % attributes % % %', r.f, r.o, r.s, r.c;
    END IF;
    IF r.proname LIKE 'rpc_%' AND r.a <> '{authenticated=X/postgres,postgres=X/postgres,service_role=X/postgres}' THEN
      RAISE EXCEPTION 'kan1004b post-image: % acl %', r.f, r.a;
    ELSIF r.proname NOT LIKE 'rpc_%' AND r.a <> '{postgres=X/postgres,service_role=X/postgres}' THEN
      RAISE EXCEPTION 'kan1004b post-image: % acl %', r.f, r.a;
    END IF;
  END LOOP;
  IF (SELECT count(*) FROM pg_proc WHERE pronamespace = 'public'::regnamespace
       AND (proname LIKE 'live_activity\_%' OR proname LIKE 'rpc_live_activity\_%')) <> 14 THEN
    RAISE EXCEPTION 'kan1004b post-image: expected 14 live activity functions';
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.role_table_grants WHERE table_schema = 'public'
              AND table_name LIKE 'live_activity\_%' AND grantee IN ('anon', 'authenticated', 'PUBLIC')) THEN
    RAISE EXCEPTION 'kan1004b post-image: client grant on a live_activity table';
  END IF;
  IF (SELECT count(*) FROM pg_trigger WHERE tgname = 'trg_kan1004_la_due') <> 6 THEN
    RAISE EXCEPTION 'kan1004b post-image: due triggers missing';
  END IF;
END
$post$;
