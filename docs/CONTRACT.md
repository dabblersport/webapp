# docs/CONTRACT.md — The Agent Contract

**Owner:** master-analyst (write) · all agents (read)
**Last updated:** 2026-08-29
**Purpose:** Who may read what, who may write what, and what gets learned where.
This is the file that stops two agents landing in the same place, and stops an agent
rewriting the rule it is judged against.

Precedence: `DECISIONS.md` (newest ACTIVE) → this file and `MANIFESTO.md` →
`CONVENTIONS.md` → everything else. If this file and another disagree, this one wins
and the other is corrected in the same session.

---

## 1. THE READING RULE

**Reading is open. Writing is scoped.**

Any agent may read any file in this repository, including files it may never write, and
including this one. An agent that has not read what it is about to touch is working
blind, and nothing in this contract is served by keeping an agent ignorant.

The single exception is the second, unrelated Supabase project on the Onebrain account.
**No agent reads it and no agent writes it.** Only `wtncuzcskpigqpmnxwws` is ours.

Writing is different. Every write path below has exactly one owner, or is explicitly
UNOWNED. There are no blank cells in the matrix, because a blank is ambiguous between
"the master owns this" and "nobody owns this" — and those are not the same thing.

---

## 2. THE CLOSED-LOOP RULE

**An agent must never be able to write the file that defines or judges it.**

These belong to master-analyst and to no one else:

| Path | Why it is closed |
|---|---|
| `.claude/agents/**` | An agent editing its own definition can widen its own scope. |
| `docs/CONTRACT.md` | An agent editing the permission matrix can grant itself a path. |
| `docs/MANIFESTO.md` | An agent editing the rules can remove the rule it just broke. |
| `docs/DECISIONS.md` | The tie-breaker. An agent that can edit it wins every disagreement. |
| `docs/AGENTS.md` | The roster. Same reasoning as `.claude/agents/**`. |
| `docs/WORKFLOWS.md` | Defines the handoffs an agent is judged against. |
| `docs/CONVENTIONS.md` | An agent that violated a convention could delete the convention. |
| Everything, for `task-auditor` | It reviews all of it. Write access anywhere would let the reviewer author what it later approves. |

**`task-auditor` is constrained the same way, from the opposite direction.** It judges other
agents' work, so it writes **nothing** they could be judged on — one status file, and its own
memory. It has no write access to a single line of code, schema, config or governance doc.
That is not a permission still to be granted: **a reviewer that can edit what it reviews is
not a reviewer.** Its authority is on the Jira board, not in the tree.

master-analyst is itself constrained, and the constraint is real rather than decorative:
it is **read-only over all code**. It may write governance docs, `PROJECT_STATE.md`,
`STATUS.md` and its own memory. It may not write `lib/`, `supabase/`, `test/`, or any
build config. It finds problems; it does not fix them. If master-analyst could both
declare a finding and fix it, no one would ever review either.

**The PO overrides everything here.** Every file in this table is the PO's to change at
any time. The closed loop constrains agents, not the person they work for.

---

## 3. THE PERMISSION MATRIX

`W` = may write · `R` = read only · `A` = append only · `—` = no access beyond reading

Agents: **MA** master-analyst · **NS** notifications-specialist · **VC** version-control ·
**AS** app-store-submission-fixer · **TA** task-auditor · **CP** cpo · **CT** cto ·
**BO** backend-owner · **FA** flutter-feature-agent · **QA** qa-tester

**`BO` and `FA` added 2026-08-28 (`DECISIONS.md` G-003).** The PO filled the two seats this
table had named vacant — the same two the audit identified when it found every database path
and 23 of 25 code slices UNOWNED. Both are **executives: they author, they do not apply.**
Neither gains any production-write authority; that stays exactly where `019` and `G-002` put
it, with `cto` or the PO. **A new agent starts from the read-only posture and is granted `W`
only on the rows named in G-003** — the columns were not filled in by analogy with an
existing agent.

**ROUTING — read this before dispatching anything (`G-008`, 2026-08-29).** This table is a
**routing table**, not just a permission table. A request goes **directly to the row's owner** —
never through `cto`, `cpo` or the assistant as a relay. Managers coordinate multi-domain work and
make the rulings `021` reserves to them; they do not answer implementation questions their
specialists own, and they are not an approval step for single-domain work. Peers message each
other directly. Work that splits into independent units is dispatched in parallel to each owner,
not bundled or serialised through a manager. `cto`'s production-apply authority (`G-002`) is
unaffected — that is an authority, not a hop.

**`qa-tester` added 2026-08-29 (`G-010`).** Functional QA against the *running* app (Chrome,
web build) — the gap `task-auditor`'s two document-comparison gates can't close. Full read
access, no DB access, no code-write access; files bugs, doesn't fix them. **It does NOT cover
`task-auditor`'s review gates, and `task-auditor` is not paused** — an earlier version of this
paragraph said otherwise and the PO superseded it. The two seats run side by side from the
start: `task-auditor` compares a claim against its acceptance criteria, `qa-tester` runs the
app against a per-ticket *testing story*. It also holds **computer-use** access for the rare
case that cannot be tested in Chrome. A future
**UX-auditor** role (copy, spacing, colour-token/design-system compliance) is spec'd but not
yet hired.

**The `QA` column is `R` almost everywhere, and that is the design, not a default.** `qa-tester`
writes no code, no SQL, no docs and no governance file; its output is Jira bugs and comments.
Four cells depart from `R`, each for a stated reason:

