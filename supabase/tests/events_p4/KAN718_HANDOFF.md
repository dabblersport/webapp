# KAN-718 handoff: legacy column consumers and the deletion manifest, re-checked 2026-11-04

Author: backend-3 (Shed), team Karnak, branch `alpha-karnak` at `0de344be` (Alpha merged, "Already up to date").
Everything below was re-run on **local throwaway PG16 clusters only** (ports 55718 and 55719, sockets in /tmp).
No hosted database was read or written. Scripts and logs: `/Users/moataz/.claude/jobs/48b1590f/tmp/`.

**Headline.** Deletion (KAN-719 Z01) is still **BLOCKED**. Supported consumers still depend on slated columns:
the app's direct `games` reads in `lib/` and the D04 readers with no conversion. Old store builds blocked
deletion; that is **resolved by CTO ruling (C)** in dreq-8ae9bcfa (see (h)): the client-read `games` columns are
retained and their deletion is deferred to KAN-719b. The three meetups columns `v_meetup_list` and
`kan718_meetups_compat` read are now **retained** by the same ruling. KAN-718 is a blocked tracking parent.
**The D06 manifest, Z01 and G6 have NOT been re-scoped to the ruling yet** (F8).

## (a) D-series status

| D | Ticket | File(s) | Last commit | Re-run 2026-11-04 | Conclusion holds? |
|---|---|---|---|---|---|
| D01 | KAN-769 | `KAN718_D01_SQL_CONSUMERS.md`, `kan718_d01_sql_consumer_scan.sql` | `6c7fd2f7` | test mode **FAIL** on the k788 chain: the V2 anchor `rpc_get_nearby_games(…,numeric)` exists only on k788b (B04). With that one anchor removed: ALL PASS, V4 40/40 pending. Scan mode on k788full: 40/40 pending | Yes: 40/40 column pairs still pending |
| D02 | KAN-770 | `KAN718_D02_NON_SQL_CONSUMERS.md`, `kan718_d02_dynamic_and_functions_scan.sql` | `60ffc238` / `5abda4d2` | PASS (B1–B5) | Yes: still BLOCKED |
| D03 | KAN-771 | `KAN718_D03_OLD_CLIENT_MATRIX.md`, `kan718_d03_client_scan_test.dart` | `45b81991` | PASS, +7 | Yes: still BLOCKED. `git grep` finds 19 `.from(SupabaseConfig.gamesTable)` sites in 6 files, plus `rows('games')` in search. No `meetups` table read |
| D04 | KAN-772 | `KAN718_D04_DISPOSITION.md`, `d04_last_reads`, migration `20261104110100` | `0c0eb763` / `5abda4d2` | PASS 69/0 | Partly: the totals line is stale. Most BLOCKER write RPCs and triggers are now converted by follow-ups (see (b)) |
| D05 | KAN-773 | migration `20261104110200`, `kan718_d05_*` | `edeeb099` | PASS | Yes, with the limits in (c) |
| D06 | KAN-774 | `KAN718_DELETION_MANIFEST.md`, `kan718_d06_manifest_check.sql` | `ce6aec57` | PASS on its documented chain. **FAIL M2 on a chain that includes D05** (see (d)) | Exact only on a chain without D05 |
| D07 | KAN-775 | migration `20261104110300`, series-uniqueness probe | `00564a7c` | PASS 35/0 | Yes |
| D08 | KAN-776 | `KAN718_RUNBOOK.md`, `kan718_d08_rollback_probe.sql` | `32fdd2d3` | PASS. F3 still printed | Yes (see (e)) |
| D09 | KAN-777 | `KAN718_D09_PRECHECK.md`, parity precheck | `a03034a5` | PASS 0/0/0/0 | Yes |

### Follow-up probes

RED means the test was run on the pre-image and fails as intended. GREEN means it was run after the
migration and passes.

| Test | Migration | Result |
|---|---|---|
| kan798 | `110600_kan798` (`97369708`) | PASS 48/0 |
| kan799 | `110600_kan799` (`9a42c849`) | PASS (RED 42703 → GREEN) |
| kan800 | `110700_kan800` (`67201194`) | PASS |
| kan801 | `110600_kan801` (`83a2133a`) | **FAIL (env)**: no rebuildable chain has the single `rpc_meetup_set_attendee(uuid,uuid,text)` pre-image. Both clean801.sh and harness801.sh are lost |
| kan803 | `110800_kan803` (`8ca6d3d3`) | PASS |
| kan804 | `110900_kan804` (`ab0a4d44`) | PASS 9/0 |
| kan805 | harness stub proof and s4 | PASS |
| kan806 | `110700_kan806` (`3f112f9c`) | PASS 11/0 |
| kan807 | `110900`/`111000_kan807` (`97e5e6df`) | **FAIL (env)**: needs the lost `base781_with_d04.sh` chain. Failures seen: `st_makepoint(numeric,numeric)` and `active_stream(...)` absent |
| kan808 | `110700_kan808` (`872f00ad`) | PASS: RED rc=1, GREEN 8/0 |
| kan809 | `110800_kan809` (`61ebab0d`) | PASS: RED 15 FAIL, GREEN 23/0 |
| kan810 | `112000_kan810` (`61ebab0d`) | PASS: RED 3 FAIL (C1 [K]…), GREEN 19/0 |
| kan834 | `112100_kan834` (`67c75707`) | PASS: capture, then verify, 3792 cases identical |
| kan794 (KAN-823) | `20261105120000` (`1be647e4`) | PASS 34/0 |

