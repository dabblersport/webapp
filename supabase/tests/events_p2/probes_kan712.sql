-- KAN-712 PROBES. LOCAL THROWAWAY POSTGRES ONLY. One transaction, ROLLBACK at the end.
--
-- Run against BOTH local databases built by /tmp chain (see KAN712_CONTRACT.md "Local verification"):
--   NEW (phase 2, KAN-712 applied): every probe must print PASS.
--   OLD (phase 1, KAN-711 only):    every probe marked [K] must print FAIL. That is the evidence each
--                                   KAN-712 probe can fail; a probe nobody has seen fail is not evidence.
--   Probes marked [=] assert behaviour that must be IDENTICAL before and after (PASS on both).
-- Each probe records: id | PASS/FAIL | expected | actual | name. Errors are captured as ERR <sqlstate>
-- (plus a short tag where the SQLSTATE alone is ambiguous). Nothing raises, so the file always completes.
-- Races (NOWAIT, events-first ordering, no deadlock) are in race_kan712.sql (needs committed fixtures).
\set ON_ERROR_STOP 1
\pset format unaligned
\pset tuples_only on
\pset pager off
BEGIN;
SET LOCAL lock_timeout = '3s';
CREATE TEMP TABLE res (n serial, id text, verdict text, expected text, actual text, name text);
CREATE TEMP TABLE fx (label text PRIMARY KEY, id uuid);

-- as(role, uid, sql): run sql as role with auth.uid() = uid; returns its text result, or ERR <sqlstate>.
-- GUCs the sql sets are local to the subtransaction only on error, so kan712.* are cleared explicitly.
CREATE FUNCTION pg_temp.as_(p_role text, p_uid uuid, p_sql text) RETURNS text LANGUAGE plpgsql AS $$
DECLARE v text; s text;
BEGIN
  BEGIN
    PERFORM set_config('request.jwt.claim.sub', coalesce(p_uid::text, ''), true);
    EXECUTE format('SET LOCAL ROLE %I', p_role);
    EXECUTE p_sql INTO v;
    RESET ROLE;
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS s = RETURNED_SQLSTATE;
    RESET ROLE;
    v := 'ERR ' || s;
  END;
  PERFORM set_config('request.jwt.claim.sub', '', true);
  PERFORM set_config('kan712.contract', '', true);
  PERFORM set_config('kan712.routing', '', true);
  PERFORM set_config('kan712.compat', '', true);
  RETURN coalesce(v, '<null>');
END $$;
CREATE FUNCTION pg_temp.chk(p_id text, p_name text, p_expect text, p_actual text) RETURNS void LANGUAGE sql AS $$
  INSERT INTO res (id, verdict, expected, actual, name)
  VALUES (p_id, CASE WHEN p_actual IS NOT DISTINCT FROM p_expect THEN 'PASS' ELSE 'FAIL' END, p_expect, coalesce(p_actual, '<null>'), p_name);
$$;
-- A plain subquery in the same statement as a write reads the statement-start snapshot and cannot see
-- that write, so every write is recorded by keep() and checked in the NEXT statement.
CREATE TEMP TABLE act (k text PRIMARY KEY, v text);
CREATE FUNCTION pg_temp.keep(p_k text, p_v text) RETURNS void LANGUAGE sql AS $$ INSERT INTO act VALUES (p_k, p_v) $$;
CREATE FUNCTION pg_temp.a(p_k text) RETURNS text LANGUAGE sql AS $$ SELECT v FROM act WHERE k = p_k $$;
CREATE FUNCTION pg_temp.q(p_sql text) RETURNS text LANGUAGE plpgsql AS $$   -- as postgres, errors captured
DECLARE v text; s text;
BEGIN
  BEGIN EXECUTE p_sql INTO v;
  EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS s = RETURNED_SQLSTATE; v := 'ERR ' || s; END;
  RETURN coalesce(v, '<null>');
END $$;

-- Row-update counter on events / games / meetups (probe-local, rolled back): proves one logical change
-- = exactly one UPDATE per table, so every legacy side-effect row trigger fires exactly once and
-- nothing ping-pongs between events and the subtype.
CREATE TABLE public.kan712probe_log (tbl text, id uuid);
CREATE FUNCTION public.kan712probe_count() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN INSERT INTO public.kan712probe_log VALUES (TG_TABLE_NAME, NEW.id); RETURN NULL; END $$;
CREATE TRIGGER zzz_kan712probe AFTER UPDATE ON public.events  FOR EACH ROW EXECUTE FUNCTION public.kan712probe_count();
CREATE TRIGGER zzz_kan712probe AFTER UPDATE ON public.games   FOR EACH ROW EXECUTE FUNCTION public.kan712probe_count();
CREATE TRIGGER zzz_kan712probe AFTER UPDATE ON public.meetups FOR EACH ROW EXECUTE FUNCTION public.kan712probe_count();
CREATE FUNCTION pg_temp.cnt() RETURNS text LANGUAGE sql AS $$
  SELECT format('e=%s g=%s m=%s', count(*) FILTER (WHERE tbl = 'events'), count(*) FILTER (WHERE tbl = 'games'),
                count(*) FILTER (WHERE tbl = 'meetups')) FROM public.kan712probe_log $$;
