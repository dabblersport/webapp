# KAN-718 D08 (KAN-776): rollback, temporary sync disable, and write-loss guard

**Status: authored, NOT applied to any Supabase project.** Every step below was exercised only on local
throwaway PG16 databases (`k776*`) by `kan718_d08_rollback_probe.sql`. The probe runs in one transaction and
always ends in `ROLLBACK`. This runbook is not a migration and it authorises nothing. A production run still
needs `G-002`'s apply conditions, and the CEO for anything destructive.

**Scope.** This runbook covers the KAN-718 events migration:

- the KAN-711 legacy→events mirrors;
- the KAN-712 cutover, which adds the events→legacy compat mirror and the ops write path;
- the phase-4 column deletion listed in `KAN718_DELETION_MANIFEST.md` (KAN-774, 130 entries).

**It uses the KAN-774 manifest verbatim and keeps no copy of its own.** The probe loads the manifest's temp
tables from `kan718_d06_manifest_check.sql`. `clean776.sh` then checks that those 130 `(seq, statement)` pairs
equal the `.md` table row for row.

**Probe:** `supabase/tests/events_p4/kan718_d08_rollback_probe.sql`. Its step labels P0–P12 and the runbook's
R/G labels below point at each other.

---

## Which section applies

| Situation | Section |
|---|---|
| Sync is suspect (parity ≠ 0), or you must pause the events→legacy mirror for a maintenance step | **R0** |
| Cutover (KAN-712) applied, phase 4 NOT applied, and you want phase-1 behaviour back | **R1** |
| Phase 4 applied (columns dropped), and you want the legacy columns back | **R2**, after reading **R3** |
| You are about to run phase 4 | **G1–G5** guard. Do not start without it |

---

## R0 — temporary sync disable, and resync

The compat mirror `trg_zz_kan712_events_compat_mirror` (AFTER UPDATE on `public.events`) copies shared fields
from events to legacy.

**The mirror only writes when a value IS DISTINCT.** So once the mirror is back on, a no-op events UPDATE
resynchronises the row.

**R0.1 Disable the mirror** (one statement; takes a short `SHARE ROW EXCLUSIVE` on events):

```sql
ALTER TABLE public.events DISABLE TRIGGER trg_zz_kan712_events_compat_mirror;
```

**Effects of the disable, observed in the probe (P4):**

- The ops path `kan712_update_event_shared(uuid, jsonb)` fails closed: SQLSTATE `55000`,
  `kan712_not_cut_over`. Ops writes stop on their own, which is the intended behaviour.
- A direct events write while the mirror is off produces divergence. `kan711_events_parity` shows exactly
  those rows: one in the probe.

**R0.2 While it is off,** watch for divergence:

```sql
SELECT kind, id, mismatched_fields FROM public.kan711_events_parity;
```

**R0.3 Re-enable it, then resync each diverged row.** The KAN-711 keeper trigger
`trg_kan711_events_keep_updated_at` pins `events.updated_at` to `kan711.src_updated_at`, so the resync stamps
no new timestamp:

```sql
BEGIN;
SET LOCAL lock_timeout = '10s';
ALTER TABLE public.events ENABLE TRIGGER trg_zz_kan712_events_compat_mirror;
LOCK TABLE public.events, public.games, public.meetups IN SHARE ROW EXCLUSIVE MODE;
-- for each row of kan711_events_parity that is not missing_event / orphan_event / unlinked:
SELECT set_config('kan711.src_updated_at', e.updated_at::text, true) FROM public.events e WHERE e.id = :id;
UPDATE public.events SET updated_at = updated_at WHERE id = :id;
-- ...
SELECT set_config('kan711.src_updated_at', '', true);
SELECT count(*) FROM public.kan711_events_parity;   -- must be 0, else ROLLBACK
COMMIT;
```

The probe's `pg_temp.k776_r0_resync()` is this loop. P4 proves that events wins: legacy receives the events
value AND the events `updated_at`.

**A mutation that drops the keeper pin makes P4 fail** (`clean776.sh` MUTATION mut3).

**Not covered by R0:**

- `missing_event`, `orphan_event` and `unlinked` rows are not repaired by a no-op UPDATE. They mean the
  link itself is broken. Stop and escalate; do not hand-insert.
- Direction: R0 makes legacy equal events. If legacy holds the correct value, that is a different repair
  (KAN-711 direction) and it is not authored here.

---

## R1 — roll back the cutover (phase 4 not applied)

Use the existing, tested script `supabase/tests/events_p2/rollback_kan712.sql` (KAN-712). It is lossless and
changes no row:

