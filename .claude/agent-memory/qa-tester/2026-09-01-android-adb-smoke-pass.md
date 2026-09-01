---
name: 2026-09-01-android-adb-smoke-pass
description: First successful interactive Android pass, driven via raw adb shell commands (computer-use still blocked for this emulator); technique notes and smoke-pass results
metadata:
  type: project
---

First real interactive Android QA pass succeeded, routed around the blocked `computer-use`
Android surface (see [[2026-09-01-android-jdk-fixed-computeruse-blocked]]) by driving the
emulator directly with `adb` shell commands through Bash.

**Technique — adb path and screen capture:**
- `adb` is not on PATH by default on this machine. Full path:
  `~/Library/Android/sdk/platform-tools/adb`.
- Device this session: `emulator-5554`, resolution **1280x2856** (get via
  `adb -s emulator-5554 shell wm size` — always re-check per session, don't assume).
- Screenshot: `adb -s emulator-5554 exec-out screencap -p > file.png`.
- Tap: `adb -s emulator-5554 shell input tap <x> <y>` in **real device pixel space**, not
  any scaled preview size.
- Swipe/scroll: `adb -s emulator-5554 shell input swipe x1 y1 x2 y2 <duration_ms>`.
- Back button: `adb -s emulator-5554 shell input keyevent 4`.
- `uiautomator dump` produces an accessibility tree, but it's **useless on this app** — all
  `text=""`, same root cause as the CanvasKit web constraint: Flutter renders as a single
  canvas with no exposed semantics by default. Don't bother trying it again; go straight to
  screenshot+coordinates.

**The costly mistake this session — coordinate misjudgment from the scaled screenshot
preview, not an app bug.** When Read tool shows a screenshot, it auto-scales large images
for display (e.g. "original 1280x2856, displayed at 896x2000") and my own visual estimate
of a control's position in that preview was off by ~1000px in Y on a long screen (I read
the bottom nav pill as being at display-y≈1206 when it was actually at display-y≈1878;
naive ratio math was right, my eyeballing in the small preview was wrong). This produced
a long false trail: taps that seemed to land on "nothing" or on the wrong element (opening
a random feed post instead of the nav button) were **entirely my own targeting error**, not
inert buttons or hit-test bugs. **Fix: when a tap's result doesn't match what the visual
target should do, don't conclude the control is broken — crop and pixel-scan the actual
screenshot file with PIL first** (`img.crop(...)`, scan rows/columns for the color
boundary) to get exact coordinates before re-testing. This is far more reliable than
eyeballing a downscaled preview, especially near the bottom of a tall 1280x2856 screenshot.

**Confirmed working (Android native, emulator-5554, PO's authenticated session, Ajman
Downtown location):**
- Home feed loads, scrolls smoothly, posts render correctly (avatars, tags, engagement
  icons, sport chips).
- Notification bell → Notifications screen: All/Games/Bookings tab filters work correctly
  (Games filter correctly reduced 20→16 items, i.e. excluded 2 follow-notifications, though
  a couple more than expected were dropped visually — not confirmed as a bug, just noted).
  Back button returns cleanly to feed with scroll position preserved.
- Bottom floating pill nav (Feeds/Venues/[grid]/[+]) all four controls work:
  - Grid icon switches to a **Games section** (separate bottom nav: Home/Games/+), with
    sport filter chips (All/Padel/Football/Cricket) and a genuine empty state ("No games
    yet — Be the first to create a game in your area!") — correctly triggered, not a false
    empty state, since there really are no games for Ajman Downtown.
  - "+" opens a working action sheet (Create Post / Create Game).
  - "Create Post" composer is solid: identity header, Dab/Public audience toggles, text
    field with live char counter (0/2000), emoji/trophy/location/game-tag icons, Media/GIF
    attach buttons, Allow reposts / Pin to profile / Set expiry toggles, and a Post button
    that only activates once text is entered. Cancel discards the draft cleanly (verified
    via feed hash/visual diff — no orphan post created).
  - Did **not** submit a real post — the classifier blocked the actual "Post" tap as a
    live write action, appropriately. Compose UI itself fully verified short of the final
    network call.
- Post detail screen (tap into any feed post): shows full post, tags, timestamp, "No
  replies yet" empty state, and a working reply input at the bottom.
- Profile (avatar tap): bio, stats (Posts/Following/Followers), Sports tags, Edit
  profile/Share profile buttons, and Posts/Replies/Liked/Reposts/Activity tabs. Replies tab
  loads real threaded content correctly.
- Settings (gear icon on profile): loads with a brief spinner on the "Profiles" section
  that resolves to a working Player/Organiser account switcher; Account Management,
  Privacy Settings, Theme, Language, App Country, Terms/Privacy/Licenses, and Sign out are
  all present and rendered correctly.

**Deliberately not tested — Sign out.** Found and screenshotted but did not tap. Accounts
are passwordless/OTP-only ([[passwordless-auth]] in project root memory), and QA has no
way to receive an OTP to log back in. Signing out the PO's active emulator session would
strand it with no automated recovery path. Flag as blocked-by-design for any future
sign-out testing pass — needs either OTP access provisioned to QA or the PO doing that one
tap themselves while QA drives the rest.

**No bugs filed this pass.** Everything exercised worked as expected once real coordinates
were used. The apparent "dead button" and "wrong navigation" symptoms earlier in the
session were retargeting artifacts, confirmed by re-testing at corrected coordinates.
