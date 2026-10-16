-- KAN-563 (Messaging Worker): two additive functions. 1) public.msg_game_conversation(p_game_id, p_access_mode) resolves the chat of a GAME from the
-- game id, creating its msg_conversations row on first use for an eligible member.   AUTHORED, NOT APPLIED (operations applies).
-- Needs KAN-505 (registry, msg_evaluate) and KAN-560 (muted_at). Additive: one new function, no DROP, no table change.
--
-- WHY: no existing function maps a game id to its conversation, and nothing creates the msg_conversations row of a game.
-- The Worker (GET /v1/games/{gameId}/conversation) needs both in ONE round trip, with the authorisation of
-- msg_authorize unchanged: the answer comes from msg_evaluate, the same evaluator, with the same access mode.
--
-- Identity is auth.uid() only. A row is created only when the caller passes the evaluator's mode/pilot gate AND holds a
-- host/player/sub roster row in active or left status, so a stranger can never create a conversation row for a game.
-- Result: ONE row. user_id (the verified caller, null with no token); conversation_id (null unless allowed);
-- game_id; allowed_action 'send' | 'read' | null; reason (the msg_evaluate reason: null, 'read_only', 'left',
-- 'game_ended', 'game_cancelled', 'not_member', 'removed', 'not_in_pilot', 'messaging_off', or 'not_found' for an unknown
-- game, or 'not_authenticated'); left_at_seq; muted (the caller's own flag). No message content, no member list.
-- GRANTS: REVOKE ALL FROM PUBLIC, anon; EXECUTE to authenticated only.
--
-- 2) public.msg_mute_conversation(p_conversation_id, p_muted, p_access_mode): the contract's mute and unmute in ONE round
-- trip. Identity is auth.uid(); the verdict is msg_evaluate's (so the pilot rule applies, as for msg_authorize). A caller the
-- evaluator allows to read or send (a left member and an ended game included) gets the flag written exactly as msg_set_muted
-- writes it (idempotent upsert of msg_conversation_members.muted_at); any other verdict writes nothing and is returned as its
-- reason. Result: one row (user_id, reason): reason null when applied. A DM or any conversation kind works the same way.
-- GRANTS for both: REVOKE ALL FROM PUBLIC, anon; EXECUTE to authenticated only.
-- ROLLBACK: supabase/tests/messaging/game_conversation_rollback.sql (revokes EXECUTE; nothing is dropped).
BEGIN;

CREATE OR REPLACE FUNCTION public.msg_game_conversation(
  p_game_id uuid,
  p_access_mode text DEFAULT 'allowlist'
)
RETURNS TABLE (
  user_id uuid,
  conversation_id uuid,
  game_id uuid,
  allowed_action text,
  reason text,
  left_at_seq bigint,
  muted boolean
)
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid    uuid := auth.uid();
  v_conv   uuid;
  v_eval   record;
  v_status text;
  v_muted  boolean;
BEGIN
  IF v_uid IS NULL THEN
    RETURN QUERY SELECT NULL::uuid, NULL::uuid, NULL::uuid, NULL::text, 'not_authenticated'::text, NULL::bigint, false;
    RETURN;
  END IF;

  IF p_game_id IS NULL OR NOT EXISTS (SELECT 1 FROM public.games g WHERE g.id = p_game_id) THEN
    RETURN QUERY SELECT v_uid, NULL::uuid, NULL::uuid, NULL::text, 'not_found'::text, NULL::bigint, false;
    RETURN;
  END IF;

  SELECT c.id INTO v_conv FROM public.msg_conversations c WHERE c.game_id = p_game_id AND c.kind = 'game';

  IF v_conv IS NULL THEN
    -- Gate first, create second. A nil id reaches only the evaluator's mode and pilot checks (then not_member).
    SELECT * INTO v_eval FROM public.msg_evaluate('00000000-0000-0000-0000-000000000000'::uuid, v_uid, p_access_mode);
    IF v_eval.reason IN ('messaging_off', 'not_in_pilot') THEN
      RETURN QUERY SELECT v_uid, NULL::uuid, p_game_id, NULL::text, v_eval.reason, NULL::bigint, false;
      RETURN;
    END IF;

    SELECT r.status INTO v_status
      FROM public.game_roster r
     WHERE r.game_id = p_game_id AND r.user_id = v_uid AND r.role IN ('host', 'player', 'sub')
     ORDER BY (r.status = 'active') DESC, (r.status = 'left') DESC, r.joined_at DESC
     LIMIT 1;
    IF v_status IS NULL THEN
      RETURN QUERY SELECT v_uid, NULL::uuid, p_game_id, NULL::text, 'not_member'::text, NULL::bigint, false;
      RETURN;
    END IF;
    IF v_status NOT IN ('active', 'left') THEN
      RETURN QUERY SELECT v_uid, NULL::uuid, p_game_id, NULL::text, 'removed'::text, NULL::bigint, false;
      RETURN;
    END IF;

    INSERT INTO public.msg_conversations (kind, game_id) VALUES ('game', p_game_id)
    ON CONFLICT (game_id) DO NOTHING;
    SELECT c.id INTO v_conv FROM public.msg_conversations c WHERE c.game_id = p_game_id AND c.kind = 'game';
  END IF;

  SELECT * INTO v_eval FROM public.msg_evaluate(v_conv, v_uid, p_access_mode);

  IF v_eval.allowed_action IS NULL THEN
    RETURN QUERY SELECT v_uid, NULL::uuid, p_game_id, NULL::text, v_eval.reason, NULL::bigint, false;
    RETURN;
  END IF;

  SELECT (m.muted_at IS NOT NULL) INTO v_muted
    FROM public.msg_conversation_members m
   WHERE m.conversation_id = v_conv AND m.user_id = v_uid;

  RETURN QUERY SELECT v_uid, v_conv, p_game_id, v_eval.allowed_action, v_eval.reason, v_eval.left_at_seq, COALESCE(v_muted, false);
END;
$$;

REVOKE ALL ON FUNCTION public.msg_game_conversation(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.msg_game_conversation(uuid, text) TO authenticated;

CREATE OR REPLACE FUNCTION public.msg_mute_conversation(
  p_conversation_id uuid,
  p_muted boolean,
  p_access_mode text DEFAULT 'allowlist'
)
RETURNS TABLE (user_id uuid, reason text)
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid  uuid := auth.uid();
  v_eval record;
BEGIN
  IF v_uid IS NULL THEN
    RETURN QUERY SELECT NULL::uuid, 'not_authenticated'::text;
    RETURN;
  END IF;
  IF p_conversation_id IS NULL OR p_muted IS NULL THEN
    RETURN QUERY SELECT v_uid, 'invalid_request'::text;
    RETURN;
  END IF;

  SELECT * INTO v_eval FROM public.msg_evaluate(p_conversation_id, v_uid, p_access_mode);
  IF v_eval.allowed_action IS NULL THEN
    RETURN QUERY SELECT v_uid, v_eval.reason;
    RETURN;
  END IF;

  INSERT INTO public.msg_conversation_members (conversation_id, user_id, muted_at)
  VALUES (p_conversation_id, v_uid, CASE WHEN p_muted THEN now() END)
  ON CONFLICT (conversation_id, user_id)
  DO UPDATE SET muted_at = EXCLUDED.muted_at, updated_at = now();

  RETURN QUERY SELECT v_uid, NULL::text;
END;
$$;

REVOKE ALL ON FUNCTION public.msg_mute_conversation(uuid, boolean, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.msg_mute_conversation(uuid, boolean, text) TO authenticated;

COMMIT;
