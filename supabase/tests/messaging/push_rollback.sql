-- KAN-572 rollback. NOT RUN. Restores the KAN-560 msg_notify text verbatim and deactivates the
-- message.received kind (rows are kept; no row removed).
BEGIN;
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

  -- KAN-547: the one added statement. Stamps the conversation so the Messages list can order by
  -- recent activity. Quiet: a failed stamp warns (sqlstate only) and the wake-ups below still go out.
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
  END LOOP;
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'msg_notify failed (sqlstate %)', SQLSTATE;
END;
$$;

REVOKE ALL ON FUNCTION public.msg_notify(uuid, bigint, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.msg_notify(uuid, bigint, text) TO authenticated;
UPDATE public.notification_kinds SET is_active = false WHERE key = 'message.received';
COMMIT;
