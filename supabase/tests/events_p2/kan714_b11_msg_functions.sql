-- KAN-730 (KAN-714 piece B11) — messaging readers. msg_evaluate, msg_authorize and msg_my_conversations read their
-- shared facts (title, sport, start/end, cancelled, organiser) from public.events; msg_game_conversation reads only
-- games.id and is pinned UNCHANGED, as are msg_user_unavailable and the msg_system_game_trg trigger.
-- LOCAL THROWAWAY POSTGRES ONLY. One transaction, ROLLBACK at the end: no data survives.
--
-- Output: PASS|id|detail or FAIL|id|detail, then #SUMMARY|expect=|pass=|fail=, plus #PLAN| / #FINGERPRINT| / #COUNT| lines.
--
-- Variable :expect selects which image is asserted:
--   post (default) — 20261104101100_kan714_b11_msg_functions.sql applied.
--   pre            — legacy pre-image (no migration, or after rollback_kan714_b11.sql).
-- RED/GREEN protocol:
--   chain without migration,  expect=post  -> FAIL lines (D, P, X)                     RED
--   chain without migration,  expect=pre   -> 0 FAIL
--   chain with migration,     expect=post  -> 0 FAIL                                   GREEN
--   migration + rollback,     expect=pre   -> 0 FAIL, and #FINGERPRINT| equal to the pre-migration DB
--
-- Groups: S shape/attributes, D definitions, E msg_evaluate parity (every conversation x 8 callers x 4 modes),
--         U msg_authorize parity, M msg_my_conversations parity (limits + whole dataset), W the Worker's
--         msg_game_conversation call shapes (existing, create path, gates), B blocked/anon literals,
--         P provenance (events-only edits), A access (events closed), X EXPLAIN shape.
--
-- HARNESS CORRECTION (inside this rolled-back transaction only): the local harness stub declares
-- msg_conversations_kind_check as CHECK (kind = 'game') (local_harness_kan714_2_stubs.sql). Production (KAN-558)
-- allows game/dm/meetup. The seed replaces the stub constraint, and ONLY when it is exactly the stub text, so that
-- meetup conversations can exist. Nothing of it survives the ROLLBACK.
\set ON_ERROR_STOP 1
\set ev_post 857b15613ad7df0ee8eca600ac727283
\set ev_pre fe42460520fa0c59244a48bc24faeaba
\set au_post 3db59a3432b9ed101c301ec602646546
\set au_pre 27c1226d540754c28dcd90693bde9d20
\set my_post 3131405c484dade6da955aa897f94fd8
\set my_pre f11737cac074781f1f0b147db8f4afce
\set gc_md5 621607f5b89e8dcae235f62fa13df8cc
\set un_md5 cf60ce13899f636d6cb1e3756728b755
\set trg_md5 a64d5a2fcaff670ce0a057ed86e55914
\if :{?expect}
\else
  \set expect post
\endif
BEGIN;
SELECT set_config('kan730.expect', :'expect', true);
SET LOCAL TimeZone = 'UTC';
CREATE TEMP TABLE res (n serial, id text, ok boolean, detail text);

CREATE FUNCTION pg_temp.post() RETURNS boolean LANGUAGE sql AS $$ SELECT current_setting('kan730.expect') = 'post' $$;
CREATE FUNCTION pg_temp.chk(p_id text, p_got text, p_want text) RETURNS void LANGUAGE sql AS $$
  INSERT INTO res (id, ok, detail)
  VALUES (p_id, p_got IS NOT DISTINCT FROM p_want, 'got=' || coalesce(p_got, '<null>') || ' want=' || coalesce(p_want, '<null>'))
$$;
-- One call under a role and a JWT sub: the scalar result as text, or 'ERR <sqlstate> <message>'.
CREATE FUNCTION pg_temp.as_(p_role text, p_uid uuid, p_sql text) RETURNS text LANGUAGE plpgsql AS $$
DECLARE v text;
BEGIN
  BEGIN
    PERFORM set_config('request.jwt.claim.sub', coalesce(p_uid::text, ''), true);
    IF p_role IS NOT NULL THEN EXECUTE format('SET LOCAL ROLE %I', p_role); END IF;
    EXECUTE p_sql INTO v;
    RESET ROLE;
  EXCEPTION WHEN OTHERS THEN
    RESET ROLE;
    v := 'ERR ' || SQLSTATE || ' ' || SQLERRM;
  END;
  PERFORM set_config('request.jwt.claim.sub', '', true);
  RETURN coalesce(v, '<null>');
END $$;
-- The same, inside a subtransaction that is always rolled back: a call that writes (msg_game_conversation's create
-- path) leaves nothing behind, so a legacy call and a live call see the same database.
CREATE FUNCTION pg_temp.as_rb(p_role text, p_uid uuid, p_sql text) RETURNS text LANGUAGE plpgsql AS $$
DECLARE v text;
BEGIN
  BEGIN
    PERFORM set_config('request.jwt.claim.sub', coalesce(p_uid::text, ''), true);
    IF p_role IS NOT NULL THEN EXECUTE format('SET LOCAL ROLE %I', p_role); END IF;
    EXECUTE p_sql INTO v;
    RESET ROLE;
    RAISE EXCEPTION 'kan730-rollback';
  EXCEPTION WHEN OTHERS THEN
    RESET ROLE;
    IF SQLERRM <> 'kan730-rollback' THEN v := 'ERR ' || SQLSTATE || ' ' || SQLERRM; END IF;
  END;
  PERFORM set_config('request.jwt.claim.sub', '', true);
  RETURN coalesce(v, '<null>');
END $$;
CREATE FUNCTION pg_temp.plan(p_sql text) RETURNS text LANGUAGE plpgsql AS $$
DECLARE l text; o text := '';
BEGIN
  FOR l IN EXECUTE 'EXPLAIN (COSTS OFF) ' || p_sql LOOP o := o || l || E'\n'; END LOOP;
  RETURN o;
END $$;
CREATE FUNCTION pg_temp.cnt(p_hay text, p_re text) RETURNS int LANGUAGE sql AS $$
  SELECT count(*)::int FROM regexp_matches(p_hay, p_re, 'g')
$$;
-- Comments stripped, whitespace collapsed: for "this statement is in the installed body" checks.
CREATE FUNCTION pg_temp.norm(p text) RETURNS text LANGUAGE sql AS $$
  SELECT btrim(regexp_replace(regexp_replace(p, '--[^\n]*', '', 'g'), '\s+', ' ', 'g'))
$$;
-- A sql function body with its trailing LIMIT clause removed: the whole result set, not the first 100 rows.
CREATE FUNCTION pg_temp.nolimit(p_fn regprocedure) RETURNS text LANGUAGE plpgsql AS $$
DECLARE s text; o text;
BEGIN
  SELECT prosrc INTO s FROM pg_proc WHERE oid = p_fn;
  o := regexp_replace(s, 'LIMIT least\(greatest\(coalesce\(p_limit, 50\), 1\), 100\);\s*$', '');
  IF o = s THEN RAISE EXCEPTION 'nolimit: % has no trailing LIMIT clause', p_fn; END IF;
  RETURN o;
END $$;

