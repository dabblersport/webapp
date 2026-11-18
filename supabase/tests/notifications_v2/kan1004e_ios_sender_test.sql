-- KAN-1004e iOS Live Activity sender: live TAP-style test.
-- Run as postgres on wtncuzcskpigqpmnxwws after 20261118180920_kan1004e_live_activity_ios_topic.sql.
-- One DO block ending in RAISE EXCEPTION: everything rolls back, no pg_net request is ever sent.
-- The iOS apns block is built in SQL (live_activity_enqueue); the function only adds message.token and
-- apns.live_activity_token, so the shape is asserted here at the layer that builds it.
DO $tap$
DECLARE
  tap text := ''; n int := 0; bad int := 0; ok boolean;
  v uuid := '039a9d4a-8c8d-48e1-8dff-327c1c615179';
  inst text := 'kan1004e-t-ios'; ev uuid; si uuid; id_s bigint; id_u bigint; id_e bigint; q0 int; q int;
  ps jsonb; pu jsonb; pe jsonb; st text; h boolean; sst text;
  fn_url text := 'https://wtncuzcskpigqpmnxwws.supabase.co/functions/v1/send-live-activity';
  hdr jsonb := '{"apns-push-type":"liveactivity","apns-priority":"10","apns-topic":"app.dabbler.pro.push-type.liveactivity"}';
