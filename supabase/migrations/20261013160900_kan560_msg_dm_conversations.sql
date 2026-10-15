-- KAN-560 (Messaging DMs B2): one-to-one direct messages in the registry.   AUTHORED, NOT APPLIED. Apply is the
-- operations process's step (Memphis) after review.
--
-- RULING (CEO 2026-10-15, orchestrator decisions): DMs exist between any two users aged 16 or over, even if they share
-- no event. Block and report work as in game chat. The recipient can mute. A daily cap limits NEW DM conversations
-- per user. No agent reads content; no message content is stored in Supabase (D12/D13).
--
-- REQUIRES (apply order): KAN-505 registry and functions, KAN-529 msg_evaluate, KAN-547 (last_activity_at, the msg_notify stamp).
--
-- WHAT THIS MIGRATION DOES (all in one transaction)
--   1. msg_conversations: kind may be 'game' or 'dm'; game_id may be NULL; a game row needs a game_id and a dm row
--      must not have one. This RELAXES constraints on an identifiers-only registry; no row and no data is removed.
--      The only two drops are the old kind check (re-added in this same transaction with the new list) and the
--      NOT NULL on game_id.
--   2. msg_conversation_members.muted_at timestamptz NULL (additive).
--   3. msg_dm_pairs: one row per pair (user_low < user_high, UNIQUE), identifiers only, started_by recorded. RLS on,
--      no policy, service_role only, like the registry.
--   4. Internal helpers (no grant to any API role): msg_user_unavailable(uuid) and msg_user_age_ok(uuid).
--        Age source: public.profiles.age (integer NOT NULL, one row per profile). A user is 16+ when they have at
--        least one profile and every profile of theirs has age >= 16; no profile means no age on record. A
--        SECURITY DEFINER function owned by postgres reads it.
--        Deleted or banned: auth.users has no row, deleted_at is set, or banned_until is in the future.
--   5. msg_evaluate re-issued (CREATE OR REPLACE, same signature and attributes). ONE added block, after the
--      access-mode and pilot gates, for conversations of kind 'dm'. The game-kind path is the KAN-529 text byte for
--      byte (a diff shows only the added declarations and the added block). In a DM: not a member -> not_member;
--      either user blocked the other -> allowed_action 'read', reason 'blocked' (BOTH sides: sending is refused,
--      history stays readable); the counterpart deleted or banned -> 'read', reason 'suspended'; otherwise 'send'.
--      No roster, no end time, no game state.
--   6. msg_authorize re-issued: only member_user_ids changes, for a DM (the two registry members); the game
--      expression is unchanged. msg_report_message is NOT re-issued: it only calls msg_evaluate, so a DM message
--      can be reported by a member exactly like a game message (it needs read access, which a blocked pair keeps).
--   7. msg_notify re-issued: a muted recipient gets no wake-up (the chat is not hidden), and a DM's recipients are
--      its two members. Everything else (gate, payload, activity stamp, quiet failure, never raises) is the KAN-547
--      text. Mute applies to game chats too.
--   8. msg_set_muted(p_conversation_id, p_muted): a member mutes or unmutes their own side. Identity auth.uid().
--      A non-member is refused with 'not_member'. Authenticated only.
--   9. msg_start_dm(p_other_user): returns the id of the DM between the caller and p_other_user, creating it when it
--      does not exist. Refusals (typed reason as the exception message, as msg_evaluate and msg_report_message do):
--        not_authenticated (28000)  no token
--        invalid_request   (22023)  null target, or the target is the caller
--        age_restricted    (42501)  the caller or the target is under 16 or has no age on record
--        not_found         (P0002)  the target is deleted or banned
--        blocked           (42501)  either user has blocked the other (direction is not revealed)
--        rate_limited      (54000)  the caller already started msg_dm_daily_cap (20) new DMs in the last 24 hours
--      Re-opening an EXISTING pair returns its id and never counts toward the cap. The creator is recorded in
--      msg_dm_pairs.started_by.
--
-- GRANTS: msg_start_dm and msg_set_muted: REVOKE ALL FROM PUBLIC and anon, EXECUTE to authenticated only. The two
-- helpers: no grant. All new functions are SECURITY DEFINER with a pinned search_path. Owners are not changed.
-- NOT IN THIS TICKET: the Worker's reason mapping for a read-only DM ('blocked', 'suspended' with allowed_action read)
-- and listing DMs in msg_my_conversations.
-- ROLLBACK: supabase/tests/messaging/dm_rollback.sql (refuses when any dm row exists).

BEGIN;

-- 1. kind and game_id
ALTER TABLE public.msg_conversations DROP CONSTRAINT IF EXISTS msg_conversations_kind_check;
ALTER TABLE public.msg_conversations
  ADD CONSTRAINT msg_conversations_kind_check CHECK (kind IN ('game', 'dm'));
ALTER TABLE public.msg_conversations ALTER COLUMN game_id DROP NOT NULL;
ALTER TABLE public.msg_conversations
  ADD CONSTRAINT msg_conversations_kind_game_check
  CHECK ((kind = 'game' AND game_id IS NOT NULL) OR (kind = 'dm' AND game_id IS NULL));

