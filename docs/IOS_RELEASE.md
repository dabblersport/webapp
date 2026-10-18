# iOS release (KAN-568)

Build, sign, verify and upload an iOS version to TestFlight from GitHub Actions
(`dabblersport/webapp`, workflow **iOS release**, `.github/workflows/ios-release.yml`), and,
only on an explicit approval, submit it for App Review. Bundle id `app.dabbler.pro`, Apple team
`J5636UH8V8`. The shared sequence for both stores is in `docs/MOBILE_RELEASE.md`.

Nothing publishes by itself: pushes, pull requests and schedules never upload a build. The only
exception is the build-only validation rail (a push to the branch `ios-build-validate`, which
builds, signs and verifies and never uploads). TestFlight upload and App Review submission are
each a person (or an authorised Thebes dispatch) pressing **Run workflow** with exact inputs.

> Names of secrets only. No certificate, private key, profile or API key content goes in Jira,
> logs, artifacts or source control. The repository is public, so logs and artifacts are
> world-readable: the IPA (which embeds the provisioning profile) is **never** an artifact.

## Inputs of "Run workflow"

| Input | Meaning |
|---|---|
| `mode` | `release` (build, verify, upload if `target` says so), `status` (read-only report), `submit` (App Review submission; a dry run unless `dry_run=false` and approved) |
| `ref` | Branch, tag or commit. Resolved to a commit and recorded in the run summary. A real submission needs the full 40-character commit |
| `version_name` | `CFBundleShortVersionString`, like `1.7.9` |
| `build_number` | `CFBundleVersion`, an integer higher than every build in App Store Connect. **Empty = the next unused number is read from App Store Connect** (and recorded) |
| `target` | `none` (build and verify only) or `testflight` (upload; internal testing only) |
| `app_environment` | The app's `ENVIRONMENT` define (`production` for store builds) |
| `dry_run`, `production_approval` | `mode=submit` only. A real submission needs `dry_run=false`, the full commit as `ref`, and `production_approval = APPROVE <40-character commit> <versionName>+<buildNumber>` |

Store builds only come from a commit that is on `Alpha`, `Canary` or `main`.

## The usual sequence

1. **Validate on web Alpha first**, then pick the Alpha commit and version.
2. Run with `mode=release`, `target=none` to check the build and signing without touching the store (repeatable).
3. Run with `mode=release`, `target=testflight`. The jobs: `prepare` (resolve and validate) -> `quality` (analyze, tests, offline release-logic checks) -> `build` on macOS (recorded Xcode and runner image, temporary keychain and profile, **manual signing patched into the runner copy of the Xcode project only**, `flutter build ipa`, IPA verification, `altool` upload, processing wait, read-back). A duplicate or lower build number is refused against App Store Connect **before** anything is built.
4. **Follow it** with `mode=status` (or let the scheduled **Mobile release status** watcher do it, `docs/MOBILE_RELEASE.md`).
5. **Public release** only after the CEO's instruction naming the exact commit and version: create the App Store version record in App Store Connect with honest release notes and metadata (the API cannot invent the legal or marketing answers), then run `mode=submit`, `dry_run=false`, with the approval string. Review is asynchronous; no duration is promised.

## What the build verifies (`scripts/ios/verify_ipa.sh`)

Bundle id, versionName and build number match the request; the embedded provisioning profile is
`Dabbler App Store`, team `J5636UH8V8`, application identifier `J5636UH8V8.app.dabbler.pro`,
`get-task-allow=false`, no device list (an App Store profile); the code signature verifies
(`codesign --verify --deep --strict`), is made by an **Apple Distribution** identity of the
team, and the entitlements carry `aps-environment=production`. Only non-secret metadata is kept
(`ios-metadata` artifact: bundle id, versions, team, profile name and expiry, signing authority,
IPA SHA-256).

Compliance: `ios/Runner/Info.plist` already declares `ITSAppUsesNonExemptEncryption = false`, so
uploaded builds do not wait on the export-compliance question. If App Store Connect ever shows
`MISSING_EXPORT_COMPLIANCE` the status report names it as a blocker and a person answers it; the
workflow never answers a legal or compliance question.

## Stages reported (never conflated)

