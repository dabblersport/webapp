-- KAN-1004f: an ended session's 'end' send is claimed; other skips still hold. Live TAP-style test.
-- One DO block ending in RAISE EXCEPTION: everything rolls back, no pg_net request survives.
-- Fixtures: staging test user V with fake installations on the newest event; sends inserted directly as 'queued'.

DO $tap$
DECLARE
  tap text := ''; n int := 0; bad int := 0; ok boolean; k int; st text; ec text;
  v uuid := '039a9d4a-8c8d-48e1-8dff-327c1c615179';
  ev uuid; s_end uuid; s_stale uuid; s_opt uuid; r_end bigint; r_upd bigint; r_stale bigint; r_opt bigint;
BEGIN
  SELECT id INTO ev FROM public.events ORDER BY created_at DESC LIMIT 1;
  INSERT INTO public.live_activity_sessions (event_id, user_id, installation_id, platform, provider, status, ended_at, end_reason)
  VALUES (ev, v, 'kan1004f-t-ended', 'android', 'fcm_android_data', 'ended', now(), 'event_ended') RETURNING id INTO s_end;
  INSERT INTO public.live_activity_sessions (event_id, user_id, installation_id, platform, provider, status)
  VALUES (ev, v, 'kan1004f-t-stale', 'android', 'fcm_android_data', 'stale') RETURNING id INTO s_stale;
  INSERT INTO public.live_activity_sessions (event_id, user_id, installation_id, platform, provider, status, ended_at, end_reason)
  VALUES (ev, v, 'kan1004f-t-opt', 'android', 'fcm_android_data', 'ended', now(), 'opted_out') RETURNING id INTO s_opt;
  INSERT INTO public.live_activity_sends (session_id, state_version, la_event, state, payload, status, handoff)
  VALUES (s_end, 1, 'end', 'ended', '{}', 'queued', true) RETURNING id INTO r_end;
  INSERT INTO public.live_activity_sends (session_id, state_version, la_event, state, payload, status, handoff)
  VALUES (s_end, 2, 'update', 'x', '{}', 'queued', true) RETURNING id INTO r_upd;
  INSERT INTO public.live_activity_sends (session_id, state_version, la_event, state, payload, status, handoff)
  VALUES (s_stale, 1, 'end', 'ended', '{}', 'queued', true) RETURNING id INTO r_stale;
  INSERT INTO public.live_activity_sends (session_id, state_version, la_event, state, payload, status, handoff)
  VALUES (s_opt, 1, 'end', 'ended', '{}', 'queued', true) RETURNING id INTO r_opt;

  -- (a) ended session's 'end' is claimed and returned to the poster
  SELECT count(*) INTO k FROM public.live_activity_claim(ARRAY[r_end]) c WHERE c.id = r_end;
  SELECT status INTO st FROM public.live_activity_sends WHERE id = r_end;
  n := n + 1; ok := k = 1 AND st = 'sending'; IF NOT ok THEN bad := bad + 1; END IF;
  tap := tap || format(E'%s %s - ended session end send claimed (returned=%s status=%s)\n', CASE WHEN ok THEN 'ok' ELSE 'not ok' END, n, k, st);

  -- (b) ended session's 'update' is still skipped
  SELECT count(*) INTO k FROM public.live_activity_claim(ARRAY[r_upd]);
  SELECT status, error_class INTO st, ec FROM public.live_activity_sends WHERE id = r_upd;
  n := n + 1; ok := k = 0 AND st = 'skipped' AND ec = 'session_ended'; IF NOT ok THEN bad := bad + 1; END IF;
  tap := tap || format(E'%s %s - ended session update send skipped (status=%s %s)\n', CASE WHEN ok THEN 'ok' ELSE 'not ok' END, n, st, ec);

  -- (c) stale session's 'end' is still skipped
  SELECT count(*) INTO k FROM public.live_activity_claim(ARRAY[r_stale]);
  SELECT status, error_class INTO st, ec FROM public.live_activity_sends WHERE id = r_stale;
  n := n + 1; ok := k = 0 AND st = 'skipped' AND ec = 'session_stale'; IF NOT ok THEN bad := bad + 1; END IF;
  tap := tap || format(E'%s %s - stale session end send skipped (status=%s %s)\n', CASE WHEN ok THEN 'ok' ELSE 'not ok' END, n, st, ec);

  -- (d) opted_out session's 'end' is still skipped
  SELECT count(*) INTO k FROM public.live_activity_claim(ARRAY[r_opt]);
  SELECT status, error_class INTO st, ec FROM public.live_activity_sends WHERE id = r_opt;
  n := n + 1; ok := k = 0 AND st = 'skipped' AND ec = 'session_ended'; IF NOT ok THEN bad := bad + 1; END IF;
  tap := tap || format(E'%s %s - opted_out session end send skipped (status=%s %s)\n', CASE WHEN ok THEN 'ok' ELSE 'not ok' END, n, st, ec);

  RAISE EXCEPTION E'TAP 1..%\n%# % of % passed (rolled back)', n, tap, n - bad, n;
END
$tap$;