-- Data fingerprint of every table the messaging readers read or write, BEFORE this script seeds anything.
SELECT '#FINGERPRINT|' || md5(
         (SELECT coalesce(string_agg(x::text, '|' ORDER BY x.id), '') FROM public.msg_conversations x) ||
         (SELECT coalesce(string_agg(x::text, '|' ORDER BY x.conversation_id, x.user_id), '') FROM public.msg_conversation_members x) ||
         (SELECT coalesce(string_agg(x::text, '|' ORDER BY x.user_id), '') FROM public.msg_access_allowlist x) ||
         (SELECT coalesce(string_agg(x::text, '|' ORDER BY x.id), '') FROM public.meetup_rsvps x) ||
         (SELECT coalesce(string_agg(x::text, '|' ORDER BY x.id), '') FROM public.game_roster x) ||
         (SELECT coalesce(string_agg(x::text, '|' ORDER BY x.id), '') FROM public.meetups x) ||
         (SELECT coalesce(string_agg(x::text, '|' ORDER BY x.id), '') FROM public.games x) ||
         (SELECT coalesce(string_agg(x::text, '|' ORDER BY x.id), '') FROM public.events x)) AS fingerprint;

-- ---------------------------------------------------------------- S: shape and attributes (identical pre and post)
SELECT pg_temp.chk('S-' || t.fn || '-' || t.k, t.got, t.want)
  FROM (
    SELECT s.fn, k.k,
           CASE k.k
             WHEN 'args'   THEN pg_get_function_identity_arguments(p.oid)
             WHEN 'result' THEN pg_get_function_result(p.oid)
             WHEN 'secdef' THEN p.prosecdef::text
             WHEN 'vol'    THEN p.provolatile::text
             WHEN 'config' THEN p.proconfig::text
             WHEN 'owner'  THEN pg_get_userbyid(p.proowner)
             WHEN 'acl'    THEN p.proacl::text
             WHEN 'lang'   THEN (SELECT lanname FROM pg_language l WHERE l.oid = p.prolang)::text
             WHEN 'n'      THEN (SELECT count(*) FROM pg_proc q WHERE q.pronamespace = 'public'::regnamespace AND q.proname = s.fn)::text
           END AS got,
           CASE k.k
             WHEN 'args'   THEN s.args
             WHEN 'result' THEN s.res
             WHEN 'secdef' THEN 'true'
             WHEN 'vol'    THEN s.vol
             WHEN 'config' THEN '{"search_path=public, pg_temp"}'
             WHEN 'owner'  THEN 'postgres'
             WHEN 'acl'    THEN '{=X/postgres,postgres=X/postgres,anon=X/postgres,authenticated=X/postgres,service_role=X/postgres}'
             WHEN 'lang'   THEN s.lang
             WHEN 'n'      THEN '1'
           END AS want
      FROM (VALUES
        ('msg_evaluate', 'p_conversation_id uuid, p_user_id uuid, p_access_mode text',
         'TABLE(allowed_action text, reason text, left_at_seq bigint, game_id uuid)', 's', 'plpgsql'),
        ('msg_authorize', 'p_conversation_id uuid, p_access_mode text',
         'TABLE(user_id uuid, allowed_action text, reason text, left_at_seq bigint, member_user_ids uuid[], hidden_sender_ids uuid[])', 's', 'plpgsql'),
        ('msg_my_conversations', 'p_limit integer',
         'TABLE(conversation_id uuid, game_id uuid, game_title text, sport text, start_at timestamp with time zone, end_at timestamp with time zone, state text, last_activity_at timestamp with time zone, kind text, counterpart_user_id uuid, counterpart_name text, counterpart_avatar text, muted boolean)', 's', 'sql'),
        ('msg_game_conversation', 'p_game_id uuid, p_access_mode text',
         'TABLE(user_id uuid, conversation_id uuid, game_id uuid, allowed_action text, reason text, left_at_seq bigint, muted boolean)', 'v', 'plpgsql')
      ) AS s(fn, args, res, vol, lang)
      LEFT JOIN pg_proc p ON p.pronamespace = 'public'::regnamespace AND p.proname = s.fn
      CROSS JOIN (VALUES ('args'), ('result'), ('secdef'), ('vol'), ('config'), ('owner'), ('acl'), ('lang'), ('n')) AS k(k)
  ) t;
SELECT pg_temp.chk('S-no-kan712-inner',
       (SELECT count(*) FROM pg_proc WHERE pronamespace = 'public'::regnamespace AND proname LIKE 'msg\_%\_kan712\_inner')::text, '0');
SELECT pg_temp.chk('S-not-wrapped',
       (SELECT count(*) FROM public.kan712_wrapped_rpcs w WHERE w::text LIKE '%msg\_%')::text, '0');

-- ---------------------------------------------------------------- D: definitions
SELECT pg_temp.chk('D-msg_evaluate-md5', md5(pg_get_functiondef('public.msg_evaluate(uuid,uuid,text)'::regprocedure)),
                   CASE WHEN pg_temp.post() THEN :'ev_post' ELSE :'ev_pre' END);
SELECT pg_temp.chk('D-msg_authorize-md5', md5(pg_get_functiondef('public.msg_authorize(uuid,text)'::regprocedure)),
                   CASE WHEN pg_temp.post() THEN :'au_post' ELSE :'au_pre' END);
SELECT pg_temp.chk('D-msg_my_conversations-md5', md5(pg_get_functiondef('public.msg_my_conversations(integer)'::regprocedure)),
                   CASE WHEN pg_temp.post() THEN :'my_post' ELSE :'my_pre' END);
SELECT pg_temp.chk('D-msg_game_conversation-md5-unchanged', md5(pg_get_functiondef('public.msg_game_conversation(uuid,text)'::regprocedure)), :'gc_md5');
SELECT pg_temp.chk('D-msg_user_unavailable-md5-unchanged', md5(pg_get_functiondef('public.msg_user_unavailable(uuid)'::regprocedure)), :'un_md5');
SELECT pg_temp.chk('D-msg_system_game_trg-md5-unchanged', md5(pg_get_functiondef('public.msg_system_game_trg()'::regprocedure)), :'trg_md5');
SELECT pg_temp.chk('D-' || f || '-reads-events', (prosrc ~ 'public\.events\M')::text, pg_temp.post()::text)
  FROM (VALUES ('msg_evaluate'), ('msg_authorize'), ('msg_my_conversations')) v(f)
  JOIN pg_proc p ON p.pronamespace = 'public'::regnamespace AND p.proname = v.f;
SELECT pg_temp.chk('D-msg_game_conversation-reads-no-events',
       ((SELECT prosrc FROM pg_proc WHERE oid = 'public.msg_game_conversation(uuid,text)'::regprocedure) ~ 'public\.events\M')::text, 'false');

-- ---------------------------------------------------------------- legacy reference bodies, as temp functions
-- The pre-images, verbatim (pg_get_functiondef of the KAN-713 stage catalogue); the two callers of msg_evaluate
-- call legacy_msg_evaluate, so a legacy chain never touches a live body.
-- legacy_msg_evaluate: the pre-image verbatim.
CREATE FUNCTION pg_temp.legacy_msg_evaluate(p_conversation_id uuid, p_user_id uuid, p_access_mode text DEFAULT 'allowlist'::text)
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

-- legacy_msg_authorize: the pre-image verbatim (its msg_evaluate call pointed at legacy_msg_evaluate).
CREATE FUNCTION pg_temp.legacy_msg_authorize(p_conversation_id uuid, p_access_mode text DEFAULT 'allowlist'::text)
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

  SELECT * INTO v_eval FROM pg_temp.legacy_msg_evaluate(p_conversation_id, v_uid, p_access_mode);

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

