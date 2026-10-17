# Mobile release: validation evidence and what remains (KAN-568)

Date: 2026-10-18 (Dubai). No secret, key, certificate or profile content appears here. Procedure:
`docs/MOBILE_RELEASE.md`, `docs/IOS_RELEASE.md`, `docs/ANDROID_RELEASE.md`.

## Status in one table

| Area | State |
|---|---|
| Android internal testing (KAN-493) | Done, reused: run https://github.com/dabblersport/webapp/actions/runs/39063775769, `1.7.9+175` from `aa50d929858b66bceac9033038f5fed58557227b`, uploaded, internal track `completed`, available to internal testers confirmed in the Console |
| Android production readiness | Done: GitHub Environment `android-production` created (branch policy: `Alpha` only, no reviewers by design), guard proven by a negative run, no production rollout |
| iOS tooling, workflow, tests, docs | Done and pushed; recipe proven locally with the real Apple Distribution identity and profile |
| iOS secrets in GitHub | 3 of 6 set; 3 need the CEO (below) |
| **Real TestFlight upload** | **Not done: blocked on two CEO actions** (Issuer ID, certificate export) |
| Public release on either store | Not done, not requested |

## Android production readiness (C3)

* Environment: `android-production` exists. Deployment branch policy `Alpha` (a production publish can only be started from a run on Alpha). No required reviewers: the CEO's release instruction with the exact commit and version, typed as `production_approval`, is the approval event, so no second routine click. `android-internal` is unchanged (no rules). `github-pages` untouched.
* Guard run, negative test, **nothing built or published**: https://github.com/dabblersport/webapp/actions/runs/39078865151 asked for `track=production` at the full Alpha commit `0afdbf688b6866807d3b19b7cdb870bfcb5d3cca`, version `1.7.10+176`, with **no** approval. Result: job "Resolve and validate the request" failed with `production_approval must be exactly: APPROVE <commit> <versionName>+<versionCode>`; the build, status and publish jobs were skipped.
* Other guards (code and tests, `scripts/android/test_play_publish.py`, 11 tests): duplicate or lower versionCode refused against Play before upload; commit must be on Alpha, Canary or main; production needs the full 40-character commit as `ref`; client-safe configuration allowlist only; `concurrency: android-release`; the push rail (`android-build-validate`) is build-only. Credential health: the service-account and signing secrets exist by name (`ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`, `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON`) and were exercised successfully by the run above on 2026-10-17. No upload-key reset, no default-branch change, code 175 not republished.

## iOS: what was done

* Workflow `ios-release.yml` (jobs `prepare`, `quality`, `build`, `status`, `submit`), read-only watcher `mobile-release-status.yml`, scripts under `scripts/ios/` (`asc_release.py`, `verify_ipa.sh`, `prepare_manual_signing.py`, `install_signing.sh`, `cleanup_signing.sh`, `set_apple_secrets.sh`), `ios/ExportOptions-AppStore.plist`, and 24 + 8 offline tests (run in CI on every Canary push and PR into main).
* Registration and the first CI run: a push to the build-only rail branch `ios-build-validate` registered the workflow: https://github.com/dabblersport/webapp/actions/runs/39078273845. `prepare` and `quality` (analyze, the whole test suite, the iOS release-logic tests) **succeeded**; `build` failed at its first step on a real bug (piping `xcodebuild -version` into `head` crashes xcodebuild), now fixed in the workflow. It would have stopped at the signing install anyway (the `.p12` secret is not set yet), which is the correct fail-closed behaviour.
* **Recipe proven locally** on a copy of the repo with the real signing identity and profile (nothing uploaded, copy deleted afterwards): the runner-only manual-signing patch applied to the Runner Release and Profile configurations only, `flutter build ipa` with `ios/ExportOptions-AppStore.plist` produced a 66.8 MB IPA, and `verify_ipa.sh` passed: bundle id `app.dabbler.pro`, team `J5636UH8V8`, profile `Dabbler App Store` (expires 2027-10-11), signed by `Apple Distribution: Moataz Abdelrahman (J5636UH8V8)`, `get-task-allow=false`, `aps-environment=production`. Local toolchain: Xcode 27.1 (iPhoneOS 27.1 SDK), Flutter 3.47.5. The GitHub runner's Xcode is recorded in each run summary and must be 26 or newer.
* Secrets set by name in GitHub Actions Secrets (values never shown): `IOS_PROVISIONING_PROFILE_BASE64`, `APP_STORE_CONNECT_API_KEY_P8`, `APP_STORE_CONNECT_KEY_ID`.
* Compliance: `ITSAppUsesNonExemptEncryption=false` is already declared in `ios/Runner/Info.plist`; no compliance answer was invented.
* No public submission and no external TestFlight invitation was made; `mode=submit` is a dry run unless `dry_run=false` and the exact approval string match (tested offline: it writes nothing without `--confirm`).

