-- KAN-1006 / KAN-1000: Live Activity `lang` and rpc_rating_get `is_organiser`: live TAP-style test.
-- Run as postgres on wtncuzcskpigqpmnxwws after 20261118163654_kan1006b_live_activity_lang_and_rating_organiser.sql.
-- One DO block ending in RAISE EXCEPTION: everything rolls back (the TAP text is the exception message).
-- Fixtures (as kan1004 / kan997): game G = 96949cc9 (casual, organiser U = a3ba3271), V = 039a9d4a an active roster
-- player, game G2 = 1ad6aec2 (training), meetup M = 1b6df962, P1 = 036735b7 a participant who attended.

DO $tap$
DECLARE
  tap text := ''; n int := 0; bad int := 0;
  u uuid := 'a3ba3271-3556-4b4e-b15d-bc0851f8a64b';
  v uuid := '039a9d4a-8c8d-48e1-8dff-327c1c615179';
  p1 uuid := '036735b7-2668-4fc6-9ec3-dceb8b95ea33';
  g uuid := '96949cc9-270e-4e61-9af4-8a9b296fb75e';
  g2 uuid := '1ad6aec2-639a-4a0e-b95f-05399cbe85d1';
  m uuid := '1b6df962-cabb-4c18-83cb-d589345e6460';
  vp uuid := 'de8a830c-c561-4528-8ba0-37b89bd37814';
  gid uuid; s_vi uuid; s_va uuid; s_ui uuid; st text; j jsonb; k jsonb; c int; ver int; ev uuid; et text;