- **`docs/status/qa-tester.md` → `W`.** Its own status file, same as every other seat.
- **`.claude/agent-memory/<self>/**` → `W`.** Same rule as every other seat.
- **Every Supabase row → `—`, including the "reading" row that is `R` for everyone else.**
  `G-010` gives it *no database access at all*. This is the one place where copying the
  read-open default would have granted something the PO explicitly withheld.
- **Jira `In Review` column → `W*`, expiring.** Covering `task-auditor`'s two gates means
  posting verdicts and transitioning tickets; the gate is worthless without it. **This grant
  ends when Sprint 1 starts (2026-08-31)** and `task-auditor` resumes — at which point the
  cell reverts to `R` and `task-auditor` is again the only writer of that column. It is
  written `W*` rather than `W` so nobody reads it as permanent.

`docs/LEARN.md` stays `R` for `qa-tester` for `task-auditor`'s
reason in that row: a reviewer appending to a governance document it later grades is authoring
what it approves. It hands append-ready text to `master-analyst`, who appends it.

**Leadership vs executive.** `master-analyst`, `cpo` and `cto` are three peers in the
leadership layer (`021`) — not a hierarchy, and `master-analyst` is not senior to the other
two or a checkpoint they route through. `cpo` and `cto` **decide**, and may reject an
executive's work with reasons and direct the fix. `master-analyst` **measures** — it does not
decide and does not review other agents' work as a gate (that is `task-auditor`'s job,
exclusively). None of the three write feature code, and none writes to production
(decision `019`). The structure is the permission — they act inside it, not outside it.

**`master-analyst` is not a default recipient of every task.** Per `G-005`, it is not CC'd on
routine task completions, migrations, or ticket verdicts, and other agents do not report back
to it as a matter of habit. It reconciles its own files (`PROJECT_STATE.md`, `SCHEMA.md`
§§1–8/§10, `INDEX.md`) on its own audit cadence — pull, not push. The one standing exception:
a PO-direct edit to one of the four closed-loop files it exclusively writes (`CONTRACT.md`,
`MANIFESTO.md`, `AGENTS.md`, `WORKFLOWS.md`) gets a same-day note, because it is the only
agent with no other way to discover that its own file changed under it.

**The line that decides who owns a document:** master-analyst establishes **what is true**;
`cpo` and `cto` decide **what should be true next**. A file recording measurements stays
with the measurer, because a decision-maker has no reason to re-run the query and the file
rots. A file recording intent goes to the decider. Where one file holds both, it is split by
section, not handed over whole — see `SCHEMA.md` below.

**Two boundaries between the new seats, because they are the ones most likely to be crossed
by accident.** `flutter-feature-agent` writes Dart and **never a migration** — a feature that
needs schema routes the schema need to `backend-owner` rather than writing SQL itself.
`backend-owner` writes schema and **never the notification domain** — those tables, their RLS
and their triggers stay with `notifications-specialist`, whose row is unchanged.

**On `task-auditor`:** it reads everything and writes **one file** —
`docs/status/task-auditor.md`. Its column is `R` on every other row in this document, and
that is not an oversight to be corrected later. **A reviewer that can edit what it reviews
is not a reviewer.** Its independence is the entire mechanism, so its row is the one place
in this matrix where "no write access anywhere" is the design rather than a gap.

### Application code

| Path | MA | NS | VC | AS | TA | CP | CT | BO | FA | QA | Owner / rule |
|---|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|---|
| `lib/features/notifications/**` | R | **W** | — | — | R | R | R | R | R | R | notifications-specialist |
| `lib/services/notifications/**` | R | **W** | — | — | R | R | R | R | R | R | notifications-specialist |
| `lib/features/<any other slice>/**` | R | — | — | — | R | R | R | R | **W** | R | **flutter-feature-agent** (G-003, 2026-08-28). 23 of the 25 slices this table previously marked UNOWNED. **Authors only — it applies nothing to production and touches no Supabase migration**; schema needs route to `backend-owner`. Notification slices stay with NS. |
| `lib/core/**` (except the four contended files) | R | R | — | — | R | R | R | R | **W** | R | **flutter-feature-agent** (G-003). Cross-cutting — changing it changes every slice, so a change here needs `cto`'s sign-off on shape before it lands. The four contended files are still §4. |
| `lib/data/**` | R | R | — | — | R | R | R | R | **W** | R | **flutter-feature-agent** (G-003). Holds the live repositories; see the audit finding that three parallel profile stacks exist here. |
| `lib/app/app_router.dart` | R | R | — | R | R | R | R | R | R | R | **CONTENDED — see §4.** |
| `lib/providers.dart` | R | R | — | R | R | R | R | R | R | R | **CONTENDED — see §4.** |
| `lib/core/config/feature_flags.dart` | R | R | — | R | R | R | R | R | R | R | **CONTENDED — see §4.** |
| `lib/core/config/supabase_config.dart` | R | R | — | R | R | R | R | R | R | R | **CONTENDED — see §4.** |
| `lib/themes/**`, `lib/design_system/**`, `lib/utils/**`, `lib/widgets/**` | R | R | — | — | R | R | R | R | R | R | **UNOWNED — nobody writes it.** Design-system ownership is unresolved; see the two-design-systems open question in `PROJECT_STATE.md`. |
| `lib/main.dart`, `lib/firebase_options.dart` | R | R | — | R | R | R | R | R | R | R | **UNOWNED — nobody writes it,** except AS for iOS bootstrap requirements raised by an actual App Review rejection. |
| `lib/l10n/**`, all `*.g.dart`, all `*.freezed.dart` | — | — | — | — | — | — | — | — | — | — | **UNOWNED — generated.** Never hand-edited by anyone. Regenerate with `dart run build_runner build -d`. |

### Backend

