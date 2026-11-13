-- KAN-919 live check for supabase/migrations/*_kan714_t_trg_zz_kan712_games_after_delete.sql. Read-only; run as postgres.
--   T0 trigger trg_zz_kan712_games_after_delete is gone from public.games
--   T1 function public.kan712_legacy_after_delete() is kept and still attached to public.meetups (enabled)
--   T2 no KAN-712 / KAN-713 trigger is left on public.games, and no function deletes from games directly
--   T3 games and events (game) pair 1:1, with no drift on the 22 shared columns
-- Before the migration T0 and T2 read "not ok" (seen 2026-11-13); after it, all ok.
SELECT string_agg(CASE WHEN ok THEN 'ok ' ELSE 'not ok ' END || n || ' - ' || label, E'\n' ORDER BY n) AS tap FROM (
  SELECT 0 n, NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgrelid = 'public.games'::regclass AND tgname = 'trg_zz_kan712_games_after_delete') ok, 'trg_zz_kan712_games_after_delete dropped' label
  UNION ALL SELECT 1, EXISTS (SELECT 1 FROM pg_trigger WHERE tgrelid = 'public.meetups'::regclass AND tgname = 'trg_zz_kan712_meetups_after_delete'
                               AND tgenabled = 'O' AND tgfoid = to_regprocedure('public.kan712_legacy_after_delete()')), 'kan712_legacy_after_delete() kept for meetups'
  UNION ALL SELECT 2, NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgrelid = 'public.games'::regclass AND (tgname LIKE 'trg_zz_kan712_%' OR tgname LIKE 'trg_kan713_%'))
                  AND NOT EXISTS (SELECT 1 FROM pg_proc WHERE pronamespace = 'public'::regnamespace AND prosrc ~* 'delete\s+from\s+(public\.)?games\M'), 'no kan712/kan713 trigger on games; no direct games delete'
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
