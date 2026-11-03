-- KAN-730 (KAN-714 piece B11, Epic KAN-708) — messaging SQL functions read their SHARED game/meetup facts from
-- public.events.
--
-- AUTHORED, NOT APPLIED. Local proof only: supabase/tests/events_p2/kan714_b11_msg_functions.sql.
-- Rollback: supabase/tests/events_p2/rollback_kan714_b11.sql (restores the pre-images below, verbatim).
--
-- PRE-IMAGE: authored from pg_get_functiondef on the KAN-713 stage catalogue (T-058), not from a migration file.
-- Latest definitions: msg_evaluate and msg_authorize 20261017130000_kan558_msg_meetup_chat.sql, msg_my_conversations
-- 20261017140000_kan559_msg_my_conversations_meetup_id.sql, msg_game_conversation
-- 20261017120000_kan563_msg_game_conversation.sql. No later migration redefines any of the four.
--
-- SCOPE, per function (every public.msg_* function that reads public.games or public.meetups):
--   msg_evaluate(uuid,uuid,text)   REPOINTED. Game path: is_cancelled, end_at from events. Meetup path: is_cancelled,
--                                  COALESCE(end_at, start_at), creator_user_id (organiser) from events. Membership
--                                  (game_roster, meetup_rsvps), DM path, gates, reasons and their order verbatim.
--   msg_authorize(uuid,text)       REPOINTED. Meetup member_user_ids: the organiser (creator_user_id) from events.
--                                  Game members still come from game_roster; DM from msg_conversation_members.
--   msg_my_conversations(integer)  REPOINTED. Game rows: title, sport (via sport_id), start_at, end_at, is_cancelled
--                                  from events. Meetup rows: title, sport, start_at, end_at, is_cancelled,
--                                  creator_user_id from events. game_id stays g.id / mt.id (subtype id, KAN-559).
--                                  Filters, union branches, ORDER BY and LIMIT clamp verbatim.
--   msg_game_conversation(uuid,text)
--                                  UNCHANGED, by design. It reads only games.id (an existence check of the subtype
--                                  row, no shared column); every shared fact it returns comes through msg_evaluate,
--                                  which is repointed here. Pinned and asserted byte-identical. This is the one RPC
--                                  workers/messaging/src/games.ts calls; its call shape and result are proven equal.
--   msg_system_game_trg()          NOT TOUCHED. A trigger on games (AFTER UPDATE OF is_cancelled) reading NEW only;
--                                  not an RPC. Out of this piece (reported).
--   Every other msg_* (notify, typing, receipts, reports, dm, set_muted, can_read/can_send, user_unavailable ...)
--   reads neither games nor meetups (repo scan); nothing to repoint.
--
-- JOIN: <subtype> JOIN events e ON e.id = <subtype>.event_id AND e.event_type = '<type>'. events.id is the PK, so
-- 1:0..1. The stage guard proves exactly one parent of the right type for every games and meetups row, and that the
-- six shared columns read here agree today, so INNER JOIN loses and doubles nothing and results are equal.
-- ACCESS (E4): all three stay SECURITY DEFINER, owner postgres (superuser: reads events past FORCE RLS), search_path
-- public, pg_temp. CREATE OR REPLACE keeps owner and ACL; captured before and asserted equal after. public.events
-- stays FORCE RLS, zero policies, no API grants. No grant is added or changed.
-- KAN-712: none of the four is a wrapped RPC (kan712_wrapped_rpcs, asserted below), so the unwrap/wrap path does not
-- apply and no DROP is needed.
--
-- No DROP, no CASCADE, no data mutation, no grant change. Single transaction.

BEGIN;

