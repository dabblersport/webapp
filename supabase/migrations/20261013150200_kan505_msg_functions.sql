-- KAN-505 (Messaging T8) 3/4: msg_can_* permission functions and msg_authorize.
-- AUTHORED, NOT APPLIED. Team Habu. Project wtncuzcskpigqpmnxwws, non-prod branch first.
-- Requires 20261013150000_kan505_msg_registry.sql and
-- 20261013150100_kan505_msg_access_allowlist.sql.
--
-- Rules (KAN-496 consolidated report, section 6):
--   D5  writable iff NOT games.is_cancelled AND games.end_at >= now(), derived AT CALL TIME.
--       Read-only from end_at or cancellation. Nothing deleted. No timer and no trigger
--       for completion: nothing in this file fires on time passing.
--   D7  host/player/sub with roster status 'active' read and send; 'left' reads up to
--       left_at_seq only; 'kicked' and any other non-active status read nothing.
--       Spectators, non-members and guessed conversation ids are denied identically.
--   D4  blocks come from public.user_blocks ONLY. In a game (group) chat both parties stay
--       members and both may send; the blocker does not see the blocked user's messages,
--       returned as hidden_sender_ids for the Worker to filter.
--   D19 mode 'allowlist': a caller absent from msg_access_allowlist -> 'not_in_pilot'.
--
-- Access mode: MESSAGING_ACCESS_MODE (off | allowlist | all) lives in the Worker
-- (report 5.1) and is passed as p_access_mode. The default is 'allowlist' and any value
-- outside the three is denied ('messaging_off'), so a missing or wrong mode fails closed.
-- A user calling the RPC directly with 'all' learns only their own authorisation for a
-- conversation they are already rostered on; no message content is reachable here.
--
-- Typed denial reasons. The T7 API contract was NOT found in the repository, so these use
-- the KAN-496 report's names (T6 'removed', D5 'read_only', D19 'not_in_pilot') plus the
-- minimum needed to type every other branch:
--   not_authenticated  auth.uid() is null (forged / expired / absent token): no user_id.
--   messaging_off      mode 'off' or an unknown mode.
--   not_in_pilot       mode 'allowlist' and the caller is not allowlisted.
--   not_member         unknown conversation id, non-member, spectator (one reason, so a
--                      guessed id cannot be told apart from a real one).
--   removed            roster status 'kicked' or any other non-active, non-'left' status.
-- Allowed results carry allowed_action 'send' (reason null) or 'read' with reason
-- 'read_only' (game ended or cancelled) or 'left' (read up to left_at_seq).

-- Internal evaluator. Not callable by anon or authenticated.
CREATE OR REPLACE FUNCTION public.msg_evaluate(
  p_conversation_id uuid,
  p_user_id uuid,
  p_access_mode text DEFAULT 'allowlist'
)
RETURNS TABLE (allowed_action text, reason text, left_at_seq bigint, game_id uuid)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = 'public', 'pg_temp'
AS $$
DECLARE
  v_game_id   uuid;
  v_cancelled boolean;
  v_end_at    timestamptz;
  v_role      text;
  v_status    text;
  v_left_seq  bigint;
BEGIN
  IF p_user_id IS NULL THEN
    RETURN QUERY SELECT NULL::text, 'not_authenticated'::text, NULL::bigint, NULL::uuid;
    RETURN;
  END IF;

  IF p_access_mode IS NULL OR p_access_mode NOT IN ('allowlist', 'all') THEN
    RETURN QUERY SELECT NULL::text, 'messaging_off'::text, NULL::bigint, NULL::uuid;
    RETURN;
  END IF;

  IF p_access_mode = 'allowlist'
     AND NOT EXISTS (SELECT 1 FROM public.msg_access_allowlist a WHERE a.user_id = p_user_id) THEN
    RETURN QUERY SELECT NULL::text, 'not_in_pilot'::text, NULL::bigint, NULL::uuid;
    RETURN;
  END IF;

  SELECT c.game_id, g.is_cancelled, g.end_at
    INTO v_game_id, v_cancelled, v_end_at
    FROM public.msg_conversations c
    JOIN public.games g ON g.id = c.game_id
   WHERE c.id = p_conversation_id;

  IF v_game_id IS NULL THEN
    RETURN QUERY SELECT NULL::text, 'not_member'::text, NULL::bigint, NULL::uuid;
    RETURN;
  END IF;

  -- One user may hold more than one roster row (one per profile): an active row wins.
  SELECT r.role, r.status
    INTO v_role, v_status
    FROM public.game_roster r
   WHERE r.game_id = v_game_id
     AND r.user_id = p_user_id
     AND r.role IN ('host', 'player', 'sub')
   ORDER BY (r.status = 'active') DESC, (r.status = 'left') DESC, r.joined_at DESC
   LIMIT 1;

  IF v_status IS NULL THEN
    RETURN QUERY SELECT NULL::text, 'not_member'::text, NULL::bigint, NULL::uuid;
    RETURN;
  END IF;

  IF v_status = 'active' THEN
    IF NOT v_cancelled AND v_end_at >= now() THEN
      RETURN QUERY SELECT 'send'::text, NULL::text, NULL::bigint, v_game_id;
    ELSE
      RETURN QUERY SELECT 'read'::text, 'read_only'::text, NULL::bigint, v_game_id;
    END IF;
    RETURN;
  END IF;

  IF v_status = 'left' THEN
    SELECT m.left_at_seq INTO v_left_seq
      FROM public.msg_conversation_members m
     WHERE m.conversation_id = p_conversation_id
       AND m.user_id = p_user_id;
    -- No recorded left_at_seq fails closed: read up to 0, i.e. nothing.
    RETURN QUERY SELECT 'read'::text, 'left'::text, COALESCE(v_left_seq, 0), v_game_id;
    RETURN;
  END IF;

  -- 'kicked' and every other non-active status read nothing.
  RETURN QUERY SELECT NULL::text, 'removed'::text, NULL::bigint, NULL::uuid;
