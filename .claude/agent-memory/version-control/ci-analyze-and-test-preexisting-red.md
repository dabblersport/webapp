---
name: ci-analyze-and-test-preexisting-red
description: GitHub Actions check "analyze-and-test" fails on pre-existing lint/info debt (flutter analyze exits non-zero on ANY issue, not just errors) — confirmed already red before the 2026-09-01 sprint-2 push, not a regression
metadata:
  type: project
---

**Fact:** the `analyze-and-test` check-run (`gh api repos/dabblersport/webapp/commits/<sha>/check-runs`)
was already `conclusion: failure` at `8acb16b` (the Canary tip before the 2026-09-01
sprint-end push), same as after. `flutter analyze` exits 1 whenever there is **any**
issue — including info-level lints like `deprecated_member_use_from_same_package` —
not just real errors. Locally this repo has ~93-156 such issues depending on which
files are touched; zero of them are actual analyzer *errors*.

**Why this matters:** don't read a red `analyze-and-test` check as a sign your push
broke something. Compare against the check-run for the immediately-prior commit
first (`gh api repos/dabblersport/webapp/commits/<prior-sha>/check-runs`) before
treating it as a regression to fix or block on. The load-bearing gate for a Canary
push is `Cloudflare Pages` = success (see [[deploy-verification-channels]]) — this
check is a separate, currently-broken CI job (`.github/workflows/*`, added in
`6bc3818`/`6dcd15e`), not the deploy gate.

**How to apply:** when verifying `flutter analyze` locally before a commit, "0
errors" (not "0 issues") is the bar per this repo's own instructions — warnings and
info are pre-existing debt, not a block. If asked to make CI green, that's a
separate, larger cleanup task (fixing ~150 lint issues across the tree), not
something to silently do inside an unrelated commit.