-- ---------------------------------------------------------------------------------------------------------
-- 0. Stage guard
-- ---------------------------------------------------------------------------------------------------------
DO $guard$
DECLARE
  v_missing text[] := '{}';
  v_has boolean;
  r record;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = current_user AND (rolsuper OR rolbypassrls)) THEN
    RAISE EXCEPTION 'KAN-730: applying role % must be superuser or BYPASSRLS', current_user;
  END IF;
  IF to_regclass('public.events') IS NULL THEN
    RAISE EXCEPTION 'KAN-730: public.events missing (KAN-710 not applied)';
  END IF;

  -- KAN-712 stage B (cutover) and KAN-713 markers.
  FOR r IN SELECT * FROM (VALUES
      ('public.events',  'trg_zz_kan712_events_compat_mirror'),
      ('public.games',   'trg_zz_kan712_games_guard'),
      ('public.games',   'trg_zz_kan712_games_after_delete'),
      ('public.meetups', 'trg_zz_kan712_meetups_guard'),
      ('public.meetups', 'trg_zz_kan712_meetups_after_delete'),
      ('public.events',  'trg_kan713_events_location'),
      ('public.games',   'trg_kan713_games_a_location'),
      ('public.games',   'trg_kan713_games_b_joining'),
      ('public.games',   'trg_kan713_games_c_venue_geo'),
      ('public.meetups', 'trg_kan713_meetups_a_location'),
      ('public.meetups', 'trg_kan713_meetups_b_joining')) AS t(rel, tg)
  LOOP
    IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgrelid = r.rel::regclass AND tgname = r.tg AND tgenabled = 'O') THEN
      v_missing := v_missing || (r.rel || '.' || r.tg);
    END IF;
  END LOOP;
  IF to_regclass('public.kan712_wrapped_rpcs') IS NULL THEN
    v_missing := v_missing || 'public.kan712_wrapped_rpcs'::text;
  ELSE
    EXECUTE 'SELECT EXISTS (SELECT 1 FROM public.kan712_wrapped_rpcs)' INTO v_has;
    IF NOT v_has THEN
      v_missing := v_missing || 'public.kan712_wrapped_rpcs (empty: stage B not run)'::text;
    END IF;
  END IF;
  IF to_regprocedure('public.kan713_meetup_visible(uuid)') IS NULL THEN
    v_missing := v_missing || 'public.kan713_meetup_visible(uuid)'::text;
  END IF;
  IF array_length(v_missing, 1) > 0 THEN
    RAISE EXCEPTION 'KAN-730: prerequisite stage missing: %', array_to_string(v_missing, ', ');
  END IF;

  -- None of the four is KAN-712-wrapped: a bare CREATE OR REPLACE is the legal path only while that holds.
  EXECUTE $q$SELECT EXISTS (SELECT 1 FROM public.kan712_wrapped_rpcs WHERE name LIKE 'msg\_%')$q$ INTO v_has;
  IF v_has OR EXISTS (SELECT 1 FROM pg_proc WHERE pronamespace = 'public'::regnamespace
                       AND proname LIKE 'msg\_%\_kan712\_inner') THEN
    RAISE EXCEPTION 'KAN-730: a msg_* function is KAN-712-wrapped — use the unwrap/wrap path (KAN712_CONTRACT.md), stop';
  END IF;

  -- events still closed to the API.
  IF EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'public.events'::regclass)
     OR NOT (SELECT relforcerowsecurity AND relrowsecurity FROM pg_class WHERE oid = 'public.events'::regclass)
     OR has_table_privilege('anon', 'public.events', 'SELECT')
     OR has_table_privilege('authenticated', 'public.events', 'SELECT') THEN
    RAISE EXCEPTION 'KAN-730: public.events is no longer closed (policy or API grant present) — re-assess';
  END IF;

  -- Every games / meetups row has exactly one parent of its own event_type (INNER JOIN loses and doubles nothing).
  IF EXISTS (SELECT 1 FROM public.games g LEFT JOIN public.events e ON e.id = g.event_id AND e.event_type = 'game'
              WHERE e.id IS NULL) THEN
    RAISE EXCEPTION 'KAN-730: a games row has no events parent of event_type game';
  END IF;
  IF EXISTS (SELECT 1 FROM public.meetups m LEFT JOIN public.events e ON e.id = m.event_id AND e.event_type = 'meetup'
              WHERE e.id IS NULL) THEN
    RAISE EXCEPTION 'KAN-730: a meetups row has no events parent of event_type meetup';
  END IF;
  -- ... and the six shared columns read here agree (the compat mirror holds; a disagreement would change results).
  IF EXISTS (SELECT 1 FROM public.games g JOIN public.events e ON e.id = g.event_id AND e.event_type = 'game'
              WHERE (e.title, e.sport_id, e.start_at, e.end_at, e.is_cancelled, e.creator_user_id)
                    IS DISTINCT FROM (g.title, g.sport_id, g.start_at, g.end_at, g.is_cancelled, g.creator_user_id))
     OR EXISTS (SELECT 1 FROM public.meetups m JOIN public.events e ON e.id = m.event_id AND e.event_type = 'meetup'
              WHERE (e.title, e.sport_id, e.start_at, e.end_at, e.is_cancelled, e.creator_user_id)
                    IS DISTINCT FROM (m.title, m.sport_id, m.start_at, m.end_at, m.is_cancelled, m.creator_user_id)) THEN
    RAISE EXCEPTION 'KAN-730: events disagrees with games/meetups on a shared column read here — reconcile first';
  END IF;

  -- The function owners must read events past FORCE RLS, and the functions stay SECURITY DEFINER.
  FOR r IN SELECT p.oid::regprocedure::text AS fn, p.proowner AS own, p.prosecdef FROM pg_proc p
            WHERE p.oid IN ('public.msg_evaluate(uuid,uuid,text)'::regprocedure,
                            'public.msg_authorize(uuid,text)'::regprocedure,
                            'public.msg_my_conversations(integer)'::regprocedure) LOOP
    IF NOT r.prosecdef THEN
      RAISE EXCEPTION 'KAN-730: % is no longer SECURITY DEFINER; reading events would break API callers — stop', r.fn;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE oid = r.own AND (rolsuper OR rolbypassrls)) THEN
      RAISE EXCEPTION 'KAN-730: owner of % cannot bypass RLS on public.events', r.fn;
    END IF;
  END LOOP;
