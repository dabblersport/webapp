# KAN-712 preflight: mutation-path inventory for public.games and public.meetups

Status: READ-ONLY INVENTORY. Nothing here is implemented. Static analysis of the repo at origin/Alpha `e7f788ec`
(KAN-710 schema included) against KAN-711's mirror triggers at `origin/alpha-luxor:supabase/migrations/20261102110000_kan711_events_mirror_triggers.sql`
(`b2903455`, in rework: updated_at sync and parity). No live database was queried, so "current definition" means "last
`CREATE FUNCTION` in `supabase/migrations/`", not what is deployed. Method: `grep` for INSERT/UPDATE/DELETE on games/meetups across
`supabase/` (migrations, functions, schema/archive), `.from(gamesTable|meetupsTable)` and `.rpc(...)` across `lib/`, then the enclosing
function of each hit. Re-run the grep when KAN-711 integrates, because a later migration can change a body.

Paths are in `supabase/migrations/` unless stated. "KAN-711 mirror" = the statement-independent triggers `trg_kan711_{games,meetups}_assign_event_id`
(BEFORE INSERT OR UPDATE, no column list) and `trg_kan711_{games,meetups}_mirror` (AFTER INSERT OR UPDATE OR DELETE, FOR EACH ROW, no column list)
(`20261102110000_...:187-203`). They fire on every row write by any role, so every path below goes through them. What differs is which columns
the mirror carries (mappers `kan711_events_map_game` / `_map_meetup`, `:56-96`).

## 1. Columns the mirror carries to events (per KAN-711 mappers)

- games -> events: id, creator_profile_id, creator_user_id, title, start_at, end_at, capacity, listing_visibility, join_policy, is_cancelled, cancelled_at,
  cancelled_reason, sport_id, area_id, geo_location_id, venue_id, min_skill, max_skill, joining_rule, cost_cover, request_id, created_at (`:56-70`).
- meetups -> events: same set; join_policy := rsvp_policy; cancelled_at and cancelled_reason fixed NULL (`:72-96`).
- Upsert compares and writes all of those except search_tsv and updated_at, which KAN-710 triggers own (`:101-141`). A write that changes only
  non-mirrored columns still fires the trigger, but the upsert is a no-op (`IS DISTINCT FROM` guard).
- NOT carried (stay on the subtype table): games: venue_space_id, rules, allow_spectators, allows_waitlist, price_aed, series_id, squad_id,
  game_type, sport_variant_id, bench_slots, sport_specific_data, status. meetups: description, location_name, members_only, vibe_key, meta, is_indoor.
  `updated_at` is the open KAN-711 rework item.

## 2. SQL write paths (migrations)

"Live?" is the repo's best answer: last definition, and whether a later migration revokes or drops it. Callable by clients = EXECUTE granted to authenticated.

