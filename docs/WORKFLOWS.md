# docs/WORKFLOWS.md — Workflows and Handoffs

**Owner:** master-analyst (write) · all agents (read)
**Last updated:** 2026-08-26
**Purpose:** The procedure. `AGENTS.md` carries the shape of the roster; this carries how
a task that crosses two or three agents actually moves, end to end.

---

## 1. THE TASK LIFECYCLE

**Jira is the single source of truth for progress.** Not the terminal, not an agent's
final message, not this repo. If the board does not show it, it did not happen.

```
PO request
   → Epic (the container)
      → child Tasks (the trackable units)
         → To Do → In Progress → In Review → Done
```

**Rules that keep that true:**

1. **A task is transitioned to In Progress when work starts**, not retroactively.
2. **Findings are commented on the ticket as the work produces them**, not saved for a
   summary at the end. The board should tell the story without anyone opening the repo.
3. **A task moves to Done only when its acceptance criteria are met** — or to In Review
   first, where the work needs a second pair of eyes (§3).
4. **An Epic closes only when its children are Done.** If children remain open by design —
   follow-ups, deferred work — say so explicitly in the closing comment. A green Epic
   above open CRITICAL children is a lie the board tells.
5. **No task is complete without its status entry** (`MANIFESTO.md` §5).

---

## 2. JIRA CONVENTIONS

| Setting | Value |
|---|---|
| Site | `dabbler.atlassian.net` |
| cloudId | `18c8e9f5-d139-4e03-b5d8-89122cc14937` |
| Project key | `KAN` — "Dabbler Team", **team-managed** |
| Transition IDs | To Do `11` · In Progress `21` · In Review `31` · Done `41` |

**Epics do not render as cards on a team-managed board. Tasks do.**

This is the rule that was got wrong once, and it is why every trackable unit is filed as
`issueTypeName: "Task"` with a `parent` Epic. An Epic alone is invisible to the person
watching the board — the work exists in the API and nowhere a human is looking.

**Transition IDs are project configuration, not a constant.** Call
`getTransitionsForJiraIssue` rather than trusting the table above; it is a convenience, not
an authority.

**Issue keys are not assigned sequentially.** Creating twelve tickets does not give you
twelve consecutive keys — KAN-5, 8, 10, 12 were interleaved with another epic's children in
the same session. **Never write a ticket key into a comment before the ticket exists.**
Create first, read the returned key, then reference it. Getting this wrong requires editing
a comment afterwards, which is recoverable but visible.

**Labels in use:** `audit`, `security`, `follow-up`, `bug`, `cleanup`, `config`,
`quality`, `po-decision`.

---

## 3. THE REVIEW GATE

`In Review` is not decoration. A ticket sitting there has a claim attached to it — "this
is done" — and the gate is where that claim is tested rather than accepted.

**Reviewing is a distinct act with its own skill.** Use the `task-review` skill, which
applies two gates: the ticket's own acceptance criteria, and alignment with the governance
docs in `docs/`. The outcome is a written verdict and a transition — to `Done`, or back to
`To Do` with what is missing.

**What goes through review:**

| Work | Review required? |
|---|---|
| Anything touching a contended file (§7) | **Yes** |
| Any schema or RLS change | **Yes** |
| Anything that closes a `security`-labelled ticket | **Yes** |
| A release to `main` | **Yes** — the launch gate is the review |
| Documentation owned by the writer | No — straight to Done |
| An audit refresh | No — master-analyst owns the output |

**The reviewer is never the author.** An agent does not review its own ticket. Where no
second agent exists for a domain, the review goes to the PO rather than being skipped —
skipping is not the same as being unable to run it, and the ticket should say which
happened.

---

## 4. THE HANDOFF RULE

**Everything routes through the master. Agents do not brief each other directly.**

An agent finishing a step reports to master-analyst / the orchestrating session, which
decides what happens next and briefs the following agent. Agent A does not hand work
straight to Agent B.

**Why, given direct messaging is technically available:**

- **Subagents cannot spawn subagents.** Nesting is off by default and version-dependent, so
  a chain assembled from inside the chain breaks in a way that is hard to see. Parallelism
  and sequencing come from the top.
