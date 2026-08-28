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
| SEC-06 | Security | db: 49 views, `reloptions IS NULL` | **CRITICAL** | M | **CORRECTED 2026-08-27 — original figures were ~2× understated.** Measured live: **71 views total** (not 49), **49 `SECURITY DEFINER`** (not 25), **19 anon-readable with no `auth.uid()` predicate** (not 8). The original 25 was the Supabase advisor's *finding count* used as a *population count* | Triage all 19 — **2 are PostGIS system views (`geography_columns`, `geometry_columns`) — extension-owned metadata, NOT defects; do not re-flag**, 5 are confirmed leaking, 12 unexamined. Per-view census now in `SCHEMA.md` §2. Default every new view to `security_invoker = true`. KAN-26 |
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
| WIRE-09 | Incomplete | `app_router.dart:1607-1622` (reachable) · `1569, 1579, 1593, 1626, 1636` + `590` (orphans) | **MED** | S | **RE-CORRECTED 2026-08-27 — my 2026-08-27 correction over-generalised and the `cpo` caught it.** I verified five and asserted six. **`socialChat` is reachable and its guard does not fire.** Chain verified end to end: `user_profile_screen.dart:1094` Message button, `onPressed: () => _sendMessage(context)`, **no flag and no condition on the button** → `:1475` `context.push('${RoutePaths.socialChat}/$userId')` → route `app_router.dart:1607` → guard `:1611 if (!FeatureFlags.messaging) return RoutePaths.home` → `feature_flags.dart:53 messaging = true`, **so the guard is open** → `:1617` `_PlaceholderScreen(title: 'Chat: …')`. `UserProfileScreen` is routed at `:1463`. **Corrected population: 7 placeholder routes · 1 reachable in-app · 6 orphans.** And the six are *not* protected: `socialNotifications` (`:1579`) and `socialMessages` (`:1593`) carry guards, but `FeatureFlags.notifications` and `FeatureFlags.messaging` are **both `true`** (`feature_flags.dart:53-54`) — **no placeholder route in the app is behind a closed flag.** `socialChatList` (`:1569`), `socialEditPost` (`:1626`), `socialAnalytics` (`:1636`) and `/language_selection` (`:590`) have no guard at all. On a web build every one is URL-reachable. `socialChat`'s only distinction is that a button pushes it. **Whoever fixes this must know that flipping the flag is not a fix:** setting `messaging = false` does not disable the Message button — the button has no flag on it — it only changes the symptom from "Coming Soon" to a **silent bounce to `/home`** via the redirect at `:1611`. The button is the thing that has to change | **Two separable jobs.** (1) The Message button is the launch-facing half — either hide it until chat exists or build chat; this is the finding `cpo` carries as B4. (2) Delete the six orphan routes and their constants (6 of the 54 unused constants in FLAG-02). Owner: a Flutter agent. Re-check: `grep -rn "socialChat\|socialChatList\|socialMessages\|socialEditPost\|socialAnalytics\|language_selection" lib --include='*.dart' | grep -v route_constants.dart | grep -v app_router.dart` |
| WIRE-10 | Incomplete | `app_router.dart:590` | **LOW** | S | **CORRECTED 2026-08-27 — the original misattributed the route.** `:590` is **`/language_selection`**, an **orphan route nothing navigates to** (`grep -rn 'language_selection' lib --include='*.dart'` outside the router → empty). It was reported as `/settings/language`. **`/settings/language` is at `:1287` and renders the real 226-line `LanguageSelectionScreen`.** Language switching **works today**: `settings_screen.dart:1064` → `:1072 _showLanguagePicker()` → writes `localeProvider` → `main.dart:254` watches, `:268` passes `locale:` | **Delete the dead route.** Not a launch blocker and it does not touch `/settings/language` |
| WIRE-11 | Incomplete | `lib/core/services/analytics/analytics_service.dart:11-219` | HIGH | M | **18 `TODO: implement …`** — every tracking method is an empty body. `main.dart:78` calls `trackEvent` for the flags snapshot into a no-op | Either wire a provider or delete the service and its call sites; right now the app believes it has analytics |
| BUG-01 | Bug | `lib/core/config/supabase_config.dart:4` | HIGH | S | `venueImagesBucket = 'venue-images'` — **no such bucket**. Actual bucket is `venue`, which has **0 storage policies** of any kind | Rename the constant to `'venue'` and add INSERT + SELECT policies; unused today, so it is a trap not an outage |
| BUG-02 | Bug | `lib/features/profile/data/datasources/supabase_profile_datasource.dart:16` | MED | S | `final String _avatarBucket = 'avatars';` — bucket does not exist (real name `Avatar`). Live uploads go through `ImageUploadService` which uses `SupabaseConfig.avatarsBucket` correctly | Delete the hardcode; route through `SupabaseConfig` |
| BUG-03 | Bug | db: bucket `dabbler-news` | MED | S | INSERT policy exists, **no SELECT policy**. Public bucket so CDN reads work, but authenticated list/read-back fails — the recurring Dabbler bug class | Add a SELECT policy |
| BUG-04 | Bug | db: bucket `venue` | MED | S | Zero policies. Uploads impossible | Add INSERT + SELECT |
| SEC-11 | Security | `android/app/build.gradle.kts:36,38` | **HIGH** (was CRITICAL) | S | Play upload keystore `storePassword`/`keyPassword` in plaintext in a tracked file. **Exposure window verified: `ebaf9b8`, 2025-11-22 → 9 months.** **Downgraded 2026-08-27 on a bound the CTO and I each verified independently: the signing artifact has never been in the repo in any form.** No `.jks`/`.keystore`/`.p12`/`.pfx`/`.pepk` was **ever added on any ref in any history**; no base64 blob in `android/`, `.github/` or `scripts/`; **no workflow references signing at all** (`deploy-web.yml` is web-only, so Android signing never runs in CI); `storeFile = file("upload-keystore.jks")` resolves to a file that is **0 tracked / present only on the maintainer's machine** | Rotate the upload key, move both values to gitignored `key.properties` or CI secrets, purge from history. **The PO-facing sentence is "a credential is exposed, the signing artifact is not."** Pre-promotion requirement, **not a launch blocker** — no user is harmed today. KAN-57 |
| SEC-12 | Security | `lib/core/services/auth_service.dart:261-267` | HIGH | S | **Logout does not clean up.** `signOut()` is six lines: it calls `_supabase.auth.signOut()` and nothing else — **no local cache clear, no `fcm_tokens` row delete.** A signed-out device keeps receiving the previous account's pushes, with content in the notification body | Delete the device's `fcm_tokens` row and clear cached profile state on sign-out. **KAN-58** |
| SEC-13 | Security | `supabase/functions/send-push-notification` | **CRITICAL** (promoted 2026-08-27) | M | **Authenticates but does not authorize.** `user_id`, `title` and `body` are all caller-supplied — no relationship check between caller and recipient, no rate limit. Any registered account can deliver arbitrary text as a **trusted first-party push**. **Promoted because signup is passwordless (decision 002), so obtaining an account is free: launch multiplies the target pool and the attacker pool simultaneously** | Verify the caller may notify the recipient; add a rate limit. **Launch blocker.** KAN-59 |
| SEC-14 | Security | `android/app/src/main/AndroidManifest.xml` | MED | S | **Android Auto Backup is on by default at targetSdk 35 with no exclusion rules**, so the Supabase refresh token syncs to the user's Google Drive | Add `android:dataExtractionRules` / `android:fullBackupContent` excluding auth storage. **KAN-60** |
| BUG-05 | Bug | db: `public.v_space_slots_today` | MED | S | **Raises 42P01 for every caller.** `find_slots()` queries `public.venue_opening_hours` — verified 2026-08-27 via `to_regclass`: **that table does not exist.** Broken, not leaky. **A table named `opening_hours` does exist** — this looks like a rename that missed the function | Point `find_slots()` at `opening_hours`, or restore the expected name. Verify with a call, not a read of the definition |
| BUG-06 | Bug | `web/.well-known/assetlinks.json:7` | MED | S | **`REPLACE_WITH_SHA256_FROM_PLAY_CONSOLE_APP_SIGNING` placeholder still present** while `AndroidManifest.xml:55` declares `android:autoVerify="true"` — **Android App Links do not resolve**; deep links fall back to the chooser | Paste the SHA-256 from Play Console app signing. Verified 2026-08-27 |
| BUG-07 | Bug | `lib/features/profile/presentation/screens/profile/user_profile_screen.dart:1467-1476` | LOW | S | **The Message button silently does nothing while the block-status provider is loading or errored.** `_sendMessage` wraps the navigation in `ref.read(isUserBlockedProvider(userId)).whenData((blocked) { … context.push(…); })` — `whenData` runs the callback only in the data state, so loading and error produce no navigation and no feedback. Independent of chat existing; found by `cpo` on the WIRE-09 path | Handle all three `AsyncValue` states explicitly — block on error, spinner or disabled button while loading. Owner: a Flutter agent |
| BUG-08 | Bug | `lib/app/app_router.dart:1618` | LOW | S | `_PlaceholderScreen(title: 'Chat: ${conversationId.substring(0, 8)}...')` — `substring(0, 8)` **throws `RangeError` on any id shorter than 8 characters.** Not triggered by the in-app push (`:1475` passes a 36-char UUID) but this is a web app and the path segment is user-supplied via URL. Found by `cpo` | Dies with the route when the six orphans are deleted; if the chat route survives to real implementation, clamp the length. Owner: a Flutter agent |
| SEC-16 | Security | db: **7 app views** → 7 base tables, all `relforcerowsecurity = false`; `v_notifications_feed` + `v_notifications_ranked` → `notifications` → `trg_push_on_notification_insert` | **CRITICAL — highest on the board** | M | **An unauthenticated caller can insert a notification row and have it delivered as a push notification to any user they choose.** Raised by `cto-4` (`T-017`); every link re-verified here against `wtncuzcskpigqpmnxwws` on 2026-08-28, **catalogue only — the insert was not attempted, by either of us.** **(1) The view is writable by `anon`:** `information_schema.views.is_insertable_into = YES`, `has_table_privilege('anon','public.v_notifications_feed','INSERT') = true`. All three NOT NULL / no-default columns of the base table — `to_user_id`, `kind_key`, `title` — are present in the view, so a row is genuinely constructible. **(2) The block exists and is bypassed:** `notifications` has exactly one INSERT policy, `n_block_insert WITH CHECK (false)`, and `relrowsecurity = true`. But view and table are both owned by `postgres`, the view is **not** `security_invoker`, and **`relforcerowsecurity = false`** — Postgres skips RLS for a table's owner unless FORCE RLS is set, so the policy is never evaluated on the view path. **(3) It reaches the device:** `trg_push_on_notification_insert` is enabled (`tgenabled = 'O'`) and posts `NEW.title` and `NEW.body` **verbatim** to `send-push-notification` with an `x-trigger-secret` header read from the vault — the trusted-server path that skips the JWT and relationship checks. **The attacker chooses `to_user_id` and writes the title and body**, so this is arbitrary push content to a chosen user, delivered on the app's own trusted channel. That is a phishing primitive, not just an integrity bug. **(4) No secret is needed:** `anon` can SELECT `notification_kinds`, and **23 of 29 kinds carry `push` in `default_channels`** (all 29 `is_active`), so the required `kind_key` is public. **One mitigation, and it does not close it:** the trigger honours the *victim's* `notification_settings` — `push_enabled`, `muted_kinds`, quiet hours — so delivery is not guaranteed for every target. It gates reliability, not access. Users with no settings row get no gating at all (`_has_settings` false skips every check). **Note also `has_table_privilege('anon','public.notifications','INSERT') = true`** — a direct grant on the base table. That path *is* blocked, because RLS applies to `anon` there and `n_block_insert` denies it. The grant is still wrong and should go with the rest | **B1a — the highest-value item on the gate. Three parts, and a REVOKE-only migration is not a fix.** (1) `REVOKE` write on all tables/views in `public` from `anon`/`authenticated`, re-granting the narrow set the app actually writes. (2) **`ALTER DEFAULT PRIVILEGES … REVOKE` for both grantors** — without this the hole **reopens by itself** on the next migration that creates a view, and a re-run of the verification query would still pass. (3) `FORCE ROW LEVEL SECURITY` on the base tables reached by definer views. **Not a uid predicate, and not a definer→invoker conversion** — that belongs with the read sweep. **Low blast radius: nothing in the app writes through these views, so revoking write cannot blank a screen** — which is the opposite of how the severity reads, and is the thing to tell the PO when they weigh applying it. Audit every other definer view for a DML grant, not just a SELECT grant. **Owner: blocked — this is notification-domain work and `CONTRACT.md` §3 gives `notifications-specialist` only `supabase/schema/migrations/**` for notification migrations, while `DECISIONS.md` 019 bars every agent from writing production. See `CONTRACT.md` §11; the PO must resolve this before anyone can fix it** **WIDENED 2026-08-28 (`cto-4` `T-018`, every figure re-measured here).** This is not one view. Of 71 views: **70 grant `anon` INSERT/UPDATE/DELETE · 19 are auto-updatable · all 19 of those carry the write grant · 8 are definer AND auto-updatable AND anon-writable.** The 8: `v_needs_organiser`, `v_my_drafts`, `v_user_reputation`, `geometry_columns`, `v_hidden_list`, `v_posts_time_preview`, `v_notifications_ranked`, `v_notifications_feed`. **`geometry_columns` is the known PostGIS false positive (decision 021) — 7 app views, 1 artefact.** **Every base table they reach has `relforcerowsecurity = false`, so all 7 bypass RLS by the same owner-path mechanism.** Six have exactly one base table, so the write target is unambiguous: `v_notifications_feed` → `notifications`, **`v_notifications_ranked` → `notifications` (a second, previously unrecorded entry to the push trigger)**, `v_posts_time_preview` → `posts`, `v_my_drafts` → `content_drafts`, `v_hidden_list` → `user_hidden_modes`, `v_user_reputation` → `user_reputation_aggregate`. **`v_needs_organiser` — ESTABLISHED 2026-08-28 (`cto-4` read the `FROM` clause; re-verified here). Its target is `auth.users`, not `profiles`.** `SELECT id AS user_id FROM auth.users u WHERE NOT (EXISTS (SELECT 1 FROM profiles p WHERE …))` — `profiles` appears **only inside the NOT EXISTS subquery**, which is exactly the pickup my base-table walk could not distinguish. **The bypass here is a different mechanism from the rest of SEC-16 and `FORCE ROW LEVEL SECURITY` would not close it.** `auth.users` is owned by `supabase_auth_admin`, **not** by `postgres`, so the owner-equals-owner argument fails — but `postgres` carries **`rolbypassrls = true`** and holds INSERT on `auth.users`, which arrives at the same place by another route. `rolbypassrls` defeats FORCE RLS too. **Only the revoked grant closes this one.** **And the block being bypassed is weaker than elsewhere:** `auth.users` has `relrowsecurity = true` and **zero policies** — a deny-all — which `rolbypassrls` walks straight past. The view projects exactly `id`, and `id` is the **only** NOT NULL / no-default column on `auth.users`. **Two things remain UNESTABLISHED and must stay that way in any writeup:** (a) whether the remaining unique indexes (8) and constraints admit a row carrying only `id`; (b) whether such a row is useful to an attacker. **What is now established against (b): the row would not be inert.** An insert fires two enabled triggers — `trg_create_default_privacy_settings` and `trg_strip_signup_password` — so "harmless orphan" is not the safe default assumption. **This must not be described as account creation or account takeover.** The established claim is exactly: *an unauthenticated write path onto the identity table exists.* **Root cause, and it is generative:** `pg_default_acl` carries `ALTER DEFAULT PRIVILEGES` in `public` from **both** `postgres` and `supabase_admin` granting `anon` and `authenticated` **`arwdDxtm`** — the full privilege set — on every relation created. Verified; the `storage` schema carries the same. **This is inherited Supabase stock configuration, not something Dabbler authored** — nobody did it wrong, nobody ever turned it off |
| SEC-15 | Security | db: `public.v_game_card`, `public.v_meetup_list` | **MED** | M | **Unauthenticated callers read organiser identity from the public game and meetup listings.** Measured 2026-08-28 as `anon`: `v_game_card` returns **216 rows**, `v_meetup_list` returns **1**; control `select count(*) from public.games` as `anon` returns **0**, so these are definer views reading over a table whose RLS denies `anon` directly. **This is not the §2a leak class and must not be filed with it** — every row returned has `listing_visibility = 'public'`, so the row set is consistent with public game discovery without an account, which is plausibly intended. **NARROWED 2026-08-28 — the `auth.users` UUID half is split out as SEC-17 (HIGH). What remains here is the discovery exposure and it is genuinely MED.** An unauthenticated caller gets, per row: display name, avatar, exact `start_at`, and venue by name. **No coordinates, no address, no phone, no email** — location is venue-and-area names. Every row is `listing_visibility = 'public'`, which is a choice the organiser made about their own game, and **a game-discovery app that cannot show public games to a logged-out browser does not work.** Stated flatly — "named person, at a place, at a time, readable without an account" — it sounds worse than it is; this is the product functioning as designed. `cto` and `cto-4` both argued it independently and converged here | **PO decision, and only a PO decision** — fuzzing venue or gating exact `start_at` behind auth are real product trade-offs against discovery, and no agent should make them. `v_game_card` is the live game path (`game_view_controller.dart:399`) and cannot be revoked. **Holding at MED pending that decision; nothing here blocks the gate** |
| SEC-17 | Security | db: `v_notifications_feed` · `v_notifications_ranked` · `v_game_card` · `v_meetup_list` · `v_circle_feed` | **HIGH** | S | **61 of 240 real `auth.users` UUIDs are readable by an unauthenticated caller — 25% of the user base.** Split out of SEC-15 on `cto`'s ruling, independently argued by `cto-4`, then scoped by me across the whole anon-readable surface rather than the one view they raised. Measured as `anon` 2026-08-28, distinct non-null user ids per view: `v_notifications_feed` and `v_notifications_ranked` **51 uids / 611 rows** · `v_game_card` **25 uids / 216 rows** · `v_circle_feed` **1 uid / 6 rows** · `v_meetup_list` **1 uid / 1 row**. Union of distinct uids: **61**. `cto` confirmed the values are genuine: all 216 `v_game_card` rows have a `creator_user_id` present in `auth.users`. **Why this is HIGH while SEC-15 is MED — nobody decided to publish it.** `listing_visibility` is a product decision an organiser made; the `auth.users` primary key is a column that leaked into a public projection because someone selected too much. `v_game_card` already carries `creator_profile_id` **separately**, so this is the internal identity key sitting *alongside* the public handle, not standing in for it. **Its severity is what it unlocks, not what it reveals.** With 27 anon-granted views in play it is a join key: an auth uid on one public surface makes correlation across the others trivial, which is the *ask what a change multiplies* test applied to a column. `v_game_card` and `v_meetup_list` are the newly found pair (SEC-15); the notification views were already known leaks (SEC-06) — **but the uid column was never counted as a distinct finding, only the rows were** | **Drop the `auth.users` uid from every anon-reachable projection.** Keep `creator_profile_id` / `author_profile_id` and the display fields — the public listings lose nothing. This is **not a PO question**: a public game card has no use for the creator's auth UUID. Then, per `cto`, audit the remaining anon-granted views for the same column, because a copied projection copies the leak — I have done that sweep and the five above are the full set that returns a non-null uid to `anon`; eight more carry such a column but return zero rows and become live the moment their filters change. **DO NOT bundle with B1a — `cto` overruled my recommendation to fold it and the evidence inverts the argument; verified here 2026-08-28.** The two changes have opposite risk profiles. **KAN-67 is `REVOKE` only, privilege-level, and all 8 writable views have _zero_ Dart references** (`v_needs_organiser`, `v_my_drafts`, `v_user_reputation`, `v_hidden_list`, `v_posts_time_preview`, `v_notifications_ranked`, `v_notifications_feed`, `geometry_columns` — 0 each). That makes it the **only production change in the plan that is verifiably risk-free**, which is precisely why it can be reviewed in minutes and shipped first while a destructive hole is open. **Folding a client-affecting change into it destroys that property** — the review that should wave it through would have to reason about Dart call sites instead. **SEC-17 is `CREATE OR REPLACE VIEW` and touches 3 read sites, not 6 — corrected 2026-08-28 by `cto`, verified here.** `grep -rn 'creator_user_id' lib` returns 6, but a grep count is not a call-site count: two of the six query the **`games` table**, not the view, and are untouched by a view change — `sport_profile_view_provider.dart:264` (`.from(gamesTable)` at `:262`) and `supabase_games_datasource.dart:507` (`.from(gamesTable)` at `:505`). **The 3 that read `v_game_card`:** `game_history_providers.dart:79-80` (`.from(vGameCardTable)` at `:84`), `game_view_controller.dart:212` (`.from(vGameCardTable)` at `:399`), `game_model.dart:81` (the shared parser). **Exactly one of the three is a filter on the view** — `game_history_providers.dart:79-80` builds an `or` filter string on `creator_user_id` and applies it to the view. **That is the dangerous site: dropping the column returns a quietly wrong game history — no error, no log.** The other two are parse sites and would surface as a null. `v_game_card` has 9 references and is registered at `supabase_config.dart:219`. **And it is not a rename — there are four competing identity columns, not two.** Reference counts in `lib/`: **`host_user_id` 23 · `creator_user_id` 6 · `organizer_id` 4 · `creator_profile_id` 1.** The migration target has **one** reference in the entire app, which is the number that sizes this job: it is not a column swap, it is establishing an identity that barely exists yet. `creator_profile_id` is also a *different* identity from the auth `userId` these sites pass down, so each migration is a caller-chain change. And `game_model.dart:81` already reconciles two of them behind an empty-string default — `organizerId: json['creator_user_id'] ?? json['host_user_id'] ?? ''` — which is its own silent-failure vector: a missing identity becomes `''` rather than an error. **And that fallback is dead: `host_user_id` exists on neither `games` nor `v_game_card`** (verified 2026-08-28), so the `?? json['host_user_id']` branch can never fire from either source — it degrades straight to `''`. **`creator_user_id` does exist on the `games` table**, which is why the two `.from(gamesTable)` sites survive a view change untouched. **Add the Dart-side propagation to the migration scope:** `grep -rn 'creatorUserId' lib` returns **6** more occurrences — the typed field at `game_view_controller.dart:130,164`, its assignment at `:212`, and three consumer lines at `game_detail_screen.dart:648-653`, where it is used to route: `context` push to `'${RoutePaths.userProfile}/$creatorUserId'`. **The identity flows into navigation**, so migrating to a profile id changes a route argument, not just a parse. **Sequence with the Flutter hire, not with B1a** — migrate the 6 call sites first, then drop the uid from the projection. Blocked on the same missing Flutter owner as KAN-58 |
| DEAD-21 | Dead code | `lib/features/profile/services/data_export_service.dart` | LOW | S | **2,092 LOC, zero importers.** Verified 2026-08-28: `grep -rn 'data_export_service' lib --include='*.dart'` outside the file itself returns **nothing**, and `lib/providers.dart` never mentions it. Reported by `cto-4` as `T-016`, verified here independently | Delete, or park it explicitly if GDPR export is a planned obligation — this is the one case where "built, never connected" may be deliberate. Ask the PO before deleting. Owner: a Flutter agent |
| DEAD-22 | Dead code | `lib/core/analytics/` · `lib/core/services/cache_service.dart:78,107` · `lib/core/services/analytics/analytics_service.dart:6` | LOW | S | **The analytics layer is built and not connected, and there are two different classes called `AnalyticsService`.** Verified 2026-08-28: `grep -rn 'core/analytics' lib --include='*.dart'` outside that directory returns **nothing**; `lib/providers.dart` contains **zero** occurrences of `analytics`; `analyticsServiceProvider` is declared at `cache_service.dart:107` and **referenced nowhere else**, so the provider is orphaned too. The whole app has **one** emission site — `main.dart:78 AnalyticsService.trackEvent('flags_snapshot', …)`, which resolves to the `cache_service.dart:78` class, not the one in `core/services/analytics/` — plus one commented-out call at `content_sharing_helper.dart:320`. Reported by `cto-4`, verified here | Pick one `AnalyticsService` and delete the other — a duplicate class name that a provider silently binds to is a trap for whoever wires analytics next. Then either wire the layer or delete it. Owner: a Flutter agent |
| STYLE-03 | Convention | 8 files, 13 sites | MED | M | **Decision 010 held — 0 raw `MaterialPage`** — but a violation the convention does not name: **13 `MaterialPageRoute` sites across 8 files** bypass GoRouter via imperative `Navigator.push`, **5 of them in `sports_screen.dart`**. Verified 2026-08-27 | Extend the convention to name `MaterialPageRoute` and imperative navigation, then migrate. A rule that names only one of two ways to do the wrong thing catches only half |
| TEST-01 | Tests | `test/` | HIGH | L | 5 test files / 783 lib files. 66 tests, all passing, **all against unreachable code** (games usecases, `RegisterUseCase`) | Write the first test against the live path: `game_view_controller.dart` join/leave, and the notification repository |
| TEST-02 | Tests | `test/features/` | HIGH | L | 22 of 25 slices have no test directory at all — including `social` (28,827 LOC) and `notifications` | Start with `notifications` — it is the cleanest slice and the highest-value regression target |
| ARCH-01 | Architecture | 140 non-generated files >500 LOC | MED | L | Top offenders: `post_composer_screen.dart` (2,996), `profile_edit_screen.dart` (2,914), `social_search_screen.dart` (2,892), `post_detail_screen.dart` (2,304), `sports_screen.dart` (2,303). `CLAUDE.md` sets a 500-line limit | Split the top 5 only; a blanket campaign is not worth it |
| ARCH-02 | Architecture | `lib/app/app_router.dart` (1,745 LOC) | MED | M | Single file holds all routes, redirect logic, an inline placeholder widget, and two `rpc('is_admin')` calls (lines 1656, 1682) | Extract route groups per feature; keep `_handleRedirect` central |
| ARCH-03 | Consistency | `lib/core/utils/either.dart` + 31 files | MED | L | **EXPANDED 2026-08-27 (cto, verified).** Not two error conventions but **three**: `Result` (124 files) · `fpdart` `Either` · **a hand-written `Either` in `lib/core/utils/either.dart` used by 13 files** — all of `profile` (12) plus `auth_onboarding/application/location/location_controller.dart`. It is **not type-compatible with fpdart**. `CLAUDE.md`'s "legacy uses fpdart" is half-right, which is worse than wrong: it stops people looking. **Two files mix conventions inside one class** — `games_repository_impl.dart`, `venues_controller.dart` | Convert `social`/`auth_onboarding` first. Treat the hand-written `Either` as its own migration, not part of the fpdart one |
| ARCH-04 | Architecture | `lib/features/profile/` | MED | L | 3 parallel profile repository stacks. Live one is `lib/data/repositories/profiles_repository_impl.dart` (221 LOC); the `features/profile/data/` stack (2,534 LOC) is reachable but built on `UnimplementedError` | Collapse to one after WIRE-01/03/04 |
| STYLE-01 | Convention | `lib/features/` + 43 files repo-wide | MED | M | **CORRECTED 2026-08-27 (cto, verified by master-analyst).** Was "233 hardcoded colours" — reproducible only under an unrecorded filter (`Color(0x` substring, `lib/features/` only). **The defensible figure is 317 across 43 files**, command below. `auth_onboarding` remains the largest concentration | Fix `auth_onboarding` first. **Command:** `grep -rEo "Color\(0x[0-9a-fA-F]{8}\)" lib --include='*.dart' \| grep -vE "^lib/(themes/\|core/theme/\|core/design_system/\|design_system/\|core/config/design_system/)" \| wc -l` — the exclusions matter: counting all of `lib/` returns 1,611 because it counts the palette definitions as violations of themselves |
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
| 2026-08-28 | 1n (SEC-17 scope settled — the axis is target, not syntax) | **`cto-4` proposed that 6 and 3 are both right counting different things. They are not, and the reconciliation mislabels the two sites that matter least.** `cto-4` grouped by *syntax* — 3 "query-filter sites" vs 2 deserialize — and called the filter group "the ones that break if the column is dropped". **Two of those three filter the `games` table, not the view** (`sport_profile_view_provider.dart:264` → `.from(gamesTable)` at `:262`; `supabase_games_datasource.dart:507` → `.from(gamesTable)` at `:505`), and **`creator_user_id` exists on the `games` table**, so they are untouched by a view change. **The axis that decides scope is the query target, not the call syntax.** Settled figures: **6 raw occurrences · 5 files · 3 sites read `v_game_card` · exactly 1 of those is a filter on the view** (`game_history_providers.dart:79-80`), which is the silently-wrong-results site. **Two real additions from `cto-4`, both verified:** the Dart-side propagation — `creatorUserId` returns **6** more occurrences, including `game_detail_screen.dart:648-653` where the identity is **routed** (`'${RoutePaths.userProfile}/$creatorUserId'`), so a migration changes a route argument and not just a parse. **And its `host_user_id` migration-path hypothesis is dead, which it correctly declined to assert:** `host_user_id` exists on **neither** `games` **nor** `v_game_card`, so `game_model.dart:81`'s `?? json['host_user_id']` branch can never fire — the parser degrades straight to `''`. |
| 2026-08-28 | 1m (SEC-17 call sites corrected 6 → 3) | **`cto` caught its own overstatement and mine inherited it.** SEC-17 was scoped against "6 `creator_user_id` read sites". Verified here: **3**. Two of the six query the `games` **table**, not the view, and a view change does not touch them (`sport_profile_view_provider.dart:264`, `supabase_games_datasource.dart:507` — both `.from(gamesTable)`). **A grep count read as a call-site count**, the same instrument error as the `pg_depend` artefact: it answered *where does this string appear*, not *what breaks*. **Exactly one of the three is a filter on the view** (`game_history_providers.dart:79-80` → `.from(vGameCardTable)` at `:84`) and it is the dangerous one — a silently wrong game history. My earlier entry said two filters; on the view there is one. **Four competing identity columns, not two:** `host_user_id` 23 refs · `creator_user_id` 6 · `organizer_id` 4 · **`creator_profile_id` 1** — the migration target has a single reference in the whole app, which sizes the job as establishing an identity rather than swapping a column. `game_model.dart:81` already reconciles two behind an `?? ''` default, a silent-failure vector of the same shape as the blocklist returning 0. **Ruling unchanged — do not fold — and it now rests on a smaller, firmer number.** |
| 2026-08-28 | 1l (`v_needs_organiser` target established — `auth.users`) | **The one thing I refused to assert turned out worse than the guess I refused to make.** I left `v_needs_organiser`'s insert target UNESTABLISHED because my `pg_depend` walk could not separate a `FROM` relation from a subquery reference, and noted `profiles` would be the worst target. `cto-4` read the view definition: the target is **`auth.users`**; `profiles` appears only inside the `NOT EXISTS`. Re-verified here. **It bypasses by a second, distinct mechanism.** `auth.users` is owned by `supabase_auth_admin`, so owner-equals-owner does not apply — but `postgres` has **`rolbypassrls = true`** and INSERT on the table, reaching the same outcome. **`FORCE ROW LEVEL SECURITY` does not close it; `rolbypassrls` defeats FORCE.** Only the revoke does — which is why `v_needs_organiser` goes into the first REVOKE ahead of the notification views, and it is free to close: 0 client references. Added here: `auth.users` has RLS enabled with **zero policies** (a deny-all) that `rolbypassrls` walks past, and an insert would fire **two enabled triggers**, so the row would not be inert. Exploitability stays UNESTABLISHED and the finding is stated as *a write path onto the identity table*, never as account creation. **`SCHEMA.md` §11 check #4 amended** — "does RLS actually execute" must test `relforcerowsecurity` **and** `rolbypassrls` on the executing role, or it passes this case. |
| 2026-08-28 | 1k (SEC-17 sequencing overruled) | **`cto` overruled my recommendation to fold SEC-17 into KAN-67; verified and adopted.** I argued bundling because it is the same file and the same review. The evidence inverts it: **all 8 anon-writable views have zero Dart references**, which makes KAN-67 the only verifiably risk-free production change in the plan — the exact property that lets it be waved through in minutes while a destructive hole is open. **SEC-17 touches 6 `creator_user_id` read sites, two of them query filters**, so it is a coordinated Dart + SQL change and would have dragged the revoke behind the missing Flutter owner. "Same file, same review" was the argument *against* folding, not for it. Added here beyond `cto`'s case: the two filter sites fail as **silently wrong results** rather than as errors, and `creator_profile_id` is a different identity from the auth `userId` the call sites pass — so this is an identity-model migration per site, not a column rename. |
| 2026-08-28 | 1j (SEC-16 widened — the write hole is project-wide and self-healing in the wrong direction) | **`cto-4` measured AC#5 and it changes the fix, not just the size.** Re-measured here, every figure reproduces: of 71 views **70 grant `anon` INSERT/UPDATE/DELETE · 19 are auto-updatable · all 19 carry the grant · 8 are definer + auto-updatable + anon-writable** (7 app views + `geometry_columns`, the known PostGIS artefact). **Root cause is `pg_default_acl`:** `ALTER DEFAULT PRIVILEGES` in `public` from **both** `postgres` and `supabase_admin` grants `anon`/`authenticated` `arwdDxtm` on every relation created — inherited Supabase stock configuration, never authored here and never turned off. `storage` carries it too. **Consequence: a REVOKE-only migration passes its own verification query and then silently regresses on the next `CREATE VIEW`.** The fix must include `ALTER DEFAULT PRIVILEGES … REVOKE` for both grantors. **Extension found here, beyond `T-018`:** walking each writable view to its base tables shows **all 7 base tables have `relforcerowsecurity = false`**, so every one bypasses RLS by the same owner path — and **`v_notifications_ranked` is a second, previously unrecorded entry to `notifications` and therefore to the push trigger.** Six views have a single base table so their write target is unambiguous; **`v_needs_organiser` resolves to two (`profiles`, `users`) and its insert target is deliberately left UNESTABLISHED.** `cto-4` also superseded its own `T-017` "only one view carries the integrity risk" — it had generalised from the three views the `cpo` happened to name. Same population error both of us made this morning, one layer up. |
| 2026-08-28 | 1i (SEC-15 split) | **`cto` ruled and `cto-4` argued the same split independently: severity attaches to the column, not the view.** SEC-15 narrowed to **MED** for the discovery exposure — display name, avatar, `start_at`, venue name, on rows the organiser marked public, with no coordinates or contact details; a discovery app must show public games to a logged-out browser. **`creator_user_id` split out as SEC-17 at HIGH**, then scoped past the one view they raised: sweeping every anon-granted definer view for an `auth.users`-shaped uuid and probing each as `anon` gives **61 distinct real `auth.users` UUIDs readable with no account — 25% of the 240-user base** — across five views. The notification views were already known leaks, **but only their row counts had ever been counted; the uid column itself was never a finding.** Eight further views carry such a column and currently return zero rows. The reusable rule, `cto`'s words: **a view can be correctly public and still carry one field that has no business in it** — grading a view as a unit is the same shape as the grant/predicate error, one level down. |
| 2026-08-28 | 1h (write path found) | **`cto-4` found a write path into `notifications` that reaches push delivery with no account, and I verified every link of it against the live catalogue.** Filed as **SEC-16, CRITICAL, now the highest item on the board** — the audit had treated the definer-view problem as a *confidentiality* problem for two runs, and it is also an *integrity and delivery* problem. `v_notifications_feed` is `is_insertable_into = YES` with `anon` holding INSERT; `n_block_insert WITH CHECK (false)` exists but is never evaluated because view and table are both owned by `postgres`, the view is not `security_invoker`, and `relforcerowsecurity = false`; `trg_push_on_notification_insert` then posts attacker-controlled `title`/`body` to the trusted `x-trigger-secret` endpoint for an attacker-chosen `to_user_id`. Neither of us attempted the insert. **Correction adopted from `cto-4`, narrowing my record:** only **one** view is writable — `v_mod_queue_open` and `v_safety_overview` are `is_insertable_into = NO`, because aggregates are not auto-updatable. They keep the same wide grants and stay confidentiality-only. **And a correction to `cto-4`:** its "23 of 29 push-enabled" was read from a `push_enabled` column that does not exist on `notification_kinds`; the real columns are `default_channels` and `is_active`. The number is right anyway — 23 of 29 active kinds carry `push` in `default_channels` — but the derivation must be recorded correctly or the check is not reproducible. |
| 2026-08-28 | 1g (view census re-probe) | **`cto-4` challenged the 19 with a count of 27; both numbers were wrong and mine was wrong in the more dangerous direction.** Re-measured against `wtncuzcskpigqpmnxwws`: **71 views · 49 definer · 22 invoker · 27 definer-and-anon-granted.** `cto-4`'s 27 is a *privilege* count, not an *exposure* count — 6 of the 27 return zero rows to `anon`, so 27 overstates the leak. But probing the remaining 8 broke my own bucket: **`v_game_card` returns 216 rows to `anon` and `v_meetup_list` returns 1.** I had filed all 8 as "safe by `auth.uid()` predicate" **on a text match against the view definition, never having queried them.** They are filtered by `listing_visibility = 'public'`, not by `auth.uid()` — right outcome for the row set, wrong mechanism in my record, and two views I called safe are readable. Not promoted to the §2a leak class: every row returned is marked public. Filed instead as **SEC-15 (MED)** on the column set — unauthenticated callers get `creator_user_id`, username, display name, avatar, start time and venue. `SCHEMA.md` §2b rewritten with per-view row counts and a control query. Also adopted from `cto-4` after independent verification: **DEAD-21** (`data_export_service.dart`, 2,092 LOC, zero importers) and **DEAD-22** (`lib/core/analytics/` unimported, two classes named `AnalyticsService`, one emission site). `cto-4`'s `pg_stat_statements_info` item did **not** verify — it exists in the `extensions` schema and nothing in `public` references it; logged as a false positive. |
| 2026-08-27 | 1f (WIRE-09 re-correction) | **My own correction was wrong, in the direction of relief.** Yesterday's 1d pass downgraded WIRE-09 to LOW on the claim that *all six* placeholder routes are orphans. **Five are. `socialChat` is not.** A live, unconditional Message button on every user profile (`user_profile_screen.dart:1094` → `:1475`) pushes it, and its `FeatureFlags.messaging` guard is open (`feature_flags.dart:53 = true`), so the user lands on "Coming Soon". This contradicted `INDEX.md` §11b's own INV-01, which was right, and the blanket claim would have retired a real `cpo` blocker (B4). Caught by `cpo`, verified independently here. **WIRE-09 restored to MED** with the population corrected to **7 placeholder routes · 1 reachable · 6 orphans**, and with the further finding that **no placeholder route is behind a closed flag** — the two that carry guards have open ones. Two new defects on the same path adopted from `cpo`: BUG-07 (`whenData` swallows loading/error, button does nothing) and BUG-08 (`substring(0, 8)` `RangeError` on a short URL id). |
| 2026-08-27 | 1e (severity re-sort) | **SEC-11 downgraded CRITICAL → HIGH; SEC-13 promoted to CRITICAL.** The keystore bound was verified independently by the CTO and me and is stronger than first stated: **no signing artifact has ever existed in the repo on any ref, and Android signing never runs in CI** — so a credential is exposed and the artifact is not. SEC-13 promoted on the interaction the original assessment missed: passwordless signup makes an account free, so **launch scales the attacker pool and the target pool at once.** Exposure window for SEC-11 now verified at 9 months (`ebaf9b8`, 2025-11-22). |
| 2026-08-27 | 1d (attribution audit) | **WIRE-10 was wrong and the error reached a launch-gate P0 before anyone caught it.** `:590` is `/language_selection` — an orphan route — not `/settings/language`, which is at `:1287` and renders a working 226-line screen. **Language switching works today.** The `cpo` sourced the claim from this record, as its definition instructs, and escalated MED → P0 without opening the screen; it has retracted. **Re-checked every sibling `WIRE-` entry that names a route or line, which is how WIRE-09 was caught: all six of its placeholder routes are also orphans** — every owning `RoutePaths` constant is referenced only by its own declaration. Both downgraded to LOW with disposition *delete the dead route*. WIRE-02/05/06/11 line citations re-verified and hold. |
| 2026-08-27 | 1c (cto reconciliation) | **CTO ran an independent pass (KAN-39/KAN-64) and we converged on the leak, the 19-view population, `flutter analyze` and `flutter test` — measured separately before either read the other.** Four deltas resolved: 143 vs 140 god files (mine excludes generated l10n — CTO agreed, `T-010`); **STYLE-01 corrected 233 → 317 with the command recorded**, because 233 was reproducible only under a filter I never wrote down; **ARCH-03 expanded — three error conventions, not two**, incl. a hand-written `Either` in `lib/core/utils/either.dart` used by 13 files and not fpdart-compatible; decision 010 held but STYLE-03 added for 13 `MaterialPageRoute` sites. **Six new findings adopted after independent verification:** SEC-11 keystore plaintext, SEC-12 logout leaves FCM token, SEC-13 push authz, SEC-14 Android Auto Backup, BUG-05 `v_space_slots_today` 42P01, BUG-06 assetlinks placeholder. PostGIS views marked do-not-re-flag in SEC-06. |
| 2026-08-27 | 1b (corrections) | **Two findings corrected after independent review.** SEC-06 understated the definer-view problem ~2×: **71 views / 49 definer / 19 anon-exposed**, not 49/25/8 — the original took the Supabase advisor's finding count for a population count, and 11 exposed views went unexamined as a result. Severity raised to **CRITICAL**. CFG-02 corrected **twice**: `supabase/migrations/` does not exist *and* `supabase_migrations.schema_migrations` holds **237 applied migrations** — the surviving finding is reproducibility (1 of 38 tracked `.sql` files has `CREATE TABLE`), not missing history. Live leaks re-filed as KAN-36/37/38. New governance: DECISIONS 019 (no agent writes production), 020 + MANIFESTO R15 (count populations, never infer). `SCHEMA.md` §2 now carries a per-view anon-exposure position for all 71 views. |
| 2026-08-26 | 1 (baseline) | First audit. 25 slices classified: 12 SHIPPED · 6 PARTIAL · 1 SCAFFOLD · 6 DEAD. 62 findings logged (10 security, 20 dead code, 11 incompleteness, 4 bugs, 2 tests, 4 architecture, 2 style, 2 dependency, 4 docs, 2 config, 1 provider). **CRITICAL:** unauthenticated read of 609 notifications across 49 users via `v_notifications_feed`/`v_notifications_ranked`; moderation queue and safety overview equally open. Headline numbers: 98/113 dead flags · 113/400 orphan providers · 21 orphan screen classes / 6,213 LOC in 10 files · 140 non-generated files >500 LOC · 22/25 features with no test dir · 5 test files vs 783 lib files (all 66 tests cover unreachable code) · 31 `Either` vs 124 `Result` files · 233 hardcoded colours · 26 `print()` · 44 empty catches · 44 `UnimplementedError` sites · 54/133 unused route constants · 0 migration files. `flutter analyze`: 0 errors. |

