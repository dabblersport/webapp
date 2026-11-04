-- KAN-810 (supporting fix for KAN-761 F4): a second rpc_cancel_game keeps the first cancel's values.
--
-- LOCAL THROWAWAY POSTGRES ONLY. The guard refuses any database not named k810*, anything that looks like Supabase,
-- a TCP connection to a non-loopback address, and a non-superuser. One transaction, ROLLBACK at the end.
--
-- BUILD CHAIN (supabase/tests/events_p4/build_kan810.sh <datadir under /tmp> <port>, database k810):
--   events_p1/local_harness_kan711.sql, events_p1/local_seed_kan711.sql, events_p2/local_harness_kan712.sql,
--   events_p2_kan713/local_harness_kan713.sql, events_p2_kan714/local_harness_kan714.sql,
--   20261101140000 KAN-710, 20261102110000 + 20261102120000 KAN-711 (+ backfill run, validate_links),
--   20261103100000 + 20261103110000 KAN-712, 20261104100000 KAN-713 helpers, 20261104110000 KAN-713 location triggers,
--   20261104100100..20261104101400 KAN-714 B01..B14 (B04 on k788b only; fixtures as build_kan788.sh),
--   20261104102000 KAN-716 (publication supabase_realtime created empty first), events_p4/local_harness_kan772.sql,
--   20261104110100 D04, 20261104110200 D05, 20261104110300 D07, 20261104110400 KAN-785,
--   rpc_meetup_rsvp pre-image (generated verbatim from kan180:116-206 + 20260915120000:740-741), 20261104110500 KAN-786.
--   AFTER run only: + 20261104112000_kan810_cancel_game_idempotent.sql.
--
-- SIDE-EFFECT TRIGGERS on games (from local_harness_kan711.sql): trg_game_updated_notify is the baseline body
-- verbatim (baseline :17785) and inserts into notifications through the harness process_notification_event;
-- msg_system_game_cancelled is the live trigger definition (name, AFTER UPDATE OF is_cancelled, WHEN OLD IS NOT TRUE
-- AND NEW IS TRUE) over a harness STUB body (one msg_system_lines row; the real body is 20261013160000). The count
-- checked here is governed by the trigger's WHEN clause, which is the live one.
--
-- MARKS. [K] = KAN-810 behaviour: FAIL before the migration (that is the defect), PASS after.
--        [=] = must be identical before and after: PASS on both.
-- NOW(). Both cancels run in this one transaction, so now() is the same for both. Step S1b therefore moves the first
-- cancel's cancelled_at back one hour on BOTH games and events (superuser, session_replication_role = replica so the
-- KAN-712 guard and mirror do not fire; parity re-checked in P0). A rewrite by the second cancel is then visible.
--
-- Run: psql -X -h /tmp -p <port> -U postgres -d k810 -v ON_ERROR_STOP=1 -f supabase/tests/events_p4/kan810_cancel_idempotent.sql
\set ON_ERROR_STOP 1
\pset pager off
\set G   '''71300000-0000-0000-0000-000000000001'''
\set G2  '''71300000-0000-0000-0000-000000000002'''
\set GX  '''71300000-0000-0000-0000-0000000000ff'''
\set a1  '''00000000-0000-0000-0000-0000000000a1'''
\set a2  '''00000000-0000-0000-0000-0000000000a2'''
\set a3  '''00000000-0000-0000-0000-0000000000a3'''

DO $g$ BEGIN
  IF current_database() NOT LIKE 'k810%' THEN
    RAISE EXCEPTION 'KAN-810: refusing database %: local throwaway k810* databases only', current_database();
  END IF;
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname IN ('supabase_admin', 'supabase_auth_admin', 'authenticator'))
     OR EXISTS (SELECT 1 FROM pg_namespace WHERE nspname IN ('storage', 'realtime', 'supabase_functions', 'vault', 'graphql')) THEN
    RAISE EXCEPTION 'KAN-810: this looks like a Supabase database; local throwaway database only';
  END IF;
  IF inet_server_addr() IS NOT NULL AND NOT (inet_server_addr() << '127.0.0.0/8'::inet OR inet_server_addr() = '::1'::inet) THEN
    RAISE EXCEPTION 'KAN-810: server address % is not local; refusing', inet_server_addr();
  END IF;
  IF NOT (SELECT rolsuper FROM pg_roles WHERE rolname = current_user) THEN
    RAISE EXCEPTION 'KAN-810: run as a superuser (session_replication_role needs it)';
  END IF;
