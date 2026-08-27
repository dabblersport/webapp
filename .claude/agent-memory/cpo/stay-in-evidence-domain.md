---
name: stay-in-evidence-domain
description: The CPO judges the business against the corpus and must take code facts from master-analyst or cto — three code claims shipped wrong on 2026-08-27 while every corpus claim held
metadata:
  type: feedback
---

**Judge the business against the corpus. Never establish a fact about the codebase by
running your own grep.** Code facts come from `docs/PROJECT_STATE.md`, or from `cto` /
`master-analyst` via `grill-peer` **with the command that produced them attached**.

**Why:** on 2026-08-27 the KAN-39 launch-readiness assessment shipped with three wrong code
claims. One — *"users cannot switch to Arabic"* — was **false**, was ranked a promotion
blocker, and was dispatched to `cto` as KAN-53, a ticket to build a screen that already
works. Another miscounted 4 empty methods as 18. A third said *"no cricket feature"* when
cricket has 107 references. **Every corpus finding in the same document held up** — C1
(the 13–27× Year-1 gap), C4 (the App Fee against Permanent Truth 1), the missing beta
record. The errors clustered exactly where the seat left its evidence domain.

Two compounding causes, both of which have to be handled:

1. **The shared record is not self-certifying.** `PROJECT_STATE.md` WIRE-10 attributed a
   "Coming Soon" placeholder to `/settings/language`; it belongs to `/language_selection`,
   an orphaned route. Reading the record faithfully still produced a false claim.
2. **I silently upgraded a MED/small finding into a launch-gate P0** and never took it back
   to the agent who logged it.

**How to apply:**

- Before any code claim becomes a **blocker, a P0, or a ticket**, confirm it with whoever
  measured it and require the command. Escalation demands re-verification.
- **Attribute measured claims in the text** — "per `PROJECT_STATE.md` WIRE-10" is checkable
  in seconds; the same sentence stated flatly launders someone else's error bars into mine.
- Verify before dispatching. A wrong claim in a document costs a correction; the same claim
  in a ticket sends an agent to build something that exists.
- **The tell does not exist from the inside.** Confidence, specificity and `file:line`
  citations were identical across the well-grounded and ungrounded halves. Do not rely on
  feeling uncertain — rely on the domain boundary.

Recorded as decision `P-006` and as a generalising lesson in `docs/LEARN.md`.
Related: [[corpus-map]], [[launch-gate-is-13b]], [[corpus-contradictions]].

## The reciprocal half, learned the same day

A correction that **softens** your finding earns the same check as one that hardens against
you. Later on 2026-08-27 `master-analyst` re-checked WIRE-09 and reported that all seven
placeholder routes are unreachable — *"Zero navigation sites"* for all six owning route
constants — which would have retired **B4**, one of my four remaining blockers.

I checked. It is right for five constants and **wrong for `socialChat`**, the one B4 rests
on: `user_profile_screen.dart:1475` pushes it, the Message button above it is
unconditional, the screen is routed, and the route's `FeatureFlags.messaging` guard does
not fire because the flag is `true` (`feature_flags.dart:53`). The true figure is **7
placeholder routes, 6 unreachable, 1 reachable on every user profile.** Their own
`INDEX.md` §11b still lists it as the #1 worst finding — the re-check overcorrected.

**How to apply:** relief is a bias like any other. Had I accepted it, I would have dropped
a real blocker on a blanket claim. The rule is symmetric — *a blocker earns one look
regardless of source, and regardless of which way the correction cuts.*

## Before quoting any figure from master-analyst

`.claude/agent-memory/master-analyst/INDEX.md` **§11b** is a "corrected facts — do not quote
the old version" table, added 2026-08-27 after several figures moved (colour count 233→317,
settings throw count 25→24, "no schema history"→237 migrations, view census 49/25/8 →
71/49/19, and WIRE-10). **Check it before citing anything of theirs read earlier in a
session.** When I cite one of their numbers without re-verifying it, I say so in the text.
