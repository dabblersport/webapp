# Dabbler — Project State

**Audit run:** 2026-08-26 · **Branch:** `Canary` · **HEAD:** `1b83967`
**Owner:** `master-analyst` · **Scope:** whole repo + Supabase project `wtncuzcskpigqpmnxwws`
**Verification:** `flutter analyze --no-pub` → **0 errors**, 55 warnings, 102 infos (157 total).
`flutter test` → **66 tests, all pass.**

This is a living document. Every concrete claim below carries a `file:line` or a number
produced by a scan in this run. Nothing here is estimated.

---

## 1. Executive summary

Ranked by impact.

1. **Unauthenticated cross-tenant data leak.** `public.v_notifications_feed` and
   `v_notifications_ranked` are `SECURITY DEFINER` views over `notifications` with **no
   `WHERE to_user_id = auth.uid()`**. Queried as the `anon` role — the key that ships inside
   the public web bundle — they return **609 rows across 49 distinct recipients**, exposing
   `to_user_id`, `title`, `body`, `action_route`, `context`. No login required. **CRITICAL.**
2. **The moderation surface is open to `anon` too.** `v_mod_queue_open` returns 9 open
   moderation tickets and `v_safety_overview` returns admin metrics to an unauthenticated
   caller. The app gates the *screens* correctly via `rpc('is_admin')`
   (`lib/features/admin/presentation/screens/moderation_queue_screen.dart:22`) — the
   database does not gate the *data*. **CRITICAL.**
2b. **The definer-view problem is ~2× larger than first reported.** 71 views, **49** `SECURITY DEFINER`, **19** anon-readable with no uid predicate — corrected 2026-08-27 after the original figures took an advisor's finding count for a population count. 5 confirmed leaking, 12 never examined. **CRITICAL.** See `SCHEMA.md` §2 for a per-view position.
3. **The rewards slice is 20,545 LOC of unreachable code.** Its entry point,
   `lib/features/rewards/presentation/providers/rewards_providers.dart`, has **zero
   importers**. Every rewards controller is watched only from inside that same file. The
   only live rewards code is daily check-in (~985 LOC). `FeatureFlags.enableRewards` gates
   a stub.
4. **The `games` clean-architecture stack is dead and would be broken if it weren't.**
   `supabase_games_datasource.dart` issues 20 direct `.from(games)` queries; `public.games`
   has RLS enabled with **zero policies**, so `select count(*) from games` as `authenticated`
   returns **0**. Nothing watches `gamesControllerProvider` outside `games_providers.dart`.
   The live game path uses `v_game_card` + RPCs in
   `lib/features/games/presentation/controllers/game_view_controller.dart:399`.
5. **113 feature flags, 10 of which gate anything.** 98 are read nowhere outside
   `feature_flags.dart`; 5 more exist only to be logged into an analytics snapshot at
   `lib/main.dart:80-92`. `FeatureFlags.squads` is snapshot-only while `lib/features/squads/`
   (136 LOC) has zero importers — the flag promises a feature that does not exist.
6. **Every test covers dead code.** All 5 test files and all 66 passing tests target the
   games clean-arch usecases and `RegisterUseCase` — none of which any screen reaches.
   Zero tests touch the live path: `game_view_controller`, the notification stack,
   `auth_service`, or `profiles_repository_impl`.
7. **`SettingsRepositoryImpl` is 26 methods of `UnimplementedError`**
   (`lib/features/profile/data/repositories/settings_repository_impl.dart:111-237`) and it is
   *wired live* into `privacy_controller.dart:60`. `settings_screen.dart:1194` catches
   `on UnimplementedError` — the author knows and is swallowing it.
8. **6,213 LOC of orphan screens** across 10 files nothing imports, plus a 632-LOC
   `.broken` file still in the tree, plus `_PlaceholderScreen` rendering "Coming Soon" on
   6 registered routes.
9. **Two live bucket-name traps.** `SupabaseConfig.venueImagesBucket = 'venue-images'`
   (`lib/core/config/supabase_config.dart:4`) — no such bucket exists; the real one is
   `venue`, and it has **zero storage policies**, so nothing can be written to it.
   `supabase_profile_datasource.dart:16` hardcodes `'avatars'` — also non-existent.
10. **Documentation is stale but not lying.** `docs/LOCATION.md` and `docs/NOTIFICATIONS.md`
    were last touched 2026-07-12; `lib/features/notifications/` last changed 2026-08-14 and
    was substantially rewritten in between (`c74d6e1`, `3b7fd50`, `09ca8fe`).
    `docs/AGENTS.md` describes a 10-agent roster; 4 agents exist.

---

## 2. Mental model

Dabbler is a Flutter/Riverpod/GoRouter social-sports app on Supabase, 390 commits over
10 months (2025-10-17 → 2026-08-17), ~226k non-generated Dart LOC across 25 feature slices.
The app has been rebuilt at least twice around the same domain. The **live** architecture is
thin and pragmatic: screens watch Riverpod providers that call `SupabaseConfig`-named tables,
views (`v_game_card`, `v_circle_feed`, `v_squad_card`) and RPCs directly. Layered on top of
that — and largely orphaned from it — sits a **second, textbook clean-architecture stack**
(`domain/repositories` → `data/datasources` → `usecases` → controllers) that was built,
tested, and then routed around. `lib/features/games/`, `lib/features/rewards/`, and
`lib/features/profile/data/` are the three biggest examples. This is the single dominant
structural fact about the repo: roughly a quarter of `lib/` is a parallel implementation that
no route reaches.

Churn over the last 6 months concentrates in `social` (223 file-touches), `data` (206),
`auth_onboarding` (166), `profile` (161) — which is also where the god files and the
`Either`/`Result` split live. The recent commit history (`c74d6e1` through `1b83967`) shows
deliberate cleanup: legacy notification stacks deleted, table names routed through
`SupabaseConfig` (now **0** hardcoded `.from('...')` calls remain), dead UI removed,
`print()` converted to `debugPrint()`. That work is real and it worked — the *notifications*
slice is the healthiest in the repo. The contradiction to flag: `CLAUDE.md` says "No tests
exist yet — start with repository and usecase unit tests." Tests now exist and pass, but
they were written against the abandoned stack, so the claim is stale in a way that
overstates coverage of anything that ships.

---

## 3. Feature completion table

