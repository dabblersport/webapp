---
name: load-bearing-measurements
description: Verified numbers from the KAN-39 assessment with the exact command that produced each — plus which widely-quoted figures are wrong.
metadata:
  type: project
---

Measured 2026-08-27 on `Canary`. A number without its command is a claim (decision `020`).

```bash
# 143 files over 500 lines (Analyst's 140 = same, additionally excluding lib/l10n/ — their choice is better)
find lib -name '*.dart' ! -name '*.g.dart' ! -name '*.freezed.dart' -exec wc -l {} + | awk '$1>500 && $2!="total"' | wc -l

# 31 Either files / 124 Result files — MUST grep the symbol, not the import.
# Grepping "fpdart" returns 17 and is WRONG: 13 profile files use a hand-written
# Either in lib/core/utils/either.dart that is not fpdart.
grep -rlE "\b(Either|Left|Right)<" lib --include='*.dart' | wc -l
grep -rlE "\bResult<" lib --include='*.dart' | wc -l

# 317 hardcoded colours across 43 files. "233" is NOT reproducible; "866" double-counts
# lib/design_system/tokens/ and lib/core/config/design_system/ — palette definitions.
grep -rEo "Color\(0x[0-9a-fA-F]{8}\)" lib --include='*.dart' \
  | grep -vE "^lib/(themes/|core/theme/|core/design_system/|design_system/|core/config/design_system/)" | wc -l
```

- `flutter analyze` -> **0 errors**, 55 warnings, 102 infos (44 `empty_catches`, 15 `use_build_context_synchronously`)
- `flutter test` -> **66 pass**, 5 test files
- Anon leak: `SET LOCAL ROLE anon; SELECT count(*) FROM public.v_notifications_feed;` -> 609, 49 distinct `to_user_id`; base table 0
- HTTP proof: `curl -H "apikey: $ANON" -H "Prefer: count=exact" .../rest/v1/v_notifications_feed` -> `content-range: 0-2/609`
- Zero raw `MaterialPage` in `lib/` (decision `010` held). 13 `MaterialPageRoute` across 8 files is a *different* violation.

**Why:** the advisor undercounted the definer views by more than half, and three quoted figures turned out unreproducible.
**How to apply:** re-run before leaning on any of these; quote the command alongside the number.

**Postgres catalogue trap (2026-08-28):** `pg_depend` does **not** track table references inside
plpgsql function bodies. Asking it "which definer functions use this table" returns **0 for
everything** and looks like a finding. Search `pg_proc.prosrc` instead:
```sql
SELECT count(*) FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
WHERE n.nspname='public' AND p.prosecdef AND p.prosrc ~* ('\m'||<table>||'\M');
-- games -> 37, squad_members -> 9, moderation_tickets -> 2
```
This nearly produced a wrong ruling on the 30 RLS-on/zero-policy tables.

**Design-system surfaces are four, not three (2026-08-28):** `lib/core/design_system/` (22
files/74 imports) · `lib/design_system/` (11/77, self-described temporary) · **`lib/themes/`
(4/39 — what `main.dart:156,265-266` actually hands to `MaterialApp`)** · `lib/core/theme/`
(2/2) · `dabbler_design_system` git dep (0 imports).


**View census — 71 total / 49 definer / 27 anon-GRANTED / 21 anon-EXPOSED (2026-08-28).**
**Use 21 for "what leaks".** A **privilege is not an exposure**: 6 of the 27 return zero rows.
27 = Analyst's 19 leaks + 2 (`v_game_card` 216 rows, `v_meetup_list` 1, filtering
`listing_visibility='public'`) + 6 empty. I wrongly "corrected" the Analyst's 19 with my 27 —
theirs was an *exposure* count, mine a `has_table_privilege` count. **Reconciling two numbers
requires checking they measure the same thing; comparing two of my own definitions is not that
check.** Also 30 tables have RLS on with zero policies.
```sql
-- definer: reloptions lacking security_invoker=true; add has_table_privilege('anon',oid,'SELECT') for the 27
-- exposure: probe as anon with `select count(*) from public.games` as control (control must return 0)
```
`pg_stat_statements_info` = **false positive, mine**: lives in `extensions` schema (normal for
Supabase), 0 refs from `public`. Not the `v_space_slots_today` class. Never re-flag.

