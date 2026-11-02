# KAN-712 — Events P2: parent writes authoritative across all mutation paths

**Status: AUTHORED, NOT APPLIED.** Nothing here has touched the live Supabase project
(`wtncuzcskpigqpmnxwws`) or any remote database. All verification below ran on a throwaway local
PostgreSQL 16 cluster (`/tmp/kan712_pg`, port 54400) that was stopped afterwards.

Author: backend-3 (Shed), team Luxor. Branch `alpha-luxor`, base `71190dfd`. Nothing is committed.

## 1. Files

| File | Lines | Role |
|---|---|---|
| `supabase/migrations/20261103100000_kan712_events_write_contract.sql` | 502 | **Stage A.** Inert on its own: creates `kan712_wrapped_rpcs` and 6 `kan712_*` functions. It creates no trigger and wraps nothing. Post-conditions start at line 465 |
| `supabase/migrations/20261103110000_kan712_cutover.sql` | 240 | **Stage B, the cutover.** One transaction: preconditions (29), direction switch (81-94), RPC wraps (97-129), post-conditions 4a-4d (132-238) |
| `supabase/tests/events_p2/probes_kan712.sql` | 332 | 55 probes, run inside `BEGIN … ROLLBACK`. `[K]` = KAN-712 behaviour (expected to FAIL on phase 1); `[=]` = behaviour that must not change |
| `supabase/tests/events_p2/race_kan712.sql` | 125 | 4 concurrency probes. Uses dblink and **commits**, so run it only on a throwaway copy (`createdb -T <db> kan712_race`) |
| `supabase/tests/events_p2/scenario_kan712.sql` | 166 | Old-vs-new end-to-end scenario: one transaction ending in ROLLBACK, normalized output, diffed |
| `supabase/tests/events_p2/rollback_kan712.sql` | 149 | Lossless rollback in one transaction, printing per-table hashes before and after |
| `supabase/tests/events_p2/local_harness_kan712.sql` | 924 | Local-only stand-ins (roles, auth, baseline objects the RPCs need). **Never run it against Supabase** |
| `supabase/tests/events_p2/KAN712_CONTRACT.md` | — | This file |

KAN-710 (`20261101140000`) and KAN-711 (`20261102110000`, `20261102120000`) are **not edited**.
KAN-711's mirror triggers are disabled and re-enabled from the KAN-712 migration and rollback,
never by changing their files.

## 2. What the cutover does

Before the cutover (phase 1), the legacy `games` and `meetups` tables are authoritative, and the
KAN-711 triggers mirror them into `events`. After the cutover (phase 2), `events` is authoritative
for the shared fields, and every write path reaches `events` first.

| Object (stage A function → stage B trigger) | Behaviour |
|---|---|
| `kan712_legacy_guard()` (77-210) → `trg_zz_kan712_{games,meetups}_guard`, BEFORE INSERT OR UPDATE, sorts last (asserted in 4c) | **INSERT:** writes the `events` parent first. A 23505 duplicate raised by `events` is re-raised under the legacy constraint name `games_creator_user_request_id_key`, so callers see the same error. **UPDATE of a shared field:** if the role is `postgres` or `supabase_admin`, the write is routed through `events` (the compat mirror writes it back). A wrapped RPC runs under `kan712.contract=on`; it holds the events lock already and is routed. Any other role is refused with **42501**. **Non-shared field:** allowed, and `events.updated_at` follows it. **Id change:** 23514 |
| `kan712_legacy_after_delete()` (213-224) → `trg_zz_kan712_{games,meetups}_after_delete` | Deletes the `events` parent |
| `kan712_events_compat_mirror()` (230-285) → `trg_zz_kan712_events_compat_mirror`, AFTER UPDATE ON events | Copies `events` back to legacy. Bound to `pg_trigger_depth()`, so spoofing a GUC cannot suppress it (probes D2, D3) |
| `kan712_update_event_shared(uuid, jsonb)` (290-328) | Ops/admin write path for service_role. It writes events first; the mirror then writes the subtype. It rejects `id`, `creator_user_id`, `request_id` and a non-object patch (22023). **It refuses with 55000 `kan712_not_cut_over` unless the compat mirror trigger exists and is enabled**, so a rolled-back database cannot drift |
| `kan712_wrap_rpc` / `kan712_unwrap_rpc` (334-453) | Generates each wrapper **from the live `pg_proc` entry** (T-058), and records the original owner and ACL in `kan712_wrapped_rpcs`. The wrapper takes `SELECT … FROM events … FOR UPDATE` and then calls `<name>_kan712_inner`. Only `postgres` can execute either function |
| Stage B, step 2 | Disables `trg_kan711_games_mirror` and `trg_kan711_meetups_mirror` (legacy → events), which would otherwise loop against the new direction |