CREATE FUNCTION pg_temp.reset_cnt() RETURNS void LANGUAGE sql AS $$ DELETE FROM public.kan712probe_log $$;

\set G01 '''10000000-0000-0000-0000-000000000001'''
\set G02 '''10000000-0000-0000-0000-000000000002'''
\set G06 '''10000000-0000-0000-0000-000000000006'''
\set M01 '''30000000-0000-0000-0000-000000000001'''
\set M02 '''30000000-0000-0000-0000-000000000002'''
\set A1 '''00000000-0000-0000-0000-0000000000a1'''
\set A2 '''00000000-0000-0000-0000-0000000000a2'''
\set SPORT '''00000000-0000-0000-0000-0000000000e1'''
\set GEO '''00000000-0000-0000-0000-0000000000d1'''
\set AREA '''00000000-0000-0000-0000-0000000000c1'''

-- A. Direct legacy writes: routed or refused -----------------------------------------------------------
SELECT pg_temp.chk('A1 [K]', 'service_role direct UPDATE games shared field (title) is refused', 'ERR 42501',
  pg_temp.as_('service_role', NULL, format($s$WITH u AS (UPDATE public.games SET title = 'direct' WHERE id = %L RETURNING 1) SELECT count(*)::text FROM u$s$, :G01)));
SELECT pg_temp.chk('A2 [K]', 'service_role direct UPDATE meetups shared field (start_at) is refused', 'ERR 42501',
  pg_temp.as_('service_role', NULL, format($s$WITH u AS (UPDATE public.meetups SET start_at = start_at + interval '1 hour' WHERE id = %L RETURNING 1) SELECT count(*)::text FROM u$s$, :M01)));
SELECT pg_temp.chk('A3 [K]', 'service_role direct UPDATE games is_cancelled (cancel bypass) is refused', 'ERR 42501',
  pg_temp.as_('service_role', NULL, format($s$WITH u AS (UPDATE public.games SET is_cancelled = true WHERE id = %L RETURNING 1) SELECT count(*)::text FROM u$s$, :G01)));
SELECT pg_temp.chk('A3b [K]', 'refused writes changed nothing (title, is_cancelled, meetup start_at = events)', 'Sunday 5s|false|t',
  (SELECT title FROM public.games WHERE id = :G01) || '|' || (SELECT is_cancelled::text FROM public.games WHERE id = :G01) || '|' ||
  (SELECT CASE WHEN m.start_at = e.start_at THEN 't' ELSE 'f' END FROM public.meetups m JOIN public.events e USING (id) WHERE m.id = :M01));
SELECT pg_temp.reset_cnt();
SELECT pg_temp.chk('A4 [=]', 'service_role direct UPDATE games non-shared field (price_aed) is allowed', '1',
  pg_temp.as_('service_role', NULL, format($s$WITH u AS (UPDATE public.games SET price_aed = 7 WHERE id = %L RETURNING 1) SELECT count(*)::text FROM u$s$, :G06)));
SELECT pg_temp.chk('A5 [=]', 'non-shared write: events.updated_at follows (one events UPDATE, one games UPDATE)', 'e=1 g=1 m=0 same_ts=true',
  pg_temp.cnt() || ' same_ts=' || (SELECT (g.updated_at = e.updated_at)::text FROM public.games g JOIN public.events e ON e.id = g.id WHERE g.id = :G06));
SELECT pg_temp.chk('A6 [=]', 'service_role direct UPDATE meetups non-shared field (description) is allowed', '1',
  pg_temp.as_('service_role', NULL, format($s$WITH u AS (UPDATE public.meetups SET description = 'probe' WHERE id = %L RETURNING 1) SELECT count(*)::text FROM u$s$, :M01)));
SELECT pg_temp.chk('A7 [=]', 'authenticated host direct UPDATE games: RLS filters it (0 rows), before and after', '0',
  pg_temp.as_('authenticated', :A1, format($s$WITH u AS (UPDATE public.games SET title = 'x' WHERE id = %L RETURNING 1) SELECT count(*)::text FROM u$s$, :G01)));
SELECT pg_temp.chk('A8 [=]', 'authenticated host direct UPDATE meetups: no grant', 'ERR 42501',
  pg_temp.as_('authenticated', :A1, format($s$WITH u AS (UPDATE public.meetups SET title = 'x' WHERE id = %L RETURNING 1) SELECT count(*)::text FROM u$s$, :M01)));
SELECT pg_temp.chk('A9 [=]', 'anon direct UPDATE games: no grant', 'ERR 42501',
  pg_temp.as_('anon', NULL, format($s$WITH u AS (UPDATE public.games SET title = 'x' WHERE id = %L RETURNING 1) SELECT count(*)::text FROM u$s$, :G01)));
