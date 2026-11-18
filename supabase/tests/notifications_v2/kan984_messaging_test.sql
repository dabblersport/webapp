-- KAN-984 [W1-B6] messaging push: live TAP-style test of the database half.
-- Run as postgres on wtncuzcskpigqpmnxwws after 20261117164003_kan984_messaging_push_preview.sql.
--
-- One DO block ending in RAISE EXCEPTION: everything rolls back (rows, settings, the meetup fixture, and the pushes
-- queued in net.http_request_queue), so no device receives anything. The sender calls msg_notify as authenticated
-- with request.jwt.claims, exactly as the Worker forwards the user's token.
-- KAN-984b (20261117170659): the snippet overload is server-only, so the snippet cases call msg_notify_core as the
-- server would; R4 checks that a member's direct 4-argument call is refused and the 3-argument call still works.
-- Note: the snippet is transiently in the pg_net request row (net.http_request_queue) until pg_net sends it; it is
-- in no table row after that.
-- Fixtures: staging test accounts U = a3ba3271 (dabbler.pro) and V = 039a9d4a (jidep35093), their DM eda0ce73, and
-- meetup 1b6df962 (organiser U; reopened in the transaction), plus a third user W = bbede6b0 as the non-member.
--
-- Negative controls:
--   snippet not stored  no snippet text in body/args/title/context   | the same query finds the sender's name
--   preview             sender_and_message -> snippet in the push    | sender_only -> generic body, no snippet
--   meetup members      going member notified                        | interested (non-member) user gets nothing
--   conversation mute   muted member: no row, no push                | unmuted: row + push
--   block               recipient blocked the sender: nothing        | unblocked: row
--   blocklist           blocklisted snippet dropped                  | clean snippet kept

DO $tap$
DECLARE
  tap text := ''; n int := 0; bad int := 0;
  u uuid := 'a3ba3271-3556-4b4e-b15d-bc0851f8a64b';
  v uuid := '039a9d4a-8c8d-48e1-8dff-327c1c615179';
  w uuid := 'bbede6b0-72e7-4b3a-a086-5eca9788a408';
  dm uuid := 'eda0ce73-ed70-4659-9df0-ea32b4090361';
  mc uuid := '78fc2e5a-42da-4ca9-878c-496fe737758e';
  mt uuid := '1b6df962-cabb-4c18-83cb-d589345e6460';
  snip text := 'see you at the pitch at 8';
  uname text; vname text; mtitle text;
  nid uuid; b jsonb; c int; t text; seq bigint := 900000;
