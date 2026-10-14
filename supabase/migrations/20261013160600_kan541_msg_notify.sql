-- KAN-541 (Realtime R1): public.msg_notify sends a METADATA-ONLY wake-up to the private Realtime
-- topic of each current member after a message is stored.   AUTHORED, NOT APPLIED. Apply is the
-- operations process's step after review.
--
-- WHAT IT DOES. The caller (the signed-in sender, through PostgREST with their own bearer token)
-- calls msg_notify(conversation, seq) once the Worker has stored the message. For each eligible
-- recipient the function calls
--     realtime.send(payload, 'msg', 'user:' || <recipient id>, true)
-- The last argument is the private flag and is ALWAYS true: the existing policy
-- msg_user_topic_receive (KAN-505, migration 20261013150300) lets a user receive only on their own
-- 'user:<uid>' topic. No INSERT policy on realtime.messages is added: the definer writes, clients
-- only receive.
--
-- PAYLOAD. Exactly jsonb {"type":"msg","conversation_id":<uuid>,"seq":<bigint>}. Never message
-- text, sender, media, event type or a member list. The payload is never logged.
--
-- IDENTITY. auth.uid() only. Nothing about who the caller is comes from a parameter. The caller
-- must pass the same gate as sending (msg_evaluate returns allowed_action 'send'); otherwise the
-- function does nothing. The access mode defaults to 'allowlist' exactly as msg_authorize does
-- (an optional third parameter, so a two-argument call keeps working).
--
-- RECIPIENTS. The CURRENT active roster of the conversation's game (status active; role host,
-- player or sub: the same query msg_authorize uses for member_user_ids). Leavers, kicked and
-- removed members are not on that list. A recipient who has blocked the caller
-- (user_blocks.blocker_user_id = recipient, blocked_user_id = caller) is skipped. The sender's own
-- topic is included.
--
-- QUIET FAILURE. A failure for one recipient is swallowed and does not stop the others; any other
-- failure is swallowed too. Each emits a WARNING carrying only the sqlstate: no payload, no ids.
-- The function never raises to the caller.
--
-- GRANTS. REVOKE ALL FROM PUBLIC and anon; EXECUTE to authenticated only. Owner postgres (the
-- migration role). Nothing is removed. Rollback: supabase/tests/messaging/notify_rollback.sql.
--
-- BEFORE APPLY (read-only, for Memphis): supabase/tests/messaging/notify_realtime_send_check.sql
-- establishes the signature, owner and privileges of realtime.send on this project.

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
BEGIN
  IF v_uid IS NULL OR p_conversation_id IS NULL OR p_seq IS NULL OR p_seq < 1 THEN
    RETURN;
  END IF;

  SELECT * INTO v_eval FROM public.msg_evaluate(p_conversation_id, v_uid, p_access_mode);
  IF v_eval.allowed_action IS DISTINCT FROM 'send' THEN
    RETURN;
  END IF;

  v_payload := jsonb_build_object(
    'type', 'msg',
    'conversation_id', p_conversation_id,
    'seq', p_seq
  );

  FOR v_to IN
    SELECT DISTINCT r.user_id
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
  LOOP
    BEGIN
      PERFORM realtime.send(v_payload, 'msg', 'user:' || v_to::text, true);
    EXCEPTION WHEN OTHERS THEN
      RAISE WARNING 'msg_notify send failed (sqlstate %)', SQLSTATE;
    END;
  END LOOP;
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'msg_notify failed (sqlstate %)', SQLSTATE;
END;
$$;

REVOKE ALL ON FUNCTION public.msg_notify(uuid, bigint, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.msg_notify(uuid, bigint, text) TO authenticated;
