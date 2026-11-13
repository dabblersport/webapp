-- KAN-775 (KAN-718 D07) SERIES OCCURRENCE UNIQUENESS PROOF. LOCAL THROWAWAY POSTGRES ONLY. NEVER RUN AGAINST SUPABASE.
-- One transaction, ROLLBACK at the end; nothing is committed.
--
-- Build (same chain as events_p2_kan713/local_harness_kan713.sql "Load order"):
--   events_p1/local_harness_kan711.sql, events_p1/local_seed_kan711.sql, events_p2/local_harness_kan712.sql,
--   events_p2_kan713/local_harness_kan713.sql, KAN-710, KAN-711 (+ CALL kan711_events_backfill_run(200) +
--   kan711_events_validate_links()), KAN-712 stage A + B, the two KAN-713 migrations           = OLD
--   OLD + 20261104110300_kan718_d07_series_occurrence_unique.sql                              = NEW
-- Run this SAME file on both:
--   NEW: every probe prints PASS.
--   OLD: every probe tagged [K] prints FAIL (evidence the probe can fail); every [=] probe PASSes on both.
-- Population: the KAN-711 seed (6 games incl. 2 series occurrences of the ended series f1, 6 meetups) + KAN-713's
-- 4 games, plus one future series S (3 occurrences) created here through rpc_create_game_series as user a2.
--
-- Withdrawal of games_series_id_start_at_key is SIMULATED only: DROP INDEX inside a SAVEPOINT of this
-- transaction, rolled back before the end (probe W9 proves the index is back).
-- Each probe: id | PASS/FAIL | expected (LIKE pattern) | actual | name.
\set ON_ERROR_STOP 1
\pset format unaligned
\pset tuples_only on
\pset pager off
BEGIN;
SET LOCAL lock_timeout = '3s';
CREATE TEMP TABLE fx (label text PRIMARY KEY, v text);

