-- KAN-712 RACE PROBES. LOCAL THROWAWAY POSTGRES ONLY. THIS FILE COMMITS.
--
-- Races need two sessions and committed fixtures, so this file cannot be BEGIN...ROLLBACK like
-- probes_kan712.sql. Run it ONLY against a disposable copy of a local database:
--   createdb -T kan712_new kan712_race     && psql -d kan712_race     -v DB=kan712_race     -f race_kan712.sql
--   createdb -T kan712_old kan712_race_old && psql -d kan712_race_old -v DB=kan712_race_old -f race_kan712.sql
-- then drop both copies. Never against a Supabase project (it creates the dblink extension and commits).
--
-- The second session is a dblink connection 'r' back into the same database. Its lock_timeout is 2s,
-- so "fast" (< 1s) versus "slow" separates a NOWAIT refusal from a lock wait.
--   R1 [K] a direct legacy write while another session holds the events row fails fast (55P03, no wait).
--   R2 [K] a wrapped RPC takes the events lock FIRST: while it waits, it holds no games row lock.
--   R3 [K] the deadlock shape (other side holds games, RPC holds events and waits on games): the
--          legacy writer gets 55P03 at once, no 40P01, and the RPC then completes.
--   R4 [=] after all of it, events = games for the fixture, and the parity view is empty.
\set ON_ERROR_STOP 1
\pset format unaligned
\pset tuples_only on
\pset pager off
CREATE EXTENSION IF NOT EXISTS dblink;
SET lock_timeout = '3s';
CREATE TEMP TABLE res (n serial, id text, verdict text, expected text, actual text, name text);
CREATE FUNCTION pg_temp.chk(p_id text, p_name text, p_expect text, p_actual text) RETURNS void LANGUAGE sql AS $$
  INSERT INTO res (id, verdict, expected, actual, name)
  VALUES (p_id, CASE WHEN p_actual IS NOT DISTINCT FROM p_expect THEN 'PASS' ELSE 'FAIL' END, p_expect, coalesce(p_actual, '<null>'), p_name);
$$;
CREATE FUNCTION pg_temp.q(p_sql text) RETURNS text LANGUAGE plpgsql AS $$   -- as postgres, errors captured
DECLARE v text; s text;
BEGIN
  BEGIN EXECUTE p_sql INTO v;
  EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS s = RETURNED_SQLSTATE; v := 'ERR ' || s; END;
  RETURN coalesce(v, '<null>');
END $$;
-- r(sql): run a statement on the second session synchronously, returning its single text column.
CREATE FUNCTION pg_temp.r(p_sql text) RETURNS text LANGUAGE sql AS $$ SELECT v FROM dblink('r', p_sql) AS t(v text) $$;

\set A1 '''00000000-0000-0000-0000-0000000000a1'''
\set SPORT '''00000000-0000-0000-0000-0000000000e1'''
\set GEO '''00000000-0000-0000-0000-0000000000d1'''
\set AREA '''00000000-0000-0000-0000-0000000000c1'''
SELECT dblink_connect('r', format('host=/tmp port=54400 user=postgres dbname=%s', :'DB')) AS connected \gset
SELECT dblink_exec('r', 'SET lock_timeout = ''2s''') AS x \gset
-- try(role, uid, sql) on the second session: result or ERR <sqlstate>, plus fast|slow.
SELECT dblink_exec('r', $q$
CREATE FUNCTION pg_temp.try(p_role text, p_uid text, p_sql text) RETURNS text LANGUAGE plpgsql AS $f$
DECLARE v text; s text; t0 timestamptz := clock_timestamp();
BEGIN
  BEGIN
    PERFORM set_config('request.jwt.claim.sub', coalesce(p_uid, ''), true);
    EXECUTE format('SET LOCAL ROLE %I', p_role);
    EXECUTE p_sql INTO v;
    RESET ROLE;
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS s = RETURNED_SQLSTATE;
    RESET ROLE;
    v := 'ERR ' || s;
  END;
  RETURN coalesce(v, '<null>') || '|' ||
         CASE WHEN clock_timestamp() - t0 < interval '1 second' THEN 'fast' ELSE 'slow' END;
END $f$ $q$) AS x \gset
SELECT pg_temp.r('SELECT pg_backend_pid()::text') AS rpid \gset

-- Committed fixture: a future game hosted by A1, created through the RPC on the second session.
SELECT split_part(pg_temp.r(format($s$SELECT pg_temp.try('authenticated', %L, %L)$s$, :A1,
  format($c$SELECT public.rpc_create_game(p_actor_type => 'player', p_sport_id => %L, p_sport_variant_id => NULL,
     p_title => 'Race game', p_start_at => '2027-07-01 18:00+00', p_end_at => '2027-07-01 19:00+00',
     p_geo_location_id => %L, p_area_id => %L, p_max_players => 10, p_price_aed => 0,
     p_request_id => 'cccccccc-0000-0000-0000-000000000001')::text$c$, :SPORT, :GEO, :AREA))), '|', 1) AS rg \gset
