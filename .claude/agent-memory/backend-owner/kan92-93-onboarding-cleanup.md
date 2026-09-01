---
name: kan92-93-onboarding-cleanup
description: KAN-92 is flutter-feature-agent's ticket and stays blocked on a cpo ruling even after KAN-48 closed; KAN-93's backfill migration is authored and in review.
metadata:
  type: project
---

KAN-92 ("delete OnboardingController's dead write half, fix resume ladder") is owned by
`flutter-feature-agent`, not `backend-owner` — it's Dart, `lib/features/auth_onboarding/**`.
Closing KAN-48 does not unblock it: `cto`'s T-038 re-audit (comment on the ticket,
2026-08-30) found a fully-built orphaned stage-2 onboarding screen chain
(`onboarding_sports_screen` → `preferences` → `privacy` → `completion`, routed at
`app_router.dart:710-743`, no entry point) and explicitly routed the "wire it up or delete
it" call to `cpo` before KAN-92 executes. No `cpo` ruling was in `docs/DECISIONS.md` as of
2026-08-31.

**Why this matters:** a task brief that says "KAN-48 closed, both tickets unblocked" is not
sufficient — always re-read the ticket's own comment trail before starting, not just the
`docs/DECISIONS.md` entry that split it. The Jira comment can carry a later, narrower block
than the decision record it cites.

KAN-93 (backfill 48 missing persona rows + 6 missing sport rows) is `backend-owner`'s and is
done: migration at `supabase/migrations/20260831140000_kan93_backfill_onboarded_profiles.sql`,
posted to the ticket, moved to In Review. It mirrors `rpc_onboard_profile`'s own inserts
exactly and excludes 2 rows (both seed accounts) with `preferred_sport IS NULL` rather than
falling back to `primary_sport`, which the live RPC never reads. Not applied — `cto` does not
apply this one (it's not security remediation, so `G-009` doesn't extend `G-002` to it); it's
a plain PO-authorized data change under `019`.

**How to apply:** before picking up either ticket again, check for a `cpo` ruling on the
stage-2 chain question in `docs/DECISIONS.md` (search "stage-2" or "onboarding_sports"). If
none exists, KAN-92 is still not actionable regardless of what a dispatch brief says.