All 25 slices in `lib/features/`. "Routed" = screen class appears in `lib/app/app_router.dart`.
Status is judged on **reachability**, not file count.

| Feature | LOC | Screen files | Routed | Tests | Status | Evidence |
|---|---:|---:|---|---|---|---|
| `profile` | 40,854 | 19 | 18/18 classes | 1 file | **PARTIAL** | Live via `lib/data/repositories/profiles_repository_impl.dart` (221 LOC). `data/repositories/settings_repository_impl.dart:111-237` = 26× `UnimplementedError`; `data/repositories/profile_stats_repository.dart:7-69` = 8× `UnimplementedError` |
| `social` | 28,827 | 6 | 5/6 | none | **SHIPPED** | 1 orphan: `CreatePostScreen` (`presentation/screens/create_post_screen.dart`, 1,196 LOC, 0 importers) |
| `rewards` | 20,545 | 1 | 0 | none | **SCAFFOLD** | `presentation/providers/rewards_providers.dart` has 0 importers; all 7 dashboard classes in `presentation/screens/rewards_analytics_dashboard.dart` orphaned. Only check-in is live |
| `auth_onboarding` | 17,471 | 16 | 14/14 classes | 1 file | **SHIPPED** | Fully routed. `presentation/providers/auth_providers.dart:265,289` throw `UnimplementedError` but are never watched |
| `games` | 16,792 | 3 | 1/3 | 3 files | **PARTIAL** | Only `join_game/game_detail_screen.dart` routed. `data/` + `domain/usecases/` = 5,674 LOC with 0 external consumers |
| `misc` | 8,260 | 12 files / 6 classes | 5/6 | none | **PARTIAL** | `create_game_screen.dart` (763) orphan + `create_game_screen.dart.broken` (632) still tracked |
| `explore` | 7,664 | 8 files / 7 classes | 3/7 | none | **PARTIAL** | Orphans: `ExploreNearbyScreen`, `FavoriteVenuesScreen`, `PaymentSheet`, `BookingSummaryModal` |
| `notifications` | 4,204 | 1 | 1/1 | none | **SHIPPED** | Every non-generated file has an importer; `NotificationsScreenV2` routed at `app_router.dart:95` |
| `location` | 3,602 | 1 | 0 (widget lib) | none | **PARTIAL** | 18 external importers for its widgets; `saved_locations_screen.dart` reached via push, not routed |
| `venues` | 3,528 | 2 | 1/2 | none | **PARTIAL** | `VenuesNearbyScreen` (619 LOC) orphan |
| `home` | 3,461 | 2 | 2/2 | none | **SHIPPED** | 6 external importers |
| `venue_submissions` | 1,670 | 3 | 3/3 | none | **SHIPPED** | 3 router imports |
| `news` | 1,604 | 1 | 1/1 | none | **SHIPPED** | routed; recent feature (`a24cf1b`) |
| `admin` | 889 | 2 | 2/2 | none | **SHIPPED** | screens correctly gated on `rpc('is_admin')` |
| `activities` | 622 | 0 | n/a | none | **SHIPPED** | widget-only slice, 3 external importers |
| `payments` | 503 | 0 | n/a | none | **DEAD** | 0 external importers across all 6 files |
| `moderation` | 285 | 0 | n/a | none | **SHIPPED** | provider-only, 2 external importers |
| `audit_safety` | 145 | 0 | n/a | none | **DEAD** | single `providers.dart`, 0 importers |
| `squads` | 136 | 0 | n/a | none | **DEAD** | 0 importers; `FeatureFlags.squads` is snapshot-only |
| `app_boot` | 117 | 0 | n/a | none | **SHIPPED** | 1 importer |
| `username_engine` | 114 | 0 | n/a | none | **SHIPPED** | 1 importer; `username_consumer.dart:19` has a `dead_null_aware_expression` warning |
| `display_names` | 90 | 0 | n/a | none | **DEAD** | 0 importers |
| `bench_mode` | 84 | 0 | n/a | none | **DEAD** | 0 importers |
| `error` | 53 | 0 | routed | none | **SHIPPED** | `ErrorPage` at `app_router.dart:1706` |
| `core` | 18 | 0 | n/a | none | **SHIPPED** | 1 importer |

**Counts:** SHIPPED 12 · PARTIAL 6 · SCAFFOLD 1 · DEAD 6.

---

## 4. Findings

