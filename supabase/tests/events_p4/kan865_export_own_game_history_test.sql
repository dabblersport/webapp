-- KAN-880 (supports KAN-865) probe for public.export_own_game_history()
-- (20261105130000_kan865_export_own_game_history.sql). CTO ruling dreq-5087907b point 1.
--
-- LOCAL THROWAWAY PG16 ONLY (refuses any database not named k880*, and anything that looks like Supabase).
-- Output is TAP. pgTAP / pg_prove are not installed on this machine, so, like kan718_f6_drop_retired_meetup_rpcs_test.sql,
-- the TAP lines are emitted by plain SQL and the file runs under perl's prove:
--   prove -v --exec 'psql -X -q -tA -h /tmp -p <port> -U postgres -d k880 -f' supabase/tests/events_p4/kan865_export_own_game_history_test.sql
--
-- CHAIN (tracked files only; the build_kan851.sh chain through step 6, postgres superuser, no demotion needed):
--   events_p1/local_harness_kan711.sql, events_p1/local_seed_kan711.sql, events_p2/local_harness_kan712.sql,
--   events_p2_kan713/local_harness_kan713.sql, events_p2_kan714/local_harness_kan714.sql, then migrations
--   20261101140000, 20261102110000, 20261102120000 (+ CALL kan711_events_backfill_run(); kan711_events_validate_links()),
--   20261103100000. RED = this file before 20261105130000; GREEN = after it.
--
-- HARNESS ALIGNMENT (inside the transaction, rolled back): the local harness game_roster has no joined_at column;
-- production has it (live information_schema 2026-11-04: game_id, profile_id, user_id, role, status, joined_at,
-- left_at, id). It is added with ADD COLUMN IF NOT EXISTS so the function's my_roster can be exercised.
--
-- Every call runs as role authenticated with request.jwt.claim.sub = the caller (auth.uid() stub). Errors are caught
-- per call and reported as {"sqlstate": ...}, so a missing function gives "not ok" lines rather than an abort.
--
-- Tests (one transaction, ROLLBACK at the end):
--   T1 creator-only user: exactly their 2 games, newest created_at first (G2, G1), my_roster NULL on both.
--   T2 creator-only user: the row carries event_id = id = the game id, event_type 'game', title, creator_user_id,
--      game_type and rules (retained games column) from the seeded game.
--   T3 non-game events excluded: the same user's meetup is not returned; every row is event_type 'game'.
--   T4 joined-only user: their 2 joined games (G3 newer, then G1), my_roster = exactly
--      {user_id, joined_at, status, role} of their own roster row.
--   T5 unrelated user: zero rows (and no error).
--   T6 null auth.uid(): raises SQLSTATE 28000.
--   T7 key set: a row's keys = every column games has in this database (the old games.* select) + event_type + my_roster.
--   T8 authenticated holds EXECUTE (the one GRANT).
\set ON_ERROR_STOP 1

DO $g$ BEGIN
  IF current_database() !~ '^k880' THEN
    RAISE EXCEPTION 'kan880 probe: refusing database % (local k880* only)', current_database();
  END IF;
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'supabase_admin')
     OR EXISTS (SELECT 1 FROM pg_namespace WHERE nspname IN ('storage', 'realtime', 'supabase_functions')) THEN
    RAISE EXCEPTION 'kan880 probe: this looks like a Supabase database; refusing';
  END IF;
END $g$;

BEGIN;
SET LOCAL TimeZone = 'UTC';

CREATE TEMP TABLE _tap (n int, ok boolean, label text);

ALTER TABLE public.game_roster ADD COLUMN IF NOT EXISTS joined_at timestamptz DEFAULT now();

-- Users: C creator-only, J joined-only, X unrelated, H host of G3 (seed-independent).
INSERT INTO auth.users (id) VALUES
  ('88000000-0000-0000-0000-0000000000c0'), ('88000000-0000-0000-0000-0000000000a0'),
  ('88000000-0000-0000-0000-0000000000f0'), ('88000000-0000-0000-0000-0000000000b0');
INSERT INTO public.profiles (id, user_id) VALUES
  ('88000000-0000-0000-0000-0000000001c0', '88000000-0000-0000-0000-0000000000c0'),
  ('88000000-0000-0000-0000-0000000001a0', '88000000-0000-0000-0000-0000000000a0'),
  ('88000000-0000-0000-0000-0000000001f0', '88000000-0000-0000-0000-0000000000f0'),
  ('88000000-0000-0000-0000-0000000001b0', '88000000-0000-0000-0000-0000000000b0');

-- G1, G2 by C (G2 created later); G3 by H, created latest. Sport/geo/area from the KAN-711 seed.
INSERT INTO public.games (id, game_type, title, creator_profile_id, creator_user_id, start_at, end_at, capacity,
  rules, sport_id, geo_location_id, area_id, created_at, updated_at)
