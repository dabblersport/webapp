# KAN-719 Z02 (KAN-779): pre-removal snapshot, restore path, surgery window

Epic KAN-708, Events P4. This covers the snapshot taken before Z01 (`20261105100000_kan719_z01_remove_replaced_columns.sql`, KAN-778) and the path back from it.

**Nothing here is applied anywhere.** No migration is added. The test is `kan719_z02_restore_test.sql` in this folder.

**This reuses KAN-776 D08 and does not replace it.** The runbook is `KAN718_RUNBOOK.md` (sections R2, R3 and G1–G5) and the probe is `kan718_d08_rollback_probe.sql`. Every restore step below carries the D08 step it implements.

## 1. Applied versus authored

| Object | State |
|---|---|
| Z01 removal migration | authored (KAN-778), **not applied** to production or to any shared database |
| Z02 snapshot and restore (this doc, the test) | authored, **not applied** to production. It runs only on local `k779*` databases, inside one transaction that ends in `ROLLBACK` |
| Snapshot schema `kan719_z02_snap` | exists only inside the test transaction. The test proves it is gone afterwards |

## 2. What the snapshot holds

The snapshot is the schema `kan719_z02_snap`. The test runs `REVOKE ALL ON SCHEMA … FROM PUBLIC` on it, and asserts that `anon`, `authenticated` and `service_role` have no `USAGE` on it.

**Why it is closed to API roles (T-020):** it holds full copies of rows that RLS protects.

| Table | Contents |
|---|---|
| `shape_q` | The **whole** shape of `games` and `meetups`, captured with `search_path = ''` so every definition is schema-qualified. This is what the restore rebuilds from. It covers: <ul><li>every column: type, NOT NULL, default, comment, column ACL, identity/generated, attnum</li><li>every trigger, with its `tgenabled` state</li><li>every constraint and index</li><li>the policies on `games`, `meetups` and `meetup_attendees`</li><li>the full `supabase_realtime` table list, with column lists and row filters</li><li>the events compat mirror `trg_zz_kan712_events_compat_mirror`</li></ul> D08's capture (P5) covered only the manifest objects. This one covers the whole of both tables |
| `shape` | The same capture taken at the app's `search_path`. It is used only for comparison (V1) |
| `games_rows`, `meetups_rows`, `events_rows` | Full row copies (`CREATE TABLE AS SELECT *`). They keep ids, NULLs, `created_at`/`updated_at` and `search_tsv` byte for byte. Z1 checks this against the live rows by md5 |
| `visible` | The id sets that an authenticated **non-owner** (`…dead`) and a **blocked** user (`…a6`) can see in `games` and `meetups` |
| `restore_point` | The D08 G5 record, exactly one row: <ul><li>`backup_ts`</li><li>`taken_by` and `db`</li><li>the G3 fingerprint `g3_fp`</li><li>catalogue md5 and data md5</li><li>the manifest md5, which must be `614c1f8d29cd017126bca92588e96d9f`, the value Z01 is authored against</li></ul> |

**The snapshot rows are evidence, not the restore source.** D08 R3 and NEGATIVE 1 both make this point: anything written after the cutover exists only in `events`. A restore that reads the snapshot rows silently loses those writes. Section 5 shows the test catching exactly that.

## 3. Surgery window rules

1. **Who may run it.** Only the operations seat that runs Z01 (Memphis, per the Z01 header), connected as a superuser or a `BYPASSRLS` owner.
   - **On production, the restore needs the CEO's explicit go-ahead in the moment.** It `UPDATE`s existing user rows, and `019` reserves user-data mutation and destructive or irreversible production action to the CEO.
   - Nothing in this ticket authorises a production run.
2. **The order is fixed:**
   1. **Snapshot (S1).** This is its own committed transaction.
   2. **Window opens.** Run G1 `LOCK events, games, meetups IN SHARE ROW EXCLUSIVE MODE` with `lock_timeout = 10s`, then `SET CONSTRAINTS ALL IMMEDIATE`.
   3. **G2.** `kan711_events_parity` must be empty, else `k779_legacy_events_diverged`, which points to runbook R0.
   4. **G3.** The current fingerprint must equal `restore_point.g3_fp`. If it does not, the data moved after the snapshot, so take a fresh snapshot and never reuse the old one.
   5. **Z01** runs.
   6. **G4.** The fingerprint must be unchanged, else `k779_write_landed_mid_surgery`. Then `ROLLBACK`, never `COMMIT`.
   7. **COMMIT** closes the window.
