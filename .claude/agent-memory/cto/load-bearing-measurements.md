---
name: load-bearing-measurements
description: Verified numbers from the KAN-39 assessment with the exact command that produced each — plus which widely-quoted figures are wrong.
metadata:
  type: project
---

Measured 2026-08-27 on `Canary`. A number without its command is a claim (decision `020`).

```bash
# 143 files over 500 lines (Analyst's 140 = same, additionally excluding lib/l10n/ — their choice is better)
find lib -name '*.dart' ! -name '*.g.dart' ! -name '*.freezed.dart' -exec wc -l {} + | awk '$1>500 && $2!="total"' | wc -l

# 31 Either files / 124 Result files — MUST grep the symbol, not the import.
# Grepping "fpdart" returns 17 and is WRONG: 13 profile files use a hand-written
# Either in lib/core/utils/either.dart that is not fpdart.
grep -rlE "\b(Either|Left|Right)<" lib --include='*.dart' | wc -l
grep -rlE "\bResult<" lib --include='*.dart' | wc -l

# 317 hardcoded colours across 43 files. "233" is NOT reproducible; "866" double-counts
# lib/design_system/tokens/ and lib/core/config/design_system/ — palette definitions.
grep -rEo "Color\(0x[0-9a-fA-F]{8}\)" lib --include='*.dart' \
  | grep -vE "^lib/(themes/|core/theme/|core/design_system/|design_system/|core/config/design_system/)" | wc -l
```

- `flutter analyze` -> **0 errors**, 55 warnings, 102 infos (44 `empty_catches`, 15 `use_build_context_synchronously`)
- `flutter test` -> **66 pass**, 5 test files
- Anon leak: `SET LOCAL ROLE anon; SELECT count(*) FROM public.v_notifications_feed;` -> 609, 49 distinct `to_user_id`; base table 0
- HTTP proof: `curl -H "apikey: $ANON" -H "Prefer: count=exact" .../rest/v1/v_notifications_feed` -> `content-range: 0-2/609`
- Zero raw `MaterialPage` in `lib/` (decision `010` held). 13 `MaterialPageRoute` across 8 files is a *different* violation.

**Why:** the advisor undercounted the definer views by more than half, and three quoted figures turned out unreproducible.
**How to apply:** re-run before leaning on any of these; quote the command alongside the number.

See [[confirmed-false-positives]], [[kan39-launch-readiness]].
