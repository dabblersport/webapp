---
name: eula-gate-implementation
description: How the pre-login EULA/Terms-of-Use acceptance gate was implemented for Guideline 1.2 — files, flag, and router insertion point.
metadata:
  type: project
---

Implemented 2026-07-01 to satisfy Guideline 1.2's requirement that UGC apps gate registration/login behind an explicit Terms-of-Use acceptance.

- `lib/core/services/eula_service.dart` (new) — `EulaService.preload()` (called from `main.dart` right after `Environment.load()`) caches acceptance state from SharedPreferences into a static bool so the router redirect can check it synchronously. `EulaService.accept()` persists locally and best-effort inserts into `public.consent_records` (new table, migration `create_consent_records_table`; `user_id` nullable since acceptance happens pre-auth, `device_id` is a locally generated+persisted UUID). Network failure on the consent_records write must never block the user — it's wrapped in try/catch.
- `lib/features/profile/presentation/screens/about/eula_gate_screen.dart` (new) — checkbox + "Agree & Continue" (disabled until checked), links out to the *existing* `/about/terms` and `/about/privacy` screens (`terms_of_service_screen.dart` / `privacy_policy_screen.dart` already existed with real legal copy — reused rather than duplicated).
- `RoutePaths.eulaGate = '/eula-gate'` in `lib/utils/constants/route_constants.dart`.
- `FeatureFlags.requireEulaAcceptance = true` in `lib/core/config/feature_flags.dart` — comment explicitly warns not to disable without an equivalent gate (compliance-critical flag, unlike the MVP feature flags around it).
- Router wiring in `lib/app/app_router.dart`: the check is inserted as the **very first branch** inside `_handleRedirect`, immediately after the `authState.isLoading` early-return and before the profile-existence/OAuth-callback check, the post-login-welcome check, and the unauth→landing check — so it gates every path into the app, not just the login screen specifically. Allow-list inside the gate check: `RoutePaths.eulaGate`, `/about/terms`, `/about/privacy` (so the in-gate "read terms" links don't bounce back to the gate).
- Does NOT touch any auth/demo-account/OTP code — confirmed by construction (only the redirect function and a new screen were touched).

Known limitation intentionally left out of scope: report/block controls exist on posts (feed_post_card.dart) and on user profiles (user_profile_screen.dart), but not on individual comments — no reusable comment-tile widget was found under `lib/features/social/`; comments-level reporting would need its own investigation if Apple flags it specifically.
