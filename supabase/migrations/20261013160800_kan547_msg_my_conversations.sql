-- KAN-547 (Messaging launch B1): the data the Messages list needs.   AUTHORED, NOT APPLIED. Apply is the
-- operations process's step (Memphis) after review.
--
-- WHAT IT ADDS
--   1. msg_conversations.last_activity_at timestamptz NOT NULL DEFAULT now() (existing rows are valid; no
--      backfill, nothing reads message content) and an index on it. Additive: IF NOT EXISTS forms only.
--   2. public.msg_notify re-issued with CREATE OR REPLACE. Signature, attributes, gate, recipients, payload and
--      quiet-failure behaviour are exactly the KAN-541 text; the ONLY addition is one UPDATE (inside its own
--      exception block) that sets last_activity_at = now() on the conversation, after the sender passes the
--      existing gate. A failed stamp warns with the sqlstate only and the wake-ups still go out; msg_notify
--      still never raises to the caller. (System lines do not stamp: they are not a user's message.)
--   3. public.msg_my_conversations(p_limit int DEFAULT 50): the signed-in user's own game chats, newest
--      activity first. Identity is auth.uid() only. It returns ids, game title, sport name, start and end time,
--      the caller's state and last_activity_at. No message content, no sender names, no member lists, no unread
--      counts, no previews.
--
-- STATE (derived at call time; the same membership rule msg_evaluate uses: one roster row per user and game,
-- role host/player/sub, an active row wins, then a left row, newest joined_at first)
--   active member, game not cancelled and end_at not passed -> 'send'
--   active member, game cancelled or ended                  -> 'read_only'
--   status 'left'                                           -> 'left'
--   kicked or any other non-active status                   -> EXCLUDED
--   no membership                                           -> empty set
-- Access mode: the list takes no mode and applies no pilot allowlist. It only reveals chats of games the caller
-- is already a member of; whether they may open one is still decided per chat by msg_authorize (mode 'all'
-- means every game member may use game chat).
--
-- ORDER AND LIMIT: last_activity_at descending, ties by the game's start_at descending; at most
-- least(greatest(p_limit, 1), 100) rows (a null limit means 50). The indexes it uses:
-- msg_conversation_members_user_idx (KAN-505, NOT recreated here) and msg_conversations_last_activity_idx.
--
-- GRANTS: REVOKE ALL FROM PUBLIC and anon; EXECUTE to authenticated only. SECURITY DEFINER, search_path pinned,
-- owner not changed. Nothing is removed.
-- ROLLBACK: supabase/tests/messaging/my_conversations_rollback.sql (revoke, and the previous msg_notify text).

ALTER TABLE public.msg_conversations
  ADD COLUMN IF NOT EXISTS last_activity_at timestamptz NOT NULL DEFAULT now();

CREATE INDEX IF NOT EXISTS msg_conversations_last_activity_idx
  ON public.msg_conversations (last_activity_at);

-- msg_notify: the KAN-541 text with the one added stamp statement.
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

CREATE OR REPLACE FUNCTION public.msg_my_conversations(p_limit int DEFAULT 50)
RETURNS TABLE (
  conversation_id  uuid,
  game_id          uuid,
  game_title       text,
  sport            text,
  start_at         timestamptz,
  end_at           timestamptz,
  state            text,
  last_activity_at timestamptz
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT c.id,
         g.id,
         g.title,
         s.name_en,
         g.start_at,
         g.end_at,
         CASE
           WHEN m.status = 'left' THEN 'left'
           WHEN g.is_cancelled OR g.end_at < now() THEN 'read_only'
           ELSE 'send'
         END,
         c.last_activity_at
    FROM public.msg_conversations c
    JOIN public.games g ON g.id = c.game_id
    LEFT JOIN public.sports s ON s.id = g.sport_id
    CROSS JOIN LATERAL (
      -- msg_evaluate's rule: one roster row per user and game, an active row wins, then a left row.
      SELECT r.status
        FROM public.game_roster r
       WHERE r.game_id = c.game_id
         AND r.user_id = auth.uid()
         AND r.role IN ('host', 'player', 'sub')
       ORDER BY (r.status = 'active') DESC, (r.status = 'left') DESC, r.joined_at DESC
       LIMIT 1
    ) m
   WHERE auth.uid() IS NOT NULL
     AND m.status IN ('active', 'left')
   ORDER BY c.last_activity_at DESC, g.start_at DESC
   LIMIT least(greatest(coalesce(p_limit, 50), 1), 100);
$$;

REVOKE ALL ON FUNCTION public.msg_my_conversations(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.msg_my_conversations(int) TO authenticated;
