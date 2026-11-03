# KAN-781 (KAN-719 Z04): post-removal checks

Probe: `supabase/tests/events_p4/kan719_z04_postcheck.sql`. It runs **after** phase-4 removal
(`supabase/migrations/20261105100000_kan719_z01_remove_replaced_columns.sql`, "Z01"). It runs only on local
or disposable databases, and the guard refuses a Supabase-shaped database or any DB not named `k781*`/`kan781*`.

## How it runs

1. **Capture, before Z01:** `psql ... -v capture=1 -f kan719_z04_postcheck.sql`. It writes schema `kan719_pre`,
   which holds full copies of games, meetups and events, the visible id set for each caller (owner, stranger,
   blocked user, anon, service_role), the realtime publication list and the `v_meetup_list` count. This is the
   local stand-in for the E10 backup (`KAN718_RUNBOOK.md` R2.0). Without it there is nothing to compare
   against, so the check refuses; it does not pass vacuously.
2. Apply Z01.
3. **Check, after Z01:** `psql ... -f kan719_z04_postcheck.sql`, run from the repository root, because it
   loads the D06 manifest from `kan718_d06_manifest_check.sql`. Everything runs inside `BEGIN ... ROLLBACK`.
   Section R then re-takes the catalogue and data md5 and requires it to match the value from before the run.
   The output is one line per check, then exactly one summary line: `KAN-781 POSTCHECK PASS ...`, or an
   exception `KAN-781 POSTCHECK FAIL: n failing check(s) in section(s) ...`.

Verdicts: **PASS**, **FAIL**, **HELD** and **ORPHAN**.
- **HELD** marks the three HARD homeless meetups columns, `description`, `location_name` and `is_indoor`
  (manifest 704/722/723). Z01 keeps them because of gate G6. They are reported and never counted as removed.
- **ORPHAN** marks a function that is not granted and not attached to a trigger. It is reported but does not
  fail the run.

## Sections

| Section | Covers |
|---|---|
| S0 | Every removed column (derived from the capture, the same way D06 derives its 600/700 entries) is gone. Games keeps exactly its 13 retained columns; meetups keeps its 6, plus the HELD columns |
| C1 | Per row: same id, `event_id = id`, exactly one events parent of the right type, and counts equal. No row is lost or doubled |
| C2 | Per field: for every removed column and every captured row, the captured value `IS NOT DISTINCT FROM` the events value. `rsvp_policy` is compared with `events.join_policy`, and the events value is cast to the captured type (smallint/integer skill). NULLs, ids and the original `created_at`/`updated_at` are covered. A removed column with no events home is a FAIL, because its data is lost |
| C3 | The retained subtype columns are byte-identical to the capture |
| M1 | KAN-773 D05 `kan718_games_compat` / `kan718_meetups_compat`: same legacy column names, order and types; one row per legacy row; each row equals the captured legacy row. A FAIL names the differing column |
| M2 | For each of 5 callers and 2 tables, the id set seen through the projection and through the table equals the capture |
| M3 | Write contract. An events UPDATE works (KAN-776 F1). `kan712_update_event_shared` (service_role) completes; a 55000 or schema-class error is a FAIL (KAN-776 F5) |
| M4 | `rpc_join_game` and `rpc_meetup_rsvp` as a member and as a stranger, `game_slots_left`, and the `v_meetup_list` count. 42703/42P01/42883/42702/55000 are FAILs; a business refusal is a PASS |
| M5 | Route ids: capture = table = `event_id` = projection |
| S1 | `pg_depend`: no view, rule, policy, index, constraint, default or publication depends on a non-retained column. Dependencies on HELD columns are reported as HELD |
| S2 | Textual scan of every public plpgsql/sql function. It flags a body that reads games/meetups through a name or alias and then names a removed column of that table (`alias.col`, `INSERT (... col ...)`, `UPDATE ... SET col =`). If the function is LIVE (granted to an API role, or attached to a trigger) that is a FAIL; if it is ORPHAN it is reported |
| S3 | Exact check: every SQL-language body is re-created from `pg_get_functiondef` with `check_function_bodies = on`. A 42703, or a 42P01 "missing FROM-clause entry" (a row-typed parameter), is a FAIL |
| S4 | Triggers left on games/meetups that read `NEW./OLD.<removed>`; policy expressions; column defaults |
| S5 | Shared facts live only in events: no subtype column duplicates an events column except `id`. The projections are not writable (`pg_relation_is_updatable = 0`, no INSTEAD OF trigger, no rule). Realtime lists `games{id}` and `meetups{id,vibe_key}` and still holds every table it held at capture (KAN-776 F2) |
| R | The catalogue and data md5 after ROLLBACK equals the md5 before the run |

## Clean proof

`/Users/moataz/.claude/jobs/dcb6a775/tmp/clean781.sh <sha>` builds the chain from `git archive` and seeds one
game and one meetup. It then:

