# Mobile release: validation evidence and what remains (KAN-568)

Date: 2026-10-18 (Dubai). No secret, key, certificate or profile content appears here. Procedure:
`docs/MOBILE_RELEASE.md`, `docs/IOS_RELEASE.md`, `docs/ANDROID_RELEASE.md`.

## Status in one table

| Area | State |
|---|---|
| Android internal testing (KAN-493) | Done, reused: run https://github.com/dabblersport/webapp/actions/runs/39063775769, `1.7.9+175` from `aa50d929858b66bceac9033038f5fed58557227b`, uploaded, internal track `completed`, available to internal testers confirmed in the Console |
| Android production readiness | Done: GitHub Environment `android-production` created (branch policy: `Alpha` only, no reviewers by design), guard proven by a negative run, no production rollout |
| iOS tooling, workflow, tests, docs | Done and pushed; recipe proven locally with the real Apple Distribution identity and profile |
| iOS secrets in GitHub | 6 of 6 set (names only; the CEO ran `scripts/ios/set_apple_secrets.sh` on 2026-10-18 08:48 UTC) |
| iOS build-only rail on a real macOS runner | **Done 2026-10-18**: https://github.com/dabblersport/webapp/actions/runs/39114076677 (see below) |
| **Real TestFlight upload** | **Done 2026-10-18**: https://github.com/dabblersport/webapp/actions/runs/39120955973 , build `1.7.9 (178)` from Alpha `125900baf736361986672a1c04f263d6fddf02b6`, processing VALID, TestFlight IN_BETA_TESTING (internal) |
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

## iOS: build-only validation on a runner (2026-10-18, after the CEO set the secrets)

Run https://github.com/dabblersport/webapp/actions/runs/39114076677 (push rail `ios-build-validate`, source `5eec39fcc647be96e47074dbfc00f08c78f4e8c3`, version taken from pubspec, never uploads): all jobs succeeded (resolve and validate, analyze and test, build, sign, verify; the status and submission jobs are skipped by design).
* Toolchain recorded in the run summary: runner image `macos-26-arm64` 20261013.0424, Xcode 26 or newer enforced, Flutter 3.47.5.
* Temporary keychain: 1 identity imported, 1 valid identity (`Apple Distribution: Moataz Abdelrahman (J5636UH8V8)`), profile installed.
* Signed IPA verified: bundle id `app.dabbler.pro`, version `1.7.8`, build `174` (pubspec; a real upload picks the next unused number from App Store Connect instead), team `J5636UH8V8`, profile `Dabbler App Store` expiring 2027-10-11, `get-task-allow=false`, `aps-environment=production`, IPA SHA-256 `36ff22c747bb1def0ca6df3896fa7a208527e24a4d0e9abaeb69007c306eae94`. The IPA itself is not an artifact; only the metadata is.
* Runner cleanup: the step "Remove signing material from the runner" (`scripts/ios/cleanup_signing.sh`, `if: always()`) ran in the same job.
* Nothing was uploaded and no App Store Connect write happened in this run.

What remains for the real upload: integrate `alpha-memphis` into Alpha (normal path), then run **iOS release** with `mode=release`, `target=testflight`, `ref=Alpha`, empty build number.

## iOS: real TestFlight upload (2026-10-18)

* Run: https://github.com/dabblersport/webapp/actions/runs/39120955973 (workflow_dispatch of **iOS release** on Alpha, `mode=release`, `target=testflight`, `ref=Alpha`, `version_name=1.7.9`, build number left empty). Source commit `125900baf736361986672a1c04f263d6fddf02b6` (Alpha, the KAN-569 integration). All jobs succeeded; the submit job is skipped by design.
* Build number: read from App Store Connect, "build number 178 is new (highest uploaded: 177)"; a duplicate or lower number is refused before building.
* Toolchain: recorded in the run summary (macOS 26 runner image, Xcode 26 or newer enforced, Flutter 3.47.5).
* Signing and profile verification (metadata artifact `ios-metadata`, no IPA): bundle id `app.dabbler.pro`, version `1.7.9`, build `178`, team `J5636UH8V8`, profile `Dabbler App Store` (expires 2027-10-11), signed by `Apple Distribution: Moataz Abdelrahman (J5636UH8V8)`, `get-task-allow=false`, `aps-environment=production`, IPA SHA-256 `47b58a84d6ade065231c435ee1001be0859d13f5ed0edfa4a41cc7b3e1ef58f5`.
* Upload: altool reported "Uploaded build 178 to App Store Connect". Read-back at the end of the same run, then again by a separate **iOS release** `mode=status` run (https://github.com/dabblersport/webapp/actions/runs/39122479016): `uploaded=true`, `processing=VALID`, `testflight=IN_BETA_TESTING`, no TestFlight blocker, `submission=null`, `review=none`, `available=unconfirmed` ("no independent availability signal yet"), `buildExpired=false`.
* Runner cleanup: the step "Remove signing material from the runner" ran and concluded success.
* Scope: internal TestFlight only. No external testers or groups were added, and no App Store version, submission or release happened. The public App Store version is still 1.1 (lookup); build 178 is not available to the public.

### Second upload with the messaging Worker URL (build 179)

TestFlight 1.7.9 build 178 showed "Couldn't load your chats" on the iPhone: the mobile workflows did not pass `MESSAGING_API_BASE_URL` (fixed in `50d077bb`, repository variable of the same name, build fails fast without it). Build 178 stays in TestFlight but is superseded.
* Run: https://github.com/dabblersport/webapp/actions/runs/39125781666 (workflow_dispatch on Alpha, `mode=release`, `target=testflight`, `ref=Alpha`, `version_name=1.7.9`, build number empty). Source commit `50d077bb6b0f969a2a5974f824d1af83df36fa33`. Success on every job.
* Build number read from App Store Connect: "build number 179 is new (highest uploaded: 178)".
* Verified: bundle `app.dabbler.pro`, version `1.7.9`, build `179`, team `J5636UH8V8`, profile `Dabbler App Store`, Apple Distribution identity, `get-task-allow=false`, `aps-environment=production`, IPA SHA-256 `84af32ef1ef317e0796f2880a80ace0bc28b45ee7d2dae1ab08d04a66a0623d5`.
* Read-back: `processing=VALID`, `testflight=IN_BETA_TESTING`, no blocker, `submission=null`, `review=none`, `available=unconfirmed`. Independent `mode=status` run: https://github.com/dabblersport/webapp/actions/runs/39127296983 (same values).
* Runner cleanup: "Remove signing material from the runner" concluded success. Internal TestFlight only; no external testers, no App Store version, no submission. The fix itself is confirmed only by opening Messages on build 179.

## iOS: what blocked the TestFlight upload before 2026-10-18, and why automation could not do it (resolved)

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
