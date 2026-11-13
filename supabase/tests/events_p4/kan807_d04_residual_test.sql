-- KAN-807 (supporting KAN-778 / KAN-719, a KAN-781 finding): proof for
--   20261104110900_kan807_d04_residual_a.sql and 20261104111000_kan807_d04_residual_b.sql.
--
-- LOCAL OR DISPOSABLE DATABASES ONLY. Never run this against a hosted Supabase project (the guard refuses).
-- It COMMITS a small fixture and helper tables into the throwaway database; every case runs inside a subtransaction
-- that is rolled back (rating inserts, joins, the Z01 dry run), so each phase starts from the same state.
--
-- Scope: the 16 in-scope functions of KAN-807. The 8 the migrations rewrite are the "fixed" set; the other 8 are
-- run too, so the census (C1) of which really fail after Z01 comes from this run and not only from the KAN-781 log.
--
-- ROLES. Every case runs as the role a real caller has: `SET LOCAL ROLE authenticated` with request.jwt.claim.sub /
-- request.jwt.claims set (how the harness auth.uid() reads the caller), or `anon` with no subject, where that role
-- holds EXECUTE. kan711_events_map_* are EXECUTE-postgres-only and run as postgres.
--
-- Phases: pre (pre-image) / pre_z01 (pre-image after a Z01 dry run: fixed cases must be RED 42703) / migrations /
-- post (new body) / post_z01 (new body after Z01: must equal pre). Z01 dry run = every `...;  -- <seq>` statement of
-- 20261105100000_kan719_z01_remove_replaced_columns.sql, each in its own savepoint, in file order (as kan799/kan803).
--
-- Run (worktree root) on a database cloned from the KAN-781 judge chain + D04
-- (supabase/tests/events_p4/base781_with_d04.sh; supabase/tests/events_p4/build_kan807.sh builds it and runs this):
--   psql -X -h /tmp -p <port> -U postgres -d k807<x> -v ON_ERROR_STOP=1 -P pager=off -f supabase/tests/events_p4/kan807_d04_residual_test.sql
\set ON_ERROR_STOP 1
SET client_min_messages = notice;

DO $g$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'supabase_admin')
     OR EXISTS (SELECT 1 FROM pg_namespace WHERE nspname IN ('storage', 'realtime', 'supabase_functions')) THEN
    RAISE EXCEPTION 'KAN-807: this looks like a Supabase database; local or disposable database only';
  END IF;
  IF current_database() !~ '^(k788|k807)' THEN
    RAISE EXCEPTION 'KAN-807: database % is not a throwaway k788/k807 database; refusing', current_database();
  END IF;
  IF NOT (SELECT rolsuper FROM pg_roles WHERE rolname = current_user) THEN RAISE EXCEPTION 'KAN-807: run as a superuser'; END IF;
  IF to_regclass('public.k807_res') IS NOT NULL THEN RAISE EXCEPTION 'KAN-807: results already present; use a fresh DB'; END IF;
END $g$;

-- ---------------------------------------------------------------------------------------------------------
-- F. Fixture. Game R (73500000-...-0004, host a1) becomes a game that ended 2h ago, on venue space ee11 (venue
-- ee01), with a2 and a3 on the active roster: the one shape every rating path accepts. Written through events (the
-- KAN-712 compat mirror carries it to games), so KAN-711 parity holds; asserted below.
-- ---------------------------------------------------------------------------------------------------------
UPDATE public.events e SET start_at = now() - interval '3 hours', end_at = now() - interval '2 hours'
  FROM public.games g WHERE g.event_id = e.id AND g.id = '73500000-0000-0000-0000-000000000004';
UPDATE public.games SET venue_space_id = '00000000-0000-0000-0000-00000000ee11' WHERE id = '73500000-0000-0000-0000-000000000004';
INSERT INTO public.game_roster (game_id, user_id, profile_id, role, status) VALUES
  ('73500000-0000-0000-0000-000000000004', '00000000-0000-0000-0000-0000000000a2', '00000000-0000-0000-0000-0000000000b2', 'player', 'active'),
  ('73500000-0000-0000-0000-000000000004', '00000000-0000-0000-0000-0000000000a3', '00000000-0000-0000-0000-0000000000b3', 'player', 'active');
