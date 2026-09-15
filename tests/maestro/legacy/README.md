# Legacy Maestro flows — NOT RUNNABLE. Read as intended-behaviour notes.

These twelve files were written on 2026-09-08 under `.maestro/dabbler_tests/` and moved here
on 2026-09-15 so that one directory owns Maestro. They have never executed against the app,
and they cannot as written:

- **`appId: com.onebrain.dabbler`** — an identifier that exists nowhere. The Android
  `applicationId` is `com.dabbler.dabblerapp` (`android/app/build.gradle.kts:38`); iOS is
  `app.dabbler.pro`. Maestro would fail to launch before the first step.
- **The screens they tap do not exist in this order.** They tap `"Mobile"` / `"Email"` on
  launch and expect `"Log In"` and `"Home"`. The live flow is Landing (`"Continue"`) →
  Auth Welcome (`"Continue with Google" / "Continue with Email" / "Already have an account?
  Log in"`) → Login → `/welcome` for an onboarded account (`email_password_screen.dart:139`).
- **They embed a test phone number and a fixture password.** Credentials belong in the
  environment (`E2E_EMAIL` / `E2E_PASSWORD`), never in a flow.

What they are still good for: a checklist of the auth journeys the Product intends to cover
— account creation (mobile / email), login (mobile OTP / email), OTP rate-limit / invalid /
expired, password reset, change password, session expiry, find-nearby-venue. Each becomes a
real flow under `tests/maestro/flows/<journey>/` when the ticket that makes that journey
testable lands — written against the live strings in `lib/l10n/app_en.arb`, with the real
`appId`, and proven by `npm run test:maestro`.

`config.yaml` globs `flows/**` only, so nothing here is ever selected by the runner.
