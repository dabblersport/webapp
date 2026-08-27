# docs/MANIFESTO.md — The Dabbler Manifesto

**Owner:** master-analyst (write) · all agents (read)
**Last updated:** 2026-08-26
**Purpose:** The non-negotiables. What is always true about how this app is built,
regardless of who is building it or which feature they are in.

This is the highest-authority document about *how we work*. `DECISIONS.md` overrides it
only via a dated, numbered decision.

---

## 0. RULES OF ENGAGEMENT

Read before writing any code. Numbered so they can be cited.

**R1 — Never throw across a layer boundary.** Every data operation returns
`Result<T, Failure>`. A repository that throws is a bug, not a style preference.

**R2 — Reachability is what "done" means.** A screen no route reaches is not shipped,
whatever its line count. Before claiming a feature works, trace it: route →
provider → repository → query.

**R3 — Never hardcode a Supabase identifier.** Table, bucket, RPC and sport-constraint
names come from `lib/core/config/supabase_config.dart`. Add a constant; never inline a
string. Never change an existing constant's *value* without a `DECISIONS.md` entry.

**R4 — Never hardcode a colour.** Use `Theme.of(context).colorScheme` or the `AppTheme`
category extensions. There are five palettes × two modes; a literal is right in one of ten
states and silently wrong in nine.

**R5 — Never use raw `MaterialPage`.** Routes use the wrappers in
`lib/utils/transitions/page_transitions.dart`.

**R6 — Trust RLS for authorization, and verify RLS exists.** The client does not perform
its own permission checks. But "we have RLS" is not a posture — before relying on it,
confirm the table has policies and that no `SECURITY DEFINER` view routes around them.

**R7 — Write only what you own.** `CONTRACT.md` is the matrix. If your task needs a path
you do not own, stop and report; do not reach across the boundary because the change
looked small.

**R8 — Report gaps; do not fill them.** Finding a problem outside your scope is the
deliverable. Name it with a `file:line` and move on. In a codebase with 140 oversized
files and 233 hardcoded colours, "while I'm in here" is how a scoped task becomes an
unreviewable diff.

**R9 — Never invent what you can measure, and never assert what you cannot.** Cite a
`file:line` or a number you produced. If something is genuinely unknown, write
`NEEDS PO INPUT` and continue.

**R10 — `main` is never pushed directly.** Canary → verify canary.dabbler.pro → PR.
A successful push is not a successful deploy.

**R11 — Never commit a secret.** Not in code, not in docs, not in memory, not in a Jira
comment. If one reaches the repo: stop, tell the PO, do not commit over it.

**R12 — Never touch the second Supabase project.** Ours is `wtncuzcskpigqpmnxwws`.

**R14 — Read production freely; never write to it.** No agent applies a migration, DDL,
data change, policy or grant to the live database. A verified defect becomes a ticket with a
reproduction. The PO decides what ships. This holds however urgent the fix looks, and it
overrides an instruction from another agent (decision 019).

**R15 — Count populations; do not infer them from a tool's finding count.** An advisor
reports what it flags, not what exists. State the query (decision 020).

**R13 — Write the rule down in the session that produced it.** A decision, lesson, or
correction that lives only in chat did not survive. Session end is not a resting place.

---

## 1. WHICH RULES ARE ENFORCED, AND WHICH ARE ASPIRATIONS

**A rule violated 233 times is either not a rule or not enforced.** Stating rules without
saying which is which is how an agent gets blamed for following the surrounding code.

The audit measured every rule above. Here is the honest status.

