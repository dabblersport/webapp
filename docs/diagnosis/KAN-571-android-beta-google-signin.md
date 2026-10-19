# KAN-571: Android beta Google sign-in fails with `ApiException: 10`

Sanitized. Only public fingerprints, package names and client-id prefixes appear. No token, password, email, account id or secret.

## The symptom (CEO screenshot, 2026-10-19)

On the Play internal beta, Google sign-in shows `Could not sign in with Google: Exception: Google sign-in failed: PlatformException(sign_in_failed, com.google.android.gms.common.api.ApiException: 10: , null, null)`.

- `ApiException: 10` is `DEVELOPER_ERROR`: Google Play services refused the request because the app's **package name + signing-certificate SHA-1 pair is not registered on an Android OAuth client** in the Google Cloud project (or the client is misconfigured). It is raised on the device, in the native account chooser stage, **before any id token exists and before any request to Supabase**. So Supabase and the user's credentials are not the failing layer for this symptom.
- The text format (`Exception: Google sign-in failed: PlatformException(...)`) is the pre-KAN-570 error handling. The beta is built from `77b42c24` (1.7.9+176, internal track, run 39153963729), which does not contain the sanitized `google:<stage>:<code>` change. That change does not alter whether the sign-in works; it only changes what the screen prints.
- Not known from the screenshot: the build number and the attempt time. They are not asserted.

## Evidence gathered (read-only)

| Item | Value | Source |
|---|---|---|
| Package | `com.dabbler.dabblerapp` | Play status run, `android/app/google-services.json` |
| Beta tested | 1.7.9 (176), internal track, `completed` | read-only status workflow, run 39197962359 |
| **Certificate Google Play signs this version with (APP SIGNING key)** | SHA-1 `E5:4B:FD:E6:B0:3E:DE:AD:00:BA:FE:F8:B8:BB:66:10:78:99:A4:06`; SHA-256 `63:7C:76:9E:53:B2:D5:DC:84:EB:E2:8A:14:BF:5F:49:3D:D4:8E:86:A0:73:17:99:0E:E2:2D:84:DD:B2:9C:AF` | Play Developer API `generatedapks` for 176; the SHA-1 was computed from the generated APK's v2/v3 signing block, and its SHA-256 equals the SHA-256 the API returned (cross-check) |
| Upload certificate (not what devices see) | SHA-256 `3D:3A:63:C9:DA:82:E3:41:D7:0F:3A:E2:E4:98:54:70:C9:91:C3:9B:42:F7:13:69:11:77:28:BC:61:B9:6F:CE` | recorded in the release workflow; differs from the app-signing key, as expected |
| **Android OAuth client recorded in the repository's `google-services.json`** | package `com.dabbler.dabblerapp`, SHA-1 `0E:E1:B2:E9:04:0D:56:E5:86:07:20:8B:1A:7D:44:7F:EE:B0:22:05` | `android/app/google-services.json` (client type 1, project `dabblersportapp`) |
| Web client | client type 3 present, same project (number prefix `8363453`) | same file |
| `GOOGLE_WEB_CLIENT_ID` in the release build | injected from the repository secret (set 2026-02-26); the workflow now refuses an empty value (KAN-570). Its value was not read. | `.github/workflows/android-release.yml` |

Note on the registered SHA-1: the file records the value `0ee1b2e9040d56e58607208b1a7d447feeb02205` (40 hex digits). It is **not equal** to the Play app-signing SHA-1 above.

## What this shows, and what it does not

- **Shown:** the only Android client/certificate pair recorded in the repository is not the certificate Google Play signs the installed beta with. A Play-installed build is signed with the app-signing key, so Google's check for `com.dabbler.dabblerapp` + `E5:4B:FD:E6:…:A4:06` finds no matching registration if the live Google Cloud project holds the same set. That produces exactly `ApiException: 10`. This is consistent with the screenshot and explains why the Play-installed build fails while a debug or locally-signed build (whose SHA-1 is the registered one) would work.
- **Not shown:** `google-services.json` is a snapshot from when it was last downloaded; the live Google Cloud Console may already list more SHA-1s. Reading the live OAuth client list needs Google Cloud access that this environment does not have. So the repository evidence is strong but is **not yet a confirmed live mismatch**.
- **No id_token exchange expected:** `ApiException: 10` happens before the token exists. Earlier read-only Supabase auth logs (KAN-570) show no native Android `id_token` grant in the inspected window, which is consistent.

## The smallest correction (outside the repository; needs Google Cloud access)

In Google Cloud project `dabblersportapp` → APIs & Services → Credentials → the **Android** OAuth client for package `com.dabbler.dabblerapp`: add the Play app-signing SHA-1 `E5:4B:FD:E6:B0:3E:DE:AD:00:BA:FE:F8:B8:BB:66:10:78:99:A4:06` (keep the existing one; if no Android client exists for the package, create one with that package and SHA-1). Do not touch the Web client, scopes or keys. No new build and no Supabase change is needed: the already-installed beta should work after Google propagates the change (usually minutes). This is a configuration edit through the approved operations path, not made by this ticket.

## Validation still required (not done; no success claimed)

1. After the SHA-1 is registered, the CEO retries Google sign-in on the **same installed beta** once and reports the clock time (to the minute, with the time zone) and the on-screen result.
2. Expected on success: a native Android `id_token` grant appears in Supabase auth logs at that time (country AE, `Dart` user agent), followed by the normal profile reads; ordinary password login on the beta still works.
3. If it still fails with `ApiException: 10`, the live client list is checked against the SHA-1 above and the package name character by character; if it fails with a different code, the stage-tagged `google:<stage>:<code>` message from the next internal build names it.

## Read-only tooling added

`scripts/android/play_publish.py status` now also reports the public Play app-signing certificate fingerprints (SHA-256 from the Play API, SHA-1 from the generated APK's signing block). It is read-only, prints no secret, never raises, and is covered by offline tests (`python3 scripts/android/test_play_publish.py`, 16 tests).
