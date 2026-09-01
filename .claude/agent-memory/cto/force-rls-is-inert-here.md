---
name: force-rls-is-inert-here
description: postgres carries rolbypassrls=true, so FORCE ROW LEVEL SECURITY remediates nothing on any postgres-owned definer view path; proved read-only on sport_profiles
metadata:
  type: project
---

**`FORCE ROW LEVEL SECURITY` is inert in this project.** `postgres` has
`rolbypassrls = true`, and BYPASSRLS is checked before the owner/FORCE logic. Every
definer view in `public` is owned by `postgres`, so base-table RLS is evaluated as
`postgres` and skipped regardless of FORCE.

**Why:** authoring the final KAN-67 migration, 2026-08-28. `T-018` part (3) and
`T-023` both prescribed FORCE RLS; `T-023` correctly excluded `auth.users` on the
BYPASSRLS ground but attributed the other six views to owner-equals-owner. The same
attribute covers all seven. Superseded in `T-025`.

**The read-only proof — reuse it, do not re-derive it.** `public.sport_profiles`
already has `relforcerowsecurity = true` and is owned by `postgres`:

```sql
SELECT (SELECT count(*) FROM public.sport_profiles) AS visible_as_postgres,      -- 138
       (SELECT count(*) FROM public.sport_profiles sp
          WHERE EXISTS (SELECT 1 FROM public.profiles p
                        WHERE p.id = sp.profile_id
                          AND (p.user_id = auth.uid() OR p.is_active = true))) AS admitted; -- 131
```

Seven rows visible that no policy admits. Note the near-miss: the first version of this
test only checked the `p.user_id = auth.uid()` policy and got 138 vs 0 — an overstated
proof. The permissive `p.is_active = true` policy admits 131, and the real margin is 7.
**Enumerate every policy on the table before claiming a bypass.**

**How to apply:** never put FORCE RLS in a remediation for a postgres-owned definer view
and never accept one in review. It becomes meaningful only if `BYPASSRLS` is removed from
`postgres`, which is its own decision. See [[kan67-migration-facts]].
