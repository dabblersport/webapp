---
name: corpus-answers-the-non-goal-forks
description: The corpus settles four of the five open scope forks and the feature-flag persona contradiction — verdicts to reuse rather than re-derive
metadata:
  type: project
---

`master-analyst` left five scope forks open in `BRIEF.md` because they are not derivable
from code. **The corpus answers four of them**, and the answers are the opposite of what
the codebase implies. Recorded as decision `P-002`; citations in `docs/BRIEF.md` §5.

| Fork | Verdict |
|---|---|
| Payments / booking | **IN SCOPE**, Phase 1B (Month 9). Deleting `lib/features/payments/` deletes deferred product, not dead product. |
| Gamification | **IN SCOPE** — one of the five named product layers. But committed *launch* scope is a **3-tier** Bronze/Silver/Gold surface plus streaks, ≈ the ~985 LOC live check-in path. The 15-tier system and the dashboards are Stage 2 at the earliest. |
| Venue marketplace | **IN SCOPE** — Pillar 1, the first revenue line. |
| Competitive leagues | **IN SCOPE at launch** — `14` E17–E20, *"run a full season"*. |
| In-app chat / messaging | **OUT of Phase 1A.** No launch checklist story exists for it. Whether it is ever in scope: **NOT ESTABLISHED**. |

**Consequence for KAN-29 (rewards):** it is no longer "build or bury". Keep the 3-tier
surface, cut the ~19,560 lines above it, revisit at Stage 2. **KAN-30 (clean architecture)
stays NOT ESTABLISHED** — the corpus is silent on internal architecture; that is the CTO's.

## The feature-flag persona contradiction is also settled (decision `P-003`)

`enablePlayerGameCreation` and `enableOrganiserGameJoining` carry comments asserting that
players cannot create and organisers cannot join, while both values are `true`.
**The values are right; the comments are wrong.**

The rule is about **game type, never access**: a Player creates **casual** games (no fee,
no uplift, off-platform payment); an Organiser creates **organised** games (in-app payment,
uplift) and leagues; **both can join anything**; one account holds up to two simultaneous
profiles. Source: `11 v2` §B.1 table, `14` E2.

**How to apply:** reuse these verdicts rather than re-reading the corpus for them. If a
scoping question touches one of these five, the answer is above. Related: [[corpus-map]],
[[corpus-contradictions]].
