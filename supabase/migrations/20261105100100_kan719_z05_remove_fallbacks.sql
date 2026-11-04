-- KAN-782 (KAN-719 Z05, Epic KAN-708): remove residual fallback-to-old-column code after verified absence.
--
-- STATUS: authored, NOT applied to any Supabase project. Executed on a local throwaway PG 16 only
-- (supabase/tests/events_p4/kan719_z05_fallbacks.sql).
--
-- RESULT: DOCUMENTED NO-OP. Nothing on this chain qualifies for removal, so this migration changes no object and
-- no row. It is a single read-only DO block (no BEGIN/COMMIT, no DDL, no DML, no grant); applying it twice, or
-- before/after Z01, is harmless. Rollback: none needed (nothing to undo).
--
-- RULE (KAN-782 scope). A fallback = code that reads public.events AND falls back to / also reads a slated legacy
-- games/meetups column (outside the D06 retained list). It may be removed here only if the KAN-781 Z04 postcheck
-- (supabase/tests/events_p4/kan719_z04_postcheck.sql, KAN719_POSTCHECK.md) shows it unused: not EXECUTE/SELECT
-- granted to an API role, not on a trigger, not called, and its legacy column absent or never the source.
--
-- INVENTORY (catalogue scan, identical pre-Z01 and post-Z01-local on alpha-luxor 20b130b3):
--   HTP  - has_table_privilege('public.events','SELECT') switch; the ELSE branch reads the legacy column and is the
--          path every anon/authenticated caller takes (events has no client grant). All API-executable. KAN-781 S2
--          FAIL; game_slots_left is also KAN-781 M4 FAIL (42703 g.capacity post-Z01).
--            _can_view_game_for_join(uuid), _recent_activity_score(uuid,integer),
--            _slot_conflicts_game(uuid,timestamptz,timestamptz), _user_hosted_game(uuid,uuid),
--            game_is_joinable(uuid), game_slots_left(uuid)
--   DUAL - KAN-713 intersection (legacy predicate AND events predicate). All API-executable. KAN-781 S2 FAIL
--          (_can_view_game, _is_game_host, active_stream, rpc_get_nearby_games are also S3 FAIL).
--            _can_view_game(uuid), _is_game_host(uuid), active_stream(...), rpc_get_activity_feed(...),
--            rpc_get_nearby_games(...), rpc_rate_game(...), rpc_rate_user(...), rpc_rate_venue(...),
--            rpc_unified_search_sectioned(...)
--   HELD - rpc_meetup_card(uuid,text), v_meetup_list, kan718_meetups_compat read only meetups.description /
--          location_name / is_indoor, which have NO events home (Z01 gate G6). Not a fallback.
--   COALESCE coalesce(e.x, legacy.x): none. Every coalesce(e.…) on the chain is events-only (e.g. B02/B11/B12
--          coalesce(e.end_at, e.start_at)).
-- Every HTP/DUAL entry is LIVE and reads a removed column -> NOT removable here; it belongs to the kan714 parent
-- reads (owner PM/cto). Removing a branch now would change behaviour (client callers would raise 42501 on events)
-- instead of removing dead code.
--
-- ALSO NOT A FALLBACK, NOT TOUCHED: the KAN-713 policy legacy conjuncts (Z01 manifest 101-104, KAN-778); the
-- kan712_*_inner write bodies (KAN-781 "orphans", each called by its live KAN-712 wrapper); kan712_events_compat_mirror()
-- (events->legacy mirror, trigger dropped by Z01 stmt 334, function left by Z01: KAN-778's disposition);
-- trg_meetups_aaa_host_actor_stub (KAN-778/KAN-718); kan712_update_event_shared F5 55000 (KAN-778/KAN-718);
-- meetups.search_tsv (ruling po/cto).

DO $kan782$
BEGIN
  RAISE NOTICE 'KAN-782 Z05: no fallback qualifies for removal (inventory 6 HTP + 9 DUAL live, 1 HELD, 0 COALESCE); nothing changed';
END
$kan782$;
