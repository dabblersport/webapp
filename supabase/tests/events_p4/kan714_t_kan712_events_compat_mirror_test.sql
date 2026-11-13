-- KAN-924 live check for supabase/migrations/*_kan714_t_kan712_events_compat_mirror.sql. Read-only; run as postgres.
--   T0 trigger trg_zz_kan712_events_compat_mirror is gone from public.events
--   T1 function public.kan712_events_compat_mirror() is gone
--   T2 the meetups guard and after-delete triggers are untouched (present, enabled)
--   T3 games and events (game) pair 1:1, with no drift on the 22 shared columns
-- Before the migration T0 and T1 read "not ok" (seen 2026-11-13); after it, all ok.
SELECT string_agg(CASE WHEN ok THEN 'ok ' ELSE 'not ok ' END || n || ' - ' || label, E'\n' ORDER BY n) AS tap FROM (
  SELECT 0 n, NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgrelid = 'public.events'::regclass AND tgname = 'trg_zz_kan712_events_compat_mirror') ok, 'trg_zz_kan712_events_compat_mirror dropped' label
  UNION ALL SELECT 1, to_regprocedure('public.kan712_events_compat_mirror()') IS NULL, 'kan712_events_compat_mirror() dropped'
  UNION ALL SELECT 2, (SELECT count(*) FROM pg_trigger WHERE tgrelid = 'public.meetups'::regclass AND tgenabled = 'O'
                        AND tgname IN ('trg_zz_kan712_meetups_guard', 'trg_zz_kan712_meetups_after_delete')) = 2, 'meetups guard + after-delete untouched'
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