-- legacy_msg_game_conversation: the pre-image verbatim (its msg_evaluate call pointed at legacy_msg_evaluate).
CREATE FUNCTION pg_temp.legacy_msg_game_conversation(p_game_id uuid, p_access_mode text DEFAULT 'allowlist'::text)
 RETURNS TABLE(user_id uuid, conversation_id uuid, game_id uuid, allowed_action text, reason text, left_at_seq bigint, muted boolean)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
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
    SELECT * INTO v_eval FROM pg_temp.legacy_msg_evaluate('00000000-0000-0000-0000-000000000000'::uuid, v_uid, p_access_mode);
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

  SELECT * INTO v_eval FROM pg_temp.legacy_msg_evaluate(v_conv, v_uid, p_access_mode);

  IF v_eval.allowed_action IS NULL THEN
    RETURN QUERY SELECT v_uid, NULL::uuid, NULL::uuid, NULL::text, v_eval.reason, NULL::bigint, false;
    RETURN;
  END IF;

  RETURN QUERY
  SELECT v_uid, v_conv, p_game_id, v_eval.allowed_action, v_eval.reason, v_eval.left_at_seq,
         EXISTS (SELECT 1 FROM public.msg_conversation_members m
                  WHERE m.conversation_id = v_conv AND m.user_id = v_uid AND m.muted_at IS NOT NULL);
END;
$function$;

-- legacy_msg_my_conversations: the pre-image verbatim.
CREATE FUNCTION pg_temp.legacy_msg_my_conversations(p_limit integer DEFAULT 50)
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

-- ---------------------------------------------------------------- seed (rolled back with everything else)
DO $fix$
BEGIN
  IF (SELECT pg_get_constraintdef(oid) FROM pg_constraint
       WHERE conrelid = 'public.msg_conversations'::regclass AND conname = 'msg_conversations_kind_check')
     = 'CHECK ((kind = ''game''::text))' THEN
    ALTER TABLE public.msg_conversations DROP CONSTRAINT msg_conversations_kind_check;
    ALTER TABLE public.msg_conversations ADD CONSTRAINT msg_conversations_kind_check
      CHECK (kind = ANY (ARRAY['game'::text, 'dm'::text, 'meetup'::text]));
    RAISE NOTICE 'KAN-730 test: harness kind_check stub replaced inside this transaction';
  END IF;
END
$fix$;

CREATE TEMP TABLE usr (u uuid);
INSERT INTO usr VALUES ('00000000-0000-0000-0000-0000000000a1'), ('00000000-0000-0000-0000-0000000000a2'),
                       ('00000000-0000-0000-0000-0000000000a3'), ('00000000-0000-0000-0000-0000000000a4'),
                       ('00000000-0000-0000-0000-0000000000a5'), ('00000000-0000-0000-0000-0000000000a6'),
                       ('00000000-0000-0000-0000-0000000000a7'), (NULL);
-- Pilot allowlist: a3 (outsider) and a7 (leaver) are not in it.
INSERT INTO public.msg_access_allowlist (user_id)
SELECT u FROM usr WHERE u IN ('00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-0000000000a2',
                              '00000000-0000-0000-0000-0000000000a4', '00000000-0000-0000-0000-0000000000a5',
                              '00000000-0000-0000-0000-0000000000a6')
ON CONFLICT DO NOTHING;
-- Leavers for meetups: half the 'declined' RSVPs become 'cancelled'.
UPDATE public.meetup_rsvps SET status = 'cancelled' WHERE status = 'declined' AND abs(hashtext(meetup_id::text)) % 2 = 0;

-- Games kept WITHOUT a conversation, for msg_game_conversation's create path: 8 with a1 active, 4 more with a7 left.
CREATE TEMP TABLE gc_new AS
SELECT g.id FROM public.games g
 WHERE EXISTS (SELECT 1 FROM public.game_roster r WHERE r.game_id = g.id
                AND r.user_id = '00000000-0000-0000-0000-0000000000a1' AND r.status = 'active')
   AND NOT EXISTS (SELECT 1 FROM public.msg_conversations c WHERE c.game_id = g.id)
 ORDER BY md5(g.id::text) LIMIT 8;
INSERT INTO gc_new
SELECT g.id FROM public.games g
 WHERE EXISTS (SELECT 1 FROM public.game_roster r WHERE r.game_id = g.id
                AND r.user_id = '00000000-0000-0000-0000-0000000000a7' AND r.status = 'left')
   AND NOT EXISTS (SELECT 1 FROM public.msg_conversations c WHERE c.game_id = g.id)
   AND g.id NOT IN (SELECT id FROM gc_new)
 ORDER BY md5(g.id::text) LIMIT 4;

-- One conversation per remaining game and per meetup; distinct last_activity_at so ordering is total.
INSERT INTO public.msg_conversations (kind, game_id, meetup_id, last_activity_at)
SELECT k, gid, mid, timestamptz '2030-01-01 00:00+00' + (row_number() OVER (ORDER BY md5(coalesce(gid, mid)::text))) * interval '1 minute'
  FROM (SELECT 'game' AS k, g.id AS gid, NULL::uuid AS mid FROM public.games g WHERE g.id NOT IN (SELECT id FROM gc_new)
        UNION ALL
        SELECT 'meetup', NULL, m.id FROM public.meetups m) s
 WHERE NOT EXISTS (SELECT 1 FROM public.msg_conversations c WHERE c.game_id = s.gid OR c.meetup_id = s.mid);

-- Members: every roster user of a game chat; the organiser and every going/cancelled RSVP of a meetup chat.
-- Leavers get a left_at_seq (one in five left NULL: the fail-closed path); one member in four is muted.
INSERT INTO public.msg_conversation_members (conversation_id, user_id, left_at_seq, muted_at)
SELECT DISTINCT ON (c.id, r.user_id) c.id, r.user_id,
       CASE WHEN r.status = 'left' AND abs(hashtext(c.id::text || r.user_id::text)) % 5 <> 0
            THEN abs(hashtext(r.user_id::text || c.id::text)) % 40 END,
       CASE WHEN abs(hashtext(c.id::text || r.user_id::text || 'm')) % 4 = 0 THEN now() END
  FROM public.msg_conversations c JOIN public.game_roster r ON r.game_id = c.game_id
 WHERE c.kind = 'game' AND r.role IN ('host', 'player', 'sub')
 ORDER BY c.id, r.user_id
ON CONFLICT DO NOTHING;
INSERT INTO public.msg_conversation_members (conversation_id, user_id, left_at_seq, muted_at)
SELECT DISTINCT ON (x.cid, x.uid) x.cid, x.uid,
       CASE WHEN x.st = 'cancelled' AND abs(hashtext(x.cid::text || x.uid::text)) % 5 <> 0
            THEN abs(hashtext(x.uid::text || x.cid::text)) % 40 END,
       CASE WHEN abs(hashtext(x.cid::text || x.uid::text || 'm')) % 4 = 0 THEN now() END
  FROM (SELECT c.id AS cid, m.creator_user_id AS uid, 'going' AS st
          FROM public.msg_conversations c JOIN public.meetups m ON m.id = c.meetup_id WHERE c.kind = 'meetup'
        UNION ALL
        SELECT c.id, r.user_id, r.status
          FROM public.msg_conversations c JOIN public.meetup_rsvps r ON r.meetup_id = c.meetup_id
         WHERE c.kind = 'meetup' AND r.status IN ('going', 'cancelled')) x
 WHERE x.uid IS NOT NULL
 ORDER BY x.cid, x.uid, (x.st = 'going') DESC
ON CONFLICT DO NOTHING;