-- Eight fixture games of mixed visibility (public / followers / private / cancelled) move to their own point, so
-- rpc_get_nearby_games returns a complete, tie-free set there (the chain puts ~2,800 games on one point, and LIMIT 50
-- over those ties picks an arbitrary 50).
INSERT INTO public.geo_locations (id, area_id, location)
  VALUES ('00000000-0000-0000-0000-0000000807d1', '00000000-0000-0000-0000-0000000000c1', st_setsrid(st_makepoint(31.2, 30.0), 4326));
UPDATE public.events e SET geo_location_id = '00000000-0000-0000-0000-0000000807d1' FROM public.games g
 WHERE g.event_id = e.id AND g.id = ANY ('{71300000-0000-0000-0000-000000000001,71300000-0000-0000-0000-000000000002,71300000-0000-0000-0000-000000000003,71300000-0000-0000-0000-000000000004,73500000-0000-0000-0000-000000000001,73500000-0000-0000-0000-000000000006,73500000-0000-0000-0000-000000000007,73500000-0000-0000-0000-000000000008}'::uuid[]);
SELECT 'fixture R' AS k, g.id, g.start_at = e.start_at AND g.end_at = e.end_at AS games_events_parity, e.end_at < now() AS ended,
       g.venue_space_id, (SELECT count(*) FROM public.game_roster r WHERE r.game_id = g.id AND r.status = 'active') AS active_roster
  FROM public.games g JOIN public.events e ON e.id = g.event_id WHERE g.id = '73500000-0000-0000-0000-000000000004';
DO $fp$ DECLARE n bigint; BEGIN
  SELECT count(*) INTO n FROM public.games g JOIN public.events e ON e.id = g.event_id
   WHERE g.start_at IS DISTINCT FROM e.start_at OR g.end_at IS DISTINCT FROM e.end_at OR g.creator_user_id IS DISTINCT FROM e.creator_user_id
      OR g.is_cancelled IS DISTINCT FROM e.is_cancelled OR g.listing_visibility IS DISTINCT FROM e.listing_visibility
      OR g.geo_location_id IS DISTINCT FROM e.geo_location_id;
  IF n <> 0 THEN RAISE EXCEPTION 'KAN-807 F: % games rows break KAN-711 parity after the fixture', n; END IF;
END $fp$;

\set z01text `cat supabase/migrations/20261105100000_kan719_z01_remove_replaced_columns.sql`
CREATE TABLE public.k807_z01 AS
  SELECT ord, x[1] AS stmt, x[2]::int AS seq
    FROM (SELECT :'z01text'::text AS src) s, regexp_matches(src, '\n((?:ALTER|DROP) [^\n]*?);  -- (\d+)', 'g') WITH ORDINALITY AS r(x, ord);
SELECT 'z01 statements' AS k, count(*) AS n, count(*) FILTER (WHERE seq BETWEEN 601 AND 623) AS games_drop_columns FROM public.k807_z01;

CREATE TABLE public.k807_res (phase text, case_name text, outcome jsonb, PRIMARY KEY (phase, case_name));
CREATE TABLE public.k807_attr (phase text, fn text, attrs text, PRIMARY KEY (phase, fn));

-- Functions under test. fixed = rewritten by the two migrations.
CREATE TABLE public.k807_fns (fn text PRIMARY KEY, sig regprocedure, fixed boolean);
INSERT INTO public.k807_fns VALUES
  ('_can_view_game',               'public._can_view_game(uuid)', true),
  ('_is_game_host',                'public._is_game_host(uuid)', true),
  ('active_stream',                'public.active_stream(text[],text,integer,timestamptz,text,uuid)', true),
  ('rpc_get_activity_feed',        'public.rpc_get_activity_feed(text,integer,timestamptz)', true),
  ('rpc_get_nearby_games',         'public.rpc_get_nearby_games(double precision,double precision,integer,uuid,text,numeric)', true),
  ('rpc_rate_game',                'public.rpc_rate_game(uuid,uuid,jsonb,text)', true),
  ('rpc_rate_user',                'public.rpc_rate_user(uuid,uuid,uuid,jsonb,text)', true),
  ('rpc_rate_venue',               'public.rpc_rate_venue(uuid,uuid,uuid,jsonb,text)', true),
  ('_can_view_game_for_join',      'public._can_view_game_for_join(uuid)', false),
  ('_slot_conflicts_game',         'public._slot_conflicts_game(uuid,timestamptz,timestamptz)', false),
  ('game_slots_left',              'public.game_slots_left(uuid)', false),
  ('kan711_events_map_game',       'public.kan711_events_map_game(public.games)', false),
  ('kan711_events_map_meetup',     'public.kan711_events_map_meetup(public.meetups)', false),
  ('rpc_challenge_spawn_game',     'public.rpc_challenge_spawn_game(uuid,timestamptz,uuid)', false),
  ('rpc_join_game',                'public.rpc_join_game(text,uuid,uuid)', false),
  ('rpc_unified_search_sectioned', 'public.rpc_unified_search_sectioned(text,uuid,double precision,double precision,double precision,integer)', false);