---

# PART II — APPLICATION INVENTORY

**Inventory run:** 2026-08-27 · **Branch:** `Canary` · **HEAD:** `5f92904`
**Scope:** the shipped application surface — every screen, every flow, every affordance.
**Method:** static reachability only. No runtime testing, no manual QA. Three measures are
used and must not be confused:

1. **Import-reachable** — a file-level BFS over `import`/`export`/`part` edges starting at
   `lib/main.dart`. A file outside this set is not compiled into the app at all.
2. **Route-referenced** — the screen class appears in `lib/app/app_router.dart`.
3. **UI-reachable** — some widget the user can actually see navigates there.

A screen can be route-referenced and still never reachable by tapping. **Dabbler ships as
Flutter Web on Cloudflare Pages (`app.dabbler.pro`), so every registered route path is
reachable by typing a URL**, whether or not a button points at it. That distinction is
load-bearing for several findings below.

Reproduce: `/Users/moatazmustapha/.claude/jobs/*/tmp/reach.py` (import BFS) and
`census.sh` (class census).

## 13. The headline number

**69,612 lines across 267 non-generated Dart files are not import-reachable from
`lib/main.dart`.** They are in the repository and not in the app.

| Measure | Value |
|---|---|
| Dart files under `lib/` | 835 (incl. generated) |
| Import-reachable from `main.dart` | 558 |
| **Unreachable, non-generated** | **267 files / 69,612 LOC** |
| Screen/page/view classes | 101 |
| — referenced in `app_router.dart` | 74 |
| — pushed from a routed screen, not routed themselves | 2 (`SavedLocationsScreen`, `SportsLibraryScreen`) |
| — orphaned public screens | 7 |
| — private helper views (`_ErrorView`, `_EmptyView`, …) | 18 |
| `GoRoute` declarations | 90 |
| `RoutePaths` constants | 99 declared · **21 referenced nowhere** |
| `RouteNames` constants | 96 declared · **44 referenced nowhere** |

