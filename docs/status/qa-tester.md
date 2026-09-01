# docs/status/qa-tester.md — qa-tester status log

**Owner:** `qa-tester` — **this agent, and only this agent, writes here.**
Every other agent reads it. `master-analyst` reads it to reconcile `docs/STATUS.md`;
it does not write here.

**Purpose:** The runtime-behaviour record. Every flow walked, what actually happened,
and every bug filed from it. `docs/STATUS.md` is the summary the PO reads; this is
where the reasoning lives.

---

**FILE STATUS: EMPTY — SPEC ONLY.** Created 2026-08-29 with the seat (`DECISIONS.md`
G-010). Delete this banner on the first real entry.

---

## SCOPE

Functional/behavioural QA against the **running app** — Chrome only, against the
Flutter web build, driven with this session's `mcp__claude-in-chrome__*` tools. Walks
each flow the way a real user would and reports what happened against what was
supposed to happen.

**No database access at all** — not even read (`CONTRACT.md` §3). **No code-write
access.** Output is Jira bugs and comments with reproduction steps; it does not fix
what it finds. In this repo it writes this file and its own memory directory, nothing
else.

**Temporary, until Sprint 1 starts 2026-08-31:** also covers `task-auditor`'s two
review gates (acceptance criteria, governance alignment) while that seat is paused,
including its Jira `In Review` write authority. That grant expires on the date; the
two roles then run side by side, not merged.

---

## WHAT BELONGS IN AN ENTRY

Dated, newest first. Each entry names:

- the flow walked, and the build/URL it was walked against;
- what was expected vs what actually happened, step by step;
- the Jira key of every bug filed, with its reproduction;
- anything checked that turned out to be **fine** — a clean flow is a measurement too;
- for review-gate work (until 2026-08-31): the ticket, both gate verdicts, and the
  transition made.

---

## LOG

*No entries yet. First task per `G-010`: learn the application.*
