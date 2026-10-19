# Android release (KAN-493, production readiness KAN-568)

Both stores share one sequence: `docs/MOBILE_RELEASE.md`. iOS: `docs/IOS_RELEASE.md`.

Build, sign, verify and publish an Android version to Google Play from GitHub Actions
(`dabblersport/webapp`, workflow **Android release**, `.github/workflows/android-release.yml`).
No routine Play Console uploads. Package: `com.dabbler.dabblerapp`.

Nothing publishes by itself: normal pushes to Alpha, Canary or main, pull requests and
schedules never touch a store. A release is a person (or an authorised Thebes dispatch)
pressing **Run workflow** with an exact ref, version and track.

> This file names secrets and variables only. Credential contents never go in Jira, logs,
> artifacts or source control.

## The usual sequence

1. **Validate on web Alpha first.** Web Alpha (alpha.dabbler.pro) is the online validation
   stage. Pick the Alpha commit the CEO wants on Android.
2. **Choose the version.** `versionName` like `1.7.9`; `versionCode` an integer **higher than
   every code already in Play** (the workflow refuses a duplicate or lower one).
3. **Build only (safe, repeatable).** Run the workflow with `track = none`. It resolves the
   ref to a commit, runs `flutter analyze` and `flutter test`, rebuilds the keystore on the
   runner, builds the signed AAB, and verifies package, versionName, versionCode and the
   signing-certificate fingerprint. The AAB and `metadata.json` are kept as a 14-day artifact.
4. **Internal testing.** Run with `track = internal`. The `publish` job re-checks the
   versionCode against Play, uploads, assigns the internal track, commits the edit, then reads
   it back from Play. Internal testing has no review step.
5. **Follow it.** Run `mode = status` (below) until the stages you care about are reached.
6. **Production** only after the CEO approves the exact commit and version (next section).

### Inputs of "Run workflow"

| Input | Meaning |
|---|---|
| `mode` | `release` (build, verify, publish if a track is chosen) or `status` (read-only report) |
| `ref` | Branch, tag or commit. Resolved to a commit and **recorded** in the run summary. Production needs the full 40-character commit |
| `version_name` / `version_code` | The version to build and publish |
| `track` | `none` (build + verify only), `internal`, `production` |
| `release_status` | `completed` (release it) or `draft` (leave for a person to finish; use if Play refuses `completed` on an app that has no published release yet) |
| `app_environment` | The app's `ENVIRONMENT` define; `production` for store builds |
| `production_approval` | Production only, see below |

Store builds only come from a commit that is on `Alpha`, `Canary` or `main`.

## Production

Production publishes **only** with an explicit approval typed into the run:

```
production_approval = APPROVE <40-character commit> <versionName>+<versionCode>
```

and `ref` set to that same full commit. Anything else fails in the first job, before any
build. The approval string is the CEO's go-ahead for that exact commit and version.

The GitHub Environment **`android-production`** exists (KAN-568) and is restricted to the
`Alpha` branch by a deployment branch policy, so a production publish can only be started from a
run on Alpha. It deliberately has **no required reviewers**: the CEO's release instruction naming
the exact commit and version is the approval event, and the typed `production_approval` above is
that approval recorded in the run. Required reviewers would add a second routine click between
"run" and "publish to production"; if the CEO wants that extra gate, add the reviewer to the
environment in Settings > Environments, which changes nothing else. The `publish` job runs in
`android-<track>`; `android-internal` has no rules and is used for internal testing.

Setting this workflow up is not an approval to publish to production.

## How to run it

Web: GitHub, **Actions**, **Android release**, **Run workflow**.

CLI:

```bash
gh workflow run android-release.yml --repo dabblersport/webapp \
  -f ref=<commit-or-branch> -f version_name=1.7.9 -f version_code=175 -f track=internal
gh run watch --repo dabblersport/webapp
```

**GitHub only lets `workflow_dispatch` run a workflow that exists on the repository's default
branch** (`main`). Until `android-release.yml` is on `main`, "Run workflow" is not offered.
Until then, build validation uses the **validation rail**: pushing a ref to the branch
`android-build-validate` runs the same build, signing and verification with the track forced
to `none` (it can never publish):

```bash
git push origin <commit>:refs/heads/android-build-validate     # run from your own checkout
```

## What the build verifies

`scripts/android/verify_aab.sh` fails the run unless all of these hold, and records them in
`metadata.json` and the run summary:

- package is `com.dabbler.dabblerapp`; versionName and versionCode are the requested values
- the bundle is signed with a certificate, not the debug certificate
- that certificate equals the certificate of the release keystore the build used
- that certificate equals the recorded upload-certificate fingerprint (SHA-256, public)
  `3D:3A:63:C9:DA:82:E3:41:D7:0F:3A:E2:E4:98:54:70:C9:91:C3:9B:42:F7:13:69:11:77:28:BC:61:B9:6F:CE`
  (the repository variable `ANDROID_UPLOAD_CERT_SHA256` overrides it)

The toolchain is recorded in the run summary and pinned in the workflow: Flutter `3.47.5`
(stable), Temurin Java 17, bundletool 1.18.3 (downloaded and checked against a pinned
SHA-256). Change a pin deliberately and re-run the validation rail.