| ID | Category | File:Line | Sev | Eff | Finding | Recommendation |
|---|---|---|---|---|---|---|
| SEC-01 | Security | db: `public.v_notifications_feed` — **KAN-36** | CRITICAL | S | `SECURITY DEFINER` view over `notifications` with no `auth.uid()` filter. As `anon`: 609 rows, 49 distinct `to_user_id`. Exposes `title`, `body`, `action_route`, `context` | Add `WHERE to_user_id = auth.uid()` **and** `ALTER VIEW … SET (security_invoker = true)`. Verify with the same `set role anon` probe |
| SEC-02 | Security | db: `public.v_notifications_ranked` — **KAN-37** | CRITICAL | S | Same table, same shape, same 609 rows to `anon` | Same fix as SEC-01 |
| SEC-03 | Security | db: `public.v_mod_queue_open` — **KAN-38** | CRITICAL | S | 9 open moderation tickets readable by `anon`. Screen is gated (`moderation_queue_screen.dart:22`), data is not | Wrap in `is_admin()` check or revoke `anon`/`authenticated` SELECT |
| SEC-04 | Security | db: `public.v_safety_overview` | HIGH | S | Admin safety metrics readable by `anon` | Revoke `anon`, `authenticated`; keep for service role / admin RPC |
| SEC-05 | Security | db: `public.v_circle_feed` | HIGH | S | 6 rows returned to `anon`; circle feeds are scoped content | Add membership predicate; set `security_invoker = true` |
| SEC-06 | Security | db: 49 views, `reloptions IS NULL` | **CRITICAL** | M | **CORRECTED 2026-08-27 — original figures were ~2× understated.** Measured live: **71 views total** (not 49), **49 `SECURITY DEFINER`** (not 25), **19 anon-readable with no `auth.uid()` predicate** (not 8). The original 25 was the Supabase advisor's *finding count* used as a *population count* | Triage all 19 — 2 are PostGIS metadata, 5 are confirmed leaking, 12 unexamined. Per-view census now in `SCHEMA.md` §2. Default every new view to `security_invoker = true`. KAN-26 |
| SEC-07 | Security | db: `public.games` | HIGH | M | RLS enabled, **zero policies**. `select count(*)` as `authenticated` → 0. All reads flow through definer views instead | Decide explicitly: either write policies on `games`, or delete the direct-table code paths that can never work |
| SEC-08 | Security | db: 30 tables | MED | M | RLS on, no policies: `squad_members`, `squad_invites`, `moderation_tickets`, `game_invites`, `game_link_tokens`, `admins`, `app_admins`, +23 | Triage: tables only reached via definer RPCs are intentional — document that; the rest need policies |
| SEC-09 | Security | Supabase Auth settings | MED | S | Leaked-password protection (HaveIBeenPwned) disabled | Enable in dashboard. Note accounts are passwordless by default (`trg_strip_signup_password`), so blast radius is the optional-password path only |
| SEC-10 | Security | db: `util.schema_tables_columns` | LOW | S | Function has a role-mutable `search_path` | `ALTER FUNCTION … SET search_path = ''` |
| DEAD-01 | Dead code | `lib/features/rewards/presentation/providers/rewards_providers.dart` | HIGH | L | 0 importers ⇒ 19,560 LOC of rewards (services, controllers, repo, dashboards) unreachable | PO decision first: revive or delete. Do not touch check-in (`check_in_*`, `early_bird_check_in_modal.dart`) |
| DEAD-02 | Dead code | `lib/features/rewards/presentation/screens/rewards_analytics_dashboard.dart:6,70,351,634,1069,1080,1091` | HIGH | S | All 7 dashboard widget classes orphaned; 3 of them render literal "Coming Soon" text | Delete the file |
| DEAD-03 | Dead code | `lib/features/games/data/**`, `lib/features/games/domain/usecases/**` | HIGH | L | 5,674 LOC; consumed only by `games_providers.dart`, which no screen watches | Delete after confirming `game_view_controller.dart` covers every live use |
| DEAD-04 | Dead code | `lib/features/misc/presentation/screens/create_game_screen.dart.broken` | MED | S | 632-LOC `.broken` file tracked in git since 2026-04-20 | `git rm` |
| DEAD-05 | Dead code | `lib/features/misc/presentation/screens/create_game_screen.dart` | MED | S | 763 LOC, 0 importers. Live composer is `game_composer_screen.dart` | Delete |
| DEAD-06 | Dead code | `lib/features/social/presentation/screens/create_post_screen.dart` | MED | S | 1,196 LOC, 0 importers. Live composer is `post_composer_screen.dart` | Delete |
| DEAD-07 | Dead code | `lib/features/explore/presentation/screens/explore_nearby_screen.dart` | MED | S | 864 LOC, 0 importers | Delete |
| DEAD-08 | Dead code | `lib/features/venues/presentation/screens/venues_nearby_screen.dart` | MED | S | 619 LOC, 0 importers | Delete |
| DEAD-09 | Dead code | `lib/features/games/presentation/screens/games_nearby_screen.dart` | MED | S | 722 LOC, 0 importers | Delete |
| DEAD-10 | Dead code | `lib/features/games/presentation/screens/create_game/game_screen_4_access_rules.dart` | MED | S | 335 LOC, 0 importers — step 4 of a create-game flow whose other steps no longer exist | Delete |
| DEAD-11 | Dead code | `lib/features/explore/presentation/screens/payment_sheet.dart`, `booking_summary_modal.dart` | MED | S | 326 + 250 LOC, 0 importers | Delete |
| DEAD-12 | Dead code | `lib/features/misc/presentation/screens/rebook_flow.dart` | LOW | S | 38 LOC, 0 importers | Delete |
| DEAD-13 | Dead code | `lib/features/payments/**` | MED | M | 503 LOC across 6 files, 0 external importers, no routes | Delete or state intent — `FeatureFlags.enablePayments` gates 2 files elsewhere |
| DEAD-14 | Dead code | `lib/features/audit_safety/providers.dart` | LOW | S | 145 LOC, 0 importers | Delete |
| DEAD-15 | Dead code | `lib/features/squads/` | MED | S | 136 LOC, 0 importers, while `FeatureFlags.squads` sits in the analytics snapshot | Delete slice or build the feature; do not leave the flag advertising it |
| DEAD-16 | Dead code | `lib/features/display_names/`, `lib/features/bench_mode/` | LOW | S | 90 + 84 LOC, 0 importers | Delete |
| DEAD-17 | Dead code | `lib/features/profile/presentation/screens/profile/profile_screen.dart` — `ManageProfilesSheet` | LOW | S | Public widget class orphaned inside a live 1,900-LOC file | Delete the class |
| DEAD-18 | Dead code | `lib/features/misc/presentation/screens/transactions_screen.dart` — `TransactionDetailsSheet` | LOW | S | Orphan class inside a routed file | Delete the class |
| DEAD-19 | Dead code | `lib/features/explore/presentation/screens/sports_screen.dart` — `FavoriteVenuesScreen`, `VenueCard` | LOW | S | Two orphan classes inside a routed 2,303-LOC file | Delete the classes |
| DEAD-20 | Dead code | `lib/data/repositories/area_repository_v2.dart` | LOW | S | `_v2` residue — 3 importers, so it is the live one; the naming is the problem | Rename to `area_repository.dart` once the v1 is gone |
| FLAG-01 | Dead config | `lib/core/config/feature_flags.dart` | HIGH | M | 113 declared, **98 never read**, 5 read only by the `main.dart:80-92` analytics snapshot, **10 actually gate** | Delete the 98. Keep the 10. Decide on the 5 |
| FLAG-02 | Dead config | `lib/utils/constants/route_constants.dart` | MED | M | 133 constants declared, **54 referenced nowhere** (`joinGame`, `myGames`, `gameLobby`, `liveGame`, `leaderboard`, `profileEdit`, …) | Delete the 54; several name flows that were removed |
| WIRE-01 | Incomplete | `lib/features/profile/data/repositories/settings_repository_impl.dart:111-237` | HIGH | L | 26 methods, every one `throw UnimplementedError(...)`. Imported live by `privacy_controller.dart:60` and `profile_providers.dart:43` | Implement, or make the class return `Result.err` so callers can degrade instead of throwing |
| WIRE-02 | Incomplete | `lib/features/profile/presentation/screens/settings/settings_screen.dart:1194` | HIGH | S | `} on UnimplementedError catch (_) {` — the UI silently absorbs an unimplemented backend | Once WIRE-01 lands, remove this catch so failures surface |
| WIRE-03 | Incomplete | `lib/features/profile/data/repositories/profile_stats_repository.dart:7-69` | MED | M | 8 methods, all `UnimplementedError`. Imported by `data/providers/profile_providers.dart:3` | Same treatment as WIRE-01 |
| WIRE-04 | Incomplete | `lib/features/profile/data/repositories/profile_repository.dart:16-137` | MED | M | 10 methods, all `UnimplementedError`, 8 importers | Same |
| WIRE-05 | Incomplete | `lib/features/auth_onboarding/presentation/providers/auth_providers.dart:265` | MED | S | `authRepositoryProvider` throws `UnimplementedError`; `authControllerProvider` (line 279) reads it. Currently defused only because nothing watches `authControllerProvider` | Delete both providers — `simpleAuthProvider` is the live path |
| WIRE-06 | Incomplete | `lib/features/auth_onboarding/presentation/providers/auth_providers.dart:289` | MED | S | `registerControllerProvider` throws before returning | Delete |
| WIRE-07 | Incomplete | `lib/features/rewards/data/repositories/rewards_repository_impl.dart:40` | MED | S | `throw UnimplementedError('Not implemented')` | Covered by the DEAD-01 decision |
| WIRE-08 | Incomplete | `lib/features/games/providers/games_providers.dart:95-121` | LOW | S | `createGameUseCaseProvider` and `cancelGameUseCaseProvider` commented out entirely | Delete the commented blocks |
| WIRE-09 | Incomplete | `lib/app/app_router.dart:1573,1587,1601,1617,1630,1640` | MED | M | 6 registered routes render `_PlaceholderScreen(… ) → "Coming Soon"`: Chat List, Social Notifications, Messages, Edit Post, Social Analytics | Either build them or unregister the routes — a route that resolves to "Coming Soon" is worse than a 404 |
| WIRE-10 | Incomplete | `lib/app/app_router.dart:590` | MED | S | `/settings/language` renders inline `Text('Language Selection - Coming Soon')` while full en/ar l10n exists (489 keys each) | Wire the existing locale switcher |
| WIRE-11 | Incomplete | `lib/core/services/analytics/analytics_service.dart:11-219` | HIGH | M | **18 `TODO: implement …`** — every tracking method is an empty body. `main.dart:78` calls `trackEvent` for the flags snapshot into a no-op | Either wire a provider or delete the service and its call sites; right now the app believes it has analytics |
| BUG-01 | Bug | `lib/core/config/supabase_config.dart:4` | HIGH | S | `venueImagesBucket = 'venue-images'` — **no such bucket**. Actual bucket is `venue`, which has **0 storage policies** of any kind | Rename the constant to `'venue'` and add INSERT + SELECT policies; unused today, so it is a trap not an outage |
| BUG-02 | Bug | `lib/features/profile/data/datasources/supabase_profile_datasource.dart:16` | MED | S | `final String _avatarBucket = 'avatars';` — bucket does not exist (real name `Avatar`). Live uploads go through `ImageUploadService` which uses `SupabaseConfig.avatarsBucket` correctly | Delete the hardcode; route through `SupabaseConfig` |
| BUG-03 | Bug | db: bucket `dabbler-news` | MED | S | INSERT policy exists, **no SELECT policy**. Public bucket so CDN reads work, but authenticated list/read-back fails — the recurring Dabbler bug class | Add a SELECT policy |
| BUG-04 | Bug | db: bucket `venue` | MED | S | Zero policies. Uploads impossible | Add INSERT + SELECT |
| TEST-01 | Tests | `test/` | HIGH | L | 5 test files / 783 lib files. 66 tests, all passing, **all against unreachable code** (games usecases, `RegisterUseCase`) | Write the first test against the live path: `game_view_controller.dart` join/leave, and the notification repository |
| TEST-02 | Tests | `test/features/` | HIGH | L | 22 of 25 slices have no test directory at all — including `social` (28,827 LOC) and `notifications` | Start with `notifications` — it is the cleanest slice and the highest-value regression target |
| ARCH-01 | Architecture | 140 non-generated files >500 LOC | MED | L | Top offenders: `post_composer_screen.dart` (2,996), `profile_edit_screen.dart` (2,914), `social_search_screen.dart` (2,892), `post_detail_screen.dart` (2,304), `sports_screen.dart` (2,303). `CLAUDE.md` sets a 500-line limit | Split the top 5 only; a blanket campaign is not worth it |
| ARCH-02 | Architecture | `lib/app/app_router.dart` (1,745 LOC) | MED | M | Single file holds all routes, redirect logic, an inline placeholder widget, and two `rpc('is_admin')` calls (lines 1656, 1682) | Extract route groups per feature; keep `_handleRedirect` central |
| ARCH-03 | Consistency | 31 files on `Either<>` vs 124 on `Result<>` | MED | L | Mixed **inside** slices, against `CLAUDE.md`: `games` (11 Either / 5 Result), `profile` (12/3), `social` (2/10), `auth_onboarding` (1/7) | Convert per-slice, `social` and `auth_onboarding` first — they are closest to done |
| ARCH-04 | Architecture | `lib/features/profile/` | MED | L | 3 parallel profile repository stacks. Live one is `lib/data/repositories/profiles_repository_impl.dart` (221 LOC); the `features/profile/data/` stack (2,534 LOC) is reachable but built on `UnimplementedError` | Collapse to one after WIRE-01/03/04 |
| STYLE-01 | Convention | 233 `Color(0x…)` in `lib/features/` | MED | M | `auth_onboarding` 97, `rewards` 65, `venues` 20, `social` 20. `CLAUDE.md` forbids hardcoded colours | Fix `auth_onboarding` (live, 97 sites); `rewards`' 65 disappear with DEAD-01 |
| STYLE-02 | Convention | 26 `print()` calls | LOW | S | `lib/utils/logger.dart` (5), `lib/main.dart` (8 — zone/error handlers), `post_repository_impl.dart:` `print('INSERT PAYLOAD: $data')` logs request bodies | Convert to `debugPrint`; the `INSERT PAYLOAD` line should go entirely |
| ERR-01 | Error handling | 44 `empty_catches` from `flutter analyze` | MED | M | Concentrated in `rewards/services/` (18) and `profile/services/onboarding_controller.dart` (6 — lines 104, 160, 172, 190, 235, 317) | Fix the 6 in `onboarding_controller.dart` (live path); the rewards ones die with DEAD-01 |
| DEP-01 | Dependency | `pubspec.yaml:40-43` | MED | S | `dabbler_design_system` is a **git dependency** on `github.com/MoatazMu/dabbler-design-system@main` with **0 imports** in `lib/`. Every clean build clones it | Remove from `pubspec.yaml`. `lib/design_system/design_system.dart:1` calls itself "(temporary)" — decide adoption or drop |
| DEP-02 | Dependency | `pubspec.yaml` | LOW | S | `cupertino_icons` declared, never imported | Remove |
| PROV-01 | Dead code | 113 of 400 providers | MED | M | Declared and referenced exactly once (their own declaration). Includes `authControllerProvider`, `authSessionProvider`, `analyticsServiceProvider`, `friendsListProvider`, `circleFeedProvider`, `dataExportServiceProvider` | Sweep per-slice alongside the DEAD-* deletions rather than as one pass |
| DOC-01 | Docs | `docs/LOCATION.md`, `docs/NOTIFICATIONS.md` | MED | S | Last commit 2026-07-12; `lib/features/notifications/` last changed 2026-08-14 after a rewrite (`c74d6e1` deleted the legacy stack) | Refresh `NOTIFICATIONS.md` against the current slice |
| DOC-02 | Docs | `CLAUDE.md` "Testing" section | MED | S | Says "No tests exist yet" — 5 files and 66 tests exist | Correct it, and note the tests cover abandoned code |
| DOC-03 | Docs | `docs/AGENTS.md` | LOW | S | Describes a 10-agent roster "awaiting PO sign-off"; `.claude/agents/` holds 4 | Reconcile to reality or mark the rest aspirational |
| DOC-04 | Docs | `docs/screen-report.md`, `docs/AGENTS.md` | LOW | S | Both untracked by git | Commit or `.gitignore` deliberately |
| CFG-01 | Config | `scripts/cloudflare-build.sh` | MED | S | Requires `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `APP_NAME`, `ENVIRONMENT`, `GOOGLE_WEB_CLIENT_ID`. Cloudflare Pages holds Production and Preview variable sets **separately** | Not verifiable from the repo — confirm all 5 exist in **both** environments before the next Canary push |
| CFG-02 | Config | `supabase_migrations.schema_migrations` | MED | M | **CORRECTED TWICE, 2026-08-27.** Originally "`supabase/migrations/` is empty — no schema history". Both halves were wrong: that directory does not exist, **and** the ledger holds **237 applied migrations** (`20251113222001` → `20260720192127`). 38 `.sql` files are also tracked at `supabase/schema/`, of which exactly **1** contains `CREATE TABLE` | The surviving, narrower finding: **no repo-authored way to rebuild the schema**. History is not missing; reproducibility is. KAN-33 needs rescoping |

---

## 5. Top 5 priority fixes

**1. Close the notification leak (SEC-01, SEC-02) — hours, not days.**
```sql
create or replace view public.v_notifications_feed as
  select … from notifications where to_user_id = auth.uid() order by created_at desc;
