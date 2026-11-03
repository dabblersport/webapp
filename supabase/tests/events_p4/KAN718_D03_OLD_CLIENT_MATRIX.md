# KAN-718 D03: client reads of slated columns, and the old-client matrix

Ticket KAN-771 (Epic KAN-708, Events P4). Guard: `kan718_d03_client_scan_test.dart` in this folder
(run from the repo root: `flutter test supabase/tests/events_p4/kan718_d03_client_scan_test.dart`).

**Status: static scan only.** No lib/ code was changed, no SQL was written or applied, and production was not read.

## VERDICT: DELETION BLOCKED

The current app (Alpha, Canary, main) and every store build since 1.3.0 still read the `games` legacy shared columns
**directly from the table**. Dropping any slated `games` column breaks those reads in every installed build. No approved
compatibility arrangement exists for direct table reads:
- No view or RPC can stand in for `.from('games')`.
- No supported-version floor is enforced: `schema_meta.app_min_version` is parsed in `lib/data/models/schema_meta.dart` and read nowhere else.

The `meetups` slated columns have **no** direct client read in any build. The meetups part of the client is not a blocker.

## 1. Slated columns

These are the legacy columns that KAN-711 copies into `events` (`kan711_events_map_game` and `kan711_events_map_meetup` in
`20261102110000_kan711_events_mirror_triggers.sql`), minus `id`, which is retained. The test reads this list from the migration.

- **games (22):**
  - `creator_profile_id`, `creator_user_id`, `title`
  - `start_at`, `end_at`, `capacity`
  - `listing_visibility`, `join_policy`
  - `is_cancelled`, `cancelled_at`, `cancelled_reason`
  - `sport_id`, `area_id`, `geo_location_id`, `venue_id`
  - `min_skill`, `max_skill`, `joining_rule`, `cost_cover`
  - `request_id`, `created_at`, `updated_at`
- **meetups (20):** the same list without `join_policy`, `cancelled_at` and `cancelled_reason`, plus `rsvp_policy`.

`created_at`/`updated_at` are copied into `events`, but the KAN-718 retained-subtype list does not name them. Whether they are
actually dropped belongs to the deletion manifest (another D ticket). They are counted as slated here so no read of them is missed.

## 2. Static scan of lib/ (origin/Alpha + KAN-744 `1fc2e95b`)

### 2a. Direct `games` table reads: 18 sites, 5 files

| # | File:line | Read | Slated columns read | State today |
|---|---|---|---|---|
| G1 | `features/games/data/datasources/supabase_games_datasource.dart:56` | `.stream(primaryKey:['id'])` → `GameModel.fromJson` | all (row payload) | live |
| G2 | same `:154` | `select('capacity')` by id | `capacity` | live |
| G3 | same `:234` | `select('*')`, getGames with filters | all | live |
| G4 | same `:299` | `select('*')`, joinGame | all | live |
| G5 | same `:437` | `select('*')`, updateGame | all | live |
| G6 | same `:461` | `select('*')`, getGame | all | live |
| G7 | same `:508` | `select('id')`, filter `.eq('creator_user_id')` | `creator_user_id` (filter) | live |
| G8 | same `:538` | `select('*')`, getMyGames | all | live |
| G9 | same `:601` | `select('*')`, `.textSearch('title')` | all, `title` | live |
| G10 | same `:711` | `select('*')`, `.eq('sport')`, `.eq('is_cancelled')`, `.order('start_at')` | all | **fails today**: `games.sport` does not exist |
| G11 | same `:888` | `select('*, game_favorites!inner(user_id)')`, `.order('start_at')` | all | live |
| G12 | same `:925` | `select('*, game_roster!inner(user_id)')`, `.eq('is_cancelled')`, `.order('start_at')` | all | live |
| G13 | same `:975` | `select('capacity')` by id | `capacity` | live |
| G14 | `features/profile/presentation/providers/sport_profile_view_provider.dart:255` | `select('id, is_cancelled, start_at')`, filters `creator_user_id`, `sport_id` | `is_cancelled`, `start_at`, `creator_user_id`, `sport_id` | live |
| G15 | `features/profile/services/data_export_service.dart:647` | `select('*, game_roster!inner(...)')`, `.order('created_at')` | all | live |
| G16 | same `:1782` | `select()`, `.or('creator_id…,participants…')` | all | **fails today**: `creator_id` and `participants` do not exist |
| G17 | `data/repositories/post_repository_impl.dart:1429` | `select('id, title, sport, game_type, start_at, end_at')`, `.ilike('title')`, `.eq('is_cancelled')`, `.order('start_at')` | `title`, `start_at`, `end_at`, `is_cancelled` | **fails today**: `sport` does not exist |
| G18 | `features/profile/services/data_retention_service.dart:317` | `.delete()` filtered on `creator_id` | none read, but it filters on a column that does not exist | already RLS-denied (KAN-740 D4) |