-- Provenance targets: a live, uncancelled game chat with a1 active; a live, uncancelled meetup chat with a sport.
-- Both are pushed to the top of their callers' lists so msg_my_conversations(100) shows them.
SELECT c.id AS pg_conv, g.id AS pg_game, g.event_id AS pg_ev
  FROM public.msg_conversations c JOIN public.games g ON g.id = c.game_id
 WHERE NOT g.is_cancelled AND g.end_at > now() + interval '1 day'
   AND EXISTS (SELECT 1 FROM public.game_roster r WHERE r.game_id = g.id
                AND r.user_id = '00000000-0000-0000-0000-0000000000a1' AND r.status = 'active')
 ORDER BY md5(c.id::text) LIMIT 1 \gset
SELECT c.id AS pm_conv, m.id AS pm_meetup, m.event_id AS pm_ev, m.creator_user_id AS pm_owner
  FROM public.msg_conversations c JOIN public.meetups m ON m.id = c.meetup_id
 WHERE NOT m.is_cancelled AND COALESCE(m.end_at, m.start_at) > now() + interval '1 day' AND m.sport_id IS NOT NULL
   AND m.creator_user_id <> '00000000-0000-0000-0000-0000000000a3'
 ORDER BY md5(c.id::text) LIMIT 1 \gset
UPDATE public.msg_conversations SET last_activity_at = timestamptz '2099-01-01 00:00+00' WHERE id = :'pg_conv';
UPDATE public.msg_conversations SET last_activity_at = timestamptz '2099-01-02 00:00+00' WHERE id = :'pm_conv';

CREATE TEMP TABLE cv AS SELECT id, kind, game_id, meetup_id FROM public.msg_conversations;
SELECT '#COUNT|conversations=' || count(*) || '|game=' || count(*) FILTER (WHERE kind = 'game')
       || '|meetup=' || count(*) FILTER (WHERE kind = 'meetup') || '|members=' || (SELECT count(*) FROM public.msg_conversation_members)
       || '|gc_new=' || (SELECT count(*) FROM gc_new) FROM cv;
SELECT pg_temp.chk('seed-games-covered', (SELECT count(*) FROM cv WHERE kind = 'game')::text,
                   ((SELECT count(*) FROM public.games) - (SELECT count(*) FROM gc_new))::text);
SELECT pg_temp.chk('seed-meetups-covered', (SELECT count(*) FROM cv WHERE kind = 'meetup')::text, (SELECT count(*) FROM public.meetups)::text);
SELECT pg_temp.chk('seed-gc_new', (SELECT count(*) FROM gc_new)::text, '12');

-- ---------------------------------------------------------------- E: msg_evaluate parity, whole dataset
-- every conversation (and one unknown id) x 8 callers (7 users + NULL) x modes all / allowlist; modes off, NULL and
-- a bogus value over a 300-conversation sample. Each side's result is the array of its rows: a doubled row shows.
CREATE TEMP TABLE ev AS
SELECT c.id AS cid, c.kind, u.u, m.m,
       (SELECT array_agg(row(x.*)::text) FROM public.msg_evaluate(c.id, u.u, m.m) x) AS live,
       (SELECT array_agg(row(y.*)::text) FROM pg_temp.legacy_msg_evaluate(c.id, u.u, m.m) y) AS leg
  FROM (SELECT id, kind FROM cv UNION ALL SELECT '00000000-0000-0000-0000-00000000dead'::uuid, 'unknown') c
 CROSS JOIN usr u CROSS JOIN (VALUES ('all'), ('allowlist')) m(m)
UNION ALL
SELECT c.id, c.kind, u.u, m.m,
       (SELECT array_agg(row(x.*)::text) FROM public.msg_evaluate(c.id, u.u, m.m) x),
       (SELECT array_agg(row(y.*)::text) FROM pg_temp.legacy_msg_evaluate(c.id, u.u, m.m) y)
  FROM (SELECT id, kind FROM cv ORDER BY md5(id::text) LIMIT 300) c
 CROSS JOIN usr u CROSS JOIN (VALUES ('off'), (NULL), ('bogus')) m(m);
SELECT '#COUNT|E|' || kind || '|' || coalesce(m, '<null>') || '|' || coalesce(live[1], '<none>') || '|' || count(*)
  FROM ev GROUP BY kind, m, live[1] ORDER BY 1;
SELECT pg_temp.chk('E-rows', (SELECT count(*) FROM ev)::text, ((((SELECT count(*) FROM cv) + 1) * 8 * 2) + 300 * 8 * 3)::text);
SELECT pg_temp.chk('E-parity', (SELECT count(*) FROM ev WHERE live IS DISTINCT FROM leg)::text, '0');
SELECT pg_temp.chk('E-one-row-each', (SELECT count(*) FROM ev WHERE coalesce(array_length(live, 1), 0) <> 1)::text, '0');
-- The parity is not vacuous: every lifecycle answer the shared facts drive is exercised, on both kinds.
SELECT pg_temp.chk('E-covers-' || k || '-' || r, (SELECT (count(*) > 0)::text FROM ev
         WHERE ev.kind = v.k AND ev.m = 'all' AND (ev.live[1])::text LIKE v.r), 'true')
  FROM (VALUES ('game', '(send,,,%'), ('game', '(read,game_cancelled,,%'), ('game', '(read,left,%'),
               ('game', '(,not_member,,)'), ('meetup', '(send,,,)'), ('meetup', '(read,game_cancelled,,)'),
               ('meetup', '(read,game_ended,,)'), ('meetup', '(read,left,%'), ('meetup', '(,not_member,,)')) v(k, r);
SELECT pg_temp.chk('E-covers-not_in_pilot',
       (SELECT (count(*) > 0)::text FROM ev WHERE m = 'allowlist' AND live[1] = '(,not_in_pilot,,)'), 'true');

-- ---------------------------------------------------------------- U: msg_authorize parity, whole dataset
CREATE TEMP TABLE au (cid uuid, u uuid, m text, live text[], leg text[]);
DO $u$
DECLARE r record;
BEGIN
  FOR r IN SELECT u FROM usr LOOP
    PERFORM set_config('request.jwt.claim.sub', coalesce(r.u::text, ''), true);
    INSERT INTO au
    SELECT c.id, r.u, m.m,
           (SELECT array_agg(row(x.*)::text) FROM public.msg_authorize(c.id, m.m) x),
           (SELECT array_agg(row(y.*)::text) FROM pg_temp.legacy_msg_authorize(c.id, m.m) y)
      FROM (SELECT id FROM cv UNION ALL SELECT '00000000-0000-0000-0000-00000000dead'::uuid) c
     CROSS JOIN (VALUES ('all'), ('allowlist'), ('off')) m(m);
  END LOOP;
  PERFORM set_config('request.jwt.claim.sub', '', true);
END
$u$;
SELECT pg_temp.chk('U-rows', (SELECT count(*) FROM au)::text, (((SELECT count(*) FROM cv) + 1) * 8 * 3)::text);
SELECT pg_temp.chk('U-parity', (SELECT count(*) FROM au WHERE live IS DISTINCT FROM leg)::text, '0');
SELECT pg_temp.chk('U-one-row-each', (SELECT count(*) FROM au WHERE coalesce(array_length(live, 1), 0) <> 1)::text, '0');
SELECT pg_temp.chk('U-covers-meetup-members',
       (SELECT (count(*) > 0)::text FROM au JOIN cv ON cv.id = au.cid
         WHERE cv.kind = 'meetup' AND au.live[1] ~ '^\([0-9a-f-]+,(send|read),'), 'true');

