# Maestro — deterministic mobile E2E and regression

**Owner:** `frontend` capability (flows are Product code). **Runner:** `qa` (test orchestration).
**Trigger:** routine for Flutter UI / mobile-journey changes; always for a release candidate.

```bash
npm run test:maestro                       # flows/smoke on the connected Android device
bash tests/maestro/run.sh flows/auth       # a folder, once it exists
bash tests/maestro/run.sh flows/smoke/01_cold_start_reaches_auth_welcome.yaml
```

Exit 0 is PASS. Exit 2 is the runner refusing for a named infrastructure reason (no
`maestro`, no device, no APK); any other nonzero is Maestro reporting a failed flow, with
JUnit XML at `tests/maestro/.results/junit.xml` (gitignored).

## Layout — one directory owns Maestro

```
tests/maestro/
  config.yaml            workspace config: flow globs, execution order
  run.sh                 device/app preflight, then `maestro test`
  flows/
    smoke/               proves the harness executes; runs on every mobile change
    <journey>/           added incrementally by the Product work that ships the journey
  legacy/                the 2026-09-08 flows, NOT runnable — see legacy/README.md
```

Intended journeys, each added by the ticket that makes it real, never speculatively:
onboarding · authentication · guest mode · profile creation · sports selection ·
game discovery · join game · create game · venue booking · messaging · profile updates ·
critical error/recovery states.

## Conventions

- **`appId: com.dabbler.dabblerapp`** — the Android `applicationId`
  (`android/app/build.gradle.kts:38`). iOS is `app.dabbler.pro`. The legacy flows used a
  third id that exists nowhere; that is why they never ran.
- **Match on the English strings in `lib/l10n/app_en.arb`**, and cite the key in a comment.
  A string change in the ARB is a flow change; nothing else is.
- **`clearState: true` when the flow starts from Landing.** A persisted session skips
  Landing and the flow passes vacuously.
- **`extendedWaitUntil` with a timeout on cold-start screens**; `assertVisible` after that.
  Timeouts are ceilings from the QA bounds (startup 60s → 30s here, UI state 10–15s).
- **Tag `smoke` only for flows that prove execution**, not for coverage. Journeys carry
  their own tag.
- **Credentials never appear in a flow.** A flow that signs in reads `E2E_EMAIL` /
  `E2E_PASSWORD` from the environment (`${E2E_EMAIL}` in Maestro), the same variables
  `tests/e2e/.env.e2e` supplies to Playwright.

## What Maestro proves and what it does not

It proves the app on a device does what a person would see. It does not prove business
logic (Dart unit tests), the data contract (`tests/api`), or web behaviour (`tests/e2e`).
Routing (`agent/qa/routing.py` in Thebes) selects it for mobile-platform and native-surface
changes, and for release candidates; it is not run for backend-only or docs-only changes.

## Devices

- **Android emulator `Dabbler_test`** (Pixel 10 Pro, android-37.1, arm64) exists on this
  machine and boots headless in ~30s:
  `~/Library/Android/sdk/emulator/emulator -avd Dabbler_test -no-window -no-audio -no-boot-anim`
- **iOS simulators are unavailable here**: `xcrun simctl` needs the Xcode licence, which
  no agent accepts on the CEO's behalf. The flows are platform-neutral; run them on iOS
  from a licensed machine or in CI.
- **BrowserStack** reuses these same flows on real devices at release stage. Not wired:
  no credentials exist. When they do, they go in CI secrets, never here.
