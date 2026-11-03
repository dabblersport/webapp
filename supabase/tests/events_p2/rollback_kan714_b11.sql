-- KAN-730 (KAN-714 piece B11) — ROLLBACK of 20261104101100_kan714_b11_msg_functions.sql.
-- LOCAL THROWAWAY POSTGRES ONLY. One transaction. No DROP, no CASCADE, no data mutation, no grant change.
-- Restores the pre-images of public.msg_evaluate, public.msg_authorize and public.msg_my_conversations verbatim
-- (pg_get_functiondef of the KAN-713 stage catalogue) with CREATE OR REPLACE, which keeps the oid, owner and ACL.
-- None is a KAN-712-wrapped function, so no unwrap/wrap path applies. msg_game_conversation was never changed.
-- Refuses unless ALL THREE live definitions are exactly the migration's post-images, so a second run, a partial
-- state, or a run against a DB that never had the migration raises instead of rewriting anything.
-- Verify afterwards with: psql -v expect=pre -f supabase/tests/events_p2/kan714_b11_msg_functions.sql
\set ON_ERROR_STOP 1
BEGIN;

DO $guard$
DECLARE r record; v text;
BEGIN
  FOR r IN SELECT * FROM (VALUES
      ('public.msg_evaluate(uuid,uuid,text)',  '857b15613ad7df0ee8eca600ac727283'),
      ('public.msg_authorize(uuid,text)',      '3db59a3432b9ed101c301ec602646546'),
      ('public.msg_my_conversations(integer)', '3131405c484dade6da955aa897f94fd8')) AS t(fn, md)
  LOOP
    v := md5(pg_get_functiondef(to_regprocedure(r.fn)));
    IF v IS DISTINCT FROM r.md THEN
      RAISE EXCEPTION 'KAN-730 rollback refused: % md5 % is not the B11 post-image % (not applied, already rolled back, or drifted)', r.fn, v, r.md;
    END IF;
  END LOOP;
END $guard$;

CREATE TEMP TABLE kan730_rb_attr ON COMMIT DROP AS
  SELECT p.oid, p.proowner, p.proacl::text AS acl, p.prosecdef, p.provolatile, p.proconfig, pg_get_function_result(p.oid) AS res
    FROM pg_proc p
   WHERE p.oid IN ('public.msg_evaluate(uuid,uuid,text)'::regprocedure, 'public.msg_authorize(uuid,text)'::regprocedure,
                   'public.msg_my_conversations(integer)'::regprocedure);

CREATE OR REPLACE FUNCTION public.msg_evaluate(p_conversation_id uuid, p_user_id uuid, p_access_mode text DEFAULT 'allowlist'::text)
 RETURNS TABLE(allowed_action text, reason text, left_at_seq bigint, game_id uuid)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
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
$function$;


CREATE OR REPLACE FUNCTION public.msg_authorize(p_conversation_id uuid, p_access_mode text DEFAULT 'allowlist'::text)
 RETURNS TABLE(user_id uuid, allowed_action text, reason text, left_at_seq bigint, member_user_ids uuid[], hidden_sender_ids uuid[])
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
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
$function$;


CREATE OR REPLACE FUNCTION public.msg_my_conversations(p_limit integer DEFAULT 50)
 RETURNS TABLE(conversation_id uuid, game_id uuid, game_title text, sport text, start_at timestamp with time zone, end_at timestamp with time zone, state text, last_activity_at timestamp with time zone, kind text, counterpart_user_id uuid, counterpart_name text, counterpart_avatar text, muted boolean)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
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
$function$;


DO $post$
DECLARE r record; v text; n int;
BEGIN
  FOR r IN SELECT * FROM (VALUES
      ('public.msg_evaluate(uuid,uuid,text)',  'fe42460520fa0c59244a48bc24faeaba'),
      ('public.msg_authorize(uuid,text)',      '27c1226d540754c28dcd90693bde9d20'),
      ('public.msg_my_conversations(integer)', 'f11737cac074781f1f0b147db8f4afce')) AS t(fn, md)
  LOOP
    v := md5(pg_get_functiondef(to_regprocedure(r.fn)));
    IF v IS DISTINCT FROM r.md THEN
      RAISE EXCEPTION 'KAN-730 rollback post: % md5 % is not the pre-image %', r.fn, v, r.md;
    END IF;
  END LOOP;
  SELECT count(*) INTO n FROM pg_proc p JOIN kan730_rb_attr a USING (oid)
   WHERE p.proowner = a.proowner AND p.proacl::text IS NOT DISTINCT FROM a.acl AND p.prosecdef = a.prosecdef
     AND p.provolatile = a.provolatile AND p.proconfig IS NOT DISTINCT FROM a.proconfig AND pg_get_function_result(p.oid) = a.res;
  IF n <> 3 THEN RAISE EXCEPTION 'KAN-730 rollback post: oid/owner/ACL/SECURITY DEFINER/volatility/search_path/result changed'; END IF;
  SELECT count(*) INTO n FROM pg_proc WHERE pronamespace = 'public'::regnamespace
     AND proname IN ('msg_evaluate', 'msg_authorize', 'msg_my_conversations', 'msg_game_conversation');
  IF n <> 4 THEN RAISE EXCEPTION 'KAN-730 rollback post: % functions (overload appeared or one is missing)', n; END IF;
END $post$;

COMMIT;