alter view public.v_notifications_feed set (security_invoker = true);
-- repeat for v_notifications_ranked
```
Re-run the probe that found it: `set local role anon; select count(*) from public.v_notifications_feed;`
must return 0. This is user data readable with nothing but the public web bundle's key.

**2. Lock the moderation views (SEC-03, SEC-04).**
`revoke select on public.v_mod_queue_open, public.v_safety_overview from anon, authenticated;`
then expose them through an `is_admin()`-guarded RPC, matching what the screens already
assume at `moderation_queue_screen.dart:22`.

**3. Sweep the remaining definer views (SEC-06) — 19 exposed, not 8.**
The query that produced the list:
```sql
select c.relname, (pg_get_viewdef(c.oid) ilike '%auth.uid()%') as filters_on_uid,
       has_table_privilege('anon', c.oid, 'SELECT')
from pg_class c join pg_namespace n on n.oid=c.relnamespace
where n.nspname='public' and c.relkind='v' and c.reloptions is null;
```
Any row with `filters_on_uid = false` and `anon = true` needs a decision. Make
`security_invoker = true` the default for every view created from here.

**4. Get one PO decision on rewards (DEAD-01), then act on it.**
20,545 LOC hinges on a single question: is the rewards system being built or was it
abandoned? Until that is answered, nobody can safely touch `rewards`, and
`FeatureFlags.enableRewards` keeps advertising a feature that resolves to a stub. If
abandoned: delete everything except `check_in_*`, `early_bird_check_in_modal.dart`,
`check_in_progress_indicator.dart` (~985 LOC survives). That single deletion also removes
65 hardcoded colours, 18 empty catch blocks, and 7 orphan dashboard classes.

**5. Make settings honest (WIRE-01, WIRE-02).**
`SettingsRepositoryImpl` throws on all 26 methods and the settings screen catches the throw.
Minimum viable fix: change every method to return `Err(Failure.unimplemented(...))` per
`CLAUDE.md`'s "never throw across layer boundaries" rule, then delete the
`on UnimplementedError catch` at `settings_screen.dart:1194` so the UI shows a real state.

---

## 6. Quick wins

Low effort, real payoff.

| Action | Effect |
|---|---|
| `git rm lib/features/misc/presentation/screens/create_game_screen.dart.broken` | 632 LOC gone, one embarrassing filename gone |
| Delete the 10 orphan screen files (DEAD-05…DEAD-12) | 6,213 LOC gone, 0 behaviour change |
| Delete the 98 never-read feature flags | `feature_flags.dart` drops from 113 flags to 15 |
| Delete the 54 unreferenced route constants | `route_constants.dart` drops from 133 to 79 |
| Remove `dabbler_design_system` + `cupertino_icons` from `pubspec.yaml` | One fewer git clone per clean build |
| Delete `lib/features/{payments,audit_safety,squads,display_names,bench_mode}/` | 958 LOC, 5 slices, 0 importers |
| Fix `print('INSERT PAYLOAD: $data')` at `post_repository_impl.dart` | Stops logging request bodies |
| Fix the 6 empty catches in `profile/services/onboarding_controller.dart` | Live onboarding stops swallowing failures |
| `alter function util.schema_tables_columns set search_path = ''` | Clears the last function advisor |
| Enable leaked-password protection in Supabase Auth | Clears an advisor; low blast radius |

---

## 7. Agent & skill utilisation

**Agents** — `.claude/agents/`, evidence of runs from `.claude/agent-memory/`.

| Agent | Memory files | Used? | Recommendation |
|---|---:|---|---|
| `notifications-specialist` | 7 | **Yes** — richest memory in the repo (schema, RLS, triggers, edge functions, a 401 delivery post-mortem) | **Keep.** It also owns the fix for SEC-01/02 |
| `app-store-submission-fixer` | 4 | **Yes** — EULA gate, moderation infra, submission 1.7.0 | **Keep** |
| `version-control` | 3 | **Yes** — Canary pipeline incident, subagent dispatch trap | **Keep** |
| `master-analyst` | 0 (this run seeds it) | First run | **Keep** |

**Project skills** — `.claude/skills/`, 34 directories.

| Skill | Used? | Recommendation |
|---|---|---|
| `project-audit` | Yes — this run | **Keep.** Note its orphan-screen regex substring-matches (`NotificationsScreen` inside `NotificationsScreenV2`) and its import check misses relative imports — both produced false positives corrected below |
| `supabase`, `supabase-postgres-best-practices` | Directly relevant to a Supabase app | **Keep** |
| `ui-ux-pro-max` | Ships Flutter guidance | **Keep** |
| 22 × `agentdb-*`, `reasoningbank-*`, `swarm-*`, `v3-*`, `sparc-methodology`, `stream-chain`, `hooks-automation`, `pair-programming`, `verification-quality`, `skill-builder`, `browser` | No evidence of use | **Remove.** These are claude-flow's internal-development skills — building claude-flow v3, its DDD architecture, its MCP transport layer. Nothing in them applies to a Flutter app |
| 5 × `github-*` (`code-review`, `multi-repo`, `project-management`, `release-management`, `workflow-automation`) | Repo has no `.github/workflows/` | **Remove** unless CI is planned; `version-control` covers the release path today |

**Global skills** — `~/.claude/skills/`, 31 directories: the same claude-flow set, duplicated.
Every one of the 31 is either irrelevant to Flutter or shadowed by the project copy.
**Remove the duplication** — a project skill and a global skill with the same name is a
resolution ambiguity waiting to bite.

**Net:** 4/4 agents earn their place. 4 of 34 project skills are relevant; 30 are noise, and
they are duplicated 31× globally on top of that.

---

## 8. Incompleteness register

Every in-code admission of unfinished work, grouped by feature. Generated files
(`.g.dart`, `.freezed.dart`, `lib/l10n/app_localizations*.dart`) excluded.

### `core` — analytics (18 admissions, all in one file)
`lib/core/services/analytics/analytics_service.dart` — every public method is an empty body:
```
:11  // TODO: forward to underlying provider(s)
:22  // TODO: implement identify
:26  // TODO: implement reset
:35  // TODO: implement game creation step tracking
:51  // TODO: implement game created tracking
:68  // TODO: implement game joined tracking
:83  // TODO: implement game search tracking
:97  // TODO: implement filter usage tracking
:112 // TODO: implement check-in tracking
:128 // TODO: implement venue selection tracking
:141 // TODO: implement screen view tracking
:149 // TODO: implement feature usage tracking
:162 // TODO: implement error tracking
:177 // TODO: implement game engagement tracking
:192 // TODO: implement search result click tracking
:206 // TODO: implement check-in attempt tracking
:219 // TODO: implement performance metric tracking
```
Also `lib/core/services/auth_profile_service.dart:109` — `/// TODO: Migrate to use
ProfilesRepository.upsert instead`, and `lib/core/analytics/analytics_helpers.dart:160` —
`sportType: '', // TODO: Add sport type parameter`.

