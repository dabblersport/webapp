---
name: policy-role-vs-check-trap
description: A policy applying to anon is not a policy permitting anon — filter on the WITH CHECK expression, never on polroles alone; the 184-table grant is gated, severity low
metadata:
  type: feedback
---

**Rule: when asking whether a role can write, read the policy's check expression. Counting
policies whose `polroles` includes the role produces an alarming number that means nothing.**

**Why.** Filing KAN-86 (2026-08-29), my first census counted permissive INSERT/ALL policies
where `polroles` contained `anon` **or** `polroles = '{0}'` (PUBLIC applies to every role).
It returned ~99 tables and read like a live breach. Reading each `WITH CHECK` showed every
one denies `anon`. `TO PUBLIC ... WITH CHECK (false)` matches a role filter and permits
nobody. Same shape as `T-017`: a count tells you policies exist, not what they permit.

**The settled finding — `T-035`.** 184 of 185 public base tables grant `anon`
INSERT/UPDATE/DELETE; **all 184 have RLS enabled**, and every permissive policy applicable
to `anon` is one of four gated shapes: literal `false`; definer-funnel
(`CURRENT_USER <> SESSION_USER`); definer-owner (`CURRENT_USER = 'postgres'`); or
owner-gated via `can_write_row()` → `is_owner()` → `auth.uid()`, NULL for `anon`.
**No permissive policy admits `anon`.** Redundant privilege surface, **low severity, not a
promotion blocker** — do not sequence KAN-86 ahead of KAN-56/59/57.

**The one genuinely open object:** `spatial_ref_sys` — `supabase_admin`-owned, **no RLS**,
`anon` holds all three write verbs. Not revocable (`T-025`). PostGIS catalogue, not our data.
Never re-flag as new. See [[confirmed-false-positives]], [[force-rls-is-inert-here]].

**How to apply.** Working query shape:

```sql
WHERE coalesce(pg_get_expr(polwithcheck,polrelid),
               pg_get_expr(polqual,polrelid), 'true')
      !~* 'auth\.uid|auth\.role|auth\.jwt|current_setting'
```

then read what survives by hand — `CURRENT_USER`-based gates pass this filter and are still
safe. See [[verification-lessons]], [[kan67-migration-facts]].