BEGIN
  SELECT id INTO ev FROM public.events ORDER BY created_at DESC LIMIT 1;
  INSERT INTO public.live_activity_push_to_start (user_id, installation_id, token) VALUES (v, inst, 'kan1004e-fake-pts')
    ON CONFLICT (user_id, installation_id) DO UPDATE SET token = excluded.token;
  INSERT INTO public.live_activity_sessions (event_id, user_id, installation_id, platform, provider, status)
  VALUES (ev, v, inst, 'iOS', 'fcm_apns_live_activity', 'planned') RETURNING id INTO si;
  UPDATE public.live_activity_config SET ios_sender_enabled = false;
  SELECT count(*) INTO q0 FROM net.http_request_queue r WHERE r.url = fn_url;

  id_s := public.live_activity_enqueue(si, 'start', 'checkin_open',
            jsonb_build_object('state', 'checkin_open', 'event_id', ev::text, 'event_type', 'game', 'title', 'T'));
  UPDATE public.live_activity_sessions SET push_token = 'kan1004e-fake-pat' WHERE id = si;
  id_u := public.live_activity_enqueue(si, 'update', 'checked_in', jsonb_build_object('state', 'checked_in'));
  id_e := public.live_activity_enqueue(si, 'end', 'ended', jsonb_build_object('state', 'ended', 'end_reason', 'event_ended'));
  SELECT payload INTO ps FROM public.live_activity_sends WHERE id = id_s;
  SELECT payload INTO pu FROM public.live_activity_sends WHERE id = id_u;
  SELECT payload INTO pe FROM public.live_activity_sends WHERE id = id_e;

  n := n + 1; ok := ps->'apns'->'headers' = hdr AND pu->'apns'->'headers' = hdr AND pe->'apns'->'headers' = hdr;
  IF NOT ok THEN bad := bad + 1; END IF;
  tap := tap || format(E'%s %s - apns headers (push-type, priority 10, topic) on start/update/end\n', CASE WHEN ok THEN 'ok' ELSE 'not ok' END, n);

  n := n + 1; ok := ps->'apns'->'payload'->'aps'->>'event' = 'start' AND pu->'apns'->'payload'->'aps'->>'event' = 'update'
                    AND pe->'apns'->'payload'->'aps'->>'event' = 'end';
  IF NOT ok THEN bad := bad + 1; END IF;
  tap := tap || format(E'%s %s - aps.event matches la_event\n', CASE WHEN ok THEN 'ok' ELSE 'not ok' END, n);

  n := n + 1; ok := ps->'apns'->'payload'->'aps'->>'attributes-type' = 'DabblerActivityAttributes'
                    AND ps->'apns'->'payload'->'aps'->'attributes'->>'event_id' = ev::text
                    AND ps->'apns'->'payload'->'aps'->'alert' ? 'title' AND ps->'apns'->'payload'->'aps'->'alert' ? 'body'
                    AND (ps->'apns'->'payload'->'aps'->>'input-push-token')::int = 1;
  IF NOT ok THEN bad := bad + 1; END IF;
  tap := tap || format(E'%s %s - start carries attributes-type, attributes, alert, input-push-token\n', CASE WHEN ok THEN 'ok' ELSE 'not ok' END, n);

  n := n + 1; ok := NOT (pu->'apns'->'payload'->'aps' ? 'attributes-type') AND NOT (pu->'apns'->'payload'->'aps' ? 'alert')
                    AND NOT (pe->'apns'->'payload'->'aps' ? 'alert');
  IF NOT ok THEN bad := bad + 1; END IF;
  tap := tap || format(E'%s %s - update/end are silent: no alert, no attributes\n', CASE WHEN ok THEN 'ok' ELSE 'not ok' END, n);

  n := n + 1; ok := ps->'apns'->'payload'->'aps'->'content-state' ? 'lang' AND pu->'apns'->'payload'->'aps'->'content-state' ? 'lang'
                    AND jsonb_typeof(pu->'apns'->'payload'->'aps'->'timestamp') = 'number'
                    AND (pu->'apns'->'payload'->'aps'->>'timestamp')::bigint BETWEEN extract(epoch FROM now())::bigint - 60 AND extract(epoch FROM now())::bigint + 60;
  IF NOT ok THEN bad := bad + 1; END IF;
  tap := tap || format(E'%s %s - content-state has lang; timestamp is Unix seconds\n', CASE WHEN ok THEN 'ok' ELSE 'not ok' END, n);

  n := n + 1; ok := jsonb_typeof(pe->'apns'->'payload'->'aps'->'dismissal-date') = 'number'
                    AND NOT (ps->'apns'->'payload'->'aps' ? 'dismissal-date') AND NOT (pu->'apns'->'payload'->'aps' ? 'dismissal-date');
  IF NOT ok THEN bad := bad + 1; END IF;
  tap := tap || format(E'%s %s - dismissal-date only on end\n', CASE WHEN ok THEN 'ok' ELSE 'not ok' END, n);

  n := n + 1; ok := NOT (ps ? 'notification') AND NOT (ps::text LIKE '%kan1004e-fake%') AND NOT (pu::text LIKE '%kan1004e-fake%');
  IF NOT ok THEN bad := bad + 1; END IF;
  tap := tap || format(E'%s %s - no top-level notification; stored payload holds no token\n', CASE WHEN ok THEN 'ok' ELSE 'not ok' END, n);

  SELECT count(*) INTO q FROM net.http_request_queue r WHERE r.url = fn_url;
  n := n + 1; ok := q = q0 AND NOT EXISTS (SELECT 1 FROM public.live_activity_sends WHERE id IN (id_s, id_u, id_e)
                                             AND (status <> 'unsent: no credentials' OR handoff));
  IF NOT ok THEN bad := bad + 1; END IF;
  tap := tap || format(E'%s %s - flag off: rows unsent: no credentials, no post (posts=%s)\n', CASE WHEN ok THEN 'ok' ELSE 'not ok' END, n, q - q0);

  -- negative control: flag on hands an iOS row to the function
  UPDATE public.live_activity_config SET ios_sender_enabled = true;
  id_u := public.live_activity_enqueue(si, 'update', 'checked_in', jsonb_build_object('state', 'checked_in'));
  SELECT status, handoff INTO st, h FROM public.live_activity_sends WHERE id = id_u;
  SELECT count(*) INTO q FROM net.http_request_queue r WHERE r.url = fn_url;
  n := n + 1; ok := st = 'queued' AND h AND q = q0 + 1;
  IF NOT ok THEN bad := bad + 1; END IF;
  tap := tap || format(E'%s %s - negative control: flag on, row handed off (status=%s posts=%s)\n', CASE WHEN ok THEN 'ok' ELSE 'not ok' END, n, st, q - q0);
  UPDATE public.live_activity_config SET ios_sender_enabled = false;

  -- claim then token_rejected (what the function records on UNREGISTERED) marks the session stale
  PERFORM * FROM public.live_activity_claim(ARRAY[id_u]);
  SELECT status INTO st FROM public.live_activity_sends WHERE id = id_u;
  PERFORM public.live_activity_record_result(id_u, 'token_rejected', 'unregistered');
  SELECT status INTO sst FROM public.live_activity_sessions WHERE id = si;
  n := n + 1; ok := st = 'sending' AND sst = 'stale'
                    AND (SELECT status FROM public.live_activity_sends WHERE id = id_u) = 'token_rejected';
  IF NOT ok THEN bad := bad + 1; END IF;
  tap := tap || format(E'%s %s - claimed ios row, token_rejected -> session stale (claim=%s session=%s)\n', CASE WHEN ok THEN 'ok' ELSE 'not ok' END, n, st, sst);

  n := n + 1; ok := NOT (SELECT ios_sender_enabled FROM public.live_activity_config);
  IF NOT ok THEN bad := bad + 1; END IF;
  tap := tap || format(E'%s %s - ios_sender_enabled is false\n', CASE WHEN ok THEN 'ok' ELSE 'not ok' END, n);

  RAISE EXCEPTION E'TAP\n1..%\n%# % failed', n, tap, bad;
END
$tap$;
