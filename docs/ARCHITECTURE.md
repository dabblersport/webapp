# docs/ARCHITECTURE.md — How Dabbler Is Actually Put Together

**Owner:** master-analyst (write) · all agents (read)
**Last updated:** 2026-08-26 · verified against the tree at HEAD `1b83967`

**This describes what is true, not what was intended.** Where the two diverge, the
divergence is named with a citation. Measurements live in `PROJECT_STATE.md`; this file
points at them rather than restating them.

---

## 1. THE STACK

| Layer | Technology | Notes |
|---|---|---|
| UI | Flutter, Material 3 | iOS · Android · Web from one codebase |
| State | Riverpod 2.x | `ProviderScope` at the root in `main.dart` |
| Navigation | GoRouter | Single router, `lib/app/app_router.dart` (1,745 LOC) |
| Backend | Supabase | Postgres + RLS + PostgREST + Storage + Edge Functions (Deno) |
| Push | Firebase Cloud Messaging | iOS via APNs, Android channels, web via service worker |
| Models | Freezed + `json_serializable` | Codegen via `build_runner` |
| Errors | `Result<T, Failure>` (`lib/core/fp/result.dart`) | 31 files still on legacy `fpdart` `Either` |
| l10n | Flutter gen-l10n | English + Arabic, 489 keys each, RTL |
| Hosting (web) | Cloudflare Pages, project `webapp` | `main` → app.dabbler.pro · `Canary` → canary.dabbler.pro |

**Scale:** 783 non-generated Dart files · ~226,000 LOC · 25 feature slices · 390 commits
since 2025-10-17.

---

## 2. DIRECTORY MAP — the actual tree

```
lib/
  app/            app_router.dart — every route, _handleRedirect, the flag gate
  core/
    config/       feature_flags.dart · supabase_config.dart · environment.dart
    errors/       the Failure hierarchy
    fp/           result.dart — Result, Ok, Err, Unit
    services/     auth_service.dart (1,494 LOC) · analytics/ (all stubs)
    widgets/      cross-slice widgets
    auth/         session_cleanup.dart
    design_system/  **22 dart files — the LARGER of the two design systems**
  data/
    models/       shared Freezed models
    repositories/ THE LIVE REPOSITORIES — profiles, posts, areas, nearby games
    mappers/
  design_system/  11 dart files · tokens/ (JSON + .dart per palette) · JSONS/ (DEAD, 0 refs)
  features/       25 slices — see PROJECT_STATE.md §3 for the state of each
  l10n/           GENERATED — never hand-edit
  services/       notifications/ (push, 4 platform variants) · sport_profile_service.dart
  themes/         app_theme.dart (1,267 LOC) — assembles ThemeData from tokens
  utils/          constants/route_constants.dart · transitions/page_transitions.dart
  widgets/        app_card, input_field, adaptive_auth_shell
  routes/         route_arguments.dart — **live**, 2 importers (see note below)
  main.dart       zone guard → Supabase init → Firebase init → ProviderScope
  providers.dart  central provider export hub
```

**What each location forbids:**

| Location | Forbidden |
|---|---|
| `lib/l10n/`, `*.g.dart`, `*.freezed.dart` | **Any hand edit.** Regenerated; your change vanishes |
| `lib/features/<slice>/` | Reaching into another slice's `data/` or `domain/`. Cross-slice goes through `lib/data/` or a shared provider |
| `lib/core/config/supabase_config.dart` | Changing a constant's **value** without a decision |
| `lib/design_system/JSONS/` | Everything — it is dead (0 references) |
| Any repository | Throwing. Return `Result` |
| Any feature widget | `Color(0x…)` literals and raw `MaterialPage` |

**`lib/routes/` is a real top-level directory and easy to miss.** It holds one file,
`route_arguments.dart`, imported from 2 places:
`core/viewmodels/game_creation_viewmodel.dart:8` and
`features/misc/presentation/screens/create_game_screen.dart:11`. **One of those two is
itself dead** — `create_game_screen.dart` has 0 importers (`PROJECT_STATE.md` DEAD-05) — so
the live importer count is effectively **1**. Do not confuse this directory with
`lib/utils/constants/route_constants.dart`, which is where route *paths* live. Different
things, similar names.