END $g$;

\echo '== KAN-810 state of rpc_cancel_game_kan712_inner on this database'
SELECT p.oid::regprocedure AS fn, md5(pg_get_functiondef(p.oid)) AS def_md5, p.proacl
  FROM pg_proc p WHERE p.proname IN ('rpc_cancel_game', 'rpc_cancel_game_kan712_inner') ORDER BY 1;

BEGIN;
SET LOCAL lock_timeout = '3s';
\o /dev/null
CREATE TEMP TABLE res (n serial, id text, verdict text, expected text, actual text, name text);
CREATE TEMP TABLE act (k text PRIMARY KEY, v text);
CREATE FUNCTION pg_temp.keep(p_k text, p_v text) RETURNS void LANGUAGE sql AS $$ INSERT INTO act VALUES (p_k, p_v) $$;
CREATE FUNCTION pg_temp.a(p_k text) RETURNS text LANGUAGE sql AS $$ SELECT v FROM act WHERE k = p_k $$;
CREATE FUNCTION pg_temp.chk(p_id text, p_name text, p_expect text, p_actual text) RETURNS void LANGUAGE sql AS $$
  INSERT INTO res (id, verdict, expected, actual, name)
  VALUES (p_id, CASE WHEN p_actual IS NOT DISTINCT FROM p_expect THEN 'PASS' ELSE 'FAIL' END, p_expect,
          coalesce(p_actual, '<null>'), p_name);
$$;
-- as_(role, uid, sql): run sql as role with auth.uid() = uid; its text result, or 'ERR <sqlstate> <message>'.
CREATE FUNCTION pg_temp.as_(p_role text, p_uid uuid, p_sql text) RETURNS text LANGUAGE plpgsql AS $$
DECLARE v text; s text; m text;
BEGIN
  BEGIN
    PERFORM set_config('request.jwt.claim.sub', coalesce(p_uid::text, ''), true);
    EXECUTE format('SET LOCAL ROLE %I', p_role);
    EXECUTE p_sql INTO v;
    RESET ROLE;
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS s = RETURNED_SQLSTATE, m = MESSAGE_TEXT;
    RESET ROLE;
    v := 'ERR ' || s || ' ' || m;
  END;
  PERFORM set_config('request.jwt.claim.sub', '', true);
  PERFORM set_config('kan712.contract', '', true);
  PERFORM set_config('kan712.routing', '', true);
  PERFORM set_config('kan712.compat', '', true);
  RETURN coalesce(v, '<null>');
END $$;
-- Cancel state of a game as text, from games (g) or events (e).
CREATE FUNCTION pg_temp.gstate(p_id uuid) RETURNS text LANGUAGE sql AS $$
  SELECT format('is_cancelled=%s cancelled_at=%s reason=%s', is_cancelled, cancelled_at, coalesce(cancelled_reason, '<null>'))
    FROM public.games WHERE id = p_id $$;
CREATE FUNCTION pg_temp.estate(p_id uuid) RETURNS text LANGUAGE sql AS $$
  SELECT format('is_cancelled=%s cancelled_at=%s reason=%s', e.is_cancelled, e.cancelled_at, coalesce(e.cancelled_reason, '<null>'))
    FROM public.games g JOIN public.events e ON e.id = g.event_id WHERE g.id = p_id $$;
CREATE FUNCTION pg_temp.nnotif(p_id uuid) RETURNS int LANGUAGE sql AS $$
  SELECT count(*)::int FROM public.notifications WHERE entity_id = p_id $$;
CREATE FUNCTION pg_temp.nmsg(p_id uuid) RETURNS int LANGUAGE sql AS $$
  SELECT count(*)::int FROM public.msg_system_lines WHERE game_id = p_id $$;
-- Shared columns (games and events both carry them, minus id/event_type/search_tsv/created_at) that differ.
CREATE FUNCTION pg_temp.parity_diff(p_id uuid) RETURNS text LANGUAGE sql AS $$
  SELECT coalesce(string_agg(jg.key, ',' ORDER BY jg.key), '')
    FROM public.games g JOIN public.events e ON e.id = g.event_id,
         jsonb_each(to_jsonb(g)) jg JOIN jsonb_each(to_jsonb(e)) je USING (key)
   WHERE g.id = p_id AND jg.key NOT IN ('id', 'event_type', 'search_tsv', 'created_at')
     AND jg.value IS DISTINCT FROM je.value $$;
