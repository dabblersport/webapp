---
name: index
description: Fact → value → source → date lookup table. Check this FIRST for any question about the project; answer with the number and its citation, or say "not established".
metadata:
  type: project
---

# INDEX — the answer desk

**Protocol.** Check here first. Answer with **the number and its citation in the first
sentence**, and say when it was measured. If the fact is not here, say
**"not established — want me to measure it?"** and offer the command.

**Never answer from recollection.** Three numbers were confidently wrong on 2026-08-26 and
survived into eight documents: *25 definer views* (really 49), *8 anon-exposed* (really 19),
*no schema history* (really 237 migrations). Each was stated fluently. A confident wrong
number is worse than "I don't know", because nobody re-checks it.

**Staleness rule.** Code figures are valid for the commit they name; DB figures for the date
they name. If the question is load-bearing — a deletion, a security claim, a deploy — **and
the record is older than the last change to that area, re-measure.** Every row carries a
`Re-measure` command for that purpose.

**Precedence.** `DECISIONS.md` (newest ACTIVE) → `MANIFESTO.md`/`CONTRACT.md` →
`CONVENTIONS.md` → everything else. `SCHEMA.md` §8 mismatch 7 owns the migration question.
`PROJECT_STATE.md` owns the violation counts. If a doc disagrees with this index, the doc
wins and this index is corrected.

Baseline commit: **`5f92904`**, branch `Canary` (run 2, 2026-08-27; run 1 was `1b83967`). DB project: `wtncuzcskpigqpmnxwws`.

---

## 1. HEADLINE SHAPE

| Fact | Value | Source | Measured |
|---|---|---|---|
| Non-generated Dart files | 783 | `PROJECT_STATE.md` §1 | 2026-08-26 |
| Non-generated LOC | ~226,327 | `PROJECT_STATE.md` §2 | 2026-08-26 |
| Feature slices | 25 | `PROJECT_STATE.md` §3 | 2026-08-26 |
| Slice status | SHIPPED 12 · PARTIAL 6 · SCAFFOLD 1 · DEAD 6 | `PROJECT_STATE.md` §3 | 2026-08-26 |
| Commits / age | 390 · 2025-10-17 → 2026-08-17 | `PROJECT_STATE.md` §2 | 2026-08-26 |
| `flutter analyze` | **0 errors** · 55 warnings · 102 infos (157) | `PROJECT_STATE.md` header | 2026-08-26 |
| `flutter test` | **66 pass**, 5 files — all cover unreachable code | `PROJECT_STATE.md` TEST-01 | 2026-08-26 |

`Re-measure:` `flutter analyze --no-pub` · `flutter test`

## 2. THE 25 SLICES

| Slice | LOC | Status | Note |
|---|---:|---|---|
| profile | 40,854 | PARTIAL | live repo is `lib/data/repositories/profiles_repository_impl.dart` (221 LOC) |
| social | 28,827 | SHIPPED | 5/6 screens routed |
| rewards | 20,545 | **SCAFFOLD — NOTHING LIVE** | corrected 2026-08-27: `FeatureFlags.enableRewards = false` (`feature_flags.dart:57`) gates both the route (`app_router.dart:932`) and the check-in modal (`main_navigation_screen.dart:81,96`). Check-in is complete and switched off. **FROZEN, decision 015** |
| auth_onboarding | 17,471 | SHIPPED | **16/16 screens routed, zero orphans** |
| games | 16,792 | PARTIAL | 1/3 screens routed; 5,674 LOC clean-arch dead. **FROZEN, decision 016** |
| misc | 8,260 | PARTIAL | **4,972 LOC dead wizard**; see §6 |
| explore | 7,664 | PARTIAL | 3/7 screens routed |
| notifications | 4,204 | **SHIPPED — healthiest slice** | every file has an importer |
| location | 3,602 | PARTIAL | widget library, 18 external importers |
| venues | 3,528 | PARTIAL | 1/2 routed |
| home | 3,461 | SHIPPED | |
| venue_submissions | 1,670 | SHIPPED | |
| news | 1,604 | SHIPPED | |
| admin | 889 | SHIPPED | gated on `rpc(is_admin)` |
| activities | 622 | SHIPPED | widget-only |
| payments | 503 | **DEAD** | 0 importers |
| moderation | 285 | SHIPPED | provider-only |
| audit_safety | 145 | **DEAD** | |
| squads | 136 | **DEAD** | backend fully built, client absent |
| app_boot | 117 | SHIPPED | |
| username_engine | 114 | SHIPPED | |
| display_names | 90 | **DEAD** | |
| bench_mode | 84 | **DEAD** | backend built |
| error | 53 | SHIPPED | |
| core | 18 | SHIPPED | |