**There are two design systems inside `lib/`, and the bigger one is not the one everybody
talks about.**

| Path | Dart files |
|---|---:|
| `lib/core/design_system/` | **22** |
| `lib/design_system/` | 11 |

Plus `dabbler_design_system`, a git dependency with **0** imports (`pubspec.yaml:40-43`).
So the real count is **three** design-system surfaces, not two. §5 discusses the divergence;
this is the measurement behind it. Ownership of all three is UNOWNED in `CONTRACT.md`.

**The naming trap:** `lib/data/repositories/` holds the **live** repositories. The
`lib/features/<slice>/data/repositories/` trees are largely the parallel stack that no route
reaches. The path that looks canonical is mostly the dead one.

---

## 3. DATA FLOW — the live path

```
   Screen (ConsumerWidget)
      │  ref.watch(xxxControllerProvider)
      ▼
   Controller (StateNotifier / AsyncNotifier)
      │  calls, then unwraps Result → typed XxxState
      ▼
   Repository  ──►  Result<T, Failure>
      │  Result.guard(() async => …, (e) => Failure.from(e))
      ▼
   Supabase.instance.client
      │  .from(SupabaseConfig.xTable)   ← name from constants, never a literal
      │  .rpc(SupabaseConfig.rpcXFn)
      ▼
   Postgres — RLS decides what comes back
```

**`Result` is unwrapped exactly once, in the controller.** The repository returns it, the
controller maps `Ok`/`Err` into a typed state, and the screen renders that state. A screen
that handles a `Result` directly is a layering mistake — the screen should never know a
failure type exists.

**Worked example — the live game path**, which is also the clearest illustration of the
two-architecture problem:

```
game_detail_screen.dart  (routed)
   └─ ref.watch(gameViewControllerProvider(gameId))
        └─ game_view_controller.dart:399
             ├─ .from(SupabaseConfig.vGameCardTable)   ← the v_game_card VIEW
             ├─ .from(SupabaseConfig.gameRosterTable)
             ├─ .rpc(SupabaseConfig.rpcJoinGameFn)
             └─ .rpc(SupabaseConfig.rpcLeaveGameFn)
```

It reads a **view** and calls **RPCs**. It does not touch the `games` table directly — which
is fortunate, because `games` has RLS enabled with zero policies and returns 0 rows
(`SCHEMA.md` §1a).

**The dead parallel path**, for contrast:

```
games_providers.dart → featuresGamesRepositoryProvider → GamesRepositoryImpl
   → SupabaseGamesDataSource → 20× .from(SupabaseConfig.gamesTable)  ← returns nothing
```

Nothing watches `gamesControllerProvider` outside `games_providers.dart` itself.

---

## 3b. THE TWO CORE PRODUCT FLOWS

Measured 2026-08-27. Both were previously undocumented.

### Game creation — one live path, one dead 7-step wizard

**LIVE:** `game_composer_screen.dart` (1,685 LOC), routed at `app_router.dart:1200, 1225, 1238`.
Reads `sportsTable`, `sportVariantsTable`, `venueSpacesTable`, `vGameCardTable`; writes via
`rpc_create_game` and `rpc_update_game`. **This is the only path that can create a game.**

**DEAD — the entire 7-step wizard, 4,340 LOC + a 632-LOC `.broken` twin:**

```
create_game_screen.dart          763 LOC   0 importers, NOT routed
  ├─ sport_format_step.dart    1,179       imported ONLY by create_game_screen
  ├─ venue_slot_step.dart        525               "
  ├─ player_invitation_step      571               "
  ├─ participation_payment_step  515               "
  └─ review_confirmation_step    749               "
rebook_flow.dart                  38 LOC   0 importers
```

**This is transitive deadness and the original audit missed it.** Each step reported
"imported from 1 place", which read as reachable — but that one place is
`create_game_screen.dart`, which nothing imports and no route reaches. A one-level
importer check is not a reachability check.

**It was also never finished.** The whole wizard's only database call is a read of
`usersTable`. It never calls `rpc_create_game` — it is a UI shell that cannot create a game.

