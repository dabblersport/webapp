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

## 0. RUN 4 — 2026-09-01, launch-readiness refresh (KAN-39). READ BEFORE §1.

**These supersede §1 and every dated row below them.** Source for all: `PROJECT_STATE.md` §22.

| Fact | Value | Measured |
|---|---|---|
| **Sprint-2 batch is UNCOMMITTED** | **109 files in `lib/`, +594 / −30,762** | 2026-09-01 |
| `.dart` under `lib/` — HEAD vs tree | **833 vs 781** (rewards 36 → 4) | 2026-09-01 |
| `Canary` ahead of `main` | **32 commits** | 2026-09-01 |
| Non-generated `lib/` LOC (working tree) | **203,580** across 729 files | 2026-09-01 |
| `flutter analyze` | **0 errors · 37 warnings · 93 total** | 2026-09-01 |
| `flutter test` | **103 pass** — now covers the live path | 2026-09-01 |
| Notification leak (`v_notifications_feed`/`_ranked`) | **RESOLVED** — `security_invoker=on`, **0 rows to `anon`** (was 609 / 49 recipients) | 2026-09-01 |
| `public.profiles` to `anon` | **154 of 154 rows, raw `auth.users` UUIDs — STILL OPEN** (KAN-106 authored, not applied) | 2026-09-01 |
| `anon` write grants across `public` | **558** (incl. INSERT/UPDATE/DELETE on `profiles`) | 2026-09-01 |
| Views: total / invoker / definer | **71 / 22 / 49** — advisor `security_definer_view` findings **15** (was 49) | 2026-09-01 |
| `rls_enabled_no_policy` | **30** (unchanged) | 2026-09-01 |
| `v_space_slots_today` | **ERRORS** — `relation "public.venue_opening_hours" does not exist` | 2026-09-01 |
| CI | **red on all 4 most recent runs**; sibling "Anon reachability allowlist" **passes** | 2026-09-01 |
| `enablePayments` / `messaging` | **both `false`, committed at HEAD** — INV-05 and INV-01 closed | 2026-09-01 |
| `DataExportService` importers | **0 — correct.** Descoped by `DECISIONS.md` `P-025` | 2026-09-01 |
| `STATUS.md` gap | no entry 2026-08-29 → 2026-09-01 across ~30 closures | 2026-09-01 |

**WITHDRAWN, same day: L-09 "Arabic switcher is Coming Soon".** FALSE POSITIVE, and the
**second** time this line has been filed (first raised and retracted 2026-08-27 — §11b, WIRE-10).
`app_router.dart:599` `/language_selection` is an **orphan** — `grep -rn language_selection lib/`
returns only its own declaration and an unused import at `:68`. The live path is
`settings_screen.dart:1062` → `_showLanguagePicker()` `:1073` → `ref.read(localeProvider)` `:1090`.
**Language switching works. Do not file this a third time.** Generalise it: a "Coming Soon"
string on a declared route proves nothing until you grep for who navigates to it — two routes can
serve one concept, and the orphan greps first.

**Also: `enablePayments` is `false`** (`:146` tree, `:142` HEAD) — `cpo`'s `true` at `:139` is a
stale 08-26/27 read. **`anon` write grants: 558 grant-rows == `cto`'s 184 tables × ~3 verbs — the
same fact in different units, not an escalation.**

**THE MEASUREMENT TRAP — do not repeat it.** `select ... where 'security_definer=true' = any(reloptions)`
returns **0** and looks like a clean bill of health. SECURITY DEFINER is the Postgres **default**
for a view and stores no reloption. Correct measure: `total_views − security_invoker views`.
Likewise, an `anon` SELECT **grant** on a view proves nothing once the view is `security_invoker` —
**check the reloption and the empirical row count as role `anon`, never the grant alone.**

`Re-measure:` `git diff HEAD --stat -- lib` · `set local role anon; select count(*) from public.profiles`

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
| **anon-exposed (definer, no uid filter)** | **19** as measured — 2 PostGIS, 5 confirmed leaking, 12 unexamined. **All 5 leaks now CLOSED** (KAN-36/37/38b, then KAN-56 for the last 3); §2a's rows read CLOSED as of 2026-08-29 | `SCHEMA.md` §2a | measured 2026-08-27, closed 2026-08-29 |
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
| **SEC-11** keystore — **CONDITION RESOLVED 2026-08-28** | **The keystore file has NEVER been committed on any ref, in any commit** (`git log --all --diff-filter=A --name-only` over `*.jks/keystore/p12/pfx/pem/key`, `key.properties` → NONE). What leaked at `ebaf9b8` is **four string literals**. **BUT the repo is PUBLIC** (`gh repo view` → `visibility: PUBLIC`), so they have been world-readable 9 months. A password without the artifact **cannot sign** → not independently exploitable. **Promotion does not worsen it** → recommended OFF the promotion gate (B10), kept as HIGH. **Still closes only on ROTATION, never on the diff.** Open risks: password reuse elsewhere (unmeasurable from repo — ask PO); pre-compromised against any future `.jks` leak. KAN-57 |
| ~~SEC-11 (superseded row)~~ | **HIGH, not a launch blocker.** Passwords plaintext in tracked `build.gradle.kts:36,38`, exposed 9 months (`ebaf9b8`, 2025-11-22). **No signing artifact has ever been in the repo on any ref; Android signing never runs in CI.** PO-facing: *a credential is exposed, the signing artifact is not.* KAN-57 |
| **SEC-12** logout | `auth_service.dart:261-267` — `signOut()` clears no cache and never deletes the `fcm_tokens` row. Signed-out devices keep receiving the prior account's pushes. KAN-58 |
| **SEC-13** push authz | **CRITICAL — launch blocker.** `send-push-notification` authenticates but does not authorize. Any account sends arbitrary trusted first-party push; **passwordless signup makes an account free**, so launch multiplies attacker and target pools at once. KAN-59 |
| **SEC-14** Android backup | Auto Backup on by default at targetSdk 35, no exclusions → refresh token syncs to Google Drive. KAN-60 |
| **BUG-05** | `v_space_slots_today` raises 42P01 — `find_slots()` queries `venue_opening_hours`, which does not exist. **`opening_hours` does** — likely a missed rename |
| **BUG-06** | `assetlinks.json:7` still `REPLACE_WITH_SHA256…` while manifest sets `autoVerify=true` → App Links do not resolve |

