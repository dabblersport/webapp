# KAN-570: Android Google sign-in and login failures: diagnosis

Sanitized. No token, password, email, client secret or account data appears here. Status: **root cause NOT yet evidenced; the failing stage cannot be proven from the repository and the authorised read-only tools.** What is proven, what is not, and the exact access still needed are below.

## What is verified

| Question | Evidence | Result |
|---|---|---|
| Version served publicly | Existing read-only workflow, run 39195911397 (`mode=status`, `track=production`, 1.7.8 / 174) | `com.dabbler.dabblerapp` 174 (1.7.8) is on the **production** track, status `completed`, "public store page shows the version" |
| Is 1.7.9 (176) public | Run 39195812309 (same workflow, 1.7.9 / 176, production) | `ok: false`; 176 is on the **internal** track only (run 39153963729, built from `77b42c24`). It is not public. |
| Client-safe defines of the Play builds | `.github/workflows/android-release.yml` "Build the signed App Bundle" | `GOOGLE_WEB_CLIENT_ID` is passed as `${GOOGLE_WEB_CLIENT_ID:-}`: **an empty secret does not fail the build**. Only `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `APP_NAME` are required. The repository secret `GOOGLE_WEB_CLIENT_ID` exists (set 2026-02-26; its value was not read). |
| Supabase sees Google/email logins | Supabase auth logs (read-only), 2026-10-17 and 2026-10-18/19, aggregate counts only | Password logins: `grant_type=password` 200 (22 in the last 24 h, none refused). Token refresh 200. One Google **PKCE** login (web/iOS flow) completed. **Zero `id_token` grant requests, successful or refused**, in the 48 h window. One `otp_expired` 403. |

## What the evidence says

- **Google on Android**: the native flow ends in `signInWithIdToken`, which would appear in Supabase as an `id_token` grant. None appears, accepted or refused. So no native Android Google sign-in reached Supabase in the window, which is what a failure *before* the exchange looks like (the account chooser / Credential Manager, or no id token returned), or simply no attempt in the window. The CEO's attempt time was not given, so this is consistent with, not proof of, an on-device failure.
- **Likely stage, from code, not proven**: `lib/core/services/auth_service.dart` (`signInWithGoogle`, Android branch) passes `serverClientId` from `GOOGLE_WEB_CLIENT_ID`. Two configuration causes would fail before the exchange: (a) the Android OAuth client in Google Cloud does not contain the **Play App Signing** certificate SHA-1 for `com.dabbler.dabblerapp` (the upload key was reset on 2026-10-11; the Play signing key is a different key and is what users' devices see), which gives `ApiException: 10` (DEVELOPER_ERROR); (b) the build was made with an empty `GOOGLE_WEB_CLIENT_ID`, which gives no id token. Neither can be confirmed from here.
- **Second failure ("Login failed")**: Supabase shows no refused password login (no 400 `invalid_credentials`) in the window, so an authentication rejection is not what it looked like. In `email_password_screen.dart` a successful `signInWithEmail` is followed by `handleSuccessfulLogin` and `getUserProfile` inside the **same** try/catch; any exception there is shown as the generic "Login failed." (`email_password_error_login_failed`). The reported strings ("Couldn't Sign with Google", "Login Failed") are not in the current Alpha ARB (the nearest are "Google sign-in failed" and "Login failed."), so they come from a different or older build or are paraphrased. The screen and method of the second failure were not identified.

## What changed in this ticket (diagnosis aid only, no behaviour change on success)

`signInWithGoogle` (Android) used to wrap everything as `Exception('Google sign-in failed: $e')`, which put the provider's raw text on screen (`auth_welcome_google_error`). It now throws `GoogleSignInFailure(stage, code)` (`lib/core/models/google_sign_in_failure.dart`) with the stage (`native`, `idToken`, `exchange`) and only a sanitized code (an Android API status number such as `10`, a Supabase error code such as `bad_jwt`, or `no_server_client_id` / `missing` when no id token came back). The screens show `google:<stage>:<code>`, so the next failing run names its stage without a secret. Cancellation (null account) and the iOS/web flows are unchanged. Tests: `test/core/models/google_sign_in_failure_test.dart`.

## What is still needed (cannot be done with the authorised tools here)

1. **Reproduction on a Play-installed build** of 1.7.8 (174) and the internal 1.7.9 (176) with an approved test account: read the `google:<stage>:<code>` text (needs a device, and this change shipped in an internal build).
2. **Google Cloud console** (project `dabblersportapp`): confirm the Android OAuth client for `com.dabbler.dabblerapp` lists the **Play App Signing** SHA-1 (Play Console, App integrity), and that the Web client id matches the `GOOGLE_WEB_CLIENT_ID` secret and the Supabase Google provider.
3. **Supabase dashboard**: Google provider enabled with that Web client id (a refused exchange would show as an `id_token` 400 in auth logs once an attempt is made).
4. A **store-signed internal validation build** that completes Google sign-in and the second login path (acceptance criterion 2). No emulator/debug result is claimed.

No public release or configuration deployment was made. If cause (b) is confirmed, the fix is to make the Android release workflow refuse an empty `GOOGLE_WEB_CLIENT_ID` (an existing-file change in the allowed paths) and rebuild; if (a), it is a Google Cloud OAuth client change through the approved operations path.