**Verified against the tree 2026-08-27.** `supabase/` contains exactly three things:
`functions/`, `schema/`, and `.temp/`. **There is no `supabase/migrations/` directory** —
an earlier version of this table granted ownership of that path, which does not exist.

| Path | MA | NS | VC | AS | TA | CP | CT | BO | FA | QA | Owner / rule |
|---|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|---|
| Supabase — notification tables, their RLS, their triggers | R | **W\*** | — | — | R | R | R | R | R | — | notifications-specialist **authors** the SQL. \*It does not apply it to production — see the writing row below (decision 019) |
| Supabase — everything else (184 tables, 336 policies, **71 views**) | R | R | — | — | R | R | R | **W\*** | R | — | **backend-owner** (G-003). Schema, RLS, RPCs, views. **\*Authors only — it never applies to production** (decision 019 / G-002: `cto` or the PO). `cto` rules on shape (021); `backend-owner` builds it. This is the row that was UNOWNED when the audit found the live data leaks. KAN-26 closed by KAN-70. |
| `supabase/functions/send-push-notification/**`, `broadcast-notification/**` | R | **W** | — | — | R | R | R | R | R | R | notifications-specialist |
| `supabase/functions/detect-country/**` | R | R | — | — | R | R | R | **W** | R | R | **backend-owner** (G-003). Non-notification edge functions. |
| `supabase/schema/migrations/**` — 38 `.sql` files | R | **W\*** | — | — | R | R | R | **W** | R | R | **\*NS writes only notification-related migrations.** Every other migration is **UNOWNED — nobody writes it**, pending a backend owner. This is where schema SQL is actually written |
| `supabase/schema/snapshots/**` — `notification_schema_snapshot.sql`, 65KB | R | **W** | — | — | R | R | R | R | R | R | notifications-specialist. It is a notification-domain artefact despite the generic directory name |
| `supabase/schema/*.sql` (top level) — currently `add_comment_attachments.sql` | R | — | — | — | R | R | R | **W** | R | R | **backend-owner** (G-003). A loose file outside `migrations/`; resolving its status is now an owned question rather than an open one. |
| `supabase/schema/schema.json` | R | — | — | — | R | R | R | **W** | R | R | **backend-owner** (G-003). |
| `supabase/.temp/**` | — | — | — | — | — | — | — | — | — | — | **UNOWNED — Supabase CLI scratch.** Not authored by anyone; do not edit or commit |
| Supabase project `wtncuzcskpigqpmnxwws` — **reading** | R | R | R | R | R | R | R | R | R | — | **Open to every agent.** SELECT, `list_tables`, `get_advisors`, probing as `anon`/`authenticated`. Reading is how findings get verified |
| Supabase project `wtncuzcskpigqpmnxwws` — **writing** | — | — | — | — | — | R | **W\*** | — | — | — | **NOBODY except `cto`, under G-002's five conditions** (claim-comment posted and re-checked immediately before applying — G-006 — then authored+posted first, preconditions measured live, schema/privilege/definition — verified+posted-back after). **User-data mutation is PO-only (`019`) except security-remediation data changes meeting `G-009`'s three tests** (recorded finding, executable row-count guard, preconditions reconfirmed live immediately before applying). Everyone else: no `apply_migration`, no DDL, no data change, no policy or grant change — however correct or urgent. A verified defect becomes a ticket with a reproduction; the PO decides what ships, or `cto` applies it under G-002/G-009. **Decisions 019, G-002, G-006, G-009.** |
| **The second Supabase project on the account** | — | — | — | — | — | — | — | — | — | — | **FORBIDDEN TO EVERY AGENT.** Not ours. Never read, never write |

**A note the next backend owner needs.** These 38 files are real migrations with real
reasoning in their comment headers — they are *not* scratch.

**For the full and authoritative statement of the migration situation, read `SCHEMA.md` §8
mismatch 7. Do not restate it here or anywhere else.** That single-location rule exists
because this fact has now been wrong in this repository twice, in up to eight documents at a
time, each copy re-derived rather than read. In brief: 237 migrations are applied per the
database ledger; the repo cannot rebuild the schema. KAN-33's original premise was wrong.

### Tests, tooling, config

| Path | MA | NS | VC | AS | TA | CP | CT | BO | FA | QA | Owner / rule |
|---|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|---|
| `test/**` | R | **W** | — | — | R | R | R | **W** | **W** | R | Any agent may add tests **for code it owns** — NS notification tests, FA feature/core/data tests, BO schema tests. Nobody deletes another owner's test. With FA and BO hired, "tests for unowned slices are UNOWNED" no longer applies to the 23 slices. |
| `pubspec.yaml` — version string | R | — | **W** | R | R | R | R | R | R | R | version-control owns bumps, including every mirrored copy of the version. |
| `pubspec.yaml` — dependencies | R | R | R | R | R | R | R | R | R | R | **UNOWNED — nobody writes it.** Adding a dependency is an architectural decision; it needs a `DECISIONS.md` entry first. |
| `ios/**` | R | R* | — | **W** | R | R | R | R | R | R | AS owns it. *NS may change push entitlements and APNs config, and must say so in its status entry so AS is not surprised at submission. |
| `android/**` | R | R* | — | — | R | R | R | R | **W** | R | **flutter-feature-agent** (G-007, 2026-08-29) owns Android platform config — manifest, native resources (`res/xml/**` backup rules, etc.), Gradle. *NS may still change FCM channel and manifest changes for its own domain and must say so in its status entry. Was UNOWNED until this ruling; caught when a KAN-60 write was made against the UNOWNED cell. |
| `web/**` | R | R* | — | — | R | R | R | R | R | R | **UNOWNED — nobody writes it,** except *NS for the web-push service worker. |
| `scripts/**` | R | — | **W** | — | R | R | R | R | R | R | version-control (it owns `cloudflare-build.sh`). |
| `.claude/agents/**` | **W** | — | — | — | R | R | R | R | R | R | master-analyst. Closed loop — see §2. |
| `.claude/skills/**` | **W** | — | — | — | R | R | R | R | R | R | master-analyst. |
| `.claude/settings*.json`, `.mcp.json` | — | — | — | — | — | — | — | — | — | — | **UNOWNED — the PO writes these.** No agent edits its own permissions or MCP wiring. This is a closed-loop rule with teeth: an agent that can edit `settings.local.json` can grant itself anything in this matrix. |
| `.claude/agent-memory/<self>/**` | **W** | **W** | **W** | **W** | **W** | **W** | **W** | **W** | **W** | **W** | Each agent writes its own memory directory and **only** its own. |
| `.claude/agent-memory/<other>/**` | R | R | R | R | R | R | R | R | R | R | Read to understand a teammate. Never write. |
| `CLAUDE.md` | R | R | R | R | R | R | R | R | R | R | **UNOWNED — the PO writes it.** Agents propose changes through `DECISIONS.md`; they do not edit it. |

