---
name: android-signing-secret-still-at-head
description: SEC-11/KAN-57 — Android plaintext signing password fix is now committed and pushed to Canary (8acb16b, 2026-08-30); history exposure and key rotation still unresolved
metadata:
  type: project
---

**Resolved in the tracked tree as of commit `8acb16b` (pushed to Canary 2026-08-30).**
`android/app/build.gradle.kts` no longer contains the plaintext `storePassword` /
`keyPassword` literals — the release `signingConfig` now reads
`keyAlias`/`keyPassword`/`storeFile`/`storePassword` from `android/key.properties`
(gitignored via `android/.gitignore:12`, never tracked). Verified with
`git show origin/Canary:android/app/build.gradle.kts | grep -i mo3taz` → no match.
KAN-57 commented with verification and transitioned to Done.

**Still open / not addressed by this commit:**
- The password `mo3taz51024.` remains in git history (introduced `ebaf9b8`,
  2025-11-22, on a public repo) — this commit only removes it from the tip. History
  scrub/rotation is a separate decision, not taken here.
- The actual upload keystore signing password should be **rotated** — a value that
  sat in a public repo for ~9 months should be treated as compromised regardless of
  whether it's still referenced.

**Why this matters:** a prior cycle (2026-08-28) had this same fix sitting
uncommitted in the working tree while a brief falsely claimed it was "already
handled in a prior commit." Always verify with `git show <ref>:<path>`, not the
working tree state, before trusting a "already fixed" claim. Related:
[[record-the-fact-not-a-pointer]].

**How to apply:** if a future brief mentions SEC-11/KAN-57 as still-open, check
`git log -S storePassword -- android/app/build.gradle.kts` and `git show
origin/Canary:...` first — the tip is now clean, so don't re-do this fix. If asked
about key rotation or history scrubbing for this secret, that's unresolved and needs
its own decision/ticket.
