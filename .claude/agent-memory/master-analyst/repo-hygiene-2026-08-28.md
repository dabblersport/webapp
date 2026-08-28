---
name: repo-hygiene-2026-08-28
description: Run-3 hygiene inventory — what is proposed for deletion, the 7 ASK items, and the two hygiene false positives that must never be re-flagged
metadata:
  type: project
---

Repo hygiene inventory, measured 2026-08-28 at HEAD `1b83967`. Full table:
`docs/PROJECT_STATE.md` §21.

**Headline:** 749 files / ~6.6 MB proposed for removal, **73 tracked**. 51 of those
tracked files are `macos/` (29) + `windows/` (15) + `linux/` (7). Root holds 7 tracked
regenerable artifacts totalling 1,053,654 B.

**Why:** the PO asked for evidence before cleanup, with an explicit "don't miss the good
files" bar — a file is only proposed for removal if nothing references it and nothing
builds from it.

**How to apply:** answer hygiene questions from §21, not by re-scanning. If asked
"can we delete X", check §21b/21e for X's row first.

**Never re-flag these two — verified non-findings** (see also [[audit-false-positives]]):
- `packages/flutter_web_auth_2/` and `packages/sign_in_with_apple/` (72 tracked files) are
  `dependency_overrides` with `path:` entries at `pubspec.yaml:167-180`. Deleting them
  breaks every build.
- The 5 `post_comments_author_profile_id_fkey` strings in `lib` are PostgREST FK-constraint
  hints, not stale table names. Constraint names survived the `post_comments`→`comments`
  rename; confirmed live via `pg_constraint`.

**Blocked on the PO (7 ASK items):** the root `…_DABBLER_CONTENT_ENGINE.pdf`,
untracked `upload_certificate.pem`, `macos/`, 4 zero-ref scripts under `scripts/`,
`App screenshot/`, and the 4 zero-ref `lib/design_system/*.md` files.

**Folded in from the deleted `ONBOARDING_AUDIT.md`:** HYG-01 (`onboarding_service.dart`
+ `mock_onboarding_service.dart`, 320 LOC, zero importers — unblocked for deletion) and
HYG-02 (`OnboardingData` declared twice incompatibly, `cto` decides). See also
[[confirmed-dead-code]].