**"Built, never connected" is the pattern the line counts hide (2026-08-28).** Verified by
grepping the import path *from outside the directory*, plus `providers.dart`:
- `lib/features/profile/services/data_export_service.dart` — 2,092 LOC, **zero importers**
- `lib/core/analytics/` — helpers 471 + storage 421 + widgets, **zero importers outside itself**
- **Two classes named `AnalyticsService`**: `core/services/analytics/analytics_service.dart` and
  `core/services/cache_service.dart:78` — the latter is what `analyticsServiceProvider` exposes
- Exactly **one** analytics emission site in the app: `lib/main.dart:78` (`flags_snapshot`)
Two of the CPO's four blockers (B2, B5) are this same defect. See `T-016`.

See [[confirmed-false-positives]], [[kan39-launch-readiness]], [[verification-lessons]].
**Logout paths — four stacks, one live seam (2026-08-28).** `grep -rn "signOut()" lib` shows 4
stacks and one (`supabase_auth_datasource.dart:71`) bypasses `AuthService` via
`client.auth.signOut()`. **It is dead:** `grep -rn "logoutUseCaseProvider" lib` -> declared at
`auth_providers.dart:274`, **zero consumers**. Live exits all funnel through
`AuthService().signOut()`. So `T-004`'s seam is correct — but 19 files write on-device storage
(`grep -rln "SharedPreferences\|Hive\.\|FlutterSecureStorage" lib`), not the 3 that `T-004`
names. Classifying the 19 is the real work in KAN-58.

**Owner-equals-owner defeats RLS (2026-08-28) — the trap `security_invoker` does NOT cover.**
`notifications` has a correct `n_block_insert` (`FOR INSERT WITH CHECK (false)`) and it is bypassed:
`v_notifications_feed` is SECURITY DEFINER owned by `postgres`, the base table is owned by
`postgres`, and `relforcerowsecurity = false`. **Postgres skips RLS for a table's owner unless FORCE
ROW LEVEL SECURITY is set.** Chain: view `is_insertable_into=YES` (all NOT NULL/no-default cols —
to_user_id, kind_key, title — exposed) -> `trg_push_on_notification_insert` (enabled) -> posts
NEW.title/NEW.body verbatim to `send-push-notification` with `x-trigger-secret`, the trusted-server
path that skips JWT + relationship checks. `anon` reads `notification_kinds` (23/29 push-enabled).
Net: unauthenticated arbitrary first-party push. Preconditions verified, **insert never attempted**
(019). Only `v_notifications_feed` is writable — `v_mod_queue_open`/`v_safety_overview` are
`is_insertable_into=NO` (aggregates), confidentiality only. See `T-017`.

```sql
SELECT relowner::regrole, relrowsecurity, relforcerowsecurity FROM pg_class ...;
SELECT is_insertable_into FROM information_schema.views WHERE table_name='...';
```
**Always check grants + relforcerowsecurity, not just invoker status.**

**The wide anon grant is INHERITED Supabase default privilege (2026-08-28) — REVOKE alone reopens it.**
`SELECT * FROM pg_default_acl;` -> `ALTER DEFAULT PRIVILEGES` in `public`, from **both** `postgres`
and `supabase_admin`, grants `anon`+`authenticated` **`arwdDxtm`** (full set) on every relation
created. Stock Supabase, not authored by Dabbler. **Every new view re-acquires it**, so a
REVOKE-only migration passes verification and silently regresses. Fix must include
`ALTER DEFAULT PRIVILEGES ... REVOKE`.
Population: **70/71 views grant anon write · 19 auto-updatable · 8 definer+auto-updatable+writable**
(= live unauth write paths). The 8: v_notifications_feed, v_notifications_ranked, v_hidden_list,
v_my_drafts, v_needs_organiser, v_posts_time_preview, v_user_reputation, **geometry_columns
(PostGIS false positive, decision 021)** -> 7 app views.
**Consequence: B1a is schema-level and CANNOT be split by view ownership** — no per-view REVOKE
fixes a schema-wide default. Therefore UNOWNED, therefore hard-blocked on the backend hire.
**Counter-intuitive and worth repeating: revoking write cannot blank a screen** (nothing writes
through these views), so B1a is the *safest* item to apply despite being the most severe — the
opposite of the T-001 read sweep. See `T-018`.

