---
name: concurrent-auditors-race
description: Multiple task-auditor instances can review the same In Review column concurrently — verify final Jira state directly rather than trusting a fork's narrative, and expect same-section contradictory verdicts
metadata:
  type: project
---

On 2026-08-29 the team ran 6+ named task-auditor instances (task-auditor through
task-auditor-6, plus this one as task-auditor-7) in the same session, alongside a
board-survey fork. When I dispatched 3 parallel forks to clear a 13-ticket backlog,
one fork's own report claimed it "worked through KAN-8,17,20" when it had only been
assigned KAN-40-44 — it had actually just observed those tickets already transitioned
by a different concurrent auditor and mis-described that as its own work in the
summary.

**Why this matters:** a fork's completion narrative is not authoritative about what
it actually did versus what it found already done by a peer. It can also mean two
reviewers evaluate the same governance-doc section on the same day with opposite
conclusions — KAN-38 (view-triage ticket) claimed to fully resolve SCHEMA.md §2a
(all 17 views verdicted), and its fix comment 10125 was itself passed by another
auditor instance. Minutes/hours later my KAN-19 review of the same §2a section found
3 CRITICAL-leaking views still missing verdicts, contradicting KAN-38's own closure
claim. Both reviews cited real file:line evidence — the most likely explanation is
the file was edited between the two review passes, not that either reviewer was
sloppy.

**How to apply:**
1. After dispatching parallel review forks, always re-query Jira directly
   (`searchJiraIssuesUsingJql` for final `status`) rather than trusting the forks'
   self-reported summary tables — reconcile before reporting to the PO/team-lead.
2. When a ticket you're failing touches the same doc section a *different* ticket
   just passed, re-read that section fresh (don't reuse cached findings) — the file
   may have changed between passes, and the discrepancy itself is worth flagging
   upward rather than silently picking one verdict as "right."
3. Flag any such contradiction explicitly in your report to team-lead/PO — it's a
   signal of either a race condition in the doc, or one of the two reviews being
   wrong, and only a PO-level read of current file state resolves it.

See [[aggregate-updated-per-view-not]] for the specific SCHEMA.md §2a failure mode
(aggregate claims "resolved" while per-item table has gaps) that both KAN-19 and
KAN-38 were independently checking.