## (b) Coverage: slated column × consumer class

Slated set: **44 columns (games 23, meetups 21). 22 retained**, per CTO ruling 2 in dreq-8ae9bcfa (was 47 slated,
19 retained). Moved from slated to retained: `meetups.description`, `meetups.location_name`, `meetups.is_indoor`.
D06 M1 in `kan718_d06_manifest_check.sql` still asserts the old 47 until F8 re-scopes it. Ruling 1 also retains
every `games` column D03 lists as client-read; that set is not yet subtracted from the games 23 here (F8).

| Consumer class | State | Pending consumers (owner) |
|---|---|---|
| SQL functions, direct | mostly **converted** by D04, 798–810, 834 and 794 (authored) | #5/#6 `get_nearby_games`, #8 `getnearbygames`, #9 `getnearbymeetups` (no ticket; named only as B05 exceptions X1–X4). #25 `rpc_meetup_visible` (**no ticket**). #11 `nearby_games`, #12 `rpc_autocomplete_entities`, #29 `rpc_search_entities` (rewritten in KAN-714 part 2 `20261105110000`, but its required part 1 `20261105100000_kan714_events_parent_reads.sql` is **absent on this branch**. That slot holds Z01) |
| Transitive helpers / %ROWTYPE / composite | pending **by design** | `kan711_events_map_game(games)` and the KAN-711/712 mirror and guard read the `games` row type. Z01 removes them in the same transaction (seq 334 drops `trg_zz_kan712_events_compat_mirror`) |
| Dynamic SQL | D02: 1 function. Still BLOCKED | per D02 |
| Views | **resolved by ruling 2, not yet in the manifest** | `v_meetup_list` and `kan718_meetups_compat` read `meetups.description`, `location_name` and `is_indoor`. These are now **retained subtype columns** (dreq-8ae9bcfa ruling 2); both views are unchanged. Clears D06 M2 and Z01 G6 for this cause once F8 re-scopes the manifest (704/722/723) and G6 |
| Compat projection | `kan718_games_compat` reads only retained `games` columns plus `event_id` | none |
| Policies | `games` has RLS on and no policy (KAN-671) | per D02 (4 policies) |
| Triggers | 803/804 converted the frozen guards and posts geo. The KAN-711/712/713 infra is removed with Z01 | none outside Z01 |
| Indexes | 13 baseline-only indexes are absent locally (Z01 G3 cannot be proven locally) | not documented locally |
| RETIRE | #20 `rpc_meetup_invite_user`, #21 `rpc_meetup_mint_link` (KAN-802/812) | **no DROP authored** |
| Edge Functions | `supabase/functions/*` contains no reference to `games`, `meetups` or slated column names (`git grep`) | none |
| Scripts | no tracked `scripts/` reference | none |
| `lib/` direct reads | **still-pending**, columns **retained** by ruling (C): 19 `.from(gamesTable)` sites (games datasource ×13, post repo, sport profile, data export ×2, data retention) | F10 (frontend conversion); column drop F11 (KAN-719b) |

## (c) Old clients

D03 verdict: old store builds 1.3.0–1.7.8 and web main/Canary/Alpha BREAK on a games column drop, so they
**blocked deletion → resolved by (C): client-read games columns retained; deletion deferred to KAN-719b**
(dreq-8ae9bcfa ruling 1). Options (A) rename-swap compat view and (B) `app_min_version` floor were rejected. The
points below are kept for the record; under (C) they no longer gate KAN-719.

D05 serves them only if `games` is renamed to `games_subtype` and the view is renamed to `games`. That swap
exists only as header text in `20261104110200`. Z01 drops the columns directly and does no swap. Three
further points:

- PostgREST embedding through a view and realtime on a view are **not demonstrated**.
- `schema_meta.app_min_version` is not enforced.
- Installed-build counts are **not documented**.

## (d) Manifest