### SEC-15 / SEC-15a — unauthenticated DESTRUCTIVE write, DEMONSTRATED (2026-08-28)

**Answer this one from here; it is the most serious finding in the record.**

| Fact | Value |
|---|---:|
| Views in `public` | 71 |
| Granting `anon` INSERT/UPDATE/DELETE | **70** |
| Definer + auto-updatable = **LIVE WRITE PATHS** | **8** |

The 8: `v_notifications_feed`, `v_notifications_ranked`, `v_posts_time_preview`,
`v_user_reputation`, `v_my_drafts`, `v_hidden_list`, `v_needs_organiser`, `geometry_columns`.
**Reaches posts, reputation and drafts, not just notifications.**

**Demonstrated, not inferred.** `EXPLAIN` *without* `ANALYZE` plans and ACL-checks but
executes nothing — a read, so it does not breach decision 019. `EXPLAIN DELETE` as `anon`
through the view and against the base table produce **identical plans**, except the base
table carries `Filter: current_setting('request.jwt.claim.sub')::uuid = to_user_id` and the
view **has no filter at all**. Method credit: `cto`; figures reproduced independently by me.

**No residual protection.** All 8 views are `security_invoker=false`, so base-table access
is checked as the **owner** — `postgres` (`rolbypassrls=true`) for 7, **`supabase_admin`
(`rolsuper=true`)** for `geometry_columns`. **RLS is definitionally not consulted**, not
merely bypassed.

**The REVOKE is safe — verified twice over.** `grep -rnE "\.from\('v_|\.from\(\"v_" lib`
→ 0; and **none of the 8 appears anywhere in `lib/` at all**. Zero client effect.
**`geometry_columns` is the exception** — `supabase_admin`-owned and PostGIS-managed; it
needs its own remediation path, not the batch.

**`geometry_columns` cannot be revoked at all** (T-015, verified): migrations run as
`postgres`, which is **not** superuser and **not** a member of the owner `supabase_admin`
(`pg_has_role` → false). So the fix closes **7 of 8**. **Never use
`REVOKE ... ON ALL TABLES IN SCHEMA public`** — it either halts mid-migration or skips the
untouchable object *while reporting success*. Enumerate targets explicitly.

**Fix order:** REVOKE **first**, ahead of all `security_invoker` work — destructive beats
confidentiality. Two uid predicates alone leave `anon` holding DELETE on 8 views. One
project-wide privilege migration, `cto`'s authorship, PO-gated. **Not yet applied.**

Full detail + queries: `PROJECT_STATE.md` SEC-15a. Ticket: KAN-67, KAN-56.

**Scoped-correction rule (from `cto`, 2026-08-28):** `geometry_columns`/`geography_columns`
were do-not-re-flag false positives **for READ only** — `geometry_columns` is one of the 8.
**A false-positive ruling is scoped to the privilege it was made about.** Check [[audit-false-positives]] carries this qualifier.

### SEC-15 — the leak is not read-only (original entry, 2026-08-28)

All five leaking views grant `anon` **SELECT INSERT UPDATE DELETE TRUNCATE REFERENCES
TRIGGER**. `v_notifications_feed` and `v_notifications_ranked` are **auto-updatable**
(`is_updatable=YES`) *and* SECURITY DEFINER *and* already proven to bypass RLS on read.
Every precondition for unauthenticated write/delete of other users' notifications is
present. **The write was not demonstrated** — that is a data change, decision 019. Claim
scope: *preconditions verified, exploitation not demonstrated.* The fix has two independent
halves: the `anon` grants and the uid-predicate. Full table + both queries:
`PROJECT_STATE.md` SEC-15 (line 874). **Not established:** whether the full-privilege grant
is project-wide drift across all 71 views — cheap to measure on request.

**B1's honest ceiling this month** (cpo ruling 2026-08-28, verified against
`CONTRACT.md:119,125`): **reviewed SQL for 2 of 5 views, PO-gated.** NS may author only the
two notification views; `v_mod_queue_open` / `v_safety_overview` / `v_circle_feed` are
UNOWNED. **No agent applies to production.** Do not repeat "B1 is owned and unblocked" —
that was my error, corrected by cpo.

### The five zero-policy orphan tables + BUG-07 (2026-08-28)

**NOT a definer funnel** — all three referencing functions are `prosecdef=false` (INVOKER),
so `cto`'s T-012 "revoke, don't add policies" ruling does **not** apply to these five. An
invoker fn over an RLS-on zero-policy table returns **0 rows to every real caller**
(verified `set local role authenticated`).

