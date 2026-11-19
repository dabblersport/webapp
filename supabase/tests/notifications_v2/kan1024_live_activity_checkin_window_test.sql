-- KAN-1024: the Live Activity carries checkin_closes_at / checkin_open and pushes one update when check-in closes.
-- Run as postgres on wtncuzcskpigqpmnxwws after 20261119152820_kan1024_live_activity_checkin_window.sql.
-- One DO block ending in RAISE EXCEPTION: everything rolls back. Fixtures as kan1004_live_activity_test.sql:
-- game G = 96949cc9, V = 039a9d4a an active roster player (not checked in), one fake android installation.

DO $tap$
DECLARE
  tap text := ''; n int := 0; bad int := 0; ok boolean; b jsonb; st text; st2 text; k int; k2 int; j jsonb;
  v uuid := '039a9d4a-8c8d-48e1-8dff-327c1c615179';
  g uuid := '96949cc9-270e-4e61-9af4-8a9b296fb75e';
  vp uuid := 'de8a830c-c561-4528-8ba0-37b89bd37814';
  gid uuid; sid uuid; v_start timestamptz;
BEGIN
  SELECT id INTO gid FROM public.games WHERE event_id = g;
  v_start := date_trunc('second', now()) - interval '5 minutes';
  UPDATE public.events SET is_cancelled = false, cancelled_at = NULL, cancelled_reason = NULL,
         start_at = v_start, end_at = v_start + interval '60 minutes' WHERE id = g;
  DELETE FROM public.event_lifecycle WHERE event_id = g;
  DELETE FROM public.event_attendance WHERE event_id = g;
  DELETE FROM public.event_attendance_finalizations WHERE event_id = g;
  DELETE FROM public.game_roster WHERE game_id = gid AND user_id = v;
  INSERT INTO public.game_roster (game_id, profile_id, user_id, role, status) VALUES (gid, vp, v, 'player', 'active');
  DELETE FROM public.live_activity_sessions WHERE event_id = g;
  DELETE FROM public.live_activity_optouts WHERE user_id = v;
  DELETE FROM public.fcm_tokens WHERE user_id = v OR installation_id LIKE 'k1024-%';
  INSERT INTO public.fcm_tokens (user_id, installation_id, token, device_platform, locale)
  VALUES (v, 'k1024-v-and', 'k1024-tok-v-and', 'android', 'en');

  -- 1 start + 5 min: fields present, checkin_open true, closes_at = start + 15 min
  b := public.live_activity_build_state(g, v);
  n := n + 1; ok := (b->'content' ? 'checkin_closes_at') AND (b->'content' ? 'checkin_open')
                   AND (b->'content'->>'checkin_closes_at')::bigint = extract(epoch FROM v_start + interval '15 minutes')::bigint;
  IF NOT ok THEN bad := bad + 1; END IF;
  tap := tap || format(E'%s %s - checkin_closes_at = start+15m and checkin_open present (%s)\n', CASE WHEN ok THEN 'ok' ELSE 'not ok' END, n, b->'content');
  n := n + 1; ok := (b->'content'->>'checkin_open')::boolean AND b->>'state' = 'scheduled_time_running';
  IF NOT ok THEN bad := bad + 1; END IF;
  tap := tap || format(E'%s %s - start+5m: checkin_open true while state is %s\n', CASE WHEN ok THEN 'ok' ELSE 'not ok' END, n, b->>'state');

  -- session started at start+6m (close is then 9 min away, inside the 10-minute cap); due_at = just after close
  v_start := v_start - interval '1 minute';
  UPDATE public.events SET start_at = v_start, end_at = v_start + interval '60 minutes' WHERE id = g;
  PERFORM public.live_activity_plan_event(g);
  SELECT id INTO sid FROM public.live_activity_sessions WHERE event_id = g AND installation_id = 'k1024-v-and';
  st := public.live_activity_session_step(sid);
  n := n + 1; ok := st = 'sent' AND (SELECT due_at FROM public.live_activity_sessions WHERE id = sid) = v_start + interval '15 minutes 1 second';
  IF NOT ok THEN bad := bad + 1; END IF;
  tap := tap || format(E'%s %s - first step sent; due_at = close + 1s (%s)\n', CASE WHEN ok THEN 'ok' ELSE 'not ok' END, n,
                       (SELECT due_at FROM public.live_activity_sessions WHERE id = sid));

  -- 2 start + 20 min (6 + 14): checkin_open false
  UPDATE public.events SET start_at = v_start - interval '14 minutes', end_at = v_start + interval '46 minutes' WHERE id = g;
  b := public.live_activity_build_state(g, v);
  UPDATE public.live_activity_sessions SET last_basis = b->'basis', due_at = now() WHERE id = sid;
  n := n + 1; ok := NOT (b->'content'->>'checkin_open')::boolean;
  IF NOT ok THEN bad := bad + 1; END IF;
  tap := tap || format(E'%s %s - start+20m: checkin_open false\n', CASE WHEN ok THEN 'ok' ELSE 'not ok' END, n);

  -- the session's stored fingerprint = the same build with only checkin_open still true (the pre-close build),
  -- so the next step's change is the window closing and nothing else
  UPDATE public.live_activity_sessions SET last_fingerprint = md5(((b->'content') || '{"checkin_open": true}'::jsonb)::text
                                                                  || (b->'basis')::text) WHERE id = sid;

  -- 3 the sweep pushes exactly one new version at close, none on the next run
  SELECT count(*) INTO k FROM public.live_activity_sends WHERE session_id = sid;
  PERFORM public.live_activity_sweep();
  SELECT count(*) INTO k2 FROM public.live_activity_sends WHERE session_id = sid;
  SELECT to_jsonb(x) INTO j FROM public.live_activity_sends x WHERE session_id = sid ORDER BY state_version DESC LIMIT 1;
  n := n + 1; ok := k2 = k + 1 AND j->>'la_event' = 'update' AND (j->>'state_version')::int = 2
                   AND ((j #>> '{payload,data,content}')::jsonb - 'state_version' - 'lang') = (b->'content')
                   AND ((j #>> '{payload,data,content}')::jsonb->>'checkin_open')::boolean = false;
  IF NOT ok THEN bad := bad + 1; END IF;
  tap := tap || format(E'%s %s - sweep at close: one update, version 2, checkin_open false (%s -> %s)\n', CASE WHEN ok THEN 'ok' ELSE 'not ok' END, n, k, k2);
  UPDATE public.live_activity_sessions SET due_at = now() WHERE id = sid;
  PERFORM public.live_activity_sweep();
  SELECT count(*) INTO k FROM public.live_activity_sends WHERE session_id = sid;
  n := n + 1; ok := k = k2;
  IF NOT ok THEN bad := bad + 1; END IF;
  tap := tap || format(E'%s %s - next sweep: no new version (%s sends)\n', CASE WHEN ok THEN 'ok' ELSE 'not ok' END, n, k);

  RAISE EXCEPTION E'TAP 1..%\n%# % of % passed (rolled back)', n, tap, n - bad, n;
END
$tap$;
