# KAN-497: close anon access to is_blocked and the block / unblock / unfollow RPCs

**Status: AUTHORED, NOT APPLIED, NOT RUN.** Nothing in this ticket was applied to any database and
no probe was run. There is no CEO-approved non-production database yet; the probes are written here
and run later by whoever applies. Only project `wtncuzcskpigqpmnxwws` is referenced.

## What is here

| File | Purpose |
|---|---|
| `supabase/migrations/20261013100000_kan497_is_blocked_narrow_to_caller.sql` | Step 2. Body-only `CREATE OR REPLACE` of `is_blocked`: answers only for the caller's own pairs, false otherwise (including no JWT). No DROP, no grant change. |
| `supabase/migrations/20261013110000_kan497_revoke_anon_block_rpcs.sql` | Step 4, separate and later: `REVOKE EXECUTE ... FROM PUBLIC, anon` then `GRANT EXECUTE ... TO authenticated, service_role` on the four mutating RPCs. |
| `CALLERS.md` | Step 1: caller map. |
| `probes.sql` | Step 3: pre-apply, post-narrowing and post-revoke probes, all wrapped in `BEGIN ... ROLLBACK`. |
| `rollback.sql` | Undo. Itself an apply. |
| `test/supabase/anon_block_grants_migration_test.dart` | Pins the shape of both migrations, the order, and the probe pack. |
| `docs/SCHEMA.md` section 2g | A dated note (the allowlist block itself is untouched). |

## Apply order (each step needs the previous one evidenced)

1. Caller map (`CALLERS.md`): done, result below.
2. Narrowing migration, on a CEO-approved non-production database. Run probes A1..A5 first, B1..B6 after.
3. Revoke migration, only after B1..B6 pass. Run C1..C5.
4. Production: only with the CEO's explicit approval of the exact migration text, G-002 backend owner
   plus PEER review (`schema_change` forces PEER), and devops for the push.

The files are separate so the revoke can be held back independently of the narrowing.

## Result of the caller map (decisions 4 and 5)

* Every caller in the repo passes `auth.uid()` as the viewer, directly or through a variable assigned
  from it. No stop condition: the narrowing changes no caller's answer.
* **There are anon-reachable invoker-rights callers of `is_blocked`**: the visibility resolvers
  `can_view_with_scope`, `can_view_with_scope3`, `_can_view_with_scope_canonical`, `can_view_owner`,
  `can_view_post` (2-arg), `_can_view_game_for_join`, reached from the anon-readable views
  `v_game_card`, `v_challenge_card`, `v_meetup_list` and by direct anon RPC. So, per decision 5, the
  revoke migration revokes **four** RPCs and the `is_blocked` revoke is held out.
* The app never calls `is_blocked`, never calls `rpc_block_user(uuid,boolean)`, and calls the other
  three RPCs only as `authenticated`.

## Held for a CEO decision: revoking `is_blocked` itself

Exact held statements (NOT in any migration file; run only after the CEO decides, then re-run
probes D1 and B6):

```sql
REVOKE EXECUTE ON FUNCTION public.is_blocked(uuid, uuid) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.is_blocked(uuid, uuid) TO authenticated, service_role;
```

Why held: an invoker function runs as the calling role, and a role without EXECUTE fails when the
statement is planned, even if a `viewer IS NOT NULL` guard would skip the call. With the revoke, anon
`SELECT` on `v_game_card`, `v_challenge_card` and `v_meetup_list`, and anon calls to the resolvers
above, would fail with "permission denied for function is_blocked". The exact list of what would break:

* views: `v_game_card`, `v_challenge_card`, `v_meetup_list`
* invoker functions: `can_view_with_scope`, `can_view_with_scope3`, `_can_view_with_scope_canonical`,
  `can_view_owner`, `can_view_post` (2-arg), `_can_view_game_for_join`, `can_current_user_join_game`
* policies that call them for anon: `meetups_select_visible`, `roster_select_visible`,
  `waitlist_select_visible`, `challenges_select`, `demo_content_select`, `meetup_attendees_select`
  (where the table is anon-readable)

