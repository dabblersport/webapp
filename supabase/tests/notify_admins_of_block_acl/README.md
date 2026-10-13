# KAN-523: revoke PUBLIC / anon from notify_admins_of_block()

**Status: AUTHORED, NOT APPLIED, NOT RUN.** Nothing was applied to any database and no probe was run. Memphis applies the migration per the CEO approval of 2026-10-13 (execute_sql, never apply_migration, never DROP, only project `wtncuzcskpigqpmnxwws`, test data only, stop on real user data) and records the real PASS/FAIL. Until then no document here claims a probe passed.

| File | Purpose |
|---|---|
| `supabase/migrations/20261013140000_revoke_public_notify_admins_of_block.sql` | exactly `REVOKE ALL ... FROM PUBLIC, anon, authenticated` and `GRANT EXECUTE ... TO service_role` on `public.notify_admins_of_block()`. No DROP, no body or trigger edit. |
| `CALLERS.md` | References: only `trg_notify_admins_of_block`. |
| `probes.sql` | Pre-apply and post-apply probes inside `BEGIN ... ROLLBACK`. |
| `rollback.sql` | Re-grants EXECUTE to PUBLIC and service_role (the baseline ACL). |
| `test/supabase/notify_admins_of_block_acl_migration_test.dart` | Pins the migration shape. |

## Apply order

1. Run A1..A3. Save A1's ACL output (`rollback.sql` restores it).
2. Apply the migration (sorts after `20261013120000`; no dependency on it).
3. Run B1..B3. B1 and B2 must pass; B3 (a block still notifies every admin) must pass. **If B3 fails for an authenticated blocker after the revoke, STOP: that is a stop condition, not a reason to grant `authenticated`.**

## Rollback

`rollback.sql` re-grants EXECUTE to PUBLIC and service_role, no DROP. It is itself an apply, done only by Memphis. It re-opens the function to PUBLIC and so to anon and authenticated (hygiene only: a trigger function cannot be called as an RPC). Last resort.

## Notes

* `notify_admins_of_block` is the only function this migration touches; `notify_admins_of_report` has the same shape and is not in scope.
* No schema note was added to `docs/SCHEMA.md` (forbidden by the ticket).
* A3 and B3 are not vacuous: they raise `SETUP FAIL` unless `app_admins` has at least one test admin and the blocker and blocked user are two distinct active test users, and they assert that the new notifications' recipients are exactly the `app_admins` rows (one each) before the revoke (A3) and after it (B3). Memphis records the admin count they print.