- **On the documented D06 chain** (k788 + KAN-716 + D07 + KAN-785), the manifest is **exact**. Counts are
  unchanged from 2026-11-03: 130 statements (117 local, 13 baseline-only), 33 triggers, and 20 entries with
  no replacement.
- **Delta found today:** on a chain that also has **D05** (`20261104110200`), `kan718_d06_manifest_check.sql`
  fails with `M2 FAIL: column-level dependent(s) with no manifest entry: view:kan718_meetups_compat`. Chain:
  `k788full` = build_kan810 + 806/808/809/807b/810/834.
  - The manifest has no statement for the compat view that reads the three homeless columns.
  - Z01 G6 already refuses on it.
  - It is part of the same homeless-column gap, not a new consumer class. Ruling 2 retains those columns; the
    manifest is **not yet re-scoped** (F8).
- D07 series uniqueness: PASS 35/0, so the manifest's series index assumptions hold.

## (e) Runbook (D08)

| Item | State |
|---|---|
| Sync-disable (R0) | Probe PASS. P7 closes the ops path with 55000 |
| Rollback (R1/R2) | Probe PASS. R2 rebuilt 44 columns and 33 triggers |
| Restore source (R3) | As written: a backup alone is not lossless. Unchanged |
| Write-loss guard (G1–G5) | As written. Unchanged |
| F1 (mirror trigger missing from the manifest) | **Resolved in authored Z01** (seq 334). Not applied |
| F2 (SET TABLE replaces the whole publication list) | **Open, mitigated**: R2.11 uses the full captured list |
| F3 (restored columns go to the end) | **Open, accepted**: printed 44/44. Named access only |
| F4 (`tgenabled` not in triggerdef) | **Open, mitigated**: R2.9 restores state |
| F5 (no write path after phase 4) | **Resolved in authored** `110700_kan806` (test PASS) |
| Z04 FAILs (meetups.search_tsv, S2, S3, M3, M4; KAN719_COMPLETION_REPORT.md:159) | **Open**. Not re-run today, because the Z01 gate refuses before Z04 can run |

## (f) Applied vs authored

**Applied to production** (per the Alpha records):

- `20261102120000_kan711_events_backfill` (KAN-842 step 5, `e2e38103`)
- `20261103100000_kan712_events_write_contract` (KAN-843 step 6, `8055ef5d`)
- step 6b `kan711_events_validate_links()` (KAN-844, `afcc1f28`)
- `20261103105000_kan844_kan712_contract_flag_set_config` (step 6c, `1573b09a`)
- `20261103104000_kan851_capture_run_seed_meetup_template` and `20261103110000_kan712_cutover` (step 7, `b7351531`/`523c389a`)

**Authored, NOT applied (every KAN-718 migration):**

- `20261104110100` D04, `110200` D05, `110300` D07, `110400` KAN-785, `110500` KAN-786
- `110600` kan798/799/801, `110700` kan800/806/808, `110800` kan803/809
- `110900` kan804/kan807a, `111000` kan807b, `112000` kan810, `112100` kan834
- `20261105100000` Z01, `20261105100100` Z05, `20261105110000` KAN-714 part 2, `20261105120000` kan794

## (g) Limitations and the prerequisites still open before KAN-719's destructive step

Limitations:

- No single local chain holds every follow-up. On k788full, the pre-image guards of 798, 799, 800, 801, 803, 804
  and 807a refuse because the harness bodies differ from the production pre-images. Each migration is proven on
  its own chain only. A full pre-Z01 catalogue (and therefore a whole-chain D01/D06/Z01 dry run) is **not
  demonstrated**.
- ~~801 and 807 could not be re-run (the chains are lost).~~ **Resolved by KAN-860 (F7), 2026-11-04**: both
  chains are now tracked and both tests were re-run green, each on a brand new throwaway PG16 cluster (ports
  54861/54862, socket /tmp), clusters deleted afterwards:
  - `base781_with_d04.sh`: the KAN-781 judge chain + D04, ported from the judge's untracked copy (Thebes review
    evidence `KAN-781/judge-04740e4f/base781_with_d04.sh`, = `KAN-807/judge-97e5e6df/base.sh`). Same steps and
    order; adds 851 capture + 6c before the cutover, and a marked stand-in giving the harness
    `game_rating_aggregate.composite_score` its baseline type `numeric(3,2)` so B03's KAN-853 pin (92d98259) holds.
  - `build_kan807.sh` → `kan807_d04_residual_test.sql` on `k807t`: `T2 PASS (RED shown)`, `T4/T5 PASS (GREEN): all
    32 cases ... identical ... before and after Z01`, `T6 PASS: 16 functions ... unchanged`, `KAN-807: ALL PASS`
    (the same verdict lines as the judged run).
  - `build_kan801.sh` → base781+D04, D05, a seed replacing the lost seed781.sql, and the lost harness801 pre-images
    cut verbatim from the baseline (`rpc_meetup_set_attendee` md5 `118f1db9`, matching the judged log;
    `meetup_attendees_pkey`; `_meetup_link_consume`). RED on the pre-image: `TOTAL pass=17 fail=8`
    (S1,S2,A1–A6; A1 `42703 column m.owner_user_id does not exist`), identical to the judged log. GREEN after
    `110600_kan801`: `KAN-801 TOTAL pass=25 fail=0`. The judged post-Z01 variant (`Z01-local`, lost
    `z01_local.sql`) is **not** reproduced.
