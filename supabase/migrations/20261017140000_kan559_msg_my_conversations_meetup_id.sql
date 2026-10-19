-- KAN-559 (Messaging meetup list id): for kind meetup, game_id carries the meetup id.   AUTHORED, NOT APPLIED.
-- Apply is the operations process's step (Memphis) after PEER review.
--
-- REQUIRES (apply order): 20261017130000_kan558_msg_meetup_chat.sql (KAN-558), whose msg_my_conversations this replaces.
--
-- WHAT THIS MIGRATION DOES (one transaction): re-issues public.msg_my_conversations with CREATE OR REPLACE. The ONLY
-- change from the KAN-558 definition: in the meetup UNION ALL branch the game_id output column is mt.id (the meetup
-- id) instead of NULL::uuid. For kind meetup, game_id carries the meetup id; clients must read it together with kind.
-- The game and DM branches, the result columns, order and limit are unchanged, so no DROP of any kind is needed.
--
-- GRANTS: re-asserted as KAN-558 did (EXECUTE to authenticated; revoked from PUBLIC, anon). SECURITY DEFINER and the
-- pinned search_path kept; owner not changed. No content column.
-- ROLLBACK: supabase/tests/messaging/meetup_list_id_rollback.sql (restores the KAN-558 text verbatim).

BEGIN;

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
             mt.id,
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