**Correction to run 1.** The baseline logged "21 orphan screen classes / 6,213 LOC in 10
files" and "54/133 unused route constants". Both were narrower measures than the population.
The dead surface is **~11× larger** than the orphan-screen figure suggested, and the route
constants are **195 declared / 65 unused**, not 133/54.

## 14. Screen inventory

### 14a. Orphaned public screens — 7

Zero references outside their own file, not import-reachable.

| Screen | File | LOC |
|---|---|---:|
| `CreatePostScreen` | `lib/features/social/presentation/screens/create_post_screen.dart:21` | 1,196 |
| `ExploreNearbyScreen` | `lib/features/explore/presentation/screens/explore_nearby_screen.dart:22` | 864 |
| `CreateGameScreen` | `lib/features/misc/presentation/screens/create_game_screen.dart:16` | 763 |
| `GamesNearbyScreen` | `lib/features/games/presentation/screens/games_nearby_screen.dart:22` | 722 |
| `VenuesNearbyScreen` | `lib/features/venues/presentation/screens/venues_nearby_screen.dart:23` | 619 |
| `SportsHistoryScreen` | `lib/features/explore/presentation/screens/sports_history_screen.dart:102` | — |
| `FavoriteVenuesScreen` | `lib/features/explore/presentation/screens/sports_screen.dart:1782` | — |