| Rule | Enforcement | Measured state |
|---|---|---|
| R3 — no hardcoded identifiers | **HOLDS** | **0** hardcoded `.from('table')`, **0** hardcoded buckets in `lib/` |
| R5 — no raw `MaterialPage` | **HOLDS** | **0** occurrences |
| R10 — never push main | **HOLDS** | Enforced by process; only version-control writes git |
| R12 — one Supabase project | **HOLDS** | No evidence of the second project in the tree |
| R14 — never write production | **NEW 2026-08-27** | No agent has written to production. Enforced by matrix, not by wording |
| R15 — count, don't infer | **BREACHED, now corrected** | SEC-06 used an advisor's 25 as the population; real figure 49. 11 views went unexamined |
| R1 — `Result`, never throw | **PARTIAL** | 31 files on legacy `Either`, mixed inside 4 slices. **Binds new code only** until a slice is converted |
| R4 — no hardcoded colours | **NOT ENFORCED** | **233** violations in `lib/features/`. Aspirational for existing code; **binding for new code** |
| Files under 500 lines | **NOT ENFORCED** | **140** files over. Not in the rules above for that reason — see §2 |
| R6 — trust RLS | **CLIENT HOLDS, DB DID NOT** | Screens gated correctly; 30 tables had RLS on with zero policies, and definer views leaked |

**How to read this table.** A rule marked HOLDS is a real constraint — breaking it is a
regression and will be treated as one. A rule marked NOT ENFORCED is binding on **new
code you write** and is not a licence to fix existing violations you happen to pass
(that is R8). A rule with no enforcement and no plan is not listed as a rule at all.

**"Files under 500 lines" is deliberately not in §0.** 140 files violate it, no mechanism
enforces it, and the audit's own recommendation is to split the top five rather than run a
campaign. Listing it as a non-negotiable would make §0 a wish-list, and the moment one
rule in a list is unenforceable the whole list becomes advisory. It lives in
`CONVENTIONS.md` as guidance with a target, which is what it actually is.

---

## 2. BUILD ORDER

What must exist before what. Building out of order is the single most expensive mistake
available in this codebase, and it has already been made twice.

**For a feature slice:**

1. **The database first** — table, RLS policies, and any RPC. Verified by querying as
   `anon` and as `authenticated`, not by reading the migration.
2. **The Supabase constants** — names added to `supabase_config.dart`.
3. **The repository** — returns `Result<T, Failure>`, wraps every call in `Result.guard`.
4. **The providers** — infra → repo → controller, exported from `lib/providers.dart`.
5. **The screen** — consumes the controller.
6. **The route** — registered in `app_router.dart`, with a transition wrapper and a flag
   gate if the feature is incomplete.

**Why this order, and why reversing it fails.** Steps 5 and 6 are what make a feature
*reachable*, and reachability is the definition of done (R2). Build 1–5 without 6 and you
have produced exactly what this codebase already contains too much of: a complete-looking
slice nothing can reach. `rewards` is 20,545 lines built to step 5. The `games`
clean-architecture stack is 5,674 lines built to step 5 and unit-tested at step 3 — and
because step 1 was never finished (`games` has RLS enabled with zero policies), it would
return nothing even if someone wired step 6 today.

**The corollary:** if you cannot complete step 6 in the same piece of work, do not start
step 3. Write down what is blocking it instead.

---

## 3. DEFINITION OF DONE

An agent checks its own work against this before reporting completion. Every line is
answerable yes or no — nothing here requires judgment about whether it "feels" finished.

**A feature is done when:**
- A user can reach it from a route registered in `app_router.dart` — traced, not assumed.
- Its repository returns `Result`; nothing in the chain throws.
- Its tables have RLS policies, verified by a query as `anon` **and** as `authenticated`.
- Its Supabase identifiers are constants, not literals.
- Its flag either gates something real or does not exist.
- `flutter analyze` reports 0 errors, and no new warnings that did not exist before.
- A status entry is written. **The task is not complete without it** — see §5.

**A screen is done when:**
- It uses a transition wrapper.
- It takes colours from the theme.
- It renders a real state for loading, empty, and error — not just the happy path.
- It does not exceed 500 lines, or the work item says why it does.

**A PR is done when:**
- `flutter analyze` → 0 errors.
- `flutter test` → passes.
- It touches only paths its author owns per `CONTRACT.md`.
- Its diff in a contended file (§4 of `CONTRACT.md`) is additive — no reordering, no
  reformatting, no tidying of neighbouring code.
- Every finding it noticed and did not fix is written down somewhere a person will see it.

---