| Table | rows | fn refs | definer | `lib/` |
|---|---:|---:|---:|---:|
| `challenge_types` | 8 | **0** | 0 | **0** |
| `surface_catalog` | 30 | **0** | 0 | **0** |
| `context_rating_config` | 2 | 1 `_get_context_config` | 0 | 0 |
| `safety_blocklist_terms` | 2 | 1 `content_hits_blocklist` | 0 | 0 |
| `space_slot_holds` | **0** | 1 `_slot_conflicts_hold` | 0 | 2 (const+model) |

**RULED:** `challenge_types` + `surface_catalog` → **REVOKE NOW, DEFER THE DROP** (`cto`).
T-007's deletion default **does not transfer**: dead Dart is recoverable from git, 38 rows of
dropped config are recoverable from nothing. A table with no reader costs nothing to keep.
**`space_slot_holds` → KEPT** (`cpo` `P-013`) — parked scaffolding for venue slot booking,
**committed scope** Phase 1B Month 9. *Deferred product is not dead code*, same as
`lib/features/payments/`. **Do not drop it in an orphan sweep.**

**BUG-07 / KAN-68 — the blocklist fails open TWICE, but nothing calls it.**
(1) locale predicate can never match: filters `locale='any' or locale=p_locale`; both terms
are `locale='en'`; client defaults `'any'` (`moderation_service.dart:546,553`). Proven **as
service role** (no RLS confound): `content_hits_blocklist('buy a fake passport here')` → **0**.
(2) INVOKER over RLS-on/zero-policy → 0 terms as `authenticated`. Fixing (1) alone changes
nothing. **`contentHitsBlocklist` has NO caller in `lib/`** → **a trap, not a breach** — say
this plainly, do not report it as a live safety hole. **RULED T-016: FIX, don't delete**
(explicit exception to T-007 — a UGC product should have a blocklist). Locale:
`p_locale='any' or locale='any' or locale=p_locale`. RLS: make the fn **DEFINER** + **REVOKE**
`SELECT` from `anon`/`authenticated` — **NOT a read policy**, because *a moderation control
whose contents are visible to the people it constrains is not a control*. Same for
`context_rating_config`. **Verify as role `authenticated`, never service role.** `moderation_service.dart` *is* live
(game composer, report dialog, both admin screens), so it is one wiring change from trusted.
Detail: `PROJECT_STATE.md` BUG-07.

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

## 9a. PREFIXED DECISIONS — all 62 (`G-` governance · `T-` technical · `P-` product)

**Added 2026-08-29 to close a real gap in this desk.** §9 held only the 21 unprefixed decisions,
so a question like *"what does `G-008` say?"* forced a read of a 3,500-line file. The line number
is the `###` heading in `docs/DECISIONS.md` — **jump to it, do not grep the whole file.**
Line numbers drift as decisions are appended; if a jump lands wrong, re-run
`grep -n "^### [GTP]-0" docs/DECISIONS.md`.

**Precedence reminder:** newest ACTIVE `DECISIONS.md` entry beats everything. Within these,
a later entry that names an earlier one supersedes it — e.g. `T-025` supersedes `T-018` part (3),
`T-024` resolves `T-001` vs `T-015` in `T-015`'s favour, `G-009` narrows `G-002` condition 3.