What the narrowing already gives: `is_blocked` answers false to anon and to third parties, so the
disclosure is closed without the revoke. The anon grant then only lets anon call a function that
answers false. An alternative the CEO may prefer to the revoke: leave the grant, or make the
resolvers SECURITY DEFINER (a separate ticket, outside this one's allowed paths).

**Decision needed from the CEO:** keep `is_blocked` executable by anon after the narrowing (recommended
here), or approve a follow-up that first converts the resolvers and then revokes.

## Rollback

`rollback.sql`: restores the baseline `is_blocked` body (`CREATE OR REPLACE`) and re-grants EXECUTE to
`PUBLIC, anon, authenticated, service_role` on the five. Order: **undo the revoke first, then the
narrowing.** Rollback is itself an apply and needs the CEO's explicit approval. It uses no DROP.
It re-opens the disclosure, so it is a last resort.

## Other findings, reported and not changed

* `notify_admins_of_block` and `rpc_remove_player` are out of scope; not touched.
* The 2-arg `rpc_block_user` writes `restrictions`, not `user_blocks` (CTO P0-c collapse): not part of this ticket.
* `rpc_unfollow_user` does not raise on a missing caller (it matches no row); the other three raise.
* Repo/live drift on `rpc_get_nearby_games` (5-arg record file vs the 6-arg function), see `CALLERS.md` row 5.
* After the revoke, four lines of the section 2g function allowlist are stale. The gate does not fail on a
  stale entry (`scripts/ci/anon_function_grants_diff.sh:248-251`); remove them in a separate change.

## Step 5: the anon allowlist family (KAN-61, T-002)

Run locally on 2026-10-13 from the repository root (docs/SCHEMA.md already carrying the section 2g note):

**1. `scripts/ci/check_anon_allowlist_test.sh` (KAN-61): PASSED.**

```
--- Test 1: live set is a subset of the allowlist -> must PASS ---
OK: all 11 anon-readable definer view(s) are on the allowlist.
PASS: gate correctly allowed the known-good set.

--- Test 2: a deliberately introduced anon-readable definer view -> must FAIL ---
FAIL: anon-readable view(s) without security_invoker are not on the SCHEMA.md §2f allowlist:
  - v_deliberately_introduced_leak

Either this is a new leak (fix it — add security_invoker or revoke anon SELECT),
or it is an intentional addition that needs cto review and a SCHEMA.md §2f update.
PASS: gate correctly rejected the unlisted view (exit code 1).

Self-test result: BOTH cases behaved correctly.
exit=
```

**2. `scripts/ci/check_anon_function_grants_test.sh` (KAN-175): COULD NOT RUN here, so it is not evidenced.**
It needs a real disposable Postgres (`KAN175_TEST_DB_URL`, or docker). This machine has neither docker nor
psql, and no non-production database is approved for this ticket.

```
FAIL: no KAN175_TEST_DB_URL and docker is not available.
This test requires a real disposable Postgres — it cannot fall back to
fixtures without ceasing to test the thing it exists to test.
exit=
```

**3. `scripts/ci/check_function_default_acl_test.sh` (KAN-194): COULD NOT RUN here, same reason.**

```
FAIL: no KAN194_TEST_DB_URL and docker is not available.
This test requires a real disposable Postgres -- it cannot fall back to
fixtures without ceasing to test the thing it exists to test.
exit=
```

Scripts 2 and 3 are left to CI (they have a Postgres service container) or to whoever applies. Nothing was
created, written or applied to any database to make them run.

**The live gates were NOT run.** `check_anon_allowlist.sh` and `check_anon_function_grants.sh` need
`SUPABASE_DB_URL`; they run in CI after apply. This ticket's migrations change no view and no anon view
grant; the function gate reads live `proacl`, so it can only be evidenced after apply.

## Honest status

No document, comment or report in this ticket claims the probes were run. They are AUTHORED, NOT RUN
until a CEO-approved non-production database exists.