- **A silent fallback beats an error here.** `.claude/agents/` is registry-scoped to the
  working directory, and an unrecognised `subagent_type` falls back to a generic agent with
  no error raised. An agent-to-agent handoff can therefore land in a generic agent that
  answers plausibly and owns nothing.
- **The contract is enforced at one point or not at all.** The master knows the permission
  matrix; a worker deciding who to hand to next is deciding scope, which is not its call.

**The exception:** a direct message is fine for a *question* — "does the notification
schema already have a `read_at` column?" — where the answer changes nothing and creates no
work. The moment a handoff creates work, it goes through the master.

---

## 5. NAMED WORKFLOWS

### W1 — A feature change

1. master-analyst confirms the slice's state in `PROJECT_STATE.md`, and that the slice has
   an owner in `CONTRACT.md`. **If the slice is UNOWNED, this stops here** — 23 of 25 are.
2. Domain agent implements, following the build order (`MANIFESTO.md` §2): database →
   constants → repository → providers → screen → route.
3. Domain agent writes tests for what it built and runs `flutter analyze` + `flutter test`.
4. Review gate (§3) if a contended file was touched.
5. version-control commits, pushes `Canary`, verifies canary.dabbler.pro.

| Step | Agent | Receives | Produces | Done when |
|---|---|---|---|---|
| 1 | master-analyst | The request | Slice state + owner confirmed | Owner named, or STOP |
| 2 | domain agent | Scope + owner | Code through step 6 of build order | A route reaches it |
| 3 | domain agent | Its own code | Tests | `analyze` 0 errors, `test` passes |
| 4 | reviewer | The diff | Verdict | Done, or back to To Do |
| 5 | version-control | Approved work | A verified Canary deploy | **The site shows it** |

### W2 — A schema change

1. Backend agent inspects live state first — `list_tables`, `get_advisors`, and a probe as
   `anon`. **Never work from the migration file alone**; the remote is the truth, and
   **`SCHEMA.md` §8 mismatch 7 is the authoritative statement of the migration situation —
   read it, do not restate it.** In brief: 237 migrations are applied per
   `supabase_migrations.schema_migrations`; the 38 `.sql` files tracked at
   `supabase/schema/` are outside the path the CLI reads, so `db diff` and
   `migration list` see nothing.
2. Writes the change **as a migration**, plus its RLS policies in the same change.
3. Verifies empirically: query as `anon` and as `authenticated`, with a control query that
   should return 0 to prove the probe works.
4. Adds any new identifier to `supabase_config.dart`.
5. Domain agent wires the client side.
6. Review gate — **mandatory** for schema.
7. version-control ships.

| Step | Agent | Receives | Produces | Done when |
|---|---|---|---|---|
| 1 | backend agent | The requirement | Current live state | Probed, not assumed |
| 2 | backend agent | State | Migration + policies | Both in one change |
| 3 | backend agent | Applied change | Probe results | `anon` returns what it should, control returns 0 |
| 4 | backend agent | New names | Constants | No literal in `lib/` |
| 5 | domain agent | Constants | Client wiring | Reachable |
| 6 | reviewer | The change | Verdict | Approved |
| 7 | version-control | Approved | Deploy | Verified on canary |

### W3 — A release

1. version-control confirms the launch gate (`MANIFESTO.md` §4) — **all seven items**.
2. Bumps the version in every place it is duplicated.
3. Commits, pushes `Canary`.
4. **Waits for the Cloudflare build and loads canary.dabbler.pro.** A green push is not a
   green deploy.
5. Opens a PR from `Canary` into `main`. **Never a direct push.**
6. After merge, confirms app.dabbler.pro serves the change.

| Step | Agent | Receives | Produces | Done when |
|---|---|---|---|---|
| 1 | version-control | Work on Canary | Gate check | All 7 pass, or STOP |
| 2 | version-control | Gate passed | Version bump | Every copy updated |
| 3–4 | version-control | Commit | Canary deploy | **canary.dabbler.pro shows it** |
| 5 | version-control | Verified canary | PR | PR open, never a push |
| 6 | version-control | Merge | Production | **app.dabbler.pro shows it** |

**As of 2026-08-26 this workflow cannot complete.** Launch gate item 4 fails — KAN-24 and
KAN-25 are open unauthenticated data leaks.

### W4 — An audit refresh

master-analyst alone. No handoffs.

