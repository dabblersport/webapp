-- KAN-1004c Live Activity sender: live TAP-style test.
-- Run as postgres on wtncuzcskpigqpmnxwws after 20261118145644_kan1004c_live_activity_sender.sql and
-- 20261118150447_kan1004d_live_activity_sender_fixes.sql (T6..T14 cover the KAN-1004d fixes).
-- One DO block ending in RAISE EXCEPTION: everything rolls back, so no pg_net request is ever sent.
-- Fixtures: staging test user V (jidep35093@iconcubic.com) with fake installations kan1004c-t-android / -ios on
-- the newest event. Hand-offs are counted as rows added to net.http_request_queue for send-live-activity.

DO $tap$
DECLARE
  tap text := ''; n int := 0; bad int := 0;
  v uuid := '039a9d4a-8c8d-48e1-8dff-327c1c615179';
  ev uuid; sa uuid; si uuid; id_a bigint; id_i bigint; id_old bigint; id_cap bigint; q0 int; q int; st text; h boolean;
  fn_url text := 'https://wtncuzcskpigqpmnxwws.supabase.co/functions/v1/send-live-activity';
  ok boolean; sb uuid; sc uuid; ids bigint[]; k int; r1 bigint; r2 bigint; att int; nb timestamptz; pl jsonb;