Source: `PROJECT_STATE.md` §3 · measured 2026-08-26

## 3. DATABASE

| Fact | Value | Source | Measured |
|---|---|---|---|
| Public tables | **184** | `SCHEMA.md` §1 | 2026-08-27 |
| RLS enabled | 183 (`spatial_ref_sys` is PostGIS, not a finding) | `SCHEMA.md` §1b | 2026-08-27 |
| Tables **with** policies | 153 | `SCHEMA.md` §1 | 2026-08-27 |
| Total policies | 336 | `SCHEMA.md` §1 | 2026-08-27 |
| **RLS on, zero policies** | **30** — incl. `games`, `squad_members`, `moderation_tickets` | `SCHEMA.md` §1a | 2026-08-27 |
| Views total | **71** | `SCHEMA.md` §2 | 2026-08-27 |
| `SECURITY DEFINER` views | **49** | `SCHEMA.md` §2 | 2026-08-27 |
| **anon-exposed (definer, no uid filter)** | **19** — 2 PostGIS, 5 confirmed leaking, 12 unexamined | `SCHEMA.md` §2a | 2026-08-27 |
| definer + uid filter (safe) | 8 | `SCHEMA.md` §2b | 2026-08-27 |
| anon-revoked (safe by grant) | 23 | `SCHEMA.md` §2c | 2026-08-27 |
| invoker | 21 (22 explicit − 1 also anon-revoked) | `SCHEMA.md` §2d | 2026-08-27 |
| RPCs | ~180 | `SCHEMA.md` §4 | 2026-08-26 |
| Triggers | ~200 | `SCHEMA.md` §5 | 2026-08-26 |
| Edge functions | 3 — `send-push-notification`, `broadcast-notification`, `detect-country` | `SCHEMA.md` §6 | 2026-08-26 |
| Extensions | 16 (8 in `public` — Supabase default, not a finding) | `SCHEMA.md` §7 | 2026-08-26 |
| **Applied migrations** | **237** — `20251113222001` → `20260720192127` | `SCHEMA.md` §8 #7 | 2026-08-27 |
| Tracked `.sql` in repo | 40 files / 5,787 lines at `supabase/schema/` — **1 has `CREATE TABLE`** | `SCHEMA.md` §8 #7 | 2026-08-27 |
| `supabase/migrations/` | **DOES NOT EXIST** | `CONTRACT.md` §9 | 2026-08-27 |

`Re-measure views:` `SCHEMA.md` §2e query · `Re-measure ledger:` `select count(*) from supabase_migrations.schema_migrations`

### Storage buckets — 4

| Bucket | SELECT | INSERT | State |
|---|:--:|:--:|---|
| `Avatar` | ✓ | ✓ | healthy |
| `post-media` | ✓ | ✓ | healthy |
| `dabbler-news` | **0** | ✓ | **read-back broken** |
| `venue` | **0** | **0** | **no policies — uploads impossible** |

**Buckets named in code that do not exist:** `'venue-images'`
(`supabase_config.dart:4`, real name `venue`) · `'avatars'`
(`supabase_profile_datasource.dart:16`, real name `Avatar`). Both in dead paths.
Source: `SCHEMA.md` §3 · 2026-08-26