END
$guard$;

-- ---------------------------------------------------------------------------------------------------------
-- 1. Drift pins: md5 of pg_get_functiondef of the three changed functions (already-applied state fails here too)
--    and of msg_game_conversation, which is left untouched.
-- ---------------------------------------------------------------------------------------------------------
DO $pins$
DECLARE r record; v text;
BEGIN
  FOR r IN SELECT * FROM (VALUES
      ('public.msg_evaluate(uuid,uuid,text)',      'fe42460520fa0c59244a48bc24faeaba'),
      ('public.msg_authorize(uuid,text)',          '27c1226d540754c28dcd90693bde9d20'),
      ('public.msg_my_conversations(integer)',     'f11737cac074781f1f0b147db8f4afce'),
      ('public.msg_game_conversation(uuid,text)',  '621607f5b89e8dcae235f62fa13df8cc')) AS t(fn, md)
  LOOP
    IF to_regprocedure(r.fn) IS NULL THEN
      RAISE EXCEPTION 'KAN-730 pin: % missing', r.fn;
    END IF;
    v := md5(pg_get_functiondef(to_regprocedure(r.fn)));
    IF v IS DISTINCT FROM r.md THEN
      RAISE EXCEPTION 'KAN-730 pin: % definition drifted (md5 % expected %) — already applied, or the pre-image moved',
        r.fn, v, r.md;
    END IF;
  END LOOP;
  IF (SELECT count(*) FROM pg_proc WHERE pronamespace = 'public'::regnamespace
        AND proname IN ('msg_evaluate', 'msg_authorize', 'msg_my_conversations', 'msg_game_conversation')) <> 4 THEN
    RAISE EXCEPTION 'KAN-730 pin: an overload of a msg_* function in scope exists — re-assess';
  END IF;
END
$pins$;

-- Attribute capture for the post-conditions (ON COMMIT DROP: nothing persists).
CREATE TEMP TABLE kan730_pre ON COMMIT DROP AS
  SELECT p.oid, p.proowner, p.proacl::text AS acl, p.prosecdef, p.provolatile, p.proconfig,
         pg_get_function_identity_arguments(p.oid) AS args, pg_get_function_result(p.oid) AS res
    FROM pg_proc p
   WHERE p.oid IN ('public.msg_evaluate(uuid,uuid,text)'::regprocedure,
                   'public.msg_authorize(uuid,text)'::regprocedure,
                   'public.msg_my_conversations(integer)'::regprocedure,
                   'public.msg_game_conversation(uuid,text)'::regprocedure);
CREATE TEMP TABLE kan730_pre_events ON COMMIT DROP AS
  SELECT relacl::text AS acl, relrowsecurity, relforcerowsecurity FROM pg_class WHERE oid = 'public.events'::regclass;

-- ---------------------------------------------------------------------------------------------------------
-- 2. Functions
-- ---------------------------------------------------------------------------------------------------------
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
    -- KAN-730: the shared facts (cancelled, start/end, organiser) come from the events parent.
    SELECT c.meetup_id, e.is_cancelled, COALESCE(e.end_at, e.start_at), e.creator_user_id
      INTO v_meetup_id, v_m_cancel, v_m_end_at, v_m_owner
      FROM public.msg_conversations c
      JOIN public.meetups mt ON mt.id = c.meetup_id
      JOIN public.events e ON e.id = mt.event_id AND e.event_type = 'meetup'
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

  -- KAN-730: the shared facts (cancelled, end) come from the events parent.
  SELECT c.game_id, e.is_cancelled, e.end_at
    INTO v_game_id, v_cancelled, v_end_at
    FROM public.msg_conversations c
    JOIN public.games g ON g.id = c.game_id
    JOIN public.events e ON e.id = g.event_id AND e.event_type = 'game'
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
                       FROM (SELECT e.creator_user_id AS uid  -- KAN-730: organiser from the events parent
                               FROM public.msg_conversations mc
                               JOIN public.meetups mt ON mt.id = mc.meetup_id
                               JOIN public.events e ON e.id = mt.event_id AND e.event_type = 'meetup'
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
             e.title AS game_title,
             s.name_en AS sport,
             e.start_at AS start_at,
             e.end_at AS end_at,
             CASE
               WHEN m.status = 'left' THEN 'left'
               WHEN e.is_cancelled OR e.end_at < now() THEN 'read_only'
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
        -- KAN-730: title, sport, start, end, cancelled come from the events parent.
        JOIN public.events e ON e.id = g.event_id AND e.event_type = 'game'
        LEFT JOIN public.sports s ON s.id = e.sport_id
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
             e.title,
             ms.name_en,
             e.start_at,
             e.end_at,
             CASE
               WHEN e.creator_user_id <> auth.uid() AND mr.status = 'cancelled' THEN 'left'
               WHEN e.is_cancelled OR COALESCE(e.end_at, e.start_at) < now() THEN 'read_only'
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
        -- KAN-730: title, sport, start, end, cancelled, organiser come from the events parent.
        JOIN public.events e ON e.id = mt.event_id AND e.event_type = 'meetup'
        LEFT JOIN public.sports ms ON ms.id = e.sport_id
        LEFT JOIN public.meetup_rsvps mr ON mr.meetup_id = mt.id AND mr.user_id = auth.uid()
       WHERE c.kind = 'meetup'
         AND auth.uid() IS NOT NULL
         AND (e.creator_user_id = auth.uid() OR mr.status IN ('going', 'cancelled'))
    ) t
   ORDER BY t.last_activity_at DESC, t.start_at DESC NULLS LAST
   LIMIT least(greatest(coalesce(p_limit, 50), 1), 100);