`CreatePostScreen` is **superseded, not missing**: the live composer is
`PostComposerScreen` (`lib/features/social/presentation/screens/post_composer_screen.dart`,
2,996 LOC), routed at `lib/app/app_router.dart:1376-1386`. Two full post composers exist;
one is wired.

### 14b. Routes that render a placeholder — 6

`_PlaceholderScreen` (`lib/app/app_router.dart:1715-1745`) renders a construction icon and
the text **"<title>\nComing Soon"**.

| Route | Line | Linked from live UI? |
|---|---|---|
| `socialChat/:userId` — "Chat: …" | `app_router.dart:1617` | **YES** — see 16a |
| `socialChatList` — "Chat List" | `app_router.dart:1573` | no |
| `socialMessages` — "Messages" | `app_router.dart:1601` | no |
| `socialNotifications` — "Social Notifications" | `app_router.dart:1587` | no |
| `socialEditPost` — "Edit Post" | `app_router.dart:1630` | no |
| `socialAnalytics` — "Social Analytics" | `app_router.dart:1640` | no |

A seventh construction screen is inlined directly in the router:
`/language_selection` → `Text('Language Selection - Coming Soon')`
(`lib/app/app_router.dart:590`).

### 14c. Route-registered but no UI navigates there — 31 `RoutePaths`

Reachable by URL on web, invisible in the app. Includes `rewards`, `adminModerationQueue`,
`adminSafetyOverview`, `socialEditPost`, `socialAnalytics`, `register`,
`onboardingPersonaSelection`, and the four `socialOnboarding*` screens. The tab routes
(`community`, `venuesTab`, `gamesTab`, `sportsExplore`, `activities`) are **not** in this
category despite appearing router-only — they are entered via
`StatefulNavigationShell.goBranch(index)`
(`lib/features/home/presentation/screens/main_navigation_screen.dart:219-236`), which is
correct and not a finding.

## 15. Flow traces — what a user can actually do

