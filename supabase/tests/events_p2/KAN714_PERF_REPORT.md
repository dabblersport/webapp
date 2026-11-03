# KAN-735 (KAN-714 B16) — performance, N+1, duplicates and pagination on the events-backed listings

Test: `supabase/tests/events_p2/kan714_b16_perf_pagination.sql`. **Local throwaway Postgres 16 only.** Production and the
Supabase project were not queried. No migration belongs to this ticket, and nothing was applied anywhere except the local
cluster.

## Baseline

The ticket says to compare against "the E1 baseline". **There is no E1 performance artifact in the repository.** The only "E1"
is `KAN714_CONTRACT.md` exception E1 (`rpc_meetup_my`), which is unrelated. So the baseline is defined here as the
**pre-image**: the database the existing harness chain builds *before* B01/B02/B04/B05. Its sources are:

| Surface | Pre-image source |
|---|---|
| `v_game_card`, `v_my_games`, `v_meetup_list`, `v_meetup_counts`, `rpc_games_following_joined` | `tests/events_p2_kan714/local_harness_kan714.sql`. `rpc_games_following_joined` has md5 `d3b31f55…`, the body B04 pins |
| `rpc_unified_search_sectioned` | `tests/events_p2/local_harness_kan724.sql` (md5 `fe338219…`) |
| `rpc_get_nearby_games` (6 args) | Created by the test's `mode=before`, **verbatim** from `20261008140000:360-442` plus its `:444` grant. Asserted to be md5 `e14430ba…`, the body B04 pins |

## Method

1. **Build the chain:** `clean735.sh <sha>` builds a fresh database from `git archive <sha>`. The chain is the
   KAN-711/712/713/714/724 harnesses, plus the events parent, backfill, KAN-712 cutover, KAN-713 helpers and KAN-718.
2. **Capture the baseline:** `psql -v mode=before -f kan714_b16_perf_pagination.sql` runs on that pre-image and commits
   three things:
   - local stand-ins for the nearby RPC: a `geography` domain over the harness `geometry` composite, plus
     `st_makepoint`/`st_setsrid`/`st_distance` (haversine)/`st_dwithin`;
   - the KAN-735 fixture: 8 games and 8 meetups that share one `start_at`, with mixed visibility and one cancelled of each
     type, plus one upcoming "prov" game and one "prov" meetup;
   - the baseline tables `kan735_baseline`, `kan735_perf` and `kan735_preimage`.
3. **Apply the four migrations:** B01 `20261104100100`, B02 `20261104100200`, B04 `20261104100400` and B05
   `20261104100500`.
4. **Run the test:** the default mode is one transaction that is rolled back. It runs T0, A, B, C, D, E, F/H, P and P2, and
   ends with `KAN-735 ALL PASS`.
5. **Timing:** each measured query gets one warm-up and then 7 runs of `EXPLAIN (ANALYZE, BUFFERS)`. The median execution
   time is reported. Runs are as `postgres`, which owns and is definer of every surface, with
   `request.jwt.claim.sub` = a2, a follower.
6. **Plans of function bodies:** a `SECURITY DEFINER` function shows only a `Function Scan`. To see the body's plan, the
   test builds an inlinable `pg_temp` copy of the current `prosrc` (`*_body`); H asserts that the copy was inlined. For
   unified search, the games and meetups section SELECTs are extracted from the current `prosrc`, with `v_tsquery` and
   `p_limit_per_section` substituted. `*_call` is the real RPC call as the app makes it.
7. **N+1 detection:** a recursive walk of the plan JSON. `public.events` must never sit under a SubPlan or InitPlan, and the
   after-plan must not add SubPlans. Two negative probes show the detectors can fail: B-neg is a doubling join, and H-neg is
   a correlated `events` lookup with SubPlan loops=3019.

## Dataset (local synthetic, not production; milliseconds are indicative only)

- **Events:** 5,039 rows — 3,019 games and 2,020 meetups. Most come from the KAN-714 harness bulk seed plus the KAN-711
  seed; 18 rows are the KAN-735 fixture.