- it restores the KAN-711 mirrors and the original RPCs under their original owner and ACL;
- it asserts parity 0, and identical md5s before and after, under lock.

**KAN-776 adds nothing to R1 except one precondition: run R0.2 first.** If parity ≠ 0, run R0.3. The script
refuses on parity ≠ 0 by itself.

---

## R2 — roll back phase 4 (the columns are gone)

### R2.0 Preconditions

- **The phase-4 capture exists.** Before phase 4 ran, the shape of every manifest object was captured, by
  name, with fully qualified definitions (`search_path = ''`). This is probe P5, `pg_temp.k776_shape()`:
  - **columns:** type, NOT NULL, default, comment, column ACL and attnum;
  - **triggers:** `pg_get_triggerdef` **plus `tgenabled`**;
  - **constraints:** `pg_get_constraintdef`;
  - **indexes:** `pg_get_indexdef`;
  - **policies:** USING, WITH CHECK, cmd, roles and permissive;
  - **publication:** the full `supabase_realtime` table list, with column lists.

  **Without that capture there is no R2. A backup is not a substitute** (see R3).
- **Use one transaction:** `SET LOCAL lock_timeout = '10s'` and **`SET CONSTRAINTS ALL IMMEDIATE`**. The KAN-710
  link-check constraint triggers are deferrable. With deferred events pending, `ALTER TABLE` fails with
  `cannot ALTER TABLE "events" because it has pending trigger events`.
- **Disable the compat mirror for the duration** (see finding F1).

### R2 steps (probe P9; each step carries the same label in the probe)

| Step | Action |
|---|---|
| R2.1 | `LOCK TABLE public.events, public.games, public.meetups IN SHARE ROW EXCLUSIVE MODE` |
| R2.2 | **Source completeness.** Every games/meetups row has an events parent of its own type with `event_id = id`, and no events row is orphaned. Any count > 0 → abort: the restore source is incomplete |
| R2.3 | `ADD COLUMN` each captured column, nullable, in captured attnum order |
| R2.4 | Recreate the two `search_tsv` triggers (`trg_games_search_tsv`, `trg_meetups_search_tsv`) and set them `ENABLE ALWAYS` |
| R2.5 | Under `session_replication_role = replica`: `UPDATE t SET (cols) = ROW(e.cols) FROM public.events e WHERE e.id = t.event_id` for games, then meetups. `rsvp_policy ← e.join_policy`; `search_tsv` is excluded, because its ALWAYS trigger recomputes it. Replica mode means no other trigger fires, so `updated_at` and every other value is the events value, not a new stamp. Abort if any dropped column has no events source column |
| R2.6 | `session_replication_role = origin`; `search_tsv` triggers back to `ENABLE`. Then restore defaults, `SET NOT NULL` (fails closed if events holds a NULL) and comments. **Abort if a column had a column-level ACL** — none exist locally; restore it by hand |
| R2.7 | `ADD CONSTRAINT` from the capture. CHECKs are validated, so they fail closed on bad data |
| R2.8 | Recreate indexes from the capture |
| R2.9 | Recreate triggers, **then restore `tgenabled`**: `D` → `DISABLE`, `A` → `ENABLE ALWAYS`, `R` → `ENABLE REPLICA`. `pg_get_triggerdef` does not carry the enabled state (F4); `clean776.sh` mut2 proves that skipping this step is caught |
| R2.10 | `ALTER POLICY ... USING (...) WITH CHECK (...)` back to the captured expressions |
| R2.11 | `ALTER PUBLICATION supabase_realtime SET TABLE` with the **full captured list** (F2) |
| R2.12 | Re-enable `trg_zz_kan712_events_compat_mirror` |

### Verify, all inside the same transaction, before COMMIT (probe P10)

- **V1** — the shape of every manifest object `EXCEPT`s to empty against the capture, both ways. Column
  *order* is reported separately (F3).
- **V2** — `kan711_events_parity` = 0.
- **V3** — counts: games + meetups = events, and no doubled id.
- **V4** — every legacy row that had no post-phase-4 write equals its pre-phase-4 jsonb exactly (5040 of 5041
  in the probe; the 5041st is the row written after phase 4).
- **V5** — every post-phase-4 write survived: W2's new title, `updated_at` and `search_tsv`; W3's brand-new
  row, with its original `created_at`, its NULLs and its id; W1+R0's values and timestamps; and
  `rsvp_policy = join_policy`.
- **V6** — a stranger and a blocked user see exactly the counts they saw before phase 4.

**Any failure → ROLLBACK.**

---

