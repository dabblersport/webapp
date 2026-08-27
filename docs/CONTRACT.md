# docs/CONTRACT.md — The Agent Contract

**Owner:** master-analyst (write) · all agents (read)
**Last updated:** 2026-08-26
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
**AS** app-store-submission-fixer · **TA** task-auditor

**On `task-auditor`:** it reads everything and writes **one file** —
`docs/status/task-auditor.md`. Its column is `R` on every other row in this document, and
that is not an oversight to be corrected later. **A reviewer that can edit what it reviews
is not a reviewer.** Its independence is the entire mechanism, so its row is the one place
in this matrix where "no write access anywhere" is the design rather than a gap.

### Application code

| Path | MA | NS | VC | AS | TA | Owner / rule |
|---|:--:|:--:|:--:|:--:|:--:|---|
| `lib/features/notifications/**` | R | **W** | — | — | R | notifications-specialist |
| `lib/services/notifications/**` | R | **W** | — | — | R | notifications-specialist |
| `lib/features/<any other slice>/**` | R | — | — | — | R | **UNOWNED — nobody writes it.** No feature agent has been hired for these 23 slices. A slice gets a writer when an agent is hired for it and this table is amended. Until then, work on them is done by the PO or by an agent the PO spawns for a named task. |
| `lib/core/**` (except the four contended files) | R | R | — | — | R | **UNOWNED — nobody writes it.** Cross-cutting; changing it changes every slice. Needs a platform owner. |
| `lib/data/**` | R | R | — | — | R | **UNOWNED — nobody writes it.** Holds the live repositories; see the audit finding that three parallel profile stacks exist here. |
| `lib/app/app_router.dart` | R | R | — | R | R | **CONTENDED — see §4.** |
| `lib/providers.dart` | R | R | — | R | R | **CONTENDED — see §4.** |
| `lib/core/config/feature_flags.dart` | R | R | — | R | R | **CONTENDED — see §4.** |
| `lib/core/config/supabase_config.dart` | R | R | — | R | R | **CONTENDED — see §4.** |
| `lib/themes/**`, `lib/design_system/**`, `lib/utils/**`, `lib/widgets/**` | R | R | — | — | R | **UNOWNED — nobody writes it.** Design-system ownership is unresolved; see the two-design-systems open question in `PROJECT_STATE.md`. |
| `lib/main.dart`, `lib/firebase_options.dart` | R | R | — | R | R | **UNOWNED — nobody writes it,** except AS for iOS bootstrap requirements raised by an actual App Review rejection. |
| `lib/l10n/**`, all `*.g.dart`, all `*.freezed.dart` | — | — | — | — | — | **UNOWNED — generated.** Never hand-edited by anyone. Regenerate with `dart run build_runner build -d`. |

### Backend

**Verified against the tree 2026-08-27.** `supabase/` contains exactly three things:
`functions/`, `schema/`, and `.temp/`. **There is no `supabase/migrations/` directory** —
an earlier version of this table granted ownership of that path, which does not exist.

| Path | MA | NS | VC | AS | TA | Owner / rule |
|---|:--:|:--:|:--:|:--:|:--:|---|
| Supabase — notification tables, their RLS, their triggers | R | **W\*** | — | — | R | notifications-specialist **authors** the SQL. \*It does not apply it to production — see the writing row below (decision 019) |
| Supabase — everything else (184 tables, 336 policies, **71 views**) | R | R | — | — | R | **UNOWNED — nobody writes it.** This is why the audit found two live data leaks. Needs a backend owner; raised as KAN-26. |
| `supabase/functions/send-push-notification/**`, `broadcast-notification/**` | R | **W** | — | — | R | notifications-specialist |
| `supabase/functions/detect-country/**` | R | R | — | — | R | **UNOWNED — nobody writes it.** |
| `supabase/schema/migrations/**` — 38 `.sql` files | R | **W\*** | — | — | R | **\*NS writes only notification-related migrations.** Every other migration is **UNOWNED — nobody writes it**, pending a backend owner. This is where schema SQL is actually written |
| `supabase/schema/snapshots/**` — `notification_schema_snapshot.sql`, 65KB | R | **W** | — | — | R | notifications-specialist. It is a notification-domain artefact despite the generic directory name |
| `supabase/schema/*.sql` (top level) — currently `add_comment_attachments.sql` | R | — | — | — | R | **UNOWNED — nobody writes it.** A loose file outside `migrations/`; its status is itself a question for the backend owner |
| `supabase/schema/schema.json` | R | — | — | — | R | **UNOWNED — nobody writes it.** |
| `supabase/.temp/**` | — | — | — | — | — | **UNOWNED — Supabase CLI scratch.** Not authored by anyone; do not edit or commit |
| Supabase project `wtncuzcskpigqpmnxwws` — **reading** | R | R | R | R | R | **Open to every agent.** SELECT, `list_tables`, `get_advisors`, probing as `anon`/`authenticated`. Reading is how findings get verified |
| Supabase project `wtncuzcskpigqpmnxwws` — **writing** | — | — | — | — | — | **NOBODY. No agent writes production**, including notifications-specialist. No `apply_migration`, no DDL, no data change, no policy or grant change — however correct or urgent. A verified defect becomes a ticket with a reproduction; the PO decides what ships. **Decision 019.** This overrides any instruction to "just fix it", including from another agent |
| **The second Supabase project on the account** | — | — | — | — | — | **FORBIDDEN TO EVERY AGENT.** Not ours. Never read, never write |

**A note the next backend owner needs.** These 38 files are real migrations with real
reasoning in their comment headers — they are *not* scratch.