-- 2. mute
ALTER TABLE public.msg_conversation_members ADD COLUMN IF NOT EXISTS muted_at timestamptz;

-- 3. one DM per pair
CREATE TABLE IF NOT EXISTS public.msg_dm_pairs (
  conversation_id uuid PRIMARY KEY REFERENCES public.msg_conversations (id),
  user_low        uuid NOT NULL,
  user_high       uuid NOT NULL,
  started_by      uuid NOT NULL,
  created_at      timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT msg_dm_pairs_order_check CHECK (user_low < user_high),
  CONSTRAINT msg_dm_pairs_started_by_check CHECK (started_by IN (user_low, user_high)),
  CONSTRAINT msg_dm_pairs_pair_key UNIQUE (user_low, user_high)
);

COMMENT ON TABLE public.msg_dm_pairs IS
  'KAN-560: one row per direct-message pair. Identifiers only, no message content. Written by SECURITY DEFINER functions and service_role.';

CREATE INDEX IF NOT EXISTS msg_dm_pairs_started_by_idx ON public.msg_dm_pairs (started_by, created_at);

ALTER TABLE public.msg_dm_pairs ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.msg_dm_pairs FROM PUBLIC, anon, authenticated;
GRANT SELECT, INSERT, UPDATE ON TABLE public.msg_dm_pairs TO service_role;