CREATE FUNCTION pg_temp.parity_cols(p_id uuid) RETURNS text LANGUAGE sql AS $$
  SELECT string_agg(jg.key, ',' ORDER BY jg.key)
    FROM public.games g JOIN public.events e ON e.id = g.event_id,
         jsonb_each(to_jsonb(g)) jg JOIN jsonb_each(to_jsonb(e)) je USING (key)
   WHERE g.id = p_id AND jg.key NOT IN ('id', 'event_type', 'search_tsv', 'created_at') $$;

-- Fixture facts the checks rely on (game G: host a1, future, not cancelled, one non-host roster player a4).
SELECT pg_temp.chk('F0', 'fixture: G exists, host a1, not cancelled, 1 non-host roster player; a2 not admin, a3 admin',
  't|a1|f|1|f|t',
  (SELECT concat_ws('|', g.start_at > now(), CASE WHEN g.creator_user_id = :a1 THEN 'a1' END, g.is_cancelled,
            (SELECT count(*) FROM public.game_roster r WHERE r.game_id = g.id AND r.user_id <> g.creator_user_id),
            public.is_admin(:a2), public.is_admin(:a3))
     FROM public.games g WHERE g.id = :G));
SELECT pg_temp.keep('n0', pg_temp.nnotif(:G)::text), pg_temp.keep('m0', pg_temp.nmsg(:G)::text);

-- S1: first cancel by the host, reason r1.
SELECT pg_temp.keep('s1', pg_temp.as_('authenticated', :a1, format($s$SELECT public.rpc_cancel_game(%L, 'r1')$s$, :G)));
SELECT pg_temp.chk('S1', 'first cancel by host returns cancelled', 'cancelled', pg_temp.a('s1'));

-- S1b: age the first cancel by one hour on both tables (see NOW() in the header).
SET LOCAL session_replication_role = replica;
UPDATE public.games  SET cancelled_at = cancelled_at - interval '1 hour' WHERE id = :G;
UPDATE public.events SET cancelled_at = cancelled_at - interval '1 hour'
 WHERE id = (SELECT event_id FROM public.games WHERE id = :G);
SET LOCAL session_replication_role = origin;
SELECT pg_temp.keep('first_g', pg_temp.gstate(:G)), pg_temp.keep('first_e', pg_temp.estate(:G)),
       pg_temp.keep('n1', pg_temp.nnotif(:G)::text), pg_temp.keep('m1', pg_temp.nmsg(:G)::text);
SELECT pg_temp.chk('P0', 'after the first cancel: games and events agree on every shared column', '', pg_temp.parity_diff(:G));
SELECT pg_temp.chk('S1c', 'first cancel recorded reason r1 and is_cancelled=true',
  'true|r1', (SELECT is_cancelled || '|' || cancelled_reason FROM public.games WHERE id = :G));

-- N1: non-host second cancel of the already-cancelled game.
SELECT pg_temp.keep('n1x', pg_temp.as_('authenticated', :a2, format($s$SELECT public.rpc_cancel_game(%L, 'rX')$s$, :G)));
SELECT pg_temp.chk('N1 [=]', 'non-host cancel of an already-cancelled game raises P0001 not_host_or_not_found',
  'ERR P0001 not_host_or_not_found', pg_temp.a('n1x'));
SELECT pg_temp.chk('N1b [=]', 'non-host attempt changed nothing', pg_temp.a('first_g'), pg_temp.gstate(:G));

-- S2: second cancel by the host, reason r2.
SELECT pg_temp.keep('s2', pg_temp.as_('authenticated', :a1, format($s$SELECT public.rpc_cancel_game(%L, 'r2')$s$, :G)));
SELECT pg_temp.chk('R1 [=]', 'second cancel by host returns cancelled', 'cancelled', pg_temp.a('s2'));
SELECT pg_temp.keep('second_g', pg_temp.gstate(:G)), pg_temp.keep('second_e', pg_temp.estate(:G));

