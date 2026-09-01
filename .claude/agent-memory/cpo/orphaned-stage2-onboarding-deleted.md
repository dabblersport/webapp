---
name: orphaned-stage2-onboarding-deleted
description: P-026 — the orphaned stage-2 onboarding chain (sports/preferences/privacy/completion) is ruled DELETE, not wired up; the reasoning and the alternative offered
metadata:
  type: project
---

**P-026 (2026-08-31, cpo):** the four-screen stage-2 onboarding chain under
`onboarding_scenarios/profile/` — ~4,900 lines including a *third* onboarding controller
(`lib/features/profile/services/onboarding_controller.dart`) and `onboarding_gamification.dart` —
is **deleted** as part of KAN-92, not finished.

**Why:** it is in neither MVP 1 nor the enumerated MVP 1+ list ([[mvp1-is-player-only]] / P-020);
its completion path writes `user_points`, which P-020 and P-024 gate for MVP 1; and it adds a
third profile write path, the exact defect KAN-92 exists to remove. Zero inbound references
outside `app_router.dart:710-747` and the route constants, so deletion is mechanical.

**How to apply:** if stage-2 onboarding comes back, the goal is "profiles complete enough to
match on" — the cheap instrument is a completion nudge on the existing profile surface, not a
blocking wizard. The PO may overrule, but only by moving P-020 and P-024 explicitly.

**Precedent worth reusing:** "the PO once described this intent" is not a reason to keep
unreachable code. T-038 Decision 1 established the intent was never implemented; preserving the
attempt as a placeholder for a design with no ticket, scope slot or owner is cost against a maybe.
Git history is the placeholder.