## R3 — the restore source (why a backup alone is not lossless)

**The complete restore source for a rolled-back phase 4 is `public.events` plus the surviving games/meetups
rows.**

- Every value in every dropped column (601–623, 701–724 minus the hard-blocked three) also lives in an events
  column of the same name. The one exception is `rsvp_policy`, which lives in `join_policy`. R2.2 and R2.5
  check this.
- After phase 4, **events is the only place post-cutover writes go.** Any restore from a pre-phase-4 backup
  rewinds them.

**NEGATIVE 1 (probe P8)** shows this exactly. A restore of the dropped columns from the backup taken at P2:

- loses W1 (an ops-path write made before phase 4 but after the backup), W1's capacity 12, R0's meetup title
  and W2;
- returns `updated_at` to the backup instant;
- leaves W3 (a game created after phase 4) with every restored column NULL, because the backup has no row
  for it;
- a full-dump restore would drop W3 entirely.

**What the backup is still for:**

- **A forensic diff.** List post-backup writes as `events.updated_at > :backup_ts`, plus events ids absent from
  the backup (G5).
- **The three hard-blocked columns (704 `meetups.description`, 722 `location_name`, 723 `is_indoor`).** They
  have NO HOME in events. The manifest refuses them (KAN-774 D1: refused, never dropped), so R2 never needs
  them. If they are ever dropped in future, the backup becomes their only source. That would be a separate
  decision, and it would need its own rollback.

---

## G1–G5 — write-loss guard for the phase-4 deletion

**Run phase 4 as ONE transaction, inside the guard. Never COMMIT past a failed check.** In the probe these are
P6, plus `pg_temp.k776_phase4_preflight` / `k776_assert_fp`.

| | Guard | How | Fires as |
|---|---|---|---|
| **G1** | Freeze writers | `LOCK TABLE public.events, public.games, public.meetups IN SHARE ROW EXCLUSIVE MODE` with `lock_timeout = '10s'`. Blocks every INSERT/UPDATE/DELETE from other sessions until COMMIT/ROLLBACK; reads continue | `clean776.sh` NEG2c: a second session's UPDATE gets `55P03 lock timeout` while the lock is held, and succeeds once it is released |
| **G2** | Refuse on divergence | `kan711_events_parity` must be empty | `k776_legacy_events_diverged` (P0001), HINT "run R0". NEG2b: events capacity changed with the mirror off → the preflight refuses |
| **G3** | Before-fingerprint | count + md5 of every events row (full jsonb) and of every games/meetups row **minus the to-be-dropped columns**, taken after G1/G2 | — |
| **G4** | After-fingerprint | the same fingerprint after the last manifest statement, before COMMIT; it must equal G3 | `k776_write_landed_mid_surgery` (P0001), HINT "ROLLBACK, never COMMIT". NEG2a: an events write inside the surgery window is caught |
| **G5** | Record the restore point | save `now()` as `backup_ts` and the G3 fingerprint next to the phase-4 capture. They are the input to R3's forensic diff | — |

**Inside the transaction, between G3 and G4:**

- disable the compat mirror (F1);
- run the manifest in `seq` order exactly as KAN-774 D1 does: hard-blocked entries refused, baseline-only
  entries skipped where the object is absent.

---

## Manifest coverage (KAN-774 `KAN718_DELETION_MANIFEST.md`, 130 entries)

| seq | kind | rollback step | exercised locally |
|---|---|---|---|
| 101–104 | policy (4) | R2.10 ALTER POLICY to captured USING/WITH CHECK | yes, 4/4 |
| 201–202 | publication (2) | R2.11 SET TABLE with the full captured list | yes, a stand-in `supabase_realtime` plus a scratch table (F2) |
| 301–333 | trigger (33) | R2.4 (`search_tsv`, 2) + R2.9 (31) with `tgenabled` | yes, 33/33, including the 8 disabled |
| 401–403 | index (3) | R2.8 | yes, 3/3 |
| 404–416 | index (13), baseline-only | R2.8 (captured if present) | **no**: absent from the local chain (local = false in the manifest); the step is generic but unexercised |
| 501–528 | constraint (28) | R2.7 | yes, 28/28, validated |
| 601–623 | games column (23) | R2.3/R2.5/R2.6 | yes |
| 701–724 minus 704/722/723 | meetups column (21) | R2.3/R2.5/R2.6 (`rsvp_policy ← join_policy`) | yes |
| 704, 722, 723 | meetups column, hard-blocked | not dropped (refused), so no rollback needed; see R3 | refusal exercised (P6: 3 refused) |