### Docs

| Path | MA | NS | VC | AS | TA | CP | CT | BO | FA | QA | Owner / rule |
|---|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|---|
| `docs/README.md` | **W** | R | R | R | R | R | R | R | R | R | master-analyst. The index. It must be corrected whenever a file's state changes — a stale index is the first thing a new agent reads |
| `docs/MANIFESTO.md`, `CONTRACT.md`, `AGENTS.md`, `WORKFLOWS.md` | **W** | R | R | R | R | R | R | R | R | R | master-analyst. Closed loop — see §2. **TA reads these to run Gate 2 and may never write them** |
| `docs/DECISIONS.md` — governance entries (unprefixed, 001–020) | **W** | R | R | R | R | R | R | R | R | R | master-analyst |
| `docs/DECISIONS.md` — technical entries (`T-nnn`) | R | R | R | R | R | R | **A** | R | R | R | **cto**, append-only. See the numbering rule in §9  **BO/FA are `R` here: G-003 grants them code and schema paths, not this file. Not an oversight — a grant nobody made.** |
| `docs/DECISIONS.md` — product entries (`P-nnn`) | R | R | R | R | R | **A** | R | R | R | R | **cpo**, append-only |
| `docs/BRIEF.md` | R | R | R | R | R | **W** | R | R | R | R | **cpo.** Filled from the 26-document business corpus in Notion — a real source, which is why this file was held empty until now. Never inferred from code |
| `docs/PROJECT_STATE.md` | **W** | R | R | R | R | R | R | R | R | R | **master-analyst.** The measured record. `cto.md:20` instructs the CTO to read it rather than re-measure |
| `docs/ROADMAP.md` | R | R | R | R | R | **W** | R | R | R | R | **cpo.** Waves and priorities are product calls — Wave 4+'s exit criterion is `NEEDS PO INPUT` for exactly this reason |
| `docs/ARCHITECTURE.md` | R | R | R | R | R | R | **W** | R | R | R | **cto.** Target technical direction. **§3b's measured flow-reachability data is master-analyst's** and is re-measured by it — the CTO decides direction, not what the tree currently contains  **BO/FA are `R` here: G-003 grants them code and schema paths, not this file. Not an oversight — a grant nobody made.** |
| `docs/SCHEMA.md` §§1–8, §10 — **the measured census** | **W** | R | R | R | R | R | R | R | R | R | **master-analyst. SPLIT — see §9 below.** RLS positions for 184 tables, the 71-view anon-exposure census, the RPC caller map, ~200 triggers, the errata log. Every line carries a verification date and a regeneration query |
| `docs/SCHEMA.md` §11 — **target state and standards** | R | R | R | R | R | R | **W** | R | R | R | **cto.** What the schema *should* be: the RLS standard, the `security_invoker` default, which `nearby` generation is canonical, whether the 30 zero-policy tables are intentional  **BO/FA are `R` here: G-003 grants them code and schema paths, not this file. Not an oversight — a grant nobody made.** |
| `docs/CONVENTIONS.md` | R | R | R | R | R | R | **W** | R | R | R | **cto**, with a guard — see §9. A convention change requires a numbered `DECISIONS.md` entry so a loosened standard is visible as a dated decision, not a silent edit  **BO/FA are `R` here: G-003 grants them code and schema paths, not this file. Not an oversight — a grant nobody made.** |
| `docs/LEARN.md` | **A** | **A** | **A** | **A** | **R** | **A** | **A** | **A** | **A** | R | **Append-only by every agent — with one exception: `task-auditor` is `R`.** `LEARN.md` is a governance document it reviews (it graded KAN-15, a `LEARN.md` ticket). Appending there would make the reviewer an author of what it later approves — the failure §2 names. **When it has a lesson, it hands the append-ready text to master-analyst, who appends it.** That is not a workaround; the content lands and the boundary holds. See §6. **CP/CT corrected from `R` to `A` on 2026-08-28: the rule in this cell said "append-only by every agent" while the cells said otherwise, and `cpo`/`cto` had both been appending all along. The text was right.** |
| `docs/STATUS.md` | **W** | R | R | R | R | R | R | R | R | R | master-analyst reconciles it. **This is the channel the PO reads.** |
| `docs/status/master-analyst.md` | **W** | R | R | R | R | R | R | R | R | R | Own status only |
| `docs/status/notifications-specialist.md` | R | **W** | R | R | R | R | R | R | R | R | Own status only |
| `docs/status/version-control.md` | R | R | **W** | R | R | R | R | R | R | R | Own status only |
| `docs/status/app-store-submission-fixer.md` | R | R | R | **W** | R | R | R | R | R | R | Own status only |
| `docs/status/task-auditor.md` | R | R | R | R | **W** | R | R | R | R | R | **The only file `task-auditor` writes in this repo.** Own status only |
| `docs/status/cpo.md` | R | R | R | R | R | **W** | R | R | R | R | Own status only |
| `docs/status/cto.md` | R | R | R | R | R | R | **W** | R | R | R | Own status only  **No agent writes another agent's status file.** |
| `docs/status/backend-owner.md` | R | R | R | R | R | R | R | **W** | R | R | Its own agent, and nobody else. Added with G-003. |
| `docs/status/flutter-feature-agent.md` | R | R | R | R | R | R | R | R | **W** | R | Its own agent, and nobody else. Added with G-003. |
| `docs/status/qa-tester.md` | R | R | R | R | R | R | R | R | R | **W** | Its own agent, and nobody else. Added with G-010, 2026-08-29. |
| `docs/NOTIFICATIONS.md` | R | **W** | R | R | R | R | R | R | R | R | notifications-specialist. Drifted — its subject was rewritten after it was written |
| `docs/LOCATION.md` | R | — | — | — | R | R | R | R | R | R | **UNOWNED — nobody writes it.** |
| `docs/RESEARCH.md` | **W** | R | R | R | R | **A** | **A** | R | R | R | **UNOWNED-BY-DEFAULT → master-analyst curates.** The single living research file; `docs/research/` was removed by the PO. `cpo`/`cto` append findings in their domain  **BO/FA are `R` here: G-003 grants them code and schema paths, not this file. Not an oversight — a grant nobody made.** |
| `docs/screen-report.md`, `docs/agents/` | **W** | — | — | — | R | R | R | R | R | R | master-analyst. Both currently untracked by git — see KAN-14. |

