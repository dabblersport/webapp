-- KAN-922 live check for supabase/migrations/*_kan714_t_trg_kan713_games_b_joining.sql. Read-only; run as postgres.
--   T0 trigger trg_kan713_games_b_joining is gone from public.games
--   T1 its function public.kan713_games_joining() is kept (trigger-only drop)
--   T2 kan718_game_derive present, postgres-only
--   T3 games and events (game) pair 1:1, with no drift on the 22 shared columns
-- Before the migration T0 reads "not ok" (seen 2026-11-13); after it, all ok.
SELECT string_agg(CASE WHEN ok THEN 'ok ' ELSE 'not ok ' END || n || ' - ' || label, E'\n' ORDER BY n) AS tap FROM (
  SELECT 0 n, NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgrelid = 'public.games'::regclass AND tgname = 'trg_kan713_games_b_joining') ok, 'trg_kan713_games_b_joining dropped' label
  UNION ALL SELECT 1, to_regprocedure('public.kan713_games_joining()') IS NOT NULL, 'kan713_games_joining() kept'
  UNION ALL SELECT 2, (SELECT proacl::text FROM pg_proc WHERE oid = to_regprocedure('public.kan718_game_derive(public.games, public.games)')) = '{postgres=X/postgres}', 'kan718_game_derive present, postgres-only'
  UNION ALL SELECT 3, (SELECT count(*) FROM public.games) = (SELECT count(*) FROM public.events WHERE event_type = 'game')
                  AND NOT EXISTS (SELECT 1 FROM public.games g LEFT JOIN public.events e ON e.id = g.event_id AND e.event_type = 'game'
                                   WHERE e.id IS NULL
                                      OR ROW(g.creator_profile_id, g.creator_user_id, g.title, g.start_at, g.end_at, g.capacity,
                                             g.listing_visibility, g.join_policy, g.is_cancelled, g.cancelled_at, g.cancelled_reason,
                                             g.sport_id, g.area_id, g.geo_location_id, g.venue_id, g.min_skill::smallint, g.max_skill::smallint,
                                             g.joining_rule, g.cost_cover, g.request_id, g.created_at, g.updated_at)
                                         IS DISTINCT FROM
                                         ROW(e.creator_profile_id, e.creator_user_id, e.title, e.start_at, e.end_at, e.capacity,
                                             e.listing_visibility, e.join_policy, e.is_cancelled, e.cancelled_at, e.cancelled_reason,
                                             e.sport_id, e.area_id, e.geo_location_id, e.venue_id, e.min_skill, e.max_skill,
                                             e.joining_rule, e.cost_cover, e.request_id, e.created_at, e.updated_at)), 'games <-> events (game) 1:1, 0 drift'
) t;
