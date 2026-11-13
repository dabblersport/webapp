-- KAN-920 live check for supabase/migrations/20261111122201_kan714_t_trg_kan711_games_mirror.sql. Read-only; run as postgres.
--   T0 trigger trg_kan711_games_mirror is gone from public.games
--   T1 function public.kan711_games_mirror() is gone
--   T2 its callees and the meetups counterpart are untouched
--   T3 the live games write path is intact: the KAN-712 guard and after-delete triggers are present and enabled
--   T4 games and events (game) still pair 1:1
-- Before the migration T0 and T1 read "not ok" (seen 2026-11-13); after it, all ok.
SELECT string_agg(CASE WHEN ok THEN 'ok ' ELSE 'not ok ' END || n || ' - ' || label, E'\n' ORDER BY n) AS tap FROM (
  SELECT 0 n, NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgrelid = 'public.games'::regclass AND tgname = 'trg_kan711_games_mirror') ok, 'trg_kan711_games_mirror dropped' label
  UNION ALL SELECT 1, to_regprocedure('public.kan711_games_mirror()') IS NULL, 'kan711_games_mirror() dropped'
  UNION ALL SELECT 2, to_regprocedure('public.kan711_events_upsert(public.events)') IS NOT NULL
                  AND to_regprocedure('public.kan711_meetups_mirror()') IS NOT NULL
                  AND EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'kan711_events_map_game' AND pronamespace = 'public'::regnamespace), 'callees and meetups mirror untouched'
  UNION ALL SELECT 3, (SELECT count(*) FROM pg_trigger WHERE tgrelid = 'public.games'::regclass AND tgenabled = 'O'
                        AND tgname IN ('trg_zz_kan712_games_guard', 'trg_zz_kan712_games_after_delete')) = 2, 'KAN-712 guard + after-delete present and enabled'
  UNION ALL SELECT 4, (SELECT count(*) FROM public.games g LEFT JOIN public.events e ON e.id = g.event_id AND e.event_type = 'game' WHERE e.id IS NULL) = 0
                  AND (SELECT count(*) FROM public.games) = (SELECT count(*) FROM public.events WHERE event_type = 'game'), 'games <-> events (game) 1:1'
) t;