- **Equal `start_at`:** 608 distinct `start_at` values are shared by more than one event. The harness steps time by
  i/5 hours, which makes groups of 5, and the fixture adds 8 games and 8 meetups at `2031-06-01 10:00+00`.
- **Viewers:** anon; a stranger; host a1, who blocks a6; follower a2; harness admin a3; and the blocked user a6.
- **Shared buffers:** all reads were shared-buffer hits (`shared_read` = 0). These are warm-cache numbers.

## Results per surface

Timings are medians from the clean run. A second run on the same build moved individual medians by up to about ±25%,
which is the noise floor here.

| Query | Before (ms) | After (ms) | SubPlans before→after | How events is read after | Verdict |
|---|---|---|---|---|---|
| `v_game_card` page (`NOT is_cancelled ORDER BY start_at, id LIMIT 50`) | 50.1 | 39.7 | 9→9 | Seq Scan → Hash join, 1 loop | No N+1; on par |
| `v_game_card` full | 57.8 | 58.7 | 9→9 | Seq Scan → Hash join, 1 loop | No N+1; on par |
| `v_meetup_list` page (app shape: `ORDER BY start_at LIMIT 20 OFFSET 0`) | 48.9 | 54.5 | 5→5 | Bitmap Heap Scan → Hash join, 1 loop (×2: list and counts) | No N+1; on par |
| `v_meetup_list` full | 50.9 | 63.7 | 5→5 | Bitmap Heap Scan → Hash join, 1 loop (×2) | No N+1; within noise to +25% |
| `rpc_get_nearby_games` call (25.2, 55.27, 50 km) | 50.1 | 65.3 | — | (Function Scan) | — |
| `rpc_get_nearby_games` body | 55.8 | 89.5 | 4→4 | Seq Scan → Hash join, 1 loop | No N+1; slower, see note 1 |
| `rpc_games_following_joined` call (200 ids, as a2) | 10.9 | 12.3 | — | (Function Scan) | — |
| `rpc_games_following_joined` body | 10.0 | 12.4 | 0→0 | Index Scan inside a Nested Loop join, 128 loops | No SubPlan; see note 2 |
| `rpc_unified_search_sectioned('bulk')` call | 1.7 | 3.9 | — | (Result) | — |
| unified search, games section | 0.85 | 1.46 | 0→0 | Bitmap Heap Scan → Hash join, 1 loop | No N+1 |
| unified search, meetups section | 0.49 | 1.00 | 0→0 | Bitmap Heap Scan → Hash join, 1 loop | No N+1 |

**Duplicates and counts (B), both types.** The test compared 36 row sets: 6 surfaces × 6 viewers, with unified search
counted per section. For every one:

- count = count(distinct id) = the legacy count;
- the md5 of the rows is identical to legacy;
- no id of the other event type appears.

Examples of the counts:

| Surface | Viewer | Rows |
|---|---|---|
| `v_game_card` | admin a3 | 3,019 |
| `v_game_card` | anon | 1,013 |
| `v_meetup_list` | admin a3 | 1,214 |
| `v_meetup_list` | anon | 410 |
| nearby | each viewer | 50 |
| following | a2 | 62 |
| following | anon | denied, as in legacy |
| unified search games ('bulk' plus 'k735') | each viewer | 948 |
| unified search meetups ('bulk' plus 'k735') | each viewer | 383 |

**Provenance (C).** The test made events disagree with the legacy row, with triggers off, inside a savepoint. All 5 read
paths returned the events title: both views, nearby, and both unified search sections.

**Access (D).** anon, the stranger and blocked a6 see no non-public fixture row. Blocked a6 does not see a1's game in nearby.
Every viewer's row set equals legacy (B).

**Rollback (E).** The test re-ran the stored pre-image DDL (4 views and 3 RPCs) and dropped the B05 index. That restores the
pre-image: all 36 row sets match the baseline, and the games, meetups and events hashes are unchanged.

**Pagination (P), equal `start_at`, both types.** The ordering is (start_at, id), the tie-break B05 `c1d7d13d` uses. Pages
were 3 and 4 rows, so page boundaries fall inside tie groups, and both keyset and OFFSET pages were checked, as host a1.
In every case the union of pages equals the full set, with no skip and no repeat (16 checks):

