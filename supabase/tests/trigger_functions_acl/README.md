# KAN-527: revoke PUBLIC and anon EXECUTE from trigger functions in schema public

**Status: AUTHORED, NOT APPLIED, NOT RUN.** Nothing was applied to any database and no probe was run. Memphis applies the migration per the CEO approval of 2026-10-13 (execute_sql, never apply_migration, never DROP, only project `wtncuzcskpigqpmnxwws`, test data only, stop on real user data) and records the real PASS/FAIL. Until then no document here claims a probe passed.

| File | Purpose |
|---|---|
| `supabase/migrations/20261014090000_revoke_public_anon_trigger_functions.sql` | 173 statements `REVOKE EXECUTE ON FUNCTION public.<name>() FROM PUBLIC, anon;`. No GRANT, no body change, nothing removed. |
| `TRIGGER_FUNCTIONS.md` | Source (KAN-498 sweep), count, each function with its grant source, caller evidence. |
| `probes.sql` | Pre-apply (A1-A3) and post-apply (B1-B5) probes inside `BEGIN ... ROLLBACK`. |
| `rollback.sql` | Re-grants EXECUTE to PUBLIC on exactly the 173, and to anon where explicit. |
| `test/supabase/trigger_functions_acl_migration_test.dart` | Pins the migration against the list and the probe pack. |

## The list

173 functions, not 174: the sweep's 174th trigger function is `notify_admins_of_block()`, owned by KAN-523, left out here. The migration sorts after `20261013130000` and nothing asserts it is the newest migration.

## Apply order

1. Run A1-A3; save A1's and A2's output (A1 must show the 173 plus `notify_admins_of_block` and nothing else; a different live count is recorded, not a stop, unless a listed function does not return `trigger`).
2. Apply the migration.
3. Run B1-B5. B1 must pass, B1b compare with A2, and B2-B5 must each print PASS. **If any trigger probe fails for an authenticated writer, STOP: do not grant to fix it.**

## Effect on authenticated

Explicit grants to `authenticated` and `service_role` are untouched. A function that held only the default PUBLIC grant also loses authenticated's *effective* EXECUTE (it came through PUBLIC); that is expected, because EXECUTE on a trigger function is checked when the trigger is created, not when it fires. B2-B5 prove it for four trigger functions.

## Rollback

`rollback.sql` re-grants EXECUTE to PUBLIC for exactly the listed functions (and anon explicitly for the one the sweep recorded with an explicit anon grant), no DROP. It is itself an apply, done only by Memphis. It re-opens the hygiene finding. Last resort.

## Notes

* The posts table has no geo trigger in the catalog (`fn_sync_geo_fields` is on games, meetups, profile_locations, venues), so B3 uses `profile_locations`; posts are covered by the `updated_at` trigger in B4.
* B2 uses a temporary admin fixture inserted inside the transaction; it judges only the new notification rows (one per admin, fixture included).
* B4/B5 insert only baseline-known columns; extra live NOT NULL columns surface as a fixture error, not a trigger failure.