### `profile` (44 `UnimplementedError` sites — the largest cluster)
`lib/features/profile/data/repositories/settings_repository_impl.dart:14` states it outright:
> `/// (notifications, themes, accessibility, etc.) throw [UnimplementedError]`

then does it 26 times — lines `111, 117, 124, 130, 134, 139, 145, 152, 157, 163, 168, 174,
178, 182, 186, 190, 194, 201, 208, 213, 218, 226, 232, 237`.

`lib/features/profile/data/repositories/profile_stats_repository.dart` — 8 methods:
`:8 'ProfileStatsRepository.getProfileStats not implemented'`, and the same for
`updateProfileStats:18`, `incrementGamesPlayed:25`, `updateRating:36`,
`recordGameOutcome:48`, `getLeaderboardPosition:55`, `getProfileViews:62`,
`incrementProfileViews:69`.

`lib/features/profile/data/repositories/profile_repository.dart` — 10 methods:
`getUserProfile:17`, `updateProfile:77`, `createProfile:82`, `deleteProfile:87`,
`uploadProfileImage:93`, `searchProfiles:106`, `getProfilesByIds:113`,
`updateCompletionPercentage:123`, `getAllUserData:130`, `deleteAllUserData:137`.

`lib/features/profile/presentation/screens/settings/settings_screen.dart:1194` —
`} on UnimplementedError catch (_) {` (the UI absorbing all of the above).
`lib/features/profile/presentation/screens/profile/profile_screen.dart:1046` —
`// TODO: Implement share profile`.
`lib/features/profile/presentation/screens/support/contact_support_screen.dart` — three
user-facing snackbars: `:388 'FAQ section coming soon'`, `:414 'Live chat coming soon'`,
`:441 'Phone call functionality coming soon'`.