"live" means a reachable file with a valid query. Per-method reachability from a screen was not traced: every site in a live
file is counted as a consumer.

### 2b. `games` embedded through another table: 7 sites

| File | Count | Embed | State today |
|---|---|---|---|
| `features/games/data/datasources/bookings_datasource.dart` | 6 (`:172, :283, :327, :456, :493, :669`) | `game:games(title, sport[, organizer_id])` | **fails today**: `sport` and `organizer_id` do not exist |
| `features/games/data/datasources/venues_datasource.dart` | 1 (`:787`) | `game:games(title, sport)` | **fails today**: same reason |

They read `title`, which is slated. A drop does not change their state; they are reported, not fixed.

### 2c. `meetups`: no direct read

There is no `.from('meetups')` and no `meetups(...)` embed in lib/. Meetup data reaches the client only through
`v_meetup_list` and the `rpc_meetup_*` RPCs. Those are server-side consumers, converted to `events` by KAN-714 B02/B06. Whether
their SQL still names slated columns is the server scan's question (other D tickets), not this one.

### 2d. Realtime on the legacy tables: column-free

`game_view_controller.dart` subscribes to `games` filtered on `id`, which is retained. `listing_refresh.dart` subscribes to
`games` and to `meetups` with no filter. `data/repositories/games_repository_impl.dart` is dead (KAN-740). Every payload is
ignored and a change only triggers a re-read, so a column drop does not break these subscriptions.

### 2e. Already converted (the BLOCKED BY tickets)

- **KAN-736 (F01) and KAN-737 (F02):** writes and cancel go through the KAN-712 RPCs. Lib/ has no direct games/meetups write
  except dead L1-L3 and RLS-denied D4 (`KAN715_ACTIVE_CALL_SITES.md`, pinned by `test/features/games/active_write_paths_test.dart`).
- **KAN-743 (R03):** nearby reads use RPCs; none appears in 2a.
- **KAN-744 (R04):** the profile game counts use `v_game_card`. **G14-G16 are not covered by it:** sport profile organiser
  metrics and the data export still read `games` directly.

## 3. Old-client matrix

| Client | Where it runs | Direct `games` reads | Direct `meetups` reads | After a slated-column drop |
|---|---|---|---|---|
| Store 1.3.0 to 1.6.4 | installed iOS/Android | 18-19 | 0 | **breaks**: explicit projections and filters error (`42703`); `select('*')` rows lose fields and `GameModel.fromJson` substitutes invented values (title `'Untitled Game'`, sport `'football'`, end = start + 1h), which the contract forbids |
| Store 1.7.0+101 to 1.7.8+174 (current main/Canary version) | installed iOS/Android | 20 | 0 | **breaks**, same way |
| Web, main (app.dabbler.pro) | browser; an open tab or a cached service worker keeps the old bundle until reload | 20 | 0 (meetups through views/RPCs) | **breaks** |
| Web, Canary (canary.dabbler.pro) | same | 20 | 0 | **breaks** |
| Web, Alpha / this branch | same | 18 | 0 | **breaks** |

Counts are `git grep` of `.from(gamesTable|'games')` in lib/ at each version bump:
- 1.3.0 `6be9def9` → 18
- 1.6.4 `904038b2` → 19
- 1.7.0 `52366be0` to 1.7.8 `81911a9e`, origin/main, origin/Canary → 20
- origin/Alpha and HEAD → 18

Which builds are actually installed, and how many users run them, is store-console data and **not documented** here.

## 4. Conditions to lift the block (next prerequisites, not done here)

1. **Current code:** re-point G1-G9 and G11-G17 to event-backed views or RPCs that keep the old projection names. Remove G10
   and G16-G18, which are already broken. This is a lib/ change and is out of this ticket's paths.
2. **Installed builds:** one of the two, and this needs a product decision:
   - keep the `games` mirror columns as compatibility mirrors until a supported-version floor is agreed and enforced; or
   - agree a supported-version plan.

   A mandatory-update UI must not be introduced without separate product agreement (KAN-718).
3. Re-run this test after (1). The `_knownGamesReads` map must reach empty before the verdict line may change.

## 5. Handoff

- **Changed files:**
  - `supabase/tests/events_p4/kan718_d03_client_scan_test.dart` (new, 7 tests)
  - this file (new)
- **Migrations:** none. **Applied:** nothing. **Authored:** the test and this matrix only.
- **Rollback:** delete the two files. No data is touched, so post-cutover data cannot be affected.
- **Limitations:**
  - The scan is textual, with comments stripped, and these forms are not seen:
    - a table name held in a variable other than the pinned forms
    - a query built across helpers
    - the generic `SupabaseRemoteDataSource.from(table)`, which no caller passes `games`/`meetups` to today
  - Only Dart under lib/ is scanned: no web JS, and no edge functions, which are server-side.
  - The live catalogue was not read.
- **Known conflicts:** none touched. Already-broken reads (G10, G16-G18 and the embeds in 2b) are reported, not fixed.