BEGIN
  SELECT id INTO gid FROM public.games WHERE event_id = g;
  -- Live Activity fixture --------------------------------------------------------------------------------------------
  UPDATE public.events SET creator_user_id = u, is_cancelled = false, cancelled_at = NULL, cancelled_reason = NULL,
         start_at = now() + interval '20 minutes', end_at = now() + interval '80 minutes' WHERE id = g;
  DELETE FROM public.event_lifecycle WHERE event_id = g;
  DELETE FROM public.event_attendance WHERE event_id = g;
  DELETE FROM public.game_roster WHERE game_id = gid AND user_id = v;
  INSERT INTO public.game_roster (game_id, profile_id, user_id, role, status) VALUES (gid, vp, v, 'player', 'active');
  DELETE FROM public.live_activity_sessions WHERE event_id = g;
  DELETE FROM public.live_activity_optouts WHERE user_id IN (u, v);
  DELETE FROM public.fcm_tokens WHERE user_id IN (u, v);
  DELETE FROM public.live_activity_push_to_start WHERE user_id IN (u, v);
  INSERT INTO public.fcm_tokens (user_id, installation_id, token, device_platform, locale) VALUES
    (v, 'k6-v-ios', 'k6-tok-v-ios', 'iOS', NULL), (v, 'k6-v-and', 'k6-tok-v-and', 'android', NULL),
    (u, 'k6-u-ios', 'k6-tok-u-ios', 'iOS', 'en-GB');
  INSERT INTO public.live_activity_push_to_start (user_id, installation_id, token) VALUES
    (v, 'k6-v-ios', 'k6-p2s-v'), (u, 'k6-u-ios', 'k6-p2s-u');
  UPDATE public.profiles SET language = 'ar' WHERE user_id IN (u, v);
  PERFORM public.live_activity_plan_event(g);
  SELECT id INTO s_vi FROM public.live_activity_sessions WHERE event_id = g AND installation_id = 'k6-v-ios';
  SELECT id INTO s_va FROM public.live_activity_sessions WHERE event_id = g AND installation_id = 'k6-v-and';
  SELECT id INTO s_ui FROM public.live_activity_sessions WHERE event_id = g AND installation_id = 'k6-u-ios';
  n := n + 1;
  IF s_vi IS NOT NULL AND s_va IS NOT NULL AND s_ui IS NOT NULL THEN
    tap := tap || format(E'ok %s - fixture: sessions for V (iOS, android) and U (iOS)\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - sessions missing %s %s %s\n', n, s_vi, s_va, s_ui); END IF;

  ------------------------------------------------------------------ L1 ar profile, no locale -> 'ar' (iOS start)
  st := public.live_activity_session_step(s_vi);
  SELECT payload->'apns'->'payload'->'aps' INTO j FROM public.live_activity_sends WHERE session_id = s_vi
   ORDER BY state_version DESC LIMIT 1;
  n := n + 1;
  IF st = 'sent' AND j->>'event' = 'start' AND j->'content-state'->>'lang' = 'ar' AND j->'attributes'->>'lang' = 'ar' THEN
    tap := tap || format(E'ok %s - ar profile, null locale: iOS content-state.lang and attributes.lang are ar\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - %s %s\n', n, st, j); END IF;

  ------------------------------------------------------------------ L2 android data message
  st := public.live_activity_session_step(s_va);
  SELECT payload->'data' INTO j FROM public.live_activity_sends WHERE session_id = s_va ORDER BY state_version DESC LIMIT 1;
  n := n + 1;
  IF st = 'sent' AND j->>'lang' = 'ar' AND (j->>'content')::jsonb->>'lang' = 'ar' THEN
    tap := tap || format(E'ok %s - android data.lang and data.content.lang are ar\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - %s %s\n', n, st, j); END IF;

  ------------------------------------------------------------------ L3 locale wins over profile
  st := public.live_activity_session_step(s_ui);
  SELECT payload->'apns'->'payload'->'aps' INTO j FROM public.live_activity_sends WHERE session_id = s_ui
   ORDER BY state_version DESC LIMIT 1;
  n := n + 1;
  IF st = 'sent' AND j->'content-state'->>'lang' = 'en' AND j->'attributes'->>'lang' = 'en'
     AND (SELECT language FROM public.profiles WHERE user_id = u ORDER BY is_original DESC NULLS LAST, created_at LIMIT 1) = 'ar' THEN
    tap := tap || format(E'ok %s - fcm_tokens.locale en-GB wins over an ar profile: lang en\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - %s %s\n', n, st, j); END IF;
  UPDATE public.fcm_tokens SET locale = 'ar-EG' WHERE installation_id = 'k6-u-ios';
  n := n + 1;
  IF public.live_activity_lang(u, 'k6-u-ios') = 'ar' THEN
    tap := tap || format(E'ok %s - control: locale ar-EG on the same installation gives ar\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - locale ar not honoured\n', n); END IF;

  ------------------------------------------------------------------ L4 en / null profile -> 'en'
  UPDATE public.profiles SET language = NULL WHERE user_id = v;
  n := n + 1;
  IF public.live_activity_lang(v, 'k6-v-ios') = 'en' THEN
    tap := tap || format(E'ok %s - null profile language, null locale: en\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - null not en\n', n); END IF;
  UPDATE public.profiles SET language = 'en' WHERE user_id = v;
  n := n + 1;
  IF public.live_activity_lang(v, 'k6-v-ios') = 'en' AND public.live_activity_lang(v, 'no-such-install') = 'en' THEN
    tap := tap || format(E'ok %s - en profile: en (and with no token row)\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - en profile not en\n', n); END IF;

  ------------------------------------------------------------------ L5 a language change is not a state change
  SELECT last_state_version INTO ver FROM public.live_activity_sessions WHERE id = s_vi;
  SELECT count(*) INTO c FROM public.live_activity_sends WHERE session_id = s_vi;
  st := public.live_activity_session_step(s_vi);   -- profile went ar -> null -> en since the last send
  n := n + 1;
  IF st = 'unchanged' AND (SELECT last_state_version FROM public.live_activity_sessions WHERE id = s_vi) = ver
     AND (SELECT count(*) FROM public.live_activity_sends WHERE session_id = s_vi) = c THEN
    tap := tap || format(E'ok %s - profile language change alone: unchanged, state_version stays %s, no send\n', n, ver);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - %s\n', n, st); END IF;

  ------------------------------------------------------------------ L6 sessions RPC content.lang, live on read
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v, 'role', 'authenticated')::text, true);
  SET LOCAL ROLE authenticated;
  j := public.rpc_live_activity_sessions('k6-v-ios');
  RESET ROLE;
  n := n + 1;
  IF j->0->'content'->>'lang' = 'en' AND (SELECT last_content->>'lang' FROM public.live_activity_sessions WHERE id = s_vi) = 'ar' THEN
    tap := tap || format(E'ok %s - rpc_live_activity_sessions content.lang is the current en (stored content still ar)\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - %s\n', n, j); END IF;

  ------------------------------------------------------------------ L7 control: a real change still bumps
  INSERT INTO public.event_attendance (event_id, event_type, user_id, checked_in_at) VALUES (g, 'game', v, now());
  st := public.live_activity_session_step(s_vi);
  SELECT payload->'apns'->'payload'->'aps' INTO j FROM public.live_activity_sends WHERE session_id = s_vi
   ORDER BY state_version DESC LIMIT 1;
  n := n + 1;
  IF st = 'sent' AND (SELECT last_state_version FROM public.live_activity_sessions WHERE id = s_vi) = ver + 1
     AND j->'content-state'->>'lang' = 'en' THEN
    tap := tap || format(E'ok %s - control: check-in bumps to version %s and the update carries lang en\n', n, ver + 1);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - %s %s\n', n, st, j); END IF;

  ------------------------------------------------------------------ R ratings fixture: G casual, G2 training, M meetup
  UPDATE public.games SET game_type = 'casual' WHERE event_id = g;
  UPDATE public.games SET game_type = 'training' WHERE event_id = g2;
  FOR ev, et IN SELECT * FROM (VALUES (g, 'game'), (g2, 'game'), (m, 'meetup')) q LOOP
    UPDATE public.events SET creator_user_id = u, is_cancelled = false, cancelled_at = NULL,
           start_at = now() - interval '3 hours', end_at = now() - interval '2 hours' WHERE id = ev;
    DELETE FROM public.event_lifecycle WHERE event_id = ev;
    INSERT INTO public.event_lifecycle (event_id, event_type, state, actual_ended_at, closed_at, closed_reason)
    VALUES (ev, et, 'ended', now() - interval '2 hours', now() - interval '2 hours', 'played');
    DELETE FROM public.event_rating_prompts WHERE event_id = ev;
    DELETE FROM public.event_attendance WHERE event_id = ev;
    DELETE FROM public.event_attendance_finalizations WHERE event_id = ev;
    INSERT INTO public.event_attendance (event_id, event_type, user_id, outcome, finalized_at)
    VALUES (ev, et, p1, 'attended', now()), (ev, et, v, 'attended', now());
    INSERT INTO public.event_attendance_finalizations (event_id, finalized_at, finalized_by, auto)
    VALUES (ev, now(), u, false);
  END LOOP;

  FOR ev, et IN SELECT * FROM (VALUES (g, 'casual game'), (g2, 'training game'), (m, 'meetup')) q LOOP
    PERFORM set_config('request.jwt.claims', json_build_object('sub', u, 'role', 'authenticated')::text, true);
    SET LOCAL ROLE authenticated;
    j := public.rpc_rating_get(ev);
    PERFORM set_config('request.jwt.claims', json_build_object('sub', p1, 'role', 'authenticated')::text, true);
    k := public.rpc_rating_get(ev);
    RESET ROLE;
    n := n + 1;
    IF j->'is_organiser' = 'true'::jsonb THEN
      tap := tap || format(E'ok %s - %s: organiser gets is_organiser true (state %s)\n', n, et, j->>'state');
    ELSE bad := bad + 1; tap := tap || format(E'not ok %s - %s organiser %s\n', n, et, j); END IF;
    n := n + 1;
    IF k->'is_organiser' = 'false'::jsonb AND k->>'state' = 'not_started' THEN
      tap := tap || format(E'ok %s - %s: negative: participant gets is_organiser false\n', n, et);
    ELSE bad := bad + 1; tap := tap || format(E'not ok %s - %s participant %s\n', n, et, k); END IF;
    n := n + 1;
    -- venue is (as before) present only when the event has a venue
    IF k ?& ARRAY['state', 'opens_at', 'closes_at', 'read_only', 'dismissed', 'players', 'organiser']
       AND (k ? 'venue') = (SELECT venue_id IS NOT NULL FROM public.events WHERE id = ev) THEN
      tap := tap || format(E'ok %s - %s: every old key still present (%s)\n', n, et,
                           (SELECT string_agg(x, ',' ORDER BY x) FROM jsonb_object_keys(k) x));
    ELSE bad := bad + 1; tap := tap || format(E'not ok %s - %s keys %s\n', n, et, k); END IF;
  END LOOP;

  -- not_open path also carries it
  UPDATE public.events SET is_cancelled = true WHERE id = g2;
  PERFORM set_config('request.jwt.claims', json_build_object('sub', u, 'role', 'authenticated')::text, true);
  SET LOCAL ROLE authenticated;
  j := public.rpc_rating_get(g2);
  RESET ROLE;
  n := n + 1;
  IF j->>'state' IN ('not_open', 'not_eligible') AND j->'is_organiser' = 'true'::jsonb THEN
    tap := tap || format(E'ok %s - cancelled event (%s): is_organiser still returned\n', n, j->>'state');
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - %s\n', n, j); END IF;

  RAISE EXCEPTION E'\n1..%\n%# % failed', n, tap, bad;
END
$tap$;
