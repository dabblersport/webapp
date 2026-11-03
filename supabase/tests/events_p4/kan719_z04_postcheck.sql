-- KAN-781 (KAN-719 Z04, Epic KAN-708): post-removal smoke, per-field / per-row coverage audit and shared-source scan.
-- Authored to run AFTER the phase-4 removal (supabase/migrations/20261105100000_kan719_z01_remove_replaced_columns.sql).
--
-- LOCAL OR DISPOSABLE DATABASES ONLY. Never run this against a hosted Supabase project (the guard refuses).
--
-- TWO MODES.
--   -v capture=1  BEFORE Z01. Writes the pre-removal capture: schema kan719_pre (full copies of games, meetups,
--                 events; per-caller visible id sets; realtime publication list; v_meetup_list count). This is the
--                 stand-in for the E10 backup / KAN718_RUNBOOK.md R2.0 capture, taken under the same lock as Z01.
--                 It is the ONLY write this file makes, and it is the input to section C.
--   (default)     AFTER Z01. Read-and-rollback: every check runs inside BEGIN ... ROLLBACK. R proves afterwards
--                 that the catalogue and data md5 are identical to before the run.
--
-- SECTIONS (check mode). Each records PASS / FAIL / HELD lines in k781_result; the run raises once at the end,
-- listing every FAIL. HELD = an item Z01 deliberately leaves in place (the three homeless meetups columns,
-- manifest 704/722/723, held by Z01 gate G6); it is reported and never counted as removed.
--   S0  no removed column exists: every 600/700 manifest column (derived as D06 derives it, from the capture) is absent from
--       games/meetups, except HELD ones; games keeps exactly its 13 retained columns, meetups its 6 (+ HELD)
--   C1  per row: every captured games/meetups row still exists with the same id and event_id = id; its events
--       parent exists exactly once with the matching event_type; counts equal (no row lost, none doubled);
--       events = games + meetups
--   C2  per field: for every removed column, every captured row's value equals its events value (rsvp_policy ->
--       events.join_policy; skill cast to the captured type). NULLs, ids and the original created_at/updated_at
--       are covered by the same equality. A removed column with no events counterpart is a FAIL (data lost)
--   C3  retained subtype columns byte-identical to the capture
--   M1  old-client compatibility (KAN-773 D05): kan718_games_compat / kan718_meetups_compat exist, have the
--       captured legacy column names, order and types, one row per legacy row, and each row equals the captured
--       legacy row (search_tsv included)
--   M2  visibility: owner, stranger, blocked user, anon and service_role see exactly the captured id sets through
--       the compat projections and through games/meetups themselves (nothing extra, nothing missing)
--   M3  write contract: an events UPDATE works (KAN-776 F1: trg_zz_kan712_events_compat_mirror gone), and the
--       authorised write path kan712_update_event_shared (service_role) completes. A schema-class error or the
--       55000 kan712_not_cut_over refusal is a FAIL (KAN-776 F5)
--   M4  join paths: rpc_join_game and rpc_meetup_rsvp as a non-host member and as a stranger, plus game_slots_left
--       and v_meetup_list (count = captured). PASS = the path completes or returns a business refusal. FAIL = a
--       schema-class error (42703 undefined column, 42P01, 42883, 42702) or 55000
--   M5  route ids: compat ids = captured ids = games/meetups ids = their events ids
--   S1  exact dependencies: no view, rule, policy, index, constraint, default, statistic or publication column
--       list depends on a games/meetups column outside the retained list (except HELD columns)
--   S2  functions (textual, conservative): every public plpgsql/sql function whose body reads games/meetups
--       through a name or alias and then names a removed column of that table (alias.col / table.col), or
--       INSERTs/UPDATEs one. LIVE (EXECUTE granted to anon/authenticated/service_role, or attached to a trigger)
--       = FAIL; ORPHAN (no grant, no trigger) = reported, not failed
--   S3  SQL-language functions (exact): each body is re-validated from pg_get_functiondef with
--       check_function_bodies on, inside a savepoint; 42703 on a games/meetups column = FAIL
--   S4  triggers left on games/meetups whose function reads NEW./OLD.<removed column>; policy expressions on any
--       table naming games/meetups and a removed column; column defaults reading a removed column
--   S5  shared facts only in events: games/meetups share no column with events except id; the compat projections
--       are not writable (pg_relation_is_updatable = 0, no INSTEAD OF trigger, no rule); realtime lists games (id)
--       and meetups (id, vibe_key) and still holds every other table it held at capture (KAN-776 F2)
--   R   after ROLLBACK: catalogue + data md5 identical to before the run
--
-- Run (repository root; the throwaway chain is built by clean781.sh, see KAN719_POSTCHECK.md):
--   psql -X -h <socket> -p <port> -U postgres -d k781... -v ON_ERROR_STOP=1 -P pager=off -v capture=1 -f supabase/tests/events_p4/kan719_z04_postcheck.sql
--   ... apply Z01 ...
--   psql -X -h <socket> -p <port> -U postgres -d k781... -v ON_ERROR_STOP=1 -P pager=off -f supabase/tests/events_p4/kan719_z04_postcheck.sql
\set ON_ERROR_STOP 1
SET client_min_messages = notice;

DO $g$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'supabase_admin')
     OR EXISTS (SELECT 1 FROM pg_namespace WHERE nspname IN ('storage', 'realtime', 'supabase_functions')) THEN
    RAISE EXCEPTION 'KAN-781: this looks like a Supabase database; local or disposable database only';
  END IF;
  IF current_database() !~ '^(k781|kan781)' THEN
    RAISE EXCEPTION 'KAN-781: database % is not a KAN-781 throwaway database; refusing', current_database();
  END IF;
  IF NOT (SELECT rolsuper FROM pg_roles WHERE rolname = current_user) THEN RAISE EXCEPTION 'KAN-781: run as a superuser'; END IF;
END $g$;