**Lock order after the cutover is always `events` first, then the subtype.** Wrapped RPCs wait on
the events lock. A direct legacy write that finds the events row held fails at once with `55P03`
(NOWAIT) rather than deadlocking (races R1-R3).

## 3. Manifest — every writer of games / meetups

**Counts.**

| Population | Count | How it was measured |
|---|---|---|
| Live writers, harness catalogue (phase 1) | **17** | `pg_proc` regex scan (`writers.sql`), which counts rather than infers (`020`) |
| Wrapped by stage B | **11** | 10 direct writers plus `rpc_cancel_game_series`, which writes only through `rpc_cancel_game` |
| Allowlisted INSERT creators | **5** direct + 2 delegating current versions | Routed by the guard's INSERT path |
| Allowlisted DELETE | **1** | Routed by the after-delete trigger |
| KAN-711 machinery | **1** | Must never run after the cutover |
| Dropped, not live | **2** overloads | `rpc_meetup_create` |
| Client write call sites (`lib/`) | **4** | All refused or dead |
| Edge-function writers | **0** | |
| FK actions that write games/meetups | **7** | |
| Foreign triggers that write games/meetups | **0** | |

### 3.1 SQL functions

"Latest definition" means the last migration that defines the function; that is what is live.

| # | Function | Latest definition (file:line) | Writes | Classification |
|---|---|---|---|---|
| 1 | `rpc_update_game` | `20261008140000_*.sql:283` | update games | **WRAPPED** (game:p_game_id) |
| 2 | `rpc_update_game_legacy_v1` | baseline `:16370`, renamed at `20261008140000:283` | update games | **WRAPPED, optional** (the cutover skips it if absent) |
| 3 | `rpc_reschedule_game` | baseline `:14986` | update games | **WRAPPED** |
| 4 | `rpc_cancel_game` | baseline `:11246` | update games | **WRAPPED** |
| 5 | `rpc_booking_hold_for_game` | baseline `:11148` | update games | **WRAPPED** |
| 6 | `rpc_edit_game_series_occurrence` | `20261030130000_*.sql:35` | update games | **WRAPPED** |
| 7 | `rpc_edit_game_series_future` | `20261030130000:85` | update games | **WRAPPED** (series:p_series_id, which locks every events row of the series) |
| 8 | `rpc_cancel_game_series` | `20261030130000:165` | via `rpc_cancel_game` | **WRAPPED** (series) |
| 9 | `fn_generate_game_series_occurrences` | `20261030140000_*.sql:33-84` | update games (+ insert via create) | **WRAPPED** (series; the cron caller is service_role) |
| 10 | `rpc_meetup_update` | `20260915120000_*.sql:534` | update meetups | **WRAPPED** (meetup:p_meetup_id) |
| 11 | `rpc_meetup_cancel` | `20260915120000:373` (baseline `:13567`) | update meetups | **WRAPPED** |
| 12 | `rpc_create_game` (current) | `20261021120200_*.sql:35`, delegates to legacy_v2 at `:45` and `:55` | — | **ALLOWLIST** (delegator) |
| 13 | `rpc_create_game_legacy_v1` | `20261008140000:170` (baseline `:11659`) | insert games | **ALLOWLIST: guard INSERT path** |
| 14 | `rpc_create_game_legacy_v2` | `20261021120200:31` | insert games | **ALLOWLIST: guard INSERT path** |
| 15 | `rpc_create_meetup` (current) | `20261021120300_*.sql:33`, delegates | — | **ALLOWLIST** (delegator) |
| 16 | `rpc_create_meetup_legacy_v1` | `20261008140000:447` (baseline `:11753`, `20260915120000:224`) | insert meetups | **ALLOWLIST: guard INSERT path** |
| 17 | `rpc_create_meetup_legacy_v2` | `20261021120300:29` | insert meetups | **ALLOWLIST: guard INSERT path** |
| 18 | `rpc_challenge_spawn_game` | baseline `:11599` | insert games | **ALLOWLIST: guard INSERT path.** Pre-existing defect: fails in both phases (L-1) |
| 19 | `admin_cleanup_user_data` | baseline `:2223-2300` | delete games | **ALLOWLIST: after-delete trigger** (L-2, L-7) |
| 20 | `kan711_events_backfill_batch` | `20261102120000_*.sql:140-245` | update games, meetups | **KAN-711 MACHINERY.** Excluded from 4d by prefix. **Must never be CALLed after the cutover** (L-6) |
| 21 | `kan712_events_compat_mirror` | `20261103100000:230-285` | update games, meetups | **INTERNAL** (the phase-2 mirror) |
| 22 | `rpc_meetup_create` (2 overloads) | baseline `:13672`, `:13765` | — | **DROPPED** at `20260915120000:95-96`. Not live, not wrapped |