- proves Z01 **as shipped refuses** here;
- runs the capture, Z01-local (Z01's own statements; see below) and the check;
- asserts the exact set of passing and failing sections;
- runs the negatives:
  - N1: with no Z01, S0 and S5 must fail;
  - N2: a missing events value must be caught by C2;
  - N3: a granted plpgsql function and an unchecked SQL function that read `g.title` must be caught by S2 and S3;
  - N4: visibility drift must be caught by M2;
  - N5: a check with no capture must refuse.

It prints `KAN-781 ALL PASS`.

## Results on the repo chain (alpha-luxor, HEAD 44514216 + this file)

**Z01 cannot be applied verbatim on this chain.** Its gate refuses on:
- G3: the 13 baseline-only indexes (manifest 404-416) do not exist locally;
- G6: `v_meetup_list` reads `description`, `location_name` and `is_indoor`.

That refusal is correct behaviour, and it is also what Z01's own test expects. The post-Z01 state below comes
from **Z01-local**: Z01's 117 local statements, extracted from the migration file in file order and run under
Z01's G1 authorisation, with the 13 baseline-only statements skipped and 704/722/723 held. It is authored and
run on a throwaway database only. **Nothing was applied anywhere else.**

**PASS**
- S0: 44 columns removed, 3 HELD.
- C1: none of 3020 games or 2021 meetups is lost or doubled.
- C2: every removed games column, and every removed meetups column except `search_tsv`.
- C3.
- M1 for games.
- M2: owner, stranger, blocked user and anon see the same ids as before; service_role sees all.
- M3 events UPDATE: `trg_zz_kan712_events_compat_mirror` is dropped by Z01 statement 334, so **F1 is handled**.
- M5.
- S1: the only dependencies left are on HELD columns.
- S5: realtime keeps both tables, with `games{id}` and `meetups{id,vibe_key}` through Z01's DROP/ADD
  publication pairs 201/202, so **F2 is handled**. The projections are read-only.
- R.

**FAIL (findings, not harness defects)**
- **C2 and M1, `meetups.search_tsv`:** 2010 of 2021 rows differ. The meetups vector is weighted over
  title (A), description (B) and location_name (C). `events.search_tsv` covers title only; the KAN-710 schema
  comment says "meetups.search_tsv stays authoritative for meetup". Dropping it loses description and
  location search. This is the same contract gap as the three homeless columns.
- **S2:** 21 API-executable functions still read removed columns. Examples:
  - `_can_view_game`, `_is_game_host`, `_user_hosted_game`
  - `game_slots_left`, `meetup_counts`, `active_stream`
  - `rpc_create_game*`, `rpc_create_meetup*`, `rpc_get_nearby_games`, `rpc_get_activity_feed`
  - `rpc_rate_*`, `rpc_unified_search_sectioned`, `rpc_challenge_spawn_game`, `_slot_conflicts_game`

  There are also 10 orphans, among them `kan712_events_compat_mirror()`: Z01 drops its trigger but leaves the
  function in place.
- **S3:** 8 SQL bodies no longer compile, for example `_can_view_game` and `kan711_events_map_game(games)`.
- **S4:** trigger `trg_meetups_aaa_host_actor_stub` reads `NEW.creator_profile_id`, so a meetups INSERT breaks.
- **M3:** `kan712_update_event_shared` fails with 55000 `kan712_not_cut_over`. There is no authorised write
  path (KAN-776 F5).
- **M4:** these fail with 42703:
  - `rpc_join_game` (member);
  - `rpc_meetup_rsvp` (member);
  - `game_slots_left`.

**Verdict:** removal is not safe on this chain. That agrees with `KAN718_DELETION_MANIFEST.md`, which says
"Deletion stays BLOCKED". The kan714 parent-reads (part 1 is untracked; part 2 aborts, KAN-792) are not on
the chain. **Unproven here:**
- a postcheck-wide PASS;
- the PASS branches of S2, S3, S4, M3 and the M4 member paths;
- Z01 applied verbatim.

## Known conflicts that touch these checks

These are reported here and not fixed by this work.

- **Visibility values.** C2 compares `listing_visibility` value for value, and it passes on this chain. Any
  value mapping applied later (for example to the events visibility vocabulary) would surface here as C2 drift.
- **join_policy vs rsvp_policy.** C2 maps `meetups.rsvp_policy` to `events.join_policy`. The vocabulary
  conflict between the two is not resolved, and C2 only proves the stored values are equal.
- **title, capacity and end_at nullability.** The seeded meetup has a NULL `end_at` and a NULL `capacity`, and
  C2's `IS DISTINCT FROM` covers the NULLs. The events check constraints (for example the meetup title length)
  decide what can be written, not this check.
- **min/max players in rules.** These live in `games.rules`, which is retained and covered by C3, so they are
  not part of C2.
- **meta.venue_space_id.** `meetups.meta` is retained and covered by C3; that value has no events column.
- **owner_user_id in `rpc_booking_hold_for_meetup`.** On this chain the function already takes the creator from
  `events.creator_user_id`; its own comment notes that the earlier version read `meetups.owner_user_id`, which
  does not exist. S2 does not flag it, because it reads no removed column through a games/meetups alias, and
  S2 checks only removed columns. Whether its owner semantics are right is outside these checks.
- **Timestamp prefix collision.** The untracked `20261105100000_kan714_events_parent_reads.sql` shares Z01's
  prefix `20261105100000`, so applying migrations by prefix order would be ambiguous. `git archive` excludes the
  untracked file, and clean781.sh refuses if the file appears in the archive.
