-- KAN-558 (Messaging meetup chat): a meetup can have its own conversation.   AUTHORED, NOT APPLIED. Apply is the
-- operations process's step (Memphis) after PEER review.
--
-- REQUIRES (apply order): KAN-505, KAN-529, KAN-547, KAN-560 (DM shape, msg_evaluate/msg_authorize v3), KAN-555
-- (msg_my_conversations v2), KAN-563 (msg_game_conversation, which calls msg_evaluate and is NOT touched here).
--
-- CONFIRMED RULES (mirror the game rules exactly):
--   member      the meetup organiser (meetups.creator_user_id) always; any user whose meetup_rsvps.status = 'going'
--   leaver      meetup_rsvps.status = 'cancelled' (not the organiser): allowed_action 'read', reason 'left', up to
--               msg_conversation_members.left_at_seq (missing means 0, fails closed), exactly the game 'left' rule
--   not member  no RSVP, or 'interested' / 'pending' / 'declined' -> reason 'not_member' (never a member, so not
--               'removed', which is the game's kicked state and has no meetup equivalent)
--   read_only   meetups.is_cancelled -> reason 'game_cancelled' (cancelled wins over ended, as for games);
--               ended -> reason 'game_ended'. A meetup ends at end_at; end_at is nullable in the baseline, and a
--               meetup without one is treated as ending at start_at (fails closed). ASSUMPTION, flagged for the PO.
--   REASON STRINGS: the game vocabulary is reused verbatim (send / game_ended / game_cancelled / left / not_member) so
--   the Worker and clients need no new mapping. Column names come from 20260829080500_baseline_schema.sql:
--   meetups(id, creator_user_id, title, sport_id, start_at, end_at, is_cancelled) and
--   meetup_rsvps(meetup_id, user_id, status) with PRIMARY KEY (meetup_id, user_id) and status in
--   ('going','interested','pending','declined','cancelled').
--
-- WHAT THIS MIGRATION DOES (one transaction)
--   1. msg_conversations: kind may also be 'meetup' (the kind check is replaced the way KAN-560 replaced it); new
--      column meetup_id uuid NULL UNIQUE REFERENCES public.meetups (id) (no ON DELETE action, like game_id); the shape
--      check msg_conversations_kind_game_check is replaced: a game row has game_id and no meetup_id, a meetup row has
--      meetup_id and no game_id, a dm row has neither. The two constraint replacements are the ONLY drops.
--   2. msg_evaluate re-issued: a faithful copy of the KAN-560 text plus ONE added block (and its declarations) for
--      kind 'meetup', placed after the DM block. game_id is returned NULL for a meetup. The game and DM paths are
--      byte for byte KAN-560; the nil id KAN-563 passes still reaches the game path and answers not_member.
--   3. msg_authorize re-issued: the KAN-560 text; the member_user_ids CASE gains one leading WHEN for a meetup
--      (organiser + 'going' RSVPs). The DM and game expressions are unchanged.
--   4. msg_my_conversations re-issued with CREATE OR REPLACE (same result columns, so no rename is needed): the KAN-555
--      text plus one UNION ALL branch for meetup rows (kind 'meetup', game_title = meetup title, sport, start_at,
--      end_at from the meetup; game_id and counterpart columns NULL). Order and limit unchanged.
--   A diff of each function against its previous definition shows only these meetup additions.
--
-- WHAT CREATES A MEETUP ROW: nothing in this migration. No creator RPC is added (out of scope). A row is
-- INSERT INTO msg_conversations (kind, meetup_id) by an owner/service_role; the probes insert it inside BEGIN..ROLLBACK.
-- NOT IN THIS TICKET: msg_notify is NOT re-issued, so a meetup chat stamps last_activity_at but sends no Realtime
-- wake-ups (its recipient query is game-roster or kind 'dm' only). A follow-up is needed for meetup wake-ups.
--
-- GRANTS: re-asserted as KAN-560/KAN-555 did: msg_evaluate revoked from PUBLIC, anon, authenticated (internal);
-- msg_authorize EXECUTE to authenticated and service_role; msg_my_conversations EXECUTE to authenticated. SECURITY
-- DEFINER and pinned search_path kept; owners not changed. No content column.
-- ROLLBACK: supabase/tests/messaging/meetup_rollback.sql (refuses when any meetup row exists).

BEGIN;

-- 1. kind, meetup_id and the shape check
ALTER TABLE public.msg_conversations DROP CONSTRAINT IF EXISTS msg_conversations_kind_check;
ALTER TABLE public.msg_conversations
  ADD CONSTRAINT msg_conversations_kind_check CHECK (kind IN ('game', 'dm', 'meetup'));
ALTER TABLE public.msg_conversations
  ADD COLUMN IF NOT EXISTS meetup_id uuid CONSTRAINT msg_conversations_meetup_id_key UNIQUE
  REFERENCES public.meetups (id);
ALTER TABLE public.msg_conversations DROP CONSTRAINT IF EXISTS msg_conversations_kind_game_check;
ALTER TABLE public.msg_conversations
  ADD CONSTRAINT msg_conversations_kind_game_check
  CHECK ((kind = 'game' AND game_id IS NOT NULL AND meetup_id IS NULL)
      OR (kind = 'meetup' AND meetup_id IS NOT NULL AND game_id IS NULL)
      OR (kind = 'dm' AND game_id IS NULL AND meetup_id IS NULL));

-- 2. msg_evaluate: the KAN-560 text plus the meetup block
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
  v_meetup_id uuid;
  v_m_cancel  boolean;
  v_m_end_at  timestamptz;
  v_m_owner   uuid;
  v_m_status  text;
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

  -- KAN-558: a meetup chat. Membership comes from the meetup, not a roster: the organiser (creator_user_id) is always
  -- a member; an RSVP with status 'going' is a member; an RSVP with status 'cancelled' is a voluntary leaver (read
  -- up to left_at_seq, exactly the game 'left' rule); any other RSVP status, or none, is not a member. Lifecycle is
  -- the game rule with the game's reason strings: cancelled wins (game_cancelled), then ended (game_ended). A meetup
  -- with no end_at ends at its start_at (fails closed). game_id is returned NULL: a meetup is not a game.
  IF v_kind = 'meetup' THEN
    SELECT c.meetup_id, mt.is_cancelled, COALESCE(mt.end_at, mt.start_at), mt.creator_user_id
      INTO v_meetup_id, v_m_cancel, v_m_end_at, v_m_owner
      FROM public.msg_conversations c
      JOIN public.meetups mt ON mt.id = c.meetup_id
     WHERE c.id = p_conversation_id;
    IF v_meetup_id IS NULL THEN
      RETURN QUERY SELECT NULL::text, 'not_member'::text, NULL::bigint, NULL::uuid;
      RETURN;
    END IF;
    IF v_m_owner = p_user_id THEN
      v_m_status := 'going';
    ELSE
      SELECT r.status INTO v_m_status
        FROM public.meetup_rsvps r
       WHERE r.meetup_id = v_meetup_id
         AND r.user_id = p_user_id;
    END IF;
    IF v_m_status = 'going' THEN
      IF v_m_cancel THEN
        RETURN QUERY SELECT 'read'::text, 'game_cancelled'::text, NULL::bigint, NULL::uuid;
      ELSIF v_m_end_at >= now() THEN
        RETURN QUERY SELECT 'send'::text, NULL::text, NULL::bigint, NULL::uuid;
      ELSE
        RETURN QUERY SELECT 'read'::text, 'game_ended'::text, NULL::bigint, NULL::uuid;
      END IF;
      RETURN;
    END IF;
    IF v_m_status = 'cancelled' THEN
      SELECT m.left_at_seq INTO v_left_seq
        FROM public.msg_conversation_members m
       WHERE m.conversation_id = p_conversation_id
         AND m.user_id = p_user_id;
      RETURN QUERY SELECT 'read'::text, 'left'::text, COALESCE(v_left_seq, 0), NULL::uuid;
      RETURN;
    END IF;
    RETURN QUERY SELECT NULL::text, 'not_member'::text, NULL::bigint, NULL::uuid;
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

-- 3. msg_authorize: the KAN-560 text; member_user_ids gains the meetup case
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
         CASE WHEN EXISTS (SELECT 1 FROM public.msg_conversations mc
                            WHERE mc.id = p_conversation_id AND mc.kind = 'meetup') THEN
           -- KAN-558: a meetup's members are its organiser and its 'going' RSVPs.
           COALESCE((SELECT array_agg(DISTINCT x.uid ORDER BY x.uid)
                       FROM (SELECT mt.creator_user_id AS uid
                               FROM public.msg_conversations mc
                               JOIN public.meetups mt ON mt.id = mc.meetup_id
                              WHERE mc.id = p_conversation_id
                             UNION
                             SELECT r.user_id
                               FROM public.msg_conversations mc
                               JOIN public.meetup_rsvps r ON r.meetup_id = mc.meetup_id
                              WHERE mc.id = p_conversation_id
                                AND r.status = 'going') x), '{}'::uuid[])
         WHEN v_eval.game_id IS NULL THEN
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

-- 4. msg_my_conversations: the KAN-555 text plus meetup rows
CREATE OR REPLACE FUNCTION public.msg_my_conversations(p_limit int DEFAULT 50)
RETURNS TABLE (
  conversation_id    uuid,
  game_id            uuid,
  game_title         text,
  sport              text,
  start_at           timestamptz,
  end_at             timestamptz,
  state              text,
  last_activity_at   timestamptz,
  kind               text,
  counterpart_user_id uuid,
  counterpart_name   text,
  counterpart_avatar text,
  muted              boolean
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT t.conversation_id, t.game_id, t.game_title, t.sport, t.start_at, t.end_at, t.state, t.last_activity_at,
         t.kind, t.counterpart_user_id, t.counterpart_name, t.counterpart_avatar, t.muted
    FROM (
      -- Game chats: the KAN-547 query, unchanged, plus the new columns.
      SELECT c.id AS conversation_id,
             g.id AS game_id,
             g.title AS game_title,
             s.name_en AS sport,
             g.start_at AS start_at,
             g.end_at AS end_at,
             CASE
               WHEN m.status = 'left' THEN 'left'
               WHEN g.is_cancelled OR g.end_at < now() THEN 'read_only'
               ELSE 'send'
             END AS state,
             c.last_activity_at AS last_activity_at,
             'game'::text AS kind,
             NULL::uuid AS counterpart_user_id,
             NULL::text AS counterpart_name,
             NULL::text AS counterpart_avatar,
             EXISTS (SELECT 1 FROM public.msg_conversation_members mm
                      WHERE mm.conversation_id = c.id AND mm.user_id = auth.uid() AND mm.muted_at IS NOT NULL) AS muted
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
       WHERE c.kind = 'game'
         AND auth.uid() IS NOT NULL
         AND m.status IN ('active', 'left')

      UNION ALL

      -- Direct messages: the caller is a member; the starter sees it at once, the other member once a message exists.
      SELECT c.id,
             NULL::uuid,
             NULL::text,
             NULL::text,
             NULL::timestamptz,
             NULL::timestamptz,
             CASE
               WHEN EXISTS (SELECT 1 FROM public.user_blocks b
                             WHERE (b.blocker_user_id = auth.uid() AND b.blocked_user_id = o.user_id)
                                OR (b.blocker_user_id = o.user_id AND b.blocked_user_id = auth.uid()))
                 OR public.msg_user_unavailable(o.user_id) THEN 'read_only'
               ELSE 'send'
             END,
             c.last_activity_at,
             'dm'::text,
             o.user_id,
             pp.display_name,
             pp.avatar_url,
             me.muted_at IS NOT NULL
        FROM public.msg_conversations c
        JOIN public.msg_dm_pairs d ON d.conversation_id = c.id
        JOIN public.msg_conversation_members me ON me.conversation_id = c.id AND me.user_id = auth.uid()
        JOIN public.msg_conversation_members o ON o.conversation_id = c.id AND o.user_id <> auth.uid()
        LEFT JOIN LATERAL (
          -- the public profile only: the view hides benched and inactive users
          SELECT v.display_name, v.avatar_url
            FROM public.profiles p
            JOIN public.v_profile_public v ON v.id = p.id
           WHERE p.user_id = o.user_id
           ORDER BY (p.profile_type = 'personal') DESC, p.created_at ASC
           LIMIT 1
        ) pp ON true
       WHERE c.kind = 'dm'
         AND auth.uid() IS NOT NULL
         AND (d.started_by = auth.uid() OR c.last_activity_at > c.created_at)

      UNION ALL

      -- KAN-558: meetup chats. The organiser and 'going' RSVPs are members; a 'cancelled' RSVP is a leaver ('left');
      -- cancelled or ended (end_at, or start_at when there is no end_at) is read_only. The meetup's title, sport,
      -- start and end fill the same columns a game row uses; game_id and the counterpart columns are NULL.
      SELECT c.id,
             NULL::uuid,
             mt.title,
             ms.name_en,
             mt.start_at,
             mt.end_at,
             CASE
               WHEN mt.creator_user_id <> auth.uid() AND mr.status = 'cancelled' THEN 'left'
               WHEN mt.is_cancelled OR COALESCE(mt.end_at, mt.start_at) < now() THEN 'read_only'
               ELSE 'send'
             END,
             c.last_activity_at,
             'meetup'::text,
             NULL::uuid,
             NULL::text,
             NULL::text,
             EXISTS (SELECT 1 FROM public.msg_conversation_members mm
                      WHERE mm.conversation_id = c.id AND mm.user_id = auth.uid() AND mm.muted_at IS NOT NULL)
        FROM public.msg_conversations c
        JOIN public.meetups mt ON mt.id = c.meetup_id
        LEFT JOIN public.sports ms ON ms.id = mt.sport_id
        LEFT JOIN public.meetup_rsvps mr ON mr.meetup_id = mt.id AND mr.user_id = auth.uid()
       WHERE c.kind = 'meetup'
         AND auth.uid() IS NOT NULL
         AND (mt.creator_user_id = auth.uid() OR mr.status IN ('going', 'cancelled'))
    ) t
   ORDER BY t.last_activity_at DESC, t.start_at DESC NULLS LAST
   LIMIT least(greatest(coalesce(p_limit, 50), 1), 100);
$$;

REVOKE ALL ON FUNCTION public.msg_my_conversations(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.msg_my_conversations(int) TO authenticated;

COMMIT;