| # | Decision | `DECISIONS.md` line |
|---|---|---:|
| `G-001` | "I cannot verify this" is itself a claim, and needs the same standard | 1250 |
| `G-002` | `cto` gains standing authority to apply production migrations; `019` is amended, not repealed | 2578 |
| `G-003` | Two vacant seats filled: `backend-owner` (KAN-70) and `flutter-feature-agent` (KAN-71) | 2627 |
| `G-004` | `macos/` is deleted after all; the PO overrides `T-012`'s "macOS stays" ruling | 2928 |
| `G-005` | `master-analyst` is a peer, not a checkpoint; stop routing tasks through it | 2958 |
| `G-006` | Claim a ticket before applying under it; collisions between same-role instances are structural, not case-by-case | 3078 |
| `G-007` | `android/**` was UNOWNED; `flutter-feature-agent` gets it, matching AS's `ios/**` pattern | 3339 |
| `G-008` | Route to the owner, not through a manager. `cto` coordinates; it does not relay | 3369 |
| `G-009` | `cto` may apply security-remediation data changes; `G-002` condition 3 is narrowed | 3415 |
| `T-001` | A view never re-implements RLS; `security_invoker = true` is the default | 552 |
| `T-002` | Anon reachability is an allowlist, proven by a catalogue test | 677 |
| `T-003` | The Play upload key is compromised; signing material never lives in the repo | 705 |
| `T-004` | Logout is a teardown contract, not a call to `signOut()` | 775 |
| `T-005` | Session tokens stay in SharedPreferences; the control is backup exclusion | 838 |
| `T-006` | No certificate pinning | 863 |
| `T-007` | Dead-but-wired code is deleted, not implemented | 882 |
| `T-008` | `Result` is the only convention; `Either` is converted on touch, never migrated | 943 |
| `T-009` | Edge functions verify authorization scope, not just authentication | 973 |
| `T-010` | Line count and colour literals are budgets, not defects; they do not gate launch | 1001 |
| `T-011` | Dabbler is not promotable today; three fixes change that | 1041 |
| `T-012` | The repo hygiene cleanup: what may go, what stays, and why `macos/` stays | 1129 |
| `T-013` | There are four design-system surfaces, not three; `lib/themes` is canonical for theming | 1380 |
| `T-014` | The first hire is a Flutter feature agent, because a promotion blocker is otherwise unownable | 1420 |
| `T-015` | Definer-funnel tables are protected by a revoked grant, not by an absent policy | 1329 |
| `T-016` | B5 is not "fill in four empty methods"; there is one emission site and two `AnalyticsService` classes | 1453 |
| `T-017` | `security_invoker` is half the fix; owner-equals-owner defeats RLS, and one view can send push | 1629 |
| `T-018` | The wide `anon` grant is inherited Supabase default privilege, so REVOKE alone reopens it | 1863 |
| `T-019` | `geometry_columns` is excluded from the revoke: we cannot alter it, and it is not ours | 1781 |
| `T-020` | A control's data is never readable by the people it constrains; and dead *data* is not dropped like dead *code* | 1916 |
| `T-021` | B1b moves ahead of B4; SEC-17 rides in B1a's migration | 2140 |
| `T-022` | SEC-17 is NOT folded into KAN-67: one is privilege-only, the other redefines a live view | 2058 |
| `T-023` | `v_needs_organiser` is an anon-writable path onto `auth.users`; it goes in the first revoke | 2301 |
| `T-024` | B1b is not a blanket invoker flip; `T-001` and `T-015` conflict, and `T-015` wins | 2438 |
| `T-025` | `FORCE ROW LEVEL SECURITY` remediates nothing here; `T-018` part (3) is superseded | 2500 |
| `T-026` | QA is required before promotion, not before every ticket; the missing piece is a mechanical gate, not a reviewer | 2655 |
| `T-027` | Five `anon`-readable views in `public` are intentionally public and are not findings | 2771 |
| `T-028` | `CONVENTIONS.md` §6b is backed: expected values ship as assertions, not as queries | 2821 |
| `T-029` | The six remaining anon-readable definer views split 3/3 on flip-vs-revoke; and my `v_mod_queue_open` base-table claim on KAN-56 was wrong | 2867 |
| `T-030` | A `service_role` policy is a contradiction: service_role bypasses RLS, so the fix is DROP, not rewrite | 2990 |
| `T-031` | A migration file is immutable once applied; corrections ship as new migrations | 3027 |
| `T-032` | KAN-33: adopt the CLI convention, but the baseline is the work and the rename is a consequence | 3117 |
| `T-033` | Amends `T-032` step 4: seven of the 43 files are not in the ledger, and one of them was never applied | 3239 |
| `T-034` | KAN-61's CI credential: a zero-grant Postgres login over the pooler, and why `cto` does not mint it | 3449 |
| `P-001` | The corpus, not the codebase, is the source for `BRIEF.md` | 394 |
| `P-002` | Four of the five open non-goal forks are settled by the corpus | 415 |
| `P-003` | The persona rule is about game type, never about access | 441 |
| `P-004` | Promotion is held until five blockers close | 462 |
| `P-005` | Corpus contradictions are logged, not silently resolved | 510 |
| `P-006` | The CPO takes code facts from the Analyst's record, never by measuring | 1220 |
| `P-007` | SEC-13 joins the promotion gate; the gate is the month, everything else waits | 1280 |
| `P-008` | The gate is the union of spend-risk and user-harm; B5 is larger, not smaller | 1505 |
| `P-009` | B1 is a CIA defect, not a read leak; split it so the certain half can move | 1550 |
| `P-010` | The one-month plan, and KAN-57 goes on the gate unless the keystore was never exposed | 1592 |
| `P-011` | B1a is first on the gate, ahead of the hire; and it is now a live destructive exposure | 1715 |
| `P-012` | B10 demoted from blocker to pre-promotion requirement; the password is burned everywhere | 1819 |
| `P-013` | B10 comes off the gate entirely; `space_slot_holds` is kept as deferred product | 1978 |
| `P-014` | B1a is schema-level and unowned; the sequencing gain is withdrawn | 2021 |
| `P-015` | Authoring B1a is also blocked, but it is an unfilled seat, not a prohibition | 2198 |
| `P-016` | B1b ahead of B4; SEC-17 stays out of B1a; the sequence has three tracks, not one | 2253 |
| `P-017` | `v_needs_organiser` leads the REVOKE; and the wording is bounded deliberately | 2354 |
| `P-018` | SEC-17's surface is three views and two base tables; the free-migration lead is dead | 2397 |
| `P-019` | A comment outlives the persona that wrote it: degrade the author, never hide the comment | 2711 |


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

**SUPERSEDED 2026-08-29 — do not quote the "23 of 25 UNOWNED" figure.** Two seats were filled on
2026-08-28 (`G-003`, KAN-70/71): **`backend-owner`** takes all Supabase outside notifications, and
**`flutter-feature-agent`** takes Dart outside notifications — the 23 slices, `lib/core/**`,
`lib/data/**` and the design system — plus **`android/**`** (`G-007`). **9 agents now, not 7.**
Routing rule `G-008`: **go to the owner directly; `cto` coordinates, it does not relay.**
The original text, for the shape of what was unowned: **FOUR design-system surfaces, not three — corrected by cto 2026-08-28.** My earlier
"three" omitted the only one that is load-bearing at runtime:
`lib/themes/` (4 files, 39 import sites) — **`main.dart:13` imports it, `:156` calls
`AppTheme.initialize()`, `:265-266` hand `AppTheme.lightTheme/darkTheme` to `MaterialApp`.
Every colour a user sees comes from here.** Verified independently 2026-08-28.
Also: `lib/core/design_system/` (22 files, 74 import sites) · `lib/design_system/` (11 files,
**77 import sites** — the most, while calling itself "temporary") · `lib/core/theme/` (2
files, 2 sites) · `dabbler_design_system` (git dep, 0 imports).
**cto ruling T-013:** `lib/themes/AppTheme` canonical for theming, `lib/core/design_system/`
canonical for components, `lib/design_system/` absorbed on touch, `dabbler_design_system`
removed now. **Import count measures entrenchment, not intent.**

