-- KAN-717 F5 live proof: rpc_create_game_series as a unified-account (contributor) user.
-- Runs on the hosted project as postgres (Supabase execute_sql or psql), entirely inside BEGIN ... ROLLBACK:
-- the series, its occurrences, their events parents and roster rows are undone by the final ROLLBACK.
--
-- Reproduces the KAN-717 web journey call of 2026-11-13 14:56:05 UTC as user a3ba3271 (profile 5eeb4305,
-- persona_type 'contributor' with player + organiser extension rows): Padel Doubles at 321 Sports, Sat
-- 2026-11-28 18:00 Asia/Dubai, weekly until 2026-12-05, private, join policy link, free.
-- RED on the pre-image: fn_generate_game_series_occurrences_kan712_inner passed profiles.persona_type
-- ('contributor') to rpc_create_game as p_actor_type; rpc_create_game_legacy_v2's KAN-440 gate admits a
-- contributor only for p_actor_type 'player'/'organiser' and raised P0001 persona_not_allowed.
BEGIN;
SET LOCAL client_min_messages = warning;

CREATE TEMP TABLE k717f5_tap (n int PRIMARY KEY, ok boolean NOT NULL, label text NOT NULL, detail text) ON COMMIT DROP;
CREATE TEMP TABLE k717f5_out (k text PRIMARY KEY, v text) ON COMMIT DROP;

DO $t$
DECLARE v_sid uuid; v_err text;
BEGIN
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', 'a3ba3271-3556-4b4e-b15d-bc0851f8a64b', 'role', 'authenticated')::text, true);
    PERFORM set_config('request.jwt.claim.sub', 'a3ba3271-3556-4b4e-b15d-bc0851f8a64b', true);
    SET LOCAL ROLE authenticated;
    v_sid := public.rpc_create_game_series(
      'player', '2502490a-0339-436c-8b5e-5ac1514606c9'::uuid, '490ce916-b984-4da5-af37-c0019402359e'::uuid,
      'fb768cbb-ac02-4867-9ee6-9aa0a09e4e7b'::uuid, 'a0000000-0000-0000-0000-000000000023'::uuid,
      date '2026-11-28', time '18:00', 90, 'Asia/Dubai', 'weekly', 4,
      'KAN717 F5 probe series', 'e561f01a-1cb7-447e-9355-5aa97e1fcef2'::uuid, date '2026-12-05',
      'private', 'link', 4, 0::numeric);
    RESET ROLE;
  EXCEPTION WHEN OTHERS THEN
    v_err := 'ERR ' || SQLSTATE || ' ' || SQLERRM;
  END;
  RESET ROLE;
  PERFORM set_config('request.jwt.claims', '', true);
  PERFORM set_config('request.jwt.claim.sub', '', true);
  INSERT INTO pg_temp.k717f5_out VALUES ('sid', v_sid::text), ('err', v_err);
END $t$;

CREATE TEMP TABLE k717f5_g ON COMMIT DROP AS
SELECT g.id, g.event_id, g.creator_profile_id, g.game_type, g.start_at
  FROM public.games g WHERE g.series_id = (SELECT v::uuid FROM pg_temp.k717f5_out WHERE k = 'sid');

INSERT INTO pg_temp.k717f5_tap
SELECT 1, (SELECT v FROM k717f5_out WHERE k='err') IS NULL, 'rpc_create_game_series returns without error',
       coalesce((SELECT v FROM k717f5_out WHERE k='err'), 'ok')
UNION ALL
SELECT 2, EXISTS (SELECT 1 FROM public.game_series s WHERE s.id = (SELECT v::uuid FROM k717f5_out WHERE k='sid')
                    AND s.creator_profile_id = '5eeb4305-9277-458e-a56f-a5ed77e3f208'),
       'series row created for the caller''s profile', (SELECT v FROM k717f5_out WHERE k='sid')
UNION ALL
SELECT 3, (SELECT count(*) FROM k717f5_g) = 2, 'two weekly occurrences (2026-11-28, 2026-12-05)',
       (SELECT count(*)::text FROM k717f5_g)
UNION ALL
SELECT 4, (SELECT count(*) FROM k717f5_g) > 0 AND (SELECT count(*) FROM k717f5_g g
             JOIN public.events e ON e.id = g.event_id AND e.event_type = 'game') = (SELECT count(*) FROM k717f5_g)
          AND (SELECT count(DISTINCT event_id) FROM k717f5_g) = (SELECT count(*) FROM k717f5_g),
       'events<->games paired 1:1', (SELECT string_agg(id::text || '>' || coalesce(event_id::text, 'null'), ' ') FROM k717f5_g)
UNION ALL
SELECT 5, (SELECT count(*) FROM k717f5_g) > 0 AND NOT EXISTS (SELECT 1 FROM k717f5_g
             WHERE creator_profile_id <> '5eeb4305-9277-458e-a56f-a5ed77e3f208' OR game_type <> 'casual'),
       'occurrences created by the caller''s profile as casual (actor player)',
       (SELECT string_agg(DISTINCT game_type, ',') FROM k717f5_g)
UNION ALL
SELECT 6, (SELECT count(*) FROM k717f5_g) > 0 AND (SELECT count(*) FROM k717f5_g g JOIN public.game_roster r
             ON r.game_id = g.id AND r.profile_id = g.creator_profile_id AND r.role = 'host' AND r.status = 'active')
          = (SELECT count(*) FROM k717f5_g),
       'creator is the active host on every occurrence', NULL
UNION ALL
SELECT 7, (SELECT p.proacl::text || '|' || p.prosecdef || '|' || array_to_string(p.proconfig, ',') || '|' || pg_get_userbyid(p.proowner)
             FROM pg_proc p WHERE p.oid = 'public.fn_generate_game_series_occurrences_kan712_inner(uuid)'::regprocedure)
          = '{postgres=X/postgres}|true|search_path=public, pg_temp|postgres',
       'inner generator ACL/secdef/search_path/owner unchanged', NULL
UNION ALL
SELECT 8, (SELECT p.proacl::text FROM pg_proc p WHERE p.oid =
             'public.rpc_create_game_series(text,uuid,uuid,uuid,uuid,date,time without time zone,integer,text,text,integer,text,uuid,date,text,text,integer,numeric)'::regprocedure)
          = '{postgres=X/postgres,authenticated=X/postgres,service_role=X/postgres}',
       'rpc_create_game_series ACL unchanged (no anon)', NULL;

SELECT string_agg(CASE WHEN ok THEN 'ok ' ELSE 'not ok ' END || n || ' - ' || label
                  || CASE WHEN detail IS NOT NULL THEN ' [' || detail || ']' ELSE '' END, E'\n' ORDER BY n)
       || E'\n# ' || count(*) FILTER (WHERE ok) || '/' || count(*) || ' passed' AS tap
  FROM pg_temp.k717f5_tap;

ROLLBACK;
