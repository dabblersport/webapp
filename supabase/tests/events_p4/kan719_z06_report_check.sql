-- KAN-783 (KAN-719 Z06, Epic KAN-708): completion-report check. Integrity, compatibility, smoke and rollback,
-- measured on the state the completion report describes (KAN719_COMPLETION_REPORT.md).
--
-- LOCAL OR DISPOSABLE DATABASES ONLY. The guard refuses a Supabase-shaped database and any database whose name
-- does not start with k783 / kan783. Nothing here is a migration.
--
-- TWO MODES.
--   -v capture=1  BEFORE Z01. Writes schema kan783_pre: legacy and compat shapes, RPC result types, counts and the
--                 per-caller visible id sets. This is the only write the file makes and it is the reference below.
--   (default)     CHECK. Runs every check inside BEGIN ... ROLLBACK, then re-counts and re-fingerprints after the
--                 ROLLBACK. It raises on any failure and prints one PASS line otherwise.
--
-- CHECKS (check mode):
--   SHP1 kan718_games_compat / kan718_meetups_compat: column names, order and types equal the capture
--   SHP2 the same compat views equal the captured LEGACY games / meetups table shape (the old-client contract)
--   SHP3 events columns unchanged against the capture
--   SHP4 every captured RPC (public rpc_*) still exists with the same identity arguments and result type
--   CNT1 events = games + meetups (no row doubled across subtypes)
--   CNT2 no id doubled inside games, meetups, events, either compat view
--   CNT3 games, meetups, events and both compat views have the captured (legacy) counts
--   SEED the seeded game and meetup (78100000-...) exist once in events, in their subtype and in the compat view
--   VIS  owner, stranger, blocked user, anon and service_role see exactly the captured id set through games,
--        meetups and both compat views: the stranger and the blocked user see nothing extra
--   WRT  inside the transaction an events title edit of the seeded game is visible through the compat view
--   R    after ROLLBACK: games / meetups / events / compat data md5 equal the value taken before BEGIN, the WRT
--        edit is gone, and the counts still equal the capture
--
-- Run (repository root):
--   psql -X -h <socket> -p <port> -U postgres -d k783... -v ON_ERROR_STOP=1 -v capture=1 -f supabase/tests/events_p4/kan719_z06_report_check.sql
--   psql -X -h <socket> -p <port> -U postgres -d k783... -v ON_ERROR_STOP=1 -f supabase/tests/events_p4/kan719_z06_report_check.sql
\set ON_ERROR_STOP 1
SET client_min_messages = notice;

DO $g$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'supabase_admin')
     OR EXISTS (SELECT 1 FROM pg_namespace WHERE nspname IN ('storage', 'realtime', 'supabase_functions')) THEN
    RAISE EXCEPTION 'KAN-783: this looks like a Supabase database; local or disposable database only';
  END IF;
  IF current_database() !~ '^(k783|kan783)' THEN
    RAISE EXCEPTION 'KAN-783: database % is not a KAN-783 throwaway database; refusing', current_database();
  END IF;
  IF NOT (SELECT rolsuper FROM pg_roles WHERE rolname = current_user) THEN RAISE EXCEPTION 'KAN-783: run as a superuser'; END IF;
  IF to_regclass('public.kan718_games_compat') IS NULL OR to_regclass('public.kan718_meetups_compat') IS NULL THEN
    RAISE EXCEPTION 'KAN-783: the D05 compat views are not present; build the chain with D05 first';
  END IF;
END $g$;

-- p_sql (returning one text) as an API role. p_uid NULL = no sub claim. Any error becomes 'ERR <sqlstate> <message>'.
CREATE FUNCTION pg_temp.k783_as(p_role text, p_uid uuid, p_sql text) RETURNS text LANGUAGE plpgsql AS $f$
DECLARE r text; st text; m text; BEGIN
  PERFORM set_config('request.jwt.claim.sub', coalesce(p_uid::text, ''), true);
  PERFORM set_config('request.jwt.claims', CASE WHEN p_uid IS NULL THEN json_build_object('role', p_role)::text
                                                ELSE json_build_object('sub', p_uid, 'role', p_role)::text END, true);
  BEGIN
    EXECUTE format('SET LOCAL ROLE %I', p_role);
    EXECUTE p_sql INTO r;
    RESET ROLE;
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS st = RETURNED_SQLSTATE, m = MESSAGE_TEXT;
    RESET ROLE; r := 'ERR ' || st || ' ' || m;
  END;
  PERFORM set_config('request.jwt.claim.sub', '', true);
  PERFORM set_config('request.jwt.claims', '', true);
  RETURN coalesce(r, '<null>'); END $f$;
