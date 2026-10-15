-- KAN-555 (Messaging DMs B3): the Messages list returns DM conversations as well as game chats.   AUTHORED, NOT
-- APPLIED. Apply is the operations process's step (Memphis) after review. Requires KAN-547 (msg_my_conversations v1,
-- last_activity_at) and KAN-560 (DM schema, msg_start_dm, msg_user_unavailable) applied first, and is applied once.
--
-- WHY THE v1 FUNCTION IS RENAMED, NOT REPLACED: this adds columns to the function's result. PostgreSQL does not allow
-- CREATE OR REPLACE FUNCTION to change a function's result columns (it fails with "cannot change return type of
-- existing function"), so a literal CREATE OR REPLACE cannot add them. The project's rename-not-remove practice (see KAN-499)
-- is followed instead: v1 is renamed to msg_my_conversations_v1 and its EXECUTE is revoked from the app; the new
-- function takes the name the app calls. Nothing is dropped. Rollback swaps the names back (my_conversations_dm_rollback.sql).
--
-- THE NEW FUNCTION: public.msg_my_conversations(p_limit int DEFAULT 50). Every v1 column and rule is kept, in the
-- same order, then five columns are added:
--   kind                'game' or 'dm'
--   counterpart_user_id the other member of a DM (NULL for a game row)
--   counterpart_name    their display name (NULL for a game row, and NULL when they have no public profile)
--   counterpart_avatar  their avatar reference, profiles.avatar_url (same NULL rules)
--   muted               whether the CALLER muted the conversation (their own member row only; false for a game
--                       chat they never muted)
-- Game rows are exactly v1: active member of a game that is not cancelled and not ended = 'send'; cancelled or ended
-- = 'read_only'; status left = 'left'; kicked, removed and other non-active memberships excluded; no membership = no row.
--
-- DM rows: both members have a member row; the caller's DMs are listed with game_id, game_title, sport, start_at and
-- end_at all NULL. State: 'send', or 'read_only' when either user has blocked the other or the counterpart is deleted
-- or banned (the same test msg_evaluate uses). The empty-DM rule: the user who started a DM sees it from the start; the
-- other member sees it only once a message exists. A message exists when msg_notify has stamped last_activity_at
-- (stamped by msg_notify on the first message): at creation last_activity_at equals created_at, and any later stamp is
-- strictly greater.
-- Name and avatar: the PUBLIC profile only. They come from the view v_profile_public (display_name and avatar_url,
-- the fields every signed-in user can already see in the app), matched to the user through public.profiles; when a user
-- has several profiles the personal one is preferred, then the oldest. A benched or inactive user has no public profile,
-- so the fields are NULL and the app falls back. No other profile field is read.
--
-- NOT RETURNED: message text, previews, sender names, unread counts, member lists.
-- ORDER AND LIMIT (unchanged): last_activity_at descending, ties by the game's start_at descending (a DM has none and
-- sorts after a game on a tie); at most least(greatest(coalesce(p_limit, 50), 1), 100) rows.
--
-- GRANTS: REVOKE ALL FROM PUBLIC and anon; EXECUTE to authenticated only. SECURITY DEFINER, search_path pinned, identity
-- auth.uid() only, owner not changed.

BEGIN;

ALTER FUNCTION public.msg_my_conversations(int) RENAME TO msg_my_conversations_v1;
REVOKE ALL ON FUNCTION public.msg_my_conversations_v1(int) FROM PUBLIC, anon, authenticated;

CREATE FUNCTION public.msg_my_conversations(p_limit int DEFAULT 50)
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
    ) t
   ORDER BY t.last_activity_at DESC, t.start_at DESC NULLS LAST
   LIMIT least(greatest(coalesce(p_limit, 50), 1), 100);
$$;

REVOKE ALL ON FUNCTION public.msg_my_conversations(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.msg_my_conversations(int) TO authenticated;

COMMIT;