### Release

| Path | MA | NS | VC | AS | TA | CP | CT | BO | FA | QA | Owner / rule |
|---|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|---|
| Git — commit, branch, merge, tag, push | R | — | **W** | — | R | R | R | R | R | R | **version-control only.** No other agent runs a write git command. |
| Branch `main` | — | — | R | — | — | — | — | — | — | — | **Nobody pushes it directly, version-control included.** It deploys straight to app.dabbler.pro. Reached only by PR from `Canary`. |
| Cloudflare Pages project `webapp` | — | — | **W** | — | — | — | — | — | — | — | version-control |
| App Store Connect | — | — | R | **W** | — | — | — | — | — | — | app-store-submission-fixer |
| Google Play Console | — | — | **W** | — | — | — | — | — | — | — | version-control |
| Jira — the `In Review` column: verdict comment + transition to Done or To Do | R | R | R | R | **W** | R | R | R | R | **W\*** | **task-auditor only** — **\*except `qa-tester` while it covers the review gates, expiring 2026-08-31 (`G-010`).** Its authority is on the board, not in the tree. master-analyst may transition its own tickets **as far as In Review and no further** |

---

## 4. THE FOUR CONTENDED FILES

Four files are touched by nearly every piece of feature work, so they are where parallel
agents collide. They are **not** owned by any one agent, and they are **not** UNOWNED.
They have a protocol instead.

| File | Why every agent needs it |
|---|---|
| `lib/app/app_router.dart` | 1,745 LOC. Every new screen adds an import and a route. |
| `lib/providers.dart` | CLAUDE.md requires every new provider to be exported here. |
| `lib/core/config/feature_flags.dart` | CLAUDE.md requires every new feature to be gated here. |
| `lib/core/config/supabase_config.dart` | Every table, bucket and RPC name lives here; hardcoding them is forbidden. |

**The protocol:**

1. **Append, do not restructure.** Add your import, your route, your provider export, your
   constant. Do not reorder, regroup, reformat, or "tidy" the file while you are in it.
   A diff that touches 40 lines to add 3 cannot be reviewed and will collide with
   everyone else's.
2. **One agent in one of these files at a time.** If two tasks both need `app_router.dart`,
   they are sequenced, not parallelised. The Workflows doc names who sequences them.
3. **Your feature's block only.** Do not fix a neighbouring feature's route while you are
   in the router, however obviously wrong it looks. Report it instead — see §5.
4. **Never delete another agent's entry.** Removing a dead flag or a dead route is
   cleanup work with its own ticket and its own owner. It is not a side effect of your
   feature.
5. **`supabase_config.dart` is add-only for constants.** Changing an existing constant's
   *value* changes which table the whole app talks to. That needs a `DECISIONS.md` entry.
   The audit found two constants pointing at buckets that do not exist
   (`venueImagesBucket = 'venue-images'`); fixing those is KAN-27's job, not yours.

**Why this is strict.** The audit measured what happens without it: 98 dead feature flags,
54 unreferenced route constants, and 1,745 lines in one router. That is what a year of
"while I'm in here" produces.

---

## 5. THE INFORMATION CONTRACT — what gets learned where

Five destinations. Each has one test. **An entry that fails its test is not written** —
writing it anyway is how a living document becomes noise nobody reads.

