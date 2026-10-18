# Mobile release: one sequence for Google Play and the App Store (KAN-568)

Both stores are released the same way, from GitHub Actions in `dabblersport/webapp`, after a
CEO release instruction that names the **immutable commit** and the **version**. There are no
routine manual store-console uploads. Details per platform: `docs/ANDROID_RELEASE.md`
(workflow **Android release**) and `docs/IOS_RELEASE.md` (workflow **iOS release**).

> Names of secrets and variables only. No credential, key, profile or certificate content goes
> in Jira, logs, artifacts or source control. This repository is public: workflow logs and
> artifacts are world-readable, so neither workflow uploads a signed IPA as an artifact.

## The sequence

| # | Step | Android | iOS |
|---|---|---|---|
| 1 | **Resolve the immutable source and environment.** The `ref` input is resolved to a commit and recorded in the run summary. A store build may only come from a commit on Alpha, Canary or main. | `prepare` job | `prepare` job |
| 2 | **Validate version and build number.** versionName like `1.7.9`; a strictly higher versionCode / build number than anything already in the store. A duplicate or lower one is refused against the store itself, before upload. | versionCode checked against Play | build number checked against App Store Connect (`check`); empty = next unused number is read and recorded |
| 3 | **Checks.** `flutter analyze --no-fatal-infos` and `flutter test`; a local config selection must never ship. | build job | `quality` job (Linux, cheap) |
| 4 | **Sign and build** from a client-safe configuration allowlist only (`SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_PUBLISHABLE_KEY`, `APP_NAME`, `GOOGLE_WEB_CLIENT_ID`, `ENVIRONMENT`). Backend-only secrets such as `SUPABASE_DB_URL` are never referenced. Signing material exists only on the runner and is removed at the end. | keystore rebuilt on the runner | temporary keychain + App Store profile on a macOS runner |
| 5 | **Verify the artifact**: package/bundle id, versionName, build, signing identity and (iOS) provisioning profile, entitlements and Apple Distribution signature. | `verify_aab.sh` + bundletool | `verify_ipa.sh` |
| 6 | **Upload** to the internal test channel. | Play internal testing | TestFlight (internal only; no external invitations) |
| 7 | **Process and read back** with the store API. | Play bundle list + track | App Store Connect build `VALID`, TestFlight state |
| 8 | **Submit** for public release. Only for an explicitly approved commit and version. | `track = production` with `production_approval` | `mode = submit`, `dry_run = false`, `production_approval` |
| 9 | **Observe review / rejection.** Asynchronous; no duration is promised. | not exposed by the Play API (see below) | App Review states via the API |
| 10 | **Confirm availability** on an independent signal, then announce "ready to update". | public Play page shows the versionName | App Store version `READY_FOR_SALE` and the public lookup shows the versionName |

**Upload is not availability.** Every status report keeps the stages apart: `uploaded`,
`processing`, `testflight`, `submission`, `review`, `available`. `available` is `confirmed` only on
an independent signal; otherwise `unconfirmed`, and nobody says "ready to update".

## Approval: the CEO's release instruction is the approval event

A public release is requested by a CEO instruction naming the commit and version, for example
"release `<40-character commit>` as `1.8.0+180` to Android production". The operator then runs
the workflow once with the approval string the CEO's instruction implies:

```
production_approval = APPROVE <40-character commit> <versionName>+<versionCode or build number>
```

with `ref` set to that same full commit. Anything else fails in the first job, before any build
or upload. There is no second routine approval click: the typed approval **is** the recorded
approval. (If the CEO wants a human gate in GitHub as well, add required reviewers to the
`android-production` environment: that is a deliberate extra step per release, not the default.)
Normal pushes, pull requests and schedules never publish to a store; the status watcher only reads.

## Status entry points (read-only)

| What | How |
|---|---|
| One build or version on demand | Run **Android release** or **iOS release** with `mode = status` |
| Everything under observation | **Mobile release status** (`workflow_dispatch`, plus a 6-hourly schedule), reading the repository variable `MOBILE_RELEASE_TRACKING`. **The schedule only fires once this workflow file is on the default branch (`main`)**; GitHub does not run `schedule` triggers from other branches, and main is released only by the CEO. Until then it is run on demand (`gh workflow run "Mobile release status" --repo dabblersport/webapp --ref Alpha`) by the operations dispatch |

Start observing a release (no commit needed):

```
gh variable set MOBILE_RELEASE_TRACKING --repo dabblersport/webapp --body '[{"platform":"ios","versionName":"1.7.9","buildNumber":"176"},{"platform":"android","versionName":"1.7.9","versionCode":"175","track":"internal"}]'
```

Stop observing: set it to `[]`. The watcher judges each entry as `available` (done, remove it),
`waiting`, `blocked` (for example MISSING_EXPORT_COMPLIANCE or failed processing) or `rejected`
(App Review rejection, halted Play release). `blocked` and `rejected` make the run **red**.

## How completion or failure reaches the CEO (existing Thebes / Jira reporting)

This is a real, configured path, with two parts that are stated separately because only one is
automatic:

1. **GitHub side (automatic once the variable is set and the file is on `main`):** the scheduled **Mobile release status**
   run is red on `rejected` or `blocked`, which GitHub emails to everyone watching the
   repository; every run leaves a summary table with the verdict per release.
2. **Thebes side (by the operations dispatch, not by a daemon):** the operations team (Memphis)
   owns each store release as a dispatch. It starts the run, records the run URL and the store
   link in its result, then checks the latest **Mobile release status** run
   (`gh run list --workflow "Mobile release status" --limit 1`, `gh run view <id>`) and reports
   every state change in that dispatch's result; the orchestrator posts it on the release ticket
   and tells the CEO. No separate watcher service exists, and none is promised: if no dispatch is
   active, only the GitHub email in part 1 fires.

Rejections: App Review's rejection reason is shown in App Store Connect (Resolution Center) and
Google's in Play Console. The APIs report the state, not the text; copy the text to the ticket.

## What only the CEO can do (and why automation cannot)

See "CEO actions" in `docs/IOS_RELEASE.md` and the Android section of `docs/ANDROID_RELEASE.md`.
In short: reading the App Store Connect **Issuer ID** (it is shown only in the portal), approving
the first Keychain export of the signing key, and creating the App Store version record with
honest release notes before a public submission.