Source: `CONTRACT.md` §3 · `AGENTS.md` · `ARCHITECTURE.md` §2

## 11. OPEN — blocking

**Live security — updated 2026-08-29.** The §2a read leaks are **closed**: KAN-36/37 (notification
views), KAN-38b (`v_comments`), KAN-56 (`v_mod_queue_open`, `v_safety_overview`, `v_circle_feed`).
**Still open and higher than any of those:** **SEC-16/SEC-15a** — unauthenticated *destructive write*
through 7 definer views, and the inherited `pg_default_acl` grant that reopens it (KAN-67, `T-018`);
**SEC-13** push authorization (KAN-59); **SEC-17** `auth.users` uids in anon projections. Also open:
KAN-26 (12 unexamined views). **Launch gate still fails** — `MANIFESTO.md` §4.4, `P-004`/`P-007`.

**Newly open, code side:** **NAV-01a** (`notifications_screen_v2.dart:518`) — a dead-end tap on a
live bottom-nav screen. Owner: `flutter-feature-agent`. Not yet ticketed.

**PO decisions:** KAN-29 rewards · KAN-30 clean-arch · KAN-16 roster · KAN-22 the 62 CUTs ·
KAN-23 `BRIEF.md`'s 7 questions · the two contradictory flags.

**Not mine (read-only):** KAN-27/28/31/32/34 are code changes — need a Flutter agent.
KAN-35 needs Cloudflare dashboard access.

## 10z. VIEW EXPOSURE — FIXED DEFINITION, 2026-09-01. Quote this, not 19/21/12/6.

**The only definition that survives: does the view return rows to `anon`, measured, with a control.**
Predicate text-matching (`auth.uid()` / `is_admin` in the viewdef) is the instrument that certified
two leaking views safe in §2b. **Do not re-derive this from a viewdef grep.**

| Measure | Value |
|---|---:|
| Views in `public` | 71 |
| **anon-readable** | **41** (my earlier 45 is superseded) |
| anon-writable | **2** — `geometry_columns`, `geography_columns`, both `supabase_admin`-owned PostGIS |
| Live anon write paths (definer + auto-updatable + grant) | **1** — PostGIS, unalterable, **accepted not open** (`T-015`) |
| definer **and** anon-readable | **12** |
| **of those, actually return rows to `anon`** | **2** |

**The 2:** `v_game_card` **217 rows** (was 216 — a new game, so the probe is live) and
`v_meetup_list` **1**. Both already filed as **SEC-15 (MED)** + **SEC-17 (HIGH)**, both
`listing_visibility='public'`, both pending a PO decision. **No new exposure.**
The other 7 probed return **0**; `v_space_slots_today` errors (**BUG-05**), not a security item.

**"21 lack a predicate" does not reproduce and should not be quoted as a trend** — nor should
my old 19. Different instruments, different populations, neither measured exposure.

## 11. INVENTORY — run 3, 2026-08-29 (supersedes the run-2 figures below)

| Fact | Value | Source |
|---|---|---|
| Screen/page/view classes | **102** — 73 ROUTED · 3 REACHED-BY-PUSH · 4 ORPHAN · 6 TRANSITIVELY DEAD · 16 private | `PROJECT_STATE.md` §14d |
| **The run-2 "101"** | **Superseded.** Different matcher, definition never recorded — not comparable, do not reconcile the two | §14d |
| Import-reachable files | **556 of 776** non-generated `lib/**` | §14d |
| Declared `GoRoute`s | 90 | §14e |
| Nav call sites outside the router | **186** — 90 `go`, 84 `push`, 12 `pushNamed`, **0** `goNamed` | §14e |
| Declared but never navigated | **31** — URL-reachable on web, so discovery-bounded | §14e |
| **Genuine dead-end taps** | **1** — NAV-01a, see below. **Corrected 2026-08-29: was 2, and both of those were wrong** | §14e |
| Unused constants | `RoutePaths` 26 of 94 · `RouteNames` 58 of 110 | §14e |
| Bottom nav | **4 shell branches, 3 rendered.** `community` has no item | §14e |
| Slice verdicts | **12 SHIPPED · 6 PARTIAL · 1 SCAFFOLD · 6 DEAD** — totals unchanged, but on 2026-08-29 `search` returned to SHIPPED and `notifications` took its PARTIAL slot | §20b |

**The one dead-end tap — lands on GoRouter's error page:**
- **NAV-01a** `notifications_screen_v2.dart:518` → `context.push('/games/<id>')`. **No route matches
  `/games/:id`**; the real one is `/sports/games/:gameId` (`app_router.dart:829`). It is the **only**
  remaining `/games/` literal in `lib/`. The screen is **live and bottom-nav reachable**, so every
  user can hit it. Fix: `RoutePaths.gameDetail(activity.subjectId)`.

**BOTH ORIGINAL NAV ROWS ARE WITHDRAWN — corrected 2026-08-29. Never quote them again.**
- ~~NAV-01~~ `social_search_screen.dart:1811` actually reads
  `context.push(RoutePaths.gameDetail(game.id))` and **resolves correctly**. Not a defect.