| Destination | What goes there | The test |
|---|---|---|
| `docs/LEARN.md` | A lesson that generalises past the task that produced it — a bug class, a trap that cost a session, a preference discovered by being corrected, a rule that turned out to have an exception. | **"Would reading this before starting have saved time?"** If no, it does not belong. |
| `docs/DECISIONS.md` | A choice with reasoning, where a different choice was genuinely available. | **"Could a reasonable agent have chosen otherwise?"** If there was only one option, it is not a decision — it is just what happened, and it goes to STATUS. |
| `docs/STATUS.md` and `docs/status/<agent>.md` | What happened in a task: what changed, what was verified, what is left. | **"Does the PO need to know this happened?"** Every completed task passes this. Write it as part of the task, never as an afterthought. |
| `docs/PROJECT_STATE.md` | Measured state of the codebase, with a `file:line` or a scanner number. | **"Did I measure it?"** If it was estimated, inferred, or remembered, it does not go in. master-analyst only. |
| `.claude/agent-memory/<self>/` | What *you* need to not re-derive next session — schema facts, confirmed false positives, PO decisions in your area. | **"Will I waste time re-deriving this?"** Not for anything the repo already records. |

**Three clarifications that have already caused confusion:**

- **A decision and a lesson are different things.** "We chose Result over Either" is a
  decision. "Mixing Result and Either inside one slice produces silent type confusion
  that the analyzer does not catch" is a lesson. The first goes to DECISIONS, the second
  to LEARN. If you find yourself writing both in one paragraph, split it.
- **A status entry is not a lesson.** "Fixed the push 401" is status. "Server-triggered
  push fails with 401 when the shared secret is fetched per-request instead of per-warm-
  instance" is a lesson. Status answers *what happened*; LEARN answers *what to do
  differently*.
- **Reporting is not fixing.** When you find a problem outside your scope — and you will,
  constantly, in a codebase this size — the deliverable is the report, not the fix. Name
  it in your status entry with a `file:line`. Do not reach across the boundary because
  the fix looked small.

---

## 6. APPEND-ONLY DISCIPLINE

**`docs/LEARN.md` is append-only, by every agent including master-analyst — except
`task-auditor`, which is read-only on it.** It reviews this file; authoring in it would let
the reviewer approve its own writing. It routes lessons through master-analyst instead.

Never restructure it. Never reorder it. Never deduplicate it. Never "improve" it.
Never fix its formatting. The PO owns its shape.

Add your entry to the section it belongs to — not necessarily the end of the file. If no
section fits, add one at the end rather than forcing your lesson into a section that is
nearly right.

**Correcting an existing line is not appending.** If a lesson in LEARN.md has become
wrong, you do not edit it and you do not delete it. You append a new dated entry saying
what changed and why, and you report the contradiction in your status entry. The old
entry stays. Knowing that we once believed something false, and when we stopped, is
information — and an agent that silently rewrites history takes that away from everyone
who reads the file later.

`docs/status/<agent>.md` files are append-only within themselves: newest entry at the
top, older entries never edited.

---

## 7. WHAT IS NEVER WRITTEN DOWN

Not in docs, not in code, not in memory, not in a status entry, not in a Jira comment,
not in an App Store reply.

- **Secrets and credentials** — service-role keys, API keys with write scope, SMTP
  credentials, signing certificates, FCM server keys, private keys of any kind.
- **`.env` contents.** The file is gitignored and untracked; both verified by command.
  Keep it that way. Naming a variable is fine — `SUPABASE_ANON_KEY is required by the
  build` is useful. Pasting its value is not.
- **User PII** — real names, emails, phone numbers, addresses, avatars, message or
  notification bodies, device tokens. The audit needed to establish that
  `v_notifications_feed` exposed 609 rows across 49 recipients; it recorded *those two
  numbers* and never a single row of content. Do the same: characterise the exposure,
  never reproduce it.
- **Unredacted third-party material** — anything under an NDA or from a partner.

**Two things that look like secrets and are not**, so nobody wastes a session on them:
the Firebase `AIza…` keys in `lib/firebase_options.dart` and
`android/app/google-services.json` are public client identifiers and are meant to ship;
and `service_role` inside `supabase/functions/**` is server-side and correct. Neither is
a leak. Both are documented in `PROJECT_STATE.md` §9.

**If a secret does reach the repo:** stop, tell the PO immediately, and do not commit
over it. Rotating the credential comes first; scrubbing history is version-control's job
and needs the PO's decision.

---

## 8. AMENDING THIS CONTRACT

An agent that finds this file wrong — a path with no owner it needs, a rule that blocks
legitimate work, a cell that contradicts its own definition — **reports it and stops.**
It does not edit this file. That is the closed-loop rule, and it applies to the contract
most of all.

The report goes in the agent's status entry and names the exact row. master-analyst
amends the matrix, logs the amendment in `DECISIONS.md`, and updates `Last updated` above.

**When a new agent is hired**, this matrix is amended *before* the agent runs, not after.
An agent whose paths are not in the matrix has no scope, and an agent with no scope
writes wherever it likes — which is the situation this file exists to prevent.

---

## 9. THE LEADERSHIP SPLIT — three rules it needs to hold

Added 2026-08-27 with `cpo` and `cto`. The split is right in principle; these three guards
are what stop it creating new failures.

### 9.1 `SCHEMA.md` is split by section, not handed over whole

**Why.** `cto.md:20` tells the CTO to *"read `PROJECT_STATE.md` rather than re-measuring —
the Analyst establishes what is true; you decide what should be true."* **`SCHEMA.md` §§1–8
are the same kind of artefact as `PROJECT_STATE.md`** — a census of what the database
currently contains, every figure carrying a verification date and a regeneration query.

If a decision-maker owns a measurement file, one of two things happens: it inherits a
re-measurement duty its own charter tells it not to perform, or nobody re-runs the queries
and the file rots. **This specific file has already been wrong twice** — 49 views that were
71, and "no schema history" against a 237-row ledger — and only re-measurement caught either.

So: **§§1–8 and §10 stay with master-analyst. §11 (target state and standards) is the
CTO's.** The CTO decides the RLS standard, the `security_invoker` default, which `nearby`
generation is canonical, and whether the 30 zero-policy tables are intentional. The Analyst
reports what is there.

