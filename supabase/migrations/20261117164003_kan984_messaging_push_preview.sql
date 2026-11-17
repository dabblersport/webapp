-- KAN-984 [W1-B6] Messaging (Epic KAN-973).
--
-- * message.received moves to notify_v2, with one sender: msg_notify_core. The old direct INSERT in msg_notify is gone
--   in this same change.
-- * Push text (F-2): the title is the sender's name, or "Sender in Group" for a game or meetup chat; the body is the
--   message snippet when the recipient's notification_settings.message_preview is 'sender_and_message' (the default),
--   and the kind's generic body ("Open the chat to read it.") under 'sender_only'.
-- * The snippet is never stored: it reaches the push through the transaction-local setting dabbler.push_body (the
--   KAN-979 hook), set right before each recipient's notify_v2 call and cleared right after.
-- * Meetup chats notify their members: the organiser and every RSVP with status 'going' (the msg_evaluate rule).
-- * Conversation mute (msg_conversation_members.muted_at) and a block in either direction (notify_v2) suppress the
--   notice. Kind mute, category flags and quiet hours (silent, never time-sensitive) are the push trigger's gate.
-- * Payload: conversation_id plus game_id or meetup_id in the push data (KAN-992 skips the alert for the open chat);
--   iOS category DABBLER_MESSAGE comes from notification_push_category (KAN-979).
-- * msg_notify(uuid,bigint,text), which the deployed Worker calls, keeps its signature and now sends sender-only
--   pushes. A new overload msg_notify(uuid,bigint,text,text) takes the snippet; the Worker change that calls it is in
--   workers/messaging/src/notify.ts and is not deployed by this migration. Adding an overload avoids a DROP.
-- * notification_push_dispatch (KAN-979) consumes dabbler.push_body before any gate, so a snippet can never carry over
--   to another row, and copies conversation_id / game_id / meetup_id from args into the push data.

-- 0. Pre-image guard -------------------------------------------------------------------------------------------------
DO $guard$
BEGIN
  IF md5(pg_get_functiondef('public.msg_notify(uuid,bigint,text)'::regprocedure)) <> '80c54b45abb09910649782a6846e067a' THEN
    RAISE EXCEPTION 'kan984 pre-image: msg_notify changed';
  END IF;
  IF md5(pg_get_functiondef('public.notification_push_dispatch(uuid,boolean)'::regprocedure)) <> '5e817b89c6c753580194e9b91053e8cb' THEN
    RAISE EXCEPTION 'kan984 pre-image: notification_push_dispatch changed';
  END IF;
  IF (SELECT count(*) FROM pg_proc WHERE proname = 'msg_notify' AND pronamespace = 'public'::regnamespace) <> 1
     OR to_regproc('public.msg_notify_core') IS NOT NULL THEN
    RAISE EXCEPTION 'kan984 pre-image: msg_notify overload or core already exists';
  END IF;
  IF (SELECT title_template_en FROM public.notification_kinds WHERE key = 'message.received') <> 'New message from {actor}' THEN
    RAISE EXCEPTION 'kan984 pre-image: message.received template changed';
  END IF;
END
$guard$;

-- 1. Templates: "Sender" or "Sender in Group" ------------------------------------------------------------------------
-- {in_group} comes from args in_group_en / in_group_ar (" in Kickabout" / " في Kickabout"); absent for a DM. The group
-- name is user data and is not translated.
UPDATE public.notification_kinds
   SET title_template_en = '{actor}{in_group}',
       title_template_ar = '{actor}{in_group}'
 WHERE key = 'message.received';