SELECT pg_temp.reset_cnt();
SELECT pg_temp.keep('A10', pg_temp.q(format($s$WITH u AS (UPDATE public.games SET title = 'pg routed' WHERE id = %L RETURNING 1) SELECT count(*)::text FROM u$s$, :G02)));
SELECT pg_temp.chk('A10 [=]', 'postgres (migration/seed path) direct UPDATE games title is routed to events', '1|pg routed|e=1 g=1 m=0',
  pg_temp.a('A10') || '|' || (SELECT title FROM public.events WHERE id = :G02) || '|' || pg_temp.cnt());
SELECT pg_temp.chk('A11 [K]', 'id change on a legacy row is refused', 'ERR 23514',
  pg_temp.q(format($s$WITH u AS (UPDATE public.games SET id = '10000000-0000-0000-0000-0000000000ff' WHERE id = %L RETURNING 1) SELECT count(*)::text FROM u$s$, :G06)));

-- B. Admin/ops write contract: kan712_update_event_shared -----------------------------------------------
SELECT pg_temp.reset_cnt();
SELECT pg_temp.keep('B1', pg_temp.as_('service_role', NULL, format($s$SELECT public.kan712_update_event_shared(%L, '{"title":"ops title"}')->>'title'$s$, :G01)));
SELECT pg_temp.chk('B1 [K]', 'service_role ops patch on a game updates events, mirrored to games', 'ops title|ops title|ops title',
  pg_temp.a('B1') || '|' || (SELECT title FROM public.events WHERE id = :G01) || '|' || (SELECT title FROM public.games WHERE id = :G01));
SELECT pg_temp.chk('B2 [K]', 'ops patch: exactly one events UPDATE and one games UPDATE (no loop)', 'e=1 g=1 m=0', pg_temp.cnt());
SELECT pg_temp.reset_cnt();
SELECT pg_temp.keep('B3pre', (SELECT rsvp_policy FROM public.meetups WHERE id = :M02));
SELECT pg_temp.keep('B3', pg_temp.as_('service_role', NULL, format($s$SELECT public.kan712_update_event_shared(%L,
  jsonb_build_object('join_policy', CASE WHEN %L = 'invite' THEN 'request' ELSE 'invite' END))->>'join_policy'$s$, :M02, pg_temp.a('B3pre'))));
SELECT pg_temp.chk('B3 [K]', 'ops patch on a meetup: join_policy lands in meetups.rsvp_policy (value changed)', 'changed|same|e=1 g=0 m=1',
  CASE WHEN pg_temp.a('B3') IS DISTINCT FROM pg_temp.a('B3pre') AND pg_temp.a('B3') IN ('invite', 'request') THEN 'changed' ELSE 'unchanged:' || pg_temp.a('B3') END
  || '|' || CASE WHEN (SELECT rsvp_policy FROM public.meetups WHERE id = :M02) = pg_temp.a('B3') THEN 'same' ELSE 'differs' END || '|' || pg_temp.cnt());
SELECT pg_temp.chk('B4 [K]', 'ops patch rejects id', 'ERR 22023',
  pg_temp.as_('service_role', NULL, format($s$SELECT public.kan712_update_event_shared(%L, '{"id":"10000000-0000-0000-0000-0000000000ff"}')::text$s$, :G01)));
SELECT pg_temp.chk('B5 [K]', 'ops patch rejects creator_user_id', 'ERR 22023',
  pg_temp.as_('service_role', NULL, format($s$SELECT public.kan712_update_event_shared(%L, '{"creator_user_id":"00000000-0000-0000-0000-0000000000a2"}')::text$s$, :G01)));
SELECT pg_temp.chk('B6 [K]', 'ops patch rejects request_id', 'ERR 22023',
  pg_temp.as_('service_role', NULL, format($s$SELECT public.kan712_update_event_shared(%L, '{"request_id":null}')::text$s$, :G01)));
SELECT pg_temp.chk('B7 [K]', 'ops patch rejects a non-object patch', 'ERR 22023',
  pg_temp.as_('service_role', NULL, format($s$SELECT public.kan712_update_event_shared(%L, '[]')::text$s$, :G01)));
SELECT pg_temp.chk('B8 [K]', 'ops patch on a missing event', 'ERR P0002',
  pg_temp.as_('service_role', NULL, $s$SELECT public.kan712_update_event_shared('99999999-0000-0000-0000-000000000000', '{"title":"x"}')::text$s$));
SELECT pg_temp.keep('B9', pg_temp.as_('service_role', NULL, format($s$SELECT public.kan712_update_event_shared(%L, '{"capacity":1}')::text$s$, :G01)));
SELECT pg_temp.chk('B9 [K]', 'ops patch violating a CHECK fails and changes nothing', 'ERR 23514|ops title|ops title',
  pg_temp.a('B9') || '|' || (SELECT title FROM public.events WHERE id = :G01) || '|' || (SELECT title FROM public.games WHERE id = :G01));
SELECT pg_temp.chk('B10 [K]', 'anon cannot call the ops path', 'ERR 42501',
  pg_temp.as_('anon', NULL, format($s$SELECT public.kan712_update_event_shared(%L, '{"title":"x"}')::text$s$, :G01)));