$function$;


-- ---------------------------------------------------------------------------------------------------------
-- 3. Post-conditions
-- ---------------------------------------------------------------------------------------------------------
DO $post$
DECLARE r record; v text;
BEGIN
  -- Exact new definitions; msg_game_conversation byte-identical.
  FOR r IN SELECT * FROM (VALUES
      ('public.msg_evaluate(uuid,uuid,text)',      '857b15613ad7df0ee8eca600ac727283'),
      ('public.msg_authorize(uuid,text)',          '3db59a3432b9ed101c301ec602646546'),
      ('public.msg_my_conversations(integer)',     '3131405c484dade6da955aa897f94fd8'),
      ('public.msg_game_conversation(uuid,text)',  '621607f5b89e8dcae235f62fa13df8cc')) AS t(fn, md)
  LOOP
    v := md5(pg_get_functiondef(to_regprocedure(r.fn)));
    IF v IS DISTINCT FROM r.md THEN
      RAISE EXCEPTION 'KAN-730 post: % definition md5 % (expected %)', r.fn, v, r.md;
    END IF;
  END LOOP;

  -- Signature, result, owner, ACL, SECURITY DEFINER, volatility, search_path identical to the pre-image.
  IF EXISTS (SELECT 1 FROM pg_temp.kan730_pre p LEFT JOIN pg_proc c ON c.oid = p.oid
              WHERE c.oid IS NULL OR c.proowner <> p.proowner OR c.proacl::text IS DISTINCT FROM p.acl
                 OR c.prosecdef <> p.prosecdef OR c.provolatile <> p.provolatile
                 OR c.proconfig IS DISTINCT FROM p.proconfig
                 OR pg_get_function_identity_arguments(c.oid) <> p.args
                 OR pg_get_function_result(c.oid) <> p.res)
     OR (SELECT count(*) FROM pg_temp.kan730_pre) <> 4 THEN
    RAISE EXCEPTION 'KAN-730 post: signature / owner / ACL / SECURITY DEFINER / volatility / search_path changed';
  END IF;
  -- No overload appeared; still not wrapped.
  IF (SELECT count(*) FROM pg_proc WHERE pronamespace = 'public'::regnamespace
        AND proname IN ('msg_evaluate', 'msg_authorize', 'msg_my_conversations', 'msg_game_conversation')) <> 4
     OR EXISTS (SELECT 1 FROM pg_proc WHERE pronamespace = 'public'::regnamespace AND proname LIKE 'msg\_%\_kan712\_inner') THEN
    RAISE EXCEPTION 'KAN-730 post: overload count changed or an inner appeared';
  END IF;

  -- events still closed to the API, attributes identical.
  IF EXISTS (SELECT 1 FROM pg_policy WHERE polrelid = 'public.events'::regclass)
     OR has_table_privilege('anon', 'public.events', 'SELECT')
     OR has_table_privilege('authenticated', 'public.events', 'SELECT')
     OR EXISTS (SELECT 1 FROM pg_temp.kan730_pre_events p, pg_class c
                 WHERE c.oid = 'public.events'::regclass
                   AND (c.relacl::text IS DISTINCT FROM p.acl OR NOT c.relrowsecurity OR NOT c.relforcerowsecurity)) THEN
    RAISE EXCEPTION 'KAN-730 post: public.events opened to the API or its posture changed';
  END IF;
END
$post$;

COMMIT;
