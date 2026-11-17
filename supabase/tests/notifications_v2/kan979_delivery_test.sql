-- KAN-979 [W1-B1] delivery: live TAP-style test of the database half.
-- Run as postgres on wtncuzcskpigqpmnxwws after 20261117055738_kan979_delivery_silent_quiet_hours.sql.
--
-- One DO block that ends in RAISE EXCEPTION, so everything rolls back and the TAP report is the error text. Each
-- notifications INSERT fires trg_push_on_notification_insert, which queues its request in net.http_request_queue
-- inside this same transaction; the test reads that queued body and the rollback discards it, so no device receives
-- anything. The edge-function half (one notification_deliveries row per device, provider result) is shown by the
-- real staging push recorded in the Jira evidence.
--
-- Run 2026-11-17 by backend-1 (Shu) after apply: 1..20, all ok, "# 0 failed of 20".
-- Real push (committed, staging test account dabbler.pro@proton.me, 2 installations android + web): notification
-- 8be421e3-873c-4b65-a024-3b621175df29 -> 2 delivery rows, both accepted with an FCM message name. Then a fake android
-- installation was added: notification 17cd250f-717e-4a9c-8040-9c6b381c1c6b -> 3 rows (2 accepted, 1 failed
-- invalid_token); the fake token was pruned (token_id SET NULL) and the 2 real tokens stayed.
--
-- KAN-979b (20261117101852): R1..R5 re-push hook (negative control R3/R4: blocked or ungrouped -> nothing) and
-- P1..P2 plural-safe grouped templates.
--
-- Negative controls:
--   quiet hours      social kind in the window -> silent      | same kind outside the window -> alert
--   breakthrough     breaks_quiet kind in the window -> alert + time-sensitive | social kind same minute -> silent, not
--   mute / category  muted kind / social push off -> no push, inbox row kept  | games kind same user -> pushed
--   security         push master off + quiet -> alert, time-sensitive        | (non-security kind with master off -> none)
--   activities       game entity with games push off -> none   | same kind, meetup entity -> pushed
--   language         AR profile -> Arabic push title           | EN profile -> English
--   snippet          dabbler.push_body set -> push body = snippet, row body unchanged | next insert -> row body
--   default quiet    no settings row at 03:00 Dubai -> quiet   | 09:00 Dubai -> not quiet

DO $tap$
DECLARE
  tap text := ''; n int := 0; bad int := 0;
  r uuid := 'a3ba3271-3556-4b4e-b15d-bc0851f8a64b';   -- staging test account dabbler.pro@proton.me
  a uuid := '039a9d4a-8c8d-48e1-8dff-327c1c615179';   -- staging test account jidep35093@iconcubic.com
  nobody uuid := '00000000-0000-0000-0000-00000000ffff';
  g uuid := '00000000-0000-0000-0000-0000000979a1';
  m int; id1 uuid; id2 uuid; b jsonb; b2 jsonb; c int; t text;