SELECT pg_temp.chk('B11 [K]', 'authenticated cannot call the ops path', 'ERR 42501',
  pg_temp.as_('authenticated', :A1, format($s$SELECT public.kan712_update_event_shared(%L, '{"title":"x"}')::text$s$, :G01)));

-- C. Side effects exactly once (cancel through the ops path; legacy cancel triggers fire from the mirror)
SELECT pg_temp.as_('postgres', NULL, format($s$WITH i AS (INSERT INTO public.game_roster (game_id, user_id, profile_id, role, status)
  VALUES (%L, '00000000-0000-0000-0000-0000000000a2', '00000000-0000-0000-0000-0000000000b2', 'player', 'active') RETURNING 1) SELECT count(*)::text FROM i$s$, :G01));
CREATE TEMP TABLE c0 AS SELECT (SELECT count(*) FROM public.msg_system_lines WHERE game_id = :G01 AND kind = 'cancelled') AS msg,
  (SELECT count(*) FROM public.notifications WHERE kind = 'game.updated') AS notif,
  (SELECT count(*) FROM public.game_roster WHERE game_id = :G01 AND user_id <> '00000000-0000-0000-0000-0000000000a1') AS players;
SELECT pg_temp.reset_cnt();
SELECT pg_temp.as_('service_role', NULL, format($s$SELECT public.kan712_update_event_shared(%L,
  '{"is_cancelled":true,"cancelled_at":"2026-11-02T10:00:00Z","cancelled_reason":"ops"}')->>'is_cancelled'$s$, :G01));
SELECT pg_temp.chk('C1 [K]', 'ops cancel: one system line, one game.updated per non-host player, one UPDATE each', 'msg=1 notif=players e=1 g=1 m=0',
  format('msg=%s notif=%s %s',
    (SELECT count(*) FROM public.msg_system_lines WHERE game_id = :G01 AND kind = 'cancelled') - (SELECT msg FROM c0),
    CASE WHEN (SELECT count(*) FROM public.notifications WHERE kind = 'game.updated') - (SELECT notif FROM c0) = (SELECT players FROM c0)
              AND (SELECT players FROM c0) > 0 THEN 'players' ELSE 'mismatch' END,
    pg_temp.cnt()));
SELECT pg_temp.reset_cnt();
SELECT pg_temp.as_('service_role', NULL, format($s$SELECT public.kan712_update_event_shared(%L, '{"is_cancelled":true}')->>'is_cancelled'$s$, :G01));
SELECT pg_temp.chk('C2 [K]', 'repeating the same cancel adds no side effect', 'msg=1 notif=players',
  format('msg=%s notif=%s',
    (SELECT count(*) FROM public.msg_system_lines WHERE game_id = :G01 AND kind = 'cancelled') - (SELECT msg FROM c0),
    CASE WHEN (SELECT count(*) FROM public.notifications WHERE kind = 'game.updated') - (SELECT notif FROM c0) = (SELECT players FROM c0)
         THEN 'players' ELSE 'mismatch' END));

-- D. Events is authoritative: a direct events write reaches the subtype; GUC spoofing ------------------
SELECT pg_temp.reset_cnt();
SELECT pg_temp.keep('D1', pg_temp.as_('service_role', NULL, format($s$WITH u AS (UPDATE public.events SET title = 'from events' WHERE id = %L RETURNING 1) SELECT count(*)::text FROM u$s$, :G06)));
SELECT pg_temp.chk('D1 [K]', 'service_role direct UPDATE events title is mirrored to games, once', '1|from events|e=1 g=1 m=0',
  pg_temp.a('D1') || '|' || (SELECT title FROM public.games WHERE id = :G06) || '|' || pg_temp.cnt());
SELECT pg_temp.keep('D2', pg_temp.as_('service_role', NULL, format($s$WITH s AS (SELECT set_config('kan712.routing', %L, true)),
     u AS (UPDATE public.events SET title = 'spoof routing' WHERE id = %L AND EXISTS (SELECT 1 FROM s) RETURNING 1) SELECT count(*)::text FROM u$s$, :G06, :G06)));
SELECT pg_temp.chk('D2 [K]', 'spoofed SET kan712.routing does not suppress the mirror (depth-bound)', '1|spoof routing',
  pg_temp.a('D2') || '|' || (SELECT title FROM public.games WHERE id = :G06));
SELECT pg_temp.chk('D3 [K]', 'spoofed SET kan712.compat does not open the refusal (depth-bound)', 'ERR 42501',
  pg_temp.as_('service_role', NULL, format($s$WITH s AS (SELECT set_config('kan712.compat', %L, true)),
     u AS (UPDATE public.games SET title = 'spoof compat' WHERE id = %L AND EXISTS (SELECT 1 FROM s) RETURNING 1) SELECT count(*)::text FROM u$s$, :G06, :G06)));
