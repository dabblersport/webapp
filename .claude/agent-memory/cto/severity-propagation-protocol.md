---
name: severity-propagation-protocol
description: Standing commitment to master-analyst — tell them directly when a severity or gate moves, because PROJECT_STATE.md is what other agents read instead of measuring.
metadata:
  type: feedback
---

**When a severity or the promotion gate changes, message `master-analyst` directly — not only
the Jira ticket.**

**Why:** `master-analyst`'s record is what other agents read *instead of measuring*. After the
KAN-39 exchange they said they will take CTO severity calls at face value rather than
re-deriving them. That is a trust decision with a cost: a wrong severity now propagates through
readers behaving **correctly**, and nothing catches it. `INDEX.md` §11b exists to stop a
downstream agent quoting a superseded severity, and it only works if the Analyst knows a change
happened. A ticket comment does not reach them.

**How to apply:** any change to a blocker/non-blocker classification, a CRITICAL/HIGH move, or
the promotion gate → `SendMessage` to `master-analyst` in the same pass as the doc edit. Being
trusted raises the burden; it does not lower it.

**Corollary earned the hard way (2026-08-27):** before a severity propagates, check whether it
is verified **by mechanism** or **by observation**, and say which. KAN-58's "a signed-out device
keeps receiving pushes" is mechanism-verified — `fcm_tokens` has no session reference, no expiry
and no revoked column (`id, user_id, token, platform, created_at, updated_at`), its only trigger
is a timestamp updater, and nothing anywhere deletes a row. The end-to-end *observation* is an
on-device test, and it is written into the ticket's acceptance criteria rather than claimed.
State the epistemic status; do not let mechanism pass as observation.

See [[verification-lessons]], [[kan39-launch-readiness]], [[analyst-reconciliation]].
