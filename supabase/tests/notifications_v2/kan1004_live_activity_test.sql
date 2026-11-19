-- KAN-1004 Live Activity sessions and sender: live TAP-style test.
-- Run as postgres on wtncuzcskpigqpmnxwws after 20261118134953_kan1004_live_activity_sessions.sql and
-- 20261118140810_kan1004b_live_activity_fixes.sql. One DO block ending
-- in RAISE EXCEPTION: everything rolls back (the TAP text is the exception message).
-- Fixtures (as kan1002_lifecycle_read_test.sql): game G = 96949cc9 (organiser U = a3ba3271), V = 039a9d4a an active
-- roster player, X = ec959ff7 a non-participant. Meetup M = a038ef0b (organiser U).

DO $tap$
DECLARE
  tap text := ''; n int := 0; bad int := 0;
  u uuid := 'a3ba3271-3556-4b4e-b15d-bc0851f8a64b';
  v uuid := '039a9d4a-8c8d-48e1-8dff-327c1c615179';
  x uuid := 'ec959ff7-46ef-4bf2-aab4-3515b81f5846';
  g uuid := '96949cc9-270e-4e61-9af4-8a9b296fb75e';
  vp uuid := 'de8a830c-c561-4528-8ba0-37b89bd37814';
  xp uuid := '2982b2cc-1409-4cfa-8c76-af5cc4862b07';
  gid uuid; sid uuid; sid2 uuid; st text; j jsonb; c int; c2 int; e text; ok boolean; r record; vers int[];
  scen text; m uuid := 'a038ef0b-4a7e-458f-ad5d-e313772d3ccb'; sid3 uuid; aps jsonb;
