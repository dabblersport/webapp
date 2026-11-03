# KAN-740 (KAN-715 F05): active write-path manifest for games/meetups

Status: READ-ONLY CLASSIFICATION + GUARD TEST. No lib/ code changed, nothing deleted, no SQL, nothing applied.
Base: origin/Alpha merged into `alpha-karnak` (includes `KAN712_MUTATION_INVENTORY.md`, whose D1-D4 this confirms).
Guard: `test/features/games/active_write_paths_test.dart` (run: `flutter test test/features/games/active_write_paths_test.dart`).

## 1. Legacy repository classification

`lib/data/repositories/games_repository_impl.dart` (`GamesRepositoryImpl extends BaseRepository`): **DEAD, not active.**

- Importers: none in `lib/` or `test/` (grep for `games_repository_impl` and the package path; asserted by the guard test).
- Two other files share the class name and are the live ones: `lib/features/games/data/repositories/games_repository_impl.dart`
  (imported by `lib/features/games/providers/games_providers.dart:20`, delegates to the datasource) and
  `lib/data/repositories/nearby_games_repository_impl.dart` (a different file, imported by `nearby_games_providers.dart:6`).
  Neither is the file classified here, so "no importers" holds for the legacy file only.
- Direct writes in the dead file: `:91` insert, `:194` update, `:223` update (all `.from('games')`, via `table`). Payloads use
  `host_profile_id` / `host_user_id` / `sport`, columns games does not have.
- Kept as-is: deletion is phase 4 cleanup, out of scope.

## 2. Direct writes to shared games/meetups tables in `lib/` (the manifest)

| # | File:line | Op | State | Why it does not succeed today |
|---|---|---|---|---|
| L1 | `lib/data/repositories/games_repository_impl.dart:91` | insert | dead file | unreachable |
| L2 | same `:194` | update | dead file | unreachable |
| L3 | same `:223` | update | dead file | unreachable |
| D1 | `lib/features/games/data/datasources/supabase_games_datasource.dart:204` (`createGame`) | insert | reachable via the active repository | games has RLS and no write policy; payload has non-existent columns (KAN-712 inventory D1) |
| D2 | same `:437` (`updateGame`) | update | reachable | same RLS denial (D2) |
| D3 | same `:688` (`cancelGame`) | update status/cancelled_at | reachable | same RLS denial; correct path is `rpc_cancel_game` (D3) |
| D4 | `lib/features/profile/services/data_retention_service.dart:317` | delete | reachable | RLS denial; filters on `creator_id`, not a games column (D4) |

Meetups: zero direct table writes in `lib/` (reads via `v_meetup_list`, writes via RPC only; KAN-712 D5).

The live write surface is RPC only (KAN-712 inventory section 4 D6): `rpc_create_game`, `rpc_update_game`, series RPCs,
`rpc_create_meetup`, `rpc_meetup_update`, `rpc_meetup_cancel`. No change here.

## 3. The guard

The test scans every `lib/**/*.dart` (comments stripped) for `.from(<games|meetups table>).insert|update|upsert|delete(` and requires the
result to equal the table above exactly (3 / 3 / 1 sites). A new direct write fails the test; removing a known one also fails it, so this
manifest and the test map are updated together. It also asserts: meetups have no direct writes, the legacy file has no importers, and a game
record with null title/end/sport parses with `id` (games.id) and `organizerId` (creator_profile_id) intact.

## 4. Limitations and findings (reported, not fixed)

1. D1-D4 are still in active-reachable code. The guard names them rather than removes them; removing or re-pointing them is a separate lib/ change.
2. `GameModel.fromJson` (the active read parse) substitutes values for nulls: title `'Untitled Game'`, sport `'football'`, end = start + 1h,
   capacity 10, `created_at`/`updated_at` = now. That conflicts with the contract "invent no names, sports, end times". The test does not pin those
   values. Fixing it changes shared model behaviour and is outside this ticket's planned surfaces.
3. The scan is textual (a `.from(...)` immediately followed by a write call). A write built through an alias or a stored query variable would not
   be seen. None exists today.

## 5. Handoff

- Changed files: `test/features/games/active_write_paths_test.dart`, this file. Migrations: none. Applied: nothing. Rollback: delete the two files.
- Checks: `flutter test test/features/games/active_write_paths_test.dart` (4 tests pass); `flutter analyze --no-pub --no-fatal-infos` exit 0.
