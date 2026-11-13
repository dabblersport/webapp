-- KAN-942 live test: the messaging access mode is server-controlled (public.msg_access_config). A direct authenticated
-- call passing p_access_mode = 'all' cannot widen access past the server mode; the caller may only narrow.
-- Runs on the hosted project as postgres (execute_sql or psql), entirely inside BEGIN ... ROLLBACK.
-- Fixture is picked live: a game conversation G with a member U the membership rules admit, and a meetup with its
-- organiser O. Both are removed from msg_access_allowlist inside the transaction, and the server mode is set to allowlist.
-- Expected (GREEN after 20261113231340_kan942_msg_server_access_mode.sql):
--   T1 U  msg_authorize(G,'all')            -> not_in_pilot        (RED before: allowed, caller 'all' skipped the allowlist)
--   T2 U  msg_game_conversation(game,'all') -> not_in_pilot        (RED before: allowed)
--   T3 O  msg_meetup_conversation(m,'all')  -> not_in_pilot        (RED before: allowed)
--   T4 U allowlisted: msg_authorize(G,'all') -> allowed (members still work)
--   T5 O allowlisted: msg_meetup_conversation(m,'all') -> allowed
--   T6 control: server mode 'all', U not allowlisted, caller 'all' -> allowed (the probe can tell the modes apart)
--   T7 narrowing kept: server 'all', caller 'allowlist', U not allowlisted -> not_in_pilot; caller 'off' -> messaging_off
--   T8 server 'off' -> messaging_off even with caller 'all'
--   T9 authenticated cannot read or write msg_access_config
BEGIN;
SET LOCAL client_min_messages = warning;

CREATE TEMP TABLE k942_tap (n int PRIMARY KEY, ok boolean NOT NULL, label text NOT NULL, detail text) ON COMMIT DROP;

-- As authenticated <uid>: run p_sql (returns one text value). Errors come back as 'ERR <sqlstate>'.
CREATE FUNCTION pg_temp.k942_as(p_uid uuid, p_sql text) RETURNS text LANGUAGE plpgsql AS $f$
DECLARE v text;
BEGIN
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', p_uid, 'role', 'authenticated')::text, true);
    PERFORM set_config('request.jwt.claim.sub', p_uid::text, true);
    SET LOCAL ROLE authenticated;
    EXECUTE p_sql INTO v;
    RESET ROLE;
  EXCEPTION WHEN OTHERS THEN
    RESET ROLE;
    v := 'ERR ' || SQLSTATE;
  END;
  PERFORM set_config('request.jwt.claims', '', true);
  PERFORM set_config('request.jwt.claim.sub', '', true);
  RETURN v;
END $f$;

DO $run$
DECLARE
  g_conv uuid; g_game uuid; u uuid;
  m_meetup uuid; o uuid;
  v text;
  auth_sql text := 'SELECT COALESCE(allowed_action, reason) FROM public.msg_authorize(%L::uuid, %L)';
BEGIN
  -- Fixture: a live game chat member and a live meetup organiser, as judged by the unchanged membership rules.
  SELECT c.id, c.game_id, m.user_id INTO g_conv, g_game, u
    FROM public.msg_conversations c JOIN public.msg_conversation_members m ON m.conversation_id = c.id
   WHERE c.kind = 'game'
     AND (SELECT e.allowed_action FROM public.msg_evaluate(c.id, m.user_id, 'all') e) IS NOT NULL
   LIMIT 1;
  -- No meetup chat may exist yet: msg_meetup_conversation runs the pilot check before it creates one (T5 creates it).
  SELECT mt.id, e.creator_user_id INTO m_meetup, o
    FROM public.kan714_meetups_read mt
    JOIN public.events e ON e.id = mt.event_id AND e.event_type = 'meetup'
   WHERE e.creator_user_id IS NOT NULL AND e.creator_user_id <> u
   ORDER BY (NOT e.is_cancelled AND COALESCE(e.end_at, e.start_at) >= now()) DESC
   LIMIT 1;
  IF g_conv IS NULL OR m_meetup IS NULL THEN RAISE EXCEPTION 'fixture missing: game % meetup %', g_conv, m_meetup; END IF;

  DELETE FROM public.msg_access_allowlist WHERE user_id IN (u, o);
  UPDATE public.msg_access_config SET mode = 'allowlist';

  v := pg_temp.k942_as(u, format(auth_sql, g_conv, 'all'));
  INSERT INTO k942_tap VALUES (1, v = 'not_in_pilot', 'direct msg_authorize(all) under server allowlist', v);
  v := pg_temp.k942_as(u, format('SELECT COALESCE(allowed_action, reason) FROM public.msg_game_conversation(%L::uuid, %L)', g_game, 'all'));
  INSERT INTO k942_tap VALUES (2, v = 'not_in_pilot', 'direct msg_game_conversation(all) under server allowlist', v);
  v := pg_temp.k942_as(o, format('SELECT COALESCE(allowed_action, reason) FROM public.msg_meetup_conversation(%L::uuid, %L)', m_meetup, 'all'));
  INSERT INTO k942_tap VALUES (3, v = 'not_in_pilot', 'direct msg_meetup_conversation(all) under server allowlist', v);

  INSERT INTO public.msg_access_allowlist (user_id, note) VALUES (u, 'kan942 test'), (o, 'kan942 test');
  v := pg_temp.k942_as(u, format(auth_sql, g_conv, 'all'));
  INSERT INTO k942_tap VALUES (4, v IN ('send', 'read'), 'allowlisted member still authorised', v);
  v := pg_temp.k942_as(o, format('SELECT COALESCE(allowed_action, reason) FROM public.msg_meetup_conversation(%L::uuid, %L)', m_meetup, 'all'));
  INSERT INTO k942_tap VALUES (5, v IN ('send', 'read'), 'allowlisted meetup organiser still authorised', v);
  DELETE FROM public.msg_access_allowlist WHERE user_id IN (u, o);

  UPDATE public.msg_access_config SET mode = 'all';
  v := pg_temp.k942_as(u, format(auth_sql, g_conv, 'all'));
  INSERT INTO k942_tap VALUES (6, v IN ('send', 'read'), 'control: server all + caller all, not allowlisted', v);
  v := pg_temp.k942_as(u, format(auth_sql, g_conv, 'allowlist'));
  INSERT INTO k942_tap VALUES (7, v = 'not_in_pilot', 'caller may narrow: server all + caller allowlist', v);
  v := pg_temp.k942_as(u, format(auth_sql, g_conv, 'off'));
  INSERT INTO k942_tap VALUES (8, v = 'messaging_off', 'caller may narrow: caller off', v);

  UPDATE public.msg_access_config SET mode = 'off';
  v := pg_temp.k942_as(u, format(auth_sql, g_conv, 'all'));
  INSERT INTO k942_tap VALUES (9, v = 'messaging_off', 'server off beats caller all', v);

  v := pg_temp.k942_as(u, 'SELECT mode FROM public.msg_access_config');
  INSERT INTO k942_tap VALUES (10, v = 'ERR 42501', 'authenticated cannot read msg_access_config', v);
  v := pg_temp.k942_as(u, 'UPDATE public.msg_access_config SET mode = ''all'' RETURNING mode');
  INSERT INTO k942_tap VALUES (11, v = 'ERR 42501', 'authenticated cannot update msg_access_config', v);
END
$run$;

SELECT n, ok, label, detail FROM k942_tap ORDER BY n;
ROLLBACK;