- The 13 baseline-only indexes (Z01 G3) cannot be checked locally.

Prerequisites (each now maps to a follow-up in (h); none is a ticket yet):

1. Homeless meetups columns: **resolved** by ruling 2 (retained). Re-scoping the manifest, Z01 and G6 to it is
   **F8**, not done.
2. Convert or retire `get_nearby_games` ×2 (**F1**), `getnearbygames` (**F2**), `getnearbymeetups` (**F3**) and
   `rpc_meetup_visible` (**F4**, PEER).
3. KAN-714 part 1 (`…_kan714_events_parent_reads.sql`) is missing on this branch; its slot is occupied by Z01.
   Re-author it in a non-colliding version slot: **F5**.
4. DROP for RETIRE #20 `rpc_meetup_invite_user` / #21 `rpc_meetup_mint_link` (KAN-802/812): **F6**.
5. Client: old-store-build policy **resolved by (C)**. Converting the 19 `lib/` `games` reads is **F10**; dropping
   the client-read columns is **F11** (KAN-719b), after F10 ships and an install-share check.
6. Re-scope Z01, the D06 manifest and G6 to rulings 1 and 2: **F8** (blocked by F1–F6).
7. Apply the authored KAN-718 migrations to production under G-002, then re-run D06/D09/Z01 G1–G6 against that
   catalogue and clear the Z04 FAILs: **F9** (PEER, blocked by F5–F8).
8. Re-establish the 801 and 807 chains, or re-prove both on a new tracked builder, before they count as green:
   **F7**. **Done (KAN-860)** pre-Z01 for 801 and in full for 807, see the limitation above.

## (h) CTO ruling dreq-8ae9bcfa (2026-11-04)

Ruled by cto (Khnum) on decision `dreq-8ae9bcfa-e8bd-46d4-903a-c3b840ab79ec`.

1. **Old clients: option (C).** Keep every legacy `games` shared column a supported client reads (D03's 19 `lib/`
   reads). They stay until those reads are converted and shipped to the store, and builds 1.3.0–1.7.8 no longer
   have meaningful installs. (A) rename-swap compat view and (B) `app_min_version` floor were rejected; (B) would
   need CPO + CEO product agreement. Z01 is re-scoped to drop nothing in `games` that D03 lists as client-read.
   Deleting those columns becomes a later ticket, KAN-719b.
2. **`meetups.description`, `location_name`, `is_indoor` are RETAINED subtype columns.** Slated 47 → 44,
   retained 19 → 22. `v_meetup_list` and `kan718_meetups_compat` are unchanged. This clears D06 M2 and Z01 G6
   for this cause once the manifest is re-scoped.
3. **KAN-718 disposition:** blocked tracking parent. Blocked reason: "deletion gated on §4 follow-ups and the
   ruling (C) in dreq-8ae9bcfa". `f2485ae5` is kept.

**Not yet done:** the D06 manifest, Z01 and G6 have **NOT** been re-scoped to rulings 1 and 2. That is F8.

Follow-ups for the PM (the CTO creates none; these are not tickets yet):

| # | Ticket | Capability | Blocked by |
|---|---|---|---|
| F1 | Convert or retire `get_nearby_games` ×2 | backend | none |
| F2 | Convert or retire `getnearbygames` | backend | none |
| F3 | Convert or retire `getnearbymeetups` | backend | none |
| F4 | Convert `rpc_meetup_visible` (PEER) | backend | none |
| F5 | Re-author KAN-714 part 1 in a non-colliding version slot | backend | none |
| F6 | DROP `rpc_meetup_invite_user` / `rpc_meetup_mint_link` | backend | none |
| F7 | Track the kan801/kan807 chain builders | backend | none |
| F8 | Re-scope Z01 + D06 manifest + G6 to rulings 1 and 2 | backend | F1–F6 |
| F9 | Ops-apply under G-002 (PEER) | backend | F5–F8 |
| F10 | Convert the 19 `lib/` `games` reads | frontend | none |
| F11 | KAN-719b: drop the client-read `games` columns | backend | F10 shipped + install-share check |
