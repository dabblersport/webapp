---
name: 2026-08-31-local-dev-smoke-pass
description: Broad smoke pass on local dev server (flutter run -d chrome, port 8765) 2026-08-31 — blocked on login by a Chrome-extension conflict on password-field focus, three new tickets filed, KAN-89 OTP-500 still broken despite Done status
metadata:
  type: project
---

Broad smoke pass requested by team-lead across sprint-2 fixes (KAN-45, KAN-88,
KAN-99, KAN-68-skip). Local dev server target per updated agent definition
(`flutter run -d chrome --dart-define-from-file=.env --web-port=8765`).

## Standing blocker discovered this pass: password-field focus breaks the Chrome automation tab

On `/enter-password`, focusing the password input (via click OR Tab-key
navigation, tried both) reliably breaks the `claude-in-chrome` extension's
access to that tab — every subsequent tool call on the tab (`type`,
`screenshot`, `javascript_tool`, even `key`) fails with `Cannot access a
chrome-extension:// URL of different extension`. Reproduced identically across
**4 independent fresh tabs**, including one attempt where the password field
was first toggled to `type=text` via the reveal-eye icon before focusing (no
effect — same failure). The only recovery is closing the tab and opening a new
one; the broken tab never self-heals.

**This is almost certainly a third-party browser extension (a password
manager) installed in this Chrome profile injecting a `chrome-extension://`
overlay/iframe into the page on password-field focus**, which the automation
extension can't cross. It is NOT an app bug — the email field, all buttons,
and every other input on this and other screens work fine with the same
tooling.

**Practical effect: password-based login is untestable with current browser
tooling in this environment**, on top of the pre-existing "no OTP receive"
blocker. This blocks all authenticated-flow testing (KAN-45 Message button,
KAN-88 notification deep link, KAN-99 sign-out console error) — none of these
three could be tested this pass. Flag to whoever manages this machine's Chrome
profile: check for a password-manager extension (1Password/Bitwarden/LastPass/
Dashlane/etc.) and consider disabling it for the QA profile, or find another
workaround (e.g. a Chrome profile with no such extension) before the next
pass, since this will recur identically.

**Update same session:** the controlled browser is actually **Brave**, not a
separate Chrome install (per team-lead correction) — the `claude-in-chrome`
tools work identically regardless of underlying browser brand. Re-tested after
a dev-server port mixup was resolved (see below) and the password-field
blocker reproduced a **5th time**, byte-identical failure, confirming this is
a persistent Brave-profile issue (likely Brave's built-in password
manager/autofill, or a similar extension) and NOT related to the server
restart or port confusion. Check `brave://extensions` on this machine for a
password-manager-style extension before the next pass.

QA credentials do exist and are valid (`.claude/agent-memory/qa-tester/credentials.local.md`) —
the blocker is purely the browser-tooling conflict, not missing credentials.

## Also discovered: local dev server died mid-session, then a port mixup

Partway into this pass, `localhost:8765` stopped responding entirely (curl
`000`, no `flutter run` process, nothing on the port) despite team-lead having
started it before dispatch. Restarted it myself via `nohup flutter run -d
chrome --dart-define-from-file=.env --web-port=8765 &` — safe, reversible,
matches exactly what was already running. Took about 45-60s to rebuild and
serve after restart (Waiting for connection from debug service on Chrome →
first 200 response → still ~15s more before the actual app content renders,
not just the loading spinner). If a future pass hits `curl: (7) Connection
refused` on the expected local port, don't assume it's still starting — check
`ps aux | grep flutter run` and `lsof -iTCP:<port>` first, it may have crashed.

Team-lead then redirected to `localhost:3000` (a claimed restart), which
turned out to be serving a **completely unrelated site** — a personal
portfolio/Next.js project ("Moataz Mustapha" — matches the `Moataz_Next`
project referenced in this session's environment notes), not Dabbler. Root
cause per team-lead: port 3000 was already occupied by that unrelated Node
dev server, so Flutter's dev server failed to bind there silently and never
actually started — team-lead's port instruction was based on a wrong
assumption, not something I misconfigured. **Lesson: always verify a
redirected dev-server URL actually renders the expected app (check for
recognizable branding/content) before running any test steps against it —
don't trust a 200 status or "just restarted" claim alone.** Corrected back to
`:8765`, confirmed working, this pass's already-filed findings all stand
against that port.

## Findings filed this pass

- **KAN-89 comment** (not new ticket — ticket already existed and is marked
  Done, but is NOT actually fixed): email OTP send still returns HTTP 500
  (`POST .../auth/v1/otp` → 500, `AuthRetryableFetchException`,
  "Error sending magic link email") on the signup path from `/email_input`.
  Reproduced twice with two fresh emails, full network evidence captured.
  This ticket needs re-opening by task-auditor/backend-owner — closing it was
  premature or the fix didn't actually land. **Flag prominently: a Done ticket
  for a still-broken core flow is itself worth a governance note, not just a
  QA re-finding.**
- **KAN-108** (MEDIUM): `/email_input` Continue button stays silently disabled
  for a valid plus-addressed email (`name+tag@domain.com`), no error shown.
  First seen 2026-08-30 on canary (unticketed at the time, see
  [[plus-address-email-validation]]), now reproduced a second time on local
  dev 2026-08-31 — confirmed still open, now properly ticketed.
- **KAN-109** (LOW): console-only finding — an unauthenticated `flags_snapshot`
  analytics event fails a NOT NULL constraint on `analytics_events.user_id`
  every time on pre-auth screens. Caught/logged, no visible UI impact, but
  silently drops analytics for every anonymous visitor.
- **KAN-110** (HIGH): cold-load / direct full-page navigation to an
  unregistered route (e.g. typing a bogus URL, or a stale/shared/bookmarked
  deep link) renders a **permanent blank white screen** — no redirect to
  `/landing`, no error UI, no console errors, `document.readyState` reports
  `complete`. This is DIFFERENT from in-app client-side navigation to an
  unknown route, which correctly redirects to `/landing` (confirmed working in
  an earlier pass, see [[navigation-map]]). Reproduced twice with two
  different bogus paths, 10+ second wait each time to rule out slow-load.
  Unverified whether this is local-dev-debug-server-specific vs also present
  on the release build served at canary/production — worth checking both.

## Confirmed still-working (not re-filed)

- `/landing` → `/auth-welcome` → `/email_input` and → `/enter-password`
  navigation chain all work identically to the canary pass.
- Hard-reload on `/enter-password` and `/email_input` correctly restores the
  same screen (does not bounce to landing) — this is normal in-app-route
  reload, distinct from the KAN-110 finding above which is about truly
  *unregistered* paths.
- The brief overlapping-carousel-content flash seen once during the
  landing→auth-welcome transition on this pass was confirmed transient (a
  second screenshot ~2s later showed a clean auth-welcome screen) — not filed,
  consistent with a transition-animation-timing artifact rather than a bug.

## Not tested this pass (blocked)

KAN-45 (Message button hidden vs Coming Soon), KAN-88 (notification tap →
game detail), KAN-99 (sign-out console error) — all require an authenticated
session, which the password-field tooling blocker (above) made unreachable.
Android emulator pass also skipped per brief (Android Studio pending updates).