SELECT pg_temp.keep('D4', pg_temp.as_('service_role', NULL, format($s$WITH s AS (SELECT set_config('kan712.contract', 'on', true)),
     u AS (UPDATE public.games SET title = 'spoof contract' WHERE id = %L AND EXISTS (SELECT 1 FROM s) RETURNING 1) SELECT count(*)::text FROM u$s$, :G06)));
SELECT pg_temp.chk('D4 [=]', 'spoofed SET kan712.contract by service_role: not refused, but still ROUTED (events = games)', '1|spoof contract|spoof contract',
  pg_temp.a('D4') || '|' || (SELECT title FROM public.games WHERE id = :G06) || '|' || (SELECT title FROM public.events WHERE id = :G06));
SELECT pg_temp.chk('D5 [=]', 'spoofed SET kan712.contract by authenticated: RLS still filters (0 rows)', '0',
  pg_temp.as_('authenticated', :A1, format($s$WITH s AS (SELECT set_config('kan712.contract', 'on', true)),
     u AS (UPDATE public.games SET title = 'x' WHERE id = %L AND EXISTS (SELECT 1 FROM s) RETURNING 1) SELECT count(*)::text FROM u$s$, :G06)));
SELECT pg_temp.chk('D6 [=]', 'authenticated cannot write events at all', 'ERR 42501',
  pg_temp.as_('authenticated', :A1, format($s$WITH u AS (UPDATE public.events SET title = 'x' WHERE id = %L RETURNING 1) SELECT count(*)::text FROM u$s$, :G06)));

-- E. RPC paths through the wrappers: one UPDATE per table, request_id replay, create failure ------------
CREATE TEMP TABLE e0 AS SELECT pg_temp.as_('authenticated', :A1, format($s$SELECT public.rpc_create_game(p_actor_type => 'player', p_sport_id => %L,
     p_sport_variant_id => NULL, p_title => 'Probe game', p_start_at => '2027-05-01 18:00+00', p_end_at => '2027-05-01 19:00+00',
     p_geo_location_id => %L, p_area_id => %L, p_max_players => 10, p_price_aed => 0,
     p_request_id => 'bbbbbbbb-0000-0000-0000-000000000001')::text$s$, :SPORT, :GEO, :AREA)) AS v;
INSERT INTO fx SELECT 'PG', v::uuid FROM e0 WHERE v ~ '^[0-9a-f-]{36}$';
SELECT pg_temp.chk('E0 [=]', 'fixture game create (authenticated host, future)', 'ok', (SELECT CASE WHEN count(*) = 1 THEN 'ok' ELSE 'bad' END FROM fx WHERE label = 'PG'));
SELECT pg_temp.chk('E1 [=]', 'request_id replay with different payload returns the same id', 'true',
  pg_temp.as_('authenticated', :A1, format($s$SELECT (public.rpc_create_game(p_actor_type => 'player', p_sport_id => %L,
     p_sport_variant_id => NULL, p_title => 'Probe game REPLAY', p_start_at => '2027-05-01 18:00+00', p_end_at => '2027-05-01 19:00+00',
     p_geo_location_id => %L, p_area_id => %L, p_max_players => 10, p_price_aed => 0,
     p_request_id => 'bbbbbbbb-0000-0000-0000-000000000001') = %L)::text$s$, :SPORT, :GEO, :AREA, (SELECT id FROM fx WHERE label = 'PG'))));
SELECT pg_temp.chk('E2 [=]', 'replay created nothing: one games row, one events row for that request_id', '1|1',
  (SELECT count(*)::text FROM public.games WHERE request_id = 'bbbbbbbb-0000-0000-0000-000000000001') || '|' ||
  (SELECT count(*)::text FROM public.events WHERE request_id = 'bbbbbbbb-0000-0000-0000-000000000001'));
SELECT pg_temp.reset_cnt();
SELECT pg_temp.keep('E3', pg_temp.as_('authenticated', :A1, format($s$SELECT public.rpc_reschedule_game(%L, '2027-05-02 18:00+00', '2027-05-02 19:30+00')::text$s$, (SELECT id FROM fx WHERE label = 'PG'))));
SELECT pg_temp.chk('E3 [=]', 'rpc_reschedule_game: one events UPDATE, one games UPDATE, values equal', 'rescheduled|e=1 g=1 m=0|true',
  pg_temp.a('E3') || '|' || pg_temp.cnt() || '|' || (SELECT (g.start_at = e.start_at AND g.end_at = e.end_at AND g.updated_at = e.updated_at)::text
                                       FROM public.games g JOIN public.events e USING (id) WHERE g.id = (SELECT id FROM fx WHERE label = 'PG')));
SELECT pg_temp.reset_cnt();
SELECT pg_temp.keep('E4', pg_temp.as_('authenticated', :A1, format($s$SELECT public.rpc_cancel_game(%L, 'probe')::text$s$, (SELECT id FROM fx WHERE label = 'PG'))));
SELECT pg_temp.chk('E4 [=]', 'rpc_cancel_game: one UPDATE each, one system line', 'cancelled|e=1 g=1 m=0|1',
  pg_temp.a('E4') || '|' || pg_temp.cnt() || '|' || (SELECT count(*)::text FROM public.msg_system_lines WHERE game_id = (SELECT id FROM fx WHERE label = 'PG')));