### Security findings beyond the views (cto pass, verified 2026-08-27)

| Finding | Detail |
|---|---|
| **SEC-11** keystore | **HIGH, not a launch blocker.** Passwords plaintext in tracked `build.gradle.kts:36,38`, exposed 9 months (`ebaf9b8`, 2025-11-22). **No signing artifact has ever been in the repo on any ref; Android signing never runs in CI.** PO-facing: *a credential is exposed, the signing artifact is not.* KAN-57 |
| **SEC-12** logout | `auth_service.dart:261-267` — `signOut()` clears no cache and never deletes the `fcm_tokens` row. Signed-out devices keep receiving the prior account's pushes. KAN-58 |
| **SEC-13** push authz | **CRITICAL — launch blocker.** `send-push-notification` authenticates but does not authorize. Any account sends arbitrary trusted first-party push; **passwordless signup makes an account free**, so launch multiplies attacker and target pools at once. KAN-59 |
| **SEC-14** Android backup | Auto Backup on by default at targetSdk 35, no exclusions → refresh token syncs to Google Drive. KAN-60 |
| **BUG-05** | `v_space_slots_today` raises 42P01 — `find_slots()` queries `venue_opening_hours`, which does not exist. **`opening_hours` does** — likely a missed rename |
| **BUG-06** | `assetlinks.json:7` still `REPLACE_WITH_SHA256…` while manifest sets `autoVerify=true` → App Links do not resolve |

### The live leak — KAN-36/37/38

`v_notifications_feed` and `v_notifications_ranked` return **609 rows / 49 distinct
recipients** to `anon`, no login. `v_mod_queue_open` 9, `v_safety_overview` 1,
`v_circle_feed` 6. **The base table returns 0** — RLS works; two definer views bypass it.
Reproduction + control query: `SCHEMA.md` §2a. Measured 2026-08-27.

## 4. CONVENTIONS & VIOLATIONS

| Convention | State | Count | Finding |
|---|---|---:|---|
| No hardcoded table/bucket names | **HOLDS** | 0 | — |
| No raw `MaterialPage` | **HOLDS** | 0 | — |
| Imperative `MaterialPageRoute` | violated | **13** sites / 8 files (5 in `sports_screen.dart`) | STYLE-03 |
| Hardcoded `Color(0x…)` | violated | **317** across 43 files (was 233 — unrecorded filter) | STYLE-01 |
| Error conventions | **THREE**, not two | `Result` 124 · fpdart `Either` · **hand-written `lib/core/utils/either.dart` in 13 files** (not fpdart-compatible) | ARCH-03 |
| Files > 500 LOC (non-generated) | not enforced | **140** | ARCH-01 |
| Stray `print()` | violated | **26** | STYLE-02 |
| Empty catch blocks | violated | **44** (7 on live onboarding path) | ERR-01 |
| Orphan providers | — | **113 of 400** | PROV-01 |
| Features with no test dir | — | **22 of 25** | TEST-02 |
| Unused route constants | — | **65 of 195** (corrected 2026-08-27: `RoutePaths` 21/99, `RouteNames` 44/96) | FLAG-02 |

**Exception found 2026-08-27:** RPC names *are* inlined as string literals in
`nearby_games_repository_impl.dart` (4 calls). The "0 hardcoded identifiers" figure covers
tables and buckets, **not RPCs**. `SCHEMA.md` §4.

Source: `PROJECT_STATE.md` §4 · `CONVENTIONS.md` · 2026-08-26

## 5. FEATURE FLAGS

| Fact | Value |
|---|---|
| Declared | **113** |
| Actually gating something | **10** |
| Snapshot-only (`main.dart:80-92`) | 5 |
| Read nowhere | **98** |
| **Hardcoded `true`** | **112 of 113** — only `enableRewards` is `false` |
| Triage | KEEP 11 · **CUT 62** · DEFER 38 · BLOCKED 2 |

