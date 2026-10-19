-- KAN-572: chat messages create a phone push through the EXISTING notifications path.
-- AUTHORED, NOT APPLIED. Apply is the operations process's step after review.
--
-- CAUSE. public.msg_notify (latest text: KAN-560, 20261013160900) only calls realtime.send to each
-- member's private 'user:<uid>' topic. Realtime reaches an app that is open; it never reaches the OS
-- notification list. No messaging code inserts a public.notifications row or calls
-- send-push-notification, so a chat message has no push at all. A follow does:
-- trg_profile_follow_notify -> process_notification_event -> INSERT public.notifications ->
-- trg_push_on_notification_insert -> net.http_post send-push-notification -> FCM (fcm_tokens).
--
-- FIX. Reuse that path unchanged. (a) one new notification_kinds key 'message.received' with
-- push in default_channels (the push trigger only fires for kinds whose channels include push).
-- (b) msg_notify re-issued: the KAN-560 text verbatim, plus, for each recipient OTHER than the
-- sender, one INSERT into public.notifications. trg_push_on_notification_insert then applies the
-- user's push_enabled / muted_kinds / quiet hours and sends via the existing edge function.
-- No new sender, no new secret, no edge-function change.
--
-- PRIVACY. title is the fixed string 'New message', body is NULL: no message text, no sender
-- name, no media. context carries only entity_type 'conversation' and the conversation id.
-- action_route: '/messaging/game/<game id>' for a game chat, '/messaging/thread/<conversation id>'
-- for a DM. Nothing is logged except sqlstate.
--
-- RECIPIENTS. Exactly the KAN-560 wake-up set (active roster host/player/sub, or the two DM
-- members; muted members and members who blocked the sender skipped), minus the sender.
--
-- DEDUPE. A recipient who already has an UNREAD 'message.received' row for the same conversation
-- created in the last 2 minutes gets no new row (one push per burst, not one per message).
--
-- AUTHORING NOTE (T-058). Authored from the newest migration text, not from pg_get_functiondef:
-- this seat had no live access for this ticket. Before apply, diff the live msg_notify against
-- the KAN-560 text; any difference must be merged here first.
--
-- GRANTS. REVOKE ALL FROM PUBLIC and anon; EXECUTE to authenticated only (unchanged).
-- Rollback: supabase/tests/messaging/push_rollback.sql.

BEGIN;

INSERT INTO public.notification_kinds
  (key, label_en, label_ar, default_priority, default_channels, route_template, timing, is_active)
VALUES
  ('message.received',
   'New message',
   'رسالة جديدة',
   'normal'::public.notify_priority, '{inapp,push}'::public.notify_channel[],
   '/messaging', NULL, true)
ON CONFLICT (key) DO NOTHING;

CREATE OR REPLACE FUNCTION public.msg_notify(
  p_conversation_id uuid,
  p_seq bigint,
  p_access_mode text DEFAULT 'allowlist'
)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid     uuid := auth.uid();
  v_eval    record;
  v_payload jsonb;
  v_to      uuid;
  v_kind    text;
  v_route   text;