SELECT pg_temp.chk('E5 [=]', 'non-host cannot reschedule through the wrapper', 'ERR P0001',
  pg_temp.as_('authenticated', :A2, format($s$SELECT public.rpc_reschedule_game(%L, '2027-05-03 18:00+00', '2027-05-03 19:30+00')::text$s$, (SELECT id FROM fx WHERE label = 'PG'))));
SELECT pg_temp.keep('E6', pg_temp.as_('authenticated', :A1, format($s$SELECT public.rpc_create_game(p_actor_type => 'player', p_sport_id => %L,
     p_sport_variant_id => NULL, p_title => 'Bad', p_start_at => '2027-05-01 18:00+00', p_end_at => '2027-05-01 19:00+00',
     p_geo_location_id => %L, p_area_id => %L, p_max_players => 1, p_price_aed => 0,
     p_request_id => 'bbbbbbbb-0000-0000-0000-0000000000ee')::text$s$, :SPORT, :GEO, :AREA)));
SELECT pg_temp.chk('E6 [=]', 'failed create (CHECK) leaves no games/events row for its request_id', 'ERR 23514|0|0',
  pg_temp.a('E6') || '|' || (SELECT count(*)::text FROM public.games WHERE request_id = 'bbbbbbbb-0000-0000-0000-0000000000ee')
  || '|' || (SELECT count(*)::text FROM public.events WHERE request_id = 'bbbbbbbb-0000-0000-0000-0000000000ee'));

-- F. Guard INSERT remap: an events-level request_id collision surfaces under the legacy key name --------
CREATE FUNCTION pg_temp.dup_insert(p_src uuid) RETURNS text LANGUAGE plpgsql AS $$
DECLARE cols text; c text; d text; s text;
BEGIN
  SELECT string_agg(quote_ident(column_name), ', ' ORDER BY ordinal_position) INTO cols FROM information_schema.columns
   WHERE table_schema = 'public' AND table_name = 'games' AND is_generated = 'NEVER' AND column_name NOT IN ('id', 'event_id', 'search_tsv');
  BEGIN
    EXECUTE format('INSERT INTO public.games (id, %s) SELECT ''10000000-0000-0000-0000-0000000000fe'', %s FROM public.games WHERE id = %L', cols, cols, p_src);
    RETURN 'inserted';
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS s = RETURNED_SQLSTATE, c = CONSTRAINT_NAME, d = PG_EXCEPTION_DETAIL;
    RETURN format('ERR %s %s %s', s, c, CASE WHEN d LIKE 'kan712:%' THEN 'via_events' ELSE 'via_legacy' END);
  END;
END $$;
SELECT pg_temp.chk('F1 [K]', 'duplicate (creator, request_id) insert: 23505 under games_creator_user_request_id_key, raised from the events parent', 'ERR 23505 games_creator_user_request_id_key via_events',
  pg_temp.dup_insert(:G02));
SELECT pg_temp.chk('F2 [=]', 'the failed insert left no row behind', '0|0',
  (SELECT count(*)::text FROM public.games WHERE id = '10000000-0000-0000-0000-0000000000fe') || '|' ||
  (SELECT count(*)::text FROM public.events WHERE id = '10000000-0000-0000-0000-0000000000fe'));

-- G. Delete removes the parent ---------------------------------------------------------------------------
-- Flush KAN-710's deferred link checks while the fixture rows still exist: a deferred
-- events_check_subtype_link event queued for a row deleted later in the same transaction raises "orphan"
-- (pre-existing KAN-710 behaviour, contract limitation L-15). Constraints stay immediate from here on.
SET CONSTRAINTS ALL IMMEDIATE;
SELECT pg_temp.keep('G1', pg_temp.q(format($s$WITH d AS (DELETE FROM public.games WHERE id = %L RETURNING 1) SELECT count(*)::text FROM d$s$, (SELECT id FROM fx WHERE label = 'PG'))));
SELECT pg_temp.chk('G1 [=]', 'postgres DELETE of a legacy game removes its events parent (KAN-711 mirror before, KAN-712 after-delete after)', '1|0',
  pg_temp.a('G1') || '|' || (SELECT count(*)::text FROM public.events WHERE id = (SELECT id FROM fx WHERE label = 'PG')));

-- G2 is the negative control for G1: with the KAN-712 after-delete trigger disabled the parent survives,
-- so G1's result on NEW is that trigger's work (the KAN-711 mirror that did it in phase 1 is disabled).
CREATE TEMP TABLE g2 AS SELECT pg_temp.as_('authenticated', :A1, format($s$SELECT public.rpc_create_game(p_actor_type => 'player', p_sport_id => %L,
     p_sport_variant_id => NULL, p_title => 'Probe game 2', p_start_at => '2027-06-01 18:00+00', p_end_at => '2027-06-01 19:00+00',
     p_geo_location_id => %L, p_area_id => %L, p_max_players => 10, p_price_aed => 0,
     p_request_id => 'bbbbbbbb-0000-0000-0000-000000000002')::text$s$, :SPORT, :GEO, :AREA)) AS v;