| # | Path (function / statement) | file:line | Op | Shared columns written (moving to events) | Live? | KAN-711 mirror covers? |
|---|---|---|---|---|---|---|
| S1 | `rpc_create_game_legacy_v2` (25-arg body, renamed by KAN-611, persona gate patched by KAN-646) INSERT | `20261008140000_game_price_meetup_setting.sql:254` (body); rename `20261021120200_kan611_rpc_create_game_request_id.sql`; patch `20261026120000_kan646_personas_s3_capabilities.sql:113` | INSERT | title, creator_profile_id, creator_user_id, sport_id, venue_id, start_at, end_at, capacity, listing_visibility, join_policy, min_skill, max_skill, joining_rule, cost_cover, geo_location_id, area_id (and not-mirrored: venue_space_id, rules, price_aed, squad_id, ...) | Yes, only through S2 (legacy_v2 is not client-executable) | Yes, whole row on AFTER INSERT. request_id arrives through BEFORE-INSERT trigger `trg_games_stamp_request_id` (`20261021120000_kan611_request_id_columns.sql:58`), which sorts before `trg_kan711_*`, so the mirror sees it |
| S2 | `rpc_create_game` (client wrapper, KAN-611) -> S1 | `20261021120200_kan611_rpc_create_game_request_id.sql` (calls S1; reads games at `:50,:60`) | INSERT via S1 | as S1, plus request_id | Yes, client callable. Dart: `lib/features/games/presentation/controllers/game_creation_controller.dart:123`, `lib/features/games/presentation/screens/game_composer_screen.dart:876` | Yes (via S1) |
| S3 | `rpc_update_game` INSERT-free UPDATE | `20261008140000_game_price_meetup_setting.sql:315` | UPDATE | start_at, end_at, title, listing_visibility, join_policy, min_skill, max_skill, capacity (not mirrored: venue_space_id, allow_spectators, allows_waitlist, rules, price_aed) | Yes. Dart: `lib/features/games/presentation/screens/game_composer_screen.dart:803` | Yes (AFTER UPDATE; shared columns upserted) |
| S4 | `fn_generate_game_series_occurrences` -> `rpc_create_game` per occurrence, then `UPDATE games SET series_id` | `20261030140000_kan694_fix_same_day_topup.sql:72` (call), `:77` (UPDATE); earlier body `20261030120000_kan693_rpc_create_game_series.sql:78` is superseded | INSERT via S2, UPDATE | series_id only on the UPDATE (not a mirrored column; events has no series_id, KAN-710 series check reads games.series_id) | Yes. Reached by `rpc_create_game_series`: Dart `game_composer_screen.dart:823` | Insert: yes. series_id UPDATE: trigger fires, upsert is a no-op, correct. The KAN-710 series trigger `trg_games_series_occurrence_check` (on update of series_id, event_id) still applies |
| S5 | `rpc_edit_game_series_occurrence` UPDATE | `20261030130000_kan694_rpc_series_edit_cancel.sql:69` | UPDATE | title, start_at, end_at, capacity (not mirrored: venue_space_id; updated_at) | Yes, authenticated | Yes for the shared columns. updated_at: pending KAN-711 rework |
| S6 | `rpc_edit_game_series_future` UPDATE (loop over future games) | `20261030130000_kan694_rpc_series_edit_cancel.sql:142`. Dart: `lib/features/games/data/repositories/game_series_repository.dart:63` | UPDATE (many rows) | title, capacity, start_at, end_at (not mirrored: venue_space_id; updated_at) | Yes, authenticated | Yes, per row. Mirror cost scales with series length |
| S7 | `rpc_cancel_game_series` -> `PERFORM rpc_cancel_game(...)` per future game (no direct games write of its own) | `20261030130000_kan694_rpc_series_edit_cancel.sql:165-190`; Dart `game_series_repository.dart:78` | UPDATE via S8 | is_cancelled, cancelled_at, cancelled_reason | Yes | Yes (via S8) |
| S8 | `rpc_cancel_game` UPDATE (baseline body, never redefined) | `20260829080500_baseline_schema.sql:11246-11251` | UPDATE | is_cancelled, cancelled_at, cancelled_reason | Yes. No direct Dart call found in `lib/` (`rpcCancelGame...` const absent); reached through S7 | Yes. Legacy-vs-events cancel: events CHECKs on cancelled_at/reason (KAN-710) must hold, the mapper passes them as-is |
| S9 | `rpc_reschedule_game` UPDATE | `20260829080500_baseline_schema.sql:14986-14994` | UPDATE | start_at, end_at | Defined, no Dart caller found in `lib/`; no later migration revokes it, so assume client-callable | Yes |
| S10 | `rpc_booking_hold_for_game` UPDATE | `20260829080500_baseline_schema.sql:11148-11173` | UPDATE | none shared (venue_space_id only) | Defined, no Dart caller found | Trigger fires, upsert no-op. Correct, nothing to move |
| S11 | `rpc_challenge_spawn_game` INSERT | `20260829080500_baseline_schema.sql:11599-11616` | INSERT | title, creator_profile_id, creator_user_id, start_at, end_at (start+90m), capacity 22, listing_visibility 'hidden', join_policy 'squad' (not mirrored: venue_space_id, game_type) | Defined, no Dart caller found | Yes (whole row). Not stamped with request_id (NULL) |
| S12 | `admin_cleanup_user_data` DELETE | `20260829080500_baseline_schema.sql:2223-2248` (copy under `supabase/schema/archive/fix_admin_functions_missing_auth_check.sql:126`, archive, not applied) | DELETE | row delete | Granted to anon/authenticated/service_role in baseline (`:34601-34604`); body checks admin | Yes: AFTER DELETE removes the events row. Check ordering: DELETE of the legacy row must precede or tolerate the deferred FK `games_event_id_fkey` ON DELETE CASCADE (KAN-710) |
| S13 | `rpc_create_meetup_legacy_v2` (20-arg, renamed by KAN-611) INSERT | `20261008140000_game_price_meetup_setting.sql:543` (superseded earlier bodies `20260915120000_meetups_hardening.sql:311`, baseline `:11815`) | INSERT | creator_profile_id, creator_user_id, sport_id, title, venue_id, geo_location_id, area_id, start_at, end_at, capacity, listing_visibility ('public'), rsvp_policy, min_skill, max_skill (not mirrored: description, location_name, members_only, vibe_key, meta, is_indoor) | Yes, only through S14 | Yes (whole row). request_id stamped by `trg_meetups_stamp_request_id` (`kan611_request_id_columns.sql:60`) before the mirror |
| S14 | `rpc_create_meetup` (client wrapper, KAN-611) -> S13 | `20261021120300_kan611_rpc_create_meetup_request_id.sql:43,53`. Dart: `lib/features/meetups/data/datasources/supabase_meetup_datasource.dart:116` | INSERT via S13 | as S13 plus request_id | Yes | Yes |
| S15 | `rpc_meetup_update` UPDATE | `20260915120000_meetups_hardening.sql:600` | UPDATE | title, start_at, end_at, capacity (not mirrored: description, location_name; updated_at) | Yes. Dart `supabase_meetup_datasource.dart:146` | Yes for the shared columns. updated_at pending rework |
| S16 | `rpc_meetup_cancel` UPDATE | `20260915120000_meetups_hardening.sql:390` (baseline copy `:13575` superseded) | UPDATE | is_cancelled (+ updated_at). cancelled_at / cancelled_reason do not exist on meetups | Yes. Dart `supabase_meetup_datasource.dart:138` | Yes. Mapper emits cancelled_at/reason NULL, matching KAN-710 meetup CHECK |
| S17 | `rpc_meetup_create` (old overloads) INSERT | `20260829080500_baseline_schema.sql:13712-13777` | INSERT | n/a | DROPPED by `20260915120000_meetups_hardening.sql:95-96`. Dead, listed so it is not re-found | n/a |