GRANT EXECUTE ON FUNCTION pg_temp.k783_as(text, uuid, text) TO anon, authenticated, service_role;

CREATE FUNCTION pg_temp.k783_shape(p_rel regclass) RETURNS text LANGUAGE sql STABLE AS $f$
  SELECT string_agg(attname || ':' || format_type(atttypid, atttypmod), ',' ORDER BY attnum)
    FROM pg_attribute WHERE attrelid = p_rel AND attnum > 0 AND NOT attisdropped $f$;

-- The data fingerprint R compares (tables + compat projections), and the visible-set probe.
CREATE FUNCTION pg_temp.k783_fp() RETURNS text LANGUAGE plpgsql AS $f$
DECLARE r text := ''; t text; v text; BEGIN
  FOREACH t IN ARRAY ARRAY['games', 'meetups', 'events', 'kan718_games_compat', 'kan718_meetups_compat'] LOOP
    EXECUTE format('SELECT count(*) || '':'' || coalesce(md5(string_agg(x::text, ''|'' ORDER BY x.id)), ''-'') FROM public.%I x', t) INTO v;
    r := r || t || '=' || v || ';';
  END LOOP;
  RETURN r; END $f$;

CREATE TEMP TABLE k783_who(label text, role text, uid uuid);
INSERT INTO k783_who VALUES
  ('owner', 'authenticated', '00000000-0000-0000-0000-0000000000a1'),
  ('stranger', 'authenticated', '00000000-0000-0000-0000-00000000dead'),
  ('blocked', 'authenticated', '00000000-0000-0000-0000-0000000000a6'),
  ('anon', 'anon', NULL),
  ('service_role', 'service_role', NULL);
GRANT SELECT ON k783_who TO anon, authenticated, service_role;

CREATE FUNCTION pg_temp.k783_visible(p_role text, p_uid uuid, p_src text) RETURNS text LANGUAGE sql AS $f$
  SELECT pg_temp.k783_as(p_role, p_uid,
    format('SELECT count(*) || '':'' || coalesce(md5(string_agg(id::text, '','' ORDER BY id)), ''-'') FROM public.%I', p_src)) $f$;

\if :{?capture}
-- ===================================== CAPTURE (before Z01) =====================================
DO $c$ BEGIN
  IF to_regnamespace('kan783_pre') IS NOT NULL THEN RAISE EXCEPTION 'KAN-783 CAPTURE: kan783_pre already exists'; END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'public.games'::regclass AND attname = 'title' AND NOT attisdropped) THEN
    RAISE EXCEPTION 'KAN-783 CAPTURE: games.title is already gone; the capture must be taken BEFORE Z01';
  END IF;
END $c$;
BEGIN;
CREATE SCHEMA kan783_pre;
REVOKE ALL ON SCHEMA kan783_pre FROM PUBLIC;
CREATE TABLE kan783_pre.shape AS
  SELECT r AS rel, pg_temp.k783_shape(r::regclass) AS cols
    FROM unnest(ARRAY['public.games', 'public.meetups', 'public.events', 'public.kan718_games_compat', 'public.kan718_meetups_compat']) r;
CREATE TABLE kan783_pre.rpc AS
  SELECT p.proname::text AS fn, pg_get_function_identity_arguments(p.oid) AS args, pg_get_function_result(p.oid) AS result
    FROM pg_proc p WHERE p.pronamespace = 'public'::regnamespace AND p.proname LIKE 'rpc\_%';
CREATE TABLE kan783_pre.counts AS
  SELECT t AS tbl, (xpath('/row/c/text()', query_to_xml(format('SELECT count(*) AS c FROM public.%I', t), false, true, '')))[1]::text::bigint AS n
    FROM unnest(ARRAY['games', 'meetups', 'events', 'kan718_games_compat', 'kan718_meetups_compat']) t;
CREATE TABLE kan783_pre.visible AS
  SELECT w.label AS who, s AS src, pg_temp.k783_visible(w.role, w.uid, s) AS ids
    FROM k783_who w CROSS JOIN unnest(ARRAY['games', 'meetups', 'kan718_games_compat', 'kan718_meetups_compat']) s;
DO $v$ BEGIN
  RAISE NOTICE 'KAN-783 CAPTURE: % shapes, % rpc signatures, counts %, % visibility rows (% of them ERR)',
    (SELECT count(*) FROM kan783_pre.shape), (SELECT count(*) FROM kan783_pre.rpc),
    (SELECT string_agg(tbl || '=' || n, ' ' ORDER BY tbl) FROM kan783_pre.counts),
    (SELECT count(*) FROM kan783_pre.visible), (SELECT count(*) FROM kan783_pre.visible WHERE ids LIKE 'ERR %');
