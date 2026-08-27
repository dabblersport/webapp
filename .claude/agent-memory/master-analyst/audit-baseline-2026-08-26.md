---
name: audit-baseline-2026-08-26
description: Headline numbers from audit run 1 (2026-08-26, HEAD 1b83967) — report deltas against these, don't restate them
metadata:
  type: project
---

Baseline measured on 2026-08-26 at HEAD `1b83967`, branch `Canary`. Report **deltas**
against these on the next run rather than re-stating absolutes.

| Metric | Value |
|---|---|
| Feature slices | 25 — SHIPPED 12 · PARTIAL 6 · SCAFFOLD 1 · DEAD 6 |
| Feature flags | 113 declared · 10 gating · 5 snapshot-only (`main.dart:80-92`) · **98 never read** |
| Providers | 400 declared · 113 orphaned |
| Orphan screen classes | 21 across 12 files · 6,213 LOC in 10 wholly-dead files |
| Route constants | 133 declared · 54 unreferenced |
| God files (>500 LOC, non-generated) | 140 (scanner says 143; 3 are generated l10n) |
| Tests | 5 files / 66 tests, **all pass**, all against unreachable code · 22/25 slices have no test dir |
| lib files (non-generated) | 783 · 226,327 LOC |
| `Either` vs `Result` | 31 files vs 124 files |
| Hardcoded `Color(0x…)` in features | 233 (auth_onboarding 97, rewards 65) |
| `print()` | 26 · empty catches 44 · `UnimplementedError` sites 44 |
| `flutter analyze` | 0 errors · 55 warnings · 102 infos |
| Supabase | 184 public tables · 183 RLS-enabled · 153 with policies · 336 policies · 49 views · 25 SECURITY DEFINER · 4 buckets · 9 storage policies · **0 migration files** |
| Hardcoded `.from('table')` / storage buckets in lib/ | **0** — the SupabaseConfig migration landed |

Deliverable lives at `docs/PROJECT_STATE.md` (62 findings, IDs `SEC-`, `DEAD-`, `FLAG-`,
`WIRE-`, `BUG-`, `TEST-`, `ARCH-`, `STYLE-`, `ERR-`, `DEP-`, `PROV-`, `DOC-`, `CFG-`).

**Why:** run 1 is the only run with no prior state to reconcile; everything after is a diff.
**How to apply:** on the next run, read `docs/PROJECT_STATE.md` first, mark fixed findings
`RESOLVED`, and quote movement (e.g. "98 → 41 dead flags") instead of the raw number.

See [[audit-false-positives]] and [[confirmed-dead-code]].