BEGIN
  SELECT id INTO gid FROM public.games WHERE event_id = g;
  -- fixture -----------------------------------------------------------------------------------------------------------
  UPDATE public.events SET is_cancelled = false, cancelled_at = NULL, cancelled_reason = NULL,
         start_at = now() + interval '20 minutes', end_at = now() + interval '80 minutes' WHERE id = g;
  DELETE FROM public.event_lifecycle WHERE event_id = g;
  DELETE FROM public.event_attendance WHERE event_id = g;
  DELETE FROM public.game_roster WHERE game_id = gid AND user_id IN (v, x);
  DELETE FROM public.game_waitlist WHERE game_id = gid AND user_id IN (v, x);
  INSERT INTO public.game_roster (game_id, profile_id, user_id, role, status) VALUES (gid, vp, v, 'player', 'active');
  INSERT INTO public.game_waitlist (game_id, profile_id, user_id, position, joined_at) VALUES (gid, xp, x, 1, now());
  DELETE FROM public.live_activity_sessions WHERE event_id = g;
  DELETE FROM public.live_activity_optouts WHERE user_id IN (v, x);
  DELETE FROM public.fcm_tokens WHERE user_id IN (u, v, x) OR installation_id LIKE 'k1004-%';   -- U's real devices too: counts see only k1004 rows
  DELETE FROM public.live_activity_push_to_start WHERE user_id IN (u, v, x);
  INSERT INTO public.fcm_tokens (user_id, installation_id, token, device_platform, locale) VALUES
    (v, 'k1004-v-ios', 'k1004-tok-v-ios', 'iOS', 'en'), (v, 'k1004-v-and', 'k1004-tok-v-and', 'android', 'en'),
    (v, 'k1004-v-web', 'k1004-tok-v-web', 'web', 'en'), (v, 'k1004-v-opt', 'k1004-tok-v-opt', 'iOS', 'en'),
    (x, 'k1004-x-ios', 'k1004-tok-x-ios', 'iOS', 'en'),
    (u, 'k1004-u-ios', 'k1004-tok-u-ios', 'iOS', 'ar');   -- organiser U: a token, and U's active host roster row
  INSERT INTO public.live_activity_push_to_start (user_id, installation_id, token) VALUES
    (v, 'k1004-v-ios', 'k1004-p2s-v'), (u, 'k1004-u-ios', 'k1004-p2s-u');
  INSERT INTO public.fcm_tokens (user_id, token, platform) VALUES (v, 'k1004-tok-v-legacy', 'iOS');
  INSERT INTO public.live_activity_optouts (user_id, installation_id) VALUES (v, 'k1004-v-opt');

  ------------------------------------------------------------------ C1 planner: no session before check-in opens
  UPDATE public.events SET start_at = now() + interval '40 minutes' WHERE id = g;
  n := n + 1; c := public.live_activity_plan_event(g);
  IF c = 0 AND NOT EXISTS (SELECT 1 FROM public.live_activity_sessions WHERE event_id = g) THEN
    tap := tap || format(E'ok %s - control: 40 minutes before the start (check-in closed) no session\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - planned %s before check-in\n', n, c); END IF;

  ------------------------------------------------------------------ C2 planner at check-in open
  UPDATE public.events SET start_at = now() + interval '20 minutes' WHERE id = g;
  n := n + 1; c := public.live_activity_plan_event(g);
  IF c = 3 AND (SELECT array_agg(installation_id ORDER BY installation_id) FROM public.live_activity_sessions
                 WHERE event_id = g AND user_id = v) = ARRAY['k1004-v-and', 'k1004-v-ios'] THEN
    tap := tap || format(E'ok %s - check-in open (start - 30m): eligible V gets a session on iOS and android\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - planned %s\n', n, c); END IF;

  n := n + 1;
  IF EXISTS (SELECT 1 FROM public.game_roster WHERE game_id = gid AND user_id = u AND status = 'active')
     AND (SELECT array_agg(installation_id::text || ':' || is_organiser::text) FROM public.live_activity_sessions
           WHERE event_id = g AND user_id = u) = ARRAY['k1004-u-ios:true'] THEN
    tap := tap || format(E'ok %s - organiser U (token + active host row) gets one session, is_organiser, on iOS only (web/legacy skipped)\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - organiser session missing\n', n); END IF;
  n := n + 1;
  IF NOT EXISTS (SELECT 1 FROM public.live_activity_sessions WHERE event_id = g AND (user_id = x
                  OR installation_id IN ('k1004-v-web', 'k1004-v-opt', 'legacy:iOS', 'legacy:android'))) THEN
    tap := tap || format(E'ok %s - negative: waitlisted X, the opted-out device, web and the legacy rows get none\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - ineligible session created\n', n); END IF;

  -- a user who left gets none (X off the waitlist first, or the freed spot promotes X)
  DELETE FROM public.game_waitlist WHERE game_id = gid AND user_id = x;
  UPDATE public.game_roster SET status = 'left' WHERE game_id = gid AND user_id = v;
  DELETE FROM public.live_activity_sessions WHERE event_id = g;
  n := n + 1; c := public.live_activity_plan_event(g);
  IF NOT EXISTS (SELECT 1 FROM public.live_activity_sessions WHERE event_id = g AND user_id = v) AND c = 1 THEN
    tap := tap || format(E'ok %s - negative: a participant who left gets no session (the organiser still does)\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - left user planned %s\n', n, c); END IF;
  UPDATE public.game_roster SET status = 'active' WHERE game_id = gid AND user_id = v;
  PERFORM public.live_activity_plan_event(g);
  n := n + 1; c := public.live_activity_plan_event(g);
  IF c = 0 AND (SELECT count(*) FROM public.live_activity_sessions WHERE event_id = g) = 3 THEN
    tap := tap || format(E'ok %s - control: planning again creates no duplicate\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - duplicate %s\n', n, c); END IF;
  SELECT id INTO sid FROM public.live_activity_sessions WHERE event_id = g AND installation_id = 'k1004-v-ios';
  SELECT id INTO sid2 FROM public.live_activity_sessions WHERE event_id = g AND installation_id = 'k1004-v-and';

  ------------------------------------------------------------------ C3 one higher version per real change
  SELECT count(*) INTO c2 FROM public.notifications WHERE to_user_id = v;
  st := public.live_activity_session_step(sid);
  n := n + 1;
  SELECT * INTO r FROM public.live_activity_sends WHERE session_id = sid ORDER BY state_version DESC LIMIT 1;
  IF st = 'sent' AND r.state_version = 1 AND r.la_event = 'start' AND r.state = 'checkin_open'
     AND r.status = 'unsent: no credentials' THEN
    tap := tap || format(E'ok %s - first step: start, version 1, checkin_open, stub marks it unsent: no credentials\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - %s %s\n', n, st, row_to_json(r)); END IF;

  st := public.live_activity_session_step(sid);
  n := n + 1;
  IF st = 'unchanged' AND (SELECT count(*) FROM public.live_activity_sends WHERE session_id = sid) = 1 THEN
    tap := tap || format(E'ok %s - negative: a run with no change sends nothing and keeps the version\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - %s\n', n, st); END IF;

  FOR r IN SELECT * FROM (VALUES (1, 'checked_in'), (2, 'checked_in:time'), (3, 'checked_in:venue'),
                                 (4, 'scheduled_time_running:time'), (5, 'started')) q(i, expect) LOOP
    IF r.i = 1 THEN INSERT INTO public.event_attendance (event_id, event_type, user_id, checked_in_at) VALUES (g, 'game', v, now());
    ELSIF r.i = 2 THEN UPDATE public.events SET start_at = now() + interval '25 minutes' WHERE id = g;
    ELSIF r.i = 3 THEN UPDATE public.events SET venue_id = NULL WHERE id = g;   -- a venue change (kan713 pins a space's venue, NULL is allowed)
    ELSIF r.i = 4 THEN UPDATE public.events SET start_at = now() - interval '1 minute' WHERE id = g;
    ELSE INSERT INTO public.event_lifecycle (event_id, event_type, state, actual_started_at) VALUES (g, 'game', 'started', now());
    END IF;
    st := public.live_activity_session_step(sid);
    SELECT * INTO j FROM (SELECT to_jsonb(x2) FROM public.live_activity_sends x2 WHERE session_id = sid ORDER BY state_version DESC LIMIT 1) q;
    n := n + 1;
    IF st = 'sent' AND (j->>'state_version')::int = r.i + 1 AND j->>'la_event' = 'update'
       AND j->>'state' = split_part(r.expect, ':', 1)
       AND (j #>> '{payload,apns,payload,aps,content-state,change}') IS NOT DISTINCT FROM nullif(split_part(r.expect, ':', 2), '') THEN
      tap := tap || format(E'ok %s - %s: one update, version %s\n', n, r.expect, r.i + 1);
    ELSE bad := bad + 1; tap := tap || format(E'not ok %s - %s: %s %s\n', n, r.expect, st, j); END IF;
  END LOOP;

  UPDATE public.event_lifecycle SET state = 'ended', actual_ended_at = now(), closed_at = now(), closed_reason = 'played' WHERE event_id = g;
  st := public.live_activity_session_step(sid);
  n := n + 1;
  SELECT * INTO r FROM public.live_activity_sessions WHERE id = sid;
  IF st = 'ended:ended' AND r.status = 'ended' AND r.end_reason = 'event_ended' AND r.last_state_version = 7
     AND (SELECT la_event FROM public.live_activity_sends WHERE session_id = sid AND state_version = 7) = 'end' THEN
    tap := tap || format(E'ok %s - ended: one end at version 7, session ended (event_ended)\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - %s %s\n', n, st, row_to_json(r)); END IF;

  n := n + 1;
  SELECT array_agg(state_version ORDER BY id) INTO vers FROM public.live_activity_sends WHERE session_id = sid;
  IF vers = ARRAY[1,2,3,4,5,6,7] AND (SELECT bool_and(a.t <= b.t) FROM
       (SELECT state_version, (payload #>> '{apns,payload,aps,timestamp}')::bigint t FROM public.live_activity_sends WHERE session_id = sid) a
       JOIN (SELECT state_version, (payload #>> '{apns,payload,aps,timestamp}')::bigint t FROM public.live_activity_sends WHERE session_id = sid) b
         ON b.state_version = a.state_version + 1)
     AND (SELECT bool_and((payload #>> '{apns,payload,aps,content-state,state_version}')::int = state_version)
            FROM public.live_activity_sends WHERE session_id = sid) THEN
    tap := tap || format(E'ok %s - client contract: versions 1..7 strictly increase, carried in content-state with a non-decreasing aps.timestamp (older arrives late -> ignored)\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - versions %s\n', n, vers); END IF;

  n := n + 1;
  IF public.live_activity_session_step(sid) = 'skipped'
     AND (SELECT count(*) FROM public.live_activity_sends WHERE session_id = sid) = 7 THEN
    tap := tap || format(E'ok %s - negative: an ended session sends nothing more\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s\n', n); END IF;

  ------------------------------------------------------------------ C4 30m reminder untouched, no extra push
  n := n + 1;
  IF (SELECT count(*) FROM public.notifications WHERE to_user_id = v) = c2
     AND NOT EXISTS (SELECT 1 FROM pg_proc WHERE pronamespace = 'public'::regnamespace
                      AND proname LIKE '%live_activity%' AND (prosrc ILIKE '%notify%' OR prosrc ILIKE '%notifications%'
                        OR prosrc ILIKE '%send-push-notification%' OR prosrc ILIKE '%reminder%'))
     AND EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'kan983_reminders_worker' AND active) THEN
    tap := tap || format(E'ok %s - no notification row from any Live Activity change; no LA code touches notify/reminders; the reminder worker still runs\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - notifications or coupling\n', n); END IF;

  ------------------------------------------------------------------ C5 end reasons
  FOR scen IN SELECT unnest(ARRAY['cancelled', 'scheduled_time_ended', 'left', 'removed', 'signed_out', 'opted_out']) LOOP
    DELETE FROM public.live_activity_sessions WHERE event_id = g;
    DELETE FROM public.event_lifecycle WHERE event_id = g;
    DELETE FROM public.live_activity_optouts WHERE user_id = v AND installation_id = 'k1004-v-ios';
    UPDATE public.events SET start_at = now() + interval '20 minutes', end_at = now() + interval '80 minutes',
           is_cancelled = false WHERE id = g;
    UPDATE public.game_roster SET status = 'active' WHERE game_id = gid AND user_id = v;
    IF NOT EXISTS (SELECT 1 FROM public.fcm_tokens WHERE user_id = v AND installation_id = 'k1004-v-ios') THEN
      INSERT INTO public.fcm_tokens (user_id, installation_id, token, device_platform) VALUES (v, 'k1004-v-ios', 'k1004-tok-v-ios', 'iOS');
    END IF;
    PERFORM public.live_activity_plan_event(g);
    SELECT id INTO sid FROM public.live_activity_sessions WHERE event_id = g AND installation_id = 'k1004-v-ios';
    PERFORM public.live_activity_session_step(sid);
    IF scen = 'cancelled' THEN UPDATE public.events SET is_cancelled = true, cancelled_at = now() WHERE id = g;
    ELSIF scen = 'scheduled_time_ended' THEN
      UPDATE public.events SET start_at = now() - interval '5 hours', end_at = now() - interval '4 hours' WHERE id = g;
      INSERT INTO public.event_lifecycle (event_id, event_type, state, closed_at, closed_reason)
      VALUES (g, 'game', 'auto_closed', now(), 'time_ended');
    ELSIF scen = 'left' THEN UPDATE public.game_roster SET status = 'left' WHERE game_id = gid AND user_id = v;
    ELSIF scen = 'removed' THEN UPDATE public.game_roster SET status = 'kicked' WHERE game_id = gid AND user_id = v;
    ELSIF scen = 'signed_out' THEN
      PERFORM set_config('request.jwt.claims', json_build_object('sub', v, 'role', 'authenticated')::text, true);
      EXECUTE 'SET LOCAL ROLE authenticated';
      PERFORM public.rpc_unregister_push_token('k1004-v-ios');
      EXECUTE 'RESET ROLE';
    END IF;
    IF scen = 'opted_out' THEN
      PERFORM set_config('request.jwt.claims', json_build_object('sub', v, 'role', 'authenticated')::text, true);
      EXECUTE 'SET LOCAL ROLE authenticated';
      c := public.rpc_live_activity_opt_out('k1004-v-ios');
      EXECUTE 'RESET ROLE';
    ELSE
      st := public.live_activity_session_step(sid);
    END IF;
    SELECT * INTO r FROM public.live_activity_sessions WHERE id = sid;
    n := n + 1;
    IF r.status = 'ended' AND r.end_reason = scen AND (SELECT la_event FROM public.live_activity_sends
         WHERE session_id = sid ORDER BY state_version DESC LIMIT 1) = 'end'
       AND (SELECT payload #>> '{apns,payload,aps,content-state,end_reason}' FROM public.live_activity_sends
         WHERE session_id = sid ORDER BY state_version DESC LIMIT 1) = scen THEN
      tap := tap || format(E'ok %s - %s ends the session with reason %s and one end push\n', n, scen, scen);
    ELSE bad := bad + 1; tap := tap || format(E'not ok %s - %s: %s\n', n, scen, row_to_json(r)); END IF;
  END LOOP;
  n := n + 1;
  -- the opted-out iOS installation must not be re-planned; android of the same user still is
  DELETE FROM public.live_activity_sessions WHERE event_id = g AND installation_id = 'k1004-v-ios';
  PERFORM public.live_activity_plan_event(g);
  IF NOT EXISTS (SELECT 1 FROM public.live_activity_sessions WHERE event_id = g AND installation_id = 'k1004-v-ios')
     AND EXISTS (SELECT 1 FROM public.live_activity_sessions WHERE event_id = g AND installation_id = 'k1004-v-and') THEN
    tap := tap || format(E'ok %s - negative: after opt-out that device gets no new session; the other device does\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - opt-out replanned\n', n); END IF;

  ------------------------------------------------------------------ C6 token rotation, provider rejection
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  PERFORM public.rpc_live_activity_opt_out('k1004-v-ios', false);
  EXECUTE 'RESET ROLE';
  PERFORM public.live_activity_plan_event(g);
  SELECT id INTO sid FROM public.live_activity_sessions WHERE event_id = g AND installation_id = 'k1004-v-ios';
  SELECT id INTO sid2 FROM public.live_activity_sessions WHERE event_id = g AND installation_id = 'k1004-v-and';
  PERFORM public.live_activity_session_step(sid);
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  j := public.rpc_live_activity_register(sid, 'act-1', 'k1004-la-token-A');
  j := public.rpc_live_activity_register(sid, NULL, 'k1004-la-token-B');
  EXECUTE 'RESET ROLE';
  n := n + 1;
  IF (SELECT push_token FROM public.live_activity_sessions WHERE id = sid) = 'k1004-la-token-B'
     AND (SELECT activity_id FROM public.live_activity_sessions WHERE id = sid) = 'act-1' AND j->>'status' = 'active' THEN
    tap := tap || format(E'ok %s - a rotated ActivityKit token replaces the old one\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - %s\n', n, j); END IF;

  PERFORM public.live_activity_record_result((SELECT max(id) FROM public.live_activity_sends WHERE session_id = sid), 'token_rejected', 'unregistered');
  UPDATE public.events SET start_at = now() + interval '22 minutes' WHERE id = g;
  PERFORM public.live_activity_session_step(sid);
  n := n + 1;
  IF (SELECT status FROM public.live_activity_sessions WHERE id = sid) = 'stale'
     AND (SELECT stale_at FROM public.live_activity_sessions WHERE id = sid) IS NOT NULL
     AND (SELECT status FROM public.live_activity_sends WHERE session_id = sid ORDER BY state_version DESC LIMIT 1) = 'unsent: stale' THEN
    tap := tap || format(E'ok %s - a provider token rejection marks the session stale; later updates are not sent\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - not stale\n', n); END IF;

  PERFORM set_config('request.jwt.claims', json_build_object('sub', v, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  j := public.rpc_live_activity_register(sid, NULL, 'k1004-la-token-C');
  EXECUTE 'RESET ROLE';
  n := n + 1;
  IF j->>'status' = 'active' AND (SELECT stale_at FROM public.live_activity_sessions WHERE id = sid) IS NULL THEN
    tap := tap || format(E'ok %s - a new token revives the stale session\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - %s\n', n, j); END IF;

  PERFORM public.live_activity_record_result((SELECT max(id) FROM public.live_activity_sends WHERE session_id = sid), 'gone', 'unregistered');
  n := n + 1;
  IF (SELECT status = 'ended' AND end_reason = 'provider_rejected' FROM public.live_activity_sessions WHERE id = sid) THEN
    tap := tap || format(E'ok %s - a provider "gone" ends the session (provider_rejected)\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s\n', n); END IF;

  ------------------------------------------------------------------ C7 client RPC negatives
  PERFORM set_config('request.jwt.claims', json_build_object('sub', x, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  n := n + 1; e := NULL;
  BEGIN PERFORM public.rpc_live_activity_register(sid2, NULL, NULL, 7); EXCEPTION WHEN OTHERS THEN e := SQLSTATE; END;
  j := public.rpc_live_activity_sessions('k1004-v-and');
  EXECUTE 'RESET ROLE';
  IF e = 'P0002' AND j = '[]'::jsonb THEN
    tap := tap || format(E'ok %s - negative: X cannot register or list V''s session\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - %s %s\n', n, e, j); END IF;

  PERFORM set_config('request.jwt.claims', json_build_object('sub', v, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  n := n + 1; e := NULL;
  BEGIN PERFORM public.rpc_live_activity_register(sid2, NULL, 'k1004-ios-token-on-android'); EXCEPTION WHEN OTHERS THEN e := SQLSTATE; END;
  j := public.rpc_live_activity_register(sid2, 'and-act', NULL, 4242);
  EXECUTE 'RESET ROLE';
  IF e = '22023' AND (SELECT android_notification_id FROM public.live_activity_sessions WHERE id = sid2) = 4242 THEN
    tap := tap || format(E'ok %s - android session registers its notification id; an ActivityKit token on android is refused\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - %s\n', n, e); END IF;

  PERFORM public.live_activity_session_step(sid2);
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  j := public.rpc_live_activity_sessions('k1004-v-and');
  EXECUTE 'RESET ROLE';
  n := n + 1;
  IF jsonb_array_length(j) = 1 AND j->0->>'session_id' = sid2::text AND NOT (j::text ILIKE '%k1004-tok%')
     AND NOT (j->0 ? 'push_token') AND NOT (j->0->'content' ?| ARRAY['apns', 'android', 'data', 'aps'])
     AND j->0->'content'->>'state' IS NOT NULL AND (j->0->'content'->>'state_version')::int = (j->0->>'state_version')::int
     AND jsonb_typeof(j->0->'content'->'start_at') = 'number' THEN
    tap := tap || format(E'ok %s - rpc_live_activity_sessions lists V''s own session, no token, content = platform-neutral state only\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - %s\n', n, j); END IF;

  ------------------------------------------------------------------ C8 no score / ETA / location / token in any payload
  n := n + 1;
  IF NOT EXISTS (SELECT 1 FROM public.live_activity_sends s JOIN public.live_activity_sessions ss ON ss.id = s.session_id
                  WHERE ss.event_id = g AND (s.payload::text ~* '(score|"eta"|location|latitude|longitude|venue|"lat"|"lng"|k1004-la-token|k1004-tok|k1004-p2s)')) THEN
    tap := tap || format(E'ok %s - no payload carries a score, ETA, location, venue or token\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - forbidden key in payload\n', n); END IF;
  -- control: the same regex does match a planted score
  n := n + 1;
  IF '{"score": 3}'::jsonb::text ~* '(score|"eta"|location)' THEN tap := tap || format(E'ok %s - control: the payload probe detects a planted score\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s\n', n); END IF;

  ------------------------------------------------------------------ C9 grant probes
  FOR r IN SELECT * FROM (VALUES ('anon', 'live_activity_sessions'), ('authenticated', 'live_activity_sessions'),
                                 ('anon', 'live_activity_sends'), ('authenticated', 'live_activity_sends'),
                                 ('authenticated', 'live_activity_optouts'), ('authenticated', 'live_activity_push_to_start'),
                                 ('anon', 'live_activity_push_to_start')) q(rl, tb) LOOP
    n := n + 1; e := NULL;
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v, 'role', r.rl)::text, true);
    EXECUTE format('SET LOCAL ROLE %I', r.rl);
    BEGIN EXECUTE format('SELECT count(*) FROM public.%I', r.tb) INTO c; EXCEPTION WHEN OTHERS THEN e := SQLSTATE; END;
    EXECUTE 'RESET ROLE';
    IF e = '42501' THEN tap := tap || format(E'ok %s - %s cannot read %s (42501)\n', n, r.rl, r.tb);
    ELSE bad := bad + 1; tap := tap || format(E'not ok %s - %s read %s: %s\n', n, r.rl, r.tb, e); END IF;
  END LOOP;
  n := n + 1; e := NULL;
  EXECUTE 'SET LOCAL ROLE service_role';
  BEGIN EXECUTE 'SELECT count(*) FROM public.live_activity_sessions' INTO c; EXCEPTION WHEN OTHERS THEN e := SQLSTATE; END;
  EXECUTE 'RESET ROLE';
  IF e IS NULL AND c > 0 THEN tap := tap || format(E'ok %s - control: service_role reads the same table (the probe can pass)\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - %s\n', n, e); END IF;
  n := n + 1;
  IF NOT has_function_privilege('authenticated', 'public.live_activity_sweep()', 'EXECUTE')
     AND NOT has_function_privilege('anon', 'public.live_activity_record_result(bigint,text,text)', 'EXECUTE')
     AND NOT has_function_privilege('authenticated', 'public.live_activity_lifecycle_as(uuid,uuid)', 'EXECUTE')
     AND NOT has_function_privilege('anon', 'public.rpc_live_activity_register(uuid,text,text,integer)', 'EXECUTE')
     AND has_function_privilege('authenticated', 'public.rpc_live_activity_register(uuid,text,text,integer)', 'EXECUTE') THEN
    tap := tap || format(E'ok %s - helpers service_role only; rpc_* authenticated only, not anon\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - function ACL\n', n); END IF;

  ------------------------------------------------------------------ C10 sweep isolation: one failing session is counted
  CREATE FUNCTION public.kan1004_test_boom() RETURNS trigger LANGUAGE plpgsql AS
    $b$ BEGIN IF NEW.session_id = current_setting('kan1004.boom')::uuid THEN RAISE EXCEPTION 'boom'; END IF; RETURN NEW; END $b$;
  CREATE TRIGGER kan1004_test_boom BEFORE INSERT ON public.live_activity_sends FOR EACH ROW EXECUTE FUNCTION public.kan1004_test_boom();
  DELETE FROM public.live_activity_sessions WHERE event_id = g;
  UPDATE public.events SET start_at = now() + interval '20 minutes' WHERE id = g;
  PERFORM public.live_activity_plan_event(g);
  SELECT id INTO sid FROM public.live_activity_sessions WHERE event_id = g AND installation_id = 'k1004-v-ios';
  SELECT id INTO sid2 FROM public.live_activity_sessions WHERE event_id = g AND installation_id = 'k1004-v-and';
  PERFORM set_config('kan1004.boom', sid::text, true);
  j := public.live_activity_sweep();
  n := n + 1;
  IF (j->>'failed')::int >= 1 AND (SELECT last_state_version FROM public.live_activity_sessions WHERE id = sid) = 0
     AND (SELECT last_state_version FROM public.live_activity_sessions WHERE id = sid2) = 1 THEN
    tap := tap || format(E'ok %s - sweep: the failing session is rolled back alone and counted (%s); the other progresses\n', n, j);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - %s\n', n, j); END IF;
  PERFORM set_config('kan1004.boom', '00000000-0000-0000-0000-000000000000', true);
  j := public.live_activity_sweep();
  n := n + 1;
  IF (SELECT last_state_version FROM public.live_activity_sessions WHERE id = sid) = 1
     AND (SELECT last_state_version FROM public.live_activity_sessions WHERE id = sid2) = 1 THEN
    tap := tap || format(E'ok %s - control: once the fault is gone the next sweep sends it, and the other is unchanged\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - %s\n', n, j); END IF;

  DROP TRIGGER kan1004_test_boom ON public.live_activity_sends;
  -- the sweep also planned live events where V/U really take part; drop those so later counts/listings see only G and M
  DELETE FROM public.live_activity_sessions WHERE installation_id LIKE 'k1004-%' AND event_id NOT IN (g, m);

  ------------------------------------------------------------------ C11 push-to-start payload (iOS 17.2+), EN and AR
  DELETE FROM public.live_activity_sessions WHERE event_id = g;
  DELETE FROM public.event_lifecycle WHERE event_id = g;
  DELETE FROM public.event_attendance WHERE event_id = g;
  UPDATE public.events SET start_at = now() + interval '20 minutes', end_at = now() + interval '80 minutes' WHERE id = g;
  PERFORM public.live_activity_plan_event(g);
  SELECT id INTO sid FROM public.live_activity_sessions WHERE event_id = g AND installation_id = 'k1004-v-ios';
  SELECT id INTO sid3 FROM public.live_activity_sessions WHERE event_id = g AND installation_id = 'k1004-u-ios';
  PERFORM public.live_activity_session_step(sid);
  PERFORM public.live_activity_session_step(sid3);
  SELECT payload #> '{apns,payload,aps}' INTO aps FROM public.live_activity_sends WHERE session_id = sid AND state_version = 1;
  n := n + 1;
  IF aps->>'event' = 'start' AND aps->>'attributes-type' = 'DabblerActivityAttributes'
     AND aps->'attributes'->>'event_id' = g::text AND aps->'attributes'->>'event_type' = 'game'
     AND jsonb_typeof(aps->'timestamp') = 'number' AND jsonb_typeof(aps->'content-state') = 'object'
     AND jsonb_typeof(aps->'content-state'->'start_at') = 'number' AND jsonb_typeof(aps->'content-state'->'end_at') = 'number'
     AND (aps->'content-state'->>'start_at')::bigint = floor(extract(epoch FROM now() + interval '20 minutes'))::bigint
     AND NOT ((aps->'content-state')::text ~ '\d{4}-\d{2}-\d{2}T')
     AND aps->'content-state'->>'role' = 'participant' AND (aps->'content-state'->>'state_version')::int = 1
     AND jsonb_typeof(aps->'alert'->'title') = 'string' AND aps->'alert'->>'body' = 'Check-in is open'
     AND (aps->>'input-push-token')::int = 1 AND NOT (aps ? 'dismissal-date')
     AND (SELECT start_mode FROM public.live_activity_sessions WHERE id = sid) = 'push_to_start' THEN
    tap := tap || format(E'ok %s - push-to-start: event start, attributes-type, attributes, content-state (Unix seconds), timestamp, EN alert\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - %s\n', n, aps); END IF;
  SELECT payload #> '{apns,payload,aps}' INTO aps FROM public.live_activity_sends WHERE session_id = sid3 AND state_version = 1;
  n := n + 1;
  IF aps->>'event' = 'start' AND aps->'alert'->>'body' = 'تسجيل الحضور مفتوح' AND aps->'content-state'->>'role' = 'organiser' THEN
    tap := tap || format(E'ok %s - organiser U: state read as U, role organiser, Arabic alert by the installation locale\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - %s\n', n, aps); END IF;
  UPDATE public.events SET start_at = now() - interval '1 minute' WHERE id = g;
  PERFORM public.live_activity_session_step(sid3);
  n := n + 1;
  IF (SELECT last_content->>'organiser_action' FROM public.live_activity_sessions WHERE id = sid3) = 'start'
     AND (SELECT last_content ? 'organiser_action' FROM public.live_activity_sessions WHERE id = sid) IS FALSE THEN
    tap := tap || format(E'ok %s - organiser controls: past the start U''s state carries organiser_action start; V''s does not\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - organiser action\n', n); END IF;

  ------------------------------------------------------------------ C12 no start push without a push-to-start token
  DELETE FROM public.live_activity_push_to_start WHERE user_id = v;
  DELETE FROM public.live_activity_sessions WHERE event_id = g;
  UPDATE public.events SET start_at = now() + interval '20 minutes' WHERE id = g;
  PERFORM public.live_activity_plan_event(g);
  SELECT id INTO sid FROM public.live_activity_sessions WHERE event_id = g AND installation_id = 'k1004-v-ios';
  st := public.live_activity_session_step(sid);
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  j := public.rpc_live_activity_sessions('k1004-v-ios');
  EXECUTE 'RESET ROLE';
  n := n + 1;
  IF st = 'sent' AND NOT EXISTS (SELECT 1 FROM public.live_activity_sends WHERE session_id = sid)
     AND (SELECT start_mode = 'local' AND last_state_version = 1 AND status = 'active' FROM public.live_activity_sessions WHERE id = sid)
     AND (j->0->>'needs_local_start')::boolean AND j->0->'content'->>'state' = 'checkin_open'
     AND (j->0->'content'->>'state_version')::int = 1 THEN
    tap := tap || format(E'ok %s - no push-to-start token: no start push; the session is local and listed with needs_local_start\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - %s %s\n', n, st, j); END IF;
  UPDATE public.events SET start_at = now() + interval '21 minutes' WHERE id = g;
  PERFORM public.live_activity_session_step(sid);
  n := n + 1;
  IF (SELECT la_event = 'update' AND state_version = 2 AND status = 'unsent: no token' FROM public.live_activity_sends WHERE session_id = sid) THEN
    tap := tap || format(E'ok %s - its next change is an update at version 2, held as unsent: no token until the app registers one\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s\n', n); END IF;

  ------------------------------------------------------------------ C13 no end without a start
  DELETE FROM public.live_activity_sessions WHERE event_id = g;
  PERFORM public.live_activity_plan_event(g);
  SELECT id INTO sid2 FROM public.live_activity_sessions WHERE event_id = g AND installation_id = 'k1004-v-and';
  SELECT id INTO sid FROM public.live_activity_sessions WHERE event_id = g AND installation_id = 'k1004-v-ios';
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  c := public.rpc_live_activity_opt_out('k1004-v-and');
  EXECUTE 'RESET ROLE';
  n := n + 1;
  IF c = 1 AND (SELECT status = 'ended' AND end_reason = 'opted_out' AND last_state_version = 0 FROM public.live_activity_sessions WHERE id = sid2)
     AND NOT EXISTS (SELECT 1 FROM public.live_activity_sends WHERE session_id = sid2) THEN
    tap := tap || format(E'ok %s - a session that never started (version 0) ends with no end push\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s\n', n); END IF;

  ------------------------------------------------------------------ C14 revival: opt back in, re-sign-in, rejoin
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  PERFORM public.rpc_live_activity_opt_out('k1004-v-and', false);
  EXECUTE 'RESET ROLE';
  PERFORM public.live_activity_plan_event(g);
  ok := (SELECT status = 'planned' AND end_reason IS NULL AND ended_at IS NULL FROM public.live_activity_sessions WHERE id = sid2);
  st := public.live_activity_session_step(sid2);   -- own statement: a later subquery must see its writes
  n := n + 1;
  IF ok AND (SELECT count(*) FROM public.live_activity_sessions WHERE event_id = g AND installation_id = 'k1004-v-and') = 1
     AND st = 'sent'
     AND (SELECT la_event FROM public.live_activity_sends WHERE session_id = sid2 AND state_version = 1) = 'start' THEN
    tap := tap || format(E'ok %s - opt back in: the opted_out row is revived in place (planned) and starts again\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - opt-in revival\n', n); END IF;

  PERFORM public.live_activity_session_step(sid);
  FOR scen IN SELECT unnest(ARRAY['opted_out', 'signed_out', 'left']) LOOP
    SELECT last_state_version INTO c2 FROM public.live_activity_sessions WHERE id = sid;
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    IF scen = 'opted_out' THEN PERFORM public.rpc_live_activity_opt_out('k1004-v-ios');
    ELSIF scen = 'signed_out' THEN PERFORM public.rpc_unregister_push_token('k1004-v-ios');
    END IF;
    EXECUTE 'RESET ROLE';
    IF scen = 'left' THEN UPDATE public.game_roster SET status = 'left' WHERE game_id = gid AND user_id = v; END IF;
    IF scen <> 'opted_out' THEN PERFORM public.live_activity_session_step(sid); END IF;
    ok := (SELECT status = 'ended' AND end_reason = scen FROM public.live_activity_sessions WHERE id = sid);
    PERFORM public.live_activity_plan_event(g);
    ok := ok AND (SELECT status = 'ended' FROM public.live_activity_sessions WHERE id = sid);   -- not yet eligible
    IF scen = 'opted_out' THEN
      PERFORM set_config('request.jwt.claims', json_build_object('sub', v, 'role', 'authenticated')::text, true);
      EXECUTE 'SET LOCAL ROLE authenticated';
      PERFORM public.rpc_live_activity_opt_out('k1004-v-ios', false);
      EXECUTE 'RESET ROLE';
    ELSIF scen = 'signed_out' THEN
      INSERT INTO public.fcm_tokens (user_id, installation_id, token, device_platform, locale) VALUES (v, 'k1004-v-ios', 'k1004-tok-v-ios', 'iOS', 'en');
    ELSE UPDATE public.game_roster SET status = 'active' WHERE game_id = gid AND user_id = v;
    END IF;
    c := public.live_activity_plan_event(g);
    st := public.live_activity_session_step(sid);
    SELECT * INTO r FROM public.live_activity_sessions WHERE id = sid;
    n := n + 1;
    IF ok AND c = 1 AND st = 'sent' AND r.status = 'active' AND r.end_reason IS NULL AND r.last_state_version = c2 + 2
       AND r.push_token IS NULL AND r.start_mode = 'local' THEN
      tap := tap || format(E'ok %s - %s then eligible again: same row revived, a fresh start at version %s (> the end at %s)\n', n, scen, r.last_state_version, c2 + 1);
    ELSE bad := bad + 1; tap := tap || format(E'not ok %s - %s: ok=%s c=%s st=%s %s\n', n, scen, ok, c, st, row_to_json(r)); END IF;
  END LOOP;

  ------------------------------------------------------------------ C15 meetup: RSVP going -> removed, and access_lost
  UPDATE public.events SET start_at = now() + interval '20 minutes', is_cancelled = false, listing_visibility = 'public' WHERE id = m;
  DELETE FROM public.event_lifecycle WHERE event_id = m;
  DELETE FROM public.live_activity_sessions WHERE event_id = m;
  DELETE FROM public.meetup_rsvps WHERE meetup_id = m AND user_id IN (v, x);
  INSERT INTO public.meetup_rsvps (meetup_id, user_id, profile_id, status) VALUES (m, v, vp, 'going');
  c := public.live_activity_plan_event(m);
  SELECT id INTO sid FROM public.live_activity_sessions WHERE event_id = m AND installation_id = 'k1004-v-ios';
  SELECT id INTO sid3 FROM public.live_activity_sessions WHERE event_id = m AND installation_id = 'k1004-u-ios';
  st := public.live_activity_session_step(sid);
  n := n + 1;
  IF c = 3 AND st = 'sent' THEN
    tap := tap || format(E'ok %s - control: meetup with V going: V (2) + organiser U (1) planned, V''s session starts\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - meetup plan %s %s\n', n, c, st); END IF;
  UPDATE public.meetup_rsvps SET status = 'removed' WHERE meetup_id = m AND user_id = v;
  st := public.live_activity_session_step(sid);
  n := n + 1;
  IF st = 'ended:removed' AND (SELECT payload #>> '{apns,payload,aps,content-state,end_reason}' FROM public.live_activity_sends
                                WHERE session_id = sid ORDER BY state_version DESC LIMIT 1) = 'removed' THEN
    tap := tap || format(E'ok %s - meetup RSVP going -> removed ends the session (removed) with one end\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - %s\n', n, st); END IF;
  UPDATE public.meetup_rsvps SET status = 'going' WHERE meetup_id = m AND user_id = v;
  PERFORM public.live_activity_plan_event(m);
  st := public.live_activity_session_step(sid);
  UPDATE public.events SET listing_visibility = 'hidden' WHERE id = m;   -- V is still RSVP going, but cannot see it
  ok := st = 'sent' AND EXISTS (SELECT 1 FROM public.attendance_participants(m) p WHERE p = v);
  st := public.live_activity_session_step(sid);
  n := n + 1;
  IF ok AND st = 'ended:access_lost'
     AND (SELECT end_reason FROM public.live_activity_sessions WHERE id = sid) = 'access_lost' THEN
    tap := tap || format(E'ok %s - access_lost: meetup made hidden while V is still a going participant ends V''s session\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - %s\n', n, st); END IF;
  st := public.live_activity_session_step(sid3);
  n := n + 1;
  IF st IN ('sent', 'unchanged')
     AND (SELECT status <> 'ended' FROM public.live_activity_sessions WHERE id = sid3) THEN
    tap := tap || format(E'ok %s - control: the organiser still sees the hidden meetup and keeps the session\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s\n', n); END IF;

  ------------------------------------------------------------------ C16 per-user isolation in planning
  CREATE FUNCTION public.kan1004_test_boom_user() RETURNS trigger LANGUAGE plpgsql AS
    $b$ BEGIN IF NEW.user_id = current_setting('kan1004.boomu')::uuid THEN RAISE EXCEPTION 'boom user'; END IF; RETURN NEW; END $b$;
  CREATE TRIGGER kan1004_test_boom_user BEFORE INSERT ON public.live_activity_sessions FOR EACH ROW EXECUTE FUNCTION public.kan1004_test_boom_user();
  DELETE FROM public.live_activity_sessions WHERE event_id = g;
  PERFORM set_config('kan1004.boomu', v::text, true);
  PERFORM set_config('live_activity.plan_failures', '0', true);
  c := public.live_activity_plan_event(g);
  n := n + 1;
  IF c = 1 AND current_setting('live_activity.plan_failures') = '1'
     AND EXISTS (SELECT 1 FROM public.live_activity_sessions WHERE event_id = g AND user_id = u)
     AND NOT EXISTS (SELECT 1 FROM public.live_activity_sessions WHERE event_id = g AND user_id = v) THEN
    tap := tap || format(E'ok %s - planning: V''s failure is rolled back alone and counted (1); U is still planned\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - %s %s\n', n, c, current_setting('live_activity.plan_failures')); END IF;
  PERFORM set_config('kan1004.boomu', '00000000-0000-0000-0000-000000000000', true);
  c := public.live_activity_plan_event(g);
  n := n + 1;
  IF c = 2 AND current_setting('live_activity.plan_failures') = '1' THEN
    tap := tap || format(E'ok %s - control: once the fault is gone V''s two installations are planned, no new failure\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - %s\n', n, c); END IF;
  DROP TRIGGER kan1004_test_boom_user ON public.live_activity_sessions;

  ------------------------------------------------------------------ C17 cost bounds: run cap, due-only, planner skip
  PERFORM set_config('live_activity.session_limit', '1', true);
  j := public.live_activity_sweep();
  n := n + 1;
  IF (j->>'stepped')::int = 1 AND (SELECT count(*) FROM public.live_activity_sessions WHERE event_id = g AND last_state_version = 0) >= 2 THEN
    tap := tap || format(E'ok %s - run cap: session_limit 1 steps exactly one session (%s)\n', n, j);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - %s\n', n, j); END IF;
  PERFORM set_config('live_activity.session_limit', '', true);
  PERFORM set_config('live_activity.event_limit', '0', true);
  j := public.live_activity_sweep();
  n := n + 1;
  IF (j->>'events')::int = 0 AND (j->>'planned')::int = 0 THEN
    tap := tap || format(E'ok %s - run cap: event_limit 0 plans no event\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - %s\n', n, j); END IF;
  PERFORM set_config('live_activity.event_limit', '', true);
  j := public.live_activity_sweep();
  n := n + 1;
  IF NOT EXISTS (SELECT 1 FROM public.live_activity_sessions WHERE event_id = g AND (status = 'planned' OR due_at <= now()))
     AND (SELECT bool_and(due_at > now()) FROM public.live_activity_sessions WHERE event_id = g AND status <> 'ended') THEN
    tap := tap || format(E'ok %s - control: with no caps the sweep steps every due session; each is then due later\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - %s\n', n, j); END IF;
  SELECT array_agg(last_state_version ORDER BY id) INTO vers FROM public.live_activity_sessions WHERE event_id = g;
  j := public.live_activity_sweep();
  n := n + 1;
  IF (SELECT array_agg(last_state_version ORDER BY id) FROM public.live_activity_sessions WHERE event_id = g) = vers
     AND NOT EXISTS (SELECT 1 FROM public.live_activity_sessions WHERE event_id = g AND due_at <= now()) THEN
    tap := tap || format(E'ok %s - due-only: nothing changed, so no session of G is due or stepped (%s)\n', n, j);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - %s\n', n, j); END IF;
  UPDATE public.events SET start_at = now() + interval '19 minutes' WHERE id = g;
  n := n + 1;
  IF (SELECT bool_and(due_at <= now()) FROM public.live_activity_sessions WHERE event_id = g AND status <> 'ended') THEN
    j := public.live_activity_sweep();
    IF (SELECT bool_and(a > b) FROM unnest((SELECT array_agg(last_state_version ORDER BY id) FROM public.live_activity_sessions WHERE event_id = g), vers) q(a, b)) THEN
      tap := tap || format(E'ok %s - an input change (start moved) makes G''s sessions due; the next sweep sends each one update\n', n);
    ELSE bad := bad + 1; tap := tap || format(E'not ok %s - %s\n', n, j); END IF;
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - the change did not mark sessions due\n', n); END IF;
  -- planner skip: count lifecycle reads with a counting copy of live_activity_lifecycle_as (rolled back with the test)
  CREATE OR REPLACE FUNCTION public.live_activity_lifecycle_as(p_event_id uuid, p_user_id uuid)
   RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $b$
  DECLARE v_claims text := current_setting('request.jwt.claims', true); v_sub text := current_setting('request.jwt.claim.sub', true); v jsonb;
  BEGIN
    PERFORM set_config('kan1004.reads', (coalesce(nullif(current_setting('kan1004.reads', true), ''), '0')::int + 1)::text, true);
    PERFORM set_config('request.jwt.claims', json_build_object('sub', p_user_id, 'role', 'authenticated')::text, true);
    PERFORM set_config('request.jwt.claim.sub', p_user_id::text, true);
    v := public.rpc_event_lifecycle_read(p_event_id);
    PERFORM set_config('request.jwt.claims', coalesce(v_claims, ''), true);
    PERFORM set_config('request.jwt.claim.sub', coalesce(v_sub, ''), true);
    RETURN v;
  END $b$;
  PERFORM set_config('kan1004.reads', '0', true);
  c := public.live_activity_plan_event(g);
  c2 := current_setting('kan1004.reads')::int;
  DELETE FROM public.live_activity_sessions WHERE event_id = g AND installation_id = 'k1004-v-and';
  PERFORM set_config('kan1004.reads', '0', true);
  n := n + 1;
  c := public.live_activity_plan_event(g) * 10 + c;
  IF c = 10 AND c2 = 0 AND current_setting('kan1004.reads')::int = 1 THEN
    tap := tap || format(E'ok %s - planner skip: users whose installations all have a live session get no lifecycle read (0); control: one missing installation -> exactly 1 read\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - plan %s reads %s then %s\n', n, c, c2, current_setting('kan1004.reads')); END IF;

  ------------------------------------------------------------------ C18 opt-out refused for a foreign installation
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  n := n + 1; e := NULL; st := NULL;
  BEGIN PERFORM public.rpc_live_activity_opt_out('k1004-x-ios'); EXCEPTION WHEN OTHERS THEN e := SQLSTATE; END;
  BEGIN PERFORM public.rpc_live_activity_opt_out('k1004-no-such-installation'); EXCEPTION WHEN OTHERS THEN st := SQLSTATE; END;
  EXECUTE 'RESET ROLE';
  IF e = '42501' AND st = '42501' AND NOT EXISTS (SELECT 1 FROM public.live_activity_optouts WHERE installation_id IN ('k1004-x-ios', 'k1004-no-such-installation')) THEN
    tap := tap || format(E'ok %s - negative: V cannot opt out X''s installation or an unknown one (42501), nothing stored\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - %s %s\n', n, e, st); END IF;
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  n := n + 1; e := NULL;
  BEGIN PERFORM public.rpc_live_activity_register_push_to_start('k1004-x-ios', 'k1004-p2s-foreign'); EXCEPTION WHEN OTHERS THEN e := SQLSTATE; END;
  j := public.rpc_live_activity_register_push_to_start('k1004-v-ios', 'k1004-p2s-v2');
  EXECUTE 'RESET ROLE';
  IF e = '42501' AND (j->>'has_push_to_start')::boolean
     AND (SELECT token FROM public.live_activity_push_to_start WHERE user_id = v AND installation_id = 'k1004-v-ios') = 'k1004-p2s-v2'
     AND NOT EXISTS (SELECT 1 FROM public.live_activity_push_to_start WHERE installation_id = 'k1004-x-ios') THEN
    tap := tap || format(E'ok %s - push-to-start registration: own iOS installation stored server-side; X''s refused (42501)\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - %s %s\n', n, e, j); END IF;

  RAISE EXCEPTION '%', format(E'1..%s\n%s# bad %s', n, tap, bad);
END
$tap$;