Probe totals: P6 114 ran / 3 refused / 13 skipped; P9 44 columns, 28 constraints, 3 indexes, 33 triggers,
4 policies.

---

## Findings (reported, not fixed: KAN-774 and the migrations are not edited by this ticket)

- **F1 — manifest gap: `trg_zz_kan712_events_compat_mirror` is not in the manifest.** Once the columns are
  gone, every `UPDATE public.events` fails with `42703 column g.creator_profile_id does not exist` while the
  mirror is enabled (P7). The phase-4 migration must disable or drop it in the same transaction. If it does
  not, phase 4 turns every event edit into an error.
- **F2 — 201/202 `SET TABLE` replaces the whole `supabase_realtime` list.** In the probe, a scratch table
  added to the publication was removed by 201/202 (P6: "after 202 supabase_realtime holds only meetups").
  On production this would silently drop every other realtime table. The statements should be
  `DROP TABLE` + `ADD TABLE ... (cols)` per table, or `SET TABLE` with the full list. R2.11 restores the full
  captured list.
- **F3 — restored columns land at the end of the attribute order.** 44 of 44 columns moved. Named access
  is unaffected, and V1 compares by name. Anything positional is affected: `SELECT *` into a fixed record,
  `COPY` without a column list, `INSERT ... VALUES` without columns, and `t::text` hashes. Not reversible
  without a table rewrite.
- **F4 — trigger enabled state is not in `pg_get_triggerdef`.** Eight manifest triggers are disabled. A
  naive recreate would re-enable `trg_game_created`, the `inherit_geo` triggers and the `sync_joining_rule`
  triggers, plus the kan711 mirrors. R2.9 restores the state; mut2 proves it is checked.
- **F5 — no authorised write path exists after phase 4.** `kan712_update_event_shared` fails `55000`. W2
  and W3 in the probe are superuser stand-ins for "the post-phase-4 write path", which is not yet authored.
  R2 does not depend on how the write was made, only on where it landed (events).

## Known conflicts that touch rollback

- **`rsvp_policy` vs `join_policy`.** R2.5 maps the value back, and R2.7 re-adds `meetups_rsvp_policy_check`
  validated. If events ever holds a `join_policy` value outside the legacy set, the rollback fails closed
  at R2.7. That is correct behaviour, but it would need a value decision before rollback could finish.
- **Visibility value sets.** These are equal locally. **On production they are unverified.** A legacy CHECK
  re-added at R2.7 fails closed if events holds a value the legacy constraint rejects.
- **`title`/`capacity`/`end_at` nullability.** R2.6 `SET NOT NULL` fails closed if events holds a NULL
  where legacy required a value. Locally the per-type events checks prevent this; production data is
  unverified.
- **min/max skill: integer (events) vs smallint (legacy).** This is an implicit assignment cast. An out-of-range
  value fails R2.5 closed.

**Conflicts that do NOT touch rollback:** min/max players in rules, `meta.venue_space_id`, and
`owner_user_id` in `rpc_booking_hold_for_meetup`. These sit in surviving columns and functions that phase 4
does not drop, so R2 neither restores nor reads them.

## Limitations

- **The KAN-792 migration `20261105110000` is not in the chain.** It depends on the untracked part 1
  (`20261105100000`). Its effect on R2 is not documented.
- **The 13 baseline-only indexes (404–416) are absent locally, so their rebuild is unexercised.**
- **The publication is a local stand-in.** The production publication's member list is not known here.
- **The G4 mid-surgery write is simulated in one session.** The cross-session freeze (G1) is proven
  separately in `clean776.sh`.
- **There is no post-phase-4 write path yet (F5).** W2/W3 are superuser writes.
- **Production data checks are not run:** value sets, NULLs and skill ranges. Every one of them fails
  closed, but a closed failure still leaves the rollback unfinished.
- **Statistics are not restored.** Run `ANALYZE games, meetups` after R2. No column comments exist locally,
  so the comment restore step is unexercised.

## How to run the proof (local throwaway only)

```bash
bash /Users/moataz/.claude/jobs/dcb6a775/tmp/clean776.sh <sha>   # prints exactly "KAN-776 ALL PASS", exit 0
```

**What `clean776.sh` does, step by step:**

1. Builds `k776full` from `git archive <sha>` on the local PG16 cluster (port 55437).
2. Checks the manifest against the `.md`.
3. Runs KAN-774 D06 on a copy, and runs the probe.
4. Checks an external catalogue+data fingerprint before and after the probe.
5. Runs the two-session lock test.
6. Runs three mutations of the probe, each of which must make the probe FAIL.
