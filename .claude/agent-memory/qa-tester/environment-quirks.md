---
name: environment-quirks
description: Chrome MCP tooling quirks specific to this session/environment discovered 2026-08-29 — scroll not working on Flutter canvas, resize_window not honored, network capture timing
metadata:
  type: project
---

**`computer` tool's `scroll` action does not scroll Flutter/CanvasKit content in
this environment.** Confirmed on both the Settings screen and the home feed:
repeated `scroll` calls (wheel-tick simulation) produced zero movement, even
after clicking to focus first. Workaround that works reliably: dispatch a real
`WheelEvent` via `javascript_tool`:
```js
const el = document.elementFromPoint(x, y);
el.dispatchEvent(new WheelEvent('wheel', {deltaY: 1200, deltaMode: 0, bubbles: true, cancelable: true, clientX: x, clientY: y}));
```
Use this instead of `computer{action:"scroll"}` whenever content doesn't visibly
move after 1-2 scroll attempts. Don't conclude "screen doesn't scroll" (a bug)
until confirming with this JS method first — the house anti-pattern of reporting
an absence without confirming the check could have found the thing applies here.

**`resize_window` did not change this session's actual CSS viewport.** Requested
390x844 and later 316x700; `window.innerWidth` stayed at 606 regardless
(`window.outerWidth` ~489, `devicePixelRatio` 2). This means true mobile-width
testing (the compact bottom-nav pill layout, distinct from the wider
side-nav-with-icon-rail layout actually rendered) was NOT achieved this session
despite requesting it. Verify with `javascript_tool` (`window.innerWidth`)
before trusting that a `resize_window` call actually narrowed the viewport —
don't rely on screenshot pixel dimensions, which are a scaled backing-store
artifact per [[navigation-map]]'s earlier note and don't reflect true CSS width
either.

**`read_network_requests` can miss the real POST/DELETE of an action, showing
only its OPTIONS preflight, on the FIRST attempt after arming — even though the
tool worked correctly moments before/after.** Confirmed as a timing/capture
artifact, not app behavior: a `profile_follows` POST and a `report_content` POST
were both invisible on first read (only OPTIONS showed) but appeared cleanly
with a full 200/409 status on an immediate retest of the identical action from a
fresh page load. **Before concluding a request never fired (silent-failure
candidate), redo the exact action once more from a clean state and re-check** —
don't file on a single OPTIONS-only read. Same pattern seen 2026-08-30 with the
`/auth/v1/otp` POST on the signup screen — first read showed only OPTIONS; the
retry (clicking "Resend code" and re-reading immediately after) captured the
real POST/200 cleanly.

**The Settings screen's internal list does not respond to `computer{scroll}`,
`WheelEvent` dispatch, `left_click_drag`, or synthetic `pointerdown`/`pointermove`/
`pointerup` sequences — tried all four on 2026-08-30, zero movement each time.**
Don't burn time on scroll workarounds here. If you need to sign out to reach an
unauthenticated state for testing (no visible Sign Out control was found within
the reachable — unscrolled — portion of Settings/Account Management, which only
showed Update Email / Change Password / Delete Account), the reliable path is
clearing the Supabase session client-side and reloading:
```js
localStorage.removeItem('sb-wtncuzcskpigqpmnxwws-auth-token');
```
then navigate to `https://canary.dabbler.pro` — it lands on `/landing` logged
out. This is a client-only local-storage clear, not a destructive account
action. Note this does NOT confirm whether a real Sign Out control exists
further down the Settings list (unreached) — don't report "no sign out option"
as a finding without exhausting scroll workarounds first.