-- p_sql (returning one text) as an API role. p_uid NULL = no sub claim. Any error becomes 'ERR <sqlstate> <message>'.
CREATE FUNCTION pg_temp.k781_as(p_role text, p_uid uuid, p_sql text) RETURNS text LANGUAGE plpgsql AS $f$
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
GRANT EXECUTE ON FUNCTION pg_temp.k781_as(text, uuid, text) TO anon, authenticated, service_role;

CREATE TEMP TABLE k781_who(label text, role text, uid uuid);
INSERT INTO k781_who VALUES
  ('owner', 'authenticated', '00000000-0000-0000-0000-0000000000a1'),
  ('stranger', 'authenticated', '00000000-0000-0000-0000-00000000dead'),
  ('blocked', 'authenticated', '00000000-0000-0000-0000-0000000000a6'),
  ('anon', 'anon', NULL),
  ('service_role', 'service_role', NULL);
GRANT SELECT ON k781_who TO anon, authenticated, service_role;

\if :{?capture}
-- ===================================== CAPTURE (before Z01) =====================================
DO $c$ BEGIN
  IF to_regnamespace('kan719_pre') IS NOT NULL THEN RAISE EXCEPTION 'KAN-781 CAPTURE: kan719_pre already exists; one capture per removal'; END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'public.games'::regclass AND attname = 'title' AND NOT attisdropped) THEN
    RAISE EXCEPTION 'KAN-781 CAPTURE: games.title is already gone; the capture must be taken BEFORE Z01';
  END IF;
END $c$;
BEGIN;
SET LOCAL lock_timeout = '10s';
LOCK TABLE public.events, public.games, public.meetups IN SHARE ROW EXCLUSIVE MODE;
CREATE SCHEMA kan719_pre;
REVOKE ALL ON SCHEMA kan719_pre FROM PUBLIC;
CREATE TABLE kan719_pre.games   AS SELECT * FROM public.games;
CREATE TABLE kan719_pre.meetups AS SELECT * FROM public.meetups;
CREATE TABLE kan719_pre.events  AS SELECT * FROM public.events;
CREATE TABLE kan719_pre.visible(who text, tbl text, ids text);
CREATE TABLE kan719_pre.pub AS SELECT schemaname, tablename FROM pg_publication_tables WHERE pubname = 'supabase_realtime';
CREATE TABLE kan719_pre.meta AS SELECT now() AS captured_at, (SELECT count(*) FROM public.v_meetup_list) AS n_v_meetup_list;
DO $v$ DECLARE w record; t text; BEGIN
  FOR w IN SELECT * FROM k781_who LOOP FOREACH t IN ARRAY ARRAY['games', 'meetups'] LOOP
    INSERT INTO kan719_pre.visible VALUES (w.label, t, pg_temp.k781_as(w.role, w.uid,
      format('SELECT count(*) || '':'' || coalesce(md5(string_agg(id::text, '','' ORDER BY id)), ''-'') FROM public.%I', t)));
  END LOOP; END LOOP;
  IF EXISTS (SELECT 1 FROM kan719_pre.visible WHERE ids LIKE 'ERR %') THEN
    RAISE EXCEPTION 'KAN-781 CAPTURE: a caller could not read games/meetups: %', (SELECT string_agg(who || ' ' || tbl || ' ' || ids, '; ') FROM kan719_pre.visible WHERE ids LIKE 'ERR %');
  END IF;
  RAISE NOTICE 'KAN-781 CAPTURE: games %, meetups %, events %; % visibility rows; % realtime tables', (SELECT count(*) FROM kan719_pre.games),
    (SELECT count(*) FROM kan719_pre.meetups), (SELECT count(*) FROM kan719_pre.events), (SELECT count(*) FROM kan719_pre.visible), (SELECT count(*) FROM kan719_pre.pub);
END $v$;
COMMIT;
\else
-- ===================================== CHECK (after Z01) =====================================
DO $pre$ BEGIN
  IF to_regclass('kan719_pre.games') IS NULL OR to_regclass('kan719_pre.meetups') IS NULL OR to_regclass('kan719_pre.visible') IS NULL THEN
    RAISE EXCEPTION 'KAN-781: no pre-removal capture (kan719_pre); section C cannot be proven. Run with -v capture=1 before Z01';
  END IF;
END $pre$;

-- The D06 manifest (k774_retained + k774_manifest), loaded from its only source.
\set mansql `sed -n '/^CREATE TEMP TABLE k774_retained/,/^-- M1-M5/p' supabase/tests/events_p4/kan718_d06_manifest_check.sql`
:mansql

CREATE TEMP TABLE k781_fpq(q text);
INSERT INTO k781_fpq VALUES ($q$SELECT md5(concat_ws('#',
 (SELECT string_agg(p.oid::regprocedure::text || md5(pg_get_functiondef(p.oid)) || coalesce(p.proacl::text, ''), '|' ORDER BY p.oid::regprocedure::text)
    FROM pg_proc p WHERE p.pronamespace = 'public'::regnamespace AND p.prokind = 'f'),
 (SELECT string_agg(attrelid::regclass::text || '.' || attname || attnum || format_type(atttypid, atttypmod) || attnotnull, ',' ORDER BY attrelid::regclass::text, attnum)
    FROM pg_attribute a JOIN pg_class c ON c.oid = a.attrelid WHERE c.relnamespace IN ('public'::regnamespace, 'kan719_pre'::regnamespace) AND c.relkind IN ('r', 'v') AND attnum > 0 AND NOT attisdropped),
 (SELECT string_agg(tgrelid::regclass::text || tgname || tgenabled::text || pg_get_triggerdef(oid), ',' ORDER BY tgrelid::regclass::text, tgname) FROM pg_trigger WHERE NOT tgisinternal),
 (SELECT string_agg(conrelid::regclass::text || conname || pg_get_constraintdef(oid), ',' ORDER BY conrelid::regclass::text, conname) FROM pg_constraint WHERE connamespace = 'public'::regnamespace),
 (SELECT string_agg(polname || coalesce(pg_get_expr(polqual, polrelid), '') || coalesce(pg_get_expr(polwithcheck, polrelid), ''), ',' ORDER BY polrelid::regclass::text, polname) FROM pg_policy),
 (SELECT string_agg(prrelid::regclass::text || coalesce(prattrs::text, '*'), ',' ORDER BY prrelid::regclass::text) FROM pg_publication_rel),
 (SELECT string_agg(relname || relkind::text, ',' ORDER BY relname) FROM pg_class WHERE relnamespace = 'public'::regnamespace))) || ' '
 || (SELECT md5(string_agg(t::text, '|' ORDER BY t.id)) FROM public.games t) || ' ' || (SELECT md5(string_agg(t::text, '|' ORDER BY t.id)) FROM public.meetups t)
 || ' ' || (SELECT md5(string_agg(t::text, '|' ORDER BY t.id)) FROM public.events t) || ' ' || (SELECT md5(string_agg(t::text, '|' ORDER BY t.id)) FROM kan719_pre.games t)$q$);
