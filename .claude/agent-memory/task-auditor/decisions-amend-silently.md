---
name: decisions-amend-silently
description: DECISIONS.md entries get amended in place after a ticket is scoped from them — always re-read the current decision text, not just the ticket description, before passing Gate 2.
metadata:
  type: feedback
---

A ticket's Jira description is a snapshot of the governing decision at scoping time. The
decision itself (`docs/DECISIONS.md`) can be amended later — same day, even — with expanded
scope, and the ticket's AC checklist is never updated to match. `[[gate2-decisions-precedence]]`

**Example: KAN-58 / T-004.** Ticket scoped signOut() teardown against T-004 (2026-08-27,
three named caches). T-004 was amended 2026-08-28 to add two more requirements to "this
work": delete the dead `LogoutUseCase` stack (T-007), and classify all 19
SharedPreferences/Hive/FlutterSecureStorage files as session- vs preference-scoped, not just
the three originally named. The implementing agent (flutter-feature-agent) shipped against
the pre-amendment description and passed every AC box it wrote for itself — but failed Gate 2
against the current decision text.

**Why:** the review method is explicit that an ACTIVE decision overrides the ticket "whatever
the ticket said." A ticket's own checklist being fully checked is not evidence the checklist
is still complete.

**How to apply:** every time a ticket cites a DECISIONS.md entry (T-NNN), re-read that entry
in full at review time, not just skim for the decision's title — check for an **Amendment**
block dated after the ticket's original scoping and treat its contents as binding scope, even
though the ticket text never mentions it. Grep for anything the amendment claims as a fact
(file counts, provider names, call sites) — don't trust the amendment's own numbers either,
re-verify them the same way you'd verify the ticket.