### `rewards`
`lib/features/rewards/data/repositories/rewards_repository_impl.dart:40` —
`throw UnimplementedError('Not implemented');`
`lib/features/rewards/services/rewards_service_stub.dart:25` —
`throw UnimplementedError('UserProgress entity needs proper structure');`
`lib/features/rewards/services/rewards_service.dart:144` — `throw UnimplementedError(`
`lib/features/rewards/domain/repositories/rewards_repository.dart:355` —
`// Missing methods for tier_calculation_service.dart`
`lib/features/rewards/presentation/screens/rewards_analytics_dashboard.dart:1075, 1086, 1097`
— three dashboards whose entire body is `Text('… Dashboard - Coming Soon')`.
18 empty catch blocks across `progress_tracking_service.dart` (7),
`achievement_notification_service.dart` (2), `rewards_analytics_service.dart` (3),
`rewards_service.dart` (4), `tier_calculation_service.dart` (3).

### `auth_onboarding`
`lib/features/auth_onboarding/presentation/providers/auth_providers.dart:265` —
`throw UnimplementedError('AuthRepository not implemented');`
`:289` — `throw UnimplementedError('RegisterUseCase not implemented');` followed by the
commented-out real body.
`lib/features/auth_onboarding/data/services/ip_country_detection_service.dart:34` —
`// TODO: Disable JWT verification in Supabase dashboard for this function` (a config change
that was never made, sitting in code).
`lib/features/profile/services/onboarding_controller.dart` — 6 empty catches at
`:104, :160, :172, :190, :235, :317`; `onboarding_gamification.dart:46` — a 7th.