Same logic for `ARCHITECTURE.md` §3b, whose flow-reachability figures are measured: the CTO
owns the file and its direction; the measured numbers inside it are re-measured by
master-analyst and must not be hand-edited.

### 9.2 A CTO convention change requires a numbered decision

**The closed-loop problem the split creates.** `task-auditor` runs Gate 2 against
`CONVENTIONS.md` and `ARCHITECTURE.md`. If the CTO owns those **and** directs the executive
work being judged, the CTO can edit the standard its own directed work is graded against.

That cannot happen today: master-analyst owns those files and is read-only over code, so it
gains nothing from loosening a rule. **A CTO gains something — its executives' work passes.**
This is precisely the failure §2 exists to prevent, and it is new.

**Not a blocker; a guard.** A CTO change to `CONVENTIONS.md` or `ARCHITECTURE.md` **must
carry a numbered `T-nnn` entry in `DECISIONS.md`**, and `task-auditor`'s Gate 2 reads the
decision log alongside the convention file. A relaxed standard then appears as a dated
decision with reasoning a reviewer can question — not a silent edit that turns yesterday's
violation into today's compliance.

### 9.2b Attribution names roles, never agent instances

*Added 2026-08-28, on the CTO's correction. Applies to every document in `docs/` and to
every agent's memory.*

**Write `cto`, never `cto-4` / `cto-5` / `cto-6`.** An instance name is an implementation
detail of how a session happened to be spawned. It means nothing to a reader six months out,
and it means something actively wrong: a record naming three `cto-N` reads as three CTOs, or
as three agents whose definitions someone will go looking for and not find. **The roster in
`AGENTS.md` is the list of names that exist.**

This was not hypothetical. On 2026-08-28 **71 instance-name references** had accumulated
across `PROJECT_STATE.md`, `SCHEMA.md`, `LEARN.md`, `CONTRACT.md` and two memory files before
anyone noticed. All collapsed to the role.

**When collapsing changes the meaning, fix the sentence, not the name.** Several entries
recorded one CTO instance correcting another; written as one role they read as
self-contradiction. The truthful form is sequential — *"the CTO ruled on this twice in
separate passes"* — because that is what happened: **one seat, two sittings.** Do not
reintroduce the instance number to preserve the drama of the correction.

### 9.3 `DECISIONS.md` numbering — prefixes, because three writers will collide

One sequence with three appenders produces two agents both writing `021` in parallel
sessions. From 2026-08-27:

| Prefix | Owner | Domain |
|---|---|---|
| *(unprefixed)* `001`–`021` | master-analyst | the existing governance sequence, now closed |
| `G-nnn` | master-analyst **and the assistant** | governance, process, the agent system |
| `T-nnn` | cto | architecture, schema, stack, engineering standards |
| `P-nnn` | cpo | product, scope, roadmap, monetisation |

Each agent numbers within its own prefix, so no coordination is needed and the prefix names
the domain at a glance. **Precedence is unchanged: the newest dated ACTIVE entry wins,
regardless of prefix.** A cross-domain supersede needs both owners to agree, or the PO decides.

**Why `G-nnn` has two appenders, named 2026-08-28 after a real collision (see errata).**
master-analyst's `G-nnn` entries are audit-derived: a process gap it found and is recording.
The assistant's are PO-direct: a structural or authority decision the PO made live in chat
(granting an agent new authority, filling a vacant seat), transcribed at the point of decision
rather than reached by any agent's own reasoning. Different origin, same domain, so they share
the prefix rather than getting a fifth one — but **no other agent appends to `G-nnn`.** A
leadership agent whose own ruling belongs in governance writes it as its own prefix (`T-nnn`
for `cto`, `P-nnn` for `cpo`) even when the topic brushes against process — as `T-026` does,
ruled on by `cto`, not filed as a fourth `G` writer.

---

## 10. WHAT THIS FILE HAS BEEN WRONG ABOUT

Kept deliberately. A permission matrix that silently corrects itself teaches readers to
trust it more than it has earned.