BEGIN
  IF v_uid IS NULL OR p_conversation_id IS NULL OR p_seq IS NULL OR p_seq < 1 THEN
    RETURN;
  END IF;

  SELECT * INTO v_eval FROM public.msg_evaluate(p_conversation_id, v_uid, p_access_mode);
  IF v_eval.allowed_action IS DISTINCT FROM 'send' THEN
    RETURN;
  END IF;

  -- KAN-547: stamp for the Messages list order. Quiet on failure.
  BEGIN
    UPDATE public.msg_conversations SET last_activity_at = now() WHERE id = p_conversation_id;
  EXCEPTION WHEN OTHERS THEN
    RAISE WARNING 'msg_notify stamp failed (sqlstate %)', SQLSTATE;
  END;

  v_payload := jsonb_build_object(
    'type', 'msg',
    'conversation_id', p_conversation_id,
    'seq', p_seq
  );

  -- KAN-572: the deep link the push opens. Content-free: ids only.
  SELECT c.kind INTO v_kind FROM public.msg_conversations c WHERE c.id = p_conversation_id;
  v_route := CASE
    WHEN v_kind = 'dm' THEN '/messaging/thread/' || p_conversation_id::text
    WHEN v_eval.game_id IS NOT NULL THEN '/messaging/game/' || v_eval.game_id::text
    ELSE '/messaging'
  END;

  FOR v_to IN
    SELECT r.user_id
      FROM public.game_roster r
     WHERE r.game_id = v_eval.game_id
       AND r.status = 'active'
       AND r.role IN ('host', 'player', 'sub')
       AND NOT EXISTS (
         SELECT 1
           FROM public.user_blocks b
          WHERE b.blocker_user_id = r.user_id
            AND b.blocked_user_id = v_uid
       )
       -- KAN-560: a muted member gets no wake-up (the chat is not hidden).
       AND NOT EXISTS (
         SELECT 1
           FROM public.msg_conversation_members mm
          WHERE mm.conversation_id = p_conversation_id
            AND mm.user_id = r.user_id
            AND mm.muted_at IS NOT NULL
       )
    UNION
    -- KAN-560: a DM has no roster; its recipients are the two members (the sender included), same rules.
    SELECT dm.user_id
      FROM public.msg_conversations c
      JOIN public.msg_conversation_members dm ON dm.conversation_id = c.id
     WHERE c.id = p_conversation_id
       AND c.kind = 'dm'
       AND dm.muted_at IS NULL
       AND NOT EXISTS (
         SELECT 1
           FROM public.user_blocks b
          WHERE b.blocker_user_id = dm.user_id
            AND b.blocked_user_id = v_uid
       )
  LOOP
    BEGIN
      PERFORM realtime.send(v_payload, 'msg', 'user:' || v_to::text, true);
    EXCEPTION WHEN OTHERS THEN
      RAISE WARNING 'msg_notify send failed (sqlstate %)', SQLSTATE;
    END;

    -- KAN-572: phone push through the existing notifications -> push trigger path.
    -- Never the sender; one row per unread burst per conversation.
    IF v_to <> v_uid THEN
      BEGIN
        IF NOT EXISTS (
          SELECT 1
            FROM public.notifications n
           WHERE n.to_user_id = v_to
             AND n.kind_key = 'message.received'
             AND n.is_read = false
             AND n.context->>'entity_id' = p_conversation_id::text
             AND n.created_at > now() - interval '2 minutes'
        ) THEN
          INSERT INTO public.notifications
            (to_user_id, kind_key, title, body, action_route, context, priority, is_read, created_at)
          VALUES
            (v_to, 'message.received', 'New message', NULL, v_route,
             jsonb_build_object('entity_type', 'conversation', 'entity_id', p_conversation_id),
             'normal', false, now());
        END IF;
      EXCEPTION WHEN OTHERS THEN
        RAISE WARNING 'msg_notify push failed (sqlstate %)', SQLSTATE;
      END;
    END IF;
  END LOOP;
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'msg_notify failed (sqlstate %)', SQLSTATE;
END;
$$;

REVOKE ALL ON FUNCTION public.msg_notify(uuid, bigint, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.msg_notify(uuid, bigint, text) TO authenticated;

-- Post-condition: anon and PUBLIC cannot execute; the kind exists with push.
DO $$
BEGIN
  IF has_function_privilege('anon', 'public.msg_notify(uuid,bigint,text)', 'EXECUTE') THEN
    RAISE EXCEPTION 'kan572: anon can execute msg_notify';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.notification_kinds
                  WHERE key = 'message.received' AND 'push' = ANY(default_channels)) THEN
    RAISE EXCEPTION 'kan572: message.received kind missing push';
  END IF;
END $$;

COMMIT;
