---
name: ios-release-entitlements-split
description: KAN-63 item 4 fix — Runner.entitlements was shared across Debug/Release/Profile and had aps-environment=development, silently breaking production push
metadata:
  type: project
---

`ios/Runner.xcodeproj/project.pbxproj` originally pointed `CODE_SIGN_ENTITLEMENTS` at the single `Runner/Runner.entitlements` file for all three Runner build configs (Debug line 682, Release line 707, Profile line 493). That file had `aps-environment: development`. Xcode does NOT auto-flip this value on archive/export — whatever the entitlements file says ships as-is. Result: every Release/TestFlight build was signing with the dev APNs entitlement, so production push silently failed for real App Store users.

**Fix (2026-08-31, KAN-63):** added `ios/Runner/Runner-Release.entitlements` (identical, `aps-environment: production`), repointed Release and Profile configs to it, left Debug on the original `Runner.entitlements` (development — correct for local runs).

**Verification still needed:** a real TestFlight/App Store archive, check embedded entitlements via `codesign -d --entitlements :- Runner.app` or Xcode Organizer, to confirm `production` actually lands in the shipped binary. Not yet verified against a real build as of this write-up — flag this in any future rejection/push-delivery investigation.

**Distinct from KAN-102** (Supabase gateway JWT issue breaking push app-wide regardless of environment) — don't conflate the two if push issues resurface.

See also [[android-app-links-needs-play-console]].