END $v$;
COMMIT;
\else
-- ===================================== CHECK =====================================
DO $pre$ BEGIN
  IF to_regnamespace('kan783_pre') IS NULL THEN RAISE EXCEPTION 'KAN-783: no capture (kan783_pre); run with -v capture=1 before Z01'; END IF;
END $pre$;

CREATE TEMP TABLE k783_fp_before AS SELECT pg_temp.k783_fp() AS fp;
CREATE TEMP TABLE k783_state AS
  SELECT EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'public.games'::regclass AND attname = 'title' AND NOT attisdropped) AS games_title_present;

BEGIN;
CREATE TEMP TABLE k783_result(sec text, name text, ok boolean, detail text) ON COMMIT DROP;

DO $chk$
DECLARE r record; v text; n bigint; m bigint; g bigint; e bigint;
BEGIN
  -- SHP1 / SHP2 / SHP3
  FOR r IN SELECT * FROM kan783_pre.shape WHERE rel IN ('public.kan718_games_compat', 'public.kan718_meetups_compat', 'public.events') LOOP
    v := pg_temp.k783_shape(r.rel::regclass);
    INSERT INTO k783_result VALUES (CASE WHEN r.rel = 'public.events' THEN 'SHP3' ELSE 'SHP1' END, r.rel || ' shape = capture',
      v IS NOT DISTINCT FROM r.cols, CASE WHEN v IS DISTINCT FROM r.cols THEN 'now ' || coalesce(v, '<none>') ELSE length(v) || ' chars' END);
  END LOOP;
  FOR r IN SELECT x.crel, x.lrel, l.cols AS legacy
             FROM (VALUES ('public.kan718_games_compat', 'public.games'), ('public.kan718_meetups_compat', 'public.meetups')) x(crel, lrel)
             JOIN kan783_pre.shape l ON l.rel = x.lrel LOOP
    v := pg_temp.k783_shape(r.crel::regclass);
    INSERT INTO k783_result VALUES ('SHP2', r.crel || ' shape = legacy ' || r.lrel, v IS NOT DISTINCT FROM r.legacy,
      CASE WHEN v IS DISTINCT FROM r.legacy THEN 'compat ' || coalesce(v, '<none>') || ' legacy ' || r.legacy ELSE 'names, order, types equal' END);
  END LOOP;
  -- SHP4
  SELECT count(*), count(*) FILTER (WHERE NOT EXISTS (
           SELECT 1 FROM pg_proc p WHERE p.pronamespace = 'public'::regnamespace AND p.proname = c.fn
              AND pg_get_function_identity_arguments(p.oid) = c.args AND pg_get_function_result(p.oid) = c.result))
    INTO n, m FROM kan783_pre.rpc c;
  INSERT INTO k783_result VALUES ('SHP4', 'rpc_* identity args + result type = capture', m = 0,
    m || ' of ' || n || ' differ' || coalesce(': ' || (SELECT string_agg(c.fn || '(' || c.args || ')', ', ') FROM kan783_pre.rpc c WHERE NOT EXISTS (
      SELECT 1 FROM pg_proc p WHERE p.pronamespace = 'public'::regnamespace AND p.proname = c.fn
         AND pg_get_function_identity_arguments(p.oid) = c.args AND pg_get_function_result(p.oid) = c.result)), ''));
  -- CNT1
  SELECT count(*) INTO g FROM public.games; SELECT count(*) INTO m FROM public.meetups; SELECT count(*) INTO e FROM public.events;
  INSERT INTO k783_result VALUES ('CNT1', 'events = games + meetups', e = g + m, format('events %s games %s meetups %s', e, g, m));
  -- CNT2 / CNT3
  FOR r IN SELECT * FROM kan783_pre.counts LOOP
    EXECUTE format('SELECT count(*), count(DISTINCT id) FROM public.%I', r.tbl) INTO n, m;
    INSERT INTO k783_result VALUES ('CNT2', r.tbl || ' ids not doubled', n = m, format('rows %s distinct ids %s', n, m));
    INSERT INTO k783_result VALUES ('CNT3', r.tbl || ' count = legacy capture', n = r.n, format('now %s captured %s', n, r.n));
  END LOOP;
  -- SEED
  INSERT INTO k783_result SELECT 'SEED', 'seeded game + meetup present once',
    (SELECT count(*) FROM public.events WHERE id IN ('78100000-0000-0000-0000-000000000001', '78100000-0000-0000-0000-00000000f001')) = 2
    AND (SELECT count(*) FROM public.games WHERE id = '78100000-0000-0000-0000-000000000001' AND event_id = id) = 1
    AND (SELECT count(*) FROM public.meetups WHERE id = '78100000-0000-0000-0000-00000000f001' AND event_id = id) = 1
    AND (SELECT count(*) FROM public.kan718_games_compat WHERE id = '78100000-0000-0000-0000-000000000001') = 1
    AND (SELECT count(*) FROM public.kan718_meetups_compat WHERE id = '78100000-0000-0000-0000-00000000f001') = 1,
    'events, games, meetups, both compat views';
  -- VIS
  FOR r IN SELECT p.who, p.src, p.ids AS was, pg_temp.k783_visible(w.role, w.uid, p.src) AS now
             FROM kan783_pre.visible p JOIN k783_who w ON w.label = p.who LOOP
    INSERT INTO k783_result VALUES ('VIS', r.who || ' via ' || r.src, r.now IS NOT DISTINCT FROM r.was,
      CASE WHEN r.now IS DISTINCT FROM r.was THEN 'now ' || left(r.now, 120) || ' captured ' || left(r.was, 120) ELSE split_part(r.now, ':', 1) || ' rows, same ids' END);
  END LOOP;
  -- WRT (rolled back with everything else)
  BEGIN
    UPDATE public.events SET title = 'KAN-783 rollback probe' WHERE id = '78100000-0000-0000-0000-000000000001';
    SELECT title INTO v FROM public.kan718_games_compat WHERE id = '78100000-0000-0000-0000-000000000001';
    INSERT INTO k783_result VALUES ('WRT', 'events edit visible through compat inside the transaction', v = 'KAN-783 rollback probe', 'compat title ' || coalesce(v, '<null>'));
  EXCEPTION WHEN OTHERS THEN
    INSERT INTO k783_result VALUES ('WRT', 'events edit visible through compat inside the transaction', false, 'ERR ' || SQLSTATE || ' ' || SQLERRM);
  END;
  FOR r IN SELECT * FROM k783_result ORDER BY sec, name LOOP
    RAISE NOTICE 'KAN-783 % % % (%)', CASE WHEN r.ok THEN 'PASS' ELSE 'FAIL' END, r.sec, r.name, r.detail;
  END LOOP;