**Two flags contradict their own comments** — `enablePlayerGameCreation = true; // Players
CANNOT create games` and `enableOrganiserGameJoining = true; // Organisers CANNOT join`.
Both gate live code. **NEEDS PO INPUT.**

Source: `ROADMAP.md` §0, §2, §3 · measured 2026-08-26

## 6. DEAD CODE

| Item | LOC | Note |
|---|---:|---|
| **Game-creation wizard** (7 files + `.broken`) | **4,972** | Transitive dead — steps imported only by `create_game_screen.dart`, itself 0 importers. **Never called `rpc_create_game`** |
| `rewards` minus check-in | 19,560 | FROZEN, decision 015 |
| `games` clean-arch stack | 5,674 | FROZEN, decision 016 |
| Orphan screen files (9, excl. wizard) | ~5,733 | DEAD-06…DEAD-12 |
| Dead slices (payments, audit_safety, squads, display_names, bench_mode) | 958 | |
| Orphan screen classes total | 21 across 12 files | |

**Not dead, despite appearances:** `notifications_screen_v2.dart` and
`activities_screen_v2.dart` are the **live routed** screens. `area_repository_v2.dart` is
live (3 importers). `sports_history_screen.dart` is live (3 importers) — only its *class* is
orphaned.

Source: `PROJECT_STATE.md` §4 · `ARCHITECTURE.md` §3b · 2026-08-26 / wizard 2026-08-27

## 7. THE TWO CORE FLOWS

**Game creation.** Live: **`lib/features/misc/presentation/screens/game_composer_screen.dart`**
(1,685 LOC, routed at `app_router.dart:1200/1225/1238`). **CORRECTED 2026-08-27 — it is NOT
under `features/games/`; that path does not exist** → `rpc_create_game`, `rpc_update_game`. The 7-step wizard
in `misc/` is entirely dead — see §6.

**Auth/onboarding.** **All 16 screens routed, zero orphans.** Order: `authWelcome` →
`emailInput` → `otpVerification`/`emailVerification` → `createUserInfo` →
`onboardingPersonaSelection` → `onboardingPrimarySport` → `onboardingInterestsSelection` →
`onboardingSports` → `onboardingPreferences` → `onboardingPrivacy` → `onboardingCompletion`
→ `welcome`. Passwordless (decision 002). Gated in `_handleRedirect`.

Source: `ARCHITECTURE.md` §3b · measured 2026-08-27

## 8. NEARBY RPCs — 5 generations, generation 4 is current

| Generation | Live? |
|---|---|
| **4** — `rpc_get_nearby_games`, `rpc_get_nearby_venues` | **LIVE** → `games_screen`, `venues_screen` (both routed) |
| 2 — `get_nearby_posts` | **DEAD — corrected 2026-08-27.** `feedRepositoryProvider`/`nearbyRpcFeedProvider` have no consumer outside `feed_providers.dart`. Live feed is `TabFeedNotifier` → `post_repository_impl.dart:449-507`, a direct `posts` query, no RPC |
| — `geo_nearby_venues` | **LIVE** via `geo_repository_impl.dart` |
| 2 — `get_nearby_games/venues/profiles` | dead consumers |
| **1 and 3, `rpc_nearby_users`** | **no caller at all — 9 functions** |

**Hazards:** `get_nearby_games` has two overloads (`integer` / `double precision`) and
callers pass an untyped `num`. `nearbyGamesProvider` and `nearbyVenuesProvider` are each
declared **3×**; live screens use `import ... hide nearbyGamesProvider` to avoid the export
hub's version.

Source: `SCHEMA.md` §4 · measured 2026-08-27

## 9. DECISIONS — all 20