SELECT 'fixture race game ' || :'rg';

-- R1 ----------------------------------------------------------------------------------------------------
BEGIN;
SELECT 1 FROM public.events WHERE id = :'rg' FOR UPDATE;
SELECT pg_temp.chk('R1 [K]', 'events row held by another session: direct service_role UPDATE games fails fast with 55P03',
  'ERR 55P03|fast',
  pg_temp.r(format($s$SELECT pg_temp.try('service_role', NULL, %L)$s$,
    format('UPDATE public.games SET price_aed = price_aed + 1 WHERE id = %L', :'rg'))));
COMMIT;

-- R2 ----------------------------------------------------------------------------------------------------
BEGIN;
SAVEPOINT hold;
SELECT 1 FROM public.events WHERE id = :'rg' FOR UPDATE;
SELECT dblink_send_query('r', format($s$SELECT pg_temp.try('authenticated', %L, %L)$s$, :A1,
  format($c$SELECT public.rpc_reschedule_game(%L, '2027-07-02 18:00+00', '2027-07-02 19:30+00')::text$c$, :'rg'))) AS sent \gset
SELECT pg_sleep(1.2);   -- longer than the 1s fast|slow line, so "slow" proves the RPC waited
-- observations go to psql variables: a temp table written inside the savepoint would be rolled back with it
SELECT dblink_is_busy('r')::text AS busy,
  (SELECT count(*) FROM pg_locks WHERE pid = :rpid AND NOT granted)::text AS waiting,
  pg_temp.q(format('SELECT 1::text FROM public.games WHERE id = %L FOR UPDATE NOWAIT', :'rg')) AS games_free \gset
ROLLBACK TO SAVEPOINT hold;
SELECT pg_temp.chk('R2 [K]', 'wrapped rpc_reschedule_game waits on the events lock first, holding no games row lock; completes after release',
  'busy=1 waiting=1 games_free=1 result=rescheduled|slow',
  format('busy=%s waiting=%s games_free=%s ', :'busy', :'waiting', :'games_free') ||
  'result=' || (SELECT v FROM dblink_get_result('r') AS t(v text)));
SELECT 1 FROM dblink_get_result('r') AS t(v text);   -- drain the end-of-results marker
COMMIT;

-- R3 ----------------------------------------------------------------------------------------------------
BEGIN;
SAVEPOINT hold;
SELECT 1 FROM public.games WHERE id = :'rg' FOR UPDATE;
SELECT dblink_send_query('r', format($s$SELECT pg_temp.try('authenticated', %L, %L)$s$, :A1,
  format($c$SELECT public.rpc_reschedule_game(%L, '2027-07-03 18:00+00', '2027-07-03 19:30+00')::text$c$, :'rg'))) AS sent \gset
SELECT pg_sleep(1.2);   -- longer than the 1s fast|slow line, so "slow" proves the RPC waited
SELECT dblink_is_busy('r')::text AS busy,
  pg_temp.q(format('SELECT 1::text FROM public.events WHERE id = %L FOR UPDATE NOWAIT', :'rg')) AS events_held,
  pg_temp.q(format($u$WITH u AS (UPDATE public.games SET price_aed = price_aed + 1 WHERE id = %L RETURNING 1) SELECT count(*)::text FROM u$u$, :'rg')) AS legacy_write \gset
ROLLBACK TO SAVEPOINT hold;
SELECT pg_temp.chk('R3 [K]', 'deadlock shape: RPC holds events and waits on games; the legacy writer gets 55P03 at once (no 40P01); the RPC completes',
  'busy=1 events_held=ERR 55P03 legacy_write=ERR 55P03 result=rescheduled|slow',
  format('busy=%s events_held=%s legacy_write=%s ', :'busy', :'events_held', :'legacy_write') ||
  'result=' || (SELECT v FROM dblink_get_result('r') AS t(v text)));
SELECT 1 FROM dblink_get_result('r') AS t(v text);
COMMIT;

-- R4 ----------------------------------------------------------------------------------------------------
SELECT pg_temp.chk('R4 [=]', 'after the races: events = games for the fixture (start_at, end_at), parity view empty',
  'true|0',
  (SELECT (e.start_at = g.start_at AND e.end_at = g.end_at)::text FROM public.events e JOIN public.games g ON g.id = e.id WHERE e.id = :'rg')
  || '|' || (SELECT count(*)::text FROM public.kan711_events_parity));

SELECT dblink_disconnect('r') AS x \gset
SELECT id || '|' || verdict || '|expected=' || expected || '|actual=' || actual || '|' || name FROM res ORDER BY n;
SELECT '#TOTAL|pass=' || count(*) FILTER (WHERE verdict = 'PASS') || '|fail=' || count(*) FILTER (WHERE verdict = 'FAIL') FROM res;