3. **A rollback is its own window.** Take the G1 lock again, then run R2.2 source completeness, then R2.3 to R2.12. V1 to V6 must pass **before** `COMMIT`. Any failure means `ROLLBACK`.
4. **Fail closed.** Every gate raises an exception, and none of them warns and continues. The restore refuses in three cases:
   - there is no single restore point for the current database;
   - a removed column has no source in `events`;
   - a column carries column-level grants (restore those by hand).
   
   It aborts with `k779_restore_wrote_events` if the restore changed `events` at all.
5. **The snapshot is taken once and never overwritten.** The guard refuses if `kan719_z02_snap` already exists, and `restore_point` carries a singleton index.

## 4. Restore steps, in order

The restore source is `public.events` plus the surviving `games`/`meetups` rows (D08 R3). These are the steps in `pg_temp.z_restore('events')`.

| # | Step | D08 |
|---|---|---|
| 0 | Refuse without a single restore point for this database | R2.0 |
| 1 | `LOCK` the three tables `SHARE ROW EXCLUSIVE` | R2.1 / G1 |
| 2 | Source complete: every subtype row has an `events` parent of its own type with `event_id = id`, and there are no orphan events | R2.2 |
| 3 | Re-add the missing columns (snapshot `shape_q` minus live), nullable, in captured attnum order | R2.3 |
| 4 | Recreate the `search_tsv` triggers `ENABLE ALWAYS` | R2.4 |
| 5 | Under `session_replication_role = replica`, run `UPDATE t SET (cols) = ROW(e.cols) FROM events e WHERE e.id = t.event_id`. `rsvp_policy` takes `join_policy`. `search_tsv` is recomputed by its trigger and not copied | R2.5 |
| 6 | Back to `origin`. Restore the `search_tsv` triggers to their normal state, then defaults, NOT NULL and comments. Abort on a column ACL | R2.6 |
| 7 | Constraints, validated | R2.7 |
| 8 | Indexes | R2.8 |
| 9 | Triggers, then `tgenabled` (D/A/R) exactly as captured | R2.9 |
| 10 | `ALTER POLICY` back to the captured `USING` / `WITH CHECK` | R2.10 |
| 11 | `ALTER PUBLICATION supabase_realtime SET TABLE` with the full captured list (F2) | R2.11 |
| 12 | **Recreate** `trg_zz_kan712_events_compat_mirror` from the capture. D08 R2.12 re-enables it, but Z01 seq 334 **drops** it, and it is not in the k774 manifest. Then assert that `events` was not written | R2.12 |
| V | V1 shape equals the snapshot in both directions. V2 parity is 0. V3 counts. V4 post-cutover writes. V5 untouched rows equal the snapshot. V6 RLS visibility | V1–V6 |

## 5. What the test proves

| Line | Assertion |
|---|---|
| Z1 | The snapshot is byte-identical to the live rows. NULLs are captured as NULL. The manifest md5 is right. The schema is closed to `anon`, `authenticated` and `service_role` |
| Z2 | Z01's own statements run inside the window: G1, G2, G3 equal to the snapshot, then G4 unchanged |
| Z3 | Post-cutover writes. W2 is an `events` edit of the seeded game, with `updated_at` pinned to 2026-08-01. W3 is a brand-new game (an `events` row plus a `games` row) with `created_at` 2026-09-01 |
| NEG V1 / NEG VERIFY | Before any restore, both probes **fail** on the removed state, which shows they can fail |
| **NEG** | **The negative.** A restore from the snapshot alone, without `events`, puts the old title back and leaves W3's columns NULL. The verifier fails with `W2(...) W3(...)`. Rolling back to the savepoint leaves data md5 and catalogue md5 identical |
| Z5 | R2.1–R2.12 from `events`, with `events` untouched |
| V1 | The legacy shapes of `games` and `meetups` equal the snapshot: column set, types, NOT NULL and defaults, triggers including their enabled state, constraints, indexes, policies and the publication. F3 (column order) is reported separately |
| V2 | Parity is 0 |
| V3 | No row is doubled. `games` equals the snapshot plus W3, which equals the game events. `meetups` equals the snapshot, which equals the meetup events. `event_id = id` everywhere |
| V4 | W2 survives with its title, pinned `updated_at`, original `created_at` and recomputed `search_tsv`. W3 survives with its id, `event_id`, title, timestamps and NULL `cancelled_reason` |
| V5 | Every untouched legacy row equals its snapshot row on every column. The seeded meetup's `end_at` and `capacity` are still NULL. `rsvp_policy` equals `join_policy` |
| V6 | The non-owner and the blocked user see exactly their snapshot id sets. The blocked user does not see the owner's game or W3. The snapshot stays closed |
| Z7 | After `ROLLBACK`, catalogue md5 and data md5 are identical to before, and `kan719_z02_snap` is gone |