| View | Window | Rows | Distinct `start_at` |
|---|---|---|---|
| `v_game_card` | W1 | 8 | 1 |
| `v_game_card` | W2 (2030-01-02) | 54 | 24 |
| `v_meetup_list` | W1 | 7 | 1 |
| `v_meetup_list` | W2 | 22 | 22 (no ties for a1 here; W1 is the meetup tie case) |

P-neg shows the detector can fail: keyset on `start_at` alone, over the tie group, returns 3 of 6 rows.

**Unified search ties (P2).** "k735 tie" returns 5 rows in each section, all with equal score and equal `start_at`. They are
ordered by id, and the limit-3 and limit-10 results are prefixes of the full result, for both games and meetups.

### Notes

1. **Nearby body is 1.3–1.6× slower after B04** (about +15 to +35 ms locally). After B04 it hash-joins a full Seq Scan of
   `events` (5k rows). The plan is still set-based, with one loop and no SubPlan on events, and the SubPlan count is
   unchanged (4: favourites and verification). This is not an N+1. At production scale it would be worth checking that the
   planner uses an events index rather than a seq scan. That could not be measured here, because the dataset is tiny and
   the PostGIS functions are local stand-ins.
2. **`rpc_games_following_joined` reads events by Index Scan inside a Nested Loop**, 128 loops for 128 joined rows. That is a
   parameterised index join chosen by the planner, not a correlated SubPlan. Its cost scales with the joined rows exactly as
   the legacy `games` join did, and timing is on par.
3. **Unified search roughly doubles**, from about 1.7 to 3.9 ms for the call. It now joins events with an extra
   `ORDER BY …, e.start_at, e.id` (B05). The absolute cost stays under 4 ms locally. The local plans read the search
   column through a bitmap scan.

## Findings that are not B-migration defects (routing, not fixed here)

- **App meetup list pagination has no tie-break.** `lib/features/meetups/data/datasources/supabase_meetup_datasource.dart:23-26`
  pages `v_meetup_list` with `.order('start_at').range(offset, …)`, which has no `id` tie-break. Under equal `start_at`,
  OFFSET pages are non-deterministic and can skip or repeat across pages. This was true before B02 as well. The fix is a
  secondary `.order('id')`, which is **frontend capability work**. P proves that the views paginate correctly when ordered
  by (start_at, id).
- **`rpc_get_nearby_games` has no id tie-break.** It orders by distance, price, start_at with `LIMIT 50` (B05 inventory X3),
  and B04 left that unchanged. So the cut at the 50th row inside a tie group is non-deterministic. The test compares nearby
  tie-aware: rows before the last `start_at` in the result are compared exactly, and the last group is compared by count.
  A follow-up would add `, g.id` to the ORDER BY, which is backend capability work and needs a new ticket.

No defect was found in B01, B02, B04 or B05.

## Limitations

- **Data:** local synthetic data of about 5k events, all in warm cache. Production was not queried, and no `pg_stat_statements`
  or production plans were used. The milliseconds are indicative and the ratios are noisy (about ±25%). The timing guard is
  deliberately loose (after ≤ 3× before + 25 ms), so it catches only a gross regression.
- **Privileges:** timings run as superuser `postgres`, the owner and definer, so RLS on the base tables is bypassed, as it is
  for the owner-run views and the `SECURITY DEFINER` RPCs in production. The row-set checks (B, D) run as `anon` or
  `authenticated` with a JWT claim.
- **PostGIS:** it is not installed locally. The nearby RPC runs against stand-ins (a composite point, haversine distance, no
  GiST index), so its plan and timing do not represent production geo access.
- **Body plans:** these come from inlined copies of the current function source, not from the `SECURITY DEFINER` functions
  themselves. Unified search section plans come from the extracted section SELECTs.
- **App ordering:** P exercises the (start_at, id) ordering, not the app's current start_at-only ordering (see the finding
  above).

## Applied vs authored

Nothing was authored as a migration, and nothing was applied to Supabase or production. The only effects are on the
throwaway local cluster (port 55437): `mode=before` commits the local stand-ins, the fixture and the baseline tables there,
and the default mode rolls back.