Post-condition **4d** (`20261103110000:220-238`) fails the cutover closed if any public function
outside this classification UPDATEs games/meetups, or INSERTs into or DELETEs from them. Probe I2
demonstrates that it catches a planted writer.

### 3.2 Client and edge functions

| Site | Operation | Phase-1 and phase-2 outcome |
|---|---|---|
| `lib/…/supabase_games_datasource.dart:203` | insert games | Refused. `authenticated` has a grant but no INSERT policy |
| `lib/…/supabase_games_datasource.dart:436` | update games | 0 rows. No UPDATE policy (probe A7, unchanged) |
| `lib/…/supabase_games_datasource.dart:687` | update games `status` | Dead: the column does not exist |
| `lib/…/data_retention_service.dart:317` | delete games by `creator_id` | Dead: the column does not exist |

The other 15 sites are select-only, plus a realtime stream at `supabase_games_datasource.dart:56`.
No edge function touches games, meetups or events. `meetups` has no `authenticated` table grants,
and `events` has no anon/authenticated grants (probes A8, D6).

### 3.3 FK actions and foreign triggers

| Table | Constraint | Action | Phase-2 path |
|---|---|---|---|
| games | event_id → events | ON DELETE CASCADE | The parent delete removes the child. Not a shared-field write |
| games | geo_location_id, series_id, venue_id | SET NULL | Runs as the table owner (`postgres`), so the guard routes it, taking the events lock with NOWAIT (L-8) |
| meetups | event_id → events | CASCADE | as above |
| meetups | host_actor_id → profiles | CASCADE | The child delete fires the after-delete trigger |
| meetups | area_id, sport_id, venue_id | SET NULL | Routed, as for games |

No trigger on any other public table writes games or meetups (`fk.sql`, empty result).

## 4. Decisions

| ID | Decision | Why |
|---|---|---|
| D-A | Two stages. A is inert; B is the switch | A can land and be reviewed without changing behaviour. Rollback keeps A (no DROP TABLE allowed) and a re-cut needs only B |
| D-B | Generate wrappers from live `pg_proc` instead of rewriting 11 bodies | T-058: a hand copy from migration files reproduces stale attributes. Owner and ACL are restored exactly (H1, H5) |
| D-C | Refuse (42501) a direct shared-field write by an API role, but route `postgres`/`supabase_admin` | API roles have no legitimate direct path. The migration, seed and FK paths run as the owner and must keep working (A10) |
| D-D | Use NOWAIT for unwrapped writers, and lock events first in wrappers | This removes the 40P01 deadlock shape. The cost is a fast 55P03 retry (R1, R3) |
| D-E | The compat mirror and routing are bound to `pg_trigger_depth()`, not to a GUC | A spoofed `SET kan712.*` cannot open or suppress anything (D2, D3). `kan712.contract` stays a GUC; see L-9 |
| D-F | The ops path refuses unless the cutover is live (55000) | Found during the rollback run: J1/J3 drifted when the ops path wrote events-only on a rolled-back database |
| D-G | No new grants. `kan712_*` functions are executable only by `postgres`; the ops function also by `service_role` | Brief rule. Asserted from `proacl`, including revocation from `anon` by name |

### Dependency matrix