| # | Decision | Status |
|---|---|---|
| 001 | `Result<T,Failure>` for new code | ACTIVE — 31 files still `Either` |
| 002 | Accounts passwordless (`trg_strip_signup_password`) | ACTIVE — trigger verified |
| 003 | Auth email on Resend SMTP | ACTIVE — **dashboard-only, invisible to repo** |
| 004 | `main` never pushed directly | ACTIVE |
| 005 | Cloudflare Production + Preview both need every variable | ACTIVE — unverified, KAN-35 |
| 006 | Supabase locked to `wtncuzcskpigqpmnxwws` | ACTIVE |
| 007 | Identifiers only from `supabase_config.dart` | ACTIVE — held for tables/buckets, **not RPCs** |
| 008 | Colour tokens in 3 synced places; `JSONS/` dead | ACTIVE |
| 009 | Never hardcode colours | ACTIVE — 233 violations |
| 010 | Transition wrappers, never `MaterialPage` | ACTIVE — held, 0 violations |
| 011 | Gate features with flags | ACTIVE — decayed |
| 012 | MCP project-scoped in `.mcp.json` | ACTIVE |
| 013 | Files under 500 lines | ACTIVE — 140 over |
| 014 | Trust RLS | ACTIVE — client held, **DB did not** |
| 015 | **`rewards` frozen** pending KAN-29 | ACTIVE — blocking |
| 016 | **Clean-arch stack frozen** pending KAN-30 | ACTIVE — blocking |
| 017 | Governance docs closed to the agents they govern | ACTIVE |
| 018 | Rules written to `docs/`, not chat | ACTIVE |
| 019 | **No agent writes production DB** | ACTIVE — PO decision |
| 020 | Count populations, never infer from a tool's finding count | ACTIVE |
| 021 | **Leadership layer — CPO/CTO hold delegated decision authority** | ACTIVE — closes the unprefixed sequence |

Source: `DECISIONS.md`

## 10. AGENTS & OWNERSHIP

**7 agents, three layers** (decision 021, 2026-08-27):
**Leadership** — `master-analyst` (measures; read-only over code) · `cto` (technical
decisions) · `cpo` (product decisions). CFO later.
**Executive** — `notifications-specialist` · `version-control` · `app-store-submission-fixer`.
**Review** — `task-auditor` (writes **one** file).

**The ownership line:** master-analyst establishes *what is true*; cpo/cto decide *what
should be true next*. `SCHEMA.md` is **split** — §§1–8/§10 measured (analyst), §11 target
state (cto). `BRIEF.md`/`ROADMAP.md` → cpo. `DECISIONS.md` prefixed `G-`/`T-`/`P-`.
Leadership may reject an executive's work with reasons; neither writes production or
feature code.

**23 of 25 slices are UNOWNED**, as is `lib/core/**`, `lib/data/**`, the design system, and
all Supabase outside notifications. **Three design-system surfaces:**
`lib/core/design_system/` (22 files, largest) · `lib/design_system/` (11) ·
`dabbler_design_system` (git dep, 0 imports).

Source: `CONTRACT.md` §3 · `AGENTS.md` · `ARCHITECTURE.md` §2

## 11. OPEN — blocking

**Live security:** KAN-36/37/38 (leaks) · KAN-26 (12 unexamined views). **Launch gate
fails** — `MANIFESTO.md` §4.4.

**PO decisions:** KAN-29 rewards · KAN-30 clean-arch · KAN-16 roster · KAN-22 the 62 CUTs ·
KAN-23 `BRIEF.md`'s 7 questions · the two contradictory flags.

**Not mine (read-only):** KAN-27/28/31/32/34 are code changes — need a Flutter agent.
KAN-35 needs Cloudflare dashboard access.

## 11a. APPLICATION INVENTORY — run 2, 2026-08-27, commit `5f92904`

Source for every row: `PROJECT_STATE.md` Part II (§13–§20).

| Fact | Value |
|---|---|
| **Unreachable from `main.dart`** | **267 non-generated files / 69,612 LOC** (~11× the run-1 orphan figure) |
| Dart files under `lib/` | 835 · import-reachable 558 |
| Screen/page/view classes | **101** — 74 route-referenced · 2 push-only · 7 orphaned public · 18 private helpers |
| `GoRoute` declarations | 90 |
| Routes rendering "Coming Soon" | **7** = 6 `_PlaceholderScreen` + 1 inlined (`app_router.dart:590`) — **1 reachable in-app (`socialChat`), 6 orphans, all 7 URL-reachable** |
| Route-registered, no UI navigates there | 31 `RoutePaths` — **reachable by URL, this is a web app** |
| **User flows traced** | **23 · 19 complete end to end** |