BEGIN
  m := extract(hour from now() at time zone 'UTC')::int * 60 + extract(minute from now() at time zone 'UTC')::int;
  DELETE FROM public.user_blocks WHERE blocker_user_id IN (r, a) OR blocked_user_id IN (r, a);
  INSERT INTO public.notification_settings (user_id) VALUES (r) ON CONFLICT (user_id) DO NOTHING;
  -- quiet window around now, in UTC
  UPDATE public.notification_settings
     SET tz = 'UTC', quiet_start_min = m, quiet_end_min = (m + 30) % 1440, push_enabled = true, muted_kinds = '{}'
   WHERE user_id = r;

  ------------------------------------------------------------------------------------------------ quiet hours (I-2)
  INSERT INTO public.notifications (to_user_id, kind_key, title, body, context, group_key)
  VALUES (r, 'social.mentioned_in_post', 'Q1 title', 'Q1 body', jsonb_build_object('entity_type','post','entity_id',g), 'grp:post:' || g)
  RETURNING id INTO id1;
  SELECT convert_from(q.body, 'UTF8')::jsonb INTO b FROM net.http_request_queue q
   WHERE convert_from(q.body, 'UTF8')::jsonb ->> 'notification_id' = id1::text;
  n := n + 1;
  IF b IS NOT NULL AND b #>> '{delivery,mode}' = 'silent' AND (b #>> '{delivery,time_sensitive}')::boolean = false
     AND b #>> '{delivery,android_channel_id}' = 'dabbler_quiet' THEN
    tap := tap || format(E'ok %s - quiet hours: social kind queued as a silent push on dabbler_quiet, not time-sensitive\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - quiet social push: %s\n', n, b); END IF;
  n := n + 1;
  IF EXISTS (SELECT 1 FROM public.notifications WHERE id = id1) THEN
    tap := tap || format(E'ok %s - quiet hours: the inbox row exists (not held, not dropped)\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - inbox row missing\n', n); END IF;

  -- payload contents (same row)
  n := n + 1;
  IF b #>> '{data,entity_id}' = g::text AND b #>> '{data,entity_type}' = 'post' AND b #>> '{data,notification_id}' = id1::text
     AND b #>> '{data,kind_key}' = 'social.mentioned_in_post' AND b ? 'notification_id'
     AND b #>> '{delivery,thread_id}' = 'grp:post:' || g AND b #>> '{delivery,collapse_id}' = 'grp:post:' || g
     AND b #>> '{delivery,ios_category}' = 'DABBLER_DEFAULT' AND b #>> '{title}' = 'Q1 title' AND b #>> '{body}' = 'Q1 body' THEN
    tap := tap || format(E'ok %s - payload: real entity_id, notification_id, kind_key, thread and collapse ids from group_key, category, row title/body\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - payload: %s\n', n, b); END IF;
  SELECT count(*)::int INTO c FROM public.notifications WHERE to_user_id = r AND NOT is_read;
  n := n + 1;
  IF (b #>> '{delivery,badge}')::int = c THEN
    tap := tap || format(E'ok %s - badge = server unread count (%s)\n', n, c);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - badge %s vs unread %s\n', n, b #>> '{delivery,badge}', c); END IF;

  -- breakthrough (I-3), same minute
  INSERT INTO public.notifications (to_user_id, kind_key, title, context)
  VALUES (r, 'game.removed', 'B1', jsonb_build_object('entity_type','game','entity_id',g)) RETURNING id INTO id2;
  SELECT convert_from(q.body, 'UTF8')::jsonb INTO b2 FROM net.http_request_queue q
   WHERE convert_from(q.body, 'UTF8')::jsonb ->> 'notification_id' = id2::text;
  n := n + 1;
  IF b2 #>> '{delivery,mode}' = 'alert' AND (b2 #>> '{delivery,time_sensitive}')::boolean
     AND b2 #>> '{delivery,android_channel_id}' = 'dabbler_games' THEN
    tap := tap || format(E'ok %s - breakthrough: breaks_quiet kind alerts in quiet hours, iOS time-sensitive, dabbler_games\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - breakthrough: %s\n', n, b2 -> 'delivery'); END IF;
  n := n + 1;
  IF b #>> '{delivery,mode}' = 'silent' AND NOT (b #>> '{delivery,time_sensitive}')::boolean THEN
    tap := tap || format(E'ok %s - negative control: the social kind in the same minute stayed silent and not time-sensitive\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - social control\n', n); END IF;

  -- outside the window
  UPDATE public.notification_settings SET quiet_start_min = (m + 60) % 1440, quiet_end_min = (m + 120) % 1440 WHERE user_id = r;
  INSERT INTO public.notifications (to_user_id, kind_key, title, context)
  VALUES (r, 'social.mentioned_in_post', 'Q2', jsonb_build_object('entity_type','post','entity_id',g)) RETURNING id INTO id1;
  SELECT convert_from(q.body, 'UTF8')::jsonb INTO b FROM net.http_request_queue q
   WHERE convert_from(q.body, 'UTF8')::jsonb ->> 'notification_id' = id1::text;
  n := n + 1;
  IF b #>> '{delivery,mode}' = 'alert' AND NOT (b #>> '{delivery,time_sensitive}')::boolean
     AND b #>> '{delivery,android_channel_id}' = 'dabbler_social' AND b #>> '{delivery,collapse_id}' IS NULL THEN
    tap := tap || format(E'ok %s - negative control: the same social kind outside quiet hours alerts normally (dabbler_social, no collapse without group_key)\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - outside window: %s\n', n, b -> 'delivery'); END IF;

  -- long group_key: collapse id is md5 (<= 64 bytes)
  INSERT INTO public.notifications (to_user_id, kind_key, title, context, group_key)
  VALUES (r, 'social.mentioned_in_post', 'Q3', '{}'::jsonb, repeat('x', 80)) RETURNING id INTO id1;
  SELECT convert_from(q.body, 'UTF8')::jsonb INTO b FROM net.http_request_queue q
   WHERE convert_from(q.body, 'UTF8')::jsonb ->> 'notification_id' = id1::text;
  n := n + 1;
  IF b #>> '{delivery,collapse_id}' = md5(repeat('x', 80)) AND b #>> '{delivery,thread_id}' = repeat('x', 80) THEN
    tap := tap || format(E'ok %s - a group_key over 64 bytes collapses by its md5\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - long collapse id: %s\n', n, b -> 'delivery'); END IF;

  ---------------------------------------------------------------------------------------------- mute and category off
  UPDATE public.notification_settings SET muted_kinds = ARRAY['game.player_joined'] WHERE user_id = r;
  INSERT INTO public.notifications (to_user_id, kind_key, title, context)
  VALUES (r, 'game.player_joined', 'M1', jsonb_build_object('entity_type','game','entity_id',g)) RETURNING id INTO id1;
  SELECT count(*) INTO c FROM net.http_request_queue q WHERE convert_from(q.body, 'UTF8')::jsonb ->> 'notification_id' = id1::text;
  n := n + 1;
  IF c = 0 AND EXISTS (SELECT 1 FROM public.notifications WHERE id = id1) THEN
    tap := tap || format(E'ok %s - muted kind: no push queued, inbox row kept\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - muted kind queued %s\n', n, c); END IF;
  UPDATE public.notification_settings SET muted_kinds = '{}',
         category_prefs = jsonb_set(category_prefs, '{social,push}', 'false') WHERE user_id = r;
  INSERT INTO public.notifications (to_user_id, kind_key, title, context)
  VALUES (r, 'social.mentioned_in_post', 'C1', '{}'::jsonb) RETURNING id INTO id1;
  INSERT INTO public.notifications (to_user_id, kind_key, title, context)
  VALUES (r, 'game.player_joined', 'C2', jsonb_build_object('entity_type','game','entity_id',g)) RETURNING id INTO id2;
  n := n + 1;
  IF NOT EXISTS (SELECT 1 FROM net.http_request_queue q WHERE convert_from(q.body, 'UTF8')::jsonb ->> 'notification_id' = id1::text)
     AND EXISTS (SELECT 1 FROM public.notifications WHERE id = id1)
     AND EXISTS (SELECT 1 FROM net.http_request_queue q WHERE convert_from(q.body, 'UTF8')::jsonb ->> 'notification_id' = id2::text) THEN
    tap := tap || format(E'ok %s - social push off: no social push, inbox row kept; negative control: games kind still pushed\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - category off\n', n); END IF;
  UPDATE public.notification_settings SET category_prefs = jsonb_set(category_prefs, '{social,push}', 'true') WHERE user_id = r;

  -------------------------------------------------------------------------------------------------------- security
  UPDATE public.notification_settings SET push_enabled = false, quiet_start_min = m, quiet_end_min = (m + 30) % 1440 WHERE user_id = r;
  INSERT INTO public.notifications (to_user_id, kind_key, title, context)
  VALUES (r, 'security.new_signin', 'New sign-in to your Dabbler account', '{}'::jsonb) RETURNING id INTO id1;
  INSERT INTO public.notifications (to_user_id, kind_key, title, context)
  VALUES (r, 'game.removed', 'S2', jsonb_build_object('entity_type','game','entity_id',g)) RETURNING id INTO id2;
  SELECT convert_from(q.body, 'UTF8')::jsonb INTO b FROM net.http_request_queue q
   WHERE convert_from(q.body, 'UTF8')::jsonb ->> 'notification_id' = id1::text;
  n := n + 1;
  IF b #>> '{delivery,mode}' = 'alert' AND (b #>> '{delivery,time_sensitive}')::boolean
     AND b #>> '{delivery,android_channel_id}' = 'dabbler_security' AND b #>> '{delivery,ios_category}' = 'DABBLER_SECURITY'
     AND NOT EXISTS (SELECT 1 FROM net.http_request_queue q WHERE convert_from(q.body, 'UTF8')::jsonb ->> 'notification_id' = id2::text) THEN
    tap := tap || format(E'ok %s - security kind alerts (time-sensitive) with push switched off in quiet hours; negative control: a game kind is not pushed\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - security: %s\n', n, b -> 'delivery'); END IF;
  UPDATE public.notification_settings SET push_enabled = true, quiet_start_min = (m + 60) % 1440, quiet_end_min = (m + 120) % 1440 WHERE user_id = r;

  ------------------------------------------------------------------------------------------------------ activities
  UPDATE public.notification_settings SET category_prefs = jsonb_set(category_prefs, '{games,push}', 'false') WHERE user_id = r;
  INSERT INTO public.notifications (to_user_id, kind_key, title, context)
  VALUES (r, 'activity.checkin_open', 'A1', jsonb_build_object('entity_type','game','entity_id',g)) RETURNING id INTO id1;
  INSERT INTO public.notifications (to_user_id, kind_key, title, context)
  VALUES (r, 'activity.checkin_open', 'A2', jsonb_build_object('entity_type','meetup','entity_id',g)) RETURNING id INTO id2;
  SELECT convert_from(q.body, 'UTF8')::jsonb INTO b FROM net.http_request_queue q
   WHERE convert_from(q.body, 'UTF8')::jsonb ->> 'notification_id' = id2::text;
  n := n + 1;
  IF NOT EXISTS (SELECT 1 FROM net.http_request_queue q WHERE convert_from(q.body, 'UTF8')::jsonb ->> 'notification_id' = id1::text)
     AND b #>> '{delivery,android_channel_id}' = 'dabbler_activities' AND b #>> '{data,meetup_id}' = g::text THEN
    tap := tap || format(E'ok %s - activities: games push off stops a game activity; negative control: the meetup activity is pushed (with meetup_id)\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - activities: %s\n', n, b); END IF;
  UPDATE public.notification_settings SET category_prefs = jsonb_set(category_prefs, '{games,push}', 'true') WHERE user_id = r;

  -------------------------------------------------------------------------------------------------------- language
  UPDATE public.profiles SET language = 'ar' WHERE user_id = r;
  id1 := public.notify_v2(r, 'game.player_joined', '{}', 'game', g, NULL, NULL, 'kan979:lang-ar', NULL, NULL);
  UPDATE public.profiles SET language = 'en' WHERE user_id = r;
  id2 := public.notify_v2(r, 'game.player_joined', '{}', 'game', g, NULL, NULL, 'kan979:lang-en', NULL, NULL);
  SELECT (SELECT convert_from(q.body, 'UTF8')::jsonb ->> 'title' FROM net.http_request_queue q
           WHERE convert_from(q.body, 'UTF8')::jsonb ->> 'notification_id' = id1::text) || ' | ' ||
         (SELECT convert_from(q.body, 'UTF8')::jsonb ->> 'title' FROM net.http_request_queue q
           WHERE convert_from(q.body, 'UTF8')::jsonb ->> 'notification_id' = id2::text) INTO t;
  n := n + 1;
  -- expected text from the live templates (KAN-982 reworded game.player_joined after the first run)
  IF t = (SELECT public.notify_v2_render(title_template_ar, '{"actor":"شخص ما"}', 'ar') || ' | '
              || public.notify_v2_render(title_template_en, '{"actor":"Someone"}', 'en')
            FROM public.notification_kinds WHERE key = 'game.player_joined')
     AND split_part(t, ' | ', 1) ~ '[؀-ۿ]' AND split_part(t, ' | ', 2) !~ '[؀-ۿ]' THEN
    tap := tap || format(E'ok %s - push text in the recipient language (AR | EN control): %s\n', n, t);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - language: %s\n', n, t); END IF;
  SELECT convert_from(q.body, 'UTF8')::jsonb INTO b FROM net.http_request_queue q
   WHERE convert_from(q.body, 'UTF8')::jsonb ->> 'notification_id' = id2::text;
  n := n + 1;
  IF b #>> '{data,dedupe_key}' = 'kan979:lang-en' THEN
    tap := tap || format(E'ok %s - payload carries dedupe_key\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - dedupe_key: %s\n', n, b -> 'data'); END IF;

  ---------------------------------------------------------------------------------------------- message snippet hook
  PERFORM set_config('dabbler.push_body', 'snippet: see you at 8', true);
  INSERT INTO public.notifications (to_user_id, kind_key, title, body, context)
  VALUES (r, 'message.received', 'New message from Sara', 'Open the chat to read it.', '{}'::jsonb) RETURNING id INTO id1;
  INSERT INTO public.notifications (to_user_id, kind_key, title, body, context)
  VALUES (r, 'message.received', 'New message from Sara', 'Open the chat to read it.', '{}'::jsonb) RETURNING id INTO id2;
  SELECT (SELECT convert_from(q.body, 'UTF8')::jsonb ->> 'body' FROM net.http_request_queue q
           WHERE convert_from(q.body, 'UTF8')::jsonb ->> 'notification_id' = id1::text) || ' | ' ||
         (SELECT convert_from(q.body, 'UTF8')::jsonb ->> 'body' FROM net.http_request_queue q
           WHERE convert_from(q.body, 'UTF8')::jsonb ->> 'notification_id' = id2::text) || ' | ' ||
         (SELECT body FROM public.notifications WHERE id = id1) INTO t;
  n := n + 1;
  IF t = 'snippet: see you at 8 | Open the chat to read it. | Open the chat to read it.' THEN
    tap := tap || format(E'ok %s - snippet travels in the push only, once; the row keeps its body (DABBLER_MESSAGE)\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - snippet: %s\n', n, t); END IF;

  --------------------------------------------------------------------------------------------- default quiet hours
  n := n + 1;
  IF public.is_quiet_hour(nobody, (current_date + time '03:00') AT TIME ZONE 'Asia/Dubai')
     AND NOT public.is_quiet_hour(nobody, (current_date + time '09:00') AT TIME ZONE 'Asia/Dubai') THEN
    tap := tap || format(E'ok %s - no settings row: quiet 00:00-08:00 Asia/Dubai (03:00 quiet; control 09:00 not)\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - default quiet hours\n', n); END IF;
  DELETE FROM public.notification_settings WHERE user_id = a;
  INSERT INTO public.notification_settings (user_id) VALUES (a);
  SELECT quiet_start_min::text || '/' || quiet_end_min::text INTO t FROM public.notification_settings WHERE user_id = a;
  n := n + 1;
  IF t = '0/480' THEN tap := tap || format(E'ok %s - a new settings row defaults to 0/480\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - new row defaults %s\n', n, t); END IF;

  ------------------------------------------------------------------------------------------------- grants and table
  n := n + 1;
  IF NOT has_sequence_privilege('anon', 'public.notification_deliveries_id_seq', 'USAGE')
     AND NOT has_sequence_privilege('authenticated', 'public.notification_deliveries_id_seq', 'UPDATE')
     AND NOT has_sequence_privilege('authenticated', 'public.notification_deliveries_id_seq', 'USAGE')
     AND has_sequence_privilege('service_role', 'public.notification_deliveries_id_seq', 'USAGE') THEN
    tap := tap || format(E'ok %s - delivery sequence: anon/authenticated nothing; control: service_role USAGE\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - sequence ACL\n', n); END IF;
  n := n + 1;
  IF NOT has_table_privilege('anon', 'public.notification_deliveries', 'SELECT')
     AND NOT has_table_privilege('authenticated', 'public.notification_deliveries', 'INSERT')
     AND NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public'
                      AND table_name = 'notification_deliveries' AND column_name ILIKE '%token' ) THEN
    tap := tap || format(E'ok %s - notification_deliveries: no anon read, no client insert, no token column\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - deliveries table grants/columns\n', n); END IF;
  n := n + 1;
  IF NOT has_function_privilege('authenticated', 'public.notification_push_enabled(uuid,text,text)', 'EXECUTE')
     AND NOT has_function_privilege('anon', 'public.notification_push_category(text)', 'EXECUTE')
     AND has_function_privilege('service_role', 'public.notification_push_enabled(uuid,text,text)', 'EXECUTE') THEN
    tap := tap || format(E'ok %s - helpers are service_role only\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - helper grants\n', n); END IF;

  ------------------------------------------------------- R (KAN-979b): re-push hook for KAN-980 grouped rows
  UPDATE public.notification_settings SET muted_kinds = '{}', push_enabled = true,
         quiet_start_min = (m + 60) % 1440, quiet_end_min = (m + 120) % 1440 WHERE user_id = r;
  id1 := public.notify_v2(r, 'social.post_liked', '{}', 'post', g, a, NULL, 'kan979:agg', NULL, NULL);
  SELECT convert_from(q.body, 'UTF8')::jsonb INTO b FROM net.http_request_queue q
   WHERE convert_from(q.body, 'UTF8')::jsonb ->> 'notification_id' = id1::text;
  SELECT group_key INTO t FROM public.notifications WHERE id = id1;
  n := n + 1;
  IF t IS NOT NULL AND b #>> '{delivery,collapse_id}' = t AND b #>> '{delivery,thread_id}' = t
     AND b #>> '{delivery,mode}' = 'alert' AND b #>> '{data,repush}' = 'false' THEN
    tap := tap || format(E'ok %s - R1 first push of a grouped row uses group_key (%s) as collapse and thread id\n', n, t);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - R1 first grouped push: %s / %s\n', n, t, b -> 'delivery'); END IF;

  UPDATE public.notifications SET title = 'Grown title' WHERE id = id1;   -- what KAN-980 does in place
  PERFORM public.notification_repush(id1);
  SELECT count(*) INTO c FROM net.http_request_queue q WHERE convert_from(q.body, 'UTF8')::jsonb ->> 'notification_id' = id1::text;
  SELECT convert_from(q.body, 'UTF8')::jsonb INTO b FROM net.http_request_queue q
   WHERE convert_from(q.body, 'UTF8')::jsonb ->> 'notification_id' = id1::text
     AND convert_from(q.body, 'UTF8')::jsonb #>> '{data,repush}' = 'true';
  n := n + 1;
  IF c = 2 AND b #>> '{title}' = 'Grown title' AND b #>> '{delivery,mode}' = 'silent'
     AND NOT (b #>> '{delivery,time_sensitive}')::boolean AND b #>> '{delivery,android_channel_id}' = 'dabbler_quiet'
     AND b #>> '{delivery,collapse_id}' = t AND b #>> '{delivery,thread_id}' = t THEN
    tap := tap || format(E'ok %s - R2 repush sends the current title, silent (no sound), same collapse/thread id, not time-sensitive\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - R2 repush: count %s, %s\n', n, c, b); END IF;

  UPDATE public.notification_settings SET muted_kinds = ARRAY['social.post_liked'] WHERE user_id = r;
  PERFORM public.notification_repush(id1);
  SELECT count(*) INTO c FROM net.http_request_queue q WHERE convert_from(q.body, 'UTF8')::jsonb ->> 'notification_id' = id1::text;
  UPDATE public.notification_settings SET muted_kinds = '{}', category_prefs = jsonb_set(category_prefs, '{social,push}', 'false') WHERE user_id = r;
  PERFORM public.notification_repush(id1);
  n := n + 1;
  IF c = 2 AND (SELECT count(*) FROM net.http_request_queue q WHERE convert_from(q.body, 'UTF8')::jsonb ->> 'notification_id' = id1::text) = 2 THEN
    tap := tap || format(E'ok %s - R3 negative control: repush of a muted kind, or with social push off, sends nothing and does not raise\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - R3 blocked repush queued\n', n); END IF;
  UPDATE public.notification_settings SET category_prefs = jsonb_set(category_prefs, '{social,push}', 'true') WHERE user_id = r;

  INSERT INTO public.notifications (to_user_id, kind_key, title, context)
  VALUES (r, 'social.mentioned_in_post', 'R4', '{}'::jsonb) RETURNING id INTO id2;
  PERFORM public.notification_repush(id2);
  PERFORM public.notification_repush('00000000-0000-0000-0000-000000000000');
  n := n + 1;
  IF (SELECT count(*) FROM net.http_request_queue q WHERE convert_from(q.body, 'UTF8')::jsonb ->> 'notification_id' = id2::text) = 1 THEN
    tap := tap || format(E'ok %s - R4 a row without group_key, or a missing id, is not re-pushed (only its insert push exists)\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - R4 ungrouped repush\n', n); END IF;

  n := n + 1;
  IF NOT has_function_privilege('authenticated', 'public.notification_repush(uuid)', 'EXECUTE')
     AND NOT has_function_privilege('anon', 'public.notification_repush(uuid)', 'EXECUTE')
     AND NOT has_function_privilege('authenticated', 'public.notification_push_dispatch(uuid,boolean)', 'EXECUTE')
     AND has_function_privilege('service_role', 'public.notification_repush(uuid)', 'EXECUTE')
     AND (SELECT prosecdef FROM pg_proc WHERE oid = 'public.notification_repush(uuid)'::regprocedure) THEN
    tap := tap || format(E'ok %s - R5 notification_repush and dispatch: SECURITY DEFINER, service_role only\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - R5 repush grants\n', n); END IF;

  -------------------------------------------------- P (KAN-979b): grouped templates read for one or many
  SELECT public.notify_v2_render(title_template_en, '{"actor":"Sara and 2 others","title":"Run club"}', 'en') || ' | ' ||
         public.notify_v2_render(title_template_en, '{"actor":"Sara","title":"Run club"}', 'en') || ' | ' ||
         public.notify_v2_render(title_template_ar, '{"actor":"سارة وشخصان آخران","title":"Run club"}', 'ar')
    INTO t FROM public.notification_kinds WHERE key = 'meetup.rsvp_interested';
  n := n + 1;
  IF t = 'Sara and 2 others showed interest in Run club | Sara showed interest in Run club | اهتمام بـ Run club من سارة وشخصان آخران' THEN
    tap := tap || format(E'ok %s - P1 interested template reads for many and one (EN, AR): %s\n', n, t);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - P1 interested: %s\n', n, t); END IF;
  n := n + 1;
  IF NOT EXISTS (SELECT 1 FROM public.notification_kinds WHERE title_template_en LIKE '{actor} is %'
                    AND key IN (SELECT kind_key FROM public.notification_aggregation_rules WHERE enabled)) THEN
    tap := tap || format(E'ok %s - P2 no grouped kind uses a singular "{actor} is" template\n', n);
  ELSE bad := bad + 1; tap := tap || format(E'not ok %s - P2 singular grouped template remains\n', n); END IF;

  RAISE EXCEPTION E'KAN-979 TAP (rolled back)\n1..%\n%# % failed of %', n, tap, bad, n;
END
$tap$;