`uploaded`, `processing` (Apple: PROCESSING / VALID / FAILED / INVALID), `testflight` (internal
state), `submission` (App Store version state), `review` (waiting / in review / rejected /
approved), `available` (`confirmed` only when the App Store version is `READY_FOR_SALE` **and**
the public lookup shows the versionName; otherwise `unconfirmed`). Never announce "ready to
update" while `available` is `unconfirmed`, and never promise a review duration.

## Credentials: names only

Repository secrets (Settings > Secrets and variables > Actions), used only by the steps that
need them:

| Secret | What it is |
|---|---|
| `IOS_DISTRIBUTION_CERT_P12_BASE64` | The Apple Distribution certificate + private key as a `.p12`, base64 |
| `IOS_DISTRIBUTION_CERT_PASSWORD` | The `.p12` password |
| `IOS_PROVISIONING_PROFILE_BASE64` | The `Dabbler App Store` provisioning profile, base64 (expires 2027-10-11) |
| `APP_STORE_CONNECT_API_KEY_P8` | The App Store Connect API private key (`AuthKey_<id>.p8` contents) |
| `APP_STORE_CONNECT_KEY_ID` | The key id |
| `APP_STORE_CONNECT_ISSUER_ID` | The issuer UUID (shown in the portal only) |

App configuration (client-safe allowlist only): `SUPABASE_URL`, `SUPABASE_ANON_KEY`,
`SUPABASE_PUBLISHABLE_KEY`, `APP_NAME`, `GOOGLE_WEB_CLIENT_ID`. `SUPABASE_DB_URL` and every other
backend secret are never referenced. Mobile builds also need the repository VARIABLE `MESSAGING_API_BASE_URL` (the messaging Worker's public URL, not a secret; set with `gh variable set`): the build passes it as `--dart-define` like the web build does and **fails fast when it is empty or not an https URL**, because with the messaging flags on a build without it shows "Couldn't load your chats" (KAN-568, found on TestFlight 1.7.9 build 178).

Local backups of the signing material live outside the app repository, in
`Dabbler/.release-credentials/ios` and `~/.config/dabbler-release/credentials`; never commit them.

### Renewal and recovery

* **Provisioning profile** (yearly, next 2027-10-11): in the Apple Developer portal regenerate the
  App Store profile for `app.dabbler.pro` against the same Apple Distribution certificate, download
  it, and update the secret `IOS_PROVISIONING_PROFILE_BASE64` with its base64 (GitHub CLI:
  `gh secret set`, reading the file; the value is never typed or printed). The profile *name* must
  stay `Dabbler App Store` (it is in `ios/ExportOptions-AppStore.plist` and the workflow), or change
  it in both places.
* **Distribution certificate** (expires after a year; creating or revoking certificates is a
  deliberate CEO decision, never done by automation): export the new identity as a `.p12` from
  Keychain Access and run `scripts/ios/set_apple_secrets.sh <the .p12>`, then renew the profile.
* **API key**: create a new key in App Store Connect with the same access, update
  `APP_STORE_CONNECT_API_KEY_P8` and `APP_STORE_CONNECT_KEY_ID`, then revoke the old key.

## CEO actions (what automation cannot do, and why)

1. **Read the Issuer ID** (a UUID) at appstoreconnect.apple.com > Users and Access > Integrations >
   App Store Connect API (tab "Team Keys"): it is displayed only there ("Issuer ID", with a copy
   button). It is not stored anywhere on this Mac and cannot be derived from the key; a probe of the
   key without it returns `NOT_AUTHORIZED`.
2. **Export the Apple Distribution identity** (needs your approval of the private key; automation
   was refused access to the Keychain private key and must not bypass that): Keychain Access >
   login > "My Certificates" > "Apple Distribution: Moataz Abdelrahman (J5636UH8V8)" (expand it so
   the private key is included) > right-click > Export > format `.p12`, choose a password.
3. **Set the three secrets** with one command, which asks for the password and the Issuer ID with
   typing hidden and checks locally that the certificate matches the provisioning profile:
   `scripts/ios/set_apple_secrets.sh ~/Downloads/Distribution.p12`
   (optional environment: `PROFILE_FILE` for the profile check, `RELEASE_CREDENTIALS_DIR` for the
   backup outside the repository). Then delete the exported file from Downloads.
4. **Before any public submission**: create the App Store version record and its release notes in
   App Store Connect (My Apps > Dabbler > iOS App > "+" version), because the API cannot supply the
   honest metadata. Not needed for TestFlight.
