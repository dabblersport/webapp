# docs/ — The Dabbler documentation system

Modelled on the governance system proven in the Moataz_Next project. Three layers.

## 1. GOVERNANCE — the rules agents are judged against
The master-analyst writes these. **No other agent may write them**, because an agent
must never be able to edit the rule it is judged by.

| File | What it is |
|---|---|
| `MANIFESTO.md` | The non-negotiables. Rules of engagement, build order, definition of done. |
| `CONTRACT.md` | Permission boundary + information contract. Who writes what; what gets learned where. |
| `AGENTS.md` | The roster. What each agent is and owns. |
| `WORKFLOWS.md` | The procedure. How a task moves between agents, tied to Jira. |
| `DECISIONS.md` | **The tie-breaker.** When docs disagree, the newest dated decision wins. |
| `CONVENTIONS.md` | Coding conventions, chosen so an agent never has to ask. |

## 2. PROJECT TRUTH — what this thing is
| File | What it is |
|---|---|
| `BRIEF.md` | Why Dabbler exists. Internal only. Filled from the PO, never inferred from code. |
| `ARCHITECTURE.md` | How the system is actually put together. |
| `SCHEMA.md` | Supabase: tables, RLS, buckets, RPCs, triggers, edge functions. |
| `ROADMAP.md` | Scope buckets and exit criteria. |
| `PROJECT_STATE.md` | **Measured** state of the codebase. The audit output. |

## 3. LIVING RECORDS — what happened and what we learned
| File | Write rule |
|---|---|
| `LEARN.md` | **Append-only, by every agent.** Never restructured, reordered, or tidied. |
| `STATUS.md` | master-analyst writes. **The channel the PO reads.** |
| `status/<agent>.md` | Each agent writes its own, and only its own. |

---

## THE PRECEDENCE ORDER

When two documents disagree:

1. `DECISIONS.md` — the newest dated, ACTIVE decision wins.
2. `MANIFESTO.md` / `CONTRACT.md`
3. `CONVENTIONS.md`
4. Everything else.

**The losing document is corrected in the same session**, and the correction logged.

## THE AGENT ROSTER — as of 2026-08-28

Seven agents, in the structure the PO set: leadership that thinks and can reject
work with reasons, a quality gate, executives that build.

| Agent | Layer | Owns |
|---|---|---|
| `master-analyst` | Leadership | Measured truth. `PROJECT_STATE.md`, `SCHEMA.md` §§1–8/10, `STATUS.md`, this file |
| `cpo` | Leadership | Product & protect. `BRIEF.md`, `ROADMAP.md`, product `DECISIONS.md` entries |
| `cto` | Leadership | Technical direction. `ARCHITECTURE.md`, `CONVENTIONS.md`, `SCHEMA.md` §11, technical `DECISIONS.md` entries |
| `task-auditor` | Quality gate | The Jira `In Review` column — two gates, Done or back to To Do |
| `version-control` | Executive | Commits, Canary, deploys, releases |
| `notifications-specialist` | Executive | `lib/features/notifications/**`, notification schema/RLS |
| `app-store-submission-fixer` | Executive | Apple review, ASC metadata, submission blockers |

Full charters, skills and boundaries: `AGENTS.md`.

## FILE STATUS — as of 2026-08-26

All twelve files were filled under epic **KAN-5**, one Jira task per file.

| File | State |
|---|---|
| `MANIFESTO.md` · `CONTRACT.md` · `AGENTS.md` · `WORKFLOWS.md` · `DECISIONS.md` · `CONVENTIONS.md` | **Filled** |
| `ARCHITECTURE.md` · `SCHEMA.md` · `ROADMAP.md` · `PROJECT_STATE.md` | **Filled** |
| `LEARN.md` · `STATUS.md` · `status/master-analyst.md` | **Filled** |
| `BRIEF.md` | **AWAITING PO INPUT** — structure drafted, questions listed in its §8. Nothing about product intent may be inferred from the code |
| `status/notifications-specialist.md` · `status/version-control.md` · `status/app-store-submission-fixer.md` | **Spec only** — each belongs to its agent and is filled on that agent's first task. master-analyst never writes into them |

**Also in this directory, outside the governance system:** `LOCATION.md` and
`NOTIFICATIONS.md` (pre-existing domain notes — `NOTIFICATIONS.md` has drifted; its
subject was rewritten after it was written) and `screen-report.md` (a prior audit,
2026-08-17, consistent with `PROJECT_STATE.md`).
