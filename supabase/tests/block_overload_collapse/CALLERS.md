# KAN-499 caller map: `public.rpc_block_user(uuid, boolean)` (the 2-argument overload)

Status: AUTHORED from the repo on Alpha `3879a977` and the supplied KAN-496 evidence. Nothing was measured
live for this ticket and nothing was run against any database. Project `wtncuzcskpigqpmnxwws` only.

## Result (read this first)

* **The app never calls the 2-argument overload.** The only app caller of `rpc_block_user` is
  `lib/data/repositories/block_repository_impl.dart:24`, which passes `{'p_peer': targetUserId}` and nothing
  else, so PostgREST resolves it to the **1-argument** overload `rpc_block_user(p_peer uuid)`. The name
  constant is `lib/core/config/supabase_config.dart:176`.
* **No other caller of the 2-argument overload exists**: no edge function, no trigger, no view, no function
  body, no policy, no CI script, no test, in the repo. The only places that mention it are its own baseline
  definition and grants, the KAN-497 probe pack and documentation. So no stop condition of the ticket applies.
* **Finding that touches AC3, not changed here:** `public.rpc_restrict_set(p_target uuid, p_type text)` accepts
  `p_type = 'blocked'` and writes a `blocked` row into `public.restrictions` (baseline 15025-15040). It is
  executable by anon, authenticated and service_role in the baseline, and the app does not call it (0 hits in
  `lib/` and `supabase/functions/`). It is not a caller of this overload, but after this ticket the API can still
  create a `blocked` row in `restrictions` through it. The ticket changes one function only, so it is reported,
  not touched. See "Second block store: closed by KAN-522" below.

## Evidence recorded (commands run on Alpha `3879a977`)

| Command | Result |
|---|---|
| `git grep -n "rpc_block_user" -- . ':!docs' ':!supabase/tests/anon_block_grants'` | `lib/core/config/supabase_config.dart:176`; baseline `20260829080500_baseline_schema.sql`: definitions at 11057 (1-arg) and 11089 (2-arg), owners at 11086 and 11108, grants at 36104-36106 (1-arg) and 36110-36112 (2-arg). **No other file.** |
| `git grep -n "rpcBlockUserFn\|p_block\b" -- lib supabase/functions test integration_test scripts .github tests` | `supabase_config.dart:176` (the constant) and `block_repository_impl.dart:24` (`params: {'p_peer': ...}`). **No `p_block` anywhere outside the baseline.** |
| `git grep -n "rpc_block_user\|rpc_unblock" -- supabase/functions` | **0 hits.** No edge function. |
| Latest definition of every `CREATE [OR REPLACE] FUNCTION/VIEW/TRIGGER/POLICY` text across `supabase/migrations` that contains `rpc_block_user` | only the two baseline definitions above; no later migration redefines, renames, calls or grants either overload. |
| `git grep -n "rpc_block_user" -- docs` | `docs/SCHEMA.md` 751-752, 795-796, 946-947 (descriptions and the §2g anon allowlist lines, not callers). |
| `git grep -n "rpc_block_user" -- supabase/tests/anon_block_grants` | KAN-497 probe pack and caller map (probes, rollback, docs; not callers). |
| `git grep -n "restrictions" -- lib supabase/functions supabase/migrations ':!baseline'` | no query on the table in app code; one `GRANT`/`REVOKE` list line in `20260901190000_kan86_...` (table grants). |

Catalog evidence supplied by the KAN-496 report (`LIVE_EVIDENCE.md` E1 and E2, read-only, 2026-10-13): the
2-argument overload is `SECURITY DEFINER`, executable by anon and authenticated and holds one PUBLIC grant (E1);
`user_blocks` has RLS on and **3 rows**; `restrictions` has RLS on and **0 rows** (E2), so no data diverges today.
**Not measured live:** the dependents of the 2-argument overload (`pg_depend`) were not queried by KAN-496 or
here, so "no caller in the database" rests on the repo reading above; probe A3 in `probes.sql` reads the
dependents at apply time and must return no row.

## Live catalog evidence: NOT obtained by this team (needs-ops)