| Step | Depends on | Blocks |
|---|---|---|
| KAN-710 parent schema (`20261101140000`) | — | everything |
| KAN-711 mirror + backfill (`20261102110000/120000`) | KAN-710 | KAN-712 B |
| KAN-711 backfill **finished**, parity 0, `validate_links` VALIDATED | KAN-711 | KAN-712 B (checked in B's preconditions) |
| KAN-712 A (`20261103100000`) | KAN-710 | KAN-712 B |
| KAN-712 B (`20261103110000`) | A + all of the above | phase 3 |
| Phase 3 (exactly-one-child, legacy read cutover) | B live and stable | phase 4 (column deletion) |

## 5. Cutover runbook

**Preconditions.** B checks each of these in `20261103110000:29-79` and aborts if any fails:
1. The applying role is superuser or BYPASSRLS.
2. Stage A is applied, and neither a kan712 trigger nor a wrapped row exists yet.
3. All five KAN-711 triggers are present and enabled.
4. `events_backfill_checkpoint` has 2 rows, both with `finished_at` set, and there are 0 unresolved `events_backfill_exceptions`.
5. `public.kan711_events_validate_links()` has run, so the `{games,meetups}_event_id_not_null` checks and the `_fkey` constraints are `convalidated`. No legacy row has a NULL `event_id`.
6. `kan711_events_parity` returns 0 rows, and no events row lacks a legacy child.
7. Every required RPC on the wrap list exists (checked in step 3; `rpc_update_game_legacy_v1` is optional).

The operator must also make sure **no backfill CALL is running or scheduled** (L-6). B cannot check this.

**Steps.**
1. Apply A (`20261103100000`). Its post-conditions assert the function attributes and ACL. Behaviour does not change.
2. In a low-traffic window, apply B (`20261103110000`). B takes `SHARE ROW EXCLUSIVE` locks on events, games and meetups for its duration; this is short, consisting of 5 trigger creates and 11 function renames and creates.
3. Verify:
   - B's own 4a-4d raised nothing;
   - `SELECT count(*) FROM kan711_events_parity` = 0;
   - `SELECT count(*) FROM kan712_wrapped_rpcs` = 11 (10 if `rpc_update_game_legacy_v1` is absent);
   - smoke-call one wrapped RPC as an authenticated host.
4. Do not CALL the KAN-711 backfill again (L-6).

## 6. Rollback runbook (lossless)

Run `supabase/tests/events_p2/rollback_kan712.sql` as `postgres`. It runs as one transaction:
1. Lock the tables, and record md5 hashes and row counts for events, games and meetups.
2. Check preconditions: 5 `trg_zz_kan712_*` triggers present, wrapped rows present, parity 0. Otherwise it aborts with "cutover is not applied", so a second run fails closed (exit 3).
3. Unwrap all 11 RPCs from the recorded rows: drop the wrapper, rename the inner back, restore the owner and ACL.
4. Drop the 5 KAN-712 triggers (no CASCADE), and re-enable the KAN-711 mirrors.
5. Check post-conditions:
   - **4a:** hashes equal and parity 0;
   - **4b:** no wrapper rows, no `*_kan712_inner`, owner and ACL equal to the originals, no `kan712.contract` proconfig;
   - **4c:** trigger set equal to the KAN-711 state;
   - **4d:** the ops path now refuses with 55000.

Stage A objects stay in place: they are inert, and `kan712_wrapped_rpcs` is a table, which may not be dropped. **A re-cut after rollback means applying B again; A is not re-applied.** This was verified locally (recut, section 9).

## 7. Limitations and known defects (reported, not fixed: none blocks KAN-712)

| ID | Item |
|---|---|
| L-1 | `rpc_challenge_spawn_game` fails in both phases (pre-existing). The SQLSTATE differs: 23502 on old, 23514 on new, because the guard writes events first and the events CHECK fires before the legacy NOT NULL. This is the only scenario diff |
| L-2 | `admin_cleanup_user_data` on a meetup-owning user fails in both phases with 23503 (`meetups_creator_profile_id_fkey` RESTRICT). Pre-existing |
| L-3 | The meetup outbox `owner_user_id` defect (pre-existing, seen in scenario sinks). Not touched |
| L-4 | `rpc_meetup_cancel` emits `meetup.cancelled` again on a repeat cancel (2 rows for 2 calls, in both phases). Pre-existing |
| L-5 | The draft-publish path calls `create_game(jsonb)`, which does not exist. Pre-existing and dead |
| L-6 | **`kan711_events_backfill_batch` must never be CALLed after the cutover.** It writes legacy → events, the reverse direction. It is excluded from 4d by prefix, so nothing stops a manual CALL. Phase 3 should drop or guard it |
| L-7 | `admin_cleanup_user_data` locks subtype → events (delete, then the after-delete trigger), the reverse of the wrapper order. It is rare and admin-only; a collision yields 55P03/40P01 on the admin call, not data loss |
| L-8 | FK SET NULL actions run as `postgres` and are routed with NOWAIT. A venue or area delete during a concurrent wrapped RPC on the same event fails fast. This is covered by analogy with A10, not by a dedicated probe |
| L-9 | A service_role that spoofs `SET kan712.contract=on` skips the 42501 refusal, but the write is **still routed** through events (D4: events = games). Integrity holds; only the refusal is bypassable |
| L-10 | Exactly-one-child (each events row has exactly one games or meetups child) is not enforced. Phase 3 |
| L-11 | The 4d scan covers `public` functions only, by regex on `prosrc`. It does not see dynamic SQL built from fragments, MERGE, other schemas, or non-plpgsql/sql languages |
| L-12 | `postgres` has BYPASSRLS. Owner-path writes are routed, not authorised |
| L-13 | `host_actor_id` is a local stub in the harness; the live persona model was not exercised |
| L-14 | The wrappers are generated at cutover time from the live catalogue, so the live bodies are what get wrapped, not the repo files. The local run proves the generator; it does not prove the live bodies match the repo |
| L-15 | KAN-710's deferred `events_check_subtype_link` raises "orphan" when one transaction creates and deletes a game and then reaches `SET CONSTRAINTS ALL IMMEDIATE` or commit. **Reproduced on phase 1**, so it is pre-existing. The probes set constraints immediate before G1 to avoid it |
| L-16 | On phase 1, a direct service_role write to `events` is not mirrored to legacy (D1 FAIL on old). That is the phase-1 contract and is closed by the cutover |
| L-17 | The rolled-back state keeps stage A. Probes B10, B11 and H7 therefore still PASS after rollback (the ops path is refused to anon/auth, and wrap/unwrap is refused to service_role); these 3 are the only differences from phase 1 |

## 8. Phase 3 prerequisites

1. KAN-712 B live, parity 0 sustained, no 55P03 storm in logs.
2. Drop or guard `kan711_events_backfill_batch` (L-6), and drop the disabled KAN-711 mirrors once phase 3 owns the direction.
3. Enforce exactly-one-child (L-10).
4. Move reads to `events` for the shared fields, so the legacy columns become write-through only. Then phase 4 can delete them.
5. Decide whether the `kan712.contract` GUC should be replaced by a depth or role check (L-9).
6. Fix or retire `rpc_challenge_spawn_game` (L-1) and the `admin_cleanup` RESTRICT (L-2). This is product-owned, outside KAN-712.

## 9. Local verification (real output)

**Cluster.** PG 16, `/tmp/kan712_pg`. Two databases were built fresh by the same chain: harness, then seed, then KAN-710, then KAN-711, then backfill.
- `kan712_old` is phase 1.
- `kan712_new` is phase 1 plus A plus B.
- `build_old_exit=0, parity_rows=0`; `build_new_exit=0, wrapped=11`.

### Probes (`probes_kan712.sql`)

| Database | Result |
|---|---|
| new (cut over) | `#TOTAL\|pass=55\|fail=0` |
| old (phase 1) | `#TOTAL\|pass=25\|fail=30`. Every FAIL is `[K]`; every `[=]` passes |
| new, rolled back | `pass=28\|fail=27`. Differs from old only at B10, B11 and H7 (L-17) |
| new, re-cut | `pass=55\|fail=0` |

New, full output:
```
A1 [K]|PASS|expected=ERR 42501|actual=ERR 42501|service_role direct UPDATE games shared field (title) is refused
A2 [K]|PASS|expected=ERR 42501|actual=ERR 42501|service_role direct UPDATE meetups shared field (start_at) is refused
A3 [K]|PASS|expected=ERR 42501|actual=ERR 42501|service_role direct UPDATE games is_cancelled (cancel bypass) is refused
A3b [K]|PASS|expected=Sunday 5s|false|t|actual=Sunday 5s|false|t|refused writes changed nothing (title, is_cancelled, meetup start_at = events)
A4 [=]|PASS|expected=1|actual=1|service_role direct UPDATE games non-shared field (price_aed) is allowed
A5 [=]|PASS|expected=e=1 g=1 m=0 same_ts=true|actual=e=1 g=1 m=0 same_ts=true|non-shared write: events.updated_at follows (one events UPDATE, one games UPDATE)
A6 [=]|PASS|expected=1|actual=1|service_role direct UPDATE meetups non-shared field (description) is allowed
A7 [=]|PASS|expected=0|actual=0|authenticated host direct UPDATE games: RLS filters it (0 rows), before and after
A8 [=]|PASS|expected=ERR 42501|actual=ERR 42501|authenticated host direct UPDATE meetups: no grant
A9 [=]|PASS|expected=ERR 42501|actual=ERR 42501|anon direct UPDATE games: no grant
A10 [=]|PASS|expected=1|pg routed|e=1 g=1 m=0|actual=1|pg routed|e=1 g=1 m=0|postgres (migration/seed path) direct UPDATE games title is routed to events
A11 [K]|PASS|expected=ERR 23514|actual=ERR 23514|id change on a legacy row is refused
B1 [K]|PASS|expected=ops title|ops title|ops title|actual=ops title|ops title|ops title|service_role ops patch on a game updates events, mirrored to games
B2 [K]|PASS|expected=e=1 g=1 m=0|actual=e=1 g=1 m=0|ops patch: exactly one events UPDATE and one games UPDATE (no loop)
B3 [K]|PASS|expected=changed|same|e=1 g=0 m=1|actual=changed|same|e=1 g=0 m=1|ops patch on a meetup: join_policy lands in meetups.rsvp_policy (value changed)
B4 [K]|PASS|expected=ERR 22023|actual=ERR 22023|ops patch rejects id
B5 [K]|PASS|expected=ERR 22023|actual=ERR 22023|ops patch rejects creator_user_id
B6 [K]|PASS|expected=ERR 22023|actual=ERR 22023|ops patch rejects request_id
B7 [K]|PASS|expected=ERR 22023|actual=ERR 22023|ops patch rejects a non-object patch
B8 [K]|PASS|expected=ERR P0002|actual=ERR P0002|ops patch on a missing event
B9 [K]|PASS|expected=ERR 23514|ops title|ops title|actual=ERR 23514|ops title|ops title|ops patch violating a CHECK fails and changes nothing
B10 [K]|PASS|expected=ERR 42501|actual=ERR 42501|anon cannot call the ops path
B11 [K]|PASS|expected=ERR 42501|actual=ERR 42501|authenticated cannot call the ops path
C1 [K]|PASS|expected=msg=1 notif=players e=1 g=1 m=0|actual=msg=1 notif=players e=1 g=1 m=0|ops cancel: one system line, one game.updated per non-host player, one UPDATE each
C2 [K]|PASS|expected=msg=1 notif=players|actual=msg=1 notif=players|repeating the same cancel adds no side effect
D1 [K]|PASS|expected=1|from events|e=1 g=1 m=0|actual=1|from events|e=1 g=1 m=0|service_role direct UPDATE events title is mirrored to games, once
D2 [K]|PASS|expected=1|spoof routing|actual=1|spoof routing|spoofed SET kan712.routing does not suppress the mirror (depth-bound)
D3 [K]|PASS|expected=ERR 42501|actual=ERR 42501|spoofed SET kan712.compat does not open the refusal (depth-bound)
D4 [=]|PASS|expected=1|spoof contract|spoof contract|actual=1|spoof contract|spoof contract|spoofed SET kan712.contract by service_role: not refused, but still ROUTED (events = games)
D5 [=]|PASS|expected=0|actual=0|spoofed SET kan712.contract by authenticated: RLS still filters (0 rows)
D6 [=]|PASS|expected=ERR 42501|actual=ERR 42501|authenticated cannot write events at all
E0 [=]|PASS|expected=ok|actual=ok|fixture game create (authenticated host, future)
E1 [=]|PASS|expected=true|actual=true|request_id replay with different payload returns the same id
E2 [=]|PASS|expected=1|1|actual=1|1|replay created nothing: one games row, one events row for that request_id
E3 [=]|PASS|expected=rescheduled|e=1 g=1 m=0|true|actual=rescheduled|e=1 g=1 m=0|true|rpc_reschedule_game: one events UPDATE, one games UPDATE, values equal
E4 [=]|PASS|expected=cancelled|e=1 g=1 m=0|1|actual=cancelled|e=1 g=1 m=0|1|rpc_cancel_game: one UPDATE each, one system line
E5 [=]|PASS|expected=ERR P0001|actual=ERR P0001|non-host cannot reschedule through the wrapper
E6 [=]|PASS|expected=ERR 23514|0|0|actual=ERR 23514|0|0|failed create (CHECK) leaves no games/events row for its request_id
F1 [K]|PASS|expected=ERR 23505 games_creator_user_request_id_key via_events|actual=ERR 23505 games_creator_user_request_id_key via_events|duplicate (creator, request_id) insert: 23505 under games_creator_user_request_id_key, raised from the events parent
F2 [=]|PASS|expected=0|0|actual=0|0|the failed insert left no row behind
G1 [=]|PASS|expected=1|0|actual=1|0|postgres DELETE of a legacy game removes its events parent (KAN-711 mirror before, KAN-712 after-delete after)
G2 [K]|PASS|expected=disabled|1|1|actual=disabled|1|1|control: after-delete trigger disabled -> the events parent survives the delete
H1 [K]|PASS|expected=11|0|actual=11|0|every wrapper ACL equals the recorded original, owner unchanged (11 RPCs)
H2 [K]|PASS|expected=11|0|actual=11|0|no inner is executable by anon/authenticated/service_role (11 inners)
H3 [K]|PASS|expected=ERR 42501|actual=ERR 42501|authenticated calling an inner directly is refused
H4 [K]|PASS|expected=ERR 42501|actual=ERR 42501|service_role calling the generator inner directly is refused
H5 [=]|PASS|expected=true|false|true|false|actual=true|false|true|false|wrapped RPC grants unchanged: anon keeps rpc_cancel_game, loses nothing, gains nothing
H6 [=]|PASS|expected=ERR 42501|actual=ERR 42501|anon calling rpc_update_game is refused
H7 [K]|PASS|expected=ERR 42501|ERR 42501|ERR 42501|actual=ERR 42501|ERR 42501|ERR 42501|service_role cannot call kan712_wrap_rpc / kan712_unwrap_rpc / read kan712_wrapped_rpcs
H8 [K]|PASS|expected=11|actual=11|every wrapper: SECURITY DEFINER, search_path pinned, kan712.contract=on
I1 [K]|PASS|expected=<none>|actual=<none>|writer scan is clean after cutover
I2 [=]|PASS|expected=kan_probe_bad_deleter(), kan_probe_bad_writer()|actual=kan_probe_bad_deleter(), kan_probe_bad_writer()|writer scan catches a planted UPDATE writer and a quoted DELETE writer
J1 [=]|PASS|expected=0|actual=0|parity view: 0 rows (events = legacy for every linked row)
J2 [=]|PASS|expected=0|0|actual=0|0|no events row without a legacy child, no legacy row without its parent
J3 [=]|PASS|expected=0|actual=0|updated_at equal on every linked row
#TOTAL|pass=55|fail=0
```

Old (phase 1), FAIL lines only. Each one is the probe failing before it counts as passing:
```
A1 [K]|FAIL|expected=ERR 42501|actual=1|...
A2 [K]|FAIL|expected=ERR 42501|actual=1|...
A3 [K]|FAIL|expected=ERR 42501|actual=1|...
A3b [K]|FAIL|expected=Sunday 5s|false|t|actual=direct|true|t|...
A11 [K]|FAIL|expected=ERR 23514|actual=ERR 23505|...
B1..B11 [K]|FAIL|actual=ERR 42883 (ops function does not exist on phase 1)
C1 [K]|FAIL|expected=msg=1 notif=players e=1 g=1 m=0|actual=msg=0 notif=mismatch e=0 g=0 m=0|...
C2 [K]|FAIL|expected=msg=1 notif=players|actual=msg=0 notif=mismatch|...
D1 [K]|FAIL|expected=1|from events|e=1 g=1 m=0|actual=1|Same request other type|e=1 g=0 m=0|...
D2 [K]|FAIL|expected=1|spoof routing|actual=1|Same request other type|...
D3 [K]|FAIL|expected=ERR 42501|actual=1|...
F1 [K]|FAIL|expected=ERR 23505 games_creator_user_request_id_key via_events|actual=ERR 23505 games_creator_user_request_id_key via_legacy|...
G2 [K]|FAIL|expected=disabled|1|1|actual=ERR 42704|0|0|...
H1, H2, H8 [K]|FAIL|actual=ERR 42P01;  H3, H4 [K]|FAIL|actual=ERR 42883;  H7 [K]|FAIL|actual=ERR 42883|ERR 42883|ERR 42P01
I1 [K]|FAIL|expected=<none>|actual=fn_generate_game_series_occurrences(uuid), rpc_booking_hold_for_game(...), rpc_cancel_game(uuid,text), rpc_edit_game_series_future(...), rpc_edit_game_series_occurrence(...), rpc_meetup_cancel(uuid), rpc_meetup_update(...), rpc_reschedule_game(...), rpc_update_game_legacy_v1(...), rpc_update_game(...)
#TOTAL|pass=25|fail=30
```

### Races (`race_kan712.sql`, on a throwaway copy)

New:
```
R1 [K]|PASS|expected=ERR 55P03|fast|actual=ERR 55P03|fast|events row held by another session: direct service_role UPDATE games fails fast with 55P03
R2 [K]|PASS|expected=busy=1 waiting=1 games_free=1 result=rescheduled|slow|actual=busy=1 waiting=1 games_free=1 result=rescheduled|slow|wrapped rpc_reschedule_game waits on the events lock first, holding no games row lock; completes after release
R3 [K]|PASS|expected=busy=1 events_held=ERR 55P03 legacy_write=ERR 55P03 result=rescheduled|slow|actual=busy=1 events_held=ERR 55P03 legacy_write=ERR 55P03 result=rescheduled|slow|deadlock shape: RPC holds events and waits on games; the legacy writer gets 55P03 at once (no 40P01); the RPC completes
R4 [=]|PASS|expected=true|0|actual=true|0|after the races: events = games for the fixture (start_at, end_at), parity view empty
#TOTAL|pass=4|fail=0
```
Old:
```
R1 [K]|FAIL|expected=ERR 55P03|fast|actual=ERR 55P03|slow|...
R2 [K]|FAIL|expected=busy=1 waiting=1 games_free=1 result=rescheduled|slow|actual=busy=1 waiting=1 games_free=ERR 55P03 result=rescheduled|slow|...
R3 [K]|FAIL|expected=busy=1 events_held=ERR 55P03 legacy_write=ERR 55P03 result=rescheduled|slow|actual=busy=1 events_held=1 legacy_write=1 result=rescheduled|slow|...
R4 [=]|PASS|expected=true|0|actual=true|0|...
#TOTAL|pass=1|fail=3
```

### Scenario diff, old vs new (`scenario_kan712.sql`)

There are 33 steps, covering:
- game create, replay, update, reschedule, hold and cancel;
- meetup create, replay, update and cancel;
- failed creates, with zero row deltas;
- series create, edit-occurrence, edit-future, cancel and the cron generator;
- challenge spawn;
- admin cleanup.

Projections of every game, meetup, event, series and sink row follow the steps. The whole diff, which is identical after the re-cut:
```
56c56
< #STEP|40|rpc_challenge_spawn_game (defect, fails in both)|ERR 23502
---
> #STEP|40|rpc_challenge_spawn_game (defect, fails in both)|ERR 23514
```
New ends with `#PARITY|kan711_events_parity rows=0` and `#PARITY|updated_at equal games=0 meetups=0 orphans=0`.

### Rollback (`rollback_kan712.sql` on `kan712_new`)

```
NOTICE:  KAN-712 rollback hash events rows=12 before=f31e518c11e11bcbefbefaa17791c118 after=f31e518c11e11bcbefbefaa17791c118
NOTICE:  KAN-712 rollback hash games rows=6 before=356187c6b84022de6e5ad7fb33c8d857 after=356187c6b84022de6e5ad7fb33c8d857
NOTICE:  KAN-712 rollback hash meetups rows=6 before=279551efda859b15cab138cbbe99cdb0 after=279551efda859b15cab138cbbe99cdb0
rollback_exit=0
```
**Catalogue fingerprint.** This is the md5 over every public function's definition, owner and ACL, plus every trigger, excluding `kan712_%`; 90 lines:
```
fp_old=9a2d6669b3ceb8ef929006edf36e7ac0 fp_new_cutover=4e0e1c7ba2844830400cc2139a998e17 fp_new_rolledback=9a2d6669b3ceb8ef929006edf36e7ac0
diff_old_vs_rb_exit=0
fp_new_recut=4e0e1c7ba2844830400cc2139a998e17
```
**Second rollback** (fails closed):
```
ERROR:  KAN-712 rollback: the cutover is not applied (expected 5 trg_zz_kan712_* triggers)
rollback_twice_exit=3
```
After the rollback, the probes gave pass=28 and fail=27, and a re-cut by applying B again gave `recut_exit=0` and pass=55 with fail=0.