-- 4. internal helpers
CREATE OR REPLACE FUNCTION public.msg_user_unavailable(p_user uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT NOT EXISTS (
    SELECT 1 FROM auth.users u
     WHERE u.id = p_user
       AND u.deleted_at IS NULL
       AND (u.banned_until IS NULL OR u.banned_until <= now())
  );
$$;

CREATE OR REPLACE FUNCTION public.msg_user_age_ok(p_user uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT EXISTS (SELECT 1 FROM public.profiles p WHERE p.user_id = p_user)
     AND NOT EXISTS (SELECT 1 FROM public.profiles p WHERE p.user_id = p_user AND (p.age IS NULL OR p.age < 16));
$$;

REVOKE ALL ON FUNCTION public.msg_user_unavailable(uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.msg_user_age_ok(uuid) FROM PUBLIC, anon, authenticated;

-- 5. msg_evaluate: the KAN-529 text plus the DM block
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
  v_kind      text;
  v_other     uuid;
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

  -- KAN-560: a one-to-one DM has no roster, no end time and no game state. Both members may read and send
  -- while neither has blocked the other; a block in either direction, or a counterpart who is deleted or
  -- banned, makes it read-only for BOTH (history stays readable, nothing is deleted). Game chats skip this branch.
  SELECT c.kind INTO v_kind FROM public.msg_conversations c WHERE c.id = p_conversation_id;
  IF v_kind = 'dm' THEN
    SELECT o.user_id INTO v_other
      FROM public.msg_conversation_members me
      JOIN public.msg_conversation_members o
        ON o.conversation_id = me.conversation_id AND o.user_id <> me.user_id
     WHERE me.conversation_id = p_conversation_id
       AND me.user_id = p_user_id;
    IF v_other IS NULL THEN
      RETURN QUERY SELECT NULL::text, 'not_member'::text, NULL::bigint, NULL::uuid;
      RETURN;
    END IF;
    IF EXISTS (SELECT 1 FROM public.user_blocks b
                WHERE (b.blocker_user_id = p_user_id AND b.blocked_user_id = v_other)
                   OR (b.blocker_user_id = v_other AND b.blocked_user_id = p_user_id)) THEN
      RETURN QUERY SELECT 'read'::text, 'blocked'::text, NULL::bigint, NULL::uuid;
      RETURN;
    END IF;
    IF public.msg_user_unavailable(v_other) THEN
      RETURN QUERY SELECT 'read'::text, 'suspended'::text, NULL::bigint, NULL::uuid;
      RETURN;
    END IF;
    RETURN QUERY SELECT 'send'::text, NULL::text, NULL::bigint, NULL::uuid;
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
    IF v_cancelled THEN
      -- Cancelled wins over ended: a cancelled game past its end time is still game_cancelled.
      RETURN QUERY SELECT 'read'::text, 'game_cancelled'::text, NULL::bigint, v_game_id;
    ELSIF v_end_at >= now() THEN
      RETURN QUERY SELECT 'send'::text, NULL::text, NULL::bigint, v_game_id;
    ELSE
      RETURN QUERY SELECT 'read'::text, 'game_ended'::text, NULL::bigint, v_game_id;
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

REVOKE ALL ON FUNCTION public.msg_evaluate(uuid, uuid, text) FROM PUBLIC, anon, authenticated;

-- 6. msg_authorize: the KAN-505 text; only member_user_ids differs, for a DM
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
         CASE WHEN v_eval.game_id IS NULL THEN
           -- KAN-560: a DM has no roster; its members are the two registry rows.
           COALESCE((SELECT array_agg(DISTINCT m.user_id ORDER BY m.user_id)
                       FROM public.msg_conversation_members m
                      WHERE m.conversation_id = p_conversation_id), '{}'::uuid[])
         ELSE
         COALESCE((SELECT array_agg(DISTINCT r.user_id ORDER BY r.user_id)
                     FROM public.game_roster r
                    WHERE r.game_id = v_eval.game_id
                      AND r.status = 'active'
                      AND r.role IN ('host', 'player', 'sub')), '{}'::uuid[])
         END,
         -- D4 group rule: users the caller blocked; the Worker hides their messages.
         COALESCE((SELECT array_agg(DISTINCT b.blocked_user_id ORDER BY b.blocked_user_id)
                     FROM public.user_blocks b
                    WHERE b.blocker_user_id = v_uid), '{}'::uuid[]);
END;
$$;

REVOKE ALL ON FUNCTION public.msg_authorize(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.msg_authorize(uuid, text) TO authenticated, service_role;

-- 7. msg_notify: the KAN-547 text; muted members skipped, DM recipients added
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

-- 8. mute
CREATE OR REPLACE FUNCTION public.msg_set_muted(p_conversation_id uuid, p_muted boolean)
RETURNS void
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
    RAISE EXCEPTION 'not_authenticated' USING ERRCODE = '28000';
  END IF;
  IF p_conversation_id IS NULL OR p_muted IS NULL THEN
    RAISE EXCEPTION 'invalid_request' USING ERRCODE = '22023';
  END IF;

  -- A member is anyone the evaluator knows (mode 'all': muting is not a pilot feature).
  SELECT * INTO v_eval FROM public.msg_evaluate(p_conversation_id, v_uid, 'all');
  IF v_eval.allowed_action IS NULL THEN
    RAISE EXCEPTION 'not_member' USING ERRCODE = '42501';
  END IF;

  INSERT INTO public.msg_conversation_members (conversation_id, user_id, muted_at)
  VALUES (p_conversation_id, v_uid, CASE WHEN p_muted THEN now() END)
  ON CONFLICT (conversation_id, user_id)
  DO UPDATE SET muted_at = EXCLUDED.muted_at, updated_at = now();
END;
$$;

REVOKE ALL ON FUNCTION public.msg_set_muted(uuid, boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.msg_set_muted(uuid, boolean) TO authenticated;

-- 9. start a DM
CREATE OR REPLACE FUNCTION public.msg_start_dm(p_other_user uuid)
RETURNS uuid
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  msg_dm_daily_cap CONSTANT int := 20;  -- new DM conversations one user may start per 24 hours
  v_uid  uuid := auth.uid();
  v_low  uuid;
  v_high uuid;
  v_conv uuid;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'not_authenticated' USING ERRCODE = '28000';
  END IF;
  IF p_other_user IS NULL OR p_other_user = v_uid THEN
    RAISE EXCEPTION 'invalid_request' USING ERRCODE = '22023';
  END IF;

  IF NOT public.msg_user_age_ok(v_uid) OR NOT public.msg_user_age_ok(p_other_user) THEN
    RAISE EXCEPTION 'age_restricted' USING ERRCODE = '42501';
  END IF;

  IF public.msg_user_unavailable(p_other_user) THEN
    RAISE EXCEPTION 'not_found' USING ERRCODE = 'P0002';
  END IF;

  IF EXISTS (SELECT 1 FROM public.user_blocks b
              WHERE (b.blocker_user_id = v_uid AND b.blocked_user_id = p_other_user)
                 OR (b.blocker_user_id = p_other_user AND b.blocked_user_id = v_uid)) THEN
    RAISE EXCEPTION 'blocked' USING ERRCODE = '42501';
  END IF;

  v_low := least(v_uid, p_other_user);
  v_high := greatest(v_uid, p_other_user);

  -- Two concurrent starts by one user, or for one pair, serialise here.
  PERFORM pg_advisory_xact_lock(hashtextextended('msg_dm_cap:' || v_uid::text, 0));
  PERFORM pg_advisory_xact_lock(hashtextextended('msg_dm_pair:' || v_low::text || ':' || v_high::text, 0));

  -- An existing pair is returned as it is and never counts toward the cap.
  SELECT d.conversation_id INTO v_conv
    FROM public.msg_dm_pairs d
   WHERE d.user_low = v_low AND d.user_high = v_high;
  IF v_conv IS NOT NULL THEN
    RETURN v_conv;
  END IF;

  IF (SELECT count(*) FROM public.msg_dm_pairs d
       WHERE d.started_by = v_uid
         AND d.created_at > now() - interval '24 hours') >= msg_dm_daily_cap THEN
    RAISE EXCEPTION 'rate_limited' USING ERRCODE = '54000';
  END IF;

  INSERT INTO public.msg_conversations (kind) VALUES ('dm') RETURNING id INTO v_conv;
  INSERT INTO public.msg_dm_pairs (conversation_id, user_low, user_high, started_by)
  VALUES (v_conv, v_low, v_high, v_uid);
  INSERT INTO public.msg_conversation_members (conversation_id, user_id) VALUES (v_conv, v_low), (v_conv, v_high);

  RETURN v_conv;
END;
$$;

REVOKE ALL ON FUNCTION public.msg_start_dm(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.msg_start_dm(uuid) TO authenticated;

COMMIT;