| Date | Error | Correction |
|---|---|---|
| 2026-08-26 → corrected 2026-08-27 | Granted `supabase/migrations/**` to notifications-specialist and called it "currently empty". **The directory does not exist.** The real tree is `supabase/schema/**` and had no row at all | Phantom row replaced with four real rows, verified against the tree |
| 2026-08-26 → corrected 2026-08-27 | `docs/README.md` had no row, and there is no catch-all | Row added under Docs |
| 2026-08-26 → corrected 2026-08-27 | No column for `task-auditor` | Column added to all five tables |
| 2026-08-27 → corrected same day | The `docs/LEARN.md` row read `A A A A **A**` — `task-auditor` granted append on a file it reviews, contradicting §2, the §1 note and §6. **A column-width artefact**: a uniform row gained a fifth `A` when the column was inserted, rather than a deliberate `R` | Cell set to `R`, with the exception and its routing stated |
| 2026-08-26 → corrected 2026-08-27 | "49 views" in the Supabase row | **71.** The 71/49/19 correction reached `SCHEMA.md` and `PROJECT_STATE.md` but not this file |
| 2026-08-27 | Sole ownership of `ARCHITECTURE.md`, `SCHEMA.md`, `CONVENTIONS.md`, `ROADMAP.md`, `BRIEF.md` and all of `DECISIONS.md` sat with master-analyst — **one agent holding both measurement and decision authority** | Split with `cpo`/`cto` per §9. `SCHEMA.md` divided by section rather than handed over whole, plus two structural guards |
| 2026-08-26 → corrected 2026-08-28 | **`docs/LEARN.md` gave `CP` and `CT` an `R` while the same row's rule read "append-only by every agent — with one exception: `task-auditor` is `R`."** The cells and the sentence beside them disagreed, and `cpo` and `cto` had both been appending to `LEARN.md` all along — correctly, per the rule, in violation of their own cells | Cells corrected to `A`. **The prose was right and the grid was wrong**, which is the reverse of the usual failure and the reason it survived: a reader checking the rule got the right answer, so nobody checked the row |
| 2026-08-28 | While adding `BO`/`FA`, the mechanical pass defaulted both columns to `cto`'s value — a read-only posture on most rows, but it silently handed the new agents `W` on `ARCHITECTURE.md`, `SCHEMA.md` §11, `CONVENTIONS.md` and **`docs/status/cto.md`**, and `A` on `DECISIONS.md` and `RESEARCH.md` | All six corrected to `R` before the edit was reported. **A default is a grant.** Filling a new agent's column by analogy with an existing one is how scope leaks in without a decision — G-003 named code and schema paths, so those are the only rows where either got `W` |
| 2026-08-28 | §9.3 said `G-nnn` had one appender, master-analyst. In practice **two others wrote to it the same day**: the assistant (`G-002`, `G-003` — PO-direct decisions, transcribed live) and `cto` (a QA/CI ruling, briefly filed as a second `G-003`). The rule and reality had already diverged before the collision made it visible | Colliding entry renumbered to `T-026` (cto's own prefix — the ruling was an engineering standard, not process). §9.3 amended to name the assistant as `G-nnn`'s second appender for PO-direct decisions specifically; every other agent's own-domain ruling stays in its own prefix even when the topic brushes governance |

**How the phantom path survived being written and self-reviewed:** nothing in the loop was
required to look at the filesystem. The row was internally consistent, plausibly worded, and
cited a real ticket. It was caught by a reviewer who ran `ls`. **A document can be coherent
and still be wrong about the tree** — the check that catches it has to touch reality.

---

## 11. ~~OPEN PROPOSAL~~ — RESOLVED 2026-08-28 by `DECISIONS.md` G-003

**The PO chose option A and filled both seats.** `backend-owner` (KAN-70) takes the database
paths; `flutter-feature-agent` (KAN-71) takes the 23 slices. The matrix in §3 is amended and
both carry `W` on their paths and **no production-write authority whatsoever** — that stays
with `cto` under `019`/`G-002`, exactly as this proposal asked.

**Kept below rather than deleted, because the reasoning is the precedent.** The next time a
gate item has no permitted writer, the argument that moved it was structural, not throughput:
*the work could not be sliced into anything an existing agent may author.* Option B — widening
a scoped agent under time pressure — was rejected and should be rejected again.

### The proposal as written

*Raised by `cto` 2026-08-28. Written here by `master-analyst` as a **proposal, not an
amendment**. Nothing in §3 changes until the PO accepts one of the options below. Per §8, a
matrix row is amended by the PO, and per `DECISIONS.md` 019 no agent writes the production
database at all.*

### The gap, stated precisely

Two promotion-gate items are database work. §3 rows 116 and 119–122 make every database path
**UNOWNED** except notification migrations. So the gate that blocks promotion cannot be
cleared by any agent currently in the matrix. This is not an oversight to be patched quietly
— it is the system working as designed and surfacing a hiring decision.

Two agents independently reached this boundary and both stopped at it rather than granting
themselves the path. That is §2 doing its job, and it is the right outcome: **an agent that
can widen its own scope to clear its own gate has no gate.**

### What the PO is being asked to decide

| Option | What it means | Cost |
|---|---|---|
| **A — hire a backend owner** | A new agent owns `supabase/schema/**` and the live schema. Already raised as **KAN-26** | A seventh agent, a new column, a definition to write |
| **B — widen `notifications-specialist`** | It already writes notification migrations and holds the only working DB-write precedent | Its name stops describing its scope, and it becomes the de facto backend owner without the review that hiring one would get |
| **C — PO executes the SQL** | Agents write and review the migration; the PO applies it | No new agent; the PO is the bottleneck on every schema change |
| **D — leave it UNOWNED** | The gate items are cleared by the PO or not at all | Honest, and it means the gate stays shut until the PO has time |

**The strongest argument for A is structural, not throughput** *(added 2026-08-28, `cto`)*.
The highest-severity finding on the board (SEC-16 / KAN-67) is one migration against
**schema-level** configuration — table and view grants plus `ALTER DEFAULT PRIVILEGES` in
`public`. There is no per-view `REVOKE` that fixes it. It therefore **cannot be sliced into
anything an existing agent may author**: carving it by view ownership yields two migrations
that each half-fix one setting, with the `pg_default_acl` half belonging to neither owner.
That is a gap in the matrix, not a queue that is moving too slowly — and it is the version
of this decision a PO can act on.

`master-analyst`'s recommendation: **A**, and not B. B is the cheapest thing to type and the
most expensive thing to live with — it converts a scoped agent into an unscoped one by
accretion, and the matrix stops describing the system. If A is too much agent for the amount
of work, **C** is the honest small answer; D is acceptable and should be chosen explicitly
rather than arrived at by neglect.

**Whoever gets the path, `DECISIONS.md` 019 still stands:** writing migration files in the
repo and writing the production database are different permissions, and this proposal is
only about the first.

### Constraint on whoever owns it

Any writer of this path inherits `SCHEMA.md` §8 mismatch 7 as the authoritative statement of
the migration situation: **237 rows in `supabase_migrations.schema_migrations` versus 38
tracked `.sql` files**, only one of which contains a `CREATE TABLE`. The repo is not a
reconstruction of the live schema and must not be treated as one.

