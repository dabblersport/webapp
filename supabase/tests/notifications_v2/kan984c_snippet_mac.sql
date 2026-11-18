-- KAN-984c live test: the message snippet needs a MAC from the Worker. Run as postgres on wtncuzcskpigqpmnxwws after
-- 20261118052921_kan984c_msg_snippet_mac.sql.
--
-- One DO block ending in RAISE EXCEPTION: everything rolls back, including a THROWAWAY Vault key created inside the
-- block (random, never selected into the output) and every push queued in net.http_request_queue. If the real key
-- 'msg_snippet_hmac_key' already exists, the block uses it as is and creates nothing; MACs are computed inside the
-- block and only compared, never printed.
--
-- The member U sends in the DM as authenticated with request.jwt.claims (as the Worker forwards the user's token);
-- the MAC travels in request.headers exactly as PostgREST sets it.
--
-- Negative controls: good MAC -> the snippet is in the push (K2) | no header, wrong seq, wrong text, wrong key,
-- malformed header, unparsable headers, no Vault key -> generic body, and the notice is still sent.
DO $tap$
DECLARE
  tap text := ''; n int := 0; bad int := 0;
  u  uuid := 'a3ba3271-3556-4b4e-b15d-bc0851f8a64b';
  v  uuid := '039a9d4a-8c8d-48e1-8dff-327c1c615179';
  dm uuid := 'eda0ce73-ed70-4659-9df0-ea32b4090361';
  snip text := 'see you at the pitch at 8 ⚽ نلتقي';
  generic text := 'Open the chat to read it.';
  seq bigint := 930000;
  had_key boolean; k text; mac text; code text; b jsonb; nid uuid; r int;
BEGIN
  -- fixtures (rolled back)
  DELETE FROM public.user_blocks WHERE (blocker_user_id = v AND blocked_user_id = u) OR (blocker_user_id = u AND blocked_user_id = v);
  UPDATE public.msg_conversation_members SET muted_at = NULL WHERE conversation_id = dm;
  INSERT INTO public.notification_settings (user_id) VALUES (v) ON CONFLICT (user_id) DO NOTHING;
  UPDATE public.notification_settings SET muted_kinds = '{}', push_enabled = true, quiet_start_min = NULL, quiet_end_min = NULL,
         message_preview = 'sender_and_message', category_prefs = jsonb_set(category_prefs, '{messages,push}', 'true')
   WHERE user_id = v;
  UPDATE public.notifications SET is_read = true WHERE to_user_id = v AND kind_key = 'message.received' AND NOT is_read;
  had_key := EXISTS (SELECT 1 FROM vault.secrets WHERE name = 'msg_snippet_hmac_key');

  ------------------------------------------------------------------ K0 no Vault key: even a well-formed MAC is dropped
  IF NOT had_key THEN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', u, 'role', 'authenticated')::text, true);
    PERFORM set_config('request.headers', json_build_object('x-msg-snippet-mac', encode(extensions.gen_random_bytes(32), 'hex'))::text, true);
    PERFORM set_config('role', 'authenticated', true);
    PERFORM public.msg_notify(dm, seq, 'allowlist', snip);
    PERFORM set_config('role', 'postgres', true);
    SELECT id INTO nid FROM public.notifications WHERE to_user_id = v AND dedupe_key = 'message.received:' || dm || ':' || seq;
    SELECT convert_from(q.body, 'UTF8')::jsonb INTO b FROM net.http_request_queue q WHERE convert_from(q.body, 'UTF8')::jsonb ->> 'notification_id' = nid::text;
    n := n + 1;
    IF nid IS NOT NULL AND b ->> 'body' = generic THEN
      tap := tap || format(E'ok %s - no Vault key: the snippet is dropped, the notice is still sent sender-only\n', n);
    ELSE bad := bad + 1; tap := tap || format(E'not ok %s - no key: %s\n', n, b ->> 'body'); END IF;
    UPDATE public.notifications SET is_read = true WHERE to_user_id = v AND kind_key = 'message.received' AND NOT is_read;
    -- a throwaway key for the rest of the test (rolled back with everything else; its value is never output)
    PERFORM vault.create_secret(encode(extensions.gen_random_bytes(32), 'hex'), 'msg_snippet_hmac_key', 'KAN-984c test key (rolled back)');
  END IF;
  SELECT decrypted_secret INTO k FROM vault.decrypted_secrets WHERE name = 'msg_snippet_hmac_key';

  ------------------------------------------------------------------ K1 no header
  PERFORM set_config('request.jwt.claims', json_build_object('sub', u, 'role', 'authenticated')::text, true);
  PERFORM set_config('request.headers', '{}', true);
  PERFORM set_config('role', 'authenticated', true);
  PERFORM public.msg_notify(dm, seq + 1, 'allowlist', snip);
  PERFORM set_config('role', 'postgres', true);
  SELECT id INTO nid FROM public.notifications WHERE to_user_id = v AND dedupe_key = 'message.received:' || dm || ':' || (seq + 1);
  SELECT convert_from(q.body, 'UTF8')::jsonb INTO b FROM net.http_request_queue q WHERE convert_from(q.body, 'UTF8')::jsonb ->> 'notification_id' = nid::text;
  n := n + 1;
  IF nid IS NOT NULL AND b ->> 'body' = generic THEN
    tap := tap || format(E'ok %s - no MAC header: sender-only push, notice still sent\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - no header: %s\n', n, b ->> 'body'); END IF;
  UPDATE public.notifications SET is_read = true WHERE to_user_id = v AND kind_key = 'message.received' AND NOT is_read;

  ------------------------------------------------------------------ K2 good MAC (positive control for every drop)
  mac := encode(extensions.hmac(convert_to(dm::text || ':' || (seq + 2)::text || ':' || snip, 'UTF8'), convert_to(k, 'UTF8'), 'sha256'), 'hex');
  PERFORM set_config('request.headers', json_build_object('x-msg-snippet-mac', mac)::text, true);
  PERFORM set_config('role', 'authenticated', true);
  PERFORM public.msg_notify(dm, seq + 2, 'allowlist', snip);
  PERFORM set_config('role', 'postgres', true);
  SELECT id INTO nid FROM public.notifications WHERE to_user_id = v AND dedupe_key = 'message.received:' || dm || ':' || (seq + 2);
  SELECT convert_from(q.body, 'UTF8')::jsonb INTO b FROM net.http_request_queue q WHERE convert_from(q.body, 'UTF8')::jsonb ->> 'notification_id' = nid::text;
  n := n + 1;
  IF nid IS NOT NULL AND b ->> 'body' = snip THEN
    tap := tap || format(E'ok %s - good MAC: the push body is the snippet (control for every drop below)\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - good MAC: %s\n', n, b ->> 'body'); END IF;
  n := n + 1;
  IF NOT EXISTS (SELECT 1 FROM public.notifications x WHERE x.id = nid AND x::text LIKE '%' || snip || '%')
     AND EXISTS (SELECT 1 FROM public.notifications x WHERE x.id = nid AND x::text LIKE '%' || x.title || '%')
     AND NOT EXISTS (SELECT 1 FROM public.notifications x WHERE x.id = nid AND x::text LIKE '%' || mac || '%')
     AND current_setting('dabbler.push_body', true) = '' THEN
    tap := tap || format(E'ok %s - good MAC: neither the snippet nor the MAC is in the row; control: the title is; push setting cleared\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - stored\n', n); END IF;
  -- replay: the same MAC for the same seq again adds no second notice (dedupe per seq)
  UPDATE public.notifications SET is_read = true WHERE to_user_id = v AND kind_key = 'message.received' AND NOT is_read;
  PERFORM set_config('role', 'authenticated', true);
  PERFORM public.msg_notify(dm, seq + 2, 'allowlist', snip);
  PERFORM set_config('role', 'postgres', true);
  SELECT count(*) INTO r FROM public.notifications WHERE to_user_id = v AND dedupe_key = 'message.received:' || dm || ':' || (seq + 2);
  n := n + 1;
  IF r = 1 THEN
    tap := tap || format(E'ok %s - replaying a captured MAC for the same seq adds no second notice\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - replay rows %s\n', n, r); END IF;

  ------------------------------------------------------------------ K3 MAC for another seq
  mac := encode(extensions.hmac(convert_to(dm::text || ':' || (seq + 2)::text || ':' || snip, 'UTF8'), convert_to(k, 'UTF8'), 'sha256'), 'hex');
  PERFORM set_config('request.headers', json_build_object('x-msg-snippet-mac', mac)::text, true);
  PERFORM set_config('role', 'authenticated', true);
  PERFORM public.msg_notify(dm, seq + 3, 'allowlist', snip);
  PERFORM set_config('role', 'postgres', true);
  SELECT id INTO nid FROM public.notifications WHERE to_user_id = v AND dedupe_key = 'message.received:' || dm || ':' || (seq + 3);
  SELECT convert_from(q.body, 'UTF8')::jsonb INTO b FROM net.http_request_queue q WHERE convert_from(q.body, 'UTF8')::jsonb ->> 'notification_id' = nid::text;
  n := n + 1;
  IF nid IS NOT NULL AND b ->> 'body' = generic THEN
    tap := tap || format(E'ok %s - MAC for another seq: sender-only\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - wrong seq: %s\n', n, b ->> 'body'); END IF;
  UPDATE public.notifications SET is_read = true WHERE to_user_id = v AND kind_key = 'message.received' AND NOT is_read;

  ------------------------------------------------------------------ K4 MAC for another text (the R4 attack with a real MAC)
  mac := encode(extensions.hmac(convert_to(dm::text || ':' || (seq + 4)::text || ':' || snip, 'UTF8'), convert_to(k, 'UTF8'), 'sha256'), 'hex');
  PERFORM set_config('request.headers', json_build_object('x-msg-snippet-mac', mac)::text, true);
  PERFORM set_config('role', 'authenticated', true);
  PERFORM public.msg_notify(dm, seq + 4, 'allowlist', 'GHOST text that is no message');
  PERFORM set_config('role', 'postgres', true);
  SELECT id INTO nid FROM public.notifications WHERE to_user_id = v AND dedupe_key = 'message.received:' || dm || ':' || (seq + 4);
  SELECT convert_from(q.body, 'UTF8')::jsonb INTO b FROM net.http_request_queue q WHERE convert_from(q.body, 'UTF8')::jsonb ->> 'notification_id' = nid::text;
  n := n + 1;
  IF nid IS NOT NULL AND b ->> 'body' = generic
     AND NOT EXISTS (SELECT 1 FROM net.http_request_queue q WHERE convert_from(q.body, 'UTF8') LIKE '%GHOST text%') THEN
    tap := tap || format(E'ok %s - MAC for another text: sender-only, the other text is queued nowhere\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - wrong text: %s\n', n, b ->> 'body'); END IF;
  UPDATE public.notifications SET is_read = true WHERE to_user_id = v AND kind_key = 'message.received' AND NOT is_read;

  ------------------------------------------------------------------ K5 MAC made with another key
  mac := encode(extensions.hmac(convert_to(dm::text || ':' || (seq + 5)::text || ':' || snip, 'UTF8'), convert_to(k || 'x', 'UTF8'), 'sha256'), 'hex');
  PERFORM set_config('request.headers', json_build_object('x-msg-snippet-mac', mac)::text, true);
  PERFORM set_config('role', 'authenticated', true);
  PERFORM public.msg_notify(dm, seq + 5, 'allowlist', snip);
  PERFORM set_config('role', 'postgres', true);
  SELECT id INTO nid FROM public.notifications WHERE to_user_id = v AND dedupe_key = 'message.received:' || dm || ':' || (seq + 5);
  SELECT convert_from(q.body, 'UTF8')::jsonb INTO b FROM net.http_request_queue q WHERE convert_from(q.body, 'UTF8')::jsonb ->> 'notification_id' = nid::text;
  n := n + 1;
  IF nid IS NOT NULL AND b ->> 'body' = generic THEN
    tap := tap || format(E'ok %s - MAC made with another key: sender-only\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - wrong key: %s\n', n, b ->> 'body'); END IF;
  UPDATE public.notifications SET is_read = true WHERE to_user_id = v AND kind_key = 'message.received' AND NOT is_read;

  ------------------------------------------------------------------ K6 malformed header, then unparsable request.headers: never raises
  PERFORM set_config('request.headers', json_build_object('x-msg-snippet-mac', 'zz-not-a-mac')::text, true);
  PERFORM set_config('role', 'authenticated', true);
  BEGIN
    PERFORM public.msg_notify(dm, seq + 6, 'allowlist', snip); code := 'ok';
  EXCEPTION WHEN OTHERS THEN code := SQLSTATE; END;
  PERFORM set_config('role', 'postgres', true);
  SELECT id INTO nid FROM public.notifications WHERE to_user_id = v AND dedupe_key = 'message.received:' || dm || ':' || (seq + 6);
  SELECT convert_from(q.body, 'UTF8')::jsonb INTO b FROM net.http_request_queue q WHERE convert_from(q.body, 'UTF8')::jsonb ->> 'notification_id' = nid::text;
  n := n + 1;
  IF code = 'ok' AND nid IS NOT NULL AND b ->> 'body' = generic THEN
    tap := tap || format(E'ok %s - malformed MAC: no error, sender-only\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - malformed: %s %s\n', n, code, b ->> 'body'); END IF;
  UPDATE public.notifications SET is_read = true WHERE to_user_id = v AND kind_key = 'message.received' AND NOT is_read;
  PERFORM set_config('request.headers', 'this is not json', true);
  PERFORM set_config('role', 'authenticated', true);
  BEGIN
    PERFORM public.msg_notify(dm, seq + 7, 'allowlist', snip); code := 'ok';
  EXCEPTION WHEN OTHERS THEN code := SQLSTATE; END;
  PERFORM set_config('role', 'postgres', true);
  SELECT id INTO nid FROM public.notifications WHERE to_user_id = v AND dedupe_key = 'message.received:' || dm || ':' || (seq + 7);
  SELECT convert_from(q.body, 'UTF8')::jsonb INTO b FROM net.http_request_queue q WHERE convert_from(q.body, 'UTF8')::jsonb ->> 'notification_id' = nid::text;
  n := n + 1;
  IF code = 'ok' AND nid IS NOT NULL AND b ->> 'body' = generic THEN
    tap := tap || format(E'ok %s - unparsable request.headers: no error, sender-only\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - unparsable: %s %s\n', n, code, b ->> 'body'); END IF;
  UPDATE public.notifications SET is_read = true WHERE to_user_id = v AND kind_key = 'message.received' AND NOT is_read;

  ------------------------------------------------------------------ K7 uppercase hex of a good MAC is accepted
  mac := upper(encode(extensions.hmac(convert_to(dm::text || ':' || (seq + 8)::text || ':' || snip, 'UTF8'), convert_to(k, 'UTF8'), 'sha256'), 'hex'));
  PERFORM set_config('request.headers', json_build_object('x-msg-snippet-mac', mac)::text, true);
  PERFORM set_config('role', 'authenticated', true);
  PERFORM public.msg_notify(dm, seq + 8, 'allowlist', snip);
  PERFORM set_config('role', 'postgres', true);
  SELECT id INTO nid FROM public.notifications WHERE to_user_id = v AND dedupe_key = 'message.received:' || dm || ':' || (seq + 8);
  SELECT convert_from(q.body, 'UTF8')::jsonb INTO b FROM net.http_request_queue q WHERE convert_from(q.body, 'UTF8')::jsonb ->> 'notification_id' = nid::text;
  n := n + 1;
  IF b ->> 'body' = snip THEN
    tap := tap || format(E'ok %s - a good MAC in uppercase hex is accepted\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - uppercase: %s\n', n, b ->> 'body'); END IF;
  UPDATE public.notifications SET is_read = true WHERE to_user_id = v AND kind_key = 'message.received' AND NOT is_read;

  ------------------------------------------------------------------ K8 sender_only preference still wins over a good MAC
  UPDATE public.notification_settings SET message_preview = 'sender_only' WHERE user_id = v;
  mac := encode(extensions.hmac(convert_to(dm::text || ':' || (seq + 9)::text || ':' || snip, 'UTF8'), convert_to(k, 'UTF8'), 'sha256'), 'hex');
  PERFORM set_config('request.headers', json_build_object('x-msg-snippet-mac', mac)::text, true);
  PERFORM set_config('role', 'authenticated', true);
  PERFORM public.msg_notify(dm, seq + 9, 'allowlist', snip);
  PERFORM set_config('role', 'postgres', true);
  SELECT id INTO nid FROM public.notifications WHERE to_user_id = v AND dedupe_key = 'message.received:' || dm || ':' || (seq + 9);
  SELECT convert_from(q.body, 'UTF8')::jsonb INTO b FROM net.http_request_queue q WHERE convert_from(q.body, 'UTF8')::jsonb ->> 'notification_id' = nid::text;
  n := n + 1;
  IF nid IS NOT NULL AND b ->> 'body' = generic THEN
    tap := tap || format(E'ok %s - recipient chose sender_only: a good MAC still shows no text\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - sender_only: %s\n', n, b ->> 'body'); END IF;
  UPDATE public.notification_settings SET message_preview = 'sender_and_message' WHERE user_id = v;
  UPDATE public.notifications SET is_read = true WHERE to_user_id = v AND kind_key = 'message.received' AND NOT is_read;

  ------------------------------------------------------------------ K9 3-argument path (the deployed Worker) unchanged
  PERFORM set_config('request.headers', '{}', true);
  PERFORM set_config('role', 'authenticated', true);
  PERFORM public.msg_notify(dm, seq + 10, 'allowlist');
  PERFORM set_config('role', 'postgres', true);
  SELECT id INTO nid FROM public.notifications WHERE to_user_id = v AND dedupe_key = 'message.received:' || dm || ':' || (seq + 10);
  SELECT convert_from(q.body, 'UTF8')::jsonb INTO b FROM net.http_request_queue q WHERE convert_from(q.body, 'UTF8')::jsonb ->> 'notification_id' = nid::text;
  n := n + 1;
  IF nid IS NOT NULL AND b ->> 'body' = generic THEN
    tap := tap || format(E'ok %s - the 3-argument msg_notify still notifies, sender only\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - 3-arg: %s\n', n, b ->> 'body'); END IF;

  ------------------------------------------------------------------ K10 grants
  PERFORM set_config('role', 'authenticated', true);
  BEGIN PERFORM public.msg_snippet_verified(dm, 1, 'x'); code := 'accepted';
  EXCEPTION WHEN OTHERS THEN code := SQLSTATE; END;
  PERFORM set_config('role', 'anon', true);
  BEGIN PERFORM public.msg_notify(dm, seq + 11, 'allowlist', snip); mac := 'accepted';
  EXCEPTION WHEN OTHERS THEN mac := SQLSTATE; END;
  PERFORM set_config('role', 'postgres', true);
  n := n + 1;
  IF code = '42501' AND mac = '42501'
     AND has_function_privilege('authenticated', 'public.msg_notify(uuid,bigint,text,text)', 'EXECUTE')
     AND NOT has_function_privilege('service_role', 'public.msg_snippet_verified(uuid,bigint,text)', 'EXECUTE')
     AND NOT has_function_privilege('authenticated', 'public.msg_notify_core(uuid,uuid,bigint,text,text)', 'EXECUTE') THEN
    tap := tap || format(E'ok %s - grants: members may call the 4-argument msg_notify; the check and the core are not client-callable; anon is refused\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - grants: helper %s, anon %s\n', n, code, mac); END IF;

  RAISE EXCEPTION E'KAN-984c TAP (rolled back, %)\n1..%\n%# % failed of %',
    CASE WHEN had_key THEN 'used the existing key' ELSE 'throwaway key' END, n, tap, bad, n;
END
$tap$;
