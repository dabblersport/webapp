---
name: contract-boundary-vs-ticket-claim
description: A ticket's own "Owning agent" line is not evidence of CONTRACT.md ownership — check the matrix cell directly, and check who actually made the edit, not who the ticket says should have.
metadata:
  type: feedback
---

KAN-60 (Android backup exclusion) failed Gate 2 on a permission-boundary violation the
ticket text itself obscured. The ticket said "Owning agent: app-store-submission-fixer
(owns the Android manifest and store config)" — that claim was simply wrong.
`docs/CONTRACT.md:171` shows `android/**` as UNOWNED except NS (notifications-specialist)
for FCM channel and manifest changes; AS's cell is `—`. The actual edit was made by
flutter-feature-agent-4, whose cell is `R` (read-only) — no exception at all.

**Why:** a ticket's description is not the repo. An "Owning agent" line, a commit
attribution, or a comment's self-report of what changed are all claims, same as any
other part of the ticket — [[decisions-amend-silently]] and [[spot-check-classification-claims]]
already establish this pattern for other fields; this is the same discipline applied to
CONTRACT.md ownership specifically.

**How to apply:** for every ticket touching a path with a named owner in CONTRACT.md's
matrix (§3), do two independent lookups, never one: (1) grep the matrix row for the path
being touched and read the cell for the agent the ticket claims owns it — cells are
`W`/`R`/`A`/`—`, and an asterisk in the "Owner / rule" text names the exception precisely,
often naming a *different* agent than the one working the ticket; (2) identify who
actually made the commit/diff (check the coordinator's brief, git log author, or ask) and
check *that* agent's cell too — a correct fix by the wrong agent still fails Gate 2.
Do not accept "Owning agent: X" in a ticket description as settling the question — verify
directly against the CONTRACT.md table, both directions.

Also worth checking when a fix is file-granular but the AC asks for key-level precision
(this ticket's AC5 "do not over-exclude" was structurally unachievable given Android's
sharedpref-file-level backup exclusion granularity, which the implementer flagged
honestly but which still made the AC fail as written) — a self-contradicting AC is a Gate
1 fail that needs a PO decision, not a rewrite the reviewer invents.