END;
$$;

CREATE OR REPLACE FUNCTION public.msg_can_read(
  p_conversation_id uuid,
  p_user_id uuid,
  p_access_mode text DEFAULT 'allowlist'
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = 'public', 'pg_temp'
AS $$
  SELECT COALESCE(
    (SELECT e.allowed_action IN ('read', 'send')
       FROM public.msg_evaluate(p_conversation_id, p_user_id, p_access_mode) e),
    false);
$$;

CREATE OR REPLACE FUNCTION public.msg_can_send(
  p_conversation_id uuid,
  p_user_id uuid,
  p_access_mode text DEFAULT 'allowlist'
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = 'public', 'pg_temp'
AS $$
  SELECT COALESCE(
    (SELECT e.allowed_action = 'send'
       FROM public.msg_evaluate(p_conversation_id, p_user_id, p_access_mode) e),
    false);
$$;

-- The Worker calls this with the user's own bearer token (D24, pass-through): PostgREST
-- verifies the token, so a forged or expired token never reaches here as a user, and
-- auth.uid() null yields no user_id. The user is never taken from a parameter.
CREATE OR REPLACE FUNCTION public.msg_authorize(
  p_conversation_id uuid,
  p_access_mode text DEFAULT 'allowlist'
)
RETURNS TABLE (
  user_id uuid,
  allowed_action text,
  reason text,
  left_at_seq bigint,
  member_user_ids uuid[],
  hidden_sender_ids uuid[]
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = 'public', 'pg_temp'
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_eval record;
BEGIN
  IF v_uid IS NULL THEN
    RETURN QUERY SELECT NULL::uuid, NULL::text, 'not_authenticated'::text, NULL::bigint,
                        NULL::uuid[], NULL::uuid[];
    RETURN;
  END IF;

  SELECT * INTO v_eval FROM public.msg_evaluate(p_conversation_id, v_uid, p_access_mode);

  IF v_eval.allowed_action IS NULL THEN
    RETURN QUERY SELECT v_uid, NULL::text, v_eval.reason, NULL::bigint,
                        NULL::uuid[], NULL::uuid[];
    RETURN;
  END IF;

  RETURN QUERY
  SELECT v_uid,
         v_eval.allowed_action,
         v_eval.reason,
         v_eval.left_at_seq,
         -- CURRENT active members, for fan-out.
         COALESCE((SELECT array_agg(DISTINCT r.user_id ORDER BY r.user_id)
                     FROM public.game_roster r
                    WHERE r.game_id = v_eval.game_id
                      AND r.status = 'active'
                      AND r.role IN ('host', 'player', 'sub')), '{}'::uuid[]),
         -- D4 group rule: users the caller blocked; the Worker hides their messages.
         COALESCE((SELECT array_agg(DISTINCT b.blocked_user_id ORDER BY b.blocked_user_id)
                     FROM public.user_blocks b
                    WHERE b.blocker_user_id = v_uid), '{}'::uuid[]);
END;
$$;

REVOKE ALL ON FUNCTION public.msg_evaluate(uuid, uuid, text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.msg_can_read(uuid, uuid, text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.msg_can_send(uuid, uuid, text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.msg_authorize(uuid, text) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.msg_evaluate(uuid, uuid, text) TO service_role;
GRANT EXECUTE ON FUNCTION public.msg_can_read(uuid, uuid, text) TO service_role;
GRANT EXECUTE ON FUNCTION public.msg_can_send(uuid, uuid, text) TO service_role;
GRANT EXECUTE ON FUNCTION public.msg_authorize(uuid, text) TO authenticated, service_role;