**Corrected dead-code figure:** `PROJECT_STATE.md` DEAD-05 recorded 763 LOC for
`create_game_screen.dart` alone. The real orphaned total for this flow is **4,972 LOC**
including the `.broken` twin.

**And it lives in `lib/features/misc/`** — the core product loop, in a directory named
`misc`, alongside `transactions_screen` (1,134 LOC, routed) and `activities_screen_v2`
(624, routed). `misc/` is not a feature slice; it is four unrelated things sharing a folder.

### Auth and onboarding — healthy

**All 16 screens under `lib/features/auth_onboarding/**/screens/` are routed.** No orphans.
`welcome_screen.dart` is referenced 4× in the router (multiple entry points); the other 15
once each.

Route constants driving the flow: `authWelcome` → `emailInput` → `otpVerification` /
`emailVerification` → `createUserInfo` → `onboardingPersonaSelection` →
`onboardingPrimarySport` → `onboardingInterestsSelection` → `onboardingSports` →
`onboardingPreferences` → `onboardingPrivacy` → `onboardingCompletion` → `welcome`.

Gating is centralised in `_handleRedirect`. Auth is passwordless by design (decision 002) —
OTP only, password optional.

**This is the counter-example to `misc/`:** 17,471 LOC, 16 screens, zero orphans, one
coherent flow. When the audit says the codebase is uneven, this is the good end.

## 4. NAVIGATION

- One router: `lib/app/app_router.dart`. Route constants in
  `lib/utils/constants/route_constants.dart` (`RoutePaths`, `RouteNames`).
- **Every route uses a transition wrapper** from `lib/utils/transitions/page_transitions.dart`.
  Verified: **0** raw `MaterialPage` in the tree.
- **`_handleRedirect` is the single gate.** It handles auth state, onboarding completion, and
  feature-flag gating in one place. Adding a second redirect path elsewhere is how gates get
  bypassed.
- In the router there is no `BuildContext` for Riverpod, so provider reads use
  `ProviderScope.containerOf(context, listen: false).read(...)`.
- Admin routes gate on a server call: `rpc(SupabaseConfig.isAdminFn)` at `app_router.dart:1656`
  and `:1682`. The client asks; it does not decide.

**Divergences:**
- 67 screen classes are wired into the router; **54 of 133 route constants are referenced
  nowhere.**
- Six routes resolve to `_PlaceholderScreen` ("Coming Soon") — `app_router.dart:1573, 1587,
  1601, 1617, 1630, 1640` — plus an inline one at `:590` for language selection.
- The router is 1,745 LOC and holds routes, redirect logic, an inline placeholder widget,
  and two RPC calls. Splitting it is ARCH-02 in `PROJECT_STATE.md`.

---

## 5. THEMING

Five palettes — `main`, `social`, `sports`, `activity`, `profile` — × light/dark. All ten
are preloaded in `main.dart` via `AppTheme.initialize()`. A screen selects one with
`AppTheme.setActiveCategory(category)`.

Each palette exists in **three** places that must be edited together (`CONVENTIONS.md` §5):
the token JSON, the token `.dart`, and `app_theme.dart`. No generator closes the loop.

**Divergences: three design-system surfaces coexist**, not two —
`lib/core/design_system/` (**22** dart files, the largest), `lib/design_system/` (11, whose
entry file calls itself "(temporary)"), and `dabbler_design_system`, a git dependency with
**0** imports. None has an owner in `CONTRACT.md`. 233 hardcoded colours remain in feature
code. **Which of the three is canonical is an open question for the PO** — it is a
precondition for the design-system agent in `AGENTS.md` §8.

---

## 6. PLATFORM DIFFERENCES

| Concern | iOS | Android | Web |
|---|---|---|---|
| Push | APNs; needs the `aps-environment` entitlement (added in `45f8c4d`) | FCM channels | Service worker |
| Push impl | `push_notification_service_mobile.dart` | same | `push_notification_service_web.dart` |
| Image read | `image_file_reader_stub.dart` → platform impl | same | `image_file_reader_web.dart` — several methods `throw UnsupportedError` |
| Env config | `.env` via `--dart-define-from-file` | same | **`--dart-define` flags** — `.env` files are blocked by CDN/WAF |
| URL strategy | n/a | n/a | `url_strategy_web.dart` / `_stub.dart` |
| Auth | OTP | OTP | OTP + Google OAuth (`GOOGLE_WEB_CLIENT_ID`) |

