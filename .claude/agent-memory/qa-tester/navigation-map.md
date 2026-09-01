# QA tester — navigation map & environment notes (first pass, 2026-08-29)

Learning/familiarization pass only. No login yet (no QA test account provisioned).
No bug tickets filed this pass per PO instruction — findings noted here for the real pass.

## Unauthenticated surface walked (canary.dabbler.pro, 390x844 phone viewport)

- Cold load redirects to `/landing` (matches PROJECT_STATE.md §15b row 1, WORKS).
- `/landing` is a 3-slide auto-rotating testimonial carousel (Aisha/Marcus/Noor), ~2s
  interval, dot indicator at bottom, "Continue" CTA always visible, language picker
  ("English" pill, bottom) and a region pill (labelled "Global" on very first load, then
  "United Kingdom" after IP-geolocation fallback — see below).
- "Continue" → `/auth-welcome` (`AuthWelcomeScreen`): **only Google and Email options
  shown — no phone/OTP "Mobile" entry point visible on web.** The `.maestro` flows
  (00/01/02/03/04) all assume a "Mobile" tap target for phone OTP — that target does not
  exist on the web build's welcome screen. Worth confirming with someone whether phone
  OTP is native-app-only by design, or missing on web. Not filed — just flagging the gap
  between the Maestro fixtures (which target `com.onebrain.dabbler`, i.e. the native app)
  and the web build under test.
- Email signup: `auth-welcome` → "Continue with Email" → `/email_input`
  (`EmailInputScreen`) → Continue button correctly disabled until a syntactically valid
  email is entered (client-side validation confirmed working).
- Login: `auth-welcome` → "Log In" → `/enter-password` (email + password fields, "Send
  email OTP" link, "Continue with Google", "Sign up" link back to email_input). Confirmed
  hard-reload on `/enter-password` correctly restores the same screen (does not bounce to
  landing) — nav-completeness sweep #1 passes for this route.
- Login "Login" button: clicking with email filled but password empty shows inline
  "Enter password" validation and fires **no network request** — correct client-side
  guard, confirmed via armed `read_network_requests` (request list was empty after
  clearing, then only a stray favicon request appeared).
- Language picker (bottom pill on `/landing`) opens a "Choose language" bottom sheet
  with English (checked) and العربية. **Unconfirmed intermittent issue**: one attempt to
  select العربية did not visibly change the UI language or the pill label back on
  landing — but the background carousel auto-advances every ~2s and may have interfered
  with the dialog/click timing. Re-test deliberately (pause carousel awareness) on the
  next pass before treating as a real finding.
- Unknown/invalid path (`/this-route-does-not-exist-qa-check`) redirects to `/landing`
  rather than showing a distinct 404/error page. Likely intentional (the same
  `_handleRedirect` gate treats any unauthenticated+unrecognized path as landing) — not
  filed as a bug, just noting the behavior since `docs/ARCHITECTURE.md` centralizes
  redirect logic there.

## Findings for the next (real) pass — NOT filed, per PO instruction

1. **Email OTP send is broken — HTTP 500.** Confirmed via armed network capture on the
   `/email_input` → Continue flow: `POST .../auth/v1/otp?` returns **500**, and the UI
   shows a generic "An error occurred. Please try again." This is a **silent-failure
   candidate** (rule: any silent failure is HIGH) once I have a real account to test the
   *login*-side OTP too — on this pass I only confirmed it on **signup**. `check_user_exists_by_identifier`
   RPC (called just before) returns 200 fine, so the break is specifically in
   Supabase Auth's OTP dispatch, not the pre-check. Ties to the known `.claude` memory
   entry on the Resend SMTP migration (auth emails were broken on Gmail SMTP, moved to
   Resend) — worth checking whether this 500 is a regression of that same integration
   rather than a new issue. **This blocks reaching the OTP-entry screen UI entirely on
   web** — I could not verify `OtpVerificationScreen` or the maestro-02/03/04 rate-limit/
   invalid/expired-OTP behaviors this pass because signup never gets past `/email_input`.
2. **`https://canary.dabbler.pro/assets/.env` returns HTTP 200 to an unauthenticated
   browser.** Caught passively in the network log while testing the login screen (not a
   deliberate probe). CLAUDE.md states `.env` files are supposed to be blocked by the
   CDN/WAF for web/production, with `--dart-define` used instead specifically because of
   this. A live URL serving `assets/.env` publicly contradicts that. **I did not open or
   read the file** — attempting to navigate directly to it was blocked by this session's
   own permission classifier (reasonably, since it could contain secrets), and I did not
   attempt to route around that block. This needs someone with authorization to check
   the file's actual contents and confirm whether it's a real secret leak or a harmless
   placeholder bundled by the Flutter web build (Flutter does bundle asset files under
   `build/web/assets/` for anything referenced via `AssetManifest`, so a `.env` ending up
   there could be a build-config issue rather than a server config issue — worth checking
   `pubspec.yaml`'s asset list too). **Escalate this ahead of the normal QA queue** — flagged
   to `main` directly in the pass report, not just parked here.
3. Login screen (`/enter-password`) does not carry forward the email typed on the prior
   signup screen — minor friction, not filed (could be intentional separation of login vs
   signup state).
4. Tab title flickers between "Dabbler" (capital D) and "dabbler" (lowercase) across
   navigations/reloads — cosmetic, very low priority, noting only because it's easy to
   forget by the next pass.

## Environment / process notes

- No QA login yet — this remains the standing blocker per the PO's brief. I did not find
  or attempt any workaround; passwordless/OTP design means I structurally cannot receive
  a code without either a provisioned account or a working OTP send path (see finding 1,
  which currently blocks even a *manual* OTP receive-and-enter test).
- `read_network_requests` truly only captures from the moment it's first called on a tab
  — confirmed this the hard way (first "Continue" click produced an empty request list
  because the tool hadn't been armed yet; had to click Continue a second time after
  arming to see the real `otp` 500).
- Screenshot resolution comes back ~1442x840 despite `resize_window` to 390x844 — the
  logical viewport is still 390x844 (confirmed by layout proportions matching a phone
  column), this is just a device-pixel-ratio/backing-store scaling artifact of the
  screenshot tool, not a real desktop-width render. Don't mistake the JPEG dimensions for
  the actual viewport when reviewing my screenshots later.
- Country/IP geolocation: `detect-country` edge function fails client-side
  (`ClientException: Failed to fetch`) but the app **falls back gracefully** to device
  locale ("United Kingdom (GB)" in this Chrome profile) — confirmed via console log, this
  is working-as-intended defensive fallback, not a bug.

## Maestro flows read (`.maestro/dabbler_tests/`, 12 files) — mental model only, not run

Phone-OTP signup/login/resend-rate-limit/invalid-OTP/expired-OTP (00-04), stay-logged-in
(05), email+password signup/login/reset/change-password (06-09), session-expiry (10), and
a draft `feature_test_01_find_nearby_venue.yaml` with 12 detailed scenarios (FNV-001..012)
covering the nearby-venues screen (skeleton/empty/error states, radius filter, sort,
location-denied fallback) — useful acceptance-criteria source for whenever Venues gets a
real pass. Note the phone-OTP flows target the **native app** (`com.onebrain.dabbler`),
not necessarily the web build — see the "Mobile" entry-point gap above.