| # | Flow | Verdict | Breaks at |
|---|---|---|---|
| 1 | Cold start / redirect | **WORKS** | — |
| 2 | Sign up / sign in (OTP, passwordless) | **WORKS** (happy path) | crash path, see 16b |
| 3 | Onboarding completion | **WORKS, silently partial** | see 16c |
| 4 | Profile view / edit / real avatar / sport profiles | **WORKS** | — |
| 5 | Sign out · account deletion | **WORKS** | — |
| 6 | Game creation (live composer) | **WORKS** | — |
| 7 | Game discovery (nearby, filters) | **WORKS** | — |
| 8 | Join / leave / waitlist / join-request | **WORKS** | — |
| 9 | Game detail + host actions | **WORKS** | no cancel-game action exists |
| 10 | Venues browse / detail / favourite | **WORKS** | share → "Sharing coming soon" |
| 11 | Venue submission | **WORKS** | — |
| 12 | Social feed (For You / Following / News) | **WORKS** | — |
| 13 | Create a post | **WORKS** | Circle visibility, see 16d |
| 14 | Follow / unfollow | **WORKS** | — |
| 15 | Social search | **WORKS** | — |
| 16 | Notifications + FCM + preferences | **WORKS** | — |
| 17 | News browse + detail | **WORKS** | — |
| 18 | Admin moderation / safety | **WORKS** for an admin | no in-app link; URL only |
| 19 | **Chat / messaging** | **NOT SHIPPED, ADVERTISED** | see 16a |
| 20 | **Circles** | **NOT REACHABLE** | see 16d |
| 21 | **Rewards / check-in** | **NOT REACHABLE** | flag off, see 16e |
| 22 | Game creation (7-step wizard) | **DEAD** | see 16f |
| 23 | Explore search | **WORKS as a local filter only** | see 16g |

**Key hop citations.** Game creation: `GameComposerScreen`
(`lib/features/misc/presentation/screens/game_composer_screen.dart:525`) → `submit()`
`:402-515` → `rpc_create_game` at `:490` / `rpc_update_game` at `:461`; errors surfaced at
`:493-513` and `:569-584`. Join: `game_detail_screen.dart:355` →
`game_view_controller.dart:481-518` → `rpc_join_game`. Post: `PostComposerScreen` →
`post_composer_providers.dart:502,611` → `post_repository_impl.dart:1058` → `posts`.
Follow: `real_friends_screen.dart:888-917` → `profile_follows`. Notifications:
`notifications_screen_v2.dart:66` → `notifications_repository_impl.dart:26-42`; FCM token
upsert at `push_notification_service_mobile.dart:254-271`.

## 16. Findings — the promise gap

Measured over **import-reachable files only**. The same patterns in dead files are excluded
because they cannot affect a user.

| Pattern | Live | Dead |
|---|---:|---:|
| `UnimplementedError` | 30 | 21 |
| `TODO`/`FIXME` | 25 | 1 |
| "coming soon" in user-visible text | 12 | 3 |
| "not implemented"/"under development" | 8 | 20 |
| Simulated / mock data | 8 | 57 |
| Empty `onPressed: () {}` | 5 | 1 |
| Empty `onTap: () {}` | 1 | 1 |

### 16a. INV-01 — CRITICAL: a live button leads to "Coming Soon"

`user_profile_screen.dart:1094` renders a **"Message"** button on the routed
`UserProfileScreen` (`lib/app/app_router.dart:1463`). It checks block status, then
`context.push('${RoutePaths.socialChat}/$userId')` (`:1475`). That route resolves to
`_PlaceholderScreen(title: 'Chat: …')` at `lib/app/app_router.dart:1617` — a construction
icon and the words "Coming Soon".

A full chat implementation exists and is not wired:
`chat_controller.dart` (741 LOC) and `chat_input_widget.dart` (695 LOC) are both
import-unreachable with zero references outside their own files.

**This is the single most visible broken promise in the app.** It is on the profile of
every other user.

### 16b. INV-02 — HIGH: a redirect target that has no route

`RoutePaths.onboardingPersonaSelection` (`lib/utils/constants/route_constants.dart:46`,
**declared twice** — also at `:169`) is used as a redirect destination at three places in
`lib/app/app_router.dart` — `:194`, `:211`, `:329`. Verified:

```
grep -n "onboarding-persona-selection" lib/app/app_router.dart   → no match
```