-- 2. The one sender of message.received ------------------------------------------------------------------------------
CREATE FUNCTION public.msg_notify_core(p_uid uuid, p_conversation_id uuid, p_seq bigint, p_access_mode text, p_snippet text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_eval      record;
  v_payload   jsonb;
  v_to        uuid;
  v_kind      text;
  v_game_id   uuid;
  v_meetup_id uuid;
  v_group     text;
  v_route     text;
  v_args      jsonb;
  v_snip      text;
  v_preview   text;
BEGIN
  IF p_uid IS NULL OR p_conversation_id IS NULL OR p_seq IS NULL OR p_seq < 1 THEN
    RETURN;
  END IF;
  SELECT * INTO v_eval FROM public.msg_evaluate(p_conversation_id, p_uid, p_access_mode);
  IF v_eval.allowed_action IS DISTINCT FROM 'send' THEN
    RETURN;
  END IF;
  BEGIN
    UPDATE public.msg_conversations SET last_activity_at = now() WHERE id = p_conversation_id;
  EXCEPTION WHEN OTHERS THEN
    RAISE WARNING 'msg_notify stamp failed (sqlstate %)', SQLSTATE;
  END;

  SELECT c.kind, c.game_id, c.meetup_id INTO v_kind, v_game_id, v_meetup_id
    FROM public.msg_conversations c WHERE c.id = p_conversation_id;
  v_game_id := COALESCE(v_eval.game_id, v_game_id);

  IF v_kind = 'game' THEN
    SELECT e.title INTO v_group
      FROM public.kan714_games_read g JOIN public.events e ON e.id = g.event_id WHERE g.id = v_game_id;
  ELSIF v_kind = 'meetup' THEN
    SELECT e.title INTO v_group
      FROM public.kan714_meetups_read mt JOIN public.events e ON e.id = mt.event_id WHERE mt.id = v_meetup_id;
  END IF;
  v_group := NULLIF(btrim(v_group), '');

  v_route := CASE
    WHEN v_kind = 'dm' THEN '/messaging/thread/' || p_conversation_id::text
    WHEN v_kind = 'game' AND v_game_id IS NOT NULL THEN '/messaging/game/' || v_game_id::text
    WHEN v_kind = 'meetup' AND v_meetup_id IS NOT NULL THEN '/meetups/' || v_meetup_id::text || '/chat'
    ELSE '/messaging'
  END;

  v_args := jsonb_strip_nulls(jsonb_build_object(
    'conversation_id', p_conversation_id::text,
    'game_id',         CASE WHEN v_kind = 'game' THEN v_game_id::text END,
    'meetup_id',       CASE WHEN v_kind = 'meetup' THEN v_meetup_id::text END,
    'in_group_en',     CASE WHEN v_kind <> 'dm' AND v_group IS NOT NULL THEN ' in ' || v_group END,
    'in_group_ar',     CASE WHEN v_kind <> 'dm' AND v_group IS NOT NULL THEN ' في ' || v_group END));

  -- the snippet: one line, at most 140 characters, never a blocklisted term
  v_snip := btrim(regexp_replace(regexp_replace(COALESCE(p_snippet, ''), '[[:cntrl:]]', ' ', 'g'), '\s+', ' ', 'g'));
  IF char_length(v_snip) > 140 THEN
    v_snip := left(v_snip, 139) || '…';
  END IF;
  v_snip := NULLIF(v_snip, '');
  IF v_snip IS NOT NULL AND public.content_hits_blocklist(v_snip) > 0 THEN
    v_snip := NULL;
  END IF;

  v_payload := jsonb_build_object('type', 'msg', 'conversation_id', p_conversation_id, 'seq', p_seq);

  FOR v_to IN
    WITH rec AS (
      SELECT r.user_id
        FROM public.game_roster r
       WHERE v_kind = 'game' AND r.game_id = v_game_id
         AND r.status = 'active' AND r.role IN ('host', 'player', 'sub')
      UNION
      SELECT dm.user_id
        FROM public.msg_conversation_members dm
       WHERE v_kind = 'dm' AND dm.conversation_id = p_conversation_id
      UNION
      SELECT e.creator_user_id
        FROM public.kan714_meetups_read mt JOIN public.events e ON e.id = mt.event_id
       WHERE v_kind = 'meetup' AND mt.id = v_meetup_id
      UNION
      SELECT rv.user_id
        FROM public.meetup_rsvps rv
       WHERE v_kind = 'meetup' AND rv.meetup_id = v_meetup_id AND rv.status = 'going'
    )
    SELECT rec.user_id FROM rec
     WHERE rec.user_id IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM public.msg_conversation_members mm
                        WHERE mm.conversation_id = p_conversation_id AND mm.user_id = rec.user_id
                          AND mm.muted_at IS NOT NULL)
       AND NOT EXISTS (SELECT 1 FROM public.user_blocks b
                        WHERE b.blocker_user_id = rec.user_id AND b.blocked_user_id = p_uid)
  LOOP
    BEGIN
      PERFORM realtime.send(v_payload, 'msg', 'user:' || v_to::text, true);
    EXCEPTION WHEN OTHERS THEN
      RAISE WARNING 'msg_notify send failed (sqlstate %)', SQLSTATE;
    END;
    IF v_to <> p_uid THEN
      BEGIN
        -- one notice per conversation per recipient while an unread one from the last 2 minutes exists (unchanged)
        IF NOT EXISTS (
          SELECT 1 FROM public.notifications n
           WHERE n.to_user_id = v_to AND n.kind_key = 'message.received' AND n.is_read = false
             AND n.context->>'entity_id' = p_conversation_id::text
             AND n.created_at > now() - interval '2 minutes'
        ) THEN
          SELECT COALESCE(s.message_preview, 'sender_and_message') INTO v_preview
            FROM public.notification_settings s WHERE s.user_id = v_to;
          v_preview := COALESCE(v_preview, 'sender_and_message');
          PERFORM set_config('dabbler.push_body',
                             CASE WHEN v_preview = 'sender_and_message' THEN COALESCE(v_snip, '') ELSE '' END, true);
          PERFORM public.notify_v2(
            v_to, 'message.received', v_args, 'conversation', p_conversation_id, p_uid,
            'msg:' || p_conversation_id::text || ':' || p_seq::text,
            'message.received:' || p_conversation_id::text || ':' || p_seq::text,
            'conv:' || p_conversation_id::text,
            v_route);
          PERFORM set_config('dabbler.push_body', '', true);
        END IF;
      EXCEPTION WHEN OTHERS THEN
        PERFORM set_config('dabbler.push_body', '', true);
        RAISE WARNING 'msg_notify push failed (sqlstate %)', SQLSTATE;
      END;
    END IF;
  END LOOP;