**B1a's unblocker is the PO, not the hire (2026-08-28).** `019` reserves *applying* to production to
the PO regardless of who is hired; **authoring an unapplied migration file is not the contended
permission.** So schema fixes route: agent authors -> PO applies, needing no CONTRACT amendment. I
spent a round treating the hire as B1a's unblocker; `master-analyst`'s "option C" is correct.
**FORCE RLS is the load-bearing half** of that migration — REVOKE alone leaves the same shape one
careless `GRANT` from reopening, and `anon` already holds a direct INSERT grant on `notifications`
(blocked by RLS today) that becomes a second hole the moment someone adds FORCE RLS and stops there.
Trigger gating on `notification_settings` **gates reliability, not access** — `_has_settings` false
(likely most users) means no gating at all; never read it as a mitigation.

**61 of 240 auth.users UUIDs are anon-readable — 25% of the user base (master-analyst, 2026-08-28).**
Swept every anon-granted definer view for an `auth.users`-shaped uuid, then **probed each as anon**
(a column list is not an exposure). v_notifications_feed/_ranked 51 uids/611 rows · v_game_card 25/216
· v_circle_feed 1/6 · v_meetup_list 1/1 -> union **61**. Eight more views carry the column and return
0 rows today: **dormant, not clean**. Filed SEC-17 (HIGH, `creator_user_id`, not a PO question —
`v_game_card` already carries `creator_profile_id` separately, so the internal key sits next to a
public handle and buys nothing) and SEC-15 (MED, discovery exposure, PO decision).
**This is the measured user-impact number for B1b** — the read sweep previously had none.

**`rolbypassrls` is the SECOND way RLS silently doesn't run (2026-08-28) — FORCE RLS does not stop it.**
`v_needs_organiser` = `SELECT id AS user_id FROM auth.users WHERE NOT EXISTS(SELECT 1 FROM profiles …)`
— **`profiles` is only in the subquery; the single FROM relation is `auth.users`.** Insertable=YES,
anon has INSERT, definer owned by `postgres`; `postgres` has INSERT on auth.users and
**`rolbypassrls = true`**; auth.users' only NOT NULL/no-default col is `id`, which the view projects.
Owner differs here (`supabase_auth_admin`), so T-017's owner-equals-owner argument fails — BYPASSRLS
reaches the same place. **Check BOTH `relforcerowsecurity` AND `pg_roles.rolbypassrls` of the
executing role.** Only the REVOKE closes this; FORCE RLS would not.
**UNESTABLISHED, never state as fact:** whether auth.users' constraints/triggers admit an id-only row,
and whether such a row is useful. **Never call it account creation/takeover** — the claim is "an
unauthenticated write path onto the identity table exists". See `T-023`.
Also: `v_notifications_ranked` and `v_notifications_feed` both resolve to `notifications` -> **two**
entries to `trg_push_on_notification_insert`; revoking one alone leaves SEC-16 open.

**Two hires, not one (CPO, 2026-08-28):** backend owner unblocks B1a/B1b/the 30 tables; Flutter agent
unblocks B2/B4/B5/KAN-58 teardown. I had fused them. Also: `CONTRACT.md` §3 blocks non-notification
migrations at **authoring**, not just applying — my "option C" premise was wrong; read the row, don't
reason from the principle. The seat is *vacant-pending-hire*, not a contested permission.

**SEC-17 / `creator_user_id` — sizing settled (2026-08-28).** **11 distinct lines**: 6 snake-case JSON
keys + 6 camelCase `creatorUserId` uses − 1 overlap (`game_view_controller.dart:212` contains both).
Failure taxonomy if dropped naively: **3 query errors** (filters) · **2 silent identity substitutions**
· **1 silently dead navigation** (`game_detail_screen.dart:648-653`, uid is a route param, null-guarded
at :650 so the organiser tap just stops working). Five of six fail *silently* — the wrong direction.
**`games.host_user_id` DOES NOT EXIST** (0 rows in information_schema for the whole `public` schema;
the comment at `game_history_providers.dart:49` is correct). So `game_model.dart:81`'s
`creator_user_id ?? host_user_id ?? ''` resolves to **`''`**, not null — empty string passes null
checks. **No free migration path.** `creator_profile_id` DOES exist on games, meetups, v_game_card,
v_meetup_list, v_my_games — target available everywhere. **Surface is wider than v_game_card:** 3
views + 2 base tables carry `creator_user_id`.
