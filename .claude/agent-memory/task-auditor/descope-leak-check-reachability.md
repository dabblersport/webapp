---
name: descope-leak-check-reachability
description: Confirming a descoped feature (P-025 data export) hasn't leaked requires checking whether its UI entry point got wired live, not just whether its ticket exists in the sprint
metadata:
  type: project
---

On 2026-08-31, during a full In Review batch audit, the PO's task brief specifically asked
to confirm nothing from KAN-52/KAN-103 (data export, DESCOPED per `docs/DECISIONS.md` P-025)
had "leaked into anything committed or staged." Checking only for a live Jira ticket
referencing export work would have missed it — there was none. The leak was in the
**uncommitted working tree**, unconnected to any ticket in the review queue:

- `lib/features/profile/services/data_export_service.dart` — 84 lines changed, updating
  internal queries from stale table names (`game_participants`, `audit_logs`,
  `friendships`, `user_media`, `location_data`) to the current live schema
  (`game_roster`, `audit_events`, `profile_follows`, `post_media`, `profile_locations`).
- `lib/features/profile/presentation/screens/settings/account_management_screen.dart` — a
  brand new `_buildDataExportSection()` widget (83 lines added) wiring a working "Export My
  Data" entry point that calls `DataExportService().requestGDPRDataExport(...)` on tap.

P-025's actual ruling: the entry point may stay visible but inert; only the *mechanism* is
prohibited from active build work. This diff does both — it repairs the mechanism's broken
queries AND adds a live, working UI entry point. Neither change is attributable to any
ticket in the In Review queue; it is uncommitted stray work from elsewhere in the shared
session that never went through review.

**Why:** In a shared multi-agent working tree, `git status` can carry live violations of an
active PO decision with no ticket, no comment trail, and no attribution — the normal
per-ticket review loop will never surface it because it isn't attached to anything being
reviewed.

**How to apply:** When a decision (`docs/DECISIONS.md`) descopes or prohibits work on a named
service/feature, grep the **whole working tree diff** (`git status --short`, then
`git diff -- <suspect file>`) for that service's files — not just the Jira queue — every time
you do a full-batch review. A clean Jira board does not mean a clean working tree. Flag any
find to the PO/team-lead immediately; task-auditor is read-only and cannot revert it. See
[[reconciliation-vs-review-queue]] for the related pattern of state existing outside the
review loop.