-- ---------------------------------------------------------------- M: msg_my_conversations parity
CREATE TEMP TABLE my (u uuid, lim text, src text, ord bigint, cid uuid, r text);
DO $m$
DECLARE r record; l record; v_live text; v_leg text;
BEGIN
  v_live := pg_temp.nolimit('public.msg_my_conversations(integer)'::regprocedure);
  v_leg  := pg_temp.nolimit('pg_temp.legacy_msg_my_conversations(integer)'::regprocedure);
  FOR r IN SELECT u FROM usr LOOP
    PERFORM set_config('request.jwt.claim.sub', coalesce(r.u::text, ''), true);
    FOR l IN SELECT * FROM (VALUES ('100'), ('50'), ('1'), ('0'), ('500'), (NULL)) t(lim) LOOP
      INSERT INTO my SELECT r.u, coalesce(l.lim, '<null>'), 'live', x.ordinality, x.conversation_id, row(x.*)::text
                       FROM public.msg_my_conversations(l.lim::int) WITH ORDINALITY x;
      INSERT INTO my SELECT r.u, coalesce(l.lim, '<null>'), 'leg', x.ordinality, x.conversation_id, row(x.*)::text
                       FROM pg_temp.legacy_msg_my_conversations(l.lim::int) WITH ORDINALITY x;
    END LOOP;
    -- the default-argument call shape
    INSERT INTO my SELECT r.u, 'default', 'live', x.ordinality, x.conversation_id, row(x.*)::text
                     FROM public.msg_my_conversations() WITH ORDINALITY x;
    INSERT INTO my SELECT r.u, 'default', 'leg', x.ordinality, x.conversation_id, row(x.*)::text
                     FROM pg_temp.legacy_msg_my_conversations() WITH ORDINALITY x;
    -- the whole dataset: the body without its LIMIT
    EXECUTE format('INSERT INTO my SELECT %L::uuid, %L, %L, 0, t.conversation_id, row(t.*)::text FROM (%s) t',
                   r.u, 'all', 'live', v_live);
    EXECUTE format('INSERT INTO my SELECT %L::uuid, %L, %L, 0, t.conversation_id, row(t.*)::text FROM (%s) t',
                   r.u, 'all', 'leg', v_leg);
  END LOOP;
  PERFORM set_config('request.jwt.claim.sub', '', true);
END
$m$;
SELECT '#COUNT|M|' || coalesce(u::text, '<null>') || '|all=' || count(*) FILTER (WHERE lim = 'all' AND src = 'live')
       || '|lim100=' || count(*) FILTER (WHERE lim = '100' AND src = 'live')
  FROM my GROUP BY u ORDER BY 1;
-- ordered parity for every limited call shape (order is part of the contract)
SELECT pg_temp.chk('M-ordered-parity', (SELECT count(*) FROM (
         SELECT u, lim, md5(string_agg(r, '|' ORDER BY ord) FILTER (WHERE src = 'live')) AS a,
                        md5(string_agg(r, '|' ORDER BY ord) FILTER (WHERE src = 'leg')) AS b
           FROM my WHERE lim <> 'all' GROUP BY u, lim) z WHERE a IS DISTINCT FROM b)::text, '0');
-- multiset parity over the whole dataset
SELECT pg_temp.chk('M-all-parity', (SELECT count(*) FROM (
         (SELECT u, r FROM my WHERE lim = 'all' AND src = 'live' EXCEPT ALL SELECT u, r FROM my WHERE lim = 'all' AND src = 'leg')
         UNION ALL
         (SELECT u, r FROM my WHERE lim = 'all' AND src = 'leg' EXCEPT ALL SELECT u, r FROM my WHERE lim = 'all' AND src = 'live')) z)::text, '0');
SELECT pg_temp.chk('M-all-no-doubled-rows', (SELECT count(*) FROM (SELECT u, cid FROM my WHERE lim = 'all' AND src = 'live'
         GROUP BY u, cid HAVING count(*) > 1) z)::text, '0');
SELECT pg_temp.chk('M-all-nonempty', (SELECT (count(*) > 2000)::text FROM my WHERE lim = 'all' AND src = 'live'), 'true');
SELECT pg_temp.chk('M-all-both-kinds', (SELECT count(DISTINCT split_part(r, ',', 9))::text FROM my WHERE lim = 'all' AND src = 'live'), '2');
SELECT pg_temp.chk('M-limit-100-cap', (SELECT max(c)::text FROM (SELECT count(*) c FROM my WHERE lim IN ('100', '500') AND src = 'live' GROUP BY u, lim) z), '100');
SELECT pg_temp.chk('M-anon-empty', (SELECT count(*)::text FROM my WHERE u IS NULL AND src = 'live'), '0');
-- the all-users result covers every state the shared facts drive
SELECT pg_temp.chk('M-covers-' || s, (SELECT (count(*) > 0)::text FROM my WHERE lim = 'all' AND src = 'live' AND split_part(r, ',', 7) = s), 'true')
  FROM (VALUES ('send'), ('read_only'), ('left')) v(s);

-- ---------------------------------------------------------------- W: the Worker's msg_game_conversation call shapes
-- workers/messaging/src/games.ts: POST rpc/msg_game_conversation {p_game_id: lower(id), p_access_mode} under the
-- caller's JWT (role authenticated). conversation_id of a freshly created chat is compared as present/absent.
CREATE FUNCTION pg_temp.wsql(p_fn text, p_game text, p_mode text) RETURNS text LANGUAGE sql AS $$
  SELECT format($f$SELECT string_agg((x.user_id, x.conversation_id IS NOT NULL, x.game_id, x.allowed_action, x.reason,
                        x.left_at_seq, x.muted)::text, ';') FROM %s(p_game_id => %L, p_access_mode => %L) x$f$,
                p_fn, lower(p_game), p_mode)
$$;
CREATE TEMP TABLE wc (shape text, g text, u uuid, role text, m text, live text, leg text);
-- existing conversations: every game chat x every user, mode all
INSERT INTO wc
SELECT 'existing', c.game_id::text, u.u, 'authenticated', 'all',
       pg_temp.as_('authenticated', u.u, pg_temp.wsql('public.msg_game_conversation', c.game_id::text, 'all')),
       pg_temp.as_('authenticated', u.u, pg_temp.wsql('pg_temp.legacy_msg_game_conversation', c.game_id::text, 'all'))
  FROM cv c CROSS JOIN usr u WHERE c.kind = 'game' AND u.u IS NOT NULL;
-- create path: every game without a chat x every user x modes all / allowlist / off, each call rolled back
INSERT INTO wc
SELECT 'create', g.id::text, u.u, 'authenticated', m.m,
       pg_temp.as_rb('authenticated', u.u, pg_temp.wsql('public.msg_game_conversation', g.id::text, m.m)),
       pg_temp.as_rb('authenticated', u.u, pg_temp.wsql('pg_temp.legacy_msg_game_conversation', g.id::text, m.m))
  FROM gc_new g CROSS JOIN usr u CROSS JOIN (VALUES ('all'), ('allowlist'), ('off')) m(m) WHERE u.u IS NOT NULL;
-- gates: unknown game, upper-case id normalised by the Worker, anon role with no sub, authenticated with no sub
INSERT INTO wc
SELECT 'gate-' || s.shape, s.g, s.u, s.role, s.m,
       pg_temp.as_rb(s.role, s.u, pg_temp.wsql('public.msg_game_conversation', s.g, s.m)),
       pg_temp.as_rb(s.role, s.u, pg_temp.wsql('pg_temp.legacy_msg_game_conversation', s.g, s.m))
  FROM (VALUES ('unknown', '00000000-0000-0000-0000-00000000dead', '00000000-0000-0000-0000-0000000000a1'::uuid, 'authenticated', 'allowlist'),
               ('upper', upper(:'pg_game'), '00000000-0000-0000-0000-0000000000a1'::uuid, 'authenticated', 'allowlist'),
               ('anon', :'pg_game', NULL::uuid, 'anon', 'allowlist'),
               ('nosub', :'pg_game', NULL::uuid, 'authenticated', 'allowlist'),
               ('pilot', :'pg_game', '00000000-0000-0000-0000-0000000000a7'::uuid, 'authenticated', 'allowlist'),
               ('off', :'pg_game', '00000000-0000-0000-0000-0000000000a1'::uuid, 'authenticated', 'off')) s(shape, g, u, role, m);
