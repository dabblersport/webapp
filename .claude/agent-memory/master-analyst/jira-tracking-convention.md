---
name: jira-tracking-convention
description: master-analyst owns its own Jira tracking under epic KAN-2 — how to create, transition, and comment child Tasks
metadata:
  type: project
---

`master-analyst` tracks its own audit work on the Jira board. Progress must be visible there,
not only in a final summary.

- Site: `dabbler.atlassian.net` · cloudId `18c8e9f5-d139-4e03-b5d8-89122cc14937`
- Project key `KAN` ("Dabbler Team", **team-managed**) · parent epic **KAN-2**
- Create children with `issueTypeName: "Task"` and `parent: "KAN-2"`. **Epics do not render as
  board cards in team-managed projects — Tasks do.** That is the whole reason for child Tasks.
- Transition IDs in this project: **To Do 11 · In Progress 21 · In Review 31 · Done 41.**
  Verify with `getTransitionsForJiraIssue` rather than trusting these — they are project config.
- Issue keys are **not** sequential on creation; KAN-5, 8, 10, 12 were skipped in run 1. Never
  predict a key in a comment before the ticket exists — create first, then reference. (I had to
  edit a comment in run 1 for exactly this.) `addCommentToJiraIssue` accepts `commentId` to
  update a comment in place.
- Out-of-scope work found during an audit (real bugs, security holes, dead code to delete)
  becomes a **separate Task under KAN-2 labelled `follow-up`** — never a fix. Read-only stands.
- Run 1 (2026-08-26) shape: 8 audit Tasks (KAN-3, 4, 6, 7, 9, 11, 13, 14) covering
  completion/reachability · dead code · incompleteness register · security & RLS · tests &
  errors · architecture · agent-skill utilisation · docs & config. Plus 12 follow-ups
  (KAN-24 … KAN-35).

**Why:** the PO wants the board to tell the story without anyone opening the repo.
**How to apply:** on the next audit run, decompose into child Tasks *before* going deep,
transition each In Progress → Done as it completes, and comment headline numbers and anything
alarming onto the ticket as you go. Close the epic last, with the executive summary.

Note on closing KAN-2: its `follow-up` children stay To Do by design, so a green epic does
**not** mean remediation happened. Say so explicitly when closing it.

See [[audit-baseline-2026-08-26]] and [[confirmed-dead-code]].