Conditional imports are the mechanism (`_stub` / `_web` / `_mobile` file triples). There are
four of these; `push_notification_service` has all four variants.

---

## 7. DEPLOYMENT TOPOLOGY

```
   feature branch
        │  PR
        ▼
     Canary  ──► Cloudflare Pages (PREVIEW env) ──► canary.dabbler.pro
        │  PR — never a direct push
        ▼
      main   ──► Cloudflare Pages (PRODUCTION env) ──► app.dabbler.pro
```

Build: `bash scripts/cloudflare-build.sh` → `build/web`.

**Cloudflare Pages keeps Production and Preview variables as two separate sets.** They do
not share values. All five must exist in **both**: `SUPABASE_URL`, `SUPABASE_ANON_KEY`,
`APP_NAME`, `ENVIRONMENT`, `GOOGLE_WEB_CLIENT_ID`. Preview sat empty for months and silently
broke every Canary build — the push was green, the build was not. **A green push is not a
green deploy.** Unverified as of today: KAN-35.

Mobile ships through App Store Connect and Play Console, version bumped by version-control
in every place the string is duplicated.

---

## 8. THE CENTRAL ARCHITECTURAL FACT — two architectures

The repo contains two complete approaches to the same domains.

**The live one** — pragmatic, thin:
```
Screen → Controller → (repository | direct client) → view / RPC / table
```

**The parallel one** — textbook layered, built, unit-tested, and then routed around:
```
Screen → Controller → UseCase → Repository (interface) → RepositoryImpl → DataSource → table
```

| Slice | Parallel stack | State |
|---|---|---|
| `games` | `data/**` + `domain/usecases/**`, 5,674 LOC | Consumed only by `games_providers.dart`, which no screen watches for games. Queries `games` directly, which returns 0 rows |
| `rewards` | Whole slice, 20,545 LOC | Entry provider `rewards_providers.dart` has **0 importers**. Only check-in (~985 LOC) is live |
| `profile` | `features/profile/data/**`, 2,534 LOC | Reachable, but built on `UnimplementedError`. The live repo is `lib/data/repositories/profiles_repository_impl.dart` (221 LOC) |

**All 66 passing tests target the parallel stack.** The test suite protects the architecture
that is not running.

This is not a style disagreement to be resolved by preference — it is roughly a quarter of
`lib/`, and it is frozen by decisions 015 and 016 pending KAN-29 and KAN-30. **Until those
are answered, new work follows the live pattern.**

---

## 9. KNOWN ARCHITECTURAL DEBT

Pointers, not restatements. Full evidence in `PROJECT_STATE.md`.

| Debt | Where | Finding |
|---|---|---|
| Two architectures | `games`, `rewards`, `profile/data` | KAN-30 |
| God files | 140 non-generated files >500 LOC | ARCH-01 |
| Router does too much | `app_router.dart` (1,745 LOC) | ARCH-02 |
| `Either` / `Result` split | 31 vs 124 files, mixed in 4 slices | ARCH-03 |
| Three profile repository stacks | `lib/data/` + `features/profile/data/` ×2 | ARCH-04 |
| **Three** design-system surfaces | `lib/core/design_system/` (22) · `lib/design_system/` (11) · `dabbler_design_system` (git dep, 0 imports) | DEP-01 |
| Repo cannot rebuild the schema | **See `SCHEMA.md` §8 mismatch 7 — the authoritative statement.** Summary: history exists in the DB ledger; the repo cannot reproduce it | KAN-33 |
| Analytics is hollow | `analytics_service.dart` — 18 empty bodies, backend already exists | WIRE-11 |
| Unowned surface | 23 of 25 slices, and all of Supabase outside notifications | `CONTRACT.md` §3 |

**The healthiest slice is `notifications`** — every non-generated file has an importer, the
provider chain is complete, the database triggers fan out correctly, and the push path works
on all three platforms. When a new slice needs a model to copy, copy that one.

---

## 10. THE SECURITY ARCHITECTURE — where authorization actually lives