Writes by non-function SQL: none found outside the above in `supabase/migrations/`. `20260910100000_kan170_games_creator_user_id_fk.sql:291` is a comment.
`supabase/seed*` and non-migration SQL contain no games/meetups DML (checked). `supabase/schema/archive/*` holds old copies (`rpc_update_game.sql:62`,
`fix_admin_functions_missing_auth_check.sql:126`) and is not applied, so it is excluded from the migration targets.

Indirect write routes with no statement of their own, all covered because the triggers are row-level and role-independent:
- FK cascades: no FK found with ON DELETE CASCADE/SET NULL that deletes a games/meetups row. `20260910100000_kan170_games_creator_user_id_fk.sql` makes creator FKs restrictive.
  The only CASCADE referencing games/meetups points the other way (children of games/meetups, `20261008120000_games_listing_match1_card_fields.sql:116-117`).
- KAN-710 FK `games.event_id -> events(id) ON DELETE CASCADE`: deleting an events row deletes the legacy row. Not a path today (nothing deletes events), but it becomes one in KAN-712
  once events is authoritative, and AFTER DELETE then runs the mirror DELETE on an already-absent events row (harmless, `DELETE ... WHERE id = OLD.id AND event_type = ...`).

Not covered by any row trigger: `TRUNCATE`, and sessions with `session_replication_role = replica` (ops/migration sessions). Neither is used by repo code.

## 3. Edge functions (`supabase/functions/`)

No edge function writes games or meetups: `broadcast-notification`, `detect-country`, `send-export-email`, `send-push-notification`. The only matches are in
`send-push-notification/index.ts:361-383`, which SELECT `game_roster` / meetup RSVP ids. Result: no edge write paths.

## 4. Client (Dart) write paths