## 6. How to run it

Use local or disposable PostgreSQL 16 only. The guard refuses:
- a Supabase-shaped database;
- a database whose name does not start with `k779`;
- a non-superuser;
- a database with no seeded game and meetup;
- a database that is not cut over.

Run it like this:

```bash
MANSQL=$(sed -n '/^CREATE TEMP TABLE k774_retained/,/^-- M1-M5/p' supabase/tests/events_p4/kan718_d06_manifest_check.sql)
psql -X -v ON_ERROR_STOP=1 -d k779… -v mansql="$MANSQL" \
  -v migtext="$(cat supabase/migrations/20261105100000_kan719_z01_remove_replaced_columns.sql)" \
  -f supabase/tests/events_p4/kan719_z02_restore_test.sql
```

The clean proof is `bash /Users/moataz/.claude/jobs/dcb6a775/tmp/k779/clean779.sh <sha>`. It is not committed. It does the following:
1. Builds from `git archive <sha>`, so only tracked files are used.
2. Builds `k779base`, which is the k781 chain.
3. Seeds `k779seed` with D04 and D05, one game and one meetup.
4. Runs the test on a fresh copy.
5. Requires `KAN-779 RESTORE TEST PASS`.

## 7. Limitations

- **Z01-local substitution.** Z01 applied verbatim refuses on the local chain, because its G3 finds 13 baseline-only indexes (seqs 404–416) absent, as KAN-781 measured. The test therefore extracts Z01's own `ALTER`/`DROP` statements in file order and runs them under Z01's G1 authorisation value. It skips the 13 baseline-only statements and holds the 3 HARD ones (704/722/723, G6 `v_meetup_list`), which is exactly what Z01's gate would decide.
  - The result is 117 statements run, 13 skipped and 3 held.
  - The restore of those 13 baseline-only indexes and of production's real index set is therefore **unexercised**.
- **The publication is a local stand-in** for `supabase_realtime`, as in D08. The production publication list must come from the production snapshot itself.
- **There is no real post-phase-4 write path** (D08 F1/F5). W2 and W3 are superuser writes into `events` (plus the retained `games` columns for W3), standing in for what a client write would produce once the KAN-714 parent reads land.
- **F3 is not fixed.** Restored columns go to the end of the attribute order. V1 compares by name, and the test reports 44 moved columns. Any `SELECT *` consumer that relies on column order would see a different order.
- **The data is local fixtures**, not production. The production visibility value sets and nullability are unverified (see section 8).
- **Snapshot size.** On production the full row copies duplicate `games`, `meetups` and `events` once. Disk space has not been measured.
- **One transaction.** The test runs snapshot, removal, writes and restore in one transaction. Production splits these into separate windows (section 3). The test cannot show lock contention from real concurrent writers. G1's `lock_timeout` and G4 are the safeguards for that.

## 8. Known conflicts touched (reported, not fixed)

These come from `KAN718_RUNBOOK.md`. The restore inherits them.

**These touch the rollback:**
- **`rsvp_policy` versus `join_policy`.** The restore takes `join_policy`. If a production value falls outside the `rsvp_policy` CHECK, R2.7 fails closed.
- **Visibility value sets** differ between legacy and `events`, and are unverified on production. A value outside a legacy CHECK fails closed at R2.7.
- **`title`/`capacity`/`end_at` nullability.** A NULL in `events` where legacy said NOT NULL fails closed at R2.6 `SET NOT NULL`.
- **`min/max skill` is integer versus smallint.** An out-of-range value fails the implicit cast at R2.5, which also fails closed.

**These do not touch the rollback, and are listed for completeness:**
- `min/max players` in rules;
- `meta.venue_space_id`;
- `owner_user_id` in `rpc_booking_hold_for_meetup`.

**New in Z02:** D08 R2.12 says "compat mirror back on", but Z01 seq 334 drops `trg_zz_kan712_events_compat_mirror`, and that trigger is not in the k774 manifest. The restore here recreates it from the snapshot. D08's runbook text is not edited; that is reported for D08's owner.
