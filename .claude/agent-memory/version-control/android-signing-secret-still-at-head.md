---
name: android-signing-secret-still-at-head
description: The Android plaintext signing password (SEC-11/KAN-57) is still in the tracked file at HEAD — the fix exists only as an uncommitted working-tree change, despite briefs claiming it was handled
metadata:
  type: project
---

**As of 2026-08-28 (HEAD `2d52157`), `android/app/build.gradle.kts` still contains
plaintext `storePassword` / `keyPassword` literals at lines 36 and 38.** The
remediation — loading them from a gitignored `android/key.properties` — exists only
as an **uncommitted working-tree modification**. It has never been committed.

Verify, don't trust the claim:
```
git show HEAD:android/app/build.gradle.kts | grep -n Password
git log -S storePassword -- android/app/build.gradle.kts   # introduced ebaf9b8, 2025-11-22
```

**Why:** a task brief on 2026-08-28 asserted the password was "already handled in a
prior commit — do not touch `android/` files". That was false: the working tree looked
fixed, so a reader who ran `cat` or `git diff` saw clean code, while `HEAD` and every
published ref still carried the literal. The instruction not to touch `android/` then
kept the fix uncommitted for another cycle. Related: [[record-the-fact-not-a-pointer]].

**How to apply:** when a brief says a secret was "already handled in a prior commit",
check `git show HEAD:<path>`, not the working tree — those are different files. Treat
SEC-11 / KAN-57 as **open** until a commit removes the literals *and* the upload key is
rotated; removing them from the tip does not undo the ~9-month exposure in history.
