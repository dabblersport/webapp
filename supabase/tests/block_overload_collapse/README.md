# KAN-499: collapse `rpc_block_user(uuid, boolean)` onto the single `user_blocks` store

**Status: AUTHORED, NOT APPLIED, NOT RUN.** Nothing in this ticket was applied to any database and no probe
was run. There is no CEO-approved non-production database yet; the probes are written here and run later by
whoever applies. Only project `wtncuzcskpigqpmnxwws` is referenced. No `apply_migration`, no write, no secret.

## What is here

| File | Purpose |
|---|---|
| `supabase/migrations/20261013120000_kan499_collapse_rpc_block_user_overload.sql` | Step 2. Renames the 2-argument overload to `rpc_block_user_legacy_v1`, revokes ALL on it from PUBLIC, anon and authenticated, and copies `restrictions` rows of type `blocked` into `user_blocks` (`ON CONFLICT DO NOTHING`). No DROP, no body edited, `restrictions` not written. |
| `CALLERS.md` | Step 1. The caller map: who calls the 2-argument overload (nobody; the app calls only the 1-argument form), with the git grep evidence. |
| `probes.sql` | Step 3. Pre-apply (A), post-apply (B) and post-rollback (C) probes; every block is `BEGIN ... ROLLBACK` and marked READ-ONLY or WRITE-IN-TRANSACTION-ROLLBACK. **AUTHORED, NOT RUN.** |
| `rollback.sql` | Step 4. Renames it back and re-grants the ACL it held. Itself an apply. |
| `test/supabase/block_overload_collapse_migration_test.dart` | Pins the shape, the order after KAN-497, the absence of any DROP and the probe pack. Runs no SQL. |
| `docs/SCHEMA.md` §2g | A dated baseline note (the allowlist block itself is untouched). |

## Apply order (each step needs the previous one evidenced)

1. Caller map (`CALLERS.md`): done. Result: no caller of the 2-argument overload; the app calls `rpc_block_user(uuid)` only.
2. **KAN-497's migrations first.** `20261013100000_kan497_is_blocked_narrow_to_caller.sql` and
   `20261013110000_kan497_revoke_anon_block_rpcs.sql` exist on KAN-497's commit `93672363` but are **not in the Alpha
   tree** (Alpha `3879a977` integrated that commit without them). This ticket's file is stamped after them
   (`20261013120000`) and does not copy or edit them. They must be integrated and applied before this one; if the
   database does not have KAN-497's revoke, the ACL `rollback.sql` restores differs (see the comment in it).
3. On a CEO-approved non-production database: run section A of `probes.sql`, apply the KAN-499 migration, run
   section B. Every B assertion should FAIL when run before the migration (that is the proof the probe can fail).
4. Production: only with the CEO's explicit approval of the exact migration text, the G-002 backend owner plus PEER
   review (`schema_change` forces PEER), and devops for the push.

## Result of the caller map

* The app's only call is `lib/data/repositories/block_repository_impl.dart:24` with `{'p_peer': ...}`, which resolves to
  the 1-argument overload. No edge function, trigger, view, policy, function body, CI script or test calls the 2-argument one.
* After the migration a client call naming `p_block` no longer resolves; nothing in the app changes.

## What the migration changes and does not change

* Changes: the 2-argument overload is renamed (so it is not callable under the API name) and loses its client grants.
  `restrictions` `blocked` rows, if any, are copied into `user_blocks`; each copied row fires
  `trg_notify_admins_of_block` (one low-priority admin notification per admin per row). Live evidence
  (KAN-496 E2, 2026-10-13): `user_blocks` 3 rows, `restrictions` 0 rows, so nothing to carry today.
* Not changed: the body and ACL of `rpc_block_user(uuid)` and `rpc_unblock_user(uuid)`; the `restrictions` table
  (its retirement is a separate ticket); every other function.

## Second block store: closed by KAN-522, migration 20261013130000

`rpc_restrict_set` and `rpc_restrict_clear` accepted `'blocked'` and wrote `restrictions`. That is KAN-522's ticket (migration
`20261013130000_restrict_rpcs_reject_blocked.sql`, which makes both refuse `blocked`). **AC3 ("blocking through the API can only
write user_blocks") is satisfied by KAN-499 and KAN-522 together, applied in that order (20261013120000, then 20261013130000).**
This ticket changes `rpc_block_user(uuid, boolean)` only.

## Rollback

`rollback.sql` renames `rpc_block_user_legacy_v1` back to `rpc_block_user(uuid, boolean)` and re-grants the ACL it
held before (default: KAN-497's revoke applied, so `authenticated` and `service_role`; the baseline variant is in the
file). Order if KAN-497 was also applied: undo this ticket first, then KAN-497. **Rollback is itself an apply and needs
the CEO's explicit approval of the exact text.** It uses no DROP. It re-opens the second block store (a block made through
the 2-argument overload is written to `restrictions` and enforced nowhere). It does not remove carried `user_blocks` rows.

## Honest status

* Authored only. The probes were not run; no document here claims they were.
* Run `flutter test test/supabase/block_overload_collapse_migration_test.dart` for the static checks.
