---
name: analyst-reconciliation
description: How the CTO read reconciled with master-analyst's PROJECT_STATE.md — where we converged, the four deltas, and what only the CTO pass found.
metadata:
  type: project
---

Reconciled 2026-08-27 against `docs/PROJECT_STATE.md` (audit run 2026-08-26, HEAD `1b83967`).

**Converged independently** on: the anon leak (609/49), the 19-view population, `flutter
analyze` (0 errors / 55 / 102) and `flutter test` (66 pass). Two independent reads landing on
the same numbers is the useful signal here.

**Four deltas — none a conflict of fact:**
1. 500-line files: mine 143, theirs 140. Same measurement; they also exclude `lib/l10n/`. **Theirs is better** — generated files.
2. "233 hardcoded colours" in decision `009` is **not reproducible**. Defensible: 317/43 files.
3. `Either`/`Result` 31/124 correct, but there are **three** conventions — a hand-written `Either` in `lib/core/utils/either.dart` (13 files, all `profile`), not fpdart.
4. Decision `010` held (zero raw `MaterialPage`), but **13 `MaterialPageRoute`** sites bypass GoRouter — a violation the convention does not currently name.

**Absent from PROJECT_STATE.md, found in the CTO pass:** Play signing password in a public
repo; logout teardown + FCM revocation; Android Auto Backup exporting the refresh token;
edge-function authorization scope; `v_space_slots_today` hard-broken (`find_slots` queries a
nonexistent `venue_opening_hours`); unverified Android App Links.

**Why:** the Analyst establishes what is true; the CTO decides what should be true next. The
overlap is the check, not duplication.
**How to apply:** offer these as additions to the Analyst's record, not corrections to it —
`master-analyst` owns `PROJECT_STATE.md`.

See [[kan39-launch-readiness]], [[load-bearing-measurements]].
