-- Close two exposure holes found by the CTO (CEO approved 2026-10-08). Team Luxor.
--
-- Record of what was applied to project wtncuzcskpigqpmnxwws on 2026-10-08, as
-- one REVOKE per execute_sql call (nothing else was created, altered or dropped).
--
-- 1) Legacy functions kept after renames were still callable by clients.
--    rpc_get_nearby_games_legacy_v1 and _v2 are SECURITY DEFINER and predate the
--    block guard, so any caller could use them to see public games of hosts who
--    blocked them (a bypass of rpc_get_nearby_games). Before this change:
--      rpc_get_nearby_games_legacy_v1  EXECUTE: PUBLIC, anon, authenticated, postgres, service_role
--      rpc_get_nearby_games_legacy_v2  EXECUTE: PUBLIC, anon, authenticated, postgres, service_role
--      rpc_get_nearby_venues_legacy_v1 EXECUTE: PUBLIC, anon, authenticated, postgres, service_role
--      rpc_get_nearby_venues_legacy_v2 EXECUTE: anon, authenticated, postgres, service_role
--    (the venues ones are SECURITY INVOKER, revoked for the same reason: nothing calls them).
--    All other *_legacy_v* functions were already postgres/service_role only
--    (rpc_get_nearby_games_legacy_v3, rpc_create_game_legacy_v1, rpc_update_game_legacy_v1,
--     rpc_create_meetup_legacy_v1, toggle_venue_favorite_legacy_v1 x2,
--     fn_activity_favorites_sync_legacy_v1).
--    The app does not reference any legacy name: grep for `_legacy_v[0-9]` in lib/,
--    supabase/functions/ and test/ returned 0 hits on origin/Alpha 1e214dd0.
--
-- 2) rpc_update_game was executable by anon (EXECUTE: anon, authenticated, postgres,
--    service_role); the intended grant is authenticated + service_role only.
--
-- After this change every *_legacy_v* function is executable by postgres and
-- service_role only; rpc_update_game by authenticated, postgres and service_role.
--
-- Reported, NOT changed: rpc_create_game is still executable by anon
-- (EXECUTE: anon, authenticated, postgres, service_role), unlike rpc_create_meetup
-- (authenticated only). An anon call fails safely today: its first statement is
-- choose_actor(p_actor_type), which raises 'not_authenticated' when
-- effective_actor_uid() is null. The anon grant looks unintended and is worth
-- revoking in a separate decision.

REVOKE ALL ON FUNCTION public.rpc_get_nearby_games_legacy_v1(double precision, double precision, integer, uuid, text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.rpc_get_nearby_games_legacy_v2(double precision, double precision, integer, uuid, text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.rpc_get_nearby_venues_legacy_v1(double precision, double precision, integer, uuid, text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.rpc_get_nearby_venues_legacy_v2(double precision, double precision, integer, uuid, text, boolean, numeric, numeric) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.rpc_update_game(uuid, timestamp with time zone, timestamp with time zone, text, uuid, boolean, text, text, boolean, boolean, integer, integer, boolean, jsonb, integer, integer, numeric) FROM PUBLIC, anon;