*Owner: `cto`. Established during the KAN-39 launch-readiness assessment, 2026-08-27.
Decisions `T-001`–`T-011` in `DECISIONS.md` are the normative statements; this section is
the map.*

### 10.1 The model is sound; one layer on top of it is not

Dabbler defers **all** authorization to Postgres RLS. That decision (`014`) held on the
client side and was verified independently: there are **no client-side authorization
decisions anywhere** in `lib/` — no owner/creator identity comparisons, no `canEdit` /
`isOwner` getters gating access. Admin routes call the `is_admin` RPC and redirect home on
*any* exception (`app_router.dart:1648-1670`, `:1674-1696`), and the admin screens re-check
independently. Deep links do **not** bypass the gate: `_handleRedirect`
(`app_router.dart:155`) is default-deny by construction — an allowlist, with unauthenticated
traffic bounced at `:357-372` and the intended destination stashed and replayed after auth
(`:236-251`, `:404-412`).

The failure is one layer above the model:

```
client ──► PostgREST ──► VIEW ──► TABLE
                          ▲          ▲
                          │          └── RLS: correct. notifications → 0 rows as anon.
                          └── SECURITY DEFINER, no predicate: 609 rows as anon.
```

**A definer view is a hole punched through RLS at the schema level.** The base table's
policy is never consulted, because the view runs as its owner. 19 anon-readable views have
this shape; 5 are confirmed leaking. `T-001` closes the class by making
`security_invoker = true` the default; `T-002` keeps it closed with a catalogue test.

**The ordering constraint that governs the fix:** flipping a view to `security_invoker`
makes the caller's RLS apply — so a view over a table with *no usable policy* starts
returning 0 rows. `public.games` has RLS enabled with **zero policies**. Base-table policies
must therefore land **before** the invoker flip, or live screens go blank. This is the one
place in the remediation where sequence matters.

### 10.2 The four trust boundaries

| Boundary | Control | State |
|---|---|---|
| Client → Postgres | RLS on base tables | **Correct**, and bypassed by definer views (`T-001`) |
| Client → Edge function | JWT verification | Present; **authorization scope missing** on `send-push-notification` (`T-009`) |
| Client → Storage | Bucket policies | Live paths correct; one wrong constant, zero call sites (`T-007`) |
| Device → Network | TLS, ATS, no cleartext | **Clean.** Pinning deliberately rejected (`T-006`) |

The client is **not** a trust boundary. Anything enforced only in Dart is a UX affordance,
not a control.

### 10.3 On-device state is the weakest surface

Transport and authorization are in better shape than local state. Session tokens sit in
plaintext `SharedPreferences` (the supabase_flutter default) — acceptable in itself, but
Android Auto Backup is **on by default** at `targetSdk 35` with no exclusion rules, so a
long-lived refresh token syncs to Google Drive (`T-005`). And logout tears down nothing:
no cache is cleared and the FCM token is never revoked, so a signed-out device keeps
receiving the previous account's pushes (`T-004`).

**Local state has no teardown contract.** Every cache was added independently and none
registers with logout. `T-004` makes that contract explicit — the architectural point is
that a new cache must join it, not merely that today's three need clearing.

### 10.4 Standing positions

- **`security_invoker = true` is the default for every view.** Definer is an exception with a
  written reason in `SCHEMA.md` §2.
- **A view never carries an `auth.uid()` predicate.** Authorization is expressed once, on the
  table.
- **Authenticating a caller is not authorizing it.** An edge function acting on a body-supplied
  `user_id` proves the caller's relationship to it.
- **No credential is ever a literal in a tracked file** (`T-003`).
- **No certificate pinning** (`T-006`) — recorded so it is not reopened each audit.
- **Population counts come from the catalogue, never a scanner's finding count** (decision
  `020`) — the advisor undercounted this leak by more than half.

### 10.5 Known-broken, filed, not blocking

`public.v_space_slots_today` raises `42P01` for **every** caller — its `find_slots(uuid,
date, integer)` function queries `public.venue_opening_hours`, which does not exist.
Reproduced as `anon` 2026-08-27. It is broken rather than leaky, so it is not a promotion
blocker, but it means any venue-slot surface built on it has never worked.