Only the client-safe allowlist reaches the app build: `SUPABASE_URL`, `SUPABASE_ANON_KEY`,
`SUPABASE_PUBLISHABLE_KEY`, `APP_NAME`, `GOOGLE_WEB_CLIENT_ID`, plus `ENVIRONMENT` from the
input. `SUPABASE_DB_URL` and every other backend secret are never referenced. Mobile builds also need the repository VARIABLE `MESSAGING_API_BASE_URL` (the messaging Worker's public URL, not a secret; set with `gh variable set`): the build passes it as `--dart-define` like the web build does and **fails fast when it is empty or not an https URL**, because with the messaging flags on a build without it shows "Couldn't load your chats" (KAN-568, found on TestFlight 1.7.9 build 178). `GOOGLE_WEB_CLIENT_ID` must be the project's WEB OAuth client (`client_type` 3 in `android/app/google-services.json`), because the app compiles it as the Google `serverClientId`; `scripts/check_google_client_id.py` makes the build fail when it is empty or equals an Android client id (`client_type` 1), which would give Google sign-in ApiException 10 (KAN-571). The value is a public client id, not a key.

## Following a release: upload, review, availability are different things

`scripts/android/play_publish.py` reports distinct stages (run `mode = status`, or read the
publish job's read-back):

| Stage | Meaning | Source |
|---|---|---|
| `uploaded` / `processed` | Play accepted the bundle and lists it | Play bundle list |
| `onTrack` | A release with the versionCode is on the track, with its status `draft`, `inProgress`, `completed` or `halted` | Play track |
| `review` | **Not exposed by the Play API.** Always `not-exposed-by-api` | n/a |
| `available` | `confirmed` only on an independent signal: internal testing: release `completed` (no review; testers must be on the tester list). Production: the public store page shows the versionName (best effort). Otherwise `unconfirmed` | derived |

Rules for reporting: never say "ready to update" while `available` is `unconfirmed`; never
promise a review duration; report a rejection as the Play Console shows it (copy the
Console message to the ticket; the API does not return it).

**How an asynchronous review reaches the CEO** (existing Thebes/Jira reporting, no new
service): the operations team (Memphis) owns each store release as a dispatch. It starts the
run, records the run URL and the Play release link in its result, and re-runs `mode = status`
on a sensible cadence (for example every few hours for production) until the state is
terminal: `available`, `halted`, or a rejection seen in the Console. Each state change is
reported in that dispatch result, which the orchestrator posts on KAN-493 / the release
ticket and surfaces to the CEO. A failed run is red in GitHub, which also emails the person
who triggered it.

## Credentials: names only

Repository **Actions secrets** in `dabblersport/webapp`:

| Secret | Used for |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | Upload keystore (base64), written to the runner's temp dir for the build |
| `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD` | Keystore and key |
| `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` | Play API: service account `dabbler-android-release@dabblersportapp.iam.gserviceaccount.com`, app-scoped release permissions only |
| `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_PUBLISHABLE_KEY`, `APP_NAME`, `GOOGLE_WEB_CLIENT_ID` | Client-safe app configuration (shared with the web build) |
| (variable, not a secret) `MESSAGING_API_BASE_URL` | The messaging Worker's public URL; required by the build |

Handling: the keystore and `android/key.properties` exist only on the runner during the run
and are deleted in an `always()` step; the service-account file is written with mode 600 and
deleted the same way; nothing is echoed. The offline backup is kept outside the repository
(`Dabbler/.release-credentials/android`) and is never committed (`.gitignore` excludes
keystores, `.pem`, service-account and signing-credential files).

### Renewal and recovery

- **Upload key reset.** Play App Signing re-signs for users; the keystore here is only the
  *upload* key. After a reset, Google activates the new upload key at its stated time
  (uploads are refused before then; do not retry or request another reset). Then: update the
  four keystore secrets, set the repository variable `ANDROID_UPLOAD_CERT_SHA256` to the new
  certificate's SHA-256, and run `track = none` to confirm the build verifies.
- **Service account.** Create a new key for the same account in Google Cloud, replace
  `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON`, delete the old key. Keep the Play Console permissions
  app-scoped (release to testing and production); never grant project IAM or financial/admin
  permissions to fix a publish error.
- **Lost secret / suspected leak.** Rotate the affected credential first (service-account key
  or upload-key reset), then update the secret. A leaked upload key cannot ship a build to
  users without also passing the Play account's own controls, but treat it as an incident.
- **Play rejects an upload as a duplicate versionCode.** Pick the next higher code; never
  re-upload the same one.

## Files

- `.github/workflows/android-release.yml`: the entry point
- `scripts/android/verify_aab.sh`: package / version / signing-certificate checks
- `scripts/android/play_publish.py` (+ `test_play_publish.py`, `requirements.txt`): Play upload,
  duplicate guard, read-back and stage report
- `android/app/build.gradle.kts`: reads `android/key.properties` (gitignored, created on the
  runner); a release build without it fails rather than signing with debug
