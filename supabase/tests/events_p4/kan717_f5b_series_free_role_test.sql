-- KAN-717 F5b live proof: a series occurrence gets what a single rpc_create_game call with the same inputs gets.
-- Runs on the hosted project as postgres (Supabase execute_sql or psql), entirely inside BEGIN ... ROLLBACK.
--
-- Caller: user a3ba3271 (profile 5eeb4305, persona_type 'contributor' with player + organiser rows).
-- Spaces: e561f01a (321 Sports, venue_spaces.joining_rule 'free'), a06ae2e0 (venue_spaces.joining_rule 'paid').
--
-- RED on the pre-image (rpc_create_game_series md5 7027ec32..., inner generator md5 6139fd55...):
--   probes 1-3: rpc_create_game_series never stored p_actor_type, and the generator mapped a contributor to
--   'player' first, so an organiser series produced casual occurrences (a single organiser game is hosted).
-- GREEN on the pre-image (pins, not fixes): probes 5-6. joining_rule/cost_cover come from the venue space in
--   rpc_create_game_legacy_v2 for both paths; price 0 at a 'paid' space is paid/paid for a single game too.
BEGIN;
SET LOCAL client_min_messages = warning;

CREATE TEMP TABLE k717f5b_tap (n int PRIMARY KEY, ok boolean NOT NULL, label text NOT NULL, detail text) ON COMMIT DROP;
CREATE TEMP TABLE k717f5b_out (k text PRIMARY KEY, v text) ON COMMIT DROP;

DO $t$
DECLARE
  c_padel uuid := '2502490a-0339-436c-8b5e-5ac1514606c9'; c_padel_v uuid := '490ce916-b984-4da5-af37-c0019402359e';
  c_s2 uuid := '4fd36109-12c2-4b17-a8a2-281be2b8649c';    c_s2_v uuid := '504fe171-6c89-4892-88eb-786db9db9b4d';
  c_free uuid := 'e561f01a-1cb7-447e-9355-5aa97e1fcef2';  c_paid uuid := 'a06ae2e0-2f6c-4937-833b-72f04cb5226f';
  c_geo uuid := 'fb768cbb-ac02-4867-9ee6-9aa0a09e4e7b';   c_area uuid := 'a0000000-0000-0000-0000-000000000023';
  v_t0 timestamptz := (date '2026-12-26' + time '18:00') AT TIME ZONE 'Asia/Dubai';
  v_err text; v_so uuid; v_sp uuid; v_go uuid; v_gf uuid; v_gp uuid;
BEGIN
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', 'a3ba3271-3556-4b4e-b15d-bc0851f8a64b', 'role', 'authenticated')::text, true);
    PERFORM set_config('request.jwt.claim.sub', 'a3ba3271-3556-4b4e-b15d-bc0851f8a64b', true);
    SET LOCAL ROLE authenticated;
    v_so := public.rpc_create_game_series('organiser', c_padel, c_padel_v, c_geo, c_area, date '2026-12-12',
        time '18:00', 90, 'Asia/Dubai', 'weekly', 4, 'F5b organiser series', c_free, date '2026-12-19',
        'private', 'link', 4, 0::numeric);
    v_sp := public.rpc_create_game_series('player', c_s2, c_s2_v, c_geo, c_area, date '2026-12-12',
        time '18:00', 60, 'Asia/Dubai', 'weekly', 10, 'F5b player series paid space', c_paid, date '2026-12-19',
        'private', 'link', 4, 0::numeric);
    v_go := public.rpc_create_game('organiser', c_padel, c_padel_v, 'F5b organiser single', c_free, v_t0,
        v_t0 + interval '90 minutes', 0, 'private', 'link', NULL, NULL, NULL, NULL, false, false, NULL, NULL,
        c_geo, c_area, NULL, NULL, NULL, 4, 0::numeric, NULL);
    v_gf := public.rpc_create_game('player', c_padel, c_padel_v, 'F5b player single free', c_free,
        v_t0 + interval '3 hours', v_t0 + interval '270 minutes', 0, 'private', 'link', NULL, NULL, NULL, NULL,
        false, false, NULL, NULL, c_geo, c_area, NULL, NULL, NULL, 4, 0::numeric, NULL);
    v_gp := public.rpc_create_game('player', c_s2, c_s2_v, 'F5b player single paid space', c_paid, v_t0,
        v_t0 + interval '60 minutes', 0, 'private', 'link', NULL, NULL, NULL, NULL, false, false, NULL, NULL,
        c_geo, c_area, NULL, NULL, NULL, 10, 0::numeric, NULL);
    RESET ROLE;
  EXCEPTION WHEN OTHERS THEN
    v_err := 'ERR ' || SQLSTATE || ' ' || SQLERRM;
  END;
  RESET ROLE;
  PERFORM set_config('request.jwt.claims', '', true);
  PERFORM set_config('request.jwt.claim.sub', '', true);
  INSERT INTO pg_temp.k717f5b_out VALUES ('s_org', v_so::text), ('s_ply', v_sp::text), ('g_org', v_go::text),
    ('g_ply_free', v_gf::text), ('g_ply_paid', v_gp::text), ('err', v_err);
END $t$;

-- One row per created game: which bucket it is in, and what the app reads (events parent + games row).
CREATE TEMP TABLE k717f5b_g ON COMMIT DROP AS
SELECT o.k, g.id, g.game_type, g.price_aed, g.creator_profile_id, e.joining_rule, e.cost_cover
  FROM pg_temp.k717f5b_out o
  JOIN public.games g ON (o.k IN ('s_org', 's_ply') AND g.series_id = o.v::uuid)
                      OR (o.k LIKE 'g\_%' AND g.id = o.v::uuid)
  JOIN public.events e ON e.id = g.id AND e.event_type = 'game';