CREATE TEMP TABLE k781_fp(phase text, v text);
DO $f$ DECLARE v text; BEGIN EXECUTE (SELECT q FROM k781_fpq) INTO v; INSERT INTO k781_fp VALUES ('before', v); END $f$;

CREATE TEMP TABLE k781_result(sec text, verdict text, detail text);
GRANT INSERT, SELECT ON k781_result TO anon, authenticated, service_role;

BEGIN;
SET CONSTRAINTS ALL IMMEDIATE;

-- Removed / held sets. D06 derives its 600/700 column entries from the LIVE catalogue (columns not retained), so
-- after Z01 it sees only what is left; the same derivation is applied here to the CAPTURE (seq = 600/700 + attnum
-- order, HARD = no events home: description, location_name, is_indoor, exactly as D06), then split by what the
-- catalogue holds now.
CREATE TEMP TABLE k781_mcol AS
  SELECT CASE v.t WHEN 'games' THEN 600 ELSE 700 END + row_number() OVER (PARTITION BY v.t ORDER BY a.attnum) AS seq, v.t AS tbl, a.attname::text AS col,
         a.attname IN ('description', 'location_name', 'is_indoor') AS hard,
         EXISTS (SELECT 1 FROM pg_attribute n WHERE n.attrelid = ('public.' || v.t)::regclass AND n.attname = a.attname AND NOT n.attisdropped) AS present
    FROM (VALUES ('games'), ('meetups')) v(t)
    JOIN pg_attribute a ON a.attrelid = ('kan719_pre.' || v.t)::regclass AND a.attnum > 0 AND NOT a.attisdropped
   WHERE NOT EXISTS (SELECT 1 FROM k774_retained r WHERE r.tbl = v.t AND r.col = a.attname);
CREATE TEMP TABLE k781_removed AS SELECT tbl, col FROM k781_mcol WHERE NOT present;
CREATE TEMP TABLE k781_held AS SELECT tbl, col FROM k781_mcol WHERE present AND hard;

-- S0
DO $s0$ DECLARE x text; BEGIN
  INSERT INTO k781_result SELECT 'S0', 'HELD', format('%s.%s still present (manifest %s, HARD: homeless column, Z01 gate G6)', tbl, col, seq)
    FROM k781_mcol WHERE present AND hard;
  SELECT string_agg(tbl || '.' || col, ', ' ORDER BY seq) INTO x FROM k781_mcol WHERE present AND NOT hard;
  IF x IS NOT NULL THEN
    INSERT INTO k781_result VALUES ('S0', 'FAIL', format('%s removed-set columns still exist (Z01 not applied?): %s', (SELECT count(*) FROM k781_mcol WHERE present AND NOT hard), left(x, 300)));
  END IF;
  SELECT string_agg(a.attrelid::regclass || '.' || a.attname, ', ') INTO x FROM pg_attribute a
   WHERE a.attrelid IN ('public.games'::regclass, 'public.meetups'::regclass) AND a.attnum > 0 AND NOT a.attisdropped
     AND NOT EXISTS (SELECT 1 FROM k774_retained r WHERE r.tbl = a.attrelid::regclass::text AND r.col = a.attname)
     AND NOT EXISTS (SELECT 1 FROM k781_mcol m WHERE m.tbl = a.attrelid::regclass::text AND m.col = a.attname);
  IF x IS NOT NULL THEN INSERT INTO k781_result VALUES ('S0', 'FAIL', 'columns outside both the retained list and the manifest: ' || x); END IF;
  SELECT string_agg(r.tbl || '.' || r.col, ', ') INTO x FROM k774_retained r
   WHERE NOT EXISTS (SELECT 1 FROM pg_attribute a WHERE a.attrelid = ('public.' || r.tbl)::regclass AND a.attname = r.col AND NOT a.attisdropped);
  IF x IS NOT NULL THEN INSERT INTO k781_result VALUES ('S0', 'FAIL', 'retained columns missing: ' || x); END IF;
  IF NOT EXISTS (SELECT 1 FROM k781_result WHERE sec = 'S0' AND verdict = 'FAIL') THEN
    INSERT INTO k781_result VALUES ('S0', 'PASS', format('%s manifest columns removed (games %s, meetups %s); games keeps its %s retained, meetups its %s retained + %s held',
      (SELECT count(*) FROM k781_removed), (SELECT count(*) FROM k781_removed WHERE tbl = 'games'), (SELECT count(*) FROM k781_removed WHERE tbl = 'meetups'),
      (SELECT count(*) FROM k774_retained WHERE tbl = 'games'), (SELECT count(*) FROM k774_retained WHERE tbl = 'meetups'), (SELECT count(*) FROM k781_held)));
  END IF;
END $s0$;