BEGIN
  SELECT id INTO ev FROM public.events ORDER BY created_at DESC LIMIT 1;
  INSERT INTO public.live_activity_sessions (event_id, user_id, installation_id, platform, provider, status)
  VALUES (ev, v, 'kan1004c-t-android', 'android', 'fcm_android_data', 'active') RETURNING id INTO sa;
  INSERT INTO public.live_activity_sessions (event_id, user_id, installation_id, platform, provider, status)
  VALUES (ev, v, 'kan1004c-t-ios', 'iOS', 'fcm_apns_live_activity', 'active') RETURNING id INTO si;
  UPDATE public.live_activity_config SET ios_sender_enabled = false;
  -- an old stub row, as every row before this migration
  INSERT INTO public.live_activity_sends (session_id, state_version, la_event, state, payload, status, result_at)
  VALUES (sa, 0, 'start', 'checkin_open', '{}', 'unsent: no credentials', now()) RETURNING id INTO id_old;
  SELECT count(*) INTO q0 FROM net.http_request_queue WHERE http_request_queue.url = fn_url;

  -- T1 android row is handed to the sender ----------------------------------------------------------------------
  id_a := public.live_activity_enqueue(sa, 'update', 'checkin_open', jsonb_build_object('state', 'checkin_open'));
  SELECT status, handoff INTO st, h FROM public.live_activity_sends WHERE id = id_a;
  SELECT count(*) INTO q FROM net.http_request_queue WHERE http_request_queue.url = fn_url;
  n := n + 1; ok := st = 'queued' AND h AND q = q0 + 1;
  IF NOT ok THEN bad := bad + 1; END IF;
  tap := tap || format(E'%s %s - android row queued, handoff, one post (status=%s handoff=%s posts=%s)\n',
                       CASE WHEN ok THEN 'ok' ELSE 'not ok' END, n, st, h, q - q0);
  n := n + 1; ok := EXISTS (SELECT 1 FROM net.http_request_queue r WHERE r.url = fn_url
                             AND convert_from(r.body, 'UTF8')::jsonb -> 'send_ids' @> to_jsonb(id_a));
  IF NOT ok THEN bad := bad + 1; END IF;
  tap := tap || format(E'%s %s - the post body carries the send id\n', CASE WHEN ok THEN 'ok' ELSE 'not ok' END, n);

  -- T2 iOS row stays unsent while the flag is off; negative control: flag on hands it off ------------------------
  id_i := public.live_activity_enqueue(si, 'start', 'checkin_open', jsonb_build_object('state', 'checkin_open'));
  -- start without push-to-start is 'local' and returns NULL; use an update with a token instead
  UPDATE public.live_activity_sessions SET push_token = 'kan1004c-fake' WHERE id = si;
  id_i := public.live_activity_enqueue(si, 'update', 'checkin_open', jsonb_build_object('state', 'checkin_open'));
  SELECT status, handoff INTO st, h FROM public.live_activity_sends WHERE id = id_i;
  SELECT count(*) INTO q FROM net.http_request_queue WHERE http_request_queue.url = fn_url;
  n := n + 1; ok := st = 'unsent: no credentials' AND NOT h AND q = q0 + 1;
  IF NOT ok THEN bad := bad + 1; END IF;
  tap := tap || format(E'%s %s - ios row unsent: no credentials, no post (status=%s)\n', CASE WHEN ok THEN 'ok' ELSE 'not ok' END, n, st);
  UPDATE public.live_activity_config SET ios_sender_enabled = true;
  id_i := public.live_activity_enqueue(si, 'update', 'checkin_open', jsonb_build_object('state', 'checkin_open'));
  SELECT status, handoff INTO st, h FROM public.live_activity_sends WHERE id = id_i;
  n := n + 1; ok := st = 'queued' AND h;
  IF NOT ok THEN bad := bad + 1; END IF;
  tap := tap || format(E'%s %s - negative control: flag on, ios row is handed off (status=%s)\n', CASE WHEN ok THEN 'ok' ELSE 'not ok' END, n, st);
  UPDATE public.live_activity_config SET ios_sender_enabled = false;
  UPDATE public.live_activity_sends SET status = 'unsent: no credentials', handoff = false WHERE id = id_i;

  -- T3 old unsent rows are not replayed --------------------------------------------------------------------------
  PERFORM public.live_activity_dispatch();
  n := n + 1; ok := NOT EXISTS (SELECT 1 FROM net.http_request_queue r WHERE r.url = fn_url
                                 AND convert_from(r.body, 'UTF8')::jsonb -> 'send_ids' @> to_jsonb(id_old))
               AND (SELECT status FROM public.live_activity_sends WHERE id = id_old) = 'unsent: no credentials';
  IF NOT ok THEN bad := bad + 1; END IF;
  tap := tap || format(E'%s %s - old unsent row not replayed by dispatch\n', CASE WHEN ok THEN 'ok' ELSE 'not ok' END, n);
  -- negative control: the same row made queued + handoff IS picked up
  UPDATE public.live_activity_sends SET status = 'queued', handoff = true, dispatched_at = NULL WHERE id = id_old;
  PERFORM public.live_activity_dispatch();
  n := n + 1; ok := EXISTS (SELECT 1 FROM net.http_request_queue r WHERE r.url = fn_url
                             AND convert_from(r.body, 'UTF8')::jsonb -> 'send_ids' @> to_jsonb(id_old));
  IF NOT ok THEN bad := bad + 1; END IF;
  tap := tap || format(E'%s %s - negative control: a queued handoff row is dispatched\n', CASE WHEN ok THEN 'ok' ELSE 'not ok' END, n);

  -- T4 bound: over the per-transaction cap the row waits for dispatch --------------------------------------------
  PERFORM set_config('live_activity.dispatch_limit', '0', true);
  SELECT count(*) INTO q0 FROM net.http_request_queue WHERE http_request_queue.url = fn_url;
  id_cap := public.live_activity_enqueue(sa, 'update', 'checked_in', jsonb_build_object('state', 'checked_in'));
  SELECT count(*) INTO q FROM net.http_request_queue WHERE http_request_queue.url = fn_url;
  SELECT status, handoff INTO st, h FROM public.live_activity_sends WHERE id = id_cap;
  n := n + 1; ok := q = q0 AND st = 'queued' AND h;
  IF NOT ok THEN bad := bad + 1; END IF;
  tap := tap || format(E'%s %s - over the cap: no direct post, row left queued for dispatch\n', CASE WHEN ok THEN 'ok' ELSE 'not ok' END, n);
  PERFORM set_config('live_activity.dispatch_limit', '', true);

  -- T5 nothing is readable by clients ----------------------------------------------------------------------------
  n := n + 1; ok := NOT has_table_privilege('authenticated', 'public.live_activity_sends', 'SELECT')
                AND NOT has_table_privilege('anon', 'public.live_activity_sends', 'SELECT')
                AND NOT has_table_privilege('authenticated', 'public.live_activity_config', 'SELECT')
                AND NOT has_table_privilege('anon', 'public.live_activity_config', 'SELECT');
  IF NOT ok THEN bad := bad + 1; END IF;
  tap := tap || format(E'%s %s - no client grant on the queue or the config\n', CASE WHEN ok THEN 'ok' ELSE 'not ok' END, n);
  n := n + 1;
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  BEGIN
    PERFORM count(*) FROM public.live_activity_sends; ok := false;
  EXCEPTION WHEN insufficient_privilege THEN ok := true;
  END;
  BEGIN
    PERFORM public.live_activity_dispatch(); ok := false;
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  EXECUTE 'RESET ROLE';
  IF NOT ok THEN bad := bad + 1; END IF;
  tap := tap || format(E'%s %s - as the test user: select on sends and dispatch() refused\n', CASE WHEN ok THEN 'ok' ELSE 'not ok' END, n);
  n := n + 1; ok := NOT has_function_privilege('authenticated', 'public.live_activity_post(bigint[])', 'EXECUTE')
                AND NOT has_function_privilege('anon', 'public.live_activity_send(bigint)', 'EXECUTE')
                AND NOT has_function_privilege('anon', 'public.live_activity_retry(bigint,text)', 'EXECUTE');
  IF NOT ok THEN bad := bad + 1; END IF;
  tap := tap || format(E'%s %s - sender functions not executable by anon/authenticated\n', CASE WHEN ok THEN 'ok' ELSE 'not ok' END, n);

  -- T6 claim is atomic -------------------------------------------------------------------------------------------
  INSERT INTO public.live_activity_sends (session_id, state_version, la_event, state, payload, status, handoff)
  VALUES (sa, 1001, 'update', 'x', '{}', 'queued', true) RETURNING id INTO r1;
  SELECT count(*) INTO k FROM public.live_activity_claim(ARRAY[r1]);
  SELECT status, attempts INTO st, att FROM public.live_activity_sends WHERE id = r1;
  n := n + 1; ok := k = 1 AND st = 'sending' AND att = 1;
  IF NOT ok THEN bad := bad + 1; END IF;
  tap := tap || format(E'%s %s - first claim takes the row: sending, attempts 1 (claimed=%s)\n', CASE WHEN ok THEN 'ok' ELSE 'not ok' END, n, k);
  SELECT count(*) INTO k FROM public.live_activity_claim(ARRAY[r1]);
  n := n + 1; ok := k = 0 AND (SELECT attempts FROM public.live_activity_sends WHERE id = r1) = 1;
  IF NOT ok THEN bad := bad + 1; END IF;
  tap := tap || format(E'%s %s - second claim of the same id returns nothing (claimed=%s)\n', CASE WHEN ok THEN 'ok' ELSE 'not ok' END, n, k);

  -- T7 20-id cap (claim and post) -------------------------------------------------------------------------------
  WITH ins AS (INSERT INTO public.live_activity_sends (session_id, state_version, la_event, state, payload, status, handoff)
               SELECT sa, 1100 + g, 'update', 'x', '{}', 'queued', true FROM generate_series(1, 25) g RETURNING id)
  SELECT array_agg(id ORDER BY id) INTO ids FROM ins;
  SELECT count(*) INTO k FROM public.live_activity_claim(ids);
  n := n + 1; ok := k = 20 AND (SELECT count(*) FROM public.live_activity_sends WHERE id = ANY (ids) AND status = 'queued') = 5;
  IF NOT ok THEN bad := bad + 1; END IF;
  tap := tap || format(E'%s %s - claim of 25 ids takes 20, leaves 5 queued (claimed=%s)\n', CASE WHEN ok THEN 'ok' ELSE 'not ok' END, n, k);
  SELECT count(*) INTO k FROM public.live_activity_claim(ids);
  n := n + 1; ok := k = 5;
  IF NOT ok THEN bad := bad + 1; END IF;
  tap := tap || format(E'%s %s - negative control: the next claim takes the remaining 5 (claimed=%s)\n', CASE WHEN ok THEN 'ok' ELSE 'not ok' END, n, k);
  SELECT count(*) INTO q0 FROM net.http_request_queue WHERE http_request_queue.url = fn_url;
  PERFORM public.live_activity_post(ids);
  n := n + 1; ok := (SELECT count(*) FROM net.http_request_queue r WHERE r.url = fn_url) = q0 + 2
       AND (SELECT max(jsonb_array_length(convert_from(r.body, 'UTF8')::jsonb -> 'send_ids')) FROM net.http_request_queue r
             WHERE r.url = fn_url AND convert_from(r.body, 'UTF8')::jsonb -> 'send_ids' @> to_jsonb(ids[1])) = 20;
  IF NOT ok THEN bad := bad + 1; END IF;
  tap := tap || format(E'%s %s - a post of 25 ids is two requests, the largest 20\n', CASE WHEN ok THEN 'ok' ELSE 'not ok' END, n);

  -- T8 stuck 'sending' recovered ---------------------------------------------------------------------------------
  UPDATE public.live_activity_sends SET status = 'sending', claimed_at = now() - interval '6 minutes', attempts = 1 WHERE id = ids[1];
  UPDATE public.live_activity_sends SET status = 'sending', claimed_at = now() - interval '6 minutes', attempts = 3 WHERE id = ids[2];
  UPDATE public.live_activity_sends SET status = 'sending', claimed_at = now() - interval '1 minute', attempts = 1 WHERE id = ids[3];
  PERFORM public.live_activity_dispatch();
  n := n + 1; ok := (SELECT status FROM public.live_activity_sends WHERE id = ids[1]) = 'queued'
                AND (SELECT status FROM public.live_activity_sends WHERE id = ids[2]) = 'failed';
  IF NOT ok THEN bad := bad + 1; END IF;
  tap := tap || format(E'%s %s - stuck sending: back to queued, or failed at 3 attempts\n', CASE WHEN ok THEN 'ok' ELSE 'not ok' END, n);
  n := n + 1; ok := (SELECT status FROM public.live_activity_sends WHERE id = ids[3]) = 'sending';
  IF NOT ok THEN bad := bad + 1; END IF;
  tap := tap || format(E'%s %s - negative control: a fresh claim (1 min) is left sending\n', CASE WHEN ok THEN 'ok' ELSE 'not ok' END, n);

  -- T9 retry schedule ---------------------------------------------------------------------------------------------
  INSERT INTO public.live_activity_sends (session_id, state_version, la_event, state, payload, status, handoff)
  VALUES (sa, 1200, 'update', 'x', '{}', 'queued', true) RETURNING id INTO r2;
  PERFORM public.live_activity_claim(ARRAY[r2]);
  PERFORM public.live_activity_retry(r2, 'unavailable');
  SELECT status, not_before INTO st, nb FROM public.live_activity_sends WHERE id = r2;
  n := n + 1; ok := st = 'queued' AND nb = now() + interval '1 minute';
  IF NOT ok THEN bad := bad + 1; END IF;
  tap := tap || format(E'%s %s - retry after attempt 1: queued, not_before +1 min\n', CASE WHEN ok THEN 'ok' ELSE 'not ok' END, n);
  SELECT count(*) INTO k FROM public.live_activity_claim(ARRAY[r2]);
  SELECT count(*) INTO q0 FROM net.http_request_queue WHERE http_request_queue.url = fn_url;
  PERFORM public.live_activity_dispatch();
  n := n + 1; ok := k = 0 AND NOT EXISTS (SELECT 1 FROM net.http_request_queue r WHERE r.url = fn_url
                     AND convert_from(r.body, 'UTF8')::jsonb -> 'send_ids' @> to_jsonb(r2));
  IF NOT ok THEN bad := bad + 1; END IF;
  tap := tap || format(E'%s %s - before not_before: no claim and no dispatch\n', CASE WHEN ok THEN 'ok' ELSE 'not ok' END, n);
  UPDATE public.live_activity_sends SET not_before = now() - interval '1 second' WHERE id = r2;
  SELECT count(*) INTO k FROM public.live_activity_claim(ARRAY[r2]);
  PERFORM public.live_activity_retry(r2, 'unavailable');
  SELECT status, not_before, attempts INTO st, nb, att FROM public.live_activity_sends WHERE id = r2;
  n := n + 1; ok := k = 1 AND st = 'queued' AND att = 2 AND nb = now() + interval '5 minutes';
  IF NOT ok THEN bad := bad + 1; END IF;
  tap := tap || format(E'%s %s - negative control: after not_before it is claimed; attempt 2 -> +5 min\n', CASE WHEN ok THEN 'ok' ELSE 'not ok' END, n);
  UPDATE public.live_activity_sends SET not_before = NULL WHERE id = r2;
  PERFORM public.live_activity_claim(ARRAY[r2]);
  PERFORM public.live_activity_retry(r2, 'unavailable');
  SELECT status, attempts INTO st, att FROM public.live_activity_sends WHERE id = r2;
  n := n + 1; ok := st = 'failed' AND att = 3;
  IF NOT ok THEN bad := bad + 1; END IF;
  tap := tap || format(E'%s %s - attempt 3 fails the row (status=%s attempts=%s)\n', CASE WHEN ok THEN 'ok' ELSE 'not ok' END, n, st, att);

  -- T10 token_rejected marks the session stale --------------------------------------------------------------------
  INSERT INTO public.live_activity_sessions (event_id, user_id, installation_id, platform, provider, status)
  VALUES (ev, v, 'kan1004d-t-b', 'android', 'fcm_android_data', 'active') RETURNING id INTO sb;
  INSERT INTO public.live_activity_sends (session_id, state_version, la_event, state, payload, status)
  VALUES (sb, 1, 'update', 'x', '{}', 'queued') RETURNING id INTO r1;
  PERFORM public.live_activity_claim(ARRAY[r1]);
  PERFORM public.live_activity_record_result(r1, 'sent', NULL);
  n := n + 1; ok := (SELECT status FROM public.live_activity_sessions WHERE id = sb) = 'active';
  IF NOT ok THEN bad := bad + 1; END IF;
  tap := tap || format(E'%s %s - negative control: sent leaves the session active\n', CASE WHEN ok THEN 'ok' ELSE 'not ok' END, n);
  INSERT INTO public.live_activity_sends (session_id, state_version, la_event, state, payload, status)
  VALUES (sb, 2, 'update', 'x', '{}', 'queued') RETURNING id INTO r1;
  PERFORM public.live_activity_claim(ARRAY[r1]);
  PERFORM public.live_activity_record_result(r1, 'token_rejected', 'unregistered');
  n := n + 1; ok := (SELECT status FROM public.live_activity_sessions WHERE id = sb) = 'stale'
                AND (SELECT status FROM public.live_activity_sends WHERE id = r1) = 'token_rejected';
  IF NOT ok THEN bad := bad + 1; END IF;
  tap := tap || format(E'%s %s - token_rejected marks the session stale\n', CASE WHEN ok THEN 'ok' ELSE 'not ok' END, n);

  -- T11 inactive session skipped (stale sb, ended/opted out sc) --------------------------------------------------
  INSERT INTO public.live_activity_sessions (event_id, user_id, installation_id, platform, provider, status, ended_at, end_reason)
  VALUES (ev, v, 'kan1004d-t-c', 'android', 'fcm_android_data', 'ended', now(), 'opted_out') RETURNING id INTO sc;
  INSERT INTO public.live_activity_sends (session_id, state_version, la_event, state, payload, status)
  VALUES (sb, 3, 'update', 'x', '{}', 'queued') RETURNING id INTO r1;
  INSERT INTO public.live_activity_sends (session_id, state_version, la_event, state, payload, status)
  VALUES (sc, 1, 'update', 'x', '{}', 'queued') RETURNING id INTO r2;
  SELECT count(*) INTO k FROM public.live_activity_claim(ARRAY[r1, r2]);
  n := n + 1; ok := k = 0 AND (SELECT count(*) FROM public.live_activity_sends WHERE id IN (r1, r2) AND status = 'skipped') = 2;
  IF NOT ok THEN bad := bad + 1; END IF;
  tap := tap || format(E'%s %s - stale and opted-out sessions: skipped, not claimed (claimed=%s)\n', CASE WHEN ok THEN 'ok' ELSE 'not ok' END, n, k);

  -- T12 re-post window -------------------------------------------------------------------------------------------
  INSERT INTO public.live_activity_sends (session_id, state_version, la_event, state, payload, status, handoff, dispatched_at)
  VALUES (sa, 1300, 'update', 'x', '{}', 'queued', true, now() - interval '1 minute') RETURNING id INTO r1;
  PERFORM public.live_activity_dispatch();
  n := n + 1; ok := NOT EXISTS (SELECT 1 FROM net.http_request_queue r WHERE r.url = fn_url
                     AND convert_from(r.body, 'UTF8')::jsonb -> 'send_ids' @> to_jsonb(r1));
  IF NOT ok THEN bad := bad + 1; END IF;
  tap := tap || format(E'%s %s - posted 1 min ago: not re-posted\n', CASE WHEN ok THEN 'ok' ELSE 'not ok' END, n);
  UPDATE public.live_activity_sends SET dispatched_at = now() - interval '6 minutes' WHERE id = r1;
  PERFORM public.live_activity_dispatch();
  n := n + 1; ok := EXISTS (SELECT 1 FROM net.http_request_queue r WHERE r.url = fn_url
                     AND convert_from(r.body, 'UTF8')::jsonb -> 'send_ids' @> to_jsonb(r1));
  IF NOT ok THEN bad := bad + 1; END IF;
  tap := tap || format(E'%s %s - posted 6 min ago: re-posted\n', CASE WHEN ok THEN 'ok' ELSE 'not ok' END, n);

  -- T13 android payload ------------------------------------------------------------------------------------------
  r1 := public.live_activity_enqueue(sa, 'update', 'checked_in', jsonb_build_object('state', 'checked_in'));
  SELECT payload INTO pl FROM public.live_activity_sends WHERE id = r1;
  n := n + 1; ok := (SELECT array_agg(k2 ORDER BY k2) FROM jsonb_object_keys(pl) k2) = ARRAY['android', 'data']
    AND (SELECT array_agg(k2 ORDER BY k2) FROM jsonb_object_keys(pl -> 'android') k2) = ARRAY['collapse_key', 'priority', 'ttl']
    AND pl #>> '{android,ttl}' = '3600s' AND pl #>> '{android,collapse_key}' = 'la:' || sa::text
    AND (SELECT array_agg(k2 ORDER BY k2) FROM jsonb_object_keys(pl -> 'data') k2)
        = ARRAY['content', 'la_event', 'lang', 'session_id', 'state_version', 'type']
    AND NOT EXISTS (SELECT 1 FROM jsonb_each(pl -> 'data') e WHERE jsonb_typeof(e.value) <> 'string');
  IF NOT ok THEN bad := bad + 1; END IF;
  tap := tap || format(E'%s %s - payload: exact keys, string data, ttl 3600s, collapse key la:<session>\n', CASE WHEN ok THEN 'ok' ELSE 'not ok' END, n);

  -- T14 grants, with a real negative control ---------------------------------------------------------------------
  n := n + 1; ok := NOT has_function_privilege('authenticated', 'public.live_activity_claim(bigint[])', 'EXECUTE')
                AND NOT has_function_privilege('anon', 'public.live_activity_claim(bigint[])', 'EXECUTE')
                AND NOT has_function_privilege('authenticated', 'public.live_activity_record_result(bigint,text,text)', 'EXECUTE')
                AND has_function_privilege('service_role', 'public.live_activity_claim(bigint[])', 'EXECUTE')
                AND has_function_privilege('service_role', 'public.live_activity_record_result(bigint,text,text)', 'EXECUTE');
  IF NOT ok THEN bad := bad + 1; END IF;
  tap := tap || format(E'%s %s - claim/record_result: service_role only\n', CASE WHEN ok THEN 'ok' ELSE 'not ok' END, n);
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  ok := true;
  BEGIN PERFORM public.live_activity_claim(ARRAY[r1]); ok := false; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  BEGIN PERFORM public.live_activity_record_result(r1, 'sent', NULL); ok := false; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  BEGIN PERFORM 1 FROM public.live_activity_sessions LIMIT 1; ok := false; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  EXECUTE 'RESET ROLE';
  n := n + 1;
  IF NOT ok THEN bad := bad + 1; END IF;
  tap := tap || format(E'%s %s - as authenticated: claim, record_result, select sessions refused\n', CASE WHEN ok THEN 'ok' ELSE 'not ok' END, n);
  GRANT EXECUTE ON FUNCTION public.live_activity_claim(bigint[]) TO authenticated;
  EXECUTE 'SET LOCAL ROLE authenticated';
  BEGIN PERFORM public.live_activity_claim(ARRAY[r1]); ok := true; EXCEPTION WHEN insufficient_privilege THEN ok := false; END;
  EXECUTE 'RESET ROLE';
  REVOKE EXECUTE ON FUNCTION public.live_activity_claim(bigint[]) FROM authenticated;
  n := n + 1;
  IF NOT ok THEN bad := bad + 1; END IF;
  tap := tap || format(E'%s %s - negative control: with a grant the same call succeeds (probe can fail)\n', CASE WHEN ok THEN 'ok' ELSE 'not ok' END, n);

  RAISE EXCEPTION E'TAP 1..%\n%# % of % passed (rolled back)', n, tap, n - bad, n;
END
$tap$;