SELECT '#COUNT|W|' || shape || '|' || coalesce(split_part(live, ',', 4) || ',' || split_part(live, ',', 5), live) || '|' || count(*)
  FROM wc GROUP BY shape, coalesce(split_part(live, ',', 4) || ',' || split_part(live, ',', 5), live) ORDER BY 1;
SELECT pg_temp.chk('W-parity', (SELECT count(*) FROM wc WHERE live IS DISTINCT FROM leg)::text, '0');
SELECT pg_temp.chk('W-no-error', (SELECT count(*) FROM wc WHERE live LIKE 'ERR%' OR live = '<null>')::text, '0');
SELECT pg_temp.chk('W-one-row-each', (SELECT count(*) FROM wc WHERE live LIKE '%;%')::text, '0');
SELECT pg_temp.chk('W-create-path-created', (SELECT (count(*) > 0)::text FROM wc WHERE shape = 'create' AND live ~ '^\([0-9a-f-]+,t,'), 'true');
SELECT pg_temp.chk('W-create-path-rolled-back', (SELECT count(*)::text FROM public.msg_conversations WHERE game_id IN (SELECT id FROM gc_new)), '0');
SELECT pg_temp.chk('W-gate-' || shape, live, want)
  FROM wc JOIN (VALUES ('gate-unknown', '(00000000-0000-0000-0000-0000000000a1,f,,,not_found,,f)'),
                       ('gate-anon', '(,f,,,not_authenticated,,f)'),
                       ('gate-nosub', '(,f,,,not_authenticated,,f)'),
                       ('gate-pilot', '(00000000-0000-0000-0000-0000000000a7,f,,,not_in_pilot,,f)'),
                       ('gate-off', '(00000000-0000-0000-0000-0000000000a1,f,,,messaging_off,,f)')) w(s, want) ON w.s = wc.shape;
SELECT pg_temp.chk('W-gate-upper-send', (SELECT live FROM wc WHERE shape = 'gate-upper'),
       '(00000000-0000-0000-0000-0000000000a1,t,' || :'pg_game' || ',send,,,'
       || (SELECT CASE WHEN muted_at IS NOT NULL THEN 't' ELSE 'f' END FROM public.msg_conversation_members
            WHERE conversation_id = :'pg_conv' AND user_id = '00000000-0000-0000-0000-0000000000a1') || ')');

-- ---------------------------------------------------------------- B: blocked, non-member, anon — literal answers
-- a1 blocks a6: a1's hidden_sender_ids is {a6}; a6's is empty; neither changes a membership answer.
SELECT pg_temp.chk('B-blocker-hidden', pg_temp.as_('authenticated', '00000000-0000-0000-0000-0000000000a1',
       format('SELECT x.hidden_sender_ids::text FROM public.msg_authorize(%L, %L) x', :'pg_conv', 'all')),
       '{00000000-0000-0000-0000-0000000000a6}');
SELECT pg_temp.chk('B-blocked-meetup', pg_temp.as_('authenticated', '00000000-0000-0000-0000-0000000000a6',
       format('SELECT (x.allowed_action, x.reason, x.hidden_sender_ids)::text FROM public.msg_authorize(%L, %L) x', :'pg_conv', 'all')),
       '(,not_member,)');
SELECT pg_temp.chk('B-nonmember-game', pg_temp.as_('authenticated', '00000000-0000-0000-0000-0000000000a3',
       format('SELECT row(x.*)::text FROM public.msg_authorize(%L, %L) x', :'pg_conv', 'all')),
       '(00000000-0000-0000-0000-0000000000a3,,not_member,,,)');
SELECT pg_temp.chk('B-nonmember-meetup', pg_temp.as_('authenticated', '00000000-0000-0000-0000-0000000000a3',
       format('SELECT row(x.*)::text FROM public.msg_authorize(%L, %L) x', :'pm_conv', 'all')),
       '(00000000-0000-0000-0000-0000000000a3,,not_member,,,)');
SELECT pg_temp.chk('B-anon-authorize', pg_temp.as_('anon', NULL,
       format('SELECT row(x.*)::text FROM public.msg_authorize(%L) x', :'pm_conv')), '(,,not_authenticated,,,)');
SELECT pg_temp.chk('B-anon-my', pg_temp.as_('anon', NULL, 'SELECT count(*)::text FROM public.msg_my_conversations(100)'), '0');
SELECT pg_temp.chk('B-anon-evaluate-null-user', pg_temp.as_('anon', NULL,
       format('SELECT row(x.*)::text FROM public.msg_evaluate(%L, NULL, %L) x', :'pm_conv', 'all')), '(,not_authenticated,,)');

-- ---------------------------------------------------------------- P: provenance — events-only edits
-- Each edit touches ONLY public.events (session_replication_role = replica: the KAN-712 mirror and every other
-- origin trigger stay silent, so games/meetups keep the old value). post: the answer follows events. pre: it does not.
SELECT row(x.*)::text AS p_ev_before FROM public.msg_evaluate(:'pg_conv', '00000000-0000-0000-0000-0000000000a1', 'all') x \gset
SELECT row(x.*)::text AS p_evm_before FROM public.msg_evaluate(:'pm_conv', '00000000-0000-0000-0000-0000000000a3', 'all') x \gset
SELECT pg_temp.as_(NULL, '00000000-0000-0000-0000-0000000000a1',
       format('SELECT game_title || ''|'' || state FROM public.msg_my_conversations(100) WHERE conversation_id = %L', :'pg_conv')) AS p_myg_before \gset
SELECT pg_temp.as_(NULL, :'pm_owner',
       format('SELECT coalesce(sport, ''<null>'') || ''|'' || state || ''|'' || game_title FROM public.msg_my_conversations(100) WHERE conversation_id = %L', :'pm_conv')) AS p_mym_before \gset
SELECT pg_temp.chk('P-baseline-game', :'p_ev_before', '(send,,,' || :'pg_game' || ')');
SELECT pg_temp.chk('P-baseline-meetup-outsider', :'p_evm_before', '(,not_member,,)');

-- P1 game cancelled on events only
SAVEPOINT p1;
SET LOCAL session_replication_role = replica;
UPDATE public.events SET is_cancelled = true WHERE id = :'pg_ev';
SET LOCAL session_replication_role = origin;
SELECT row(x.*)::text AS p1 FROM public.msg_evaluate(:'pg_conv', '00000000-0000-0000-0000-0000000000a1', 'all') x \gset
SELECT is_cancelled::text AS p1_sub FROM public.games WHERE id = :'pg_game' \gset
ROLLBACK TO SAVEPOINT p1;
SELECT pg_temp.chk('P1-game-cancelled-subtype-untouched', :'p1_sub', 'false');
SELECT pg_temp.chk('P1-game-cancelled', :'p1', CASE WHEN pg_temp.post() THEN '(read,game_cancelled,,' || :'pg_game' || ')' ELSE :'p_ev_before' END);

