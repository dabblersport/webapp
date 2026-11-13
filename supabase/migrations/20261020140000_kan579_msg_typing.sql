-- KAN-579: public.msg_typing sends an EPHEMERAL typing signal to the other current members of a conversation.
-- AUTHORED, NOT APPLIED. Apply is the operations process's step after review (needs-ops).
--
-- WHAT IT DOES. The signed-in member's Worker call (POST /v1/conversations/{id}/typing, which forwards the
-- caller's own bearer token, as it does for msg_notify) calls msg_typing(conversation, typing). For each other
-- eligible member the function calls
--     realtime.send(payload, 'typing', 'user:' || <member id>, true)
-- The last argument is the private flag and is ALWAYS true: the existing policy msg_user_topic_receive (KAN-505)
-- lets a user receive only on their own 'user:<uid>' topic. No policy is added or changed: the definer writes,
-- clients only receive. It is the same channel and the same authorisation as the KAN-541 message wake-up.
--
-- NOTHING DURABLE. No table of ours is read for writing, no row is inserted, updated or deleted by this
-- function, and no notification or push row is created (contrast msg_notify, which stamps last_activity_at and
-- inserts a push notification). A typing signal is a broadcast that is not kept on any table of ours.
--
-- PAYLOAD. Exactly jsonb {"type":"typing","conversation_id":<uuid>,"user_id":<uuid of the typer>,"on":<boolean>}.
-- Never message text, a draft, a name, media or a member list. The payload is never logged.
--
-- IDENTITY AND MEMBERSHIP. auth.uid() only; nothing about the caller comes from a parameter. The caller must
-- pass the same gate as sending (msg_evaluate returns allowed_action 'send'), so a removed, left, blocked or
-- suspended member, or a member of a finished game, signals nobody. The access mode defaults to 'allowlist'
-- exactly as msg_notify does; the Worker passes its own MESSAGING_ACCESS_MODE, so the kill switch applies.
--
-- RECIPIENTS. Exactly msg_notify's rules, minus the caller: the CURRENT active roster of the conversation's game
-- (status active; role host, player or sub) or the two members of a DM; never the caller; never a member who
-- has blocked the caller; never a member who muted the conversation (a muted chat does not get live signals).
--
-- QUIET FAILURE. A failure for one recipient is swallowed and does not stop the others; any other failure is
-- swallowed too. Each emits a WARNING carrying only the sqlstate: no payload, no ids. Never raises to the caller.
--
-- GRANTS. REVOKE ALL FROM PUBLIC and anon; EXECUTE to authenticated only. Nothing is removed.
-- Rollback: supabase/tests/messaging/typing_rollback.sql. Probes: supabase/tests/messaging/typing_probes.sql.
--
-- BEFORE APPLY (read-only, for Memphis): supabase/tests/messaging/notify_realtime_send_check.sql establishes the
-- signature, owner and privileges of realtime.send on this project; this function uses it the same way msg_notify does.

CREATE OR REPLACE FUNCTION public.msg_typing(
  p_conversation_id uuid,
  p_typing boolean,
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
BEGIN
  IF v_uid IS NULL OR p_conversation_id IS NULL OR p_typing IS NULL THEN
    RETURN;
  END IF;

  SELECT * INTO v_eval FROM public.msg_evaluate(p_conversation_id, v_uid, p_access_mode);
  IF v_eval.allowed_action IS DISTINCT FROM 'send' THEN
    RETURN;
  END IF;

  v_payload := jsonb_build_object(
    'type', 'typing',
    'conversation_id', p_conversation_id,
    'user_id', v_uid,
    'on', p_typing
  );

  FOR v_to IN
    SELECT r.user_id
      FROM public.game_roster r
     WHERE r.game_id = v_eval.game_id
       AND r.status = 'active'
       AND r.role IN ('host', 'player', 'sub')
       AND r.user_id <> v_uid
       AND NOT EXISTS (
         SELECT 1
           FROM public.user_blocks b
          WHERE b.blocker_user_id = r.user_id
            AND b.blocked_user_id = v_uid
       )
       AND NOT EXISTS (
         SELECT 1
           FROM public.msg_conversation_members mm
          WHERE mm.conversation_id = p_conversation_id
            AND mm.user_id = r.user_id
            AND mm.muted_at IS NOT NULL
       )
    UNION
    -- A DM has no roster; its recipients are its members other than the caller, same rules.
    SELECT dm.user_id
      FROM public.msg_conversations c
      JOIN public.msg_conversation_members dm ON dm.conversation_id = c.id
     WHERE c.id = p_conversation_id
       AND c.kind = 'dm'
       AND dm.user_id <> v_uid
       AND dm.muted_at IS NULL
       AND NOT EXISTS (
         SELECT 1
           FROM public.user_blocks b
          WHERE b.blocker_user_id = dm.user_id
            AND b.blocked_user_id = v_uid
       )
  LOOP
    BEGIN
      PERFORM realtime.send(v_payload, 'typing', 'user:' || v_to::text, true);
    EXCEPTION WHEN OTHERS THEN
      RAISE WARNING 'msg_typing send failed (sqlstate %)', SQLSTATE;
    END;
  END LOOP;
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'msg_typing failed (sqlstate %)', SQLSTATE;
END;
$$;

REVOKE ALL ON FUNCTION public.msg_typing(uuid, boolean, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.msg_typing(uuid, boolean, text) TO authenticated;