- ~~NAV-02~~ `onboarding_sports_screen.dart:194` actually reads
  `context.go(RoutePaths.createUserInfo)` — a declared route (`app_router.dart:186`).
  `onboardingBasicInfo` appears **nowhere in `lib/` outside `route_constants.dart:45,168`** and
  left that file at `2523def`. **And it was never launch-critical:** `onboardingSports` →
  `onboardingPreferences` → `onboardingPrivacy` → `onboardingCompletion` is a **closed four-screen
  cluster whose only inbound edges come from inside itself**; the sole navigator to
  `onboardingSports` is `onboarding_preferences_screen.dart:171,298`, in the same cluster. The live
  chain runs `intent_selection` → `interests_selection` → `onboardingPrimarySport` and never enters
  it. Raised by `flutter-feature-agent-5` and `task-auditor-11`, verified independently here.

**Why both were wrong, and the rule that follows.** The constant-name match and the `file:line`
came from **separate passes**, so the cited line was never re-read. **Resolve the literal and
re-read the cited line in the same pass — a `file:line` you did not open is not evidence.** Same
class as the 14 documented false positives, but failing the other way: inventing defects rather
than missing them.

**Do not re-derive the dead-end list by comparing constant names.** That over-reports by 14:
path-builder functions (`RoutePaths.gameDetail(id)` is a function, not a constant), nested child
routes (`'create'` under `/venue-submissions`), and interpolated paths. **Resolve to literal path
strings and match against declared patterns, including children.**

**`docs/INDEX.md` does not exist and will not be created — PO decision 2026-08-29, it stays here.**
KAN-44's acceptance criterion cites the wrong path; read it as citing this file.

**SEC-02/SEC-03 RESOLVED 2026-08-29** (KAN-56): `v_mod_queue_open` + `v_safety_overview` raise
`42501 permission denied` to `anon` (revoked, not flipped — both `moderation_reports` policies deny
SELECT, so a flip would have blanked the admin queue); `v_circle_feed` 0 rows, was 6.
Controls held: `v_game_card` 216, `v_comments` 66.

**Re-verified 2026-08-30 (KAN-42), and the closure is stronger than recorded.** `authenticated`
*does* still hold SELECT on both views — that is not a gap, because **the gate is inside the view
body**: `v_mod_queue_open` ends `AND is_admin(auth.uid())`, `v_safety_overview` is
`WHERE is_admin(auth.uid())`. A logged-in non-admin gets **0 rows**, not a leak. So the fix was
revoke-*and*-predicate, not revoke alone. **If asked "is the moderation queue exposed?" the answer
is no, on two independent grounds.** `PROJECT_STATE.md` carried SEC-03/SEC-04 as live
CRITICAL/HIGH for four days after they closed — now tagged RESOLVED.

**Admin/moderation flow hops** (`PROJECT_STATE.md` §15b flows 19-21, 2026-08-30): queue read
`moderation_queue_screen.dart:18` → `moderation_service.dart:818` `fetchOpenModQueue()` →
`v_mod_queue_open` `:822-825`; safety overview `safety_overview_screen.dart:14` →
`moderation_service.dart:858` → `v_safety_overview` `:862-866`; writes
`moderation_queue_screen.dart:423`/`:511` → `moderation_service.dart:727`/`:768` → RPCs
`admin_resolve_report` `:738` · `admin_take_action` `:782`. **The `is_admin` client check is at
`moderation_queue_screen.dart:24`** — *not* `:22`, which was wrong in four places — **and there is
also a route-level guard** at `app_router.dart:1673` (queue) and `:1699` (safety overview).
**Claim to never repeat: "no `.rpc(` call site exists under `lib/features/admin/**`." It is false**
— `:24` is one. That sentence cost KAN-42 two review rounds.

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

## 11e. VIEW CENSUS — corrected instrument, 2026-08-28. USE THIS QUERY, NOT THE OLD ONE.

**`security_invoker` must be parsed, not string-matched.** Postgres accepts `on`/`true`/`yes`/`1`.
My old test `option_value='true'` read four genuinely-fixed views as still definer — **it reports an
applied fix as unapplied.** Correct form:

```sql
coalesce((select option_value::boolean from pg_options_to_table(c.reloptions)
          where option_name='security_invoker'), false)
```

Also wrong, same query: `case when reloptions is null then 'DEFINER' else 'invoker'` — any reloption
(e.g. `security_barrier`) reads as invoker.

**Census as of 2026-08-28, post-KAN-38b (final for the day):** 71 views · **28 invoker** · 43 definer ·
**45 anon-readable**. Invoker = 6 flipped today (`=on`) + 22 pre-existing (`=true`).
**"6 postgres-owned invoker views" is the count flipped today, NOT the population — the population is 28.**
The 2026-08-27 figures (22 invoker / 49 definer / 48 readable) were correct then and are superseded.

**The 45 anon-readable views are NOT 45 findings** — five are confirmed intentional (`T-027`):
`username_registry_public` (pre-session signup check) · `geometry_columns` + `geography_columns`
(supabase_admin-owned, unalterable) · `v_potential_vibes_default` + `v_recreate_quickpicks`
(function-backed — `security_invoker` is a **no-op** when the `FROM` is a set-returning function).
Both function-backed ones probed as `anon`: **0 rows each**. See `audit-false-positives.md`.

**KAN-38b:** `v_comments`/`v_post_comments` 67 → **66** to `anon`, 18 null-author rows preserved
(LEFT JOIN, not INNER — `profiles.is_active` is the persona switch, not a ban flag). 1 real leak closed.

**SEC-01 RESOLVED** — `v_notifications_feed` and `v_notifications_ranked` return **0 rows** to `anon`
(were 611 across 51 users). Controls unchanged: `v_meetup_list` 1, `v_game_card` 216 — no cascade.
**KAN-67's write posture survived the `CREATE OR REPLACE VIEW`** — 0 postgres-owned views grant write.