INSERT INTO fx SELECT 'PG2', v::uuid FROM g2 WHERE v ~ '^[0-9a-f-]{36}$';
SELECT pg_temp.keep('G2a', pg_temp.q($s$ALTER TABLE public.games DISABLE TRIGGER trg_zz_kan712_games_after_delete; SELECT 'disabled'$s$));
SELECT pg_temp.keep('G2', pg_temp.q(format($s$WITH d AS (DELETE FROM public.games WHERE id = %L RETURNING 1) SELECT count(*)::text FROM d$s$, (SELECT id FROM fx WHERE label = 'PG2'))));
SELECT pg_temp.chk('G2 [K]', 'control: after-delete trigger disabled -> the events parent survives the delete', 'disabled|1|1',
  pg_temp.a('G2a') || '|' || pg_temp.a('G2') || '|' || (SELECT count(*)::text FROM public.events WHERE id = (SELECT id FROM fx WHERE label = 'PG2')));
SELECT pg_temp.q($s$DELETE FROM public.events WHERE id = (SELECT id FROM fx WHERE label = 'PG2'); SELECT 'x'$s$);
SELECT pg_temp.q($s$ALTER TABLE public.games ENABLE TRIGGER trg_zz_kan712_games_after_delete; SELECT 'enabled'$s$);

-- H. Wrapper / inner privileges (adversarial) -----------------------------------------------------------
SELECT pg_temp.chk('H1 [K]', 'every wrapper ACL equals the recorded original, owner unchanged (11 RPCs)', '11|0',
  pg_temp.q($s$SELECT count(*)::text || '|' || count(*) FILTER (WHERE NOT ok)::text FROM (
     SELECT w.name, (SELECT p.proacl IS NOT DISTINCT FROM w.original_acl AND p.proowner = w.original_owner FROM pg_proc p
                      WHERE p.pronamespace = 'public'::regnamespace AND p.proname = w.name
                        AND pg_get_function_identity_arguments(p.oid) = w.identity_args) AS ok
       FROM public.kan712_wrapped_rpcs w) x$s$));
SELECT pg_temp.chk('H2 [K]', 'no inner is executable by anon/authenticated/service_role (11 inners)', '11|0',
  pg_temp.q($s$SELECT count(*)::text || '|' || count(*) FILTER (WHERE has_function_privilege('anon', p.oid, 'EXECUTE')
     OR has_function_privilege('authenticated', p.oid, 'EXECUTE') OR has_function_privilege('service_role', p.oid, 'EXECUTE'))::text
     FROM public.kan712_wrapped_rpcs w JOIN pg_proc p ON p.pronamespace = 'public'::regnamespace AND p.proname = w.inner_name
      AND pg_get_function_identity_arguments(p.oid) = w.identity_args$s$));
SELECT pg_temp.chk('H3 [K]', 'authenticated calling an inner directly is refused', 'ERR 42501',
  pg_temp.as_('authenticated', :A1, format($s$SELECT public.rpc_cancel_game_kan712_inner(%L, 'bypass')::text$s$, :G06)));
SELECT pg_temp.chk('H4 [K]', 'service_role calling the generator inner directly is refused', 'ERR 42501',
  pg_temp.as_('service_role', NULL, $s$SELECT public.fn_generate_game_series_occurrences_kan712_inner('00000000-0000-0000-0000-0000000000f1')::text$s$));
SELECT pg_temp.chk('H5 [=]', 'wrapped RPC grants unchanged: anon keeps rpc_cancel_game, loses nothing, gains nothing', 'true|false|true|false',
  has_function_privilege('anon', 'public.rpc_cancel_game(uuid,text)', 'EXECUTE')::text || '|' ||
  has_function_privilege('anon', 'public.rpc_update_game(uuid,timestamptz,timestamptz,text,uuid,boolean,text,text,boolean,boolean,integer,integer,boolean,jsonb,integer,integer,numeric)', 'EXECUTE')::text || '|' ||
  has_function_privilege('service_role', 'public.fn_generate_game_series_occurrences(uuid)', 'EXECUTE')::text || '|' ||
  has_function_privilege('authenticated', 'public.fn_generate_game_series_occurrences(uuid)', 'EXECUTE')::text);
SELECT pg_temp.chk('H6 [=]', 'anon calling rpc_update_game is refused', 'ERR 42501',
  pg_temp.as_('anon', NULL, format($s$SELECT public.rpc_update_game(%L, '2027-03-02 18:00+00', '2027-03-02 20:00+00', p_title => 'x')$s$, :G06)));