BEGIN
  -- fixtures (rolled back)
  DELETE FROM public.user_blocks WHERE blocker_user_id IN (u, v, w) OR blocked_user_id IN (u, v, w);
  DELETE FROM public.notifications WHERE kind_key = 'message.received' AND to_user_id IN (u, v, w);
  UPDATE public.msg_conversation_members SET muted_at = NULL WHERE conversation_id IN (dm, mc);
  INSERT INTO public.notification_settings (user_id) VALUES (v) ON CONFLICT (user_id) DO NOTHING;
  UPDATE public.notification_settings SET muted_kinds = '{}', push_enabled = true, quiet_start_min = NULL, quiet_end_min = NULL,
         message_preview = 'sender_and_message', category_prefs = jsonb_set(category_prefs, '{messages,push}', 'true')
   WHERE user_id = v;
  UPDATE public.profiles SET language = 'en' WHERE user_id IN (u, v);
  SELECT p.display_name INTO uname FROM public.profiles p WHERE p.user_id = u AND p.is_active ORDER BY p.updated_at DESC NULLS LAST LIMIT 1;

  ------------------------------------------------------------------------- D1 DM, sender_and_message
  PERFORM set_config('request.jwt.claims', json_build_object('sub', u, 'role', 'authenticated')::text, true);
  PERFORM public.msg_notify_core(u, dm, seq + 1, 'all', snip);  -- server path (KAN-984b)
  SELECT id INTO nid FROM public.notifications WHERE to_user_id = v AND dedupe_key = 'message.received:' || dm || ':' || (seq + 1);
  SELECT convert_from(q.body, 'UTF8')::jsonb INTO b FROM net.http_request_queue q
   WHERE convert_from(q.body, 'UTF8')::jsonb ->> 'notification_id' = nid::text;
  n := n + 1;
  IF nid IS NOT NULL AND b ->> 'title' = uname AND b ->> 'body' = snip
     AND b #>> '{data,conversation_id}' = dm::text AND b #>> '{delivery,ios_category}' = 'DABBLER_MESSAGE'
     AND NOT (b #>> '{delivery,time_sensitive}')::boolean AND b #>> '{data,action_route}' = '/messaging/thread/' || dm THEN
    tap := tap || format(E'ok %s - DM, sender_and_message: push title = sender (%s), body = snippet, conversation_id, DABBLER_MESSAGE, not time-sensitive\n', n, uname);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - DM push: %s\n', n, b); END IF;

  -- the snippet is not stored; negative control: the same query finds the sender's name
  n := n + 1;
  IF NOT EXISTS (SELECT 1 FROM public.notifications x WHERE x.id = nid
                  AND (coalesce(x.body,'') || coalesce(x.title,'') || coalesce(x.args::text,'') || coalesce(x.context::text,'')) LIKE '%' || snip || '%')
     AND EXISTS (SELECT 1 FROM public.notifications x WHERE x.id = nid
                  AND (coalesce(x.body,'') || coalesce(x.title,'') || coalesce(x.args::text,'') || coalesce(x.context::text,'')) LIKE '%' || uname || '%')
     AND current_setting('dabbler.push_body', true) = '' THEN
    tap := tap || format(E'ok %s - the snippet is not in the row (body/title/args/context); control: the sender''s name is; the push setting is cleared\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - snippet stored or setting left: %s\n', n, current_setting('dabbler.push_body', true)); END IF;

  ------------------------------------------------------------------------- D2 DM, sender_only
  UPDATE public.notification_settings SET message_preview = 'sender_only' WHERE user_id = v;
  PERFORM set_config('request.jwt.claims', json_build_object('sub', u, 'role', 'authenticated')::text, true);
  PERFORM public.msg_notify_core(u, dm, seq + 2, 'all', snip || ' two');  -- server path (KAN-984b)
  SELECT id INTO nid FROM public.notifications WHERE to_user_id = v AND dedupe_key = 'message.received:' || dm || ':' || (seq + 2);
  -- (D1's row is still unread inside 2 minutes, so the coalesce rule applies; mark it read first is the app's job)
  n := n + 1;
  IF nid IS NULL THEN
    tap := tap || format(E'ok %s - coalescing kept: a second message within 2 minutes while the first is unread makes no second row\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - coalescing broken\n', n); END IF;
  UPDATE public.notifications SET is_read = true WHERE to_user_id = v AND kind_key = 'message.received';
  PERFORM set_config('request.jwt.claims', json_build_object('sub', u, 'role', 'authenticated')::text, true);
  PERFORM public.msg_notify_core(u, dm, seq + 3, 'all', snip || ' three');  -- server path (KAN-984b)
  SELECT id INTO nid FROM public.notifications WHERE to_user_id = v AND dedupe_key = 'message.received:' || dm || ':' || (seq + 3);
  SELECT convert_from(q.body, 'UTF8')::jsonb INTO b FROM net.http_request_queue q
   WHERE convert_from(q.body, 'UTF8')::jsonb ->> 'notification_id' = nid::text;
  n := n + 1;
  IF nid IS NOT NULL AND b ->> 'title' = uname AND b ->> 'body' = 'Open the chat to read it.' AND position('three' IN b::text) = 0 THEN
    tap := tap || format(E'ok %s - DM, sender_only: push shows the sender, no message text (generic body)\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - sender_only push: %s\n', n, b); END IF;
  UPDATE public.notification_settings SET message_preview = 'sender_and_message' WHERE user_id = v;
  UPDATE public.notifications SET is_read = true WHERE to_user_id = v AND kind_key = 'message.received';

  ------------------------------------------------------------------------- 3-argument path (deployed Worker today)
  PERFORM set_config('request.jwt.claims', json_build_object('sub', u, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  PERFORM public.msg_notify(dm, seq + 4, 'all');
  EXECUTE 'RESET ROLE';
  SELECT id INTO nid FROM public.notifications WHERE to_user_id = v AND dedupe_key = 'message.received:' || dm || ':' || (seq + 4);
  SELECT convert_from(q.body, 'UTF8')::jsonb INTO b FROM net.http_request_queue q
   WHERE convert_from(q.body, 'UTF8')::jsonb ->> 'notification_id' = nid::text;
  n := n + 1;
  IF nid IS NOT NULL AND b ->> 'title' = uname AND b ->> 'body' = 'Open the chat to read it.'
     AND (SELECT schema_version FROM public.notifications WHERE id = nid) = 2 THEN
    tap := tap || format(E'ok %s - the 3-argument msg_notify (deployed Worker) still notifies, sender only, through notify_v2\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - 3-arg path: %s\n', n, b); END IF;
  UPDATE public.notifications SET is_read = true WHERE to_user_id = v AND kind_key = 'message.received';

  ------------------------------------------------------------------------- blocklisted snippet dropped
  PERFORM set_config('request.jwt.claims', json_build_object('sub', u, 'role', 'authenticated')::text, true);
  PERFORM public.msg_notify_core(u, dm, seq + 5, 'all', 'buy a fake passport here');  -- server path (KAN-984b)
  SELECT id INTO nid FROM public.notifications WHERE to_user_id = v AND dedupe_key = 'message.received:' || dm || ':' || (seq + 5);
  SELECT convert_from(q.body, 'UTF8')::jsonb INTO b FROM net.http_request_queue q
   WHERE convert_from(q.body, 'UTF8')::jsonb ->> 'notification_id' = nid::text;
  n := n + 1;
  IF nid IS NOT NULL AND b ->> 'body' = 'Open the chat to read it.' THEN
    tap := tap || format(E'ok %s - a blocklisted snippet is dropped (sender-only push); control: D1''s clean snippet was kept\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - blocklist: %s\n', n, b); END IF;
  UPDATE public.notifications SET is_read = true WHERE to_user_id = v AND kind_key = 'message.received';

  ------------------------------------------------------------------------- conversation mute and block
  UPDATE public.msg_conversation_members SET muted_at = now() WHERE conversation_id = dm AND user_id = v;
  PERFORM set_config('request.jwt.claims', json_build_object('sub', u, 'role', 'authenticated')::text, true);
  PERFORM public.msg_notify_core(u, dm, seq + 6, 'all', snip);  -- server path (KAN-984b)
  n := n + 1;
  IF NOT EXISTS (SELECT 1 FROM public.notifications WHERE to_user_id = v AND dedupe_key = 'message.received:' || dm || ':' || (seq + 6)) THEN
    tap := tap || format(E'ok %s - a muted conversation produces no row and no push\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - muted conversation notified\n', n); END IF;
  UPDATE public.msg_conversation_members SET muted_at = NULL WHERE conversation_id = dm AND user_id = v;

  INSERT INTO public.user_blocks (blocker_user_id, blocked_user_id) VALUES (v, u);
  PERFORM set_config('request.jwt.claims', json_build_object('sub', u, 'role', 'authenticated')::text, true);
  PERFORM public.msg_notify_core(u, dm, seq + 7, 'all', snip);  -- server path (KAN-984b)
  n := n + 1;
  IF NOT EXISTS (SELECT 1 FROM public.notifications WHERE to_user_id = v AND dedupe_key = 'message.received:' || dm || ':' || (seq + 7)) THEN
    tap := tap || format(E'ok %s - a blocked sender produces no row and no push\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - blocked sender notified\n', n); END IF;
  DELETE FROM public.user_blocks WHERE blocker_user_id = v AND blocked_user_id = u;

  PERFORM set_config('request.jwt.claims', json_build_object('sub', u, 'role', 'authenticated')::text, true);
  PERFORM public.msg_notify_core(u, dm, seq + 8, 'all', snip);  -- server path (KAN-984b)
  n := n + 1;
  IF EXISTS (SELECT 1 FROM public.notifications WHERE to_user_id = v AND dedupe_key = 'message.received:' || dm || ':' || (seq + 8)) THEN
    tap := tap || format(E'ok %s - negative control: unmuted and unblocked, the same message notifies\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - control did not notify\n', n); END IF;
  UPDATE public.notifications SET is_read = true WHERE to_user_id = v AND kind_key = 'message.received';

  ------------------------------------------------------------------------- quiet hours: silent, never time-sensitive
  UPDATE public.notification_settings SET tz = 'UTC',
         quiet_start_min = (extract(hour from now() at time zone 'UTC')::int * 60 + extract(minute from now() at time zone 'UTC')::int),
         quiet_end_min = (extract(hour from now() at time zone 'UTC')::int * 60 + extract(minute from now() at time zone 'UTC')::int + 30) % 1440
   WHERE user_id = v;
  PERFORM set_config('request.jwt.claims', json_build_object('sub', u, 'role', 'authenticated')::text, true);
  PERFORM public.msg_notify_core(u, dm, seq + 9, 'all', snip);  -- server path (KAN-984b)
  SELECT id INTO nid FROM public.notifications WHERE to_user_id = v AND dedupe_key = 'message.received:' || dm || ':' || (seq + 9);
  SELECT convert_from(q.body, 'UTF8')::jsonb INTO b FROM net.http_request_queue q
   WHERE convert_from(q.body, 'UTF8')::jsonb ->> 'notification_id' = nid::text;
  n := n + 1;
  IF b #>> '{delivery,mode}' = 'silent' AND NOT (b #>> '{delivery,time_sensitive}')::boolean AND b ->> 'body' = snip THEN
    tap := tap || format(E'ok %s - quiet hours: the message push is silent and not time-sensitive (snippet still shown)\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - quiet: %s\n', n, b -> 'delivery'); END IF;
  UPDATE public.notification_settings SET quiet_start_min = NULL, quiet_end_min = NULL WHERE user_id = v;
  UPDATE public.notifications SET is_read = true WHERE to_user_id = v AND kind_key = 'message.received';

  ------------------------------------------------------------------------- meetup chat: "Sender in Group", members only
  UPDATE public.events SET is_cancelled = false, start_at = now() + interval '30 minutes', end_at = now() + interval '2 hours'
   WHERE id = (SELECT event_id FROM public.kan714_meetups_read WHERE id = mt);
  SELECT e.title INTO mtitle FROM public.kan714_meetups_read m JOIN public.events e ON e.id = m.event_id WHERE m.id = mt;
  DELETE FROM public.meetup_rsvps WHERE meetup_id = mt AND user_id IN (v, w);
  INSERT INTO public.meetup_rsvps (meetup_id, user_id, status) VALUES (mt, v, 'going'), (mt, w, 'interested');
  UPDATE public.profiles SET language = 'ar' WHERE user_id = v;
  PERFORM set_config('request.jwt.claims', json_build_object('sub', u, 'role', 'authenticated')::text, true);
  PERFORM public.msg_notify_core(u, mc, seq + 10, 'all', snip);  -- server path (KAN-984b)
  SELECT id INTO nid FROM public.notifications WHERE to_user_id = v AND dedupe_key = 'message.received:' || mc || ':' || (seq + 10);
  SELECT convert_from(q.body, 'UTF8')::jsonb INTO b FROM net.http_request_queue q
   WHERE convert_from(q.body, 'UTF8')::jsonb ->> 'notification_id' = nid::text;
  n := n + 1;
  IF nid IS NOT NULL AND b ->> 'title' = uname || ' في ' || mtitle AND b ->> 'body' = snip
     AND b #>> '{data,meetup_id}' = mt::text AND b #>> '{data,conversation_id}' = mc::text
     AND b #>> '{data,action_route}' = '/meetups/' || mt || '/chat' THEN
    tap := tap || format(E'ok %s - meetup chat: a going member gets "Sender in Group" (AR: %s), the snippet, meetup_id and conversation_id\n', n, b ->> 'title');
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - meetup member push: %s\n', n, b); END IF;
  n := n + 1;
  IF NOT EXISTS (SELECT 1 FROM public.notifications WHERE to_user_id = w AND kind_key = 'message.received'
                  AND dedupe_key = 'message.received:' || mc || ':' || (seq + 10))
     AND NOT EXISTS (SELECT 1 FROM public.notifications WHERE to_user_id = u AND dedupe_key = 'message.received:' || mc || ':' || (seq + 10)) THEN
    tap := tap || format(E'ok %s - negative control: an interested (non-member) user and the sender get nothing\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - non-member or sender notified\n', n); END IF;

  UPDATE public.profiles SET language = 'en' WHERE user_id = v;
  UPDATE public.notifications SET is_read = true WHERE to_user_id = v AND kind_key = 'message.received';
  PERFORM set_config('request.jwt.claims', json_build_object('sub', u, 'role', 'authenticated')::text, true);
  PERFORM public.msg_notify_core(u, mc, seq + 11, 'all', snip);  -- server path (KAN-984b)
  SELECT title INTO t FROM public.notifications WHERE to_user_id = v AND dedupe_key = 'message.received:' || mc || ':' || (seq + 11);
  n := n + 1;
  IF t = uname || ' in ' || mtitle THEN
    tap := tap || format(E'ok %s - meetup chat, EN recipient: "%s"\n', n, t);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - EN group title: %s\n', n, t); END IF;

  ------------------------------------------------------------------------- R4 (KAN-984b, KAN-984c): no client-supplied snippet
  -- KAN-984c: the 4-argument overload is callable by members again, but a snippet without the Worker's MAC
  -- (x-msg-snippet-mac) is dropped: the ghost text reaches no push. The MAC cases live in kan984c_snippet_mac.sql.
  UPDATE public.notifications SET is_read = true WHERE to_user_id = v AND kind_key = 'message.received';
  PERFORM set_config('request.jwt.claims', json_build_object('sub', u, 'role', 'authenticated')::text, true);
  PERFORM set_config('request.headers', '{}', true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  BEGIN
    PERFORM public.msg_notify(dm, 987654321, 'all', 'GHOST text that is no message');
    t := 'accepted';
  EXCEPTION WHEN insufficient_privilege THEN t := '42501';
  END;
  EXECUTE 'RESET ROLE';
  SELECT id INTO nid FROM public.notifications WHERE to_user_id = v AND dedupe_key = 'message.received:' || dm || ':987654321';
  SELECT convert_from(q.body, 'UTF8')::jsonb INTO b FROM net.http_request_queue q
   WHERE convert_from(q.body, 'UTF8')::jsonb ->> 'notification_id' = nid::text;
  n := n + 1;
  IF t = 'accepted' AND nid IS NOT NULL AND b ->> 'body' = 'Open the chat to read it.'
     AND NOT EXISTS (SELECT 1 FROM net.http_request_queue q WHERE convert_from(q.body, 'UTF8') LIKE '%GHOST text%') THEN
    tap := tap || format(E'ok %s - R4 a member''s direct snippet call without the Worker MAC is sender-only: the ghost text is queued nowhere\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - R4 direct snippet call: %s / %s\n', n, t, b ->> 'body'); END IF;
  UPDATE public.notifications SET is_read = true WHERE to_user_id = v AND kind_key = 'message.received';

  PERFORM set_config('request.jwt.claims', json_build_object('sub', u, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  PERFORM public.msg_notify(dm, 987654322, 'all');
  EXECUTE 'RESET ROLE';
  SELECT id INTO nid FROM public.notifications WHERE to_user_id = v AND dedupe_key = 'message.received:' || dm || ':987654322';
  SELECT convert_from(q.body, 'UTF8')::jsonb INTO b FROM net.http_request_queue q
   WHERE convert_from(q.body, 'UTF8')::jsonb ->> 'notification_id' = nid::text;
  n := n + 1;
  IF nid IS NOT NULL AND b ->> 'title' = uname AND b ->> 'body' = 'Open the chat to read it.' THEN
    tap := tap || format(E'ok %s - R4 control: the same member''s 3-argument call still notifies, sender only\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - R4 control: %s\n', n, b); END IF;

  ------------------------------------------------------------------------- one sender; grants
  SELECT count(*) INTO c FROM pg_proc p
   WHERE p.pronamespace = 'public'::regnamespace AND p.prokind = 'f'
     AND pg_get_functiondef(p.oid) ~ '''message\.received'''
     AND p.proname NOT IN ('msg_notify_core', 'notification_push_category');
  n := n + 1;
  IF c = 0 AND NOT has_function_privilege('authenticated', 'public.msg_notify_core(uuid,uuid,bigint,text,text)', 'EXECUTE')
     AND NOT has_function_privilege('anon', 'public.msg_notify(uuid,bigint,text,text)', 'EXECUTE')
     AND has_function_privilege('authenticated', 'public.msg_notify(uuid,bigint,text,text)', 'EXECUTE')  -- KAN-984c
     AND NOT has_function_privilege('authenticated', 'public.msg_snippet_verified(uuid,bigint,text)', 'EXECUTE')
     AND has_function_privilege('authenticated', 'public.msg_notify(uuid,bigint,text)', 'EXECUTE') THEN
    tap := tap || format(E'ok %s - message.received has one sender (msg_notify_core); core and the MAC check are not client-callable; anon cannot call msg_notify\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - senders %s / grants\n', n, c); END IF;

  RAISE EXCEPTION E'KAN-984 TAP (rolled back)\n1..%\n%# % failed of %', n, tap, bad, n;
END
$tap$;