### `games`
`lib/features/games/providers/games_providers.dart:101, :118` — two whole use-case providers
commented out around `// throw UnimplementedError('BookingsRepository not yet implemented');`
`lib/features/games/data/repositories/bookings_repository_impl.dart:897` —
`return Left(UnknownFailure('QR code validation not implemented'));`
`lib/features/games/data/datasources/games_remote_data_source.dart:183` and
`games_repository_impl.dart:710` — `/// Returns 0.0 if no ratings exist or backend not implemented.`

### `social`
`lib/features/social/providers/community_providers.dart:183` —
`'totalPosts': 0, // TODO(post-rebuild): reconnect to PostRepository`

### `app` / `main`
`lib/main.dart:217` —
`// TODO(post-rebuild): reinitialize realtime post updates when new service is ready`
`lib/app/app_router.dart:590` — `Text('Language Selection - Coming Soon')`
`lib/app/app_router.dart:1715-1743` — `_PlaceholderScreen`, rendered on 6 routes
(`:1573, :1587, :1601, :1617, :1630, :1640`).

### `explore` / `misc` / `venues`
`lib/features/explore/presentation/screens/sports_screen.dart:2289` —
`// TODO: Navigate to add venue screen`
`lib/features/misc/presentation/screens/activities_screen_v2.dart:82` —
`// TODO: Navigate to detail screen based on subject_type and subject_id`
`lib/features/venues/presentation/screens/venue_detail_screen.dart:922` —
`void _shareVenue() => _snack('Sharing coming soon');`

### `design_system`
`lib/design_system/design_system.dart:1` —
`/// Single entrypoint for the app's (temporary) design-system layer.`
The word "temporary" has survived every refactor to date.

**Totals:** 26 strict `TODO`/`FIXME`/`HACK` comments · 44 `UnimplementedError` throw sites ·
9 user-visible "coming soon" strings · 44 empty catch blocks · 6 placeholder routes.
The two `TODO(post-rebuild)` markers name a rebuild that has not been finished.

---

## 9. Looks bad but is actually fine

Do not open tickets for these.

1. **Firebase `AIza…` keys** in `lib/firebase_options.dart:44,54,62,71,80` and
   `android/app/google-services.json:31`. These are **public client identifiers**, designed to
   ship in the binary. Not a leak.
2. **`service_role` in `supabase/functions/**`.** Appears at
   `send-push-notification/index.ts:15,219` and in the private-key handling of
   `broadcast-notification/index.ts:204`. Server-side Deno, correct. It does **not** appear
   anywhere in `lib/`.
3. **`spatial_ref_sys` flagged `rls_disabled_in_public` (ERROR).** PostGIS system table owned
   by the extension. You cannot enable RLS on it and it holds no app data.
4. **8 × `extension_in_public` warnings** (`postgis`, `citext`, `pg_trgm`, `btree_gin`,
   `btree_gist`, `cube`, `earthdistance`, `unaccent`). Supabase installs these into `public`
   by default; relocating them breaks every existing query. Ignore.
5. **300 + 299 `*_security_definer_function_executable` advisors.** That is one warning per
   role per `SECURITY DEFINER` function — the entire RPC layer, which is the deliberate
   architecture here (RLS-less tables reached through definer RPCs). These are not
   individually actionable. The **views** (SEC-01…06) are the real problem, not the functions.
6. **`notifications_screen_v2.dart` and `activities_screen_v2.dart`.** The `_v2` suffix reads
   like residue; both are the **live, routed** screens (`app_router.dart:95` / `:58`) and
   their v1 predecessors were deleted in `c74d6e1`. The scanner's substring match on
   `class NotificationsScreen…` inside `NotificationsScreenV2` produced a false orphan.
   The filenames should be renamed, but nothing is broken.
7. **`isAdmin` "client-side auth checks"** — 32 grep hits. Every gate that matters calls
   `Supabase.instance.client.rpc(SupabaseConfig.isAdminFn)` server-side
   (`app_router.dart:1656,1682`, `moderation_queue_screen.dart:24`). The client is asking the
   server, not deciding for itself. Correct pattern.
8. **`SportsHistoryScreen` reported orphan.** The **class** is unreferenced, but the **file**
   has 3 importers (`sports_library_screen.dart:6`,
   `profile/presentation/widgets/sport_game_history_section.dart:5`,
   `games/providers/game_history_providers.dart:6`) which pull other symbols from it.
   Delete the class, keep the file.
9. **"143 god files."** 3 of those are generated l10n (`app_localizations.dart` 3,338,
   `_en` 1,826, `_ar` 1,786). Real count is **140**.
10. **`print()` in `lib/main.dart` (8 sites) and `lib/utils/logger.dart` (5).** These are
    zone-guard and error-handler paths where losing output would hide crashes. Worth
    converting to `debugPrint`, but not a leak or a bug.
11. **`authControllerProvider` / `registerControllerProvider` throw `UnimplementedError`.**
    They are also in the 113-provider orphan list — nothing watches them, so nothing crashes
    today. Still delete them (WIRE-05/06), but there is no live incident here.
12. **App hangs on the launch screen without `--dart-define-from-file=.env`.** Expected and
    documented. Not a bug.
