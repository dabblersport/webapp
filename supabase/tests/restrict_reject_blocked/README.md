# KAN-522: rpc_restrict_set / rpc_restrict_clear reject 'blocked'

**Status: AUTHORED, NOT APPLIED, NOT RUN.** Nothing was applied to any database and no probe was run. Memphis applies the migration per the CEO approval of 2026-10-13 (execute_sql, never apply_migration, never DROP, only project `wtncuzcskpigqpmnxwws`, test data only, stop on real user data) and records the real PASS/FAIL. Until then no document here claims a probe passed.

| File | Purpose |
|---|---|
| `supabase/migrations/20261013130000_restrict_rpcs_reject_blocked.sql` | `CREATE OR REPLACE` of the two bodies; `'blocked'` raises `use_rpc_block_user` / `use_rpc_unblock_user` (P0001); `'hidden'` unchanged; `REVOKE` from PUBLIC and anon, `GRANT` to authenticated and service_role. No DROP, no rename, no signature change. |
| `CALLERS.md` | Caller map: none. |
| `probes.sql` | Pre-apply and post-apply probes, all inside `BEGIN ... ROLLBACK`. |
| `rollback.sql` | Restores the baseline bodies and the prior ACL. |
| `test/supabase/restrict_reject_blocked_migration_test.dart` | Pins the migration shape. |

## Apply order

1. Run probes A1..A5 (read-only or rolled back). Save A2's ACL output.
2. Apply the migration. It sorts after `20261013120000` (KAN-499); it does not depend on it.
3. Run B1..B7. Every one must pass; before the apply B1, B2 and B5 are expected to fail.

## Existing 'blocked' rows

The migration does not touch them (KAN-499 carries them to `user_blocks`). After it, `rpc_restrict_clear` can no longer clear an old `'blocked'` row (it raises `use_rpc_unblock_user`). Memphis may delete such rows as a test-data cleanup only after confirming the KAN-499 carry-over, and only rows the team created. Probe A5 counts them read-only.

## Rollback

`rollback.sql` restores the exact baseline bodies and ACL, with no DROP. It is itself an apply, by Memphis only, and it **reopens the second block store**: a `'blocked'` row would again be writable and enforced nowhere. Last resort.

## Notes

* `rpc_restrict_set` no longer downgrades a friendship: that only ran for `'blocked'`, which is now refused.
* A NULL `p_type` skips both type checks in both functions (`NULL not in (...)` is NULL), exactly as in the baseline; `rpc_restrict_set` then fails on the column and `rpc_restrict_clear` matches no row, as before.
* No schema note was added to `docs/SCHEMA.md` (KAN-499 owns the section 2g edit).
