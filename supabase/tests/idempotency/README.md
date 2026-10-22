# KAN-611: request-id idempotency for create post / game / meetup

**Status: AUTHORED, NOT APPLIED, NOT RUN.** The team applied nothing and ran nothing against any database. Memphis
applies the migration after approval (execute_sql only, never apply_migration, test data only, project
`wtncuzcskpigqpmnxwws` only) and records the real PASS/FAIL of `idempotency_tests.sql`. No secret or key is in any file.

| File | Purpose |
|---|---|
| `supabase/migrations/20261021120000_kan611_request_id_idempotency.sql` | Adds `request_id` + partial unique indexes on posts/games/meetups, the stamping trigger, and the three request-id aware functions (old ones renamed `*_legacy_v2`, revoked from clients). |
| `idempotency_tests.sql` | T1-T4 post, G1-G4 game, M1-M4 meetup, X1-X3 hygiene. Each test is one `BEGIN ... ROLLBACK` batch. |
| `rollback.sql` | Renames the new functions to `*_v3_rolledback` (revoked) and the legacy ones back. No DROP. Itself an apply (Memphis). |
| `test/supabase/kan611_request_id_idempotency_migration_test.dart` | Static checks of the files. Runs no SQL. |

## How it works

* A call WITH `p_request_id` takes an advisory lock on (profile, id), returns the existing row if `(profile, request_id)` is
  already stored, otherwise creates the row and stamps it. A call WITHOUT it is the previous function, unchanged.
* `create_post` (replay returns the same jsonb shape as the first success) now also writes `hashtags` / `post_hashtags`
  inside the call, next to circles, squads and mentions. Any failure rolls the whole call back: no post without its tags.
* `rpc_create_game` / `rpc_create_meetup` wrap the unchanged legacy body; the wrapper sets a transaction-local setting that a
  BEFORE INSERT trigger copies into `request_id`, so no UPDATE fires and no activity trigger runs twice.

## Backward compatibility and RLS

The new parameter is last and defaulted, so every named-argument call from a 1.7.9 build resolves to the new function and
takes the id-less path. Existing rows keep `request_id` NULL and are not in the partial indexes. No policy, grant on a table,
or RLS setting is touched; ACLs on the three public functions equal the ones they replace.

## Limits (honest note)

`supabase/migrations` contains no numeric daily create limit for posts, games or meetups (only `msg_dm_daily_cap`, KAN-560, for
DMs). What exists are the guards (persona gate, frozen user, `price_required`, `free_meetups_only`, ...). They run unchanged on
a first call. A replay returns before them and inserts nothing, so it cannot consume any count-based allowance twice. Tests
G3/M3 prove the guards still fire with a request id, that a refused call leaves no row, and that replays add no row.

## Not in this ticket

* The app does not send a request id yet and still links hashtags itself (idempotent against the RPC's own links). Moving the
  standard post path from a direct `posts` INSERT to the RPC, and sending a uuid per create attempt, is a follow-up client
  ticket (needs a fresh uuid per user attempt, reused on retry).
* Onboarding RPC idempotency (excluded by decision; not assessed as unsafe). Message sending (already has Idempotency-Key).

## Apply order and rollback

1. Run `idempotency_tests.sql` once BEFORE the migration: every T/G/M test must fail or skip (the proof they can fail).
2. Apply the migration, run the tests again: expect PASS (SKIPPED means a fixture was missing, not a pass).
3. Rollback: `rollback.sql` (re-opens the retry-duplicates bug; stamped rows keep their `request_id`).