The repo map above is complete, but the live catalog read (dependents of the 2-argument overload in `pg_depend`, function bodies, views, policies and triggers that mention it, and the row counts) has NOT been measured for this ticket: the ops guard refuses `execute_sql` for team Karnak (D-042), and a read-only catalog SELECT was attempted and refused. **needs-ops: Memphis runs probes.sql block A3 (read-only) and A4 on project wtncuzcskpigqpmnxwws and records the output here.** Expected: A3 returns no row from any of its four queries; A4 shows user_blocks 3, restrictions 0 (KAN-496 E2, 2026-10-13). Until Memphis records it, "no live caller" is an inference from the repo, not a measurement. If A3 returns a row the migration must not be applied until that caller is migrated.

## Callers of `rpc_block_user(uuid, boolean)`

| # | Caller | Kind | Evidence | Result |
|---|---|---|---|---|
| 1 | app (`lib/`) | app | 0 hits for `p_block`; the only `rpc_block_user` call passes `p_peer` only (`block_repository_impl.dart:24`) | **does not call it** |
| 2 | edge functions (`supabase/functions/`) | edge fn | 0 hits | none |
| 3 | triggers | trigger | `trg_notify_admins_of_block` is `AFTER INSERT ON user_blocks` (baseline 29991) and does not call the function; no trigger body names it | none |
| 4 | views | view | no view definition names it | none |
| 5 | function bodies | function | no function body names it (`rpc_unblock_user(uuid)` deletes from `user_blocks`; `rpc_restrict_set` writes `restrictions` directly) | none |
| 6 | policies | policy | none name it | none |
| 7 | migrations | migration-only | `20260829080500_baseline_schema.sql` creates it (11089), sets the owner (11108) and grants `ALL` to anon, authenticated, service_role (36110-36112). KAN-497's `20261013110000_kan497_revoke_anon_block_rpcs.sql` (authored on commit `93672363`, **not present on Alpha**) revokes PUBLIC and anon on it and re-grants authenticated and service_role. | the only mentions |

## Behaviour of the two overloads (why the 2-argument one is the second store)

| | `rpc_block_user(p_peer uuid)` (kept) | `rpc_block_user(p_peer uuid, p_block boolean)` (retired by this ticket) |
|---|---|---|
| writes | `user_blocks` (`ON CONFLICT (blocker_user_id, blocked_user_id) DO NOTHING`), deletes follows and friendships | `restrictions` (`type = 'blocked'`) only |
| fires `trg_notify_admins_of_block` | yes (AFTER INSERT on `user_blocks`) | no |
| error on no JWT | `Not authenticated` | `not_authenticated` |
| read by | `is_blocked` (baseline 8199) and the Alpha migrations that guard on blocks (`20261008170000_games_following_joined.sql:51`) read `user_blocks` | no function, view or policy in the repo reads `restrictions` rows of type `blocked` (the one reader, `is_hidden`, reads `hidden`) |

So a client that called the 2-argument overload would record a block that no guard reads: it would **look**
blocked to that client and be enforced nowhere. Removing it from the callable API is the safe direction.

## Second block store: closed by KAN-522, migration 20261013130000

`public.rpc_restrict_set(p_target uuid, p_type text)` and `public.rpc_restrict_clear(p_target uuid, p_type text)` could
write and delete `restrictions` rows of type `blocked`; the app does not call either (0 hits). That path has its own ticket,
**KAN-522** (migration `20261013130000_restrict_rpcs_reject_blocked.sql`, reviewed), which makes both refuse the type `blocked`.
**AC3 ("blocking through the API can only write user_blocks") is satisfied by KAN-499 (20261013120000) and KAN-522
(20261013130000) together, applied in that order.** This ticket stays limited to `rpc_block_user(uuid, boolean)`.

## Dependency on KAN-497

KAN-497's two migration files (`20261013100000_kan497_is_blocked_narrow_to_caller.sql`,
`20261013110000_kan497_revoke_anon_block_rpcs.sql`) and its Dart test exist on KAN-497's commit `93672363`
but are **not in the Alpha tree** (`3879a977` merged that commit without them; its probes, caller map, README
and the SCHEMA.md note are there). This ticket's migration is named to sort after them
(`20261013120000_...`) and is written to apply after them. Its README states that KAN-497's revoke migration
must be applied (or its two files integrated) first; this ticket does not copy or edit KAN-497's files.