13. **All 66 tests pass.** The tests themselves are well-written — parameterised, thorough on
    validation edges. The problem is what they point at, not their quality.
14. **`.env` hygiene is clean.** `git check-ignore .env` → ignored; `git ls-files .env` →
    not tracked. **0** hardcoded `.from('table')` calls and **0** hardcoded storage buckets
    remain in `lib/` — the `SupabaseConfig` migration (`5aee97e`, `a61d1d8`) actually landed.
15. **`raw MaterialPage` count: 0.** Every route uses a transition wrapper, exactly as
    `CLAUDE.md` requires.

---

## 10. Open questions for the PO

1. **Rewards: build or bury?** 20,545 LOC, unreachable, with a live flag advertising it.
   Every other rewards finding waits on this answer. (DEAD-01)
2. **The clean-architecture stack: is it the destination or the past?** `games`, `rewards`,
   and `profile/data` all contain complete layered implementations that no screen reaches,
   while the live code queries Supabase views and RPCs directly. Which is the target
   architecture? Answering it decides ~25% of `lib/`.
3. **`public.games` has no RLS policies.** Is the intent that all game access flows through
   `SECURITY DEFINER` views and RPCs? If yes, that is a valid design and should be written
   down — and the 5,674 LOC of direct-table code deleted. If no, policies are missing.
4. **Squads:** flag present, slice empty (136 LOC, 0 importers), `v_squad_card` /
   `v_squad_detail` views exist in the database. Was this cut, or is it next?
5. **Payments:** `lib/features/payments/` (503 LOC) has no importers, yet
   `FeatureFlags.enablePayments` gates 2 files elsewhere and `v_wallet_balance` /
   `v_user_balance` views exist. What is the live payment path?
6. **Migrations:** ~~`supabase/migrations/` is empty — no schema history~~ **CORRECTED 2026-08-27** — `supabase_migrations.schema_migrations` holds **237 applied migrations**. The narrower open question: the repo cannot rebuild the schema (1 of 38 tracked `.sql` files has `CREATE TABLE`), so a fresh environment is not reproducible from source. The remote holds 184 tables and 336
   policies. Is schema history kept somewhere else, or has it never been captured?
7. **`dabbler_design_system`:** a git dependency with zero imports, alongside a local
   `lib/design_system/` that calls itself "temporary". Which one wins?
8. **The 6 "Coming Soon" routes** (Chat List, Messages, Social Notifications, Edit Post,
   Social Analytics, Language Selection): scheduled, or should the routes come out?
9. **Cloudflare Preview variables** — I cannot read them from the repo. Have all five
   (`SUPABASE_URL`, `SUPABASE_ANON_KEY`, `APP_NAME`, `ENVIRONMENT`, `GOOGLE_WEB_CLIENT_ID`)
   been confirmed present in **both** the Production and Preview environments since the last
   incident?

---

## 11. Handoff — who owns what

| Findings | Owner | First action |
|---|---|---|
| SEC-01 … SEC-06 | `notifications-specialist` | Owns the notification schema and RLS memory. Fix the two notification views (KAN-36/37) first, then triage the remaining 17 app views from the `SCHEMA.md` §2 census |
| SEC-07 … SEC-10, CFG-02 | `notifications-specialist` (DB scope) or a new `supabase-backend` agent | Policy triage on the 30 no-policy tables; baseline migration |
| BUG-01 … BUG-04 | `notifications-specialist` (DB) + a Flutter agent for the constants | Storage policies + bucket-name constants |
| DEAD-01 … DEAD-20, FLAG-01, FLAG-02, PROV-01, DEP-01, DEP-02 | A Flutter cleanup agent | Blocked on PO answers to Q1 and Q2 for rewards/games; the orphan screen files and `.broken` can go immediately |
| WIRE-01 … WIRE-11 | Feature agents per slice (profile, auth, games) | Start with WIRE-01/02 — it is a live user-facing failure |
| TEST-01, TEST-02 | A QA agent | First live-path test: `game_view_controller.dart` join/leave |
| ARCH-01 … ARCH-04, STYLE-01, STYLE-02, ERR-01 | Per-slice feature agents | Fold into whatever slice work happens next; do not run as a campaign |
| DOC-01 … DOC-04 | `master-analyst` | Refresh `NOTIFICATIONS.md`; correct the `CLAUDE.md` testing claim |
| CFG-01 | `version-control` | Verify Preview variables before the next Canary push |

---

## 12. Changelog

| Date | Run | Summary |
|---|---|---|
| 2026-08-27 | 1b (corrections) | **Two findings corrected after independent review.** SEC-06 understated the definer-view problem ~2×: **71 views / 49 definer / 19 anon-exposed**, not 49/25/8 — the original took the Supabase advisor's finding count for a population count, and 11 exposed views went unexamined as a result. Severity raised to **CRITICAL**. CFG-02 corrected **twice**: `supabase/migrations/` does not exist *and* `supabase_migrations.schema_migrations` holds **237 applied migrations** — the surviving finding is reproducibility (1 of 38 tracked `.sql` files has `CREATE TABLE`), not missing history. Live leaks re-filed as KAN-36/37/38. New governance: DECISIONS 019 (no agent writes production), 020 + MANIFESTO R15 (count populations, never infer). `SCHEMA.md` §2 now carries a per-view anon-exposure position for all 71 views. |
| 2026-08-26 | 1 (baseline) | First audit. 25 slices classified: 12 SHIPPED · 6 PARTIAL · 1 SCAFFOLD · 6 DEAD. 62 findings logged (10 security, 20 dead code, 11 incompleteness, 4 bugs, 2 tests, 4 architecture, 2 style, 2 dependency, 4 docs, 2 config, 1 provider). **CRITICAL:** unauthenticated read of 609 notifications across 49 users via `v_notifications_feed`/`v_notifications_ranked`; moderation queue and safety overview equally open. Headline numbers: 98/113 dead flags · 113/400 orphan providers · 21 orphan screen classes / 6,213 LOC in 10 files · 140 non-generated files >500 LOC · 22/25 features with no test dir · 5 test files vs 783 lib files (all 66 tests cover unreachable code) · 31 `Either` vs 124 `Result` files · 233 hardcoded colours · 26 `print()` · 44 empty catches · 44 `UnimplementedError` sites · 54/133 unused route constants · 0 migration files. `flutter analyze`: 0 errors. |
