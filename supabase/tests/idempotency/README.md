# KAN-611: request-id idempotency for create post / game / meetup

**Status: AUTHORED, NOT APPLIED, NOT RUN.** The team applied nothing and ran nothing against any database. Memphis
applies the migrations after approval (execute_sql only, never apply_migration, test data only, project
`wtncuzcskpigqpmnxwws` only) and records the real PASS/FAIL of `idempotency_tests.sql`. No secret or key is in any file.

| File | Purpose |
|---|---|
| `supabase/migrations/20261021120000_kan611_request_id_columns.sql` | `request_id` on posts/games/meetups, partial unique indexes on the owner user id (`posts_author_user_request_id_key`, `games_creator_user_request_id_key`, `meetups_creator_user_request_id_key`), stamping trigger. |
| `supabase/migrations/20261021120100_kan611_create_post_request_id.sql` | `create_post` = legacy body + `p_request_id` only (21 args). |
| `supabase/migrations/20261021120200_kan611_rpc_create_game_request_id.sql` | `rpc_create_game` thin wrapper over `rpc_create_game_legacy_v2`. |
| `supabase/migrations/20261021120300_kan611_rpc_create_meetup_request_id.sql` | `rpc_create_meetup` thin wrapper over `rpc_create_meetup_legacy_v2`. |
| `idempotency_tests.sql` | P0 pre-check, T1/T2/T4 post, G1-G4 game, M1-M4 meetup, X1-X3 post-checks. Each one `BEGIN ... ROLLBACK`. |
| `rollback.sql` | Renames new functions to `*_v3_rolledback` (revoked), legacy back, restores legacy grants. No DROP. |
| `test/supabase/kan611_request_id_idempotency_migration_test.dart` | Static checks of the files. Runs no SQL. |

Each RPC file runs, in order: a DO pre-check (exactly one overload, `*_legacy_v2` absent), RENAME to `*_legacy_v2`,
REVOKE the legacy from PUBLIC/anon/authenticated, CREATE the new signature, the ACL, and a DO post-check that the new
function's `proacl` has no PUBLIC and no anon entry.

## How it works

* With `p_request_id`, the lookup of (owner user, request id) runs FIRST, before every guard and limit. A repeat returns
  the original row in the same shape (`create_post`: same jsonb; game/meetup: same uuid) and inserts nothing.
* A first call runs every unchanged guard. A concurrent twin losing on the partial unique index gets the winner's row
  (the handler checks the index name; any other unique violation is re-raised).
* Without `p_request_id`: today's behaviour exactly; `request_id` stays NULL and the row is outside the partial index.
* Hashtag linking is NOT part of this ticket.

## ACL (orchestrator ruling) and the live check Memphis must do BEFORE apply

All three new functions: `REVOKE FROM PUBLIC, anon`; `GRANT EXECUTE TO authenticated, service_role`. anon cannot create.

`rpc_create_game` was recorded as anon-executable (`20261008140000`, `GRANT ... TO anon, authenticated, service_role`),
so for it this is a **tightening**. Before applying, Memphis captures the live ACL of the three current functions and
keeps it with the apply record:

```sql
select p.oid::regprocedure, p.proacl from pg_proc p join pg_namespace n on n.oid = p.pronamespace
 where n.nspname = 'public' and p.proname in ('create_post', 'rpc_create_game', 'rpc_create_meetup');
```

If `rpc_create_game` shows `anon=X`, the tightening is real and `rollback.sql` must uncomment its marked anon line to
restore the previous state exactly.

## Limits (honest note)

`supabase/migrations` contains no numeric daily create limit for posts, games or meetups (only `msg_dm_daily_cap`,
KAN-560, for DMs). The guards (persona gate, frozen user, `price_required`, `free_meetups_only`, ...) run unchanged on a
first call. A replay returns before them and inserts nothing, so it consumes no allowance. G3/M3 prove it.

## Apply order and rollback

1. Capture the live ACL (above). Run P0: must PASS. Run the T/G/M tests: each must fail (the proof they can fail).
2. Apply the four migrations in filename order; run every test: expect PASS (SKIPPED = missing fixture, not a pass).
3. Rollback: `rollback.sql`. Columns, indexes, trigger function and triggers stay (no DROP); they are inert.