## iOS: what blocks the TestFlight upload, and why automation cannot do it

1. **The App Store Connect Issuer ID is not available to automation.** Evidence of the checks already performed: not in the repository or its docs, not in the Keychain items present (`dabbler-cloudflare`, `dabbler-test-user*`, `mcp.github.dabbler`), not in the environment, not in the credentials folders (they hold only the `.p8` key and the provisioning profile). A probe of the API key without an issuer returned `HTTP 401 NOT_AUTHORIZED`, which confirms it is a team key that requires the issuer. Apple shows the Issuer ID only in the portal.
2. **The Apple Distribution private key could not be exported.** The identity is valid in the login Keychain (`Apple Distribution: Moataz Abdelrahman (J5636UH8V8)`) and its certificate is the one the profile was issued for, but exporting the private key for CI was refused by the permission system ("Credential Exploration"). It was not bypassed; a person must export it.

### The CEO's steps (about five minutes)

1. Open https://appstoreconnect.apple.com > **Users and Access** > **Integrations** > **App Store Connect API** > tab **Team Keys**. Copy the **Issuer ID** (a UUID, shown above the key list). Check that the key whose id is the one in `~/.config/dabbler-release/credentials/AuthKey_<id>.p8` is listed and Active, with access **App Manager** (or Admin) so it can upload builds and read TestFlight. If it is missing or has lesser access, create a new key with **App Manager** access, download it once, and tell Memphis (it then replaces `APP_STORE_CONNECT_API_KEY_P8` and `APP_STORE_CONNECT_KEY_ID`).
2. On this Mac open **Keychain Access** > **login** > **My Certificates**. Expand **Apple Distribution: Moataz Abdelrahman (J5636UH8V8)** so the private key shows under it. Right-click the **certificate row** > **Export** > format **Personal Information Exchange (.p12)**, save as `~/Downloads/Distribution.p12`, and choose a password you can type once. (macOS asks for your login password to release the key: that approval is the reason automation cannot do this step.)
3. In Terminal run, from the repository checkout, `scripts/ios/set_apple_secrets.sh ~/Downloads/Distribution.p12` (optionally prefix it with `PROFILE_FILE=<the .mobileprovision> RELEASE_CREDENTIALS_DIR=<folder outside the repo>` to check the certificate against the profile and to keep a backup outside the repository). It asks, with typing hidden, for the `.p12` password and the Issuer ID, verifies the certificate is Apple Distribution for team `J5636UH8V8` with a private key, sets `IOS_DISTRIBUTION_CERT_P12_BASE64`, `IOS_DISTRIBUTION_CERT_PASSWORD` and `APP_STORE_CONNECT_ISSUER_ID`, and prints nothing secret. Then delete `~/Downloads/Distribution.p12`.
4. Tell the orchestrator "Apple secrets are set". Operations then runs, in this order: the validation rail (push to `ios-build-validate`, build only), then **iOS release** with `mode=release`, `target=testflight`, `ref=Alpha` and the version, and records the run URL, the build number read from App Store Connect, the processing state and the TestFlight state.

Optional later, only when a public release is wanted: create the App Store version record and release notes in App Store Connect (My Apps > Dabbler > iOS App > "+").

## Observations

* The Android `mode=status` job exits non-zero while `available` is `unconfirmed`, which is a normal state; the iOS status command is the same by design (exit 1 only when the build is not found). The scheduled **Mobile release status** run turns red only for `rejected` or `blocked`.
* `ios/ExportOptions-AppStore.plist` carries only the team id, bundle id and profile name (no secret).