EXCEPTION WHEN OTHERS THEN
  PERFORM set_config('dabbler.push_body', '', true);
  RAISE WARNING 'msg_notify failed (sqlstate %)', SQLSTATE;
END;
$function$;

-- 3. The existing entry point (deployed Worker): sender-only, same signature, same grants ---------------------------
CREATE OR REPLACE FUNCTION public.msg_notify(p_conversation_id uuid, p_seq bigint, p_access_mode text DEFAULT 'allowlist'::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  -- KAN-984: the logic and the one sender of message.received live in msg_notify_core. No snippet on this path.
  PERFORM public.msg_notify_core(auth.uid(), p_conversation_id, p_seq, p_access_mode, NULL);
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'msg_notify failed (sqlstate %)', SQLSTATE;
END;
$function$;

-- 4. The snippet entry point (Worker after its KAN-984 deploy). No defaults: a 3-argument call resolves to the above.
CREATE FUNCTION public.msg_notify(p_conversation_id uuid, p_seq bigint, p_access_mode text, p_snippet text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  PERFORM public.msg_notify_core(auth.uid(), p_conversation_id, p_seq, p_access_mode, p_snippet);
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'msg_notify failed (sqlstate %)', SQLSTATE;
END;
$function$;

REVOKE ALL ON FUNCTION public.msg_notify_core(uuid, uuid, bigint, text, text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.msg_notify_core(uuid, uuid, bigint, text, text) TO service_role;
REVOKE ALL ON FUNCTION public.msg_notify(uuid, bigint, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.msg_notify(uuid, bigint, text, text) TO authenticated, service_role;

-- 5. Dispatch: snippet consumed before any gate; chat ids in the push data -------------------------------------------
-- Rebuilt from pg_get_functiondef (md5 5e817b89c6c753580194e9b91053e8cb).
CREATE OR REPLACE FUNCTION public.notification_push_dispatch(p_notification_id uuid, p_repush boolean DEFAULT false)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  n public.notifications%ROWTYPE;
  _kind public.notification_kinds%ROWTYPE;
  _anon_key text;
  _trigger_secret text;
  _entity_type text;
  _entity_id text;
  _breaks boolean;
  _quiet boolean;
  _collapse text;
  _badge int;
  _body text;
  _snippet text;
BEGIN
  SELECT * INTO n FROM public.notifications WHERE id = p_notification_id;
  IF NOT FOUND THEN
    RETURN false;
  END IF;
  _entity_type := NULLIF(n.context->>'entity_type', '');
  _entity_id := NULLIF(n.context->>'entity_id', '');
  _body := COALESCE(n.body, '');

  -- KAN-984: the snippet hook is consumed first, before any gate, so it can never carry over to another row.
  IF NOT p_repush THEN
    _snippet := NULLIF(current_setting('dabbler.push_body', true), '');
    IF _snippet IS NOT NULL THEN
      PERFORM set_config('dabbler.push_body', '', true);
    END IF;
  END IF;

  -- Only proceed for kinds whose default channels include push.
  SELECT * INTO _kind FROM public.notification_kinds WHERE key = n.kind_key;
  IF NOT FOUND OR _kind.default_channels IS NULL OR NOT ('push' = ANY(_kind.default_channels)) THEN
    RETURN false;
  END IF;

  -- Per-user push gate: master switch, muted kinds, category flags (activities follow games / meetups by entity).
  -- Security kinds are always on. The in-app row is never touched here.
  IF NOT public.notification_push_enabled(n.to_user_id, n.kind_key, _entity_type) THEN
    RETURN false;
  END IF;

  IF p_repush THEN
    -- KAN-980 growth re-push: replaces the group's push, no sound, never time-sensitive.
    _breaks := false;
    _quiet := true;
  ELSE
    -- KAN-979, I-2 / I-3: quiet hours deliver silently; breaks_quiet and security kinds alert and are time-sensitive.
    _breaks := COALESCE(_kind.breaks_quiet, false) OR public.notification_kind_is_unmutable(n.kind_key);
    _quiet := NOT _breaks AND public.is_quiet_hour(n.to_user_id, now());
  END IF;

  _collapse := CASE WHEN n.group_key IS NULL THEN NULL
                    WHEN octet_length(n.group_key) <= 64 THEN n.group_key
                    ELSE md5(n.group_key) END;

  SELECT count(*)::int INTO _badge FROM public.notifications x WHERE x.to_user_id = n.to_user_id AND NOT x.is_read;

  -- KAN-984 hook: the message snippet travels in the push only, for a messages kind; it is never stored.
  IF _kind.category = 'messages' AND _snippet IS NOT NULL THEN
    _body := _snippet;
  END IF;

  SELECT decrypted_secret INTO _anon_key FROM vault.decrypted_secrets WHERE name = 'supabase_anon_key' LIMIT 1;
  IF _anon_key IS NULL THEN
    RAISE WARNING 'notification_push_dispatch: supabase_anon_key not found in vault';
    RETURN false;
  END IF;
  SELECT decrypted_secret INTO _trigger_secret FROM vault.decrypted_secrets WHERE name = 'push_trigger_secret' LIMIT 1;
  IF _trigger_secret IS NULL THEN
    RAISE WARNING 'notification_push_dispatch: push_trigger_secret not found in vault';
    RETURN false;
  END IF;

  PERFORM net.http_post(
    url    := 'https://wtncuzcskpigqpmnxwws.supabase.co/functions/v1/send-push-notification',
    body   := jsonb_build_object(
      'user_id',         n.to_user_id,
      'notification_id', n.id,
      'title',           COALESCE(n.title, ''),
      'body',            _body,
      'data',            jsonb_build_object(
        'kind_key',        n.kind_key,
        'action_route',    COALESCE(n.action_route, ''),
        'entity_type',     COALESCE(_entity_type, ''),
        'entity_id',       COALESCE(_entity_id, ''),
        'notification_id', n.id::text,
        'dedupe_key',      COALESCE(n.dedupe_key, ''),
        'group_key',       COALESCE(n.group_key, ''),
        'repush',          CASE WHEN p_repush THEN 'true' ELSE 'false' END
      ) || CASE
        WHEN _entity_type = 'meetup' AND _entity_id IS NOT NULL
        THEN jsonb_build_object('meetup_id', _entity_id)   -- kept for meetupPushRoute in current builds
        ELSE '{}'::jsonb
      END
      -- KAN-984: the chat a message belongs to, so the app can skip the alert for the open chat (KAN-992)
      || jsonb_strip_nulls(jsonb_build_object(
           'conversation_id', n.args->>'conversation_id',
           'game_id',         n.args->>'game_id',
           'meetup_id',       n.args->>'meetup_id')),
      'delivery',        jsonb_build_object(
        'mode',               CASE WHEN _quiet THEN 'silent' ELSE 'alert' END,
        'time_sensitive',     _breaks,
        'android_channel_id', CASE WHEN _quiet THEN 'dabbler_quiet' ELSE 'dabbler_' || COALESCE(_kind.category, 'default') END,
        'ios_category',       public.notification_push_category(n.kind_key),
        'thread_id',          n.group_key,
        'collapse_id',        _collapse,
        'badge',              _badge
      )
    ),
    headers := jsonb_build_object(
      'Content-Type',     'application/json',
      'Authorization',    'Bearer ' || _anon_key,
      'x-trigger-secret', _trigger_secret
    )
  );
  RETURN true;
END;
$function$;

-- 6. Post-image guard ------------------------------------------------------------------------------------------------
DO $post$
DECLARE v text;
BEGIN
  -- one sender: no function other than msg_notify_core writes message.received
  SELECT string_agg(p.oid::regprocedure::text, ', ') INTO v FROM pg_proc p
   WHERE p.pronamespace = 'public'::regnamespace AND p.prokind = 'f'
     AND pg_get_functiondef(p.oid) ~ '''message\.received'''
     AND p.proname NOT IN ('msg_notify_core', 'notification_push_category');
  IF v IS NOT NULL THEN
    RAISE EXCEPTION 'kan984 post-image: another writer of message.received: %', v;
  END IF;
  IF (SELECT proacl::text FROM pg_proc WHERE oid = 'public.msg_notify_core(uuid,uuid,bigint,text,text)'::regprocedure)
       <> '{postgres=X/postgres,service_role=X/postgres}' THEN
    RAISE EXCEPTION 'kan984 post-image: msg_notify_core grants';
  END IF;
  IF has_function_privilege('anon', 'public.msg_notify(uuid,bigint,text,text)', 'EXECUTE')
     OR NOT has_function_privilege('authenticated', 'public.msg_notify(uuid,bigint,text,text)', 'EXECUTE')
     OR NOT has_function_privilege('authenticated', 'public.msg_notify(uuid,bigint,text)', 'EXECUTE') THEN
    RAISE EXCEPTION 'kan984 post-image: msg_notify grants';
  END IF;
END
$post$;
