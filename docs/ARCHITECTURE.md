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