END $chk$;

SELECT count(*) FILTER (WHERE NOT ok) AS k783_nfail, count(*) AS k783_nchk,
       coalesce(string_agg(sec || ' ' || name, '; ') FILTER (WHERE NOT ok), '') AS k783_fails
  FROM k783_result \gset
ROLLBACK;

-- R: after ROLLBACK
CREATE TEMP TABLE k783_after AS SELECT :k783_nfail::int AS nfail, :k783_nchk::int AS nchk, :'k783_fails'::text AS fails;
DO $r$
DECLARE fp_b text := (SELECT fp FROM k783_fp_before); fp_a text := pg_temp.k783_fp(); a record := (SELECT x FROM k783_after x);
        t text; bad text := ''; r record; n bigint; probe int; z01 text;
BEGIN
  IF fp_a IS DISTINCT FROM fp_b THEN bad := bad || 'R data md5 changed (' || fp_b || ' -> ' || fp_a || '); '; END IF;
  SELECT count(*) INTO probe FROM public.events WHERE title = 'KAN-783 rollback probe';
  IF probe <> 0 THEN bad := bad || 'R the WRT edit survived the ROLLBACK; '; END IF;
  FOR r IN SELECT * FROM kan783_pre.counts LOOP
    EXECUTE format('SELECT count(*) FROM public.%I', r.tbl) INTO n;
    IF n <> r.n THEN bad := bad || format('R %s re-count %s <> captured %s; ', r.tbl, n, r.n); END IF;
  END LOOP;
  RAISE NOTICE 'KAN-783 % R after ROLLBACK: data md5 equal to before BEGIN, WRT edit gone, re-counts equal capture (%)',
    CASE WHEN bad = '' THEN 'PASS' ELSE 'FAIL' END, fp_a;
  z01 := CASE WHEN (SELECT games_title_present FROM k783_state) THEN 'pre-Z01' ELSE 'post-Z01' END;
  IF a.nfail > 0 OR bad <> '' THEN
    RAISE EXCEPTION 'KAN-783 Z06 REPORT CHECK FAIL (%): % of % check(s) failed: % %', z01, a.nfail + (bad <> '')::int, a.nchk + 1, a.fails, bad;
  END IF;
  RAISE NOTICE 'KAN-783 Z06 REPORT CHECK PASS (%): % checks + R', z01, a.nchk;
END $r$;
\endif
