---
name: 2026-09-01-android-jdk-fixed-computeruse-blocked
description: JDK toolchain fix confirmed working (Gradle build + install succeed on emulator-5554); Android smoke pass now blocked by a different, platform-level issue — computer-use's Android emulator support is disabled by rollout flag on this machine
metadata:
  type: project
---

## JDK fix CONFIRMED working

Team-lead set `flutter config --jdk-dir` to a JDK 24 install to fix the
Gradle 8.14.3 vs JDK 25 mismatch documented in
[[2026-08-31-retest-and-android-attempt]]. Reran `flutter run -d
emulator-5554 --dart-define-from-file=.env` from a clean state: Gradle
`assembleDebug` completed (`BUILD SUCCESSFUL in 1m 4s`), APK built and
installed on `emulator-5554`, app launched (`com.dabbler.dabblerapp`,
ProfileInstaller ran). No JDK/toolchain error anywhere in the log. **The JDK
blocker is resolved** — this path is no longer the obstacle.

## NEW blocker: computer-use cannot see/control the Android emulator on this machine

`mcp__computer-use__request_access` for "Android Emulator", the actual
process name `qemu-system-aarch64`, and the adb serial `emulator-5554` all
returned `notInstalled` — computer-use does app-list matching and the
emulator process isn't found under any of these, even though
`ps aux` confirms `qemu-system-aarch64 ... -avd Dabbler_test` is genuinely
running (pid confirmed live).

Root cause visible in the Claude Desktop process's own `--desktop-features`
JSON (captured via `ps aux`): `"androidEmulator":{"status":"unsupported",
"reason":"Android emulator is disabled by its rollout flag",
"unsupportedCode":"unknown"}`. This is a **platform-level feature flag**,
not a naming issue or a permission the user can grant — computer-use's
Android-emulator capability is turned off in this rollout, independent of
whether the emulator itself is running fine.

**Not an app bug, not the JDK issue, and not something QA or the PO can fix
by retrying with different app names.** Escalate to whoever controls Claude
Desktop's rollout flags if a native Android pass via computer-use is
actually needed; otherwise Android-native verification stays blocked until
that flag flips. Chrome/local-dev-server QA (unaffected) remains the
default surface per the standing agent instructions.