-- P2 game ended on events only
SAVEPOINT p2;
SET LOCAL session_replication_role = replica;
UPDATE public.events SET start_at = now() - interval '2 days', end_at = now() - interval '1 day' WHERE id = :'pg_ev';
SET LOCAL session_replication_role = origin;
SELECT row(x.*)::text AS p2 FROM public.msg_evaluate(:'pg_conv', '00000000-0000-0000-0000-0000000000a1', 'all') x \gset
SELECT pg_temp.as_(NULL, '00000000-0000-0000-0000-0000000000a1',
       format('SELECT game_title || ''|'' || state FROM public.msg_my_conversations(100) WHERE conversation_id = %L', :'pg_conv')) AS p2_my \gset
ROLLBACK TO SAVEPOINT p2;
SELECT pg_temp.chk('P2-game-ended-evaluate', :'p2', CASE WHEN pg_temp.post() THEN '(read,game_ended,,' || :'pg_game' || ')' ELSE :'p_ev_before' END);
SELECT pg_temp.chk('P2-game-ended-my-state', split_part(:'p2_my', '|', 2), CASE WHEN pg_temp.post() THEN 'read_only' ELSE 'send' END);

-- P3 game title on events only
SAVEPOINT p3;
SET LOCAL session_replication_role = replica;
UPDATE public.events SET title = 'KAN-730 provenance title' WHERE id = :'pg_ev';
SET LOCAL session_replication_role = origin;
SELECT pg_temp.as_(NULL, '00000000-0000-0000-0000-0000000000a1',
       format('SELECT game_title || ''|'' || state FROM public.msg_my_conversations(100) WHERE conversation_id = %L', :'pg_conv')) AS p3 \gset
ROLLBACK TO SAVEPOINT p3;
SELECT pg_temp.chk('P3-game-title', :'p3', CASE WHEN pg_temp.post() THEN 'KAN-730 provenance title|send' ELSE :'p_myg_before' END);

-- P4 meetup organiser on events only: a3 becomes the organiser
SAVEPOINT p4;
SET LOCAL session_replication_role = replica;
UPDATE public.events SET creator_user_id = '00000000-0000-0000-0000-0000000000a3' WHERE id = :'pm_ev';
SET LOCAL session_replication_role = origin;
SELECT row(x.*)::text AS p4 FROM public.msg_evaluate(:'pm_conv', '00000000-0000-0000-0000-0000000000a3', 'all') x \gset
SELECT pg_temp.as_(NULL, '00000000-0000-0000-0000-0000000000a3',
       format('SELECT (x.allowed_action, (%L::uuid = ANY (x.member_user_ids)))::text FROM public.msg_authorize(%L, %L) x',
              '00000000-0000-0000-0000-0000000000a3', :'pm_conv', 'all')) AS p4_au \gset
SELECT pg_temp.as_(NULL, '00000000-0000-0000-0000-0000000000a3',
       format('SELECT count(*)::text FROM public.msg_my_conversations(100) WHERE conversation_id = %L', :'pm_conv')) AS p4_my \gset
ROLLBACK TO SAVEPOINT p4;
SELECT pg_temp.chk('P4-meetup-organiser-evaluate', :'p4', CASE WHEN pg_temp.post() THEN '(send,,,)' ELSE :'p_evm_before' END);
SELECT pg_temp.chk('P4-meetup-organiser-authorize', :'p4_au', CASE WHEN pg_temp.post() THEN '(send,t)' ELSE '(,)' END);
SELECT pg_temp.chk('P4-meetup-organiser-my', :'p4_my', CASE WHEN pg_temp.post() THEN '1' ELSE '0' END);

-- P5 meetup ended (start and end) on events only
SAVEPOINT p5;
SET LOCAL session_replication_role = replica;
UPDATE public.events SET start_at = now() - interval '2 days', end_at = now() - interval '1 day' WHERE id = :'pm_ev';
SET LOCAL session_replication_role = origin;
SELECT pg_temp.as_(NULL, :'pm_owner',
       format('SELECT coalesce(sport, ''<null>'') || ''|'' || state || ''|'' || game_title FROM public.msg_my_conversations(100) WHERE conversation_id = %L', :'pm_conv')) AS p5 \gset
SELECT row(x.*)::text AS p5_ev FROM public.msg_evaluate(:'pm_conv', :'pm_owner', 'all') x \gset
ROLLBACK TO SAVEPOINT p5;
SELECT pg_temp.chk('P5-meetup-ended-my-state', split_part(:'p5', '|', 2), CASE WHEN pg_temp.post() THEN 'read_only' ELSE 'send' END);
SELECT pg_temp.chk('P5-meetup-ended-evaluate', :'p5_ev', CASE WHEN pg_temp.post() THEN '(read,game_ended,,)' ELSE '(send,,,)' END);

-- P6 meetup cancelled, sport cleared, title changed on events only
SAVEPOINT p6;
SET LOCAL session_replication_role = replica;
UPDATE public.events SET is_cancelled = true, sport_id = NULL, title = 'KAN-730 meetup title' WHERE id = :'pm_ev';
SET LOCAL session_replication_role = origin;
SELECT pg_temp.as_(NULL, :'pm_owner',
       format('SELECT coalesce(sport, ''<null>'') || ''|'' || state || ''|'' || game_title FROM public.msg_my_conversations(100) WHERE conversation_id = %L', :'pm_conv')) AS p6 \gset
SELECT row(x.*)::text AS p6_ev FROM public.msg_evaluate(:'pm_conv', :'pm_owner', 'all') x \gset
ROLLBACK TO SAVEPOINT p6;
SELECT pg_temp.chk('P6-meetup-sport-cancel-title-my', :'p6', CASE WHEN pg_temp.post() THEN '<null>|read_only|KAN-730 meetup title' ELSE :'p_mym_before' END);
SELECT pg_temp.chk('P6-meetup-cancelled-evaluate', :'p6_ev', CASE WHEN pg_temp.post() THEN '(read,game_cancelled,,)' ELSE '(send,,,)' END);

-- ---------------------------------------------------------------- A: access — events stays closed to the API
SELECT pg_temp.chk('A-events-anon', left(pg_temp.as_('anon', NULL, 'SELECT count(*)::text FROM public.events'), 9), 'ERR 42501');
SELECT pg_temp.chk('A-events-authenticated', left(pg_temp.as_('authenticated', '00000000-0000-0000-0000-0000000000a1',
       'SELECT count(*)::text FROM public.events'), 9), 'ERR 42501');
SELECT pg_temp.chk('A-events-force-rls', (SELECT (relrowsecurity AND relforcerowsecurity)::text FROM pg_class WHERE oid = 'public.events'::regclass), 'true');
SELECT pg_temp.chk('A-events-no-policies', (SELECT count(*)::text FROM pg_policy WHERE polrelid = 'public.events'::regclass), '0');
SELECT pg_temp.chk('A-events-no-api-grants', (SELECT count(*)::text FROM information_schema.role_table_grants
        WHERE table_schema = 'public' AND table_name = 'events' AND grantee IN ('anon', 'authenticated', 'PUBLIC')), '0');
-- authenticated callers still get their chats through the SECURITY DEFINER readers
SELECT pg_temp.chk('A-authenticated-my-via-definer', pg_temp.as_('authenticated', '00000000-0000-0000-0000-0000000000a1',
       format('SELECT count(*)::text FROM public.msg_my_conversations(100) WHERE conversation_id = %L', :'pg_conv')), '1');