INSERT INTO pg_temp.k717f5b_tap
SELECT 1, (SELECT s.game_type FROM public.game_series s WHERE s.id = (SELECT v::uuid FROM k717f5b_out WHERE k='s_org'))
          IS NOT DISTINCT FROM 'hosted', 'organiser series stores game_type hosted',
       (SELECT s.game_type FROM public.game_series s WHERE s.id = (SELECT v::uuid FROM k717f5b_out WHERE k='s_org'))
UNION ALL
SELECT 2, (SELECT count(*) FROM k717f5b_g WHERE k='s_org') = 2
          AND NOT EXISTS (SELECT 1 FROM k717f5b_g WHERE k='s_org' AND game_type <> 'hosted'),
       'organiser series: 2 occurrences, all hosted',
       (SELECT count(*) || ' ' || coalesce(string_agg(DISTINCT game_type, ','), '-') FROM k717f5b_g WHERE k='s_org')
UNION ALL
SELECT 3, (SELECT count(*) FROM k717f5b_g WHERE k='s_org') > 0 AND NOT EXISTS (
             SELECT 1 FROM k717f5b_g a, k717f5b_g b WHERE a.k='s_org' AND b.k='g_org'
              AND ROW(a.game_type, a.creator_profile_id, a.joining_rule, a.cost_cover, a.price_aed)
                  IS DISTINCT FROM ROW(b.game_type, b.creator_profile_id, b.joining_rule, b.cost_cover, b.price_aed)),
       'organiser occurrence = single organiser game (type, profile, joining_rule, cost_cover, price)',
       (SELECT string_agg(k || ':' || game_type || '/' || joining_rule || '/' || cost_cover, ' ' ORDER BY k)
          FROM (SELECT DISTINCT k, game_type, joining_rule, cost_cover FROM k717f5b_g WHERE k IN ('s_org','g_org')) x)
UNION ALL
SELECT 4, (SELECT s.game_type FROM public.game_series s WHERE s.id = (SELECT v::uuid FROM k717f5b_out WHERE k='s_ply')) IS NOT DISTINCT FROM 'casual'
          AND (SELECT count(*) FROM k717f5b_g WHERE k='s_ply') = 2
          AND NOT EXISTS (SELECT 1 FROM k717f5b_g WHERE k='s_ply' AND game_type <> 'casual'),
       'player series unchanged: game_type casual, 2 casual occurrences',
       (SELECT count(*) || ' ' || coalesce(string_agg(DISTINCT game_type, ','), '-') FROM k717f5b_g WHERE k='s_ply')
UNION ALL
SELECT 5, (SELECT count(*) FROM k717f5b_g WHERE k='s_org') > 0
          AND NOT EXISTS (SELECT 1 FROM k717f5b_g WHERE k='s_org' AND (joining_rule, cost_cover) <> ('free', 'free'))
          AND NOT EXISTS (SELECT 1 FROM k717f5b_g a, k717f5b_g b WHERE a.k='s_org' AND b.k='g_ply_free'
                           AND (a.joining_rule, a.cost_cover) IS DISTINCT FROM (b.joining_rule, b.cost_cover)),
       'price 0, free space: occurrences free/free = single game at the same space',
       (SELECT string_agg(DISTINCT k || ':' || joining_rule || '/' || cost_cover, ' ') FROM k717f5b_g WHERE k IN ('s_org','g_ply_free'))
UNION ALL
SELECT 6, (SELECT count(*) FROM k717f5b_g WHERE k='s_ply') > 0
          AND NOT EXISTS (SELECT 1 FROM k717f5b_g a, k717f5b_g b WHERE a.k='s_ply' AND b.k='g_ply_paid'
                           AND ROW(a.game_type, a.joining_rule, a.cost_cover, a.price_aed)
                               IS DISTINCT FROM ROW(b.game_type, b.joining_rule, b.cost_cover, b.price_aed)),
       'price 0, paid space: occurrence = single game at the same space (both paths agree)',
       (SELECT string_agg(DISTINCT k || ':' || joining_rule || '/' || cost_cover || '/' || price_aed, ' ') FROM k717f5b_g WHERE k IN ('s_ply','g_ply_paid'))
UNION ALL
SELECT 7, (SELECT v FROM k717f5b_out WHERE k='err') IS NULL, 'all creates return without error',
       coalesce((SELECT v FROM k717f5b_out WHERE k='err'), 'ok')
UNION ALL
SELECT 8, (SELECT p.proacl::text || '|' || p.prosecdef || '|' || array_to_string(p.proconfig, ',')
             FROM pg_proc p WHERE p.oid =
             'public.rpc_create_game_series(text,uuid,uuid,uuid,uuid,date,time without time zone,integer,text,text,integer,text,uuid,date,text,text,integer,numeric)'::regprocedure)
          = '{postgres=X/postgres,authenticated=X/postgres,service_role=X/postgres}|true|search_path=public, pg_temp',
       'rpc_create_game_series ACL/secdef/search_path unchanged', NULL;

SELECT string_agg(CASE WHEN ok THEN 'ok ' ELSE 'not ok ' END || n || ' - ' || label
                  || CASE WHEN detail IS NOT NULL THEN ' [' || detail || ']' ELSE '' END, E'\n' ORDER BY n)
       || E'\n# ' || count(*) FILTER (WHERE ok) || '/' || count(*) || ' passed' AS tap
  FROM pg_temp.k717f5b_tap;

ROLLBACK;