\echo '== C1 values: first cancel (aged) vs after the second cancel'
\o
SELECT 'games  first ' AS row, pg_temp.a('first_g') AS state
UNION ALL SELECT 'games  second', pg_temp.a('second_g')
UNION ALL SELECT 'events first ', pg_temp.a('first_e')
UNION ALL SELECT 'events second', pg_temp.a('second_e');
\o /dev/null

SELECT pg_temp.chk('C1 [K]', 'games: second cancel leaves cancelled_at and cancelled_reason as the first cancel wrote them',
  pg_temp.a('first_g'), pg_temp.a('second_g'));
SELECT pg_temp.chk('C2a [K]', 'events: second cancel leaves cancelled_at and cancelled_reason as the first cancel wrote them',
  pg_temp.a('first_e'), pg_temp.a('second_e'));
SELECT pg_temp.chk('C2b [=]', 'notifications for G: exactly 1 new row over both cancels (one non-host player)',
  '1', (pg_temp.nnotif(:G) - pg_temp.a('n0')::int)::text);
SELECT pg_temp.chk('C2c [=]', 'msg_system_lines for G: exactly 1 new row over both cancels',
  '1', (pg_temp.nmsg(:G) - pg_temp.a('m0')::int)::text);
SELECT pg_temp.chk('C2d [=]', 'the second cancel added no notification and no system line',
  pg_temp.a('n1') || '|' || pg_temp.a('m1'), pg_temp.nnotif(:G) || '|' || pg_temp.nmsg(:G));
SELECT pg_temp.chk('C3 [=]', 'games vs events parity after both cancels: no shared column differs', '', pg_temp.parity_diff(:G));
\o
\echo '== C3 shared columns compared (games vs events)'
SELECT pg_temp.parity_cols(:G) AS shared_columns_compared, pg_temp.parity_diff(:G) AS differing;
\o /dev/null

-- A1: an admin's repeat cancel (a3 is a harness_admins row in the fixture, checked in F0) returns cancelled, rewrites nothing.
SELECT pg_temp.keep('a1x', pg_temp.as_('authenticated', :a3, format($s$SELECT public.rpc_cancel_game(%L, 'r3')$s$, :G)));
SELECT pg_temp.chk('A1 [=]', 'admin repeat cancel returns cancelled', 'cancelled', pg_temp.a('a1x'));
SELECT pg_temp.chk('A1b [K]', 'admin repeat cancel leaves the first cancel''s values', pg_temp.a('first_g'), pg_temp.gstate(:G));

-- N2: missing game.  N3: non-host first cancel of a live game (G2, host a1) is refused and changes nothing.
SELECT pg_temp.keep('n2', pg_temp.as_('authenticated', :a1, format($s$SELECT public.rpc_cancel_game(%L, 'r')$s$, :GX)));
SELECT pg_temp.chk('N2 [=]', 'missing game raises P0001 not_host_or_not_found', 'ERR P0001 not_host_or_not_found', pg_temp.a('n2'));
SELECT pg_temp.keep('g2_0', pg_temp.gstate(:G2));
SELECT pg_temp.keep('n3', pg_temp.as_('authenticated', :a2, format($s$SELECT public.rpc_cancel_game(%L, 'r')$s$, :G2)));
SELECT pg_temp.chk('N3 [=]', 'non-host cancel of a live game raises P0001 not_host_or_not_found',
  'ERR P0001 not_host_or_not_found', pg_temp.a('n3'));
SELECT pg_temp.chk('N3b [=]', 'non-host attempt left the live game unchanged', pg_temp.a('g2_0'), pg_temp.gstate(:G2));
SELECT pg_temp.chk('N3c [=]', 'the live game is not cancelled', 'false',
  (SELECT is_cancelled::text FROM public.games WHERE id = :G2));

\o
\echo '== KAN-810 results'
SELECT id, verdict, expected, actual, name FROM res ORDER BY n;
SELECT 'KAN-810 TOTAL pass=' || count(*) FILTER (WHERE verdict = 'PASS') || ' fail=' || count(*) FILTER (WHERE verdict = 'FAIL')
       || '  ([K] fail=' || count(*) FILTER (WHERE verdict = 'FAIL' AND id LIKE '%[K]%')
       || ', [=] and unmarked fail=' || count(*) FILTER (WHERE verdict = 'FAIL' AND id NOT LIKE '%[K]%') || ')' AS total
  FROM res;
ROLLBACK;