1. Read the existing `PROJECT_STATE.md` first.
2. Run the `project-audit` skill's five phases.
3. Mark fixed findings `RESOLVED`, update moved numbers, tag new ones `NEW`.
4. Append a dated changelog row.
5. Report deltas against the baseline in `.claude/agent-memory/master-analyst/`, not
   absolutes.

Output is findings, never fixes. Each finding names the work it implies and who should own
it — an audit that does not become assignable work has failed.

### W5 — An App Store rejection

1. app-store-submission-fixer diagnoses against the cited guideline.
2. If the fix is inside `ios/**` or submission metadata, it implements directly.
3. **If the fix requires app code outside its scope, it stops and reports.** It does not
   reach into a slice it does not own.
4. version-control bumps and ships.

| Step | Agent | Receives | Produces | Done when |
|---|---|---|---|---|
| 1 | app-store-submission-fixer | The rejection text + cited guideline | A diagnosis naming the guideline and the offending behaviour | The guideline is identified, not guessed |
| 2a | app-store-submission-fixer | Diagnosis, fix **inside** `ios/**` or ASC metadata | The fix + a Resolution Centre reply | Change made, reply drafted, **never claims a fix it cannot evidence** |
| 2b | app-store-submission-fixer | Diagnosis, fix **outside** its scope | **A report naming the slice and the change needed. STOPS** | The report exists. It does **not** reach into a slice it does not own (`CONTRACT.md`) |
| 3 | master-analyst | A 2b report | A ticket, and a decision on who can own it — **23 of 25 slices are UNOWNED**, so this often escalates to the PO | An owner is named, or the PO is asked |
| 4 | version-control | An approved fix | Version bump + build + upload | Build accepted by App Store Connect |

**The branch at step 2 is the whole point of this workflow.** Most App Store rejections
(Guideline 5.1.1 registration walls, 1.2 UGC controls) need app-code changes outside
`ios/**`. Step 2b is the common path, not the exception, and it terminates in a report
rather than a fix.

Note: a rejected marketing version must be **bumped, not just re-built** — a new build
number under a rejected version does not re-open review.

---

## 6. THE STOP CONDITION

A workflow halts mid-flight when any of these is true:

- **An open question whose answer changes the work.** Stopping is the correct output.
  A guess that keeps the session moving costs more than the pause.
- **A gate fails** — `flutter analyze` errors, a failed test, an unverified deploy.
- **The task needs a path its agent does not own** (`CONTRACT.md`).
- **The work is frozen by a decision** — `rewards` (015), the clean-arch stack (016).
- **A CRITICAL security finding is open and the workflow ends in a release.**

**What happens to the remaining steps:** they do not run. The ticket goes back to `To Do`
with a comment naming the blocker, and the blocker is added to `MANIFESTO.md` §6 if it
blocks more than this one task.

**What must not happen:** the agent must not substitute adjacent work to have something to
show. A halted task that reports the blocker is a success. A halted task that quietly
delivers something else is worse than one that delivers nothing, because the blocker stays
invisible.

---

## 7. THE CONTENTION PROTOCOL

Four files are touched by nearly every feature change, and they are the practical limit on
how many agents can run at once:

`lib/app/app_router.dart` · `lib/providers.dart` ·
`lib/core/config/feature_flags.dart` · `lib/core/config/supabase_config.dart`

**The procedure:**

1. **Before dispatching parallel agents, the master checks which of the four each task
   needs.** Tasks needing the same file are **sequenced, not parallelised**. This check
   happens at dispatch, not after a conflict.
2. **An agent in one of these files appends only.** Add your import, route, export, or
   constant. Do not reorder, regroup, reformat, or tidy.
3. **Your feature's block only.** Do not fix a neighbouring feature's entry, however
   obviously wrong. Report it (`MANIFESTO.md` R8).
4. **Never delete another agent's entry.** Removing a dead flag or route is cleanup work
   with its own ticket and owner.
5. **A diff touching one of these files goes through the review gate** (§3).
6. **`supabase_config.dart` is add-only for values.** Changing an existing constant's value
   redirects the whole app and needs a `DECISIONS.md` entry first.

**How many agents can safely run in parallel:** as many as have disjoint file sets. In
practice that means **one agent per feature slice, plus version-control, plus
master-analyst** — and only one of those in a contended file at a time. Parallelism beyond
that produces conflicts faster than it produces work.