-- as_(role, uid, sql, immediate): run sql as role with auth.uid() = uid. With immediate = true, every pending
-- deferred constraint trigger (KAN-710's backstop) is fired inside the probe, i.e. what COMMIT would raise.
-- With immediate = false the statement alone is observed and then undone (its deferred checks never run).
-- Returns the text result, or 'ERR <sqlstate> <message>'. Never raises.
CREATE FUNCTION pg_temp.as_(p_role text, p_uid uuid, p_sql text, p_immediate boolean DEFAULT true) RETURNS text
LANGUAGE plpgsql AS $$
DECLARE v text; s text; m text;
BEGIN
  BEGIN
    PERFORM set_config('request.jwt.claim.sub', coalesce(p_uid::text, ''), true);
    IF p_role IS NOT NULL THEN EXECUTE format('SET LOCAL ROLE %I', p_role); END IF;
    EXECUTE p_sql INTO v;
    IF p_immediate THEN SET CONSTRAINTS ALL IMMEDIATE; END IF;
    RESET ROLE;
    -- statement-only probe: undo its effect (and its still-pending deferred checks) after observing it succeeded
    IF NOT p_immediate THEN RAISE EXCEPTION USING ERRCODE = 'UD000', MESSAGE = coalesce(v, '<null>'); END IF;
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS s = RETURNED_SQLSTATE, m = MESSAGE_TEXT;
    RESET ROLE;
    v := CASE WHEN s = 'UD000' THEN m || ' (statement accepted; undone)' ELSE 'ERR ' || s || ' ' || m END;
  END;
  SET CONSTRAINTS ALL DEFERRED;
  PERFORM set_config('request.jwt.claim.sub', '', true);
  PERFORM set_config('kan712.contract', '', true);
  PERFORM set_config('kan712.routing', '', true);
  PERFORM set_config('kan712.compat', '', true);
  RETURN coalesce(v, '<null>');
END $$;
-- chk prints its line as it runs: a ROLLBACK TO SAVEPOINT would erase rows stored in a table, so tallies live in
-- temp sequences (nextval is not transactional) and survive the savepoints used below.
CREATE TEMP SEQUENCE t_pass; CREATE TEMP SEQUENCE t_fail; CREATE TEMP SEQUENCE t_kfail; CREATE TEMP SEQUENCE t_eqfail;
CREATE FUNCTION pg_temp.chk(p_id text, p_name text, p_expected text, p_actual text) RETURNS text LANGUAGE plpgsql AS $$
DECLARE v_ok boolean := coalesce(p_actual, '<null>') LIKE p_expected;
BEGIN
  IF v_ok THEN PERFORM nextval('t_pass'); ELSE
    PERFORM nextval('t_fail');
    IF p_id LIKE '%[K]%' THEN PERFORM nextval('t_kfail'); ELSE PERFORM nextval('t_eqfail'); END IF;
  END IF;
  RETURN p_id || '|' || CASE WHEN v_ok THEN 'PASS' ELSE 'FAIL' END || '|' || p_expected || '|' || coalesce(p_actual, '<null>') || '|' || p_name;
END $$;
CREATE FUNCTION pg_temp.tally(p text) RETURNS bigint LANGUAGE sql AS $$
  SELECT CASE p WHEN 'pass' THEN (SELECT last_value - CASE WHEN is_called THEN 0 ELSE 1 END FROM t_pass)
                WHEN 'fail' THEN (SELECT last_value - CASE WHEN is_called THEN 0 ELSE 1 END FROM t_fail)
                WHEN 'kfail' THEN (SELECT last_value - CASE WHEN is_called THEN 0 ELSE 1 END FROM t_kfail)
                ELSE (SELECT last_value - CASE WHEN is_called THEN 0 ELSE 1 END FROM t_eqfail) END $$;
CREATE FUNCTION pg_temp.fx(p text) RETURNS text LANGUAGE sql AS $$ SELECT v FROM fx WHERE label = p $$;
-- duplicate (series_id, events.start_at) slots among event-linked series games: the invariant, measured
CREATE FUNCTION pg_temp.dups() RETURNS bigint LANGUAGE sql AS $$
  SELECT count(*) FROM (SELECT g.series_id, e.start_at FROM public.games g JOIN public.events e ON e.id = g.event_id
                         WHERE g.series_id IS NOT NULL GROUP BY 1, 2 HAVING count(*) > 1) d $$;
-- the data fingerprint the rollback must preserve
CREATE FUNCTION pg_temp.data_md5() RETURNS text LANGUAGE sql AS $$
  SELECT md5((SELECT string_agg(g::text, '|' ORDER BY g.id) FROM public.games g) || '#'
          || (SELECT string_agg(m::text, '|' ORDER BY m.id) FROM public.meetups m) || '#'
          || (SELECT string_agg(e::text, '|' ORDER BY e.id) FROM public.events e)) $$;

\set A1 '''00000000-0000-0000-0000-0000000000a1'''
\set A2 '''00000000-0000-0000-0000-0000000000a2'''
\set A3 '''00000000-0000-0000-0000-0000000000a3'''

-- ---------------------------------------------------------------------------------------------------------
-- 0. Baseline: legacy shapes, counts, parity
-- ---------------------------------------------------------------------------------------------------------
INSERT INTO fx SELECT 'n_games', count(*)::text FROM public.games;
INSERT INTO fx SELECT 'n_meetups', count(*)::text FROM public.meetups;
INSERT INTO fx SELECT 'n_events', count(*)::text FROM public.events;
SELECT pg_temp.chk('B1 [=]', 'events = games + meetups (no doubled parents)', 'ok',
  CASE WHEN pg_temp.fx('n_events')::int = pg_temp.fx('n_games')::int + pg_temp.fx('n_meetups')::int THEN 'ok' ELSE 'events ' || pg_temp.fx('n_events') END);
SELECT pg_temp.chk('B2 [=]', 'every game start_at equals its events.start_at (compat mirror)', '0',
  (SELECT count(*)::text FROM public.games g LEFT JOIN public.events e ON e.id = g.event_id WHERE e.start_at IS DISTINCT FROM g.start_at));
SELECT pg_temp.chk('B3 [=]', 'no duplicate series slot in seeded data', '0', pg_temp.dups()::text);

-- ---------------------------------------------------------------------------------------------------------
-- 1. A future series S as user a2, through the owning RPC (KAN-712-wrapped)
-- ---------------------------------------------------------------------------------------------------------
INSERT INTO fx SELECT 'S', pg_temp.as_('authenticated', :A2, $q$SELECT public.rpc_create_game_series('player',
  '00000000-0000-0000-0000-0000000000e1', NULL, '00000000-0000-0000-0000-0000000000d1', '00000000-0000-0000-0000-0000000000c1',
  '2027-03-01', '18:00', 60, 'UTC', 'weekly', 10, 'D07 series', NULL, NULL, 'public', 'open', 3, 0)::text$q$);
SELECT pg_temp.chk('S1 [=]', 'rpc_create_game_series succeeded', '________-____-____-____-____________', pg_temp.fx('S'));
INSERT INTO fx SELECT 'occ' || row_number() OVER (ORDER BY start_at), id::text FROM public.games WHERE series_id::text = pg_temp.fx('S');
INSERT INTO fx SELECT 'start' || row_number() OVER (ORDER BY start_at), start_at::text FROM public.games WHERE series_id::text = pg_temp.fx('S');
SELECT pg_temp.chk('S2 [=]', 'series S has 3 occurrences, each with exactly one events parent at the same start_at', '3|3|0',
  (SELECT count(*) || '|' || count(e.id) || '|' || count(*) FILTER (WHERE e.start_at IS DISTINCT FROM g.start_at)
     FROM public.games g LEFT JOIN public.events e ON e.id = g.event_id AND e.event_type = 'game' WHERE g.series_id::text = pg_temp.fx('S')));

-- ---------------------------------------------------------------------------------------------------------
-- 2. Simulated withdrawal of the legacy games time index (local, savepoint only)
-- ---------------------------------------------------------------------------------------------------------
SET CONSTRAINTS ALL IMMEDIATE; SET CONSTRAINTS ALL DEFERRED;   -- flush pending deferred trigger events before DDL
SAVEPOINT withdraw;
DROP INDEX public.games_series_id_start_at_key;
SELECT pg_temp.chk('W0 [=]', 'legacy index absent inside the savepoint', '<null>', to_regclass('public.games_series_id_start_at_key')::text);

-- W1: the product path. Moving occ2 onto occ1's slot must be refused AT THE STATEMENT, so the RPC's own
-- unique_violation handler maps it to its contract error. OLD: KAN-710's deferred check only fires at commit
-- (forced here by SET CONSTRAINTS IMMEDIATE), as a raw 23505 the RPC never sees -> FAIL.
SELECT pg_temp.chk('W1 [K]', 'duplicate occurrence via rpc_edit_game_series_occurrence -> occurrence_time_taken', 'ERR P0001 occurrence_time_taken',
  pg_temp.as_('authenticated', :A2, format($q$SELECT public.rpc_edit_game_series_occurrence(%L, p_start_at => %L)::text$q$,
    pg_temp.fx('occ2'), pg_temp.fx('start1'))));
SELECT pg_temp.chk('W2 [=]', 'no duplicate slot after the refused edit', '0', pg_temp.dups()::text);

-- W3: authoritative events-side write (postgres, as the write contract does) onto an occupied slot.
SELECT pg_temp.chk('W3 [=]', 'duplicate occurrence via direct events.start_at write -> 23505', 'ERR 23505 %',
  pg_temp.as_(NULL, NULL, format($q$UPDATE public.events SET start_at = %L, end_at = %L::timestamptz + interval '1 hour' WHERE id = %L RETURNING 'updated'$q$,
    pg_temp.fx('start1'), pg_temp.fx('start1'), pg_temp.fx('occ2'))));

-- W4: a new occurrence joining the series at an occupied slot (generator shape: game exists, then series_id is set).
SELECT pg_temp.chk('W4a [=]', 'setup: unrelated future game moved to occ1''s start (no series yet)', 'updated',
  pg_temp.as_(NULL, NULL, format($q$UPDATE public.events SET start_at = %L, end_at = %L::timestamptz + interval '1 hour' WHERE id = '71300000-0000-0000-0000-000000000001' RETURNING 'updated'$q$,
    pg_temp.fx('start1'), pg_temp.fx('start1'))));
SELECT pg_temp.chk('W4 [=]', 'attaching that game to series S at the taken slot -> 23505', 'ERR 23505 %',
  pg_temp.as_(NULL, NULL, format($q$UPDATE public.games SET series_id = %L WHERE id = '71300000-0000-0000-0000-000000000001' RETURNING 'updated'$q$, pg_temp.fx('S'))));
SELECT pg_temp.chk('W4b [K]', 'the attach is refused at the statement (immediate), not only at commit', 'ERR 23505 %',
  pg_temp.as_(NULL, NULL, format($q$UPDATE public.games SET series_id = %L WHERE id = '71300000-0000-0000-0000-000000000001' RETURNING 'updated'$q$, pg_temp.fx('S')), false));

-- W5: negative control. With every series check disabled (and the legacy index gone) the same write succeeds and
-- a duplicate appears: the W-probes are capable of failing.
SET CONSTRAINTS ALL IMMEDIATE; SET CONSTRAINTS ALL DEFERRED;   -- flush pending deferred trigger events before DDL
SAVEPOINT negctl;
ALTER TABLE public.events DISABLE TRIGGER trg_events_series_start_check;
ALTER TABLE public.games  DISABLE TRIGGER trg_games_series_occurrence_check;
DO $$ BEGIN
  IF to_regproc('public.kan718_series_occurrence_guard') IS NOT NULL THEN
    ALTER TABLE public.events DISABLE TRIGGER trg_kan718_events_series_occurrence;
    ALTER TABLE public.games  DISABLE TRIGGER trg_kan718_games_series_occurrence;
  END IF;
END $$;
SELECT pg_temp.chk('W5 [=]', 'NEGATIVE CONTROL: no checks -> duplicate write accepted', 'updated',
  pg_temp.as_(NULL, NULL, format($q$UPDATE public.events SET start_at = %L, end_at = %L::timestamptz + interval '1 hour' WHERE id = %L RETURNING 'updated'$q$,
    pg_temp.fx('start1'), pg_temp.fx('start1'), pg_temp.fx('occ2'))));
SELECT pg_temp.chk('W5b [=]', 'NEGATIVE CONTROL: duplicate slot measured', '1', pg_temp.dups()::text);
ROLLBACK TO SAVEPOINT negctl;
SELECT pg_temp.chk('W5c [=]', 'negative control rolled back, triggers re-enabled', '0|0',
  pg_temp.dups()::text || '|' || (SELECT count(*) FROM pg_trigger WHERE (tgname LIKE '%series%occurrence%' OR tgname = 'trg_events_series_start_check') AND tgenabled <> 'O')::text);

-- W6-W7: series edits still work with the index gone.
SELECT pg_temp.chk('W6 [=]', 'edit occ1 to a free slot (19:00 same day) succeeds', '{"game_id": %',
  pg_temp.as_('authenticated', :A2, format($q$SELECT public.rpc_edit_game_series_occurrence(%L, p_start_at => %L::timestamptz + interval '1 hour')::text$q$,
    pg_temp.fx('occ1'), pg_temp.fx('start1'))));
SELECT pg_temp.chk('W6b [=]', 'occ1 moved on events and on the legacy mirror', 'ok',
  (SELECT CASE WHEN e.start_at = pg_temp.fx('start1')::timestamptz + interval '1 hour' AND g.start_at = e.start_at THEN 'ok' ELSE e.start_at::text || '/' || g.start_at::text END
     FROM public.games g JOIN public.events e ON e.id = g.event_id WHERE g.id::text = pg_temp.fx('occ1')));
SELECT pg_temp.chk('W7 [=]', 'occ2 may take the slot occ1 vacated (no false positive)', '{"game_id": %',
  pg_temp.as_('authenticated', :A2, format($q$SELECT public.rpc_edit_game_series_occurrence(%L, p_start_at => %L)::text$q$,
    pg_temp.fx('occ2'), pg_temp.fx('start1'))));
SELECT pg_temp.chk('W7b [=]', 'still no duplicate slot', '0', pg_temp.dups()::text);

-- W8: visibility. Non-owner and blocked user gain nothing.
SELECT pg_temp.chk('V1 [=]', 'non-owner a1 cannot edit a2''s occurrence', 'ERR P0001 not_host_or_not_found',
  pg_temp.as_('authenticated', :A1, format($q$SELECT public.rpc_edit_game_series_occurrence(%L, p_start_at => '2027-06-01 10:00+00')::text$q$, pg_temp.fx('occ3'))));
INSERT INTO public.user_blocks (blocker_user_id, blocked_user_id) VALUES (:A2, :A3);
SELECT pg_temp.chk('V2 [=]', 'blocked a3 cannot edit a2''s occurrence', 'ERR P0001 not_host_or_not_found',
  pg_temp.as_('authenticated', :A3, format($q$SELECT public.rpc_edit_game_series_occurrence(%L, p_start_at => '2027-06-01 10:00+00')::text$q$, pg_temp.fx('occ3'))));
SELECT pg_temp.chk('V3 [=]', 'blocked a3 reads no events rows (no grant)', 'ERR 42501 %',
  pg_temp.as_('authenticated', :A3, $q$SELECT count(*)::text FROM public.events$q$));
SELECT pg_temp.chk('V4 [=]', 'blocked a3 sees no series S games (harness games RLS: zero policies)', '0',
  pg_temp.as_('authenticated', :A3, format($q$SELECT count(*)::text FROM public.games WHERE series_id = %L$q$, pg_temp.fx('S'))));
SELECT pg_temp.chk('V5 [K]', 'D07 guard function is not executable by anon/authenticated/service_role', 'false|false|false',
  (SELECT has_function_privilege('anon', p.oid, 'EXECUTE') || '|' || has_function_privilege('authenticated', p.oid, 'EXECUTE')
          || '|' || has_function_privilege('service_role', p.oid, 'EXECUTE')
     FROM pg_proc p WHERE p.oid = to_regproc('public.kan718_series_occurrence_guard')));

-- L1: a series game cannot lose its events link (the guard would skip it). KAN-711's validated games_event_id_not_null
-- is what guarantees this; D07 relies on it (pre-check) rather than adding a second constraint. Assigners disabled to reach the case.
SET CONSTRAINTS ALL IMMEDIATE; SET CONSTRAINTS ALL DEFERRED;   -- flush pending deferred trigger events before DDL
SAVEPOINT link;
ALTER TABLE public.games DISABLE TRIGGER trg_kan711_games_assign_event_id;
ALTER TABLE public.games DISABLE TRIGGER trg_zz_kan712_games_guard;
SELECT pg_temp.chk('L1 [=]', 'series game with event_id NULL refused (23514)', 'ERR 23514 %',
  pg_temp.as_(NULL, NULL, format($q$UPDATE public.games SET event_id = NULL WHERE id = %L RETURNING 'updated'$q$, pg_temp.fx('occ3'))));
ROLLBACK TO SAVEPOINT link;

ROLLBACK TO SAVEPOINT withdraw;
SELECT pg_temp.chk('W9 [=]', 'simulated withdrawal undone: legacy index present again', 'games_series_id_start_at_key',
  to_regclass('public.games_series_id_start_at_key')::text);

-- ---------------------------------------------------------------------------------------------------------
-- 3. D07 shape, counts after the run
-- ---------------------------------------------------------------------------------------------------------
SELECT pg_temp.chk('D1 [K]', 'guard: owner postgres, SECURITY DEFINER, search_path pinned empty', 'postgres|true|search_path=""',
  (SELECT pg_get_userbyid(proowner) || '|' || prosecdef || '|' || coalesce(array_to_string(proconfig, ','), '') FROM pg_proc WHERE oid = to_regproc('public.kan718_series_occurrence_guard')));
SELECT pg_temp.chk('D2 [K]', 'two D07 triggers, enabled, not deferrable', 'trg_kan718_events_series_occurrence:O:false,trg_kan718_games_series_occurrence:O:false',
  (SELECT string_agg(tgname || ':' || tgenabled::text || ':' || tgdeferrable, ',' ORDER BY tgname) FROM pg_trigger WHERE tgname LIKE 'trg\_kan718\_%'));
SELECT pg_temp.chk('D3 [=]', 'KAN-711 games_event_id_not_null validated (every series game is event-linked)', 'CHECK ((event_id IS NOT NULL))|true',
  (SELECT pg_get_constraintdef(oid) || '|' || convalidated FROM pg_constraint WHERE conname = 'games_event_id_not_null' AND conrelid = 'public.games'::regclass));
SELECT pg_temp.chk('D4 [=]', 'KAN-710 deferred backstop untouched (enabled, deferrable, initially deferred)', 'trg_events_series_start_check:O:true:true,trg_games_series_occurrence_check:O:true:true',
  (SELECT string_agg(tgname || ':' || tgenabled::text || ':' || tgdeferrable || ':' || tginitdeferred, ',' ORDER BY tgname)
     FROM pg_trigger WHERE tgname IN ('trg_events_series_start_check', 'trg_games_series_occurrence_check')));
SELECT pg_temp.chk('C1 [=]', 'counts: games +3, meetups +0, events +3 (series S only), events = games + meetups', '3|0|3|ok',
  ((SELECT count(*) FROM public.games) - pg_temp.fx('n_games')::int) || '|' || ((SELECT count(*) FROM public.meetups) - pg_temp.fx('n_meetups')::int)
  || '|' || ((SELECT count(*) FROM public.events) - pg_temp.fx('n_events')::int) || '|'
  || CASE WHEN (SELECT count(*) FROM public.events) = (SELECT count(*) FROM public.games) + (SELECT count(*) FROM public.meetups) THEN 'ok' ELSE 'doubled' END);
SELECT pg_temp.chk('C2 [=]', 'every game start_at still equals events.start_at', '0',
  (SELECT count(*)::text FROM public.games g LEFT JOIN public.events e ON e.id = g.event_id WHERE e.start_at IS DISTINCT FROM g.start_at));

-- ---------------------------------------------------------------------------------------------------------
-- 4. Rollback (the migration header's rollback, verbatim) leaves data intact
-- ---------------------------------------------------------------------------------------------------------
INSERT INTO fx SELECT 'md5_before', pg_temp.data_md5();
SET CONSTRAINTS ALL IMMEDIATE; SET CONSTRAINTS ALL DEFERRED;   -- flush pending deferred trigger events before DDL
SAVEPOINT rb;
-- ROLLBACK SQL (20261104110300_kan718_d07_series_occurrence_unique.sql header) ----------------------------
DROP TRIGGER IF EXISTS trg_kan718_events_series_occurrence ON public.events;
DROP TRIGGER IF EXISTS trg_kan718_games_series_occurrence ON public.games;
DROP FUNCTION IF EXISTS public.kan718_series_occurrence_guard();
-- (games_series_id_idx is KAN-671's index on live; it is NOT dropped.)
-- ----------------------------------------------------------------------------------------------------------
SELECT pg_temp.chk('R1 [=]', 'rollback: games/meetups/events data byte-identical', pg_temp.fx('md5_before'), pg_temp.data_md5());
SELECT pg_temp.chk('R2 [=]', 'rollback: D07 objects gone, legacy index + KAN-710 backstop remain', '0|<null>|games_series_id_start_at_key|2',
  (SELECT count(*) FROM pg_trigger WHERE tgname LIKE 'trg\_kan718\_%')::text || '|'
  || coalesce(to_regproc('public.kan718_series_occurrence_guard')::text, '<null>') || '|'
  || coalesce(to_regclass('public.games_series_id_start_at_key')::text, '<gone>') || '|'
  || (SELECT count(*) FROM pg_trigger WHERE tgname IN ('trg_events_series_start_check', 'trg_games_series_occurrence_check') AND tgenabled = 'O')::text);
SELECT pg_temp.chk('R3 [=]', 'rollback: duplicate still refused (legacy index -> occurrence_time_taken)', 'ERR P0001 occurrence_time_taken',
  pg_temp.as_('authenticated', :A2, format($q$SELECT public.rpc_edit_game_series_occurrence(%L, p_start_at => %L)::text$q$,
    pg_temp.fx('occ3'), pg_temp.fx('start1'))));
ROLLBACK TO SAVEPOINT rb;

-- ---------------------------------------------------------------------------------------------------------
-- Report
-- ---------------------------------------------------------------------------------------------------------
SELECT '#FP|' || c.table_name || '|' || md5(string_agg(c.column_name || ':' || c.data_type || ':' || c.is_nullable || ':' || coalesce(c.column_default, ''), ',' ORDER BY c.ordinal_position))
  FROM information_schema.columns c WHERE c.table_schema = 'public' AND c.table_name IN ('games', 'meetups', 'events') GROUP BY c.table_name ORDER BY c.table_name;
SELECT '#TOTAL|pass=' || pg_temp.tally('pass') || '|fail=' || pg_temp.tally('fail') || '|K_fail=' || pg_temp.tally('kfail')
    || '|eq_fail=' || pg_temp.tally('eqfail');
ROLLBACK;
