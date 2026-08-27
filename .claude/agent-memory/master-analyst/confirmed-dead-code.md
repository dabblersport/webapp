---
name: confirmed-dead-code
description: Files and slices verified unreachable on 2026-08-26 and awaiting a deletion decision — re-check existence before recommending
metadata:
  type: project
---

Verified unreachable at HEAD `1b83967` (2026-08-26). **Verify each still exists before
recommending deletion** — some may already be gone.

**Whole slices, 0 external importers, no routes:**
`lib/features/payments/` (503 LOC) · `lib/features/audit_safety/` (145) ·
`lib/features/squads/` (136) · `lib/features/display_names/` (90) ·
`lib/features/bench_mode/` (84).

**Whole files, 0 importers (6,213 LOC total):**
- `misc/presentation/screens/create_game_screen.dart` (763) + its `.broken` twin (632)
- `social/presentation/screens/create_post_screen.dart` (1,196)
- `rewards/presentation/screens/rewards_analytics_dashboard.dart` (1,100)
- `explore/presentation/screens/explore_nearby_screen.dart` (864), `payment_sheet.dart` (326), `booking_summary_modal.dart` (250)
- `games/presentation/screens/games_nearby_screen.dart` (722), `create_game/game_screen_4_access_rules.dart` (335)
- `venues/presentation/screens/venues_nearby_screen.dart` (619)
- `misc/presentation/screens/rebook_flow.dart` (38)

**Orphan classes inside otherwise-live files:** `ManageProfilesSheet`
(`profile/.../profile_screen.dart`) · `TransactionDetailsSheet`
(`misc/.../transactions_screen.dart`) · `FavoriteVenuesScreen` + `VenueCard`
(`explore/.../sports_screen.dart`) · `SportsHistoryScreen` (file itself is live).

**Two large stacks blocked on PO decisions, NOT yet safe to delete:**
- `lib/features/rewards/` — entry point `presentation/providers/rewards_providers.dart` has
  0 importers ⇒ 19,560 LOC unreachable. **Survivors if deleted:** `check_in_providers.dart`,
  `controllers/check_in_controller.dart`, `widgets/early_bird_check_in_modal.dart`,
  `widgets/check_in_progress_indicator.dart` (~985 LOC, all genuinely live).
- `lib/features/games/data/**` + `domain/usecases/**` (5,674 LOC) — consumed only by
  `games_providers.dart`, which no screen watches. Live game path is
  `presentation/controllers/game_view_controller.dart` via `v_game_card` + RPCs.

**Why:** these are the audit's largest single lever (~27k LOC), but two of them need a
product decision (is rewards being built? is the clean-arch stack the target?) before
anyone deletes. Everything above that line is unblocked.
**How to apply:** hand the unblocked items to a Flutter cleanup agent as one batch; hold the
rewards/games stacks until the PO answers Q1 and Q2 in `docs/PROJECT_STATE.md`.

See [[audit-baseline-2026-08-26]] and [[audit-false-positives]].
