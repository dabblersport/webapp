---
name: cto-own-ruling-corrections
description: CTO rulings later found wrong, with the reasoning error that produced each — check these before quoting an earlier decision
metadata:
  type: feedback
---

**Rule: when a prior ruling of mine is already quoted in a ticket, correct it in the ticket AND in
`DECISIONS.md`, never by quiet amendment.** An implementing agent reads the ticket comment, not the
decision log.

**Why:** on KAN-56 (2026-08-28) I ruled `v_mod_queue_open` and `v_safety_overview` were definer
views over `moderation_tickets`, a zero-policy funnel table, and both must be revoked rather than
flipped. `moderation_tickets` is **not a base relation of either view** — `v_mod_queue_open` reads
`moderation_reports` (2 policies) + `profiles` (13), so the flip is available and revoking would
have closed the leak by blanking the admin moderation queue. **I reasoned from a table's name to a
view's name**, and the wrong one was my worked example. Corrected in `T-029`.

**How to apply:** before ruling on any view, resolve base relations from the catalogue:
`pg_depend` JOIN `pg_rewrite` on `r.ev_class = '<view>'::regclass`. Name similarity is not evidence.
This is the same class as the errors in [[verification-lessons]] — anchor to structure, never to a
literal or a name.

Related: [[view-leak-triage-2026-08-29]], [[invoker-flip-join-trap]].