-- ---------------------------------------------------------------- X: EXPLAIN shape — no new per-row SubPlans
-- (1) msg_my_conversations: the whole installed body vs the legacy body, planned as a1.
SELECT set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000a1', true);
SELECT pg_temp.plan(pg_temp.nolimit('public.msg_my_conversations(integer)'::regprocedure)) AS x_my_live \gset
SELECT pg_temp.plan(pg_temp.nolimit('pg_temp.legacy_msg_my_conversations(integer)'::regprocedure)) AS x_my_leg \gset
SELECT set_config('request.jwt.claim.sub', '', true);
SELECT '#PLAN|my|live|subplans=' || pg_temp.cnt(:'x_my_live', 'SubPlan') || '|events=' || pg_temp.cnt(:'x_my_live', ' on events ')
       || '|legacy|subplans=' || pg_temp.cnt(:'x_my_leg', 'SubPlan') || '|events=' || pg_temp.cnt(:'x_my_leg', ' on events ');
SELECT pg_temp.chk('X-my-subplans-equal', pg_temp.cnt(:'x_my_live', 'SubPlan')::text, pg_temp.cnt(:'x_my_leg', 'SubPlan')::text);
SELECT pg_temp.chk('X-my-events-joined', pg_temp.cnt(:'x_my_live', ' on events ')::text, CASE WHEN pg_temp.post() THEN '2' ELSE '0' END);
SELECT pg_temp.chk('X-my-no-events-subplan', (:'x_my_live' ~ 'SubPlan[^\n]*\n(\s+->[^\n]*\n)*?\s+->\s+[^\n]* on events ')::text, 'false');

-- (2) the three changed plpgsql statements: the installed body must contain the image's statement, and that
--     statement's plan must have no more SubPlans than the legacy statement's.
CREATE TEMP TABLE xs (id text, fn regprocedure, pre_frag text, post_frag text, pre_sql text, post_sql text);
INSERT INTO xs VALUES
 ('evaluate-meetup', 'public.msg_evaluate(uuid,uuid,text)',
  'FROM public.msg_conversations c JOIN public.meetups mt ON mt.id = c.meetup_id WHERE c.id = p_conversation_id;',
  'FROM public.msg_conversations c JOIN public.meetups mt ON mt.id = c.meetup_id JOIN public.events e ON e.id = mt.event_id AND e.event_type = ''meetup'' WHERE c.id = p_conversation_id;',
  'SELECT c.meetup_id, mt.is_cancelled, COALESCE(mt.end_at, mt.start_at), mt.creator_user_id FROM public.msg_conversations c JOIN public.meetups mt ON mt.id = c.meetup_id WHERE c.id = p_conversation_id',
  'SELECT c.meetup_id, e.is_cancelled, COALESCE(e.end_at, e.start_at), e.creator_user_id FROM public.msg_conversations c JOIN public.meetups mt ON mt.id = c.meetup_id JOIN public.events e ON e.id = mt.event_id AND e.event_type = ''meetup'' WHERE c.id = p_conversation_id'),
 ('evaluate-game', 'public.msg_evaluate(uuid,uuid,text)',
  'FROM public.msg_conversations c JOIN public.games g ON g.id = c.game_id WHERE c.id = p_conversation_id;',
  'FROM public.msg_conversations c JOIN public.games g ON g.id = c.game_id JOIN public.events e ON e.id = g.event_id AND e.event_type = ''game'' WHERE c.id = p_conversation_id;',
  'SELECT c.game_id, g.is_cancelled, g.end_at FROM public.msg_conversations c JOIN public.games g ON g.id = c.game_id WHERE c.id = p_conversation_id',
  'SELECT c.game_id, e.is_cancelled, e.end_at FROM public.msg_conversations c JOIN public.games g ON g.id = c.game_id JOIN public.events e ON e.id = g.event_id AND e.event_type = ''game'' WHERE c.id = p_conversation_id'),
 ('authorize-organiser', 'public.msg_authorize(uuid,text)',
  '(SELECT mt.creator_user_id AS uid FROM public.msg_conversations mc JOIN public.meetups mt ON mt.id = mc.meetup_id WHERE mc.id = p_conversation_id UNION',
  '(SELECT e.creator_user_id AS uid FROM public.msg_conversations mc JOIN public.meetups mt ON mt.id = mc.meetup_id JOIN public.events e ON e.id = mt.event_id AND e.event_type = ''meetup'' WHERE mc.id = p_conversation_id UNION',
  'SELECT mt.creator_user_id AS uid FROM public.msg_conversations mc JOIN public.meetups mt ON mt.id = mc.meetup_id WHERE mc.id = p_conversation_id',
  'SELECT e.creator_user_id AS uid FROM public.msg_conversations mc JOIN public.meetups mt ON mt.id = mc.meetup_id JOIN public.events e ON e.id = mt.event_id AND e.event_type = ''meetup'' WHERE mc.id = p_conversation_id');
SELECT pg_temp.chk('X-' || id || '-installed',
       (position(CASE WHEN pg_temp.post() THEN post_frag ELSE pre_frag END IN pg_temp.norm(p.prosrc)) > 0)::text, 'true')
  FROM xs JOIN pg_proc p ON p.oid = xs.fn;
SELECT pg_temp.chk('X-' || id || '-other-image-absent',
       (position(CASE WHEN pg_temp.post() THEN pre_frag ELSE post_frag END IN pg_temp.norm(p.prosrc)) > 0)::text, 'false')
  FROM xs JOIN pg_proc p ON p.oid = xs.fn;
CREATE TEMP TABLE xp AS
SELECT id,
       pg_temp.plan(replace(pre_sql,  'p_conversation_id', quote_literal(CASE WHEN id = 'evaluate-game' THEN :'pg_conv' ELSE :'pm_conv' END) || '::uuid')) AS pre_plan,
       pg_temp.plan(replace(post_sql, 'p_conversation_id', quote_literal(CASE WHEN id = 'evaluate-game' THEN :'pg_conv' ELSE :'pm_conv' END) || '::uuid')) AS post_plan
  FROM xs;
SELECT '#PLAN|' || id || '|pre|subplans=' || pg_temp.cnt(pre_plan, 'SubPlan') || '|events=' || pg_temp.cnt(pre_plan, ' on events ')
       || '|post|subplans=' || pg_temp.cnt(post_plan, 'SubPlan') || '|events=' || pg_temp.cnt(post_plan, ' on events ')
  FROM xp ORDER BY id;
SELECT pg_temp.chk('X-' || id || '-subplans-equal', pg_temp.cnt(post_plan, 'SubPlan')::text, pg_temp.cnt(pre_plan, 'SubPlan')::text) FROM xp;
SELECT pg_temp.chk('X-' || id || '-events-by-key', (post_plan ~ 'Index Scan using events_pkey on events e')::text, 'true') FROM xp;
-- the statements are the bodies' statements: run as the body would, they agree with the function's own answer
SELECT pg_temp.chk('X-evaluate-game-stmt-agrees',
       (SELECT row(t.*)::text FROM public.events e0, LATERAL (SELECT 1) z,
               LATERAL (SELECT c.game_id, e.is_cancelled, e.end_at FROM public.msg_conversations c JOIN public.games g ON g.id = c.game_id
                          JOIN public.events e ON e.id = g.event_id AND e.event_type = 'game' WHERE c.id = :'pg_conv') t
         WHERE e0.id = :'pg_ev'),
       (SELECT row(c.game_id, g.is_cancelled, g.end_at)::text FROM public.msg_conversations c JOIN public.games g ON g.id = c.game_id WHERE c.id = :'pg_conv'));

-- ---------------------------------------------------------------- report
SELECT CASE WHEN ok THEN 'PASS' ELSE 'FAIL' END || '|' || id || '|' || detail FROM res ORDER BY n;
SELECT '#SUMMARY|expect=' || current_setting('kan730.expect') || '|pass=' || count(*) FILTER (WHERE ok) || '|fail=' || count(*) FILTER (WHERE NOT ok) FROM res;
ROLLBACK;