SELECT pg_temp.chk('H7 [K]', 'service_role cannot call kan712_wrap_rpc / kan712_unwrap_rpc / read kan712_wrapped_rpcs', 'ERR 42501|ERR 42501|ERR 42501',
  pg_temp.as_('service_role', NULL, $s$SELECT public.kan712_wrap_rpc('public.rpc_cancel_game(uuid,text)'::regprocedure, 'game:p_game_id')::text$s$) || '|' ||
  pg_temp.as_('service_role', NULL, $s$SELECT public.kan712_unwrap_rpc('rpc_cancel_game', 'p_game_id uuid, p_reason text')::text$s$) || '|' ||
  pg_temp.as_('service_role', NULL, $s$SELECT count(*)::text FROM public.kan712_wrapped_rpcs$s$));
SELECT pg_temp.chk('H8 [K]', 'every wrapper: SECURITY DEFINER, search_path pinned, kan712.contract=on', '11',
  pg_temp.q($s$SELECT count(*)::text FROM public.kan712_wrapped_rpcs w JOIN pg_proc p ON p.pronamespace = 'public'::regnamespace
     AND p.proname = w.name AND pg_get_function_identity_arguments(p.oid) = w.identity_args
    WHERE p.prosecdef AND 'search_path=""' = ANY (p.proconfig) AND 'kan712.contract=on' = ANY (p.proconfig)$s$));

-- I. The fail-closed writer scan (cutover 4d), seen failing on a planted writer ------------------------------
CREATE FUNCTION pg_temp.scan() RETURNS text LANGUAGE sql AS $s$
  SELECT coalesce(string_agg(p.oid::regprocedure::text, ', ' ORDER BY p.oid::regprocedure::text), '<none>')
    FROM pg_proc p
   WHERE p.pronamespace = 'public'::regnamespace
     AND p.proname NOT LIKE 'kan711\_%' AND p.proname NOT LIKE 'kan712\_%' AND p.proname NOT LIKE '%\_kan712\_inner'
     AND (
       p.prosrc ~* '\mupdate\s+(only\s+)?("?public"?\s*\.\s*)?"?(games|meetups)\M'
       OR (p.prosrc ~* '\m(insert\s+into|delete\s+from)\s+(only\s+)?("?public"?\s*\.\s*)?"?(games|meetups)\M'
           AND p.proname NOT IN ('rpc_create_game', 'rpc_create_game_legacy_v1', 'rpc_create_game_legacy_v2',
                                 'rpc_create_meetup', 'rpc_create_meetup_legacy_v1', 'rpc_create_meetup_legacy_v2',
                                 'rpc_challenge_spawn_game', 'admin_cleanup_user_data'))
     ) $s$;
SELECT pg_temp.chk('I1 [K]', 'writer scan is clean after cutover', '<none>', pg_temp.scan());
CREATE FUNCTION public.kan_probe_bad_writer() RETURNS void LANGUAGE sql AS $s$ UPDATE public.meetups SET title = title WHERE false $s$;
CREATE FUNCTION public.kan_probe_bad_deleter() RETURNS void LANGUAGE sql AS $s$ DELETE FROM "public"."games" WHERE false $s$;
SELECT pg_temp.chk('I2 [=]', 'writer scan catches a planted UPDATE writer and a quoted DELETE writer', 'kan_probe_bad_deleter(), kan_probe_bad_writer()',
  (SELECT string_agg(x, ', ' ORDER BY x) FROM unnest(string_to_array(pg_temp.scan(), ', ')) x WHERE x LIKE 'kan_probe%'));
DROP FUNCTION public.kan_probe_bad_writer();
DROP FUNCTION public.kan_probe_bad_deleter();

-- J. Global state after all of the above -----------------------------------------------------------------
SELECT pg_temp.chk('J1 [=]', 'parity view: 0 rows (events = legacy for every linked row)', '0', (SELECT count(*)::text FROM public.kan711_events_parity));
SELECT pg_temp.chk('J2 [=]', 'no events row without a legacy child, no legacy row without its parent', '0|0',
  (SELECT count(*)::text FROM public.events e WHERE NOT EXISTS (SELECT 1 FROM public.games g WHERE g.id = e.id)
      AND NOT EXISTS (SELECT 1 FROM public.meetups m WHERE m.id = e.id)) || '|' ||
  ((SELECT count(*) FROM public.games g WHERE NOT EXISTS (SELECT 1 FROM public.events e WHERE e.id = g.id))
   + (SELECT count(*) FROM public.meetups m WHERE NOT EXISTS (SELECT 1 FROM public.events e WHERE e.id = m.id)))::text);
SELECT pg_temp.chk('J3 [=]', 'updated_at equal on every linked row', '0',
  ((SELECT count(*) FROM public.games g JOIN public.events e USING (id) WHERE g.updated_at IS DISTINCT FROM e.updated_at)
   + (SELECT count(*) FROM public.meetups m JOIN public.events e USING (id) WHERE m.updated_at IS DISTINCT FROM e.updated_at))::text);

SELECT format('%s|%s|expected=%s|actual=%s|%s', id, verdict, expected, actual, name) FROM res ORDER BY n;
SELECT format('#TOTAL|pass=%s|fail=%s', count(*) FILTER (WHERE verdict = 'PASS'), count(*) FILTER (WHERE verdict = 'FAIL')) FROM res;
ROLLBACK;
