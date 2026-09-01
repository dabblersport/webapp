---
name: 2026-08-31-retest-and-android-attempt
description: Password-field blocker confirmed resolved on fresh Chrome; KAN-45/KAN-88/KAN-99 all confirmed fixed; Android emulator smoke pass blocked by a Gradle/JDK toolchain mismatch (not an app bug)
metadata:
  type: project
---

## Password-field blocker (see [[2026-08-31-local-dev-smoke-pass]]) — RESOLVED

Team-lead switched the controlled browser to a fresh Google Chrome instance
(not the Brave profile that broke 5 times previously). Retested the exact
sequence that broke before: click into `/enter-password`'s password field,
type into it, screenshot. All three succeeded, tab stayed fully responsive
throughout, and login completed normally. **This blocker is gone as of
2026-08-31** — no more password-manager-extension conflict on this browser
profile. Authenticated-flow testing is unblocked going forward.

## KAN-45, KAN-88, KAN-99 — all confirmed fixed this pass

Tested against local dev (`flutter run -d chrome --dart-define-from-file=.env
--web-port=8765`), authenticated as the QA test account.

- **KAN-45** (Message button should be hidden): visited another user's
  profile (Nixon, via a "Nixon started following you" notification) — no
  Message button anywhere on the profile screen, and the "..." overflow menu
  only shows Block user / Report user. Confirmed on two full navigations to
  the profile (once for the initial check, once when retesting for the
  ParentDataWidget console error below). No Message entry point reachable.
- **KAN-88** (notification tap → game detail, not error page): tapped the
  "You're in! Your request to join was accepted." notification from
  Notifications → All. Opened the real game detail screen ("New Game
  Tomorrow", Aktiv Nation, Al Quoz 3, 7/12 players, "You're in" banner) — not
  an error page. Note: this pushes as a nested-navigator/modal without
  updating the URL (stayed at `/home` in the address bar) — a reload here
  would lose the detail view. That's a separate, minor nav-completeness note,
  not a KAN-88 regression — not filing, since the ticket's actual claim
  (real detail screen vs error) is confirmed working.
- **KAN-99** (sign-out should not throw a Navigator console error): armed
  console reading, clicked Sign Out → confirmed. Console showed a clean
  sequence — FCM token revoked, Supabase `SignOutScope.local`, GoRouter
  redirect `/home` → `/landing` (unauth) — zero exceptions, zero Navigator
  errors. Landed cleanly on `/landing`, fully rendered.

## New: intermittent FlutterError on Settings/Profile — NOT filed (couldn't reproduce twice)

Saw one occurrence of `FlutterError: Incorrect use of ParentDataWidget.
Competing ParentDataWidgets... RichText ← Text ← Flexible ← Flexible ← Row ←
_OutlinedButtonWithIconChild ← Align ← Padding ← Listener ←
RawGestureDetector` in console right after opening Settings via
avatar → gear icon the first time. Retested the identical path (fresh login →
home → avatar → gear icon → Settings, then also the JS-WheelEvent scroll
workaround on the Settings list) twice more — did not reproduce either time.
Per the two-clean-runs filing rule, **not filed** — noting here in case a
future pass sees it again; if it recurs, the stack trace points at an
`OutlinedButton.icon` somewhere on Profile or Settings with two `Flexible`s
competing for the same Row (candidates: "Edit profile"/"Share profile" pill
buttons on the own-profile screen, or "Become a Organiser" row on Settings).

## Android emulator smoke pass — BLOCKED, root cause found, not an app bug

`flutter devices` confirmed `emulator-5554` (`sdk gphone16k arm64`, Android 17
API 37) visible and nothing already installed/running there. Ran `flutter run
-d emulator-5554 --dart-define-from-file=.env` twice (fresh attempts) — both
failed identically at the Gradle step in under 1 second:

```
FAILURE: Build failed with an exception.
* What went wrong:
25.0.2
BUILD FAILED
```

**Root cause identified**: `flutter doctor -v` shows the Android toolchain's
Java binary is the JDK bundled with the latest Android Studio install,
version `25.0.2`. Gradle 8.14.3 (this project's wrapper version) does not
support JDK 25 — that bare "25.0.2" IS the Gradle error, not a coincidence.
Confirmed by running `cd android && ./gradlew assembleDebug` directly from
the shell: **that succeeded** (`BUILD SUCCESSFUL in 18s`), because the shell's
default `java` is a different, older build (OpenJDK 24.0.2) that Gradle 8.14.3
does support. `flutter config --jdk-dir` is unset, so `flutter run` falls back
to Android Studio's bundled JDK 25 specifically for its Gradle invocation,
which is what fails.

**This is a machine/toolchain misconfiguration, not an app bug** — no QA
ticket filed. The fix is one of: point Flutter at a Gradle-8.14-compatible
JDK via `flutter config --jdk-dir=<path-to-jdk-24-or-earlier>`, or bump the
Gradle wrapper version in `android/gradle/wrapper/gradle-wrapper.properties`
to one that supports JDK 25. Neither is a QA action (no code-write access,
and `flutter config` changes global machine state) — flagging to whoever owns
this machine's Android toolchain (cto or PO) to decide the fix, then the
Android smoke pass can run. **The emulator itself, the app's Gradle project,
and the build config are otherwise fine** — direct `./gradlew assembleDebug`
proves the app compiles correctly on Android; this is purely an invocation
path issue.

## Environment note: shared browser window kept resizing mid-pass

Viewport genuinely changed size several times mid-pass (1305x924 → 1481x812 →
500x987) confirmed via `window.innerWidth` JS reads, not a screenshot
artifact this time — likely another parallel agent sharing the same Chrome
instance (multiple `qa-tester-N` agents are listed as active in this swarm
session). Coordinates from a stale screenshot silently miss their target
(one click landed on a different nav item than intended). **Always
screenshot immediately before each click when the viewport might be shared**
— don't trust coordinates from more than one tool-call ago in this kind of
multi-agent session.