**No `GoRoute` registers this path.** Any redirect that resolves to it falls through to
`errorBuilder` (`lib/app/app_router.dart:146`) and the user lands on the error page. The
live trigger is the DB resume path: `onboarding_controller.dart:154-155` ("Unknown state —
restart from persona selection") → `app_router.dart:329`, evaluated on every authenticated
app load whose onboarding step is `checking`.

Dormant for a clean first-time signup. Not dormant for a user whose profile row does not
match the three recognised completion shapes.

### 16c. INV-03 — HIGH: onboarding can complete with its dependent rows missing

`rpc_onboard_profile` sets `profiles.onboard = true` atomically
(`auth_service.dart:1052-1063`). The persona-table insert and the `sport_profiles` insert
are **separate, non-transactional calls whose failures are swallowed**:
`auth_service.dart:1081-1082`, `:1090-1091`, `:1099-1100` are all empty `catch (_) {}`.

Result: `onboard = true` with no `player`/`organiser`/`hoster` row and no sport profile. The
router treats that user as fully onboarded and admits them to the app. There is no
reconciliation or repair path. This is also the most likely producer of the INV-02 crash.

### 16d. INV-04 — HIGH: two settings screens report success without saving anything

**Avatar upload at `/profile/photo`** —
`lib/features/profile/presentation/screens/settings/profile_avatar_screen.dart:624-660`:

```dart
await Future.delayed(const Duration(seconds: 2)); // Simulate upload
...
const SnackBar(content: Text('Avatar uploaded successfully!'), backgroundColor: Colors.green)
```

No storage call, no repository call, nothing persisted. Routed at
`lib/app/app_router.dart:1063-1070`. A *real* avatar upload exists on a different route,
`/profile/edit` (`profile_edit_screen.dart:914-922` → `image_upload_service.dart:122-211`).
Two entry points for the same action; one lies.

**Availability preferences** —
`lib/features/profile/presentation/screens/preferences/availability_preferences_screen.dart:1045-1059`:
`_saveSettings()` is a `SnackBar('Availability settings saved!')` and nothing else. The file
contains no `.from()`, no `.rpc()`, no repository call. Routed at
`lib/app/app_router.dart:1311`. Mitigating: the settings menu entry that pointed at it is
commented out (`settings_screen.dart:88`), so it is currently URL-only.

**Circle visibility.** `PostComposerScreen` offers "Circle — shared with a specific circle"
in its visibility picker (`post_composer_screen.dart:1105-1140`) but contains no circle
picker; `grep -n "circleId" post_composer_screen.dart` returns nothing. Selecting it and
submitting always fails validation at `post_composer_providers.dart:514`: *"Select a circle
to post to."* The real picker (`CirclePickerSheet` → `CircleManagementSheet`, 740 LOC) is
wired only into the dead `create_post_screen.dart`. **Circles has no live entry point at
all** while the composer advertises it.

### 16e. INV-05 — MEDIUM: `/transactions` shows fabricated money

`lib/features/misc/presentation/screens/transactions_screen.dart:51` — `_transactions` is a
hardcoded list: `'Football Game Payment'`, `'amount': 150.00`, `'currency': 'AED'`, comment
*"Mock transaction data - Replace with real data from repository"*. The screen is routed at
`lib/app/app_router.dart:1165`, gated on `FeatureFlags.enablePayments`, which is **`true`**
(`feature_flags.dart:132`). Two of its buttons are `onPressed: () {}` (`:1021`, `:1032`).

No in-app link points at `/transactions` — but it is a live route on a web app, and it
displays invented financial records.

Same class of finding: `SocialOnboardingFriendsScreen` is routed
(`lib/app/app_router.dart:1487`) and shows fabricated friend suggestions — "John Smith",
avatars fetched from the external placeholder service `i.pravatar.cc` — plus a faked
contacts-permission request (`social_onboarding_friends_screen.dart:31,77`).

### 16f. INV-06 — MEDIUM: linked stub screens in Settings

`settings_screen.dart:294` is a live info-circle button that pushes `/help/center` →
`HelpCenterScreen` → **"This screen is under development"**
(`lib/features/misc/presentation/screens/help_center_screen.dart:32`).

`ContactSupportScreen` (`/help/contact`, routed at `lib/app/app_router.dart:1332`) offers
three list rows whose entire handler is a SnackBar: *"FAQ section coming soon"* (`:388`),
*"Live chat coming soon"* (`:414`), *"Phone call functionality coming soon"* (`:441`).

`RewardsScreen` (`lib/features/misc/presentation/screens/rewards_screen.dart:22`) is
`Text('Rewards Screen - Under Construction')`.

Venue share: `venue_detail_screen.dart:922` → `_snack('Sharing coming soon')`.

### 16g. INV-07 — MEDIUM: the dead game-creation wizard designed three shipped-nothing capabilities

The 7-step wizard under `lib/features/misc/presentation/screens/` is confirmed unreachable —
only `create_game_screen.dart:6-10` imports the five steps, and nothing imports
`create_game_screen.dart`. What it was built to do that the live composer cannot:

- **Payments** — payment split host-pays / split-evenly / custom, per-player AED cost
  (`participation_payment_step.dart:396-414`, `:91-208`, `_calculateCostPerPlayer:420-432`).
  The live composer has no cost field at all.
- **Venue slot booking** — a dedicated search/filter venue-slot UI
  (`venue_slot_step.dart:16-51`).
- **Player invitations** — invite from contacts / recent teammates / search with a custom
  message (`player_invitation_step.dart:20-33`) — itself backed by `_loadMockData()` (`:34`,
  `:44`), so it was never functional either.

`rebook_flow.dart:26-27` is a stub reading "This screen is under development".

### 16h. INV-08 — LOW: search is a client-side filter, not a search

`ExploreScreen` (class in `sports_screen.dart:378`, routed at `lib/app/app_router.dart:899`)
has a search field at `sports_screen.dart:1555-1599` that substring-filters the already
fetched in-memory list (`:1046-1059`). There is no server-side search RPC or full-text
query. A user searching for a sport or venue outside the loaded page gets no results.

## 17. Corrections to the record

Four established facts were wrong and are corrected here.

| Was recorded | Actually | Evidence |
|---|---|---|
| Live composer at `lib/features/games/.../game_composer_screen.dart` | It is at **`lib/features/misc/`** — the `games/` path does not exist | `find lib -name game_composer_screen.dart` |
| `get_nearby_posts` LIVE via `feed_repository_impl.dart` | **Dead.** `feedRepositoryProvider` / `nearbyRpcFeedProvider` are referenced only inside `feed_providers.dart` itself. The live feed is `TabFeedNotifier` → `post_repository_impl.dart:449-507`, a direct bounding-box query on `posts`, no RPC | `grep -rn "nearbyRpcFeedProvider\|feedRepositoryProvider" lib` |
| rewards: "only check-in (~985 LOC) live" | **Nothing in rewards is live.** `FeatureFlags.enableRewards = false` (`feature_flags.dart:57`) gates both the route (`app_router.dart:932`) and the check-in modal trigger (`main_navigation_screen.dart:81,96`). The implementation is complete and switched off | `grep -n enableRewards` |
| 54 of 133 route constants unused | **65 of 195.** `RoutePaths` 99 declared / 21 unused; `RouteNames` 96 declared / 44 unused | census script §13 |

## 18. Looks bad but is actually fine

Mandatory section. Each of these trips a scanner and is not a finding.

- **`route: ''` on two Settings items** (`settings_screen.dart:107,114`, Language and App
  Country). Reads as a navigation to nowhere. `_navigateToSetting` (`:1062-1070`)
  special-cases both by title and opens a picker sheet. Correct behaviour.
- **Help Center / Contact Support / Availability removed from the Settings list**
  (`settings_screen.dart:88,127,134,141` are commented out). The team already hid the stubs.
  Only the stray info button at `:294` still reaches one.
- **Rewards hidden cleanly.** No nav destination references `RoutePaths.rewards` and no
  routed screen mentions rewards. The flag hides an unfinished feature properly — this is
  the pattern the other stubs should follow.
- **`notifications_screen_v2.dart` / `activities_screen_v2.dart`** are the live routed
  screens, not abandoned rewrites. Unchanged from run 1.
- **Tab routes appearing "router-only"** — entered via `goBranch(index)`, not by path.
- **`_ErrorView` / `_EmptyView` counted as orphan classes** — private per-file helpers, 18
  of the 25 non-routed classes. Not screens.
- **`onPressed: null`** on a disabled button is a valid Flutter idiom for the disabled
  state, not a dead handler.
- **`UnimplementedError` in `settings_repository_impl.dart`** (25 sites) — the class doc at
  `:14-15` declares them deliberate. The notification/theme/accessibility methods are not
  called by any reachable UI; those screens use `notificationSettingsControllerProvider`
  instead. Only the privacy methods are wired, and those are implemented.
- **18 of the 44 `UnimplementedError` sites from run 1** live in
  `lib/features/profile/data/providers/profile_providers.dart` and the two stub repos it
  instantiates — that file is imported by nothing. Dead, not broken.

## 19. Handoff

| Finding | Owner | First action |
|---|---|---|
| INV-01 chat button → Coming Soon | Flutter feature agent | Hide the Message button behind a flag, or wire `chat_controller.dart`. Hiding is one line |
| INV-02 missing `onboardingPersonaSelection` route | Flutter feature agent | Register the route or change the three redirect targets. Also de-duplicate the constant declared at `route_constants.dart:46` and `:169` |
| INV-03 non-transactional onboarding | `cto` decides, then Supabase agent | Either fold persona + sport insert into `rpc_onboard_profile`, or stop swallowing the catches |
| INV-04 fake-success saves | Flutter feature agent | Delete `/profile/photo` (a real one exists at `/profile/edit`); make availability write or remove the route. Remove the Circle option from the composer until a picker exists |
| INV-05 fabricated transactions + fake friends | `cpo` decides, then Flutter agent | Flip `enablePayments` off or delete the route; same for `SocialOnboardingFriendsScreen` |
| INV-06 linked stub screens | Flutter feature agent | Remove `settings_screen.dart:294`; hide `/help/contact` rows |
| INV-07 dead wizard (4,972 LOC) | `cpo` | Payments, venue-slot booking and invitations are unbuilt product, not just dead code. Decide before deleting |
| INV-08 client-side search | `cto` | Decide whether server-side search is in launch scope |
| 69,612 LOC unreachable | `cpo` + `cto` | Supersedes the run-1 deletion list. Needs a decision, not a campaign |

## 20. Changelog

| Date | Run | Summary |
|---|---|---|
| 2026-08-27 | 2 (application inventory) | **Full map of the shipped surface at `5f92904`.** 267 non-generated files / **69,612 LOC** not import-reachable from `main.dart` — ~11× the run-1 orphan-screen figure. 101 screen classes: 74 route-referenced, 2 push-only, 7 orphaned public, 18 private helpers. **19 of 23 user flows complete end to end.** Four do not: chat is advertised by a live button and lands on "Coming Soon" (INV-01), Circles has no entry point while the composer offers it, rewards is complete but flagged off, the 7-step game wizard is dead. Two settings screens report success without writing (INV-04). `/transactions` shows fabricated AED amounts on a live route (INV-05). One redirect target has no registered route (INV-02). Onboarding can set `onboard = true` with dependent rows missing (INV-03). **Four record corrections:** composer lives in `misc/` not `games/`; `get_nearby_posts` is dead not live; nothing in rewards is live; route constants are 65/195 unused not 54/133. |

| 2026-08-28 | 3 (repo hygiene) | **Root and tree hygiene inventory at `1b83967`, §21.** 749 files / ~6.6 MB proposed for removal, **73 of them tracked** — 51 are `macos/`+`windows/`+`linux/` (no build, no CI job, no store target references them; `pubspec.yaml:168-171` states the position itself). Root holds 7 tracked regenerable artifacts (1,053,654 B, of which one 553 KB analyzer dump and one 432 KB PDF). Of the 5 root docs: `PRODUCTION_READINESS_REVIEW.md` DELETE (superseded, and its "maintainability High" verdict is now known false); `APPLE_REVIEW_SIGNIN.md`, `task_20_flutter_overhaul.md`, `flutter_localization_checklist.md` MOVE (all still operationally live); `ONBOARDING_AUDIT.md` folded in then delete. **Two findings folded in:** HYG-01 two dead onboarding services, 320 LOC, zero importers; HYG-02 `OnboardingData` declared twice incompatibly. **Two false positives caught:** `packages/` is a load-bearing `dependency_overrides` path dep, and the 5 `post_comments_*_fkey` strings resolve correctly (constraint names survived the table rename — verified against the live DB). |

### SEC-15 — `anon` holds WRITE grants on all five leaking views (NEW, 2026-08-28)

**B1 is not a confidentiality defect alone.** Measured against `wtncuzcskpigqpmnxwws`,
2026-08-28, read-only:

```sql
select table_name, grantee, privilege_type from information_schema.role_table_grants
 where table_schema='public' and table_name in ('v_notifications_feed','v_notifications_ranked',
 'v_mod_queue_open','v_safety_overview','v_circle_feed') and grantee in ('anon','authenticated');

select table_name, is_updatable, is_insertable_into from information_schema.views
 where table_schema='public' and table_name in (...same five...);
```

| View | `anon` grants | auto-updatable | SECURITY DEFINER | rows to `anon` |
|---|---|:--:|:--:|---:|
| `v_notifications_feed` | SELECT INSERT UPDATE DELETE TRUNCATE REFERENCES TRIGGER | **YES** | yes | 609 (with ranked) |
| `v_notifications_ranked` | same full set | **YES** | yes | — |
| `v_mod_queue_open` | same full set | NO | yes | 9 |
| `v_safety_overview` | same full set | NO | yes | 1 |
| `v_circle_feed` | same full set | NO | yes | 6 |

**The composition.** The two auto-updatable views are the same two that bypass RLS on read
(base table returns 0 to `anon`; view returns 609). Postgres routes writes through an
auto-updatable view to the base table; SECURITY DEFINER executes as owner. **Every
precondition for unauthenticated INSERT/UPDATE/DELETE of other users' notifications is
present and measured.**

**Not demonstrated:** the write itself. Executing it is a data change and decision 019
forbids it, diagnostic intent included. Claim scope: *preconditions verified, exploitation
not demonstrated.*

**Consequence for the fix.** B1 has two independent halves — the `anon` grants and the
definer/uid-predicate question. Closing only the read path leaves `anon` holding DELETE.
The revocation is the smaller, more certain half and is verifiable by re-running query A.
It also crosses the ownership boundary: `CONTRACT.md:119` lets notifications-specialist
author only the two notification views; the other three are UNOWNED.

**Not established:** whether the full-privilege grant is project-wide default drift rather
than five bad views. Not measured across all 71 views. Cheap to measure on request.

Owner of the fix decision: `cto`. Application: PO only (decision 019).


### SEC-15a — DEMONSTRATED, and it is schema-wide drift (2026-08-28)

`cto` closed the demonstration gap without breaking decision 019: **`EXPLAIN` without
`ANALYZE` plans and performs ACL checks but executes nothing.** It is a read. The claim
moves from *preconditions verified* to **demonstrated**:

```
SET LOCAL ROLE anon;  EXPLAIN DELETE FROM public.v_notifications_feed WHERE id='…'::uuid;
  Delete on notifications -> Index Scan using notifications_pkey
       Index Cond: (id = …)                                        <-- NO RLS FILTER

SET LOCAL ROLE anon;  EXPLAIN DELETE FROM public.notifications  WHERE id='…'::uuid;   -- CONTROL
  Delete on notifications -> Index Scan using notifications_pkey
       Index Cond: (id = …)
       Filter: (current_setting('request.jwt.claim.sub')::uuid = to_user_id)   <-- RLS APPLIED
```

Identical plans; through the view the RLS filter is simply absent.

**There is no residual protection, and I verified the mechanism independently.** Query:
`pg_class` reloptions for `security_invoker` joined to `pg_roles` on the view owner.

| View | Owner | `rolbypassrls` | `rolsuper` |
|---|---|:--:|:--:|
| `v_notifications_feed`, `v_notifications_ranked`, `v_posts_time_preview`, `v_user_reputation`, `v_my_drafts`, `v_hidden_list`, `v_needs_organiser` | `postgres` | **true** | false |
| `geometry_columns` | **`supabase_admin`** | **true** | **true** |

With `security_invoker=false` the base-table access is checked as the **owner**, and every
owner here bypasses RLS outright. **RLS is not "maybe insufficient" — it is definitionally
not consulted.**

**Population — this is drift, not five bad views.** Reproduced independently, same figures:

| Measure | Count |
|---|---:|
| Views in `public` | 71 |
| Granting `anon` INSERT/UPDATE/DELETE | **70** |
| Of those, SECURITY DEFINER | 49 |
| **Definer + auto-updatable = LIVE WRITE PATHS** | **8** |

The 8: `v_notifications_feed`, `v_notifications_ranked`, `v_posts_time_preview`,
`v_user_reputation`, `v_my_drafts`, `v_hidden_list`, `v_needs_organiser`, `geometry_columns`.
**It reaches posts, reputation and drafts — not only notifications — destructively.**

**Why the REVOKE is safe (verified, and stronger than first claimed).**
`grep -rnE "\.from\('v_|\.from\(\"v_" lib --include='*.dart'` → **0**. The app never
writes through a view. Going further: **none of the 8 is referenced anywhere in `lib/` at
all** — not read, not written (`grep -rl` per view → 0 for all 8). So revoking `anon`
entirely on these 8 has **zero** client-behavioural effect, not merely zero write effect.

**`geometry_columns` needs a different remediation path** and must not be batched blindly
with the other 7: it is owned by `supabase_admin`, a **superuser**, and is PostGIS-managed
rather than ours. Whether we may alter its grants at all is a question for the fix author.

**Correction inherited from `cto`, carried here because it changes a do-not-re-flag note:**
`geometry_columns`/`geography_columns` were recorded as confirmed false positives. **That
ruling was correct for READ and wrong for WRITE** — `geometry_columns` is one of the 8, and
`anon` DELETE against PostGIS metadata is not harmless. **A false-positive ruling is scoped
to the privilege it was made about.** Any SEC-06 do-not-re-flag note needs that qualifier or
the one that matters gets skipped.

**Fix order (cto ruling, T-012/T-001/T-011):** the **REVOKE comes first**, ahead of all
`security_invoker` work — it closes a destructive path; the invoker work closes a
confidentiality one. Two uid predicates would leave `anon` holding DELETE on eight views.
Authorship: one project-wide privilege migration, `cto`'s, PO-gated. It is not a
notifications/moderation/social change, so it does not need the ownership matrix widened.

**`geometry_columns` CANNOT be revoked — verified, T-015.** Not "may fail". Migrations run
as `postgres`; `postgres` is **not** superuser and is **not** a member of the owner:

```sql
select current_user,                                          -- postgres
  (select rolsuper from pg_roles where rolname=current_user),  -- FALSE
  pg_get_userbyid(relowner) for geometry_columns,              -- supabase_admin
  pg_has_role(current_user,'supabase_admin','USAGE');          -- FALSE
```

`REVOKE ... ON geometry_columns FROM anon` fails for insufficient privilege.

**The trap is sharper than an error.** `REVOKE ... ON ALL TABLES IN SCHEMA public FROM anon`
— the obvious single-statement form — either halts partway through a security migration or
**skips the object it cannot touch while reporting success**. The second outcome is a fix
that reports total and is not.

**T-015 ruling:** the migration **enumerates its targets explicitly** and excludes
`geometry_columns` by name, with a comment. **7 of 8 write paths close**; the 8th is
documented as platform-owned with the ownership query above as evidence. If the PostGIS
grant is judged to matter, it is a Supabase support question — not something we force.

**Still not done by any agent:** the write itself, and application to production.
Decision 019 stands.


### The five zero-policy orphan tables — answered for `cto` (2026-08-28)

`cto` asked whether anything reads them, to decide "policy or drop". Measured via `prosrc`
(not `pg_depend` — it does not track plpgsql bodies), `pg_views.definition`, and `grep` over `lib/`.

| Table | rows | fn refs | definer fns | view refs | policies | `lib/` refs |
|---|---:|---:|---:|---:|---:|---:|
| `challenge_types` | 8 | **0** | 0 | 0 | 0 | **0** |
| `surface_catalog` | 30 | **0** | 0 | 0 | 0 | **0** |
| `context_rating_config` | 2 | 1 (`_get_context_config`) | 0 | 0 | 0 | 0 |
| `safety_blocklist_terms` | 2 | 1 (`content_hits_blocklist`) | 0 | 0 | 0 | 0 |
| `space_slot_holds` | **0** | 1 (`_slot_conflicts_hold`) | 0 | 0 | 0 | 2 (const + model) |

**All five are RLS-on / zero-policies, and all three referencing functions are INVOKER
(`prosecdef=false`).** So they are **not** a definer funnel — the pattern `cto` ruled on for
`games`/`squad_members` does not apply here. An invoker function reading an RLS-on
zero-policy table returns **0 rows to every real caller**. Verified:

```sql
set local role authenticated;
select count(*) from safety_blocklist_terms;  -- 0   (2 rows exist)
select count(*) from context_rating_config;   -- 0   (2 rows exist)
select count(*) from challenge_types;         -- 0   (8 rows exist)
select count(*) from surface_catalog;         -- 0   (30 rows exist)
```

**`challenge_types` and `surface_catalog` have no reader at all** — no function, no view, no
client. 38 rows of config nothing can reach.

**RULED — `cto`, 2026-08-28: REVOKE NOW, DEFER THE DROP. T-007 does not transfer here.**
Dead Dart is recoverable from git in one command; **38 rows of dropped config are
recoverable from nothing.** A table with no reader costs nothing to leave in place, so the
asymmetry between "wrong to drop" and "wrong to keep" is enormous and one-sided. Revoking
removes the exposure and is free; the drop is the irreversible half and carries no urgency.

**`space_slot_holds` — KEPT, `cpo` ruling `P-013`.** It is parked scaffolding for venue slot
booking, and **booking is committed scope** (Phase 1B, Month 9, `P-002` from `11 v2` F.3 and
`13a` Appendix C). Same ruling as `lib/features/payments/`: **deferred product is not dead
code.** Do not drop it in the orphan-table sweep.

**Note on `challenge_types`:** `challenges` sits under the competitive-leagues fork, which
`P-002` ruled **in scope**. These two tables are config for a surface that was never built,
not the feature itself — dropping them does not touch that ruling.

### BUG-07 — the safety blocklist fails open, twice, independently (NEW, 2026-08-28)

`content_hits_blocklist(p_text, p_locale default 'any')` is **STABLE, INVOKER**, and reads
`safety_blocklist_terms`. Two defects, either of which alone returns "clean" for all input:

**1. The locale predicate can never match.** The function filters
`where locale = 'any' or locale = p_locale`. Both stored terms are `locale = 'en'`. The
client (`moderation_service.dart:546`) defaults `locale = 'any'` and passes it straight
through. With `p_locale='any'`, an `'en'` term matches neither branch. Demonstrated as
**service role**, which bypasses RLS entirely:

```sql
select content_hits_blocklist('buy a fake passport here');  -- 0
-- while safety_blocklist_terms contains ('fake passport','en',is_regex=false)
```

The predicate treats `'any'` as a property of the stored term, but the caller passes it as
the *query* locale. A term is reachable only when the caller names its exact locale.

**2. RLS returns zero rows to every real caller.** The function is INVOKER over an RLS-on,
zero-policy table, so as `authenticated` it reads 0 terms regardless of locale. Fixing the
locale bug alone would not make the blocklist work.

**Severity — and the reason this is not a live hole today.** `contentHitsBlocklist` has
**no caller anywhere in `lib/`** (`grep -rn "contentHitsBlocklist" lib` → only its own
definition). Nothing invokes it, so nothing is currently being let through. `moderation_service.dart`
itself *is* live — imported by `game_composer_screen.dart`, `profile_screen.dart`,
`report_dialog.dart`, and both admin screens — so the method is one wiring change away from use.

**It is a trap, not a breach.** Whoever wires up the blocklist gets `0` — a plausible,
silent "clean" — for every input, and both defects are invisible at the call site.

**RULED — T-016 (`cto`, 2026-08-28). Fix, do not delete — stated as an explicit exception to
T-007's deletion default**, because Dabbler carries user-generated content and a content
blocklist is a control it should have. The right end state is a working check, not the
honest absence of one. **Fix both defects or remove both artifacts — never one of each.**

- **Locale:** `where p_locale = 'any' or locale = 'any' or locale = p_locale`.
- **RLS:** make `content_hits_blocklist` **SECURITY DEFINER** and **REVOKE** direct `SELECT`
  on `safety_blocklist_terms` from `anon` and `authenticated`. **NOT a read policy.**

**Why not a policy — the reasoning is specific to what the table is.** A read policy for
`authenticated` would work, and would be wrong: every user could then download the list of
banned terms and author around it. **A moderation control whose contents are visible to the
people it constrains is not a control.** Same treatment for `context_rating_config` via
`_get_context_config`.

**Verification is part of the decision, not an acceptance criterion someone may trim:**
**verify as role `authenticated`, never as service role.** A service-role test passes while
production fails — that is exactly how this survived.

**Not a promotion blocker** (`cpo` `P-013` concurring). Recorded in `BRIEF.md` as a known
trap because moderation is a corpus commitment; the App Store requirement is the
report/block mechanism, which exists and is live.


## 21. Repo hygiene inventory — 2026-08-28

**Scope:** every non-directory file in the project root, the four unused platform
folders, and stray files elsewhere in the tree. **Read-only:** nothing here was
moved or deleted. `version-control` executes once the PO approves.

**The bar for DELETE:** nothing references it AND nothing builds from it AND it is
either regenerable or preserved in `git log`. Every verdict below carries the
command that produced it.

### 21a. Reference-count method

Inbound references were counted with, for each candidate `F`:

```
grep -rIl --exclude-dir=.git --exclude-dir=build --exclude-dir=node_modules \
     --exclude-dir=.dart_tool -F "F" . | grep -v "^\./F$" | wc -l
```

This matches the filename anywhere in any text file — deliberately over-broad, so a
zero is strong evidence. Two results needed disambiguation because the basename is
common (`README.md`, `QUICK_REFERENCE.md`); those were re-checked by path.

### 21b. Project root — every non-directory file

| path | size | tracked? | inbound refs | verdict | evidence |
|---|---|---|---|---|---|
| `pubspec.yaml` | 8,002 B | yes | build input | **KEEP** | Flutter manifest |
| `pubspec.lock` | 59,543 B | yes | build input | **KEEP** | resolved deps |
| `analysis_options.yaml` | 1,816 B | yes | `flutter analyze` | **KEEP** | lint config |
| `l10n.yaml` | 120 B | yes | `flutter gen-l10n` | **KEEP** | points at `lib/l10n/` |
| `firebase.json` | 901 B | yes | Firebase tooling | **KEEP** | |
| `devtools_options.yaml` | 184 B | yes | 0 | **KEEP** | Flutter-tool generated; regenerated on every DevTools launch. Zero refs is normal for it — not evidence of rot |
| `package.json` / `package-lock.json` | 651 / 6,933 B | yes | 13 / 3 | **KEEP** | referenced by `.claude/helpers/security-scanner.sh` and several skills |
| `skills-lock.json` | 3,552 B | yes | 3 | **KEEP** | `docs/status/version-control.md`, agent memory |
| `.gitignore` | 4,342 B | yes | — | **KEEP** | |
| `.env.example` | 803 B | yes | `run.sh:24`, `build_ios.sh:19` | **KEEP** | both scripts print it in their error path |
| `run.sh` | 979 B | yes | executable entry point | **KEEP** | the only correct way to `flutter run` |
| `build_ios.sh` | 1,903 B | yes | executable entry point | **KEEP** | store build; calls `scripts/gen_dart_defines.sh` |
| `CLAUDE.md` | 9,947 B | yes | governance | **KEEP** | |
| `.mcp.json` | 597 B | **no** (gitignored) | — | **KEEP** | holds live tokens; correctly untracked |
| `.env` | 813 B | **no** (gitignored) | `run.sh`, `build_ios.sh` | **KEEP** | real secrets; correctly untracked |
| `.flutter-plugins-dependencies` | 23,190 B | no | tool-generated | **KEEP** | regenerated by `flutter pub get` |
| `.an_out.txt` | 553,010 B | **yes** | 0 | **DELETE** | captured `flutter analyze` output, last committed `8a8178f` 2026-04-25. Regenerable in one command; preserved in `git log` |
| `flutter_analyze.txt` | 56,629 B | **yes** | 0 | **DELETE** | same — a second, older capture of the same command |
| `.dto_candidates` | 3,908 B | **yes** | 0 | **DELETE** | one-off refactor scratch output, 2026-02-28 |
| `.dto_moves_map` | 7,116 B | **yes** | 0 | **DELETE** | same batch |
| `.dto_conflicts` | 0 B | **yes** | 0 | **DELETE** | empty file, same batch |
| `.dupes_candidates` | 0 B | **yes** | 0 | **DELETE** | empty file, same batch |
| `.05B_summary.json` | 1,141 B | **yes** | 0 | **DELETE** | same batch |
| `1ab7a966-…_DABBLER_CONTENT_ENGINE.pdf` | 431,850 B | **yes** | 0 | **ASK** | a marketing/content PDF with a UUID filename. Not regenerable and not in `docs/`. **Ask the PO** whether the source of record lives in Notion; if so, delete — if not, it should move to `docs/` with a real name |
| `flutter_01.log` … `flutter_04.log` | 21,625 B total | **no** | 0 | **DELETE** | run logs 2025-11-17 → 2026-07-12. Already matched by `.gitignore:20` (`*.log`) — they were never tracked |
| `flutter_run.log` | 518 B | **no** | 0 | **DELETE** | same |
| `test_icon.dart` | 93 B | **no** | 1 (its own name inside `flutter_analyze.txt`) | **DELETE** | 93-byte scratch file at root; the only "reference" is a line in a file also being deleted. Violates `CLAUDE.md`'s no-tests-at-root rule |
| `upload_certificate.pem` | 1,294 B | **no** (untracked) | 0 | **ASK** | appeared 2026-08-27. This is the Play Store **upload key certificate** — the public half, so not a secret, but it is a signing artifact and belongs with the Android release material, not at root. **Ask the PO** whether to move it under `android/` or delete it as a re-downloadable Play Console export. **Do not commit it** in either case |
| `.DS_Store` | 18,436 B | no | 0 | **DELETE** | macOS Finder metadata. 19 exist across the tree (157,772 B total), none tracked |

### 21c. The five root documents

Read in full before judging. Verdicts differ per document — this is not one decision.

| path | age | verdict | reasoning |
|---|---|---|---|
| `APPLE_REVIEW_SIGNIN.md` | `c70b2e8` 2026-06-26 | **MOVE → `docs/APPLE_REVIEW_SIGNIN.md`** | **Still true and operationally live.** It is the App Review demo-account instruction sheet, used at every store submission. Zero inbound references is expected — its reader is a human filling in App Store Connect, not a build. Do not delete. Note it ships with a `<ENTER_DEMO_PASSWORD_HERE>` placeholder, which is the correct posture (the password is not in the repo) |
| `task_20_flutter_overhaul.md` | `32452e1` 2026-05-05 | **MOVE → `docs/briefs/task_20_flutter_overhaul.md`** | **Still relevant — the work it describes is not finished.** It specifies the `post_comments`→`comments` / `post_likes`→`likes` / `public_activities` migration. 6 references to the old table names remain in `lib` (see 21f). Deleting it would delete the only written statement of the target architecture for that migration |
| `flutter_localization_checklist.md` | `2f8e3ba` 2026-05-12 | **MOVE → `docs/`** | Generic Arabic/English l10n audit checklist. `l10n.yaml`, `lib/l10n/app_en.arb` and `app_ar.arb` all exist, so the work is partly done and the checklist is a live gap-tracker. Nothing in `docs/` covers l10n |
| `ONBOARDING_AUDIT.md` | `de8f3f1` 2026-04-25 | **FOLD IN → then DELETE** | Largely superseded — `PROJECT_STATE.md` §14–16 covers onboarding reachability with newer numbers, and its Bug 1 (missing `onboardingPersonaSelection` route) is already recorded as INV-02. **But it held two facts this document did not**, both re-verified today and now folded into 21f below. Delete only after 21f is accepted |
| `PRODUCTION_READINESS_REVIEW.md` | `474248a` 2026-03-17 | **DELETE** | **Stale and superseded, and its judgements are now known to be wrong.** It rates Maintainability "High" and Separation of Concerns "Good" — against a codebase that run 2 measured as 69,612 LOC unreachable with three competing error conventions. It predates every audit in this document by five months. Keeping it risks someone citing it. `git log` preserves it |

### 21d. Unused platform folders

`macos/` (29 tracked, 674 files, 4.9 MB), `windows/` (15 tracked, 88 KB),
`linux/` (7 tracked, 48 KB). **Verdict: DELETE — but see the risk note.**

Independently confirmed:

- **No build targets them.** `scripts/cloudflare-build.sh:27` runs `flutter build web`;
  `build_ios.sh:44` runs `flutter build ipa`; the only CI workflow,
  `.github/workflows/deploy-web.yml:36`, runs `flutter build web`. No desktop target
  anywhere.
- **`pubspec.yaml` says so itself.** `pubspec.yaml:168-171` pins `win32: 5.15.0` with the
  comment *"win32 code paths only run on Windows desktop builds, which we do not ship."*
  That is the PO's own recorded position, not an inference.
- **No plugin requires a desktop registrar to exist.** `macos/Flutter/GeneratedPluginRegistrant.swift`
  and the `linux`/`windows` equivalents are generated by `flutter pub get` from
  `.flutter-plugins-dependencies`; they are consumed only by a desktop build. This is an
  app, not a plugin — `pubspec.yaml` has no `flutter.plugin.platforms` block.
- **The `Platform.is*` checks are unaffected — verified, not assumed.** The three sites are
  `bug_report_screen.dart:452-454` (`isWindows`/`isMacOS`/`isLinux`), inside a `String`
  getter that labels a bug report. These are `dart:io` **runtime** checks. `dart:io`
  compiles on every non-web target regardless of which platform folders exist; the
  constants resolve at runtime, not against a folder. Removing `macos/` cannot break them.
  They become permanently-false branches, which is what they already are.

**Risk note (not hygiene):** deleting these makes `flutter build macos|windows|linux` fail
until `flutter create --platforms=macos .` regenerates them. That is a one-command
recovery and no shipping target is affected. But if the PO intends a macOS desktop build
in the next 12 months, keeping 5 MB is cheaper than re-deriving the Xcode project settings.
**Recommend deleting `windows/` and `linux/` unconditionally (136 KB, 22 tracked files —
no plausible future) and confirming `macos/` with the PO before removing it.**

### 21e. Rot elsewhere in the tree

| path | size | tracked? | inbound refs | verdict | evidence |
|---|---|---|---|---|---|
| `lib/features/misc/presentation/screens/create_game_screen.dart.broken` | 632 LOC | yes | 0 | **DELETE** | `grep -rIn 'create_game_screen' --include='*.dart' lib` → no match. Not compiled (`.broken` is not `.dart`). Already flagged in §1 finding 8 |
| `lib/design_system/JSONS/` | 40 KB, 10 files | yes | 0 | **DELETE** | already ADR'd: `docs/DECISIONS.md:143` entry 008, status ACTIVE, "confirmed dead 2026-08-26". **Do not confuse with `lib/design_system/tokens/`**, which is a declared Flutter asset at `pubspec.yaml:223` and is load-bearing |
| `lib/core/services/onboarding_service.dart` | 199 LOC | yes | 0 | **DELETE** | `grep -rIn "onboarding_service.dart" lib test integration_test` → no importers. See 21f |
| `lib/core/services/mock_onboarding_service.dart` | 121 LOC | yes | 0 | **DELETE** | same command, no importers. Mock for the above |
| `scripts/analyze_appbutton.sh` | 1,448 B | yes | 0 | **ASK** | one-off analysis script, 2026-02-28. Harmless; delete only if the PO agrees it is spent |
| `scripts/migrate_to_material3.sh` | 4,412 B | yes | 0 | **ASK** | one-off codemod for a migration that `lib/core/design_system/MATERIAL3_MIGRATION_GUIDE.md` says is done. Same call |
| `scripts/generate_token_json.py` | 2,138 B | yes | 0 | **ASK** | regenerates design-token JSON. Zero refs, but it is the *producer* of a live asset directory (`lib/design_system/tokens/`). **Keeping is the safe default** — deleting it means the tokens can only be hand-edited |
| `scripts/parse_logs.py` | 1,236 B | yes | 0 | **ASK** | log parser for the `flutter_*.log` files being deleted. Probably spent |
| `scripts/cloudflare-build.sh`, `gen_dart_defines.sh`, `run_integration_tests.sh` | — | yes | 6 / 5 / 3 | **KEEP** | all three are live build/release entry points |
| `lib/design_system/*.md` (4 files: `COLOR_TOKEN_MAPPING`, `style_guide`, `SPORTS_COLOR_MAPPING`, `ONBOARDING_STYLE_GUIDE`) | — | yes | 0 each | **ASK** | design-system documentation sitting inside `lib/`, referenced by nothing. Candidates to move to `docs/`, but they are **design intent**, not analysis — the PO or `cto` should say whether they are still the design of record before they move or go |
| `lib/core/design_system/*.md` (7 files) | — | yes | mixed | **KEEP where referenced** | `MATERIAL3_MIGRATION_GUIDE.md` is cited from live code at `lib/core/design_system/colors/app_colors.dart:10,17` (inside a `@Deprecated` message a developer will read) and `design_system.dart:6`. `README.md` and `QUICK_REFERENCE.md` are cross-linked from it. **Only `IMPLEMENTATION_SUMMARY.md`, `LAYOUT_STRUCTURE.md` and `ICONSAX_USAGE_GUIDE.md` have zero inbound refs — ASK before touching those** |
| `App screenshot/` | 13 MB, 7 tracked | yes | 0 | **ASK** | store screenshots. 13 MB on disk but only 7 files tracked, so most of it is untracked local clutter. Ask whether the tracked 7 are the current App Store set |
| `docs/agents/` | empty | — | — | **DELETE** (directory) | empty directory; the agent definitions live in `.claude/agents/` and their status files in `docs/status/` |
| `.github/prompts/ui-ux-pro-max/scripts/__pycache__/` | 3 `.pyc` | check | 0 | **DELETE** | compiled Python bytecode, never a source artifact |
| 19 × `.DS_Store` | 157,772 B | none tracked | 0 | **DELETE** | and add `.DS_Store` to `.gitignore` if absent |

### 21f. Folded in from `ONBOARDING_AUDIT.md` — two findings this document did not hold

Both re-verified today against the current tree, not transcribed.

- **HYG-01 · Two dead onboarding services, 320 LOC, zero importers.**
  `lib/core/services/onboarding_service.dart` (199 LOC) is a SharedPreferences-based
  onboarding tracker fully replaced by the DB-authoritative `OnboardingController`.
  `lib/core/services/mock_onboarding_service.dart` (121 LOC) is its test mock.
  `grep -rIn "onboarding_service.dart\|mock_onboarding_service.dart" lib test integration_test --include='*.dart'`
  returns **nothing**. The 2026-04-25 audit said `set_password_screen.dart` was the last
  consumer; that link is now gone too. **Unblocked for deletion.**
  (`onboarding_gamification.dart`, 419 LOC, is *not* in this group — it still has two
  importers, both inside the dead `onboarding_scenarios/profile/` slice, so it dies with
  that slice and not before.)

- **HYG-02 · `OnboardingData` is declared twice, incompatibly.**
  `lib/features/auth_onboarding/domain/models/onboarding_state.dart:40` declares a Freezed
  `OnboardingData`; `lib/features/auth_onboarding/presentation/providers/onboarding_data_provider.dart:5`
  declares a second, hand-written class of the same name, consumed by
  `OnboardingDataNotifier` at `:126`. Same name, different type, same feature slice. Not
  currently throwing, but it is a live import-ambiguity trap for anyone editing onboarding.
  **Owner: `cto` decides which survives.**

### 21g. Looks bad but is actually fine

- **`packages/flutter_web_auth_2/` and `packages/sign_in_with_apple/` (72 tracked files)
  are NOT vendored cruft — they are load-bearing.** `pubspec.yaml:167-180` declares them as
  `dependency_overrides` with `path:` entries. Deleting them breaks `flutter pub get` and
  therefore every build. The comment at `:172-176` explains why they exist (a patched
  Gradle line). **Do not touch.**
- **The 5 `post_comments_author_profile_id_fkey` strings in `lib` are not broken queries.**
  They look like references to a table renamed in the `task_20` migration. They are
  PostgREST **FK-constraint hints**, and Postgres preserves constraint names across
  `ALTER TABLE … RENAME`. Verified live:
  `select conname, conrelid::regclass from pg_constraint where conname like 'post_comments%'`
  → 6 constraints, all now on table `comments`. The hints resolve correctly.
  Sites: `post_providers.dart:214`, `news_repository_impl.dart:44,90`,
  `post_repository_impl.dart:1351,1401`. **Leave them.** (Renaming the constraints later
  would break the app — worth an ADR.)
- **`devtools_options.yaml` has zero inbound references and is still not deletable.** It is
  read by the Flutter DevTools tooling by filename convention, not by any file in the repo.
  A naive reference scan flags it; it is fine.
- **`lib/design_system/tokens/` looks like a duplicate of `JSONS/` and is not.** `tokens/`
  is a declared Flutter asset (`pubspec.yaml:223`) shipped into the bundle. `JSONS/` is
  the dead one. Getting this backwards would break theming at runtime.
- **`.mcp.json` and `.env` sitting untracked in the root is correct, not sloppy.** Both
  hold live credentials and are gitignored by design.
- **`.github/workflows/deploy-web.yml` publishes to `gh-pages`, not Cloudflare** — it is a
  second, parallel deploy path that fires on `main` and `BETA`. Out of hygiene scope, but
  worth knowing it exists: it is not the release topology `CLAUDE.md` describes.

### 21h. Totals

| bucket | files | bytes | tracked |
|---|---|---|---|
| Root — regenerable artifacts, DELETE | 7 | 1,053,654 | **7** |
| Root — untracked logs + scratch, DELETE | 6 | 22,236 | 0 |
| Root docs — MOVE to `docs/` | 3 | 19,680 | 3 |
| Root docs — DELETE (superseded) | 2 | 17,349 | 2 |
| Root — ASK | 2 | 433,144 | 1 |
| Platform folders `macos/` `windows/` `linux/` | 702 on disk | 5,259,264 | **51** |
| Dead code in `lib/` (`.broken`, `JSONS/`, 2 services) | 13 | ~65,000 | 13 |
| `.DS_Store` across tree | 19 | 157,772 | 0 |
| **Total proposed for removal (DELETE verdicts only)** | **749** | **≈6.6 MB** | **73** |

**Read that as two numbers, not one.** The number that matters for repo weight is
**73 tracked files, ~6.5 MB**, of which 51 files / 5 MB is the three platform folders. The
root junk is 7 tracked files but the single most-visible offence — a 553 KB analyzer dump
and a 432 KB PDF sitting next to `pubspec.yaml`.

**Nothing in the DELETE column changes a build, a CI job, or a store submission.** The one
item with any build consequence is `macos/`, flagged in 21d and downgraded to a PO
confirmation.

### 21i. Handoff

| Item | Owner | Action |
|---|---|---|
| Execute 21b/21c/21e DELETE + MOVE verdicts | `version-control` | One commit per bucket: `chore: remove regenerable analysis artifacts` · `docs: move root documentation into docs/` · `chore: remove unused desktop platform folders`. Do not batch them |
| `.DS_Store` and `__pycache__` | `version-control` | Delete, and confirm both patterns are in `.gitignore` |
| HYG-01 delete 2 dead onboarding services (320 LOC) | Flutter feature agent | Zero importers verified — safe alone, no coordination needed |
| HYG-02 duplicate `OnboardingData` | `cto` | Decide which declaration survives, then a feature agent executes |
| `macos/` keep-or-delete | **PO** | 5 MB against a possible future desktop build |
| The 7 ASK items (PDF, `.pem`, 4 scripts, `App screenshot/`, design-system `.md`s) | **PO** | Listed in 21b/21e — none guessed at |

