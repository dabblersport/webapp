# KAN-58 — Sign out / FCM revoke / store teardown — re-verification story

Status per docs: closed 2026-08-29 (fixed). Re-verify, don't trust the ticket status.

## Steps
1. Fresh load canary.dabbler.pro (390x844), sign in with QA account
   (dabbler.pro@proton.me).
2. Note any locally-set preference (e.g. change language/theme if a quick toggle
   exists) before signing out, to check preference stores survive teardown.
3. Arm read_network_requests. Navigate to sign-out control (Settings/Profile menu).
   Click sign out.
4. Screenshot immediately after click. Expected: redirect to /landing or
   /auth-welcome, no authenticated content flashes after redirect.
5. Read network requests: expect a request that clears/revokes the FCM token
   (or a Supabase call consistent with sign-out) with 2xx status. Flag if none.
6. Reload the page cold. Expected: still signed out (session not restored) —
   confirms session-scoped stores were cleared, not just UI-navigated away.
7. Check that preference-scoped state (theme/locale) noted in step 2 survived
   the sign-out (per ROADMAP.md B9: theme_service, locale_provider,
   notification_preference must survive teardown) — i.e. NOT wiped along with
   session data.
8. Sign back in with QA account to confirm re-login works after teardown (no
   leftover corrupt state blocking re-auth).
9. Check console for uncaught exceptions during the whole flow.

## Result — executed 2026-08-29 — PASS

- FCM revoke confirmed via console log: `Web FCM token revoked for user
  a3ba3271-3556-4b4e-b15d-bc0851f8a64b` fired immediately on sign-out confirm.
- Session teardown confirmed: cold reload after sign-out landed on `/landing`
  (unauthenticated), not restored session.
- Preference survival confirmed: switched language to Arabic before signing out;
  Arabic selection (and full RTL layout) survived sign-out AND the subsequent
  cold reload — theme/locale preference is not wiped by teardown, matching the
  ROADMAP B9 requirement.
- Re-login confirmed: signed back in with QA credentials immediately after
  sign-out, no blocked/corrupt state; landed on "Welcome Back" screen and into
  the app normally.
- No console errors during the flow (checked via `read_console_messages`).

**Two new bugs found along the way (filed, not blocking KAN-58 itself):**
KAN-94 (MEDIUM) — Arabic locale leaves `/auth-welcome`, `/welcome`, and the
`/landing` carousel partially untranslated with RTL-mirrored English punctuation.
KAN-95 (LOW) — emoji render as missing-glyph boxes intermittently on feed posts
and auth screens (`Could not find a set of Noto fonts...` console warning).

## Pass/fail criteria
- FAIL (HIGH) if any authenticated screen/data is visible after sign-out+reload.
- FAIL (MEDIUM) if preference stores (theme/locale) are wiped by sign-out.
- FAIL (HIGH) if re-login is blocked/broken after sign-out.
- Silent failure (network call for FCM revoke fails but UI shows signed out
  normally) is HIGH per house rule, but only fileable if reproducible.
