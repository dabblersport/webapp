-- KAN-714 plans. LOCAL THROWAWAY POSTGRES ONLY. Read-only (ROLLBACK). Run on the pre-KAN-714 and post-KAN-714
-- copies of the same data (local harness: 3010 games + 2011 meetups = 5021 events) and compare.
-- Keyset pagination contract for the listing views: ORDER BY start_at, id with WHERE (start_at, id) > (:last_start, :last_id).
\set ON_ERROR_STOP 1
BEGIN;
ANALYZE public.events; ANALYZE public.games; ANALYZE public.meetups;
SELECT set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000a1', true) IS NULL AS _x \gset
SET LOCAL ROLE authenticated;
\echo '### Q1 v_game_card keyset page 1 (a1)'
EXPLAIN (ANALYZE, BUFFERS, COSTS OFF, TIMING ON, SUMMARY ON)
SELECT id, start_at FROM public.v_game_card WHERE start_at >= '2030-01-01' ORDER BY start_at, id LIMIT 25;
\echo '### Q2 v_game_card keyset page n (a1)'
EXPLAIN (ANALYZE, BUFFERS, COSTS OFF, TIMING ON, SUMMARY ON)
SELECT id, start_at FROM public.v_game_card WHERE (start_at, id) > ('2030-06-01 00:00+00', '00000000-0000-0000-0000-000000000000') ORDER BY start_at, id LIMIT 25;
\echo '### Q3 v_meetup_list keyset (a1)'
EXPLAIN (ANALYZE, BUFFERS, COSTS OFF, TIMING ON, SUMMARY ON)
SELECT id, start_at FROM public.v_meetup_list WHERE (start_at, id) > ('2030-01-01 00:00+00', '00000000-0000-0000-0000-000000000000') ORDER BY start_at, id LIMIT 25;
\echo '### Q4 rpc_sport_overview(football, all) (a1)'
EXPLAIN (ANALYZE, BUFFERS, COSTS OFF, TIMING ON, SUMMARY ON)
SELECT * FROM public.rpc_sport_overview('00000000-0000-0000-0000-0000000000e1');
\echo '### Q5 v_my_games (a1)'
EXPLAIN (ANALYZE, BUFFERS, COSTS OFF, TIMING ON, SUMMARY ON)
SELECT id FROM public.v_my_games ORDER BY start_at, id LIMIT 50;
RESET ROLE;
ROLLBACK;
