# Android release: validation evidence (KAN-493)

What was run, with links and non-secret metadata. No credential, keystore, password or
service-account content appears here. Procedure: `docs/ANDROID_RELEASE.md`.

## C3: signed AAB from GitHub Actions, from a recorded commit
Run: https://github.com/dabblersport/webapp/actions/runs/39063775769 (workflow **Android release**, `workflow_dispatch`, ref `Alpha`, 2026-10-17, success).

| | |
|---|---|
| Resolved commit (immutable) | `aa50d929858b66bceac9033038f5fed58557227b` (Alpha at the time) |
| Package | `com.dabbler.dabblerapp` |
| versionName / versionCode | `1.7.9` / `175` |
| Signing certificate SHA-256 (public) | `3D:3A:63:C9:DA:82:E3:41:D7:0F:3A:E2:E4:98:54:70:C9:91:C3:9B:42:F7:13:69:11:77:28:BC:61:B9:6F:CE` |
| Matches the release keystore and the recorded upload certificate | yes (the build job fails otherwise) |
| Toolchain | Flutter 3.47.5 (recorded in the workflow), Temurin Java 17, bundletool 1.18.3 (SHA-256 checked), `ubuntu-latest` |
| Jobs | Resolve and validate: success. Build, sign and verify: success. Publish (internal): success. Status: skipped |

Earlier build-only rail (push to `android-build-validate`, never publishes): https://github.com/dabblersport/webapp/actions/runs/38165304908 (success; the publish job was skipped).

## C4: Play internal testing, uploaded and read back with the service account
Same run as above, job **Publish to Google Play (internal)**, after the upload key became valid.

| Stage | Result |
|---|---|
| Duplicate/older versionCode check | passed ("versionCode 175 is new, highest uploaded: 174") |
| `uploaded` / `processed` | true / true (Play lists versionCode 175) |
| Track | `internal`, release status `completed`, no staged fraction |
| `review` | `not-exposed-by-api` (internal testing has no review) |
| `available` | `confirmed` (internal: release completed; testers must be on the tester list) |
| Production | untouched: no production upload or rollout was made |

One internal upload exists, so no second upload was made for this check (a duplicate would burn a
versionCode for no new evidence). Store-listing reading of versionCode 174 (production) with
`mode=status` correctly reports `review: not-exposed-by-api` and `available: unconfirmed`
(run https://github.com/dabblersport/webapp/actions/runs/39063723716; the job is red because
`unconfirmed` is reported as not verified, see observations).

## C5: unapproved pushes cannot publish; no secrets in files, logs or artifacts
- Triggers: `android-release.yml` runs only on `workflow_dispatch` and on a push to the branch `android-build-validate`, where the track is forced to `none` (the push-rail run above shows the publish job skipped). `ci.yml` and `anon-allowlist-check.yml` never reference the Android workflow. A push to Alpha, Canary or main does not run it.
- A store track requires the commit to be on Alpha, Canary or main; production additionally requires the full 40-character commit as `ref` and the exact `production_approval` string, checked in the first job before any build.
- Overlap and duplicates: `concurrency: android-release` (queued, not cancelled) and the versionCode check against Play before upload.
- Tracked files: no keystore, `key.properties`, service-account or `.jks` file is tracked (`android/key.properties` is git-ignored). Secret-like patterns found in tracked files are only code that strips PEM markers (two Edge Functions), a test asserting the absence of `private_key`, and the local-CI database URL with the default `postgres:postgres` test credentials. `SUPABASE_DB_URL` appears in the workflow only in a comment saying it is never referenced.
- Logs: a scan of the full log of run 39063775769 (6108 lines) for private-key headers, `"private_key"`, JWT-shaped strings, `sbp_` tokens and credentialed database URLs finds none (GitHub masks the secret values).
- Artifacts: one artifact, `android-aab` (the verified `.aab` and `metadata.json`, 14-day retention), uploaded from explicit paths; the keystore and `key.properties` are removed from the runner at the end of the build job and the service-account file at the end of publish.
- Stages are reported distinctly: `uploaded`, `processed`, track release status, `review` (never available from the API), `available` (`unconfirmed` until an independent signal).

## Offline checks
`python3 scripts/android/test_play_publish.py`: 11 tests pass (publishing logic, no network).

## Observations and open items (not changed here)
1. **GitHub Environment `android-production` does not exist yet** (only `android-internal` and `github-pages`). Until a repository admin creates it with the CEO as required reviewer, the only production gate is the typed `production_approval` string. Needs the CEO; production publishing stays unapproved and unused.
2. `mode=status` exits non-zero (a red job) whenever `available` is `unconfirmed`, which is the normal state of a production release with no independent availability signal. The information is correct; the red status is noisy. Suggest exit 0 on a successful read with `ok` kept in the JSON, as a follow-up.
3. Production availability needs an independent signal (the public store page) and is best-effort; no review duration is promised.
