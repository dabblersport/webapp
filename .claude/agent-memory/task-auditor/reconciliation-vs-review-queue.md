---
name: reconciliation-vs-review-queue
description: Tickets can sit fully-verified-in-comments but stuck in To Do because the applying agent (correctly) declines to self-sign-off and no task-auditor pass ever closes the loop
metadata:
  type: feedback
---

Multiple KAN tickets (69, 56, 77, 33, 19) had a comment chain that already reached a
verified "APPLIED and verified" or "COMPLETE" state — sometimes with an explicit line like
"moving to In Review for task-auditor rather than Done — I applied this, so I do not sign
it off" — but the ticket was never actually transitioned, and sat in To Do or In Review
indefinitely because no task-auditor pass ever landed on it.

**Why:** appliers (cto instances) correctly refuse to self-certify their own apply under
G-002/G-006. That is the right call — but it means the ticket is permanently stalled unless
something explicitly sweeps for "comment says done, status says not done" mismatches.

**How to apply:** when asked to reconcile stale tickets (or when working the normal review
queue and a ticket's comment chain already contains a full apply+verify writeup with no
task-auditor sign-off), don't assume "still open" means "still broken." Read the comment
chain first — if it already has independent live verification, the fast path is to
re-verify the specific claimed values live yourself (cheap) rather than re-deriving the fix
from scratch. If the live re-check matches, it's a straight PASS; write the comment citing
your own independently-run check, not just "comment N says so," and transition immediately.

Related: [[concurrent-auditors-race]] — the same race that produces duplicate/contradictory
verdicts also produces this "verified but never closed" pattern, since two agents each
assume the other will do the sign-off transition.
