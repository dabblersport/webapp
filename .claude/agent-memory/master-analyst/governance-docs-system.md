---
name: governance-docs-system
description: docs/ is a live governance system with a precedence order — read DECISIONS.md and CONTRACT.md before any task, and write new rules into these files rather than leaving them in chat
metadata:
  type: project
---

`docs/` is a working governance system as of 2026-08-26 (epic KAN-5, 12 files). It is not
reference material — it is the authority, and master-analyst owns and maintains it.

**Precedence when two documents disagree:**
1. `DECISIONS.md` — the newest dated ACTIVE entry wins
2. `MANIFESTO.md` / `CONTRACT.md`
3. `CONVENTIONS.md`
4. everything else

**The losing document is corrected in the same session**, and the correction logged.

**Read before starting any task:** `CONTRACT.md` (may I write this path?) and `DECISIONS.md`
(has this already been ruled on?). Two decisions are **blocking freezes** — 015 `rewards`
and 016 the clean-architecture stack. Do not touch either until KAN-29 / KAN-30 are answered.

**Files I own and write:** all governance docs, `PROJECT_STATE.md`, `STATUS.md`,
`status/master-analyst.md`, my memory.
**Files I never write:** `.claude/settings*.json`, `.mcp.json`, `CLAUDE.md`, and the other
three agents' `status/*.md`. `LEARN.md` is **append-only, including for me** — never
restructure, reorder or deduplicate it; correcting a line means appending a dated correction
and leaving the original.

**`BRIEF.md` is deliberately unfilled** and must stay that way until the PO answers its §8.
Product intent is never inferred from this codebase — a year of rework means the code
reflects abandoned directions as much as current ones, and BRIEF sits above ROADMAP in
precedence, so an inferred answer poisons every future scoping decision.

**Why:** everything in `DECISIONS.md` 001–014 previously existed only in session context and
CLAUDE.md prose. Reconstructing it cost a full task, several rationales could only be
inferred, and one (the Resend SMTP move) was invisible to the repo entirely.
**How to apply:** decision 018 is binding — every new instruction, correction or lesson is
written into these files **as part of the task that produced it**. Session end is not a
valid resting place for a rule.

See [[audit-baseline-2026-08-26]], [[confirmed-dead-code]], [[jira-tracking-convention]].