-- C1 per row
DO $c1$ DECLARE t text; et text; n_pre bigint; n_now bigint; n_ev bigint; bad bigint; dup bigint; BEGIN
  FOREACH t IN ARRAY ARRAY['games', 'meetups'] LOOP
    et := CASE t WHEN 'games' THEN 'game' ELSE 'meetup' END;
    EXECUTE format('SELECT count(*) FROM kan719_pre.%I', t) INTO n_pre;
    EXECUTE format('SELECT count(*) FROM public.%I', t) INTO n_now;
    EXECUTE format('SELECT count(*) FROM public.events WHERE event_type = %L', et) INTO n_ev;
    EXECUTE format($q$SELECT count(*) FROM kan719_pre.%1$I p
       WHERE p.event_id IS DISTINCT FROM p.id
          OR NOT EXISTS (SELECT 1 FROM public.%1$I s WHERE s.id = p.id AND s.event_id = p.id)
          OR (SELECT count(*) FROM public.events e WHERE e.id = p.id AND e.event_type = %2$L) <> 1$q$, t, et) INTO bad;
    EXECUTE format('SELECT count(*) FROM (SELECT id FROM public.%I GROUP BY id HAVING count(*) > 1) d', t) INTO dup;
    IF n_pre <> n_now OR n_now <> n_ev OR bad > 0 OR dup > 0 THEN
      INSERT INTO k781_result VALUES ('C1', 'FAIL', format('%s: captured %s, now %s, events(%s) %s, rows without own parent/id %s, doubled ids %s', t, n_pre, n_now, et, n_ev, bad, dup));
    ELSE
      INSERT INTO k781_result VALUES ('C1', 'PASS', format('%s: %s captured rows = %s now = %s events(%s); every row keeps id, event_id = id and exactly one parent', t, n_pre, n_now, n_ev, et));
    END IF;
  END LOOP;
  IF (SELECT count(*) FROM public.events) <> (SELECT count(*) FROM public.games) + (SELECT count(*) FROM public.meetups) THEN
    INSERT INTO k781_result VALUES ('C1', 'FAIL', 'events count <> games + meetups');
  END IF;
END $c1$;

