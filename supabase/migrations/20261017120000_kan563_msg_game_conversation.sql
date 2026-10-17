-- KAN-563 (Messaging getGameConversation): public.msg_game_conversation(p_game_id, p_access_mode).   AUTHORED, NOT
-- APPLIED (operations applies). Needs KAN-505 (registry, msg_evaluate), KAN-529, KAN-560 (muted_at, msg_evaluate v3).
--
-- WHY: the Worker's GET /v1/games/{gameId}/conversation must turn a GAME id into the game's conversation and the
-- caller's authorisation in ONE call. No existing function does that: msg_authorize takes a conversation id, and
-- msg_my_conversations lists only conversations that already exist and cannot create one. Nothing creates a game's
-- registry row today.
--
-- WHAT IT DOES (identity auth.uid() only; no message content anywhere):
--   1. no token                          -> reason not_authenticated
--   2. no such game                      -> reason not_found
--   3. the game has no conversation yet: msg_evaluate on the nil id runs the SAME access-mode and pilot gates every
--      other call runs (messaging_off, not_in_pilot are returned as they are). Past the gates, a conversation row is
--      created ONLY when the caller has a host/player/sub roster row for the game (any status, so a removed member
--      still gets 'removed' below); INSERT ... ON CONFLICT (game_id) DO NOTHING then re-read, so two concurrent first
--      calls converge on one row. A caller with no roster row gets not_member and nothing is created.
--   4. msg_evaluate(conversation, caller, mode) decides, unchanged: send / read+(left|game_ended|game_cancelled) /
--      deny+(not_member|removed|not_in_pilot|messaging_off). Authorisation is NOT re-implemented here.
--   5. muted: the caller's own msg_conversation_members.muted_at only.
-- Returns one row: user_id, conversation_id, game_id, allowed_action, reason, left_at_seq, muted.
-- conversation_id is NULL on every denial, so a non-member learns nothing beyond the reason.
--
-- GRANTS: REVOKE ALL FROM PUBLIC and anon; EXECUTE to authenticated only. SECURITY DEFINER, search_path pinned,
-- owner not changed. Nothing is dropped. Rollback: supabase/tests/messaging/game_conversation_rollback.sql (revoke only).
BEGIN;

CREATE OR REPLACE FUNCTION public.msg_game_conversation(
  p_game_id uuid,
  p_access_mode text DEFAULT 'allowlist'
)
RETURNS TABLE (
  user_id         uuid,
  conversation_id uuid,
  game_id         uuid,
  allowed_action  text,
  reason          text,
  left_at_seq     bigint,
  muted           boolean
)
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid  uuid := auth.uid();
  v_conv uuid;
  v_eval record;
BEGIN
  IF v_uid IS NULL THEN
    RETURN QUERY SELECT NULL::uuid, NULL::uuid, NULL::uuid, NULL::text, 'not_authenticated'::text, NULL::bigint, false;
    RETURN;
  END IF;

  IF p_game_id IS NULL OR NOT EXISTS (SELECT 1 FROM public.games g WHERE g.id = p_game_id) THEN
    RETURN QUERY SELECT v_uid, NULL::uuid, NULL::uuid, NULL::text, 'not_found'::text, NULL::bigint, false;
    RETURN;
  END IF;

  SELECT c.id INTO v_conv FROM public.msg_conversations c WHERE c.game_id = p_game_id;

  IF v_conv IS NULL THEN
    -- The shared gates, by msg_evaluate itself: the nil id has no row, so past the gates it answers not_member.
    SELECT * INTO v_eval FROM public.msg_evaluate('00000000-0000-0000-0000-000000000000'::uuid, v_uid, p_access_mode);
    IF v_eval.reason IS DISTINCT FROM 'not_member' THEN
      RETURN QUERY SELECT v_uid, NULL::uuid, NULL::uuid, NULL::text, v_eval.reason, NULL::bigint, false;
      RETURN;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM public.game_roster r
                    WHERE r.game_id = p_game_id AND r.user_id = v_uid AND r.role IN ('host', 'player', 'sub')) THEN
      RETURN QUERY SELECT v_uid, NULL::uuid, NULL::uuid, NULL::text, 'not_member'::text, NULL::bigint, false;
      RETURN;
    END IF;
    INSERT INTO public.msg_conversations (kind, game_id) VALUES ('game', p_game_id)
    -- the constraint by name: a bare (game_id) target would be ambiguous with the OUT column of the same name.
    ON CONFLICT ON CONSTRAINT msg_conversations_game_id_key DO NOTHING;
    SELECT c.id INTO v_conv FROM public.msg_conversations c WHERE c.game_id = p_game_id;
  END IF;

  SELECT * INTO v_eval FROM public.msg_evaluate(v_conv, v_uid, p_access_mode);

  IF v_eval.allowed_action IS NULL THEN
    RETURN QUERY SELECT v_uid, NULL::uuid, NULL::uuid, NULL::text, v_eval.reason, NULL::bigint, false;
    RETURN;
  END IF;

  RETURN QUERY
  SELECT v_uid, v_conv, p_game_id, v_eval.allowed_action, v_eval.reason, v_eval.left_at_seq,
         EXISTS (SELECT 1 FROM public.msg_conversation_members m
                  WHERE m.conversation_id = v_conv AND m.user_id = v_uid AND m.muted_at IS NOT NULL);
END;
$$;

REVOKE ALL ON FUNCTION public.msg_game_conversation(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.msg_game_conversation(uuid, text) TO authenticated;

COMMIT;