**KAN-38 is NOT resolved:** `v_comments`/`v_post_comments` slice rejected (invoker flip drops 19 of 67
anon rows, 18 via `profiles.is_active=false` on an INNER JOIN — only 1 is the leak; blocked on `cpo`) ·
five intentionally-public views need `T-027` · `v_space_slots_today` broken independent of security (BUG-05).

## 11c. SEC-16 — **RESOLVED (PARTIAL) 2026-08-28**, migration `20260828160122`

Verified post-state: anon/auth write on postgres-owned views **0** · all 7 paths false on INS/UPD/DEL ·
**anon_readable_views 48, UNCHANGED** (no read path moved) · `pg_default_acl` postgres grantor `anon=rxtm`.
**Exercised on `v_notifications_feed`** — a real INSERT as `anon` was refused with `insufficient_privilege`
(KAN-67 comment 10100). **Mechanism-verified on the other six**, which must NOT be exercised:
`v_needs_organiser` writes `auth.users`; the notification views fire push over `pg_net`, unrollbackable.
**NO QA GATE EXISTS.** Nothing runs `flutter analyze` or `flutter test` — not `deploy-web.yml`,
not `cloudflare-build.sh`; `run_integration_tests.sh` is invoked by nothing. Never call a promotion
QA-verified until a QA seat exists and KAN-72 lands (**`T-026`** — `cto`'s ruling, `DECISIONS.md:2648`.
**Not G-003** (that is the hiring decision) and **not G-004** (never existed past a transient renumber).
**NOT closed, do not claim otherwise:** 184/184 base tables still grant anon+auth write ·
`supabase_admin` default-privilege rule still `arwdDxtm` (not executable — no membership) ·
`geography_columns`/`geometry_columns` still anon-writable (PostGIS, by design, decision 021) ·
TRIGGER/REFERENCES still granted on the 7.

Original finding, for the mechanism:

## 11c. SEC-16 — the single highest item on the board (2026-08-28)

**Unauthenticated INSERT into `notifications`, delivered as push to a chosen user.**
`v_notifications_feed` `is_insertable_into=YES` + `anon` holds INSERT · the three NOT NULL/no-default
columns (`to_user_id`, `kind_key`, `title`) are all in the view · `n_block_insert WITH CHECK (false)`
exists but **never runs** — view and table both owned by `postgres`, view is not `security_invoker`,
`relforcerowsecurity = false` · `trg_push_on_notification_insert` (`tgenabled='O'`) posts attacker-controlled
`title`/`body` verbatim to `send-push-notification` on the `x-trigger-secret` trusted path ·
`anon` reads `notification_kinds`, 23 of 29 active kinds carry `push` in `default_channels`.

**Fix (B1a):** `REVOKE` the DML grants **and** `ALTER TABLE public.notifications FORCE ROW LEVEL SECURITY`.
FORCE RLS is the load-bearing half. **Blocked on the `CONTRACT.md` §11 ownership decision.**

**SUPERSEDED 2026-08-28: not one view — 7 app views + `geometry_columns` (PostGIS artefact).**
Of 71 views: **70 grant anon write · 19 auto-updatable · all 19 granted · 8 definer+updatable+granted.**
All 7 app base tables have `relforcerowsecurity=false`. **`v_notifications_ranked` is a 2nd path to `notifications`.**
**`v_needs_organiser` targets `auth.users`** (`profiles` only in the NOT EXISTS) — established 2026-08-28.
Bypasses via **`rolbypassrls` on `postgres`**, not owner-equals-owner; **FORCE RLS does NOT close it**, only the revoke.
`auth.users`: RLS on, **zero policies** (deny-all), `id` the only NOT NULL/no-default col — which the view projects.
**UNESTABLISHED and must stay so:** whether the row inserts, and whether it is useful. **Never call it account creation.**
Not inert though — an insert fires `trg_create_default_privacy_settings` + `trg_strip_signup_password`.
**SEC-17 call sites: 3, not 6** — 2 of the 6 query the `games` table, not the view. One filter site
(`game_history_providers.dart:79-80`) = silently wrong game history. Identity cols: host_user_id 23 ·
creator_user_id 6 · organizer_id 4 · **creator_profile_id 1** (the migration target).
**Root cause `pg_default_acl`:** `ALTER DEFAULT PRIVILEGES` in `public` from postgres AND supabase_admin
grants anon/authenticated `arwdDxtm` on every new relation — Supabase stock config, never turned off.
**A REVOKE-only fix regresses on the next CREATE VIEW and still passes its own check.**
**Fix = REVOKE + `ALTER DEFAULT PRIVILEGES … REVOKE`. TWO parts — FORCE RLS was struck 2026-08-28.**
All 7 app views are owned by `postgres`, which has `rolbypassrls=true`, checked ahead of the owner/FORCE
logic — **FORCE RLS remediates nothing on any of them.** Demo: `sport_profiles` has FORCE on, owner postgres,
138 visible vs 131 admitted. **Do not cite `relforcerowsecurity=false` as the cause** — it is accurate and
is not the mechanism.
`pg_has_role('postgres','supabase_admin','MEMBER')=false` — the supabase_admin half of the default-privileges
revoke is **not executable** from this project's roles; needs a PO decision.
**All 184 base tables also grant anon/authenticated write** — out of KAN-67 scope; "KAN-67 applied" does NOT
close the wide grant. Low blast radius:
nothing in the app writes through these views.
**Never attempted, by anyone.** Catalogue-verified only. `SCHEMA.md` §11 has the reproduction.

## 11d. SEC-17 — auth.users UUIDs readable with no account (2026-08-28)

**61 of 240 real `auth.users` UUIDs — 25% of the user base — readable by `anon`.**
Measured as `anon`, distinct non-null uids: `v_notifications_feed` / `v_notifications_ranked` **51** (611 rows) ·
`v_game_card` **25** (216 rows) · `v_circle_feed` **1** (6 rows) · `v_meetup_list` **1** (1 row). Union **61**.
All 216 `v_game_card` uids confirmed present in `auth.users`.
Eight further anon-granted views carry an `auth.users`-shaped uuid column but return **0 rows** today.

**HIGH, and not a PO question** — drop the uid from every anon-reachable projection; keep `creator_profile_id`
and display fields. Bundle with SEC-16's migration. **SEC-15 stays MED** for the discovery exposure
(display name, avatar, `start_at`, venue name; rows the organiser marked public; no coordinates or contact details).

**Rule (`cto`):** severity attaches to the **column**, not the view. A view can be correctly public and still
carry one field that has no business in it.

## 11b. CORRECTED FACTS — do not quote the old version

| Was recorded | Truth (verified 2026-08-27) |
|---|---|
| `/settings/language` renders "Coming Soon" | **False.** `:590` is `/language_selection`, an orphan. `/settings/language` is at `:1287` → real 226-line `LanguageSelectionScreen`. **Language switching works** |
| **WIRE-09: "all 7 placeholder routes are unreachable"** (my own 1d correction) | **False, and it was wrong in the direction of relief.** **6 are orphans; `socialChat` is reachable.** `user_profile_screen.dart:1094` Message button (no flag, no condition) → `:1475` `context.push('${RoutePaths.socialChat}/$userId')` → `app_router.dart:1607` route → guard `:1611` `FeatureFlags.messaging`, which is **`true`** → `:1617` "Coming Soon". **INV-01 above is correct — do not retire it on the blanket claim.** Also: **no placeholder route is behind a closed flag** — `socialNotifications`/`socialMessages` carry guards but both flags are `true`; the other four have no guard. `PROJECT_STATE.md` WIRE-09, run 1f |
| 233 hardcoded colours | **317 across 43 files** (old filter unrecorded) |
| 25 `UnimplementedError` in settings repo | **24** — a doc comment contained the word `throw` |
| "no schema history" | **237 applied migrations** |
| 49 views / 25 definer / 8 exposed | **71 / 49 / 19** |
| **"8 definer views are safe by `auth.uid()` predicate"** (mine, `SCHEMA.md` §2b) | **False for 2 of the 8.** Probed as `anon` 2026-08-28: `v_game_card` **216 rows**, `v_meetup_list` **1 row**, other six 0. Filter is `listing_visibility='public'`, not `auth.uid()`. **Position was assigned by reading the definition, never by querying.** Not the §2a leak class — rows are all public — but the columns include `creator_user_id`, username, avatar, start time, venue → **SEC-15 (MED)** |
| **"27 anon-readable definer views"** (`cto`, `T-001`) | **A privilege count, not an exposure count.** 27 = definer AND `anon` holds SELECT. 6 of the 27 return zero rows. **21 return data**, of which 19 are the §2a leaks and 2 are SEC-15. Do not quote 27 as a leak figure |
| **`public.pg_stat_statements_info` is a dangling reference** (`cto`) | **False.** It lives in the `extensions` schema, which is where the extension installs it. `to_regclass('public.…')` is `NULL` by design, and **zero** functions or views in `public` reference it. Not a finding |

## 11c. REPO HYGIENE — run 3, 2026-08-28, commit `1b83967`

Full table: `docs/PROJECT_STATE.md` §21. Answer "can we delete X" from §21b/21e, do not re-scan.

| Fact | Value | Source | Measured |
|---|---|---|---|
| Repo hygiene — files proposed for removal | 749 files / ~6.6 MB, 73 tracked | `docs/PROJECT_STATE.md` §21h | 2026-08-28 |
| Unused platform folders (macos/windows/linux) | 51 tracked files, 5.0 MB, no build references them. **All three deleted — `macos/` per G-004 (PO override of `T-012`); deletion staged, folder absent from disk.** `flutter build macos` fails until `flutter create --platforms=macos .` regenerates it — accepted | `docs/PROJECT_STATE.md` §21d | 2026-08-29 |
| Root regenerable artifacts | 7 tracked, 1,053,654 B | `docs/PROJECT_STATE.md` §21b | 2026-08-28 |
| Fate of the 5 root .md docs | 3 MOVE, 2 DELETE (per-doc reasoning) | `docs/PROJECT_STATE.md` §21c | 2026-08-28 |
| Dead onboarding services (HYG-01) | 320 LOC, 0 importers | `docs/PROJECT_STATE.md` §21f | 2026-08-28 |
| `packages/` is load-bearing, not cruft | dependency_overrides path deps | `pubspec.yaml:167-180`, §21g | 2026-08-28 |

**Do not re-flag** (also in [[audit-false-positives]]): `packages/` is a load-bearing `dependency_overrides` path dep; the 5 `post_comments_*_fkey` strings are PostgREST constraint hints that resolve correctly (constraint names survived the table rename, verified via `pg_constraint`).

**6 items blocked on the PO** (was 7 — **`macos/` resolved 2026-08-28 by G-004: delete, PO overrode `T-012`**): root PDF, untracked `upload_certificate.pem`, 4 zero-ref `scripts/`, `App screenshot/`, 4 zero-ref `lib/design_system/*.md`. Listed in §21b/21e.

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
