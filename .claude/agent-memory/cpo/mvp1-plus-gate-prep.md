---
name: mvp1-plus-gate-prep
description: The MVP 1+ checklist is a retrofit promotion gate, not a launch gate — the app already shipped; plus the two P0s nobody owns
metadata:
  type: project
---

**"MVP 1+ launch checklist" is not the corpus's launch gate.** The app is live in two
stores; `13a`–`14` were all written for a product that had not shipped. The real question is
the promotion gate: what must be true before spending acquisition money, plus what ships
next.

**Why:** the corpus's launch apparatus assumes a go/no-go that was already taken. Judging
current state against it literally produces nonsense (P0-1 "store approval" is trivially
green while the gate it belongs to is moot).

**How to apply:** when a launch/promotion/MVP-scope question arrives, split it — Part A
promotion gate (judge against [[launch-gate-is-13b]]'s ten P0s), Part B next-release scope
(judge against `docs/BRIEF.md` §5 Phase 1A commitments). Draft:
`docs/briefs/MVP1-PLUS-LAUNCH-CHECKLIST-DRAFT.md`, written 2026-08-29, supersede and delete
it once rulings land in `DECISIONS.md`.

**The finding worth carrying forward: P0-7 (monitoring) and P0-8 (rollback) are the only two
P0 criteria with no ticket and no owner.** Every other red P0 has one. Without P0-7, P0-2
("48h, zero P0 bugs") is unfalsifiable. Without P0-8, a bad promotion is unrecoverable —
which is `13b`'s entire stated rationale for holding.

**Also settled 2026-08-29:** KAN-30 is not a product question — the corpus contains **no**
reference to internal code architecture in any of the 26 documents. Reassigned to `cto`.
Do not re-litigate; the search was exhaustive.

Related: [[corpus-map]], [[corpus-contradictions]], [[launch-gate-is-13b]],
[[stay-in-evidence-domain]].