VALUES
 ('88000000-0000-0000-0000-000000000001', 'pickup', 'K880 G1', '88000000-0000-0000-0000-0000000001c0',
  '88000000-0000-0000-0000-0000000000c0', '2026-03-01 18:00+00', '2026-03-01 19:00+00', 10, '{"k": "g1"}',
  '00000000-0000-0000-0000-0000000000e1', '00000000-0000-0000-0000-0000000000d1', '00000000-0000-0000-0000-0000000000c1',
  '2025-01-01 10:00+00', '2025-01-01 10:00+00'),
 ('88000000-0000-0000-0000-000000000002', 'casual', 'K880 G2', '88000000-0000-0000-0000-0000000001c0',
  '88000000-0000-0000-0000-0000000000c0', '2026-02-01 18:00+00', '2026-02-01 19:00+00', 8, '{}',
  '00000000-0000-0000-0000-0000000000e1', '00000000-0000-0000-0000-0000000000d1', '00000000-0000-0000-0000-0000000000c1',
  '2025-02-01 10:00+00', '2025-02-01 10:00+00'),
 ('88000000-0000-0000-0000-000000000003', 'league', 'K880 G3', '88000000-0000-0000-0000-0000000001b0',
  '88000000-0000-0000-0000-0000000000b0', '2026-01-01 18:00+00', '2026-01-01 19:00+00', 12, '{}',
  '00000000-0000-0000-0000-0000000000e1', '00000000-0000-0000-0000-0000000000d1', '00000000-0000-0000-0000-0000000000c1',
  '2025-03-01 10:00+00', '2025-03-01 10:00+00');

-- A meetup by C, created newest of all: must never appear (non-game event).
INSERT INTO public.meetups (id, creator_profile_id, creator_user_id, title, start_at, host_actor_id, created_at, updated_at)
VALUES ('88000000-0000-0000-0000-000000000004', '88000000-0000-0000-0000-0000000001c0',
        '88000000-0000-0000-0000-0000000000c0', 'K880 meetup', '2026-04-01 06:00+00',
        '88000000-0000-0000-0000-0000000001c0', '2025-04-01 10:00+00', '2025-04-01 10:00+00');

-- J's own roster rows on G1 and G3. Only C is on nothing (creator-only); X is on nothing and created nothing.
INSERT INTO public.game_roster (game_id, user_id, profile_id, role, status, joined_at) VALUES
 ('88000000-0000-0000-0000-000000000001', '88000000-0000-0000-0000-0000000000a0', '88000000-0000-0000-0000-0000000001a0',
  'player', 'active', '2025-01-05 12:00+00'),
 ('88000000-0000-0000-0000-000000000003', '88000000-0000-0000-0000-0000000000a0', '88000000-0000-0000-0000-0000000001a0',
  'player', 'left', '2025-03-05 12:00+00');

-- Fixture sanity (fails loudly, it is not a test): the setup produced what the tests assume.
DO $f$ BEGIN
  IF (SELECT count(*) FROM public.events WHERE id IN ('88000000-0000-0000-0000-000000000001',
        '88000000-0000-0000-0000-000000000002', '88000000-0000-0000-0000-000000000003') AND event_type = 'game') <> 3
     OR NOT EXISTS (SELECT 1 FROM public.events WHERE id = '88000000-0000-0000-0000-000000000004' AND event_type = 'meetup')
     OR EXISTS (SELECT 1 FROM public.game_roster WHERE user_id IN ('88000000-0000-0000-0000-0000000000c0',
        '88000000-0000-0000-0000-0000000000f0')) THEN
    RAISE EXCEPTION 'kan880 probe: fixture not as assumed (events parents / roster)';
  END IF;
END $f$;

-- One call as role authenticated with auth.uid() = p_uid (NULL = no JWT). Returns the rows as a jsonb array in
-- the function's own output order, or {"sqlstate": ..., "message": ...} when the call raises.
CREATE FUNCTION pg_temp.k880_call(p_uid uuid) RETURNS jsonb LANGUAGE plpgsql AS $c$
DECLARE v jsonb;
BEGIN
  PERFORM set_config('request.jwt.claim.sub', coalesce(p_uid::text, ''), true);
  SET LOCAL ROLE authenticated;
  BEGIN
    EXECUTE $q$SELECT coalesce(jsonb_agg(to_jsonb(r) - 'ordinality' ORDER BY r.ordinality), '[]'::jsonb)
                 FROM public.export_own_game_history() WITH ORDINALITY r$q$ INTO v;
  EXCEPTION WHEN OTHERS THEN
    v := jsonb_build_object('sqlstate', SQLSTATE, 'message', SQLERRM);
  END;
  RESET ROLE;
  RETURN v;
END $c$;

CREATE TEMP TABLE _r AS
SELECT 'C'::text AS who, pg_temp.k880_call('88000000-0000-0000-0000-0000000000c0') AS v
UNION ALL SELECT 'J', pg_temp.k880_call('88000000-0000-0000-0000-0000000000a0')
UNION ALL SELECT 'X', pg_temp.k880_call('88000000-0000-0000-0000-0000000000f0')
UNION ALL SELECT 'N', pg_temp.k880_call(NULL);

SELECT (SELECT v FROM _r WHERE who = 'C') AS c, (SELECT v FROM _r WHERE who = 'J') AS j,
       (SELECT v FROM _r WHERE who = 'X') AS x, (SELECT v FROM _r WHERE who = 'N') AS nul \gset

