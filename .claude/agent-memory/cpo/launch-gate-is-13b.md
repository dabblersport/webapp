---
name: launch-gate-is-13b
description: Doc 13b's ten P0 criteria are the corpus's own binding launch gate — judge any launch or promotion question against them, not against opinion
metadata:
  type: reference
---

**When asked whether Dabbler is ready to launch or promote, the bar already exists and is
written down.** Use it. Do not invent a bar.

`13b launch runbook and day-0 operations` (`37dd4c6dd86d805f9602dc53bcd725f5`):

> "The go/no-go gate (Section C) is binding. If a P0 criterion is red, you hold the launch.
> No exceptions, no 'we'll fix it live.'"
> "A held launch costs days. A broken launch costs trust, store ratings (which are hard to
> recover), and the founding-user cohort you only get once. **When in doubt, hold.**"

**The ten P0s — any red = HOLD:** P0-1 store approval · P0-2 48h production stability with
zero P0 bugs · P0-3 auth works in production · P0-4 core loop (create → discover → RSVP)
verified in production · P0-5 payments dormant · P0-6 PDPL consent + export + delete
**verified in production** · P0-7 monitoring live · P0-8 rollback tested and executable solo
· P0-9 RLS verified, no unauthorized data access · P0-10 Arabic RTL on every screen.

Five P1s launch with a written risk note instead.

**Two earlier binding gates:** T-30 (paid infra, backups restore-tested, anon-key probe,
legal live) and T-14 (stores submitted, monitoring alerts *received*, load test passed,
rollback tested, seed content loaded).

**Which gate binds is itself contested.** `14` J10 reduces the same day-of check to one
line — *"stores approved, no serious bugs, monitoring live"* — dropping P0-5, P0-6, P0-8,
P0-9 and P0-10. `14` is the later document (Phase D) and explicitly supersedes 13a–13c on
auth, so the ambiguity is real. **Judge against `13b`'s ten**, and note the ambiguity;
that is what the 2026-08-27 assessment did.

**Two more gates live outside 13b:** `08` Part 2 §A.2 requires verified analytics
instrumentation, and `13d` requires the beta exit criteria (≥80% of 25 organisers ran a
real game; ≥60% "would use instead of WhatsApp").

**As of 2026-08-27:** P0-6, P0-9, P0-10 and `14` H6 are red, plus the `08` analytics gate.
Recorded as decision `P-004` and ROADMAP Wave P. Related: [[corpus-map]],
[[corpus-contradictions]].