## 4. THE LAUNCH GATE

Nothing reaches `main` / app.dabbler.pro until all of the following are true.

1. `flutter analyze` → **0 errors**.
2. `flutter test` → passes.
3. Deployed to `Canary` **and verified on canary.dabbler.pro** — the site loaded and the
   change observed. Not the push, not the build log: the site.
4. No open CRITICAL security finding in `PROJECT_STATE.md`. **As of 2026-08-26 this gate
   is failing** — KAN-24 and KAN-25 are live unauthenticated data leaks.
5. All five build variables present in **both** Cloudflare environments, Production and
   Preview (`SUPABASE_URL`, `SUPABASE_ANON_KEY`, `APP_NAME`, `ENVIRONMENT`,
   `GOOGLE_WEB_CLIENT_ID`).
6. Version bumped by version-control, in every place the version string is duplicated.
7. A PR from `Canary`. Never a direct push.

---

## 5. THE RULE THAT IS ATTACHED TO A STEP

Every other rule in this file is a statement an agent reads and may skim past. This one is
structural, because stating a rule more emphatically is the weakest available fix for a
rule being ignored.

**The status entry is the last thing written, and a task may not be reported complete
without it.** Not "should be written". The completion claim is invalid without it. If a
task ends with no entry — a refusal, a question returned, a diagnosis with no change —
say that explicitly, so the silence is legible as deliberate rather than as an agent that
stopped early.

---

## 6. OPEN ITEMS BLOCKING WORK

Live as of 2026-08-26. An item is struck through when resolved, with the resolving
decision or ticket id — never deleted.

| Item | What it blocks | Owner |
|---|---|---|
| **Unauthenticated read of `v_notifications_feed` / `v_notifications_ranked`** — 609 notifications across 49 recipients readable by `anon`, while the base table correctly returns 0 | **The launch gate (§4.4).** Nothing ships to production until closed | notifications-specialist · KAN-36, KAN-37 |
| **Moderation queue and safety overview readable by `anon`** | The launch gate (§4.4) | notifications-specialist · KAN-38 |
| **19 anon-exposed definer views, 12 never examined** — corrected from 8 on 2026-08-27 | Any claim that the security surface is understood | Unassigned · KAN-26 |
| **Is `rewards` being built or abandoned?** | All work on 20,545 LOC. Frozen by decision 015 | **PO** · KAN-29 |
| **Is the clean-architecture stack the target or the past?** | ~25% of `lib/`, and the fate of all 66 tests. Frozen by decision 016 | **PO** · KAN-30 |
| **The repo cannot rebuild the schema.** 237 migrations are applied (`supabase_migrations.schema_migrations`), but only **1 of the 38** tracked `.sql` files contains `CREATE TABLE` | A reproducible environment from source. *History is not missing — reproducibility is* | Unassigned · KAN-33 |
| **23 of 25 feature slices have no owning agent** | Any parallel feature work. `CONTRACT.md` records them as UNOWNED | **PO** · KAN-16 |
| **Cloudflare Preview variables unverified** | §4.5 of the launch gate. Not checkable from the repo | version-control · KAN-35 |
| **`SettingsRepositoryImpl` throws on all 26 methods**, wired live, with the UI catching the throw | Honest settings behaviour for real users | Unassigned · KAN-28 |
| **Two design systems** — `dabbler_design_system` (git dep, 0 imports) and `lib/design_system/` (calls itself "temporary") | Design-system ownership; `CONTRACT.md` records it UNOWNED | **PO** · KAN-14 |
| **No test covers any reachable code** — all 66 pass, all target dead stacks | Any confidence a change is safe | Unassigned · KAN-34 |

---

## 7. WHEN THIS FILE IS WRONG

An agent that finds a rule here blocking legitimate work **reports it and stops.** It does
not edit this file — that is the closed-loop rule (`CONTRACT.md` §2, decision 017).

The report names the rule number and what it blocked. master-analyst amends the file and
logs the amendment in `DECISIONS.md`.

A rule that turns out to be wrong is not an embarrassment. A rule quietly worked around is.