Direct table writes via PostgREST are RLS-blocked today, so they cannot succeed for `authenticated`; they are still code that targets the table and must be
removed or re-pointed when events is authoritative.

| # | Path | file:line | Op | Why it cannot / can write | KAN-711 mirror |
|---|---|---|---|---|---|
| D1 | `SupabaseGamesDataSource.createGame` -> `.from(gamesTable).insert(gameData)` | `lib/features/games/data/datasources/supabase_games_datasource.dart:199-206` (via `games_repository_impl.dart:53`) | INSERT | `games` has RLS enabled and no policy (`20261027120000_kan671_game_series.sql:8`), so authenticated INSERT is denied despite `GRANT INSERT, UPDATE, DELETE ... TO authenticated` (`20260901190000_kan86_revoke_and_scope_anon_authenticated_table_grants.sql:165`). Also writes columns (`host_profile_id`) that do not exist on games | n/a (denied) |
| D2 | `updateGame` -> `.update(updates)` | `supabase_games_datasource.dart:430-438` (via `games_repository_impl.dart:77`) | UPDATE | Same RLS denial | n/a (denied) |
| D3 | `cancelGame` -> `.update({status, cancelled_at})` | `supabase_games_datasource.dart:683-692` (via `games_repository_impl.dart:230`, `cancel_game_usecase.dart:67`, `games_providers.dart:577`) | UPDATE | Same RLS denial; `status` is not a mirrored column and the correct path is S8/S7 | n/a (denied) |
| D4 | `DataRetentionService` purge -> `.from(gamesTable).delete().eq('creator_id', ...)` | `lib/features/profile/services/data_retention_service.dart:317-320` | DELETE | Same RLS denial; filters on `creator_id`, which is not a games column (`creator_profile_id`/`creator_user_id`) | n/a (denied) |
| D5 | meetups: no `.from(meetupsTable)` writes found | `lib/` (meetups use `v_meetup_list` view reads and RPCs only); `meetups_no_direct_insert` policy `20260829080500_baseline_schema.sql:32566`, `FORCE ROW LEVEL SECURITY` `:23122` | none | n/a | n/a |
| D6 | RPC callers (the live client write surface) | create game `game_creation_controller.dart:123`, `game_composer_screen.dart:876`; update game `game_composer_screen.dart:803`; series `game_composer_screen.dart:823`, `game_series_repository.dart:63,78`; meetups `supabase_meetup_datasource.dart:116,138,146` | RPC | = S2, S3, S4, S6, S7, S14, S16, S15 | covered, see section 2 |

## 5. Findings for KAN-712 (inputs, not decisions)

1. Every live write converges on 8 client-callable RPCs: S2 (create game, with S1 inside), S3 (update game), S4 (series create, which calls S2), S5/S6 (series edit),
   S7 (series cancel, which calls S8), S14 (create meetup, with S13 inside), S15 (update meetup), S16 (cancel meetup). Dormant but still granted: S9, S10, S11, S12 (S12 is a destructive admin path).
2. Mirror coverage is complete for shared columns on every path above, because it hangs on the table, not the function. Gaps to settle in KAN-711/712, not
   covered by the mirror today: `updated_at` (rework item); `session_replication_role` and TRUNCATE; venue_space_id and the other subtype-only columns,
   which are intentionally not parent columns.
3. When events becomes authoritative, the write direction flips for exactly the shared columns in section 1. Rewrite targets: S1 (insert order and event_id), S3, S5, S6, S8, S9,
   S11, S13, S15, S16 (they set shared columns directly on the legacy table). S2, S4, S7, S14 only wrap those, and S10 writes no shared column.
4. D1 to D4 are dead client code against RLS-denied tables with column names that do not exist; they should be deleted or left, not ported. This is a `lib/` change and outside this preflight.
5. Ordering to preserve: BEFORE triggers on games are `trg_games_stamp_request_id` then `trg_kan711_games_assign_event_id` (name order); the AFTER mirror must stay after both
   so it sees request_id and event_id. KAN-712 should not add a trigger that sorts between them.
6. Unknown (needs live read, not available in this lane): deployed function bodies vs the repo; whether S9, S10, S11 are still callable; row counts. Memphis can confirm with a read-only
   `pg_proc` / `has_function_privilege` check.
