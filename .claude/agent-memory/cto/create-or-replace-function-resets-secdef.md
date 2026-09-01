---
name: create-or-replace-function-resets-secdef
description: CREATE OR REPLACE FUNCTION without SECURITY DEFINER silently resets prosecdef to false — the function analogue of the CREATE OR REPLACE VIEW / security_invoker trap; bites when two unapplied migrations touch the same body
metadata:
  type: project
---

`CREATE OR REPLACE FUNCTION` that omits `SECURITY DEFINER` resets `prosecdef` to `false`
with no error or warning — exactly like [[create-or-replace-view-resets-invoker]].

**Why:** ruled in `T-044` (KAN-104). `find_slots` is being elevated to DEFINER while
KAN-74's `CREATE OR REPLACE` of the same function sits authored-but-unapplied. If the two
are applied out of order, or KAN-74 is ever re-run, the elevation vanishes silently and
`is_booked` goes back to reading false for every anon caller. `CONVENTIONS §6c` extended
to cover functions on 2026-09-01.

**How to apply:** whenever a migration edits a definer function's body, restate
`SECURITY DEFINER` and every `SET` clause in full, and assert `prosecdef` + `proconfig`
in the verification block. When two unapplied migrations touch one function, the file
WITHOUT the elevation must not sort last. Row-count checks pass either way and prove nothing.