**The 4 that do not work:** chat (advertised by a live button → "Coming Soon",
`app_router.dart:1617`) · Circles (no entry point; composer offers it,
`post_composer_providers.dart:514`) · rewards (built, flag off) · 7-step game wizard (dead).

**The promise gap — live files only:** 30 `UnimplementedError` · 25 TODO/FIXME ·
12 "coming soon" strings · 8 mock-data sites · 5 empty `onPressed`.

**Worst 5, in order:**
1. **INV-01** Message button on every user profile → "Coming Soon" (`user_profile_screen.dart:1094` → `app_router.dart:1617`)
2. **INV-02** `RoutePaths.onboardingPersonaSelection` is a redirect target with **no registered route** → error page (`app_router.dart:194,211,329`)
3. **INV-03** onboarding sets `onboard=true` with persona/sport rows possibly missing; failures swallowed (`auth_service.dart:1081,1090,1099`)
4. **INV-04** two screens say "saved!" and write nothing (`profile_avatar_screen.dart:624-660`, `availability_preferences_screen.dart:1045-1059`)
5. **INV-05** `/transactions` shows fabricated AED amounts on a live route (`transactions_screen.dart:51`, `enablePayments=true`)

`Re-measure:` `.claude/jobs/*/tmp/reach.py` (import BFS) · `census.sh` (class census)

## 11b. CORRECTED FACTS — do not quote the old version

| Was recorded | Truth (verified 2026-08-27) |
|---|---|
| `/settings/language` renders "Coming Soon" | **False.** `:590` is `/language_selection`, an orphan. `/settings/language` is at `:1287` → real 226-line `LanguageSelectionScreen`. **Language switching works** |
| **WIRE-09: "all 7 placeholder routes are unreachable"** (my own 1d correction) | **False, and it was wrong in the direction of relief.** **6 are orphans; `socialChat` is reachable.** `user_profile_screen.dart:1094` Message button (no flag, no condition) → `:1475` `context.push('${RoutePaths.socialChat}/$userId')` → `app_router.dart:1607` route → guard `:1611` `FeatureFlags.messaging`, which is **`true`** → `:1617` "Coming Soon". **INV-01 above is correct — do not retire it on the blanket claim.** Also: **no placeholder route is behind a closed flag** — `socialNotifications`/`socialMessages` carry guards but both flags are `true`; the other four have no guard. `PROJECT_STATE.md` WIRE-09, run 1f |
| 233 hardcoded colours | **317 across 43 files** (old filter unrecorded) |
| 25 `UnimplementedError` in settings repo | **24** — a doc comment contained the word `throw` |
| "no schema history" | **237 applied migrations** |
| 49 views / 25 definer / 8 exposed | **71 / 49 / 19** |

## 12. NOT ESTABLISHED — say so, don't guess

- Row counts for **12 of the 19** anon-exposed views
- Whether the 30 zero-policy tables are deliberately definer-RPC-only
- Which of the **three** design systems is canonical
- Apply order of the 237 ledger migrations vs the 40 repo files
- Cloudflare Preview variable state
- **Everything in `BRIEF.md`** — product intent, audiences, success criteria, non-goals
- Runtime behaviour of any kind: performance, crash rates, actual user flows
- Whether the 6 suspected duplicate trigger pairs are genuinely duplicates
- Whether `rpc_create_game` accepts `p_min_players`/`p_max_players` — the composer comment
  (`game_composer_screen.dart:484-485`) and `rpc_update_game.sql:12-13` contradict each other;
  `rpc_create_game`'s definition is not in the repo
- How many of the 267 unreachable files are intentionally-parked work vs residue