-- C2 per field
DO $c2$ DECLARE r record; ecol text; ptype text; n bigint; nn bigint; bad bigint; ok_cols int := 0; rows_cmp bigint := 0; BEGIN
  FOR r IN SELECT m.tbl, m.col FROM k781_mcol m WHERE NOT m.present ORDER BY m.seq LOOP
    ecol := CASE WHEN r.tbl = 'meetups' AND r.col = 'rsvp_policy' THEN 'join_policy' ELSE r.col END;
    SELECT format_type(a.atttypid, a.atttypmod) INTO ptype FROM pg_attribute a WHERE a.attrelid = ('kan719_pre.' || r.tbl)::regclass AND a.attname = r.col;
    IF ptype IS NULL THEN INSERT INTO k781_result VALUES ('C2', 'FAIL', format('%s.%s is not in the capture', r.tbl, r.col)); CONTINUE; END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'public.events'::regclass AND attname = ecol AND NOT attisdropped) THEN
      INSERT INTO k781_result VALUES ('C2', 'FAIL', format('%s.%s was removed but events has no %s: its data is lost', r.tbl, r.col, ecol)); CONTINUE;
    END IF;
    EXECUTE format('SELECT count(*), count(p.%2$I), count(*) FILTER (WHERE p.%2$I IS DISTINCT FROM e.%3$I::%4$s)
                      FROM kan719_pre.%1$I p LEFT JOIN public.events e ON e.id = p.event_id', r.tbl, r.col, ecol, ptype) INTO n, nn, bad;
    rows_cmp := rows_cmp + n;
    IF bad > 0 THEN
      INSERT INTO k781_result VALUES ('C2', 'FAIL', format('%s.%s: %s of %s rows differ from (or lack) events.%s', r.tbl, r.col, bad, n, ecol));
    ELSE ok_cols := ok_cols + 1; END IF;
  END LOOP;
  IF NOT EXISTS (SELECT 1 FROM k781_result WHERE sec = 'C2' AND verdict = 'FAIL') THEN
    INSERT INTO k781_result VALUES ('C2', 'PASS', format('%s removed columns x their rows (%s cells): every captured value equals its events value, NULLs, timestamps (created_at/updated_at) and enums included',
      ok_cols, rows_cmp));
  END IF;
END $c2$;

-- C3 retained columns
DO $c3$ DECLARE t text; cols text; a text; b text; BEGIN
  FOREACH t IN ARRAY ARRAY['games', 'meetups'] LOOP
    SELECT string_agg(quote_ident(col), ', ' ORDER BY col) INTO cols FROM k774_retained WHERE tbl = t;
    EXECUTE format('SELECT md5(string_agg(row(%s)::text, ''|'' ORDER BY id)) FROM kan719_pre.%I', cols, t) INTO a;
    EXECUTE format('SELECT md5(string_agg(row(%s)::text, ''|'' ORDER BY id)) FROM public.%I', cols, t) INTO b;
    INSERT INTO k781_result VALUES ('C3', CASE WHEN a = b THEN 'PASS' ELSE 'FAIL' END, format('%s retained columns: capture %s, now %s', t, left(a, 8), left(b, 8)));
  END LOOP;
END $c3$;

-- M1 compat projections
DO $m1$ DECLARE t text; v text; a text; b text; n_v bigint; n_p bigint; bad bigint; BEGIN
  FOREACH t IN ARRAY ARRAY['games', 'meetups'] LOOP
    v := 'kan718_' || t || '_compat';
    IF to_regclass('public.' || v) IS NULL THEN INSERT INTO k781_result VALUES ('M1', 'FAIL', format('public.%s does not exist (KAN-773 D05 not applied)', v)); CONTINUE; END IF;
    SELECT string_agg(attname || ':' || format_type(atttypid, atttypmod), ',' ORDER BY attnum) INTO a FROM pg_attribute WHERE attrelid = ('kan719_pre.' || t)::regclass AND attnum > 0;
    SELECT string_agg(attname || ':' || format_type(atttypid, atttypmod), ',' ORDER BY attnum) INTO b FROM pg_attribute WHERE attrelid = ('public.' || v)::regclass AND attnum > 0;
    EXECUTE format('SELECT count(*) FROM public.%I', v) INTO n_v;
    EXECUTE format('SELECT count(*) FROM kan719_pre.%I', t) INTO n_p;
    IF a IS DISTINCT FROM b THEN INSERT INTO k781_result VALUES ('M1', 'FAIL', format('%s shape differs from the captured legacy %s', v, t)); CONTINUE; END IF;
    EXECUTE format('SELECT count(*) FROM kan719_pre.%1$I p FULL JOIN public.%2$I c ON c.id = p.id WHERE c.id IS NULL OR p.id IS NULL OR to_jsonb(c) IS DISTINCT FROM to_jsonb(p)', t, v) INTO bad;
    IF bad > 0 THEN
      a := NULL;
      DECLARE c record; nd bigint; BEGIN
        FOR c IN SELECT attname FROM pg_attribute WHERE attrelid = ('public.' || v)::regclass AND attnum > 0 ORDER BY attnum LOOP
          EXECUTE format('SELECT count(*) FROM kan719_pre.%1$I p JOIN public.%2$I c ON c.id = p.id WHERE c.%3$I IS DISTINCT FROM p.%3$I', t, v, c.attname) INTO nd;
          IF nd > 0 THEN a := concat_ws(', ', a, c.attname || ' (' || nd || ' rows)'); END IF;
        END LOOP;
      END;
    END IF;
    INSERT INTO k781_result VALUES ('M1', CASE WHEN bad = 0 AND n_v = n_p THEN 'PASS' ELSE 'FAIL' END,
      format('%s: legacy shape (%s columns) unchanged; %s rows vs %s captured; %s rows differ from the captured legacy row%s', v, array_length(string_to_array(b, ','), 1), n_v, n_p, bad,
             CASE WHEN bad > 0 THEN ' in: ' || coalesce(a, '?') ELSE '' END));
  END LOOP;
END $m1$;

-- M2 visibility
DO $m2$ DECLARE w record; t text; got text; got_t text; want text; ok int := 0; BEGIN
  FOR w IN SELECT * FROM k781_who LOOP FOREACH t IN ARRAY ARRAY['games', 'meetups'] LOOP
    want := (SELECT ids FROM kan719_pre.visible WHERE who = w.label AND tbl = t);
    got := CASE WHEN to_regclass('public.kan718_' || t || '_compat') IS NULL THEN 'ERR no projection' ELSE pg_temp.k781_as(w.role, w.uid,
      format('SELECT count(*) || '':'' || coalesce(md5(string_agg(id::text, '','' ORDER BY id)), ''-'') FROM public.%I', 'kan718_' || t || '_compat')) END;
    got_t := pg_temp.k781_as(w.role, w.uid, format('SELECT count(*) || '':'' || coalesce(md5(string_agg(id::text, '','' ORDER BY id)), ''-'') FROM public.%I', t));
    IF got IS DISTINCT FROM want OR got_t IS DISTINCT FROM want THEN
      INSERT INTO k781_result VALUES ('M2', 'FAIL', format('%s on %s: captured %s, projection %s, table %s', w.label, t, want, left(got, 80), left(got_t, 80)));
    ELSE ok := ok + 1; END IF;
  END LOOP; END LOOP;
  IF ok = 10 THEN INSERT INTO k781_result VALUES ('M2', 'PASS', format('5 callers x 2 tables: projection and table id sets equal the capture (%s)',
    (SELECT string_agg(who || ' ' || tbl || '=' || split_part(ids, ':', 1), ', ' ORDER BY who, tbl) FROM kan719_pre.visible))); END IF;
END $m2$;

-- M3 / M4 smoke. Targets: the newest captured game and meetup (clean781.sh seeds one of each before the capture).
CREATE TEMP TABLE k781_tgt AS SELECT
  (SELECT id FROM kan719_pre.games ORDER BY created_at DESC, id LIMIT 1) AS g,
  (SELECT id FROM kan719_pre.meetups ORDER BY created_at DESC, id LIMIT 1) AS m;
CREATE TEMP TABLE k781_smoke(sec text, name text, role text, uid uuid, sql text, res text);
INSERT INTO k781_smoke(sec, name, role, uid, sql) SELECT s.sec, s.name, s.role, s.uid::uuid, format(s.sql, t.g, t.m) FROM k781_tgt t, (VALUES
  ('M3', 'events UPDATE (F1)', 'postgres', NULL, $s$WITH u AS (UPDATE public.events SET title = title WHERE id IN (%1$L, %2$L) RETURNING 1) SELECT count(*)::text FROM u$s$),
  ('M3', 'kan712_update_event_shared game (service_role)', 'service_role', NULL, $s$SELECT public.kan712_update_event_shared(%1$L, '{"title": "KAN-781 smoke game"}')::text$s$),
  ('M3', 'kan712_update_event_shared meetup (service_role)', 'service_role', NULL, $s$SELECT public.kan712_update_event_shared(%2$L, '{"title": "KAN-781 smoke meetup"}')::text$s$),
  ('M4', 'rpc_join_game member', 'authenticated', '00000000-0000-0000-0000-0000000000a2', $s$SELECT row_to_json(r)::text FROM public.rpc_join_game('player', %1$L) r$s$),
  ('M4', 'rpc_join_game stranger', 'authenticated', '00000000-0000-0000-0000-00000000dead', $s$SELECT row_to_json(r)::text FROM public.rpc_join_game('player', %1$L) r$s$),
  ('M4', 'rpc_meetup_rsvp member going', 'authenticated', '00000000-0000-0000-0000-0000000000a2', $s$SELECT public.rpc_meetup_rsvp(%2$L, 'going', NULL, NULL)::text$s$),
  ('M4', 'rpc_meetup_rsvp stranger going', 'authenticated', '00000000-0000-0000-0000-00000000dead', $s$SELECT public.rpc_meetup_rsvp(%2$L, 'going', NULL, NULL)::text$s$),
  ('M4', 'game_slots_left', 'authenticated', '00000000-0000-0000-0000-0000000000a1', $s$SELECT public.game_slots_left(%1$L)::text$s$),
  ('M4', 'v_meetup_list count', 'postgres', NULL, $s$SELECT count(*)::text FROM public.v_meetup_list$s$)
) AS s(sec, name, role, uid, sql);
DO $sm$ DECLARE r record; v_res text; BEGIN
  FOR r IN SELECT * FROM k781_smoke ORDER BY sec, name LOOP
    IF r.role = 'postgres' THEN
      BEGIN EXECUTE r.sql INTO v_res; EXCEPTION WHEN OTHERS THEN v_res := 'ERR ' || SQLSTATE || ' ' || SQLERRM; END;
    ELSE v_res := pg_temp.k781_as(r.role, r.uid, r.sql); END IF;
    UPDATE k781_smoke SET res = v_res WHERE name = r.name;
    INSERT INTO k781_result VALUES (r.sec,
      CASE WHEN v_res ~ '^ERR (42703|42P01|42883|42702|55000|42P10) ' THEN 'FAIL'
           WHEN r.name = 'v_meetup_list count' AND v_res IS DISTINCT FROM (SELECT n_v_meetup_list::text FROM kan719_pre.meta) THEN 'FAIL'
           WHEN r.name = 'events UPDATE (F1)' AND v_res <> '2' THEN 'FAIL'
           ELSE 'PASS' END,
      r.name || ' -> ' || left(v_res, 160));
  END LOOP;
END $sm$;

-- M5 route ids
DO $m5$ DECLARE t text; a text; b text; c text; d text; BEGIN
  FOREACH t IN ARRAY ARRAY['games', 'meetups'] LOOP
    EXECUTE format('SELECT md5(string_agg(id::text, '','' ORDER BY id)) FROM kan719_pre.%I', t) INTO a;
    EXECUTE format('SELECT md5(string_agg(id::text, '','' ORDER BY id)) FROM public.%I', t) INTO b;
    EXECUTE format('SELECT md5(string_agg(event_id::text, '','' ORDER BY event_id)) FROM public.%I', t) INTO c;
    IF to_regclass('public.kan718_' || t || '_compat') IS NOT NULL THEN
      EXECUTE format('SELECT md5(string_agg(id::text, '','' ORDER BY id)) FROM public.%I', 'kan718_' || t || '_compat') INTO d;
    END IF;
    INSERT INTO k781_result VALUES ('M5', CASE WHEN a = b AND b = c AND b = d THEN 'PASS' ELSE 'FAIL' END,
      format('%s ids: capture %s, table %s, event_id %s, projection %s', t, left(a, 8), left(b, 8), left(c, 8), left(coalesce(d, '-'), 8)));
  END LOOP;
END $m5$;

-- S1 exact dependencies on non-retained columns
DO $s1$ DECLARE r record; n int := 0; BEGIN
  FOR r IN
    SELECT DISTINCT d.classid::regclass::text AS cls, pg_describe_object(d.classid, d.objid, d.objsubid) AS obj, d.refobjid::regclass::text AS tbl, a.attname AS col
      FROM pg_depend d JOIN pg_attribute a ON a.attrelid = d.refobjid AND a.attnum = d.refobjsubid
     WHERE d.refobjid IN ('public.games'::regclass, 'public.meetups'::regclass) AND d.refobjsubid > 0 AND d.deptype <> 'i'
       AND NOT EXISTS (SELECT 1 FROM k774_retained k WHERE k.tbl = d.refobjid::regclass::text AND k.col = a.attname)
       AND NOT (d.classid = 'pg_class'::regclass AND d.objid = d.refobjid)
  LOOP
    n := n + 1;
    INSERT INTO k781_result VALUES ('S1', CASE WHEN EXISTS (SELECT 1 FROM k781_held h WHERE h.tbl = r.tbl AND h.col = r.col) THEN 'HELD' ELSE 'FAIL' END,
      format('%s depends on %s.%s', r.obj, r.tbl, r.col));
  END LOOP;
  IF NOT EXISTS (SELECT 1 FROM k781_result WHERE sec = 'S1' AND verdict = 'FAIL') THEN
    INSERT INTO k781_result VALUES ('S1', 'PASS', format('no view/rule/policy/index/constraint/default/publication depends on a removed column (%s dependencies, all on held columns)', n));
  END IF;
END $s1$;

-- S2 functions (textual)
CREATE TEMP TABLE k781_fn AS
  SELECT p.oid, p.oid::regprocedure::text AS sig, l.lanname,
         regexp_replace(regexp_replace(coalesce(p.prosrc, ''), '/\*([^*]|\*+[^*/])*\*+/', '', 'g'), '--[^\n]*', '', 'g') AS src,
         EXISTS (SELECT 1 FROM pg_trigger t WHERE t.tgfoid = p.oid AND NOT t.tgisinternal) AS has_trg,
         (has_function_privilege('anon', p.oid, 'EXECUTE') OR has_function_privilege('authenticated', p.oid, 'EXECUTE')
          OR has_function_privilege('service_role', p.oid, 'EXECUTE')) AS api
    FROM pg_proc p JOIN pg_language l ON l.oid = p.prolang
   WHERE p.pronamespace = 'public'::regnamespace AND l.lanname IN ('sql', 'plpgsql')
     AND p.proname !~ '^(k7\d\d_ref_|b\d\d_ref_|harness_|k781_)';
CREATE TEMP TABLE k781_alias AS
  SELECT DISTINCT f.oid, lower(m[1]) AS tbl, lower(coalesce(nullif(m[2], ''), m[1])) AS alias
    FROM k781_fn f, regexp_matches(f.src,
      '\m(?:from|join|update|into)\s+(?:only\s+)?(?:public\.)?(games|meetups)\M(?:\s+(?:as\s+)?(?!(?:where|on|set|join|left|right|inner|cross|using|group|order|limit|returning|for|select|values|union|natural|full|lateral|and|or|having|window|except|intersect|offset|fetch|then|end|loop|into)\M)([a-z_][a-z0-9_]*))?', 'gi') m;
CREATE TEMP TABLE k781_hit AS
  SELECT DISTINCT f.sig, f.has_trg, f.api, r.tbl, r.col FROM k781_fn f JOIN k781_alias a ON a.oid = f.oid JOIN k781_removed r ON r.tbl = a.tbl
   WHERE f.src ~* ('\m(' || a.alias || '|' || a.tbl || ')\.' || r.col || '\M')
      OR f.src ~* ('\minsert\s+into\s+(public\.)?' || a.tbl || '\s*\([^)]*\m' || r.col || '\M')
      OR f.src ~* ('\mupdate\s+(only\s+)?(public\.)?' || a.tbl || '\M[^;]*?\mset\M[^;]*?\m' || r.col || '\s*=');
DO $s2$ DECLARE r record; BEGIN
  FOR r IN SELECT sig, has_trg, api, string_agg(tbl || '.' || col, ',' ORDER BY tbl, col) AS cols FROM k781_hit GROUP BY 1, 2, 3 ORDER BY 2 DESC, 3 DESC, 1 LOOP
    INSERT INTO k781_result VALUES ('S2', CASE WHEN r.has_trg OR r.api THEN 'FAIL' ELSE 'ORPHAN' END,
      format('%s [%s] reads removed %s', r.sig, CASE WHEN r.has_trg THEN 'trigger' WHEN r.api THEN 'API-executable' ELSE 'no grant, no trigger' END, r.cols));
  END LOOP;
  IF NOT EXISTS (SELECT 1 FROM k781_result WHERE sec = 'S2') THEN
    INSERT INTO k781_result VALUES ('S2', 'PASS', format('%s public functions scanned (%s read games/meetups): none names a removed column',
      (SELECT count(*) FROM k781_fn), (SELECT count(DISTINCT oid) FROM k781_alias)));
  END IF;
END $s2$;

-- S3 SQL-language functions, re-validated
DO $s3$ DECLARE r record; st text; m text; n int := 0; BEGIN
  SET LOCAL check_function_bodies = on;
  FOR r IN SELECT oid, sig FROM k781_fn WHERE lanname = 'sql' ORDER BY sig LOOP
    n := n + 1;
    BEGIN
      EXECUTE pg_get_functiondef(r.oid);
    EXCEPTION WHEN OTHERS THEN
      GET STACKED DIAGNOSTICS st = RETURNED_SQLSTATE, m = MESSAGE_TEXT;
      -- 42703 = undefined column; 42P01 'missing FROM-clause entry' = a row-typed parameter (games/meetups) read for a
      -- field it no longer has. Any other error (e.g. a relation this harness does not build) is a NOTE, not a finding.
      INSERT INTO k781_result VALUES ('S3', CASE WHEN st = '42703' OR (st = '42P01' AND m ~ 'FROM-clause entry') THEN 'FAIL' ELSE 'NOTE' END, format('%s -> %s %s', r.sig, st, m));
    END;
  END LOOP;
  IF NOT EXISTS (SELECT 1 FROM k781_result WHERE sec = 'S3' AND verdict = 'FAIL') THEN
    INSERT INTO k781_result VALUES ('S3', 'PASS', format('%s SQL-language functions re-validated with check_function_bodies on: no undefined column', n));
  END IF;
END $s3$;

-- S4 triggers on games/meetups, policies, defaults
DO $s4$ DECLARE r record; BEGIN
  FOR r IN SELECT DISTINCT t.tgrelid::regclass::text AS tbl, t.tgname, rm.col FROM pg_trigger t JOIN pg_proc p ON p.oid = t.tgfoid
             JOIN k781_removed rm ON rm.tbl = t.tgrelid::regclass::text
            WHERE t.tgrelid IN ('public.games'::regclass, 'public.meetups'::regclass) AND NOT t.tgisinternal
              AND p.prosrc ~* ('\m(new|old)\.' || rm.col || '\M') LOOP
    INSERT INTO k781_result VALUES ('S4', 'FAIL', format('trigger %s on %s reads NEW/OLD.%s', r.tgname, r.tbl, r.col));
  END LOOP;
  FOR r IN SELECT pol.polrelid::regclass::text AS tbl, pol.polname, rm.tbl AS rtbl, rm.col
             FROM pg_policy pol, k781_removed rm
            WHERE (coalesce(pg_get_expr(pol.polqual, pol.polrelid), '') || ' ' || coalesce(pg_get_expr(pol.polwithcheck, pol.polrelid), '')) ~* ('\m' || rm.tbl || '\M')
              AND (coalesce(pg_get_expr(pol.polqual, pol.polrelid), '') || ' ' || coalesce(pg_get_expr(pol.polwithcheck, pol.polrelid), '')) ~* ('\m[a-z_]+\.' || rm.col || '\M')
              AND NOT (coalesce(pg_get_expr(pol.polqual, pol.polrelid), '') || ' ' || coalesce(pg_get_expr(pol.polwithcheck, pol.polrelid), '')) ~* '\mevents\M' LOOP
    INSERT INTO k781_result VALUES ('S4', 'FAIL', format('policy %s on %s names %s and .%s', r.polname, r.tbl, r.rtbl, r.col));
  END LOOP;
  FOR r IN SELECT ad.adrelid::regclass::text AS tbl, a.attname, pg_get_expr(ad.adbin, ad.adrelid) AS expr FROM pg_attrdef ad
             JOIN pg_attribute a ON a.attrelid = ad.adrelid AND a.attnum = ad.adnum
            WHERE pg_get_expr(ad.adbin, ad.adrelid) ~* '\m(games|meetups)\M' LOOP
    INSERT INTO k781_result VALUES ('S4', 'FAIL', format('default of %s.%s names games/meetups: %s', r.tbl, r.attname, r.expr));
  END LOOP;
  IF NOT EXISTS (SELECT 1 FROM k781_result WHERE sec = 'S4') THEN
    INSERT INTO k781_result VALUES ('S4', 'PASS', format('%s triggers left on games/meetups read no removed NEW/OLD column; no policy or default names one; trg_zz_kan712_events_compat_mirror %s',
      (SELECT count(*) FROM pg_trigger WHERE tgrelid IN ('public.games'::regclass, 'public.meetups'::regclass) AND NOT tgisinternal),
      CASE WHEN EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_zz_kan712_events_compat_mirror') THEN 'STILL PRESENT' ELSE 'gone (F1 handled)' END));
  END IF;
  IF EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_zz_kan712_events_compat_mirror' AND tgenabled <> 'D') AND EXISTS (SELECT 1 FROM k781_removed) THEN
    INSERT INTO k781_result VALUES ('S4', 'FAIL', 'trg_zz_kan712_events_compat_mirror is enabled after removal (KAN-776 F1)');
  END IF;
END $s4$;

-- S5 shared facts only in events
DO $s5$ DECLARE x text; v text; BEGIN
  SELECT string_agg(a.attrelid::regclass || '.' || a.attname, ', ') INTO x FROM pg_attribute a
   WHERE a.attrelid IN ('public.games'::regclass, 'public.meetups'::regclass) AND a.attnum > 0 AND NOT a.attisdropped AND a.attname <> 'id'
     AND EXISTS (SELECT 1 FROM pg_attribute e WHERE e.attrelid = 'public.events'::regclass AND e.attname = CASE a.attname WHEN 'rsvp_policy' THEN 'join_policy' ELSE a.attname END AND NOT e.attisdropped);
  INSERT INTO k781_result VALUES ('S5', CASE WHEN x IS NULL THEN 'PASS' ELSE 'FAIL' END,
    coalesce('subtype columns that duplicate an events fact: ' || x, 'games/meetups share no column with events except id: shared facts live only in events'));
  FOREACH v IN ARRAY ARRAY['kan718_games_compat', 'kan718_meetups_compat'] LOOP
    IF to_regclass('public.' || v) IS NULL THEN CONTINUE; END IF;
    IF pg_relation_is_updatable(('public.' || v)::regclass, true) <> 0
       OR EXISTS (SELECT 1 FROM pg_trigger WHERE tgrelid = ('public.' || v)::regclass)
       OR EXISTS (SELECT 1 FROM pg_rewrite WHERE ev_class = ('public.' || v)::regclass AND rulename <> '_RETURN') THEN
      INSERT INTO k781_result VALUES ('S5', 'FAIL', v || ' is writable: a second write path for shared facts');
    ELSE INSERT INTO k781_result VALUES ('S5', 'PASS', v || ' read-only (not updatable, no INSTEAD OF trigger, no rule)'); END IF;
  END LOOP;
  x := (SELECT string_agg(tablename || coalesce(attnames::text, '*'), ',' ORDER BY tablename) FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND tablename IN ('games', 'meetups'));
  IF EXISTS (SELECT 1 FROM k781_removed) AND x IS DISTINCT FROM 'games{id},meetups{id,vibe_key}' THEN
    INSERT INTO k781_result VALUES ('S5', 'FAIL', 'realtime column lists for games/meetups are ' || coalesce(x, '<absent>') || ', expected games{id},meetups{id,vibe_key}');
  END IF;
  SELECT string_agg(p.schemaname || '.' || p.tablename, ', ') INTO v FROM kan719_pre.pub p
   WHERE NOT EXISTS (SELECT 1 FROM pg_publication_tables n WHERE n.pubname = 'supabase_realtime' AND n.schemaname = p.schemaname AND n.tablename = p.tablename);
  INSERT INTO k781_result VALUES ('S5', CASE WHEN v IS NULL THEN 'PASS' ELSE 'FAIL' END,
    coalesce('realtime lost tables held at capture (KAN-776 F2): ' || v, format('realtime still holds all %s captured tables; games/meetups lists %s (F2 handled)', (SELECT count(*) FROM kan719_pre.pub), coalesce(x, '-'))));
END $s5$;

-- The results leave the transaction as a psql variable; everything else is rolled back.
SELECT coalesce(json_agg(r), '[]')::text AS k781_json FROM k781_result r \gset
ROLLBACK;
CREATE TEMP TABLE k781_final AS SELECT * FROM json_populate_recordset(NULL::k781_result, :'k781_json');

-- R
DO $r$ DECLARE v text; f text; n int; BEGIN
  EXECUTE (SELECT q FROM k781_fpq) INTO v;
  INSERT INTO k781_fp VALUES ('after', v);
  IF v IS DISTINCT FROM (SELECT k781_fp.v FROM k781_fp WHERE phase = 'before') THEN
    INSERT INTO k781_final VALUES ('R', 'FAIL', 'catalogue + data md5 changed by the run');
  ELSE INSERT INTO k781_final VALUES ('R', 'PASS', 'catalogue + data md5 identical after ROLLBACK: ' || left(v, 32)); END IF;
  FOR f IN SELECT format('KAN-781 %s %s: %s', sec, verdict, detail) FROM k781_final
            ORDER BY array_position(ARRAY['S0','C1','C2','C3','M1','M2','M3','M4','M5','S1','S2','S3','S4','S5','R'], sec), verdict, detail LOOP
    RAISE NOTICE '%', f;
  END LOOP;
  n := (SELECT count(*) FROM k781_final WHERE verdict = 'FAIL');
  IF n > 0 THEN
    RAISE EXCEPTION 'KAN-781 POSTCHECK FAIL: % failing check(s) in section(s) %', n,
      (SELECT string_agg(DISTINCT sec, ',') FROM k781_final WHERE verdict = 'FAIL');
  END IF;
  RAISE NOTICE 'KAN-781 POSTCHECK PASS: % checks, % held, % orphan references', (SELECT count(*) FROM k781_final),
    (SELECT count(*) FROM k781_final WHERE verdict = 'HELD'), (SELECT count(*) FROM k781_final WHERE verdict = 'ORPHAN');
END $r$;
\endif