-- Cases: (ord, name, fn, role, caller user suffix or NULL, query). Users a1 (host of every fixture game), a2/a3
-- (on R's roster), a5 (stranger); profiles b<n> belong to a<n>.
CREATE TABLE public.k807_cases (ord int PRIMARY KEY, name text UNIQUE, fn text REFERENCES public.k807_fns, role text, caller text, q text);
\set gids '''{71300000-0000-0000-0000-000000000001,71300000-0000-0000-0000-000000000002,71300000-0000-0000-0000-000000000003,71300000-0000-0000-0000-000000000004,73500000-0000-0000-0000-000000000001,73500000-0000-0000-0000-000000000004,73500000-0000-0000-0000-000000000006,73500000-0000-0000-0000-000000000007,73500000-0000-0000-0000-000000000008}'''
INSERT INTO public.k807_cases VALUES
  ( 1, 'cvg_host',        '_can_view_game', 'authenticated', 'a1', 'select x, public._can_view_game(x) from unnest(' || quote_literal(:gids) || '::uuid[]) x order by 1'),
  ( 2, 'cvg_rostered',    '_can_view_game', 'authenticated', 'a2', 'select x, public._can_view_game(x) from unnest(' || quote_literal(:gids) || '::uuid[]) x order by 1'),
  ( 3, 'cvg_stranger',    '_can_view_game', 'authenticated', 'a5', 'select x, public._can_view_game(x) from unnest(' || quote_literal(:gids) || '::uuid[]) x order by 1'),
  ( 4, 'cvg_anon',        '_can_view_game', 'anon',          NULL, 'select x, public._can_view_game(x) from unnest(' || quote_literal(:gids) || '::uuid[]) x order by 1'),
  ( 5, 'host_host',       '_is_game_host',  'authenticated', 'a1', 'select x, public._is_game_host(x) from unnest(' || quote_literal(:gids) || '::uuid[]) x order by 1'),
  ( 6, 'host_rostered',   '_is_game_host',  'authenticated', 'a2', 'select x, public._is_game_host(x) from unnest(' || quote_literal(:gids) || '::uuid[]) x order by 1'),
  ( 7, 'host_anon',       '_is_game_host',  'anon',          NULL, 'select x, public._is_game_host(x) from unnest(' || quote_literal(:gids) || '::uuid[]) x order by 1'),
  ( 8, 'stream_host',     'active_stream',  'authenticated', 'a1', 'select * from public.active_stream(null, null, 50)'),
  ( 9, 'stream_rostered', 'active_stream',  'authenticated', 'a2', 'select * from public.active_stream(null, null, 50)'),
  (10, 'stream_games',    'active_stream',  'authenticated', 'a2', 'select * from public.active_stream(array[''game_created'',''game_started'',''game_ended''], null, 50)'),
  (11, 'stream_meetups',  'active_stream',  'authenticated', 'a5', 'select * from public.active_stream(array[''meetup_created'',''meetup_started'',''meetup_completed''], null, 50)'),
  (12, 'stream_anon',     'active_stream',  'anon',          NULL, 'select * from public.active_stream(null, null, 50)'),
  (13, 'feed_host',       'rpc_get_activity_feed', 'authenticated', 'a1', 'select * from public.rpc_get_activity_feed(''all'', 50, null)'),
  (14, 'feed_rostered',   'rpc_get_activity_feed', 'authenticated', 'a2', 'select * from public.rpc_get_activity_feed(''all'', 50, null)'),
  (15, 'feed_anon',       'rpc_get_activity_feed', 'anon',          NULL, 'select * from public.rpc_get_activity_feed(''all'', 50, null)'),
  (16, 'nearby_host',     'rpc_get_nearby_games', 'authenticated', 'a1', 'select id, title, status, is_public, spots_remaining from public.rpc_get_nearby_games(30.0, 31.2, 5000, null, ''distance'', null) order by id'),
  (17, 'nearby_rostered', 'rpc_get_nearby_games', 'authenticated', 'a2', 'select id, title, status, is_public, spots_remaining from public.rpc_get_nearby_games(30.0, 31.2, 5000, null, ''distance'', null) order by id'),
  (18, 'nearby_stranger', 'rpc_get_nearby_games', 'authenticated', 'a5', 'select id, title, status, is_public, spots_remaining from public.rpc_get_nearby_games(30.0, 31.2, 5000, null, ''start'', null) order by id'),
  (19, 'nearby_anon',     'rpc_get_nearby_games', 'anon',          NULL, 'select id, title, status, is_public, spots_remaining from public.rpc_get_nearby_games(30.0, 31.2, 5000, null, ''distance'', null) order by id'),
  (20, 'rgame_ok',        'rpc_rate_game', 'authenticated', 'a2', 'select public.rpc_rate_game(''73500000-0000-0000-0000-000000000004'', ''00000000-0000-0000-0000-0000000000b2'', ''{}''::jsonb)'),
  (21, 'rgame_cancelled', 'rpc_rate_game', 'authenticated', 'a2', 'select public.rpc_rate_game(''73500000-0000-0000-0000-000000000008'', ''00000000-0000-0000-0000-0000000000b2'', ''{}''::jsonb)'),
  (22, 'rgame_not_in',    'rpc_rate_game', 'authenticated', 'a5', 'select public.rpc_rate_game(''73500000-0000-0000-0000-000000000004'', ''00000000-0000-0000-0000-0000000000b5'', ''{}''::jsonb)'),
  (23, 'rgame_anon',      'rpc_rate_game', 'anon',          NULL, 'select public.rpc_rate_game(''73500000-0000-0000-0000-000000000004'', ''00000000-0000-0000-0000-0000000000b2'', ''{}''::jsonb)'),
  (24, 'ruser_host',      'rpc_rate_user', 'authenticated', 'a2', 'select public.rpc_rate_user(''73500000-0000-0000-0000-000000000004'', ''00000000-0000-0000-0000-0000000000b2'', ''00000000-0000-0000-0000-0000000000a1'', ''{}''::jsonb)'),
  (25, 'ruser_player',    'rpc_rate_user', 'authenticated', 'a2', 'select public.rpc_rate_user(''73500000-0000-0000-0000-000000000004'', ''00000000-0000-0000-0000-0000000000b2'', ''00000000-0000-0000-0000-0000000000a3'', ''{}''::jsonb)'),
  (26, 'ruser_stranger',  'rpc_rate_user', 'authenticated', 'a2', 'select public.rpc_rate_user(''73500000-0000-0000-0000-000000000004'', ''00000000-0000-0000-0000-0000000000b2'', ''00000000-0000-0000-0000-0000000000a5'', ''{}''::jsonb)'),
  (27, 'ruser_cancelled', 'rpc_rate_user', 'authenticated', 'a2', 'select public.rpc_rate_user(''73500000-0000-0000-0000-000000000008'', ''00000000-0000-0000-0000-0000000000b2'', ''00000000-0000-0000-0000-0000000000a1'', ''{}''::jsonb)'),
  (28, 'ruser_anon',      'rpc_rate_user', 'anon',          NULL, 'select public.rpc_rate_user(''73500000-0000-0000-0000-000000000004'', ''00000000-0000-0000-0000-0000000000b2'', ''00000000-0000-0000-0000-0000000000a1'', ''{}''::jsonb)'),
  (29, 'rvenue_ok',       'rpc_rate_venue', 'authenticated', 'a2', 'select public.rpc_rate_venue(''73500000-0000-0000-0000-000000000004'', ''00000000-0000-0000-0000-00000000ee01'', ''00000000-0000-0000-0000-0000000000b2'', ''{}''::jsonb)'),
  (30, 'rvenue_mismatch', 'rpc_rate_venue', 'authenticated', 'a2', 'select public.rpc_rate_venue(''73500000-0000-0000-0000-000000000004'', ''00000000-0000-0000-0000-00000000ee02'', ''00000000-0000-0000-0000-0000000000b2'', ''{}''::jsonb)'),
  (31, 'rvenue_cancelled','rpc_rate_venue', 'authenticated', 'a2', 'select public.rpc_rate_venue(''73500000-0000-0000-0000-000000000008'', ''00000000-0000-0000-0000-00000000ee01'', ''00000000-0000-0000-0000-0000000000b2'', ''{}''::jsonb)'),
  (32, 'rvenue_anon',     'rpc_rate_venue', 'anon',          NULL, 'select public.rpc_rate_venue(''73500000-0000-0000-0000-000000000004'', ''00000000-0000-0000-0000-00000000ee01'', ''00000000-0000-0000-0000-0000000000b2'', ''{}''::jsonb)'),
  -- left (not rewritten): census only
  (40, 'join_view_auth',  '_can_view_game_for_join', 'authenticated', 'a2', 'select public._can_view_game_for_join(''73500000-0000-0000-0000-000000000004'')'),
  (41, 'join_view_anon',  '_can_view_game_for_join', 'anon',          NULL, 'select public._can_view_game_for_join(''73500000-0000-0000-0000-000000000001'')'),
  (42, 'slot_auth',       '_slot_conflicts_game', 'authenticated', 'a1', 'select public._slot_conflicts_game(''00000000-0000-0000-0000-00000000ee11'', now() - interval ''4 hours'', now())'),
  (43, 'slots_left_auth', 'game_slots_left', 'authenticated', 'a2', 'select public.game_slots_left(''73500000-0000-0000-0000-000000000001'')'),
  (44, 'map_game',        'kan711_events_map_game', 'postgres', NULL, 'select (public.kan711_events_map_game(g)).title from public.games g where g.id = ''73500000-0000-0000-0000-000000000001'''),
  (45, 'map_meetup',      'kan711_events_map_meetup', 'postgres', NULL, 'select (public.kan711_events_map_meetup(m)).title from public.meetups m order by m.id limit 1'),
  (46, 'spawn_unknown',   'rpc_challenge_spawn_game', 'authenticated', 'a1', 'select public.rpc_challenge_spawn_game(''00000000-0000-0000-0000-00000000dead'', now() + interval ''1 day'', null)'),
  (47, 'join_member',     'rpc_join_game', 'authenticated', 'a5', 'select * from public.rpc_join_game(''player'', ''73500000-0000-0000-0000-000000000003'')'),
  (48, 'search_auth',     'rpc_unified_search_sectioned', 'authenticated', 'a2', 'select public.rpc_unified_search_sectioned(''game'')'),
  (49, 'search_anon',     'rpc_unified_search_sectioned', 'anon',          NULL, 'select public.rpc_unified_search_sectioned(''game'')');

CREATE FUNCTION public.k807_uid(s text) RETURNS uuid LANGUAGE sql IMMUTABLE AS $f$
  SELECT CASE WHEN s IS NULL THEN NULL ELSE ('00000000-0000-0000-0000-0000000000' || s)::uuid END $f$;
CREATE FUNCTION public.k807_auth_uid_probe() RETURNS uuid LANGUAGE sql STABLE AS $f$ SELECT auth.uid() $f$;
GRANT EXECUTE ON FUNCTION public.k807_auth_uid_probe() TO anon, authenticated;

-- One case, inside the caller's subtransaction. Returns {n, md5, rows (when n <= 10)} or {error:{sqlstate,message}}.
CREATE FUNCTION public.k807_case(c public.k807_cases) RETURNS jsonb LANGUAGE plpgsql AS $f$
DECLARE r jsonb; d text; uid uuid := public.k807_uid(c.caller);
BEGIN
  BEGIN
    PERFORM set_config('request.jwt.claim.sub', coalesce(uid::text, ''), true);
    PERFORM set_config('request.jwt.claims', CASE WHEN uid IS NULL THEN jsonb_build_object('role', c.role)
                                                  ELSE jsonb_build_object('sub', uid, 'role', c.role) END::text, true);
    IF c.role <> 'postgres' THEN
      EXECUTE format('SET LOCAL ROLE %I', c.role);
      IF public.k807_auth_uid_probe() IS DISTINCT FROM uid OR current_user <> c.role THEN
        RAISE EXCEPTION 'k807 harness: caller not established';
      END IF;
    END IF;
    EXECUTE format('select coalesce(jsonb_agg(to_jsonb(q)), ''[]''::jsonb) from (%s) q', c.q) INTO r;
    RAISE EXCEPTION 'k807_ok' USING DETAIL = jsonb_build_object('n', jsonb_array_length(r), 'md5', md5(r::text),
                                                                'rows', CASE WHEN jsonb_array_length(r) <= 10 THEN r END)::text;
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM = 'k807_ok' THEN
      GET STACKED DIAGNOSTICS d = PG_EXCEPTION_DETAIL;
      RETURN d::jsonb;
    END IF;
    RETURN jsonb_build_object('error', jsonb_build_object('sqlstate', SQLSTATE, 'message', SQLERRM));
  END;
END $f$;

-- One phase: every case in its own rolled-back subtransaction, optionally after a Z01 dry run.
CREATE FUNCTION public.k807_phase(p_phase text, p_z01 boolean) RETURNS void LANGUAGE plpgsql AS $f$
DECLARE c public.k807_cases; s record; r jsonb; d text; skipped text[]; gone int; first boolean := true;
BEGIN
  FOR c IN SELECT * FROM public.k807_cases ORDER BY ord LOOP
    skipped := '{}';
    BEGIN
      IF p_z01 THEN
        FOR s IN SELECT seq, stmt FROM public.k807_z01 ORDER BY ord LOOP
          BEGIN EXECUTE s.stmt; EXCEPTION WHEN OTHERS THEN skipped := skipped || (s.seq || ':' || SQLSTATE); END;
        END LOOP;
        SELECT count(*) INTO gone FROM public.k807_z01 z WHERE z.seq BETWEEN 601 AND 623
           AND NOT EXISTS (SELECT 1 FROM pg_attribute a WHERE a.attrelid = 'public.games'::regclass AND NOT a.attisdropped
                            AND a.attname = substring(z.stmt FROM 'DROP COLUMN ([a-z_]+)'));
        IF gone <> 23 THEN RAISE EXCEPTION 'KAN-807: Z01 dry run removed only % of the 23 games columns', gone; END IF;
      END IF;
      r := public.k807_case(c);
      RAISE EXCEPTION 'k807_rollback' USING DETAIL = jsonb_build_object('r', r, 'skipped', to_jsonb(skipped), 'gone', gone)::text;
    EXCEPTION WHEN OTHERS THEN
      IF SQLERRM <> 'k807_rollback' THEN RAISE; END IF;
      GET STACKED DIAGNOSTICS d = PG_EXCEPTION_DETAIL;
    END;
    INSERT INTO public.k807_res VALUES (p_phase, c.name, (d::jsonb)->'r');
    IF p_z01 AND first THEN
      RAISE NOTICE 'KAN-807 % Z01 dry run: games columns removed %/23; harness-skipped (seq:sqlstate): %',
        p_phase, (d::jsonb)->'gone', (d::jsonb)->'skipped';
      first := false;
    END IF;
  END LOOP;
  IF current_user <> 'postgres' THEN RAISE EXCEPTION 'KAN-807: role leaked out of a case (%)', current_user; END IF;
END $f$;

-- Attribute snapshot for C4.
CREATE FUNCTION public.k807_snapshot(p_phase text) RETURNS void LANGUAGE sql AS $f$
  INSERT INTO public.k807_attr
  SELECT p_phase, f.fn,
         concat_ws(' | ', 'args=' || pg_get_function_identity_arguments(p.oid), 'ret=' || pg_get_function_result(p.oid),
                   'secdef=' || p.prosecdef, 'vol=' || p.provolatile::text, 'lang=' || l.lanname,
                   'config=' || coalesce(p.proconfig::text, 'NULL'), 'owner=' || pg_get_userbyid(p.proowner),
                   'acl=' || coalesce(p.proacl::text, 'NULL'))
    FROM public.k807_fns f JOIN pg_proc p ON p.oid = f.sig JOIN pg_language l ON l.oid = p.prolang
$f$;

-- ---------------------------------------------------------------------------------------------------------
-- T1 / T2 (C1): pre-images, before and after a Z01 dry run.
-- ---------------------------------------------------------------------------------------------------------
SELECT public.k807_snapshot('pre');
SELECT public.k807_phase('pre', false);
SELECT public.k807_phase('pre_z01', true);
\echo '== T1 pre and T2 pre_z01 per case (C1 census)'
SELECT c.ord, c.name, c.fn, c.role, f.fixed,
       coalesce(a.outcome->'error'->>'sqlstate', 'ok n=' || (a.outcome->>'n')) AS pre,
       coalesce(b.outcome->'error'->>'sqlstate' || ' ' || (b.outcome->'error'->>'message'), 'ok n=' || (b.outcome->>'n')) AS pre_z01
  FROM public.k807_cases c JOIN public.k807_fns f USING (fn)
  JOIN public.k807_res a ON a.case_name = c.name AND a.phase = 'pre'
  JOIN public.k807_res b ON b.case_name = c.name AND b.phase = 'pre_z01'
 ORDER BY c.ord;
\echo '== C1 per function: does the pre-image fail after Z01, for its realistic callers?'
SELECT f.fn, f.fixed,
       count(*) AS cases,
       count(*) FILTER (WHERE b.outcome->'error'->>'sqlstate' IN ('42703', '42P01')) AS z01_undefined_column_or_table,
       count(*) FILTER (WHERE b.outcome IS DISTINCT FROM a.outcome) AS z01_changed,
       string_agg(DISTINCT b.outcome->'error'->>'message', ' / ') AS z01_errors
  FROM public.k807_fns f JOIN public.k807_cases c USING (fn)
  JOIN public.k807_res a ON a.case_name = c.name AND a.phase = 'pre'
  JOIN public.k807_res b ON b.case_name = c.name AND b.phase = 'pre_z01'
 GROUP BY f.fn, f.fixed ORDER BY f.fixed DESC, f.fn;
DO $t2$ DECLARE x text; BEGIN
  SELECT string_agg(c.name, ', ') INTO x FROM public.k807_cases c JOIN public.k807_fns f USING (fn)
    JOIN public.k807_res a ON a.case_name = c.name AND a.phase = 'pre'
   WHERE f.fixed AND a.outcome->'error'->>'sqlstate' IN ('42703', '42P01', 'XX000');
  IF x IS NOT NULL THEN RAISE EXCEPTION 'KAN-807 T1 FAIL: pre-image errors before Z01 on %', x; END IF;
  SELECT string_agg(f.fn, ', ') INTO x FROM public.k807_fns f WHERE f.fixed AND NOT EXISTS (
    SELECT 1 FROM public.k807_cases c JOIN public.k807_res b ON b.case_name = c.name AND b.phase = 'pre_z01'
     WHERE c.fn = f.fn AND b.outcome->'error'->>'sqlstate' = '42703');
  IF x IS NOT NULL THEN RAISE EXCEPTION 'KAN-807 T2 FAIL: no 42703 after Z01 for fixed function(s) %', x; END IF;
  SELECT string_agg(c.name, ', ') INTO x FROM public.k807_cases c JOIN public.k807_fns f USING (fn)
    JOIN public.k807_res a ON a.case_name = c.name AND a.phase = 'pre'
    JOIN public.k807_res b ON b.case_name = c.name AND b.phase = 'pre_z01'
   WHERE f.fixed AND b.outcome IS DISTINCT FROM a.outcome AND b.outcome->'error'->>'sqlstate' IS DISTINCT FROM '42703';
  IF x IS NOT NULL THEN RAISE EXCEPTION 'KAN-807 T2 FAIL: fixed case(s) changed after Z01 other than by 42703: %', x; END IF;
  RAISE NOTICE 'KAN-807 T2 PASS (RED shown): every one of the 8 rewritten functions raises 42703 after Z01 with its pre-image';
END $t2$;

-- ---------------------------------------------------------------------------------------------------------
-- T3: the migrations (each its own BEGIN/COMMIT with pre/post-conditions).
-- ---------------------------------------------------------------------------------------------------------
\echo '== T3 apply 20261104110900_kan807_d04_residual_a.sql and 20261104111000_kan807_d04_residual_b.sql'
\i supabase/migrations/20261104110900_kan807_d04_residual_a.sql
\i supabase/migrations/20261104111000_kan807_d04_residual_b.sql
SELECT public.k807_snapshot('post');

-- ---------------------------------------------------------------------------------------------------------
-- T4 / T5 (C2, C3): new bodies, before and after a Z01 dry run. Fixed cases must equal pre, case by case.
-- ---------------------------------------------------------------------------------------------------------
SELECT public.k807_phase('post', false);
SELECT public.k807_phase('post_z01', true);
\echo '== T4 post and T5 post_z01: outcome per case vs pre'
SELECT c.ord, c.name, f.fixed, coalesce(a.outcome->'error'->>'sqlstate', 'ok n=' || (a.outcome->>'n') || ' md5=' || (a.outcome->>'md5')) AS pre,
       (a.outcome = b.outcome) AS post_equal, (a.outcome = z.outcome) AS post_z01_equal,
       coalesce(z.outcome->'error'->>'sqlstate' || ' ' || (z.outcome->'error'->>'message'), 'ok') AS post_z01
  FROM public.k807_cases c JOIN public.k807_fns f USING (fn)
  JOIN public.k807_res a ON a.case_name = c.name AND a.phase = 'pre'
  JOIN public.k807_res b ON b.case_name = c.name AND b.phase = 'post'
  JOIN public.k807_res z ON z.case_name = c.name AND z.phase = 'post_z01'
 ORDER BY c.ord;
DO $t5$ DECLARE x text; n int; BEGIN
  SELECT count(*) INTO n FROM public.k807_cases c JOIN public.k807_fns f USING (fn) WHERE f.fixed;
  SELECT string_agg(c.name || '@' || b.phase, ', ') INTO x FROM public.k807_cases c JOIN public.k807_fns f USING (fn)
    JOIN public.k807_res a ON a.case_name = c.name AND a.phase = 'pre'
    JOIN public.k807_res b ON b.case_name = c.name AND b.phase IN ('post', 'post_z01')
   WHERE f.fixed AND a.outcome IS DISTINCT FROM b.outcome;
  IF x IS NOT NULL OR n <> 32 THEN RAISE EXCEPTION 'KAN-807 T4/T5 FAIL: % fixed cases; differ from pre: %', n, x; END IF;
  RAISE NOTICE 'KAN-807 T4/T5 PASS (GREEN): all % cases of the 8 rewritten functions identical to the pre-image, before and after Z01', n;
END $t5$;

-- ---------------------------------------------------------------------------------------------------------
-- T6 (C4): attributes before vs after, all 16 functions (the 8 left ones must be untouched too).
-- ---------------------------------------------------------------------------------------------------------
\echo '== T6 / C4 attributes, pre vs post'
SELECT a.fn, a.attrs, (a.attrs = b.attrs) AS unchanged
  FROM public.k807_attr a JOIN public.k807_attr b ON (b.fn, b.phase) = (a.fn, 'post') WHERE a.phase = 'pre' ORDER BY 1;
DO $t6$ BEGIN
  IF (SELECT count(*) FROM public.k807_attr WHERE phase = 'pre') <> 16 OR (SELECT count(*) FROM public.k807_attr WHERE phase = 'post') <> 16
     OR EXISTS (SELECT 1 FROM public.k807_attr a LEFT JOIN public.k807_attr b ON (b.fn, b.phase) = (a.fn, 'post')
                 WHERE a.phase = 'pre' AND b.attrs IS DISTINCT FROM a.attrs) THEN
    RAISE EXCEPTION 'KAN-807 T6 FAIL: a signature, result, SECURITY attribute, search_path, owner or ACL changed';
  END IF;
  RAISE NOTICE 'KAN-807 T6 PASS: 16 functions (args, result, SECURITY, volatility, language, search_path, owner, ACL) unchanged';
END $t6$;

\echo 'KAN-807: ALL PASS'