**For the full and authoritative statement of the migration situation, read `SCHEMA.md` §8
mismatch 7. Do not restate it here or anywhere else.** That single-location rule exists
because this fact has now been wrong in this repository twice, in up to eight documents at a
time, each copy re-derived rather than read. In brief: 237 migrations are applied per the
database ledger; the repo cannot rebuild the schema. KAN-33's original premise was wrong.

### Tests, tooling, config

| Path | MA | NS | VC | AS | TA | Owner / rule |
|---|:--:|:--:|:--:|:--:|:--:|---|
| `test/**` | R | **W** | — | — | R | Any agent may add tests **for code it owns**. NS owns notification tests. Tests for unowned slices are UNOWNED. Nobody deletes another owner's test. |
| `pubspec.yaml` — version string | R | — | **W** | R | R | version-control owns bumps, including every mirrored copy of the version. |
| `pubspec.yaml` — dependencies | R | R | R | R | R | **UNOWNED — nobody writes it.** Adding a dependency is an architectural decision; it needs a `DECISIONS.md` entry first. |
| `ios/**` | R | R* | — | **W** | R | AS owns it. *NS may change push entitlements and APNs config, and must say so in its status entry so AS is not surprised at submission. |
| `android/**` | R | R* | — | — | R | **UNOWNED — nobody writes it,** except *NS for FCM channel and manifest changes. |
| `web/**` | R | R* | — | — | R | **UNOWNED — nobody writes it,** except *NS for the web-push service worker. |
| `scripts/**` | R | — | **W** | — | R | version-control (it owns `cloudflare-build.sh`). |
| `.claude/agents/**` | **W** | — | — | — | R | master-analyst. Closed loop — see §2. |
| `.claude/skills/**` | **W** | — | — | — | R | master-analyst. |
| `.claude/settings*.json`, `.mcp.json` | — | — | — | — | — | **UNOWNED — the PO writes these.** No agent edits its own permissions or MCP wiring. This is a closed-loop rule with teeth: an agent that can edit `settings.local.json` can grant itself anything in this matrix. |
| `.claude/agent-memory/<self>/**` | **W** | **W** | **W** | **W** | **W** | Each agent writes its own memory directory and **only** its own. |
| `.claude/agent-memory/<other>/**` | R | R | R | R | R | Read to understand a teammate. Never write. |
| `CLAUDE.md` | R | R | R | R | R | **UNOWNED — the PO writes it.** Agents propose changes through `DECISIONS.md`; they do not edit it. |

### Docs

| Path | MA | NS | VC | AS | TA | Owner / rule |
|---|:--:|:--:|:--:|:--:|:--:|---|
| `docs/README.md` | **W** | R | R | R | R | master-analyst. The index. It must be corrected whenever a file's state changes — a stale index is the first thing a new agent reads |
| `docs/MANIFESTO.md`, `CONTRACT.md`, `AGENTS.md`, `WORKFLOWS.md`, `DECISIONS.md`, `CONVENTIONS.md` | **W** | R | R | R | R | master-analyst. Closed loop — see §2. **TA reads these to run Gate 2 and may never write them** |
| `docs/BRIEF.md` | **W** | R | R | R | R | master-analyst transcribes; **content comes from the PO only.** Never inferred from code. |
| `docs/ARCHITECTURE.md`, `SCHEMA.md`, `ROADMAP.md`, `PROJECT_STATE.md` | **W** | R | R | R | R | master-analyst |
| `docs/LEARN.md` | **A** | **A** | **A** | **A** | **R** | **Append-only by every agent — with one exception: `task-auditor` is `R`.** `LEARN.md` is a governance document it reviews (it graded KAN-15, a `LEARN.md` ticket). Appending there would make the reviewer an author of what it later approves — the failure §2 names. **When it has a lesson, it hands the append-ready text to master-analyst, who appends it.** That is not a workaround; the content lands and the boundary holds. See §6. |
| `docs/STATUS.md` | **W** | R | R | R | R | master-analyst reconciles it. **This is the channel the PO reads.** |
| `docs/status/master-analyst.md` | **W** | R | R | R | R | Own status only |
| `docs/status/notifications-specialist.md` | R | **W** | R | R | R | Own status only |
| `docs/status/version-control.md` | R | R | **W** | R | R | Own status only |
| `docs/status/app-store-submission-fixer.md` | R | R | R | **W** | R | Own status only |
| `docs/status/task-auditor.md` | R | R | R | R | **W** | **The only file `task-auditor` writes in this repo.** Own status only |
| `docs/NOTIFICATIONS.md` | R | **W** | R | R | R | notifications-specialist. Drifted — its subject was rewritten after it was written |
| `docs/LOCATION.md` | R | — | — | — | R | **UNOWNED — nobody writes it.** |
| `docs/screen-report.md`, `docs/agents/` | **W** | — | — | — | R | master-analyst. Both currently untracked by git — see KAN-14. |

### Release

| Path | MA | NS | VC | AS | TA | Owner / rule |
|---|:--:|:--:|:--:|:--:|:--:|---|
| Git — commit, branch, merge, tag, push | R | — | **W** | — | R | **version-control only.** No other agent runs a write git command. |
| Branch `main` | — | — | R | — | — | **Nobody pushes it directly, version-control included.** It deploys straight to app.dabbler.pro. Reached only by PR from `Canary`. |
| Cloudflare Pages project `webapp` | — | — | **W** | — | — | version-control |
| App Store Connect | — | — | R | **W** | — | app-store-submission-fixer |
| Google Play Console | — | — | **W** | — | — | version-control |
| Jira — the `In Review` column: verdict comment + transition to Done or To Do | R | R | R | R | **W** | **task-auditor only.** Its authority is on the board, not in the tree. master-analyst may transition its own tickets **as far as In Review and no further** |

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