INSERT INTO _tap VALUES
 (1, jsonb_typeof(:'c'::jsonb) = 'array'
     AND (SELECT array_agg(e ->> 'event_id' ORDER BY o) FROM jsonb_array_elements(:'c'::jsonb) WITH ORDINALITY t(e, o))
         = ARRAY['88000000-0000-0000-0000-000000000002', '88000000-0000-0000-0000-000000000001']
     AND (SELECT bool_and(e -> 'my_roster' = 'null'::jsonb) FROM jsonb_array_elements(:'c'::jsonb) e),
  'T1 creator-only: own 2 games, created_at DESC (G2, G1), my_roster NULL'),
 (2, coalesce((SELECT e ->> 'id' = '88000000-0000-0000-0000-000000000001'
                  AND e ->> 'event_type' = 'game'
                  AND e ->> 'title' = 'K880 G1'
                  AND e ->> 'creator_user_id' = '88000000-0000-0000-0000-0000000000c0'
                  AND e ->> 'creator_profile_id' = '88000000-0000-0000-0000-0000000001c0'
                  AND e ->> 'game_type' = 'pickup'
                  AND e -> 'rules' = '{"k": "g1"}'::jsonb
                  AND (e ->> 'created_at')::timestamptz = '2025-01-01 10:00+00'
                  AND (e ->> 'end_at')::timestamptz = '2026-03-01 19:00+00'
                  AND (e ->> 'capacity')::int = 10
                FROM jsonb_array_elements(CASE WHEN jsonb_typeof(:'c'::jsonb) = 'array' THEN :'c'::jsonb ELSE '[]' END) e
               WHERE e ->> 'event_id' = '88000000-0000-0000-0000-000000000001'), false),
  'T2 creator-only: G1 row carries id = event_id, event_type, events fields and retained games fields'),
 (3, jsonb_typeof(:'c'::jsonb) = 'array'
     AND NOT EXISTS (SELECT 1 FROM jsonb_array_elements(:'c'::jsonb) e
                      WHERE e ->> 'event_id' = '88000000-0000-0000-0000-000000000004' OR e ->> 'event_type' <> 'game')
     AND NOT EXISTS (SELECT 1 FROM jsonb_array_elements(:'j'::jsonb) e WHERE e ->> 'event_type' <> 'game'),
  'T3 non-game events excluded (the creator''s meetup is absent)'),
 (4, jsonb_typeof(:'j'::jsonb) = 'array'
     AND (SELECT array_agg(e ->> 'event_id' ORDER BY o) FROM jsonb_array_elements(:'j'::jsonb) WITH ORDINALITY t(e, o))
         = ARRAY['88000000-0000-0000-0000-000000000003', '88000000-0000-0000-0000-000000000001']
     AND (SELECT e -> 'my_roster' FROM jsonb_array_elements(:'j'::jsonb) e
           WHERE e ->> 'event_id' = '88000000-0000-0000-0000-000000000001')
         = jsonb_build_object('user_id', '88000000-0000-0000-0000-0000000000a0',
                              'joined_at', '2025-01-05T12:00:00+00:00', 'status', 'active', 'role', 'player')
     AND (SELECT e -> 'my_roster' ->> 'status' FROM jsonb_array_elements(:'j'::jsonb) e
           WHERE e ->> 'event_id' = '88000000-0000-0000-0000-000000000003') = 'left',
  'T4 joined-only: 2 joined games (G3, G1) with my_roster = own roster row {user_id, joined_at, status, role}'),
 (5, :'x'::jsonb = '[]'::jsonb,
  'T5 unrelated user: zero rows'),
 (6, :'nul'::jsonb ->> 'sqlstate' = '28000',
  'T6 null auth.uid() raises SQLSTATE 28000'),
 (7, jsonb_typeof(:'c'::jsonb) = 'array' AND jsonb_array_length(:'c'::jsonb) > 0
     AND (SELECT array_agg(k ORDER BY k) FROM jsonb_object_keys(:'c'::jsonb -> 0) k)
         = (SELECT array_agg(k ORDER BY k) FROM (
              SELECT column_name::text FROM information_schema.columns
               WHERE table_schema = 'public' AND table_name = 'games'
              UNION SELECT 'event_type' UNION SELECT 'my_roster') s(k)),
  'T7 keys = every games column (old games.*) + event_type + my_roster'),
 (8, coalesce(has_function_privilege('authenticated', to_regprocedure('public.export_own_game_history()'), 'EXECUTE'), false),
  'T8 authenticated holds EXECUTE');

SELECT '1..' || count(*) FROM _tap;
SELECT CASE WHEN ok IS TRUE THEN 'ok ' ELSE 'not ok ' END || n || ' - ' || label FROM _tap ORDER BY n;
SELECT '# C: ' || left(:'c', 200);
SELECT '# N: ' || :'nul';
SELECT '# proacl: ' || coalesce((SELECT proacl::text FROM pg_proc WHERE oid = to_regprocedure('public.export_own_game_history()')), '(no function)');

ROLLBACK;
