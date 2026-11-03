# KAN-769 (KAN-718 D01): SQL consumers of the slated legacy columns

**Verdict: all 40 slated (table, column) pairs are PENDING. No column is free to delete.** This is evidence
only. No migration was written and nothing was changed.

## 1. Slated set: where it comes from

**The repo has no exact list of the columns slated for deletion.** KAN712_CONTRACT.md §8 says phase 4
deletes "the legacy columns", but it lists none of them. This scan therefore uses the B15 shared-column set
(`k734_shared` in `supabase/tests/events_p2/kan714_b15_coverage_probe.sql`), intersected with the columns
that actually exist on each table. No column was invented.

- `games`: 21 columns. These are title, creator_profile_id, creator_user_id, start_at, end_at, capacity,
  listing_visibility, join_policy, min_skill, max_skill, is_cancelled, cancelled_at, cancelled_reason,
  sport_id, geo_location_id, area_id, venue_id, joining_rule, cost_cover, request_id and search_tsv.
- `meetups`: 19 columns. Meetups has no cancelled_at, cancelled_reason or join_policy. It adds rsvp_policy,
  which exists on meetups only.

If the slated list differs from B15's shared set, rerun the probe after editing the `slated` CTE. The
verdicts below cover only these 40 pairs.

## 2. How the scan works

The scan is `supabase/tests/events_p4/kan718_d01_sql_consumer_scan.sql`.

- **`mode=scan`** is one SELECT inside `BEGIN TRANSACTION READ ONLY`. It creates no temp objects and ends
  with ROLLBACK, so it can be run read-only against any database, production included. **It was NOT run
  against production.** The production execute_sql path is refused by a hook, and this ticket forbids
  querying production. An ops seat has to run it there.
- **`mode=test`** runs only on a local database whose name starts with `kan769` or `k769`.

The catalogue scan uses these detection paths:

- `pg_depend` on the column, which covers views (pg_rewrite), triggers, policies, constraints, indexes,
  defaults, SQL-body functions and publications. Dependency type n blocks the drop; type a is dropped with
  the column.
- `pg_publication_rel.prattrs`.
- `alias.col` in function bodies, matched per table.
- `NEW.col` and `OLD.col` in trigger functions attached to the table.
- Whole-row use: `%rowtype`, `NULL::games`, `SELECT * INTO`, `t.*` and `to_jsonb(NEW)`.
- Functions that take the table's row type in their signature.
- A view or policy that passes a whole row to a function typed on the table. This is how `kan711_events_parity`
  reads every column; pg_depend records no column dependency for it.
- Dynamic `EXECUTE` in a body that names the table.
- Loose bare-column matches, counted separately as a heuristic.
- Transitive callers up to depth 3.

The same SQL was also scanned as text in the repo migrations (latest definition wins, `k769_repo.py`) and
diffed against the catalogue and the B15 matrix (`k769_diff.py`).

## 3. Per-column verdicts

Counts are from `mode=scan` on the clean local database built from the migrations. `d` is the number of
direct consumers. `other` covers constraints, indexes, the publication and the composite signature. Every
column also has the `kan711_events_map_*` composite signature consumer and the `kan711_events_parity` view
(whole row through a function).

| column | verdict | consumers | ticket / reason |
|---|---|---|---|
| games.area_id | pending | d=19 (view 1, trig 0, pol 0, fn 14, loose 0, other 4); transitive 14; e.g. admin_cleanup_user_data, can_current_user_join_game, fn_games_activity_sync, fn_games_inherit_geo | KAN-711 map/backfill, KAN-712 compat mirror (KAN-713 intersection rule: kept mirror); KAN-716 realtime column list (pg_depend n, blocks DROP COLUMN); B15 open rows: no ticket |
| games.cancelled_at | pending | d=13 (view 1, trig 0, pol 0, fn 9, loose 1, other 2); transitive 9; e.g. admin_cleanup_user_data, can_current_user_join_game, kan711_events_backfill_batch, kan712_events_compat_mirror | KAN-711 map/backfill, KAN-712 compat mirror (KAN-713 intersection rule: kept mirror); KAN-716 realtime column list (pg_depend n, blocks DROP COLUMN); B15 open rows: no ticket |
| games.cancelled_reason | pending | d=13 (view 1, trig 0, pol 0, fn 9, loose 1, other 2); transitive 9; e.g. admin_cleanup_user_data, can_current_user_join_game, kan711_events_backfill_batch, kan712_events_compat_mirror | KAN-711 map/backfill, KAN-712 compat mirror (KAN-713 intersection rule: kept mirror); KAN-716 realtime column list (pg_depend n, blocks DROP COLUMN); B15 open rows: no ticket |
| games.capacity | pending | d=20 (view 1, trig 0, pol 0, fn 13, loose 3, other 3); transitive 12; e.g. admin_cleanup_user_data, can_current_user_join_game, game_slots_left, kan711_events_backfill_batch | KAN-711 map/backfill, KAN-712 compat mirror (KAN-713 intersection rule: kept mirror); KAN-716 realtime column list (pg_depend n, blocks DROP COLUMN); B15 open rows: no ticket |
| games.cost_cover | pending | d=15 (view 1, trig 0, pol 0, fn 11, loose 0, other 3); transitive 11; e.g. admin_cleanup_user_data, can_current_user_join_game, fn_games_sync_joining_rule, kan711_events_backfill_batch | KAN-711 map/backfill, KAN-712 compat mirror (KAN-713 intersection rule: kept mirror); B15 open rows: no ticket |
| games.creator_profile_id | pending | d=16 (view 1, trig 1, pol 0, fn 12, loose 0, other 2); transitive 12; e.g. admin_cleanup_user_data, can_current_user_join_game, fn_games_activity_sync, handle_game_created; trigger: trigger trg_games_set_host | KAN-711 map/backfill, KAN-712 compat mirror (KAN-713 intersection rule: kept mirror); B15 open rows: no ticket |
| games.creator_user_id | pending | d=33 (view 1, trig 0, pol 0, fn 23, loose 7, other 2); transitive 21; e.g. _can_view_game, _can_view_game_for_join, _is_game_host, _user_hosted_game | KAN-711 map/backfill, KAN-712 compat mirror (KAN-713 intersection rule: kept mirror); B15 open rows: no ticket |
| games.end_at | pending | d=22 (view 1, trig 0, pol 0, fn 11, loose 8, other 2); transitive 10; e.g. _slot_conflicts_game, admin_cleanup_user_data, can_current_user_join_game, kan711_events_backfill_batch | KAN-711 map/backfill, KAN-712 compat mirror (KAN-713 intersection rule: kept mirror); KAN-716 realtime column list (pg_depend n, blocks DROP COLUMN); B15 open rows: no ticket |
| games.geo_location_id | pending | d=19 (view 1, trig 0, pol 0, fn 14, loose 0, other 4); transitive 14; e.g. admin_cleanup_user_data, can_current_user_join_game, fn_games_activity_sync, fn_games_inherit_geo | KAN-711 map/backfill, KAN-712 compat mirror (KAN-713 intersection rule: kept mirror); KAN-716 realtime column list (pg_depend n, blocks DROP COLUMN); B15 open rows: no ticket |
| games.is_cancelled | pending | d=29 (view 1, trig 2, pol 0, fn 20, loose 4, other 2); transitive 16; e.g. _slot_conflicts_game, active_stream, admin_cleanup_user_data, can_current_user_join_game; trigger: trigger msg_system_game_cancelled; trigger: trigger trg_game_updated_notify | KAN-711 map/backfill, KAN-712 compat mirror (KAN-713 intersection rule: kept mirror); KAN-716 realtime column list (pg_depend n, blocks DROP COLUMN); B15 open rows: no ticket |
| games.join_policy | pending | d=15 (view 1, trig 0, pol 0, fn 11, loose 0, other 3); transitive 11; e.g. admin_cleanup_user_data, can_current_user_join_game, kan711_events_backfill_batch, kan712_events_compat_mirror | KAN-711 map/backfill, KAN-712 compat mirror (KAN-713 intersection rule: kept mirror); B15 open rows: no ticket |
| games.joining_rule | pending | d=15 (view 1, trig 0, pol 0, fn 11, loose 0, other 3); transitive 11; e.g. admin_cleanup_user_data, can_current_user_join_game, fn_games_sync_joining_rule, kan711_events_backfill_batch | KAN-711 map/backfill, KAN-712 compat mirror (KAN-713 intersection rule: kept mirror); B15 open rows: no ticket |
| games.listing_visibility | pending | d=18 (view 1, trig 0, pol 0, fn 15, loose 0, other 2); transitive 15; e.g. _can_view_game, _can_view_game_for_join, admin_cleanup_user_data, can_current_user_join_game | KAN-711 map/backfill, KAN-712 compat mirror (KAN-713 intersection rule: kept mirror); B15 open rows: no ticket |
| games.max_skill | pending | d=14 (view 1, trig 0, pol 0, fn 10, loose 1, other 2); transitive 10; e.g. admin_cleanup_user_data, can_current_user_join_game, kan711_events_backfill_batch, kan712_events_compat_mirror | KAN-711 map/backfill, KAN-712 compat mirror (KAN-713 intersection rule: kept mirror); B15 open rows: no ticket |
| games.min_skill | pending | d=14 (view 1, trig 0, pol 0, fn 10, loose 1, other 2); transitive 10; e.g. admin_cleanup_user_data, can_current_user_join_game, kan711_events_backfill_batch, kan712_events_compat_mirror | KAN-711 map/backfill, KAN-712 compat mirror (KAN-713 intersection rule: kept mirror); B15 open rows: no ticket |
| games.request_id | pending | d=14 (view 1, trig 0, pol 0, fn 11, loose 0, other 2); transitive 15; e.g. admin_cleanup_user_data, can_current_user_join_game, kan611_stamp_request_id, kan711_events_backfill_batch | KAN-711 map/backfill, KAN-712 compat mirror (KAN-713 intersection rule: kept mirror); B15 open rows: no ticket |
| games.search_tsv | pending | d=9 (view 1, trig 0, pol 0, fn 7, loose 0, other 1); transitive 6; e.g. admin_cleanup_user_data, can_current_user_join_game, kan711_events_backfill_batch, kan712_wrap_rpc | KAN-711 map/backfill, KAN-712 compat mirror (KAN-713 intersection rule: kept mirror); B15 open rows: no ticket |
| games.sport_id | pending | d=17 (view 1, trig 1, pol 0, fn 12, loose 0, other 3); transitive 12; e.g. admin_cleanup_user_data, can_current_user_join_game, fn_games_activity_sync, kan711_events_backfill_batch; trigger: trigger trg_games_require_challenge_sport | KAN-711 map/backfill, KAN-712 compat mirror (KAN-713 intersection rule: kept mirror); KAN-716 realtime column list (pg_depend n, blocks DROP COLUMN); B15 open rows: no ticket |
| games.start_at | pending | d=26 (view 1, trig 0, pol 0, fn 14, loose 8, other 3); transitive 15; e.g. _slot_conflicts_game, admin_cleanup_user_data, can_current_user_join_game, fn_generate_game_series_occurrences_kan712_inner | KAN-711 map/backfill, KAN-712 compat mirror (KAN-713 intersection rule: kept mirror); KAN-716 realtime column list (pg_depend n, blocks DROP COLUMN); B15 open rows: no ticket |
| games.title | pending | d=19 (view 1, trig 0, pol 0, fn 11, loose 5, other 2); transitive 11; e.g. admin_cleanup_user_data, can_current_user_join_game, kan711_events_backfill_batch, kan712_events_compat_mirror | KAN-711 map/backfill, KAN-712 compat mirror (KAN-713 intersection rule: kept mirror); KAN-716 realtime column list (pg_depend n, blocks DROP COLUMN); B15 open rows: no ticket |
| games.venue_id | pending | d=21 (view 1, trig 2, pol 0, fn 13, loose 2, other 3); transitive 13; e.g. admin_cleanup_user_data, can_current_user_join_game, fn_games_inherit_geo, kan711_events_backfill_batch; trigger: trigger trg_games_inherit_geo; trigger: trigger trg_kan713_games_a_location | KAN-711 map/backfill, KAN-712 compat mirror (KAN-713 intersection rule: kept mirror); KAN-716 realtime column list (pg_depend n, blocks DROP COLUMN); B15 open rows: no ticket |
| meetups.area_id | pending | d=12 (view 1, trig 0, pol 0, fn 8, loose 0, other 3); transitive 11; e.g. can_current_user_rsvp_meetup, fn_meetups_activity_sync, fn_meetups_inherit_geo, kan711_events_backfill_batch | KAN-711 map/backfill, KAN-712 compat mirror (KAN-713 intersection rule: kept mirror); KAN-716 realtime column list (pg_depend n, blocks DROP COLUMN); B15 open rows: no ticket |
| meetups.capacity | pending | d=11 (view 1, trig 0, pol 0, fn 6, loose 1, other 3); transitive 8; e.g. can_current_user_rsvp_meetup, k727_ref_meetup_slots_left, kan711_events_backfill_batch, kan712_events_compat_mirror | KAN-711 map/backfill, KAN-712 compat mirror (KAN-713 intersection rule: kept mirror); KAN-716 realtime column list (pg_depend n, blocks DROP COLUMN); B15 open rows: no ticket |
| meetups.cost_cover | pending | d=11 (view 1, trig 0, pol 0, fn 7, loose 0, other 3); transitive 10; e.g. can_current_user_rsvp_meetup, fn_meetups_sync_joining_rule, kan711_events_backfill_batch, kan712_events_compat_mirror | KAN-711 map/backfill, KAN-712 compat mirror (KAN-713 intersection rule: kept mirror); B15 open rows: no ticket |
| meetups.creator_profile_id | pending | d=10 (view 1, trig 0, pol 0, fn 7, loose 0, other 2); transitive 10; e.g. can_current_user_rsvp_meetup, fn_meetups_activity_sync, harness_host_actor_stub, kan711_events_backfill_batch | KAN-711 map/backfill, KAN-712 compat mirror (KAN-713 intersection rule: kept mirror); B15 open rows: no ticket |
| meetups.creator_user_id | pending | d=19 (view 1, trig 0, pol 4, fn 11, loose 1, other 2); transitive 11; e.g. active_stream, can_current_user_rsvp_meetup, fn_meetups_activity_sync, kan711_events_backfill_batch; policy: policy meetup_attendees_select; policy: policy meetup_attendees_select_visible; policy: policy meetup_attendees_write | KAN-711 map/backfill, KAN-712 compat mirror (KAN-713 intersection rule: kept mirror); RLS policy reads it; B15 open rows: no ticket |
| meetups.end_at | pending | d=10 (view 1, trig 0, pol 0, fn 5, loose 2, other 2); transitive 8; e.g. can_current_user_rsvp_meetup, kan711_events_backfill_batch, kan712_events_compat_mirror, kan712_legacy_guard | KAN-711 map/backfill, KAN-712 compat mirror (KAN-713 intersection rule: kept mirror); KAN-716 realtime column list (pg_depend n, blocks DROP COLUMN); B15 open rows: no ticket |
| meetups.geo_location_id | pending | d=12 (view 1, trig 0, pol 0, fn 8, loose 0, other 3); transitive 11; e.g. can_current_user_rsvp_meetup, fn_meetups_activity_sync, fn_meetups_inherit_geo, kan711_events_backfill_batch | KAN-711 map/backfill, KAN-712 compat mirror (KAN-713 intersection rule: kept mirror); KAN-716 realtime column list (pg_depend n, blocks DROP COLUMN); B15 open rows: no ticket |
| meetups.is_cancelled | pending | d=16 (view 1, trig 1, pol 0, fn 10, loose 2, other 2); transitive 11; e.g. active_stream, can_current_user_rsvp_meetup, fn_meetups_activity_sync, kan711_events_backfill_batch; trigger: trigger trg_meetups_cancel_notify | KAN-711 map/backfill, KAN-712 compat mirror (KAN-713 intersection rule: kept mirror); KAN-716 realtime column list (pg_depend n, blocks DROP COLUMN); B15 open rows: no ticket |
| meetups.joining_rule | pending | d=11 (view 1, trig 0, pol 0, fn 7, loose 0, other 3); transitive 10; e.g. can_current_user_rsvp_meetup, fn_meetups_sync_joining_rule, kan711_events_backfill_batch, kan712_events_compat_mirror | KAN-711 map/backfill, KAN-712 compat mirror (KAN-713 intersection rule: kept mirror); B15 open rows: no ticket |
| meetups.listing_visibility | pending | d=14 (view 1, trig 0, pol 3, fn 8, loose 0, other 2); transitive 8; e.g. active_stream, can_current_user_rsvp_meetup, kan711_events_backfill_batch, kan712_events_compat_mirror; policy: policy meetup_attendees_select; policy: policy meetup_attendees_select_visible; policy: policy meetups_select_visible | KAN-711 map/backfill, KAN-712 compat mirror (KAN-713 intersection rule: kept mirror); RLS policy reads it; B15 open rows: no ticket |
| meetups.max_skill | pending | d=8 (view 1, trig 0, pol 0, fn 5, loose 1, other 1); transitive 8; e.g. can_current_user_rsvp_meetup, kan711_events_backfill_batch, kan712_events_compat_mirror, kan712_legacy_guard | KAN-711 map/backfill, KAN-712 compat mirror (KAN-713 intersection rule: kept mirror); B15 open rows: no ticket |
| meetups.min_skill | pending | d=8 (view 1, trig 0, pol 0, fn 5, loose 1, other 1); transitive 8; e.g. can_current_user_rsvp_meetup, kan711_events_backfill_batch, kan712_events_compat_mirror, kan712_legacy_guard | KAN-711 map/backfill, KAN-712 compat mirror (KAN-713 intersection rule: kept mirror); B15 open rows: no ticket |
| meetups.request_id | pending | d=10 (view 1, trig 0, pol 0, fn 7, loose 0, other 2); transitive 10; e.g. can_current_user_rsvp_meetup, kan611_stamp_request_id, kan711_events_backfill_batch, kan712_events_compat_mirror | KAN-711 map/backfill, KAN-712 compat mirror (KAN-713 intersection rule: kept mirror); B15 open rows: no ticket |
| meetups.rsvp_policy | pending | d=8 (view 1, trig 0, pol 0, fn 5, loose 0, other 2); transitive 8; e.g. can_current_user_rsvp_meetup, kan711_events_backfill_batch, kan712_events_compat_mirror, kan712_legacy_guard | KAN-711 map/backfill, KAN-712 compat mirror (KAN-713 intersection rule: kept mirror); B15 open rows: no ticket |
| meetups.search_tsv | pending | d=7 (view 1, trig 0, pol 0, fn 5, loose 0, other 1); transitive 6; e.g. can_current_user_rsvp_meetup, kan711_events_backfill_batch, meetups_search_tsv_trigger, rpc_meetup_update_kan712_inner | KAN-711 map/backfill, KAN-712 compat mirror (KAN-713 intersection rule: kept mirror); B15 open rows: no ticket |
| meetups.sport_id | pending | d=12 (view 1, trig 1, pol 0, fn 7, loose 0, other 3); transitive 10; e.g. can_current_user_rsvp_meetup, fn_meetups_activity_sync, fn_meetups_enforce_solo_sport, kan711_events_backfill_batch; trigger: trigger trg_meetups_enforce_solo_sport | KAN-711 map/backfill, KAN-712 compat mirror (KAN-713 intersection rule: kept mirror); KAN-716 realtime column list (pg_depend n, blocks DROP COLUMN); B15 open rows: no ticket |
| meetups.start_at | pending | d=11 (view 1, trig 0, pol 0, fn 6, loose 2, other 2); transitive 9; e.g. can_current_user_rsvp_meetup, kan711_events_backfill_batch, kan712_events_compat_mirror, kan712_legacy_guard | KAN-711 map/backfill, KAN-712 compat mirror (KAN-713 intersection rule: kept mirror); KAN-716 realtime column list (pg_depend n, blocks DROP COLUMN); B15 open rows: no ticket |
| meetups.title | pending | d=14 (view 1, trig 0, pol 0, fn 6, loose 3, other 4); transitive 9 (KAN-789: was d=15 / fn 7 before KAN-785 retired `rpc_meetup_my`, which read m.title); e.g. can_current_user_rsvp_meetup, kan711_events_backfill_batch, kan712_events_compat_mirror, kan712_legacy_guard | KAN-711 map/backfill, KAN-712 compat mirror (KAN-713 intersection rule: kept mirror); KAN-716 realtime column list (pg_depend n, blocks DROP COLUMN); B15 open rows: no ticket |
| meetups.venue_id | pending | d=17 (view 1, trig 4, pol 0, fn 9, loose 0, other 3); transitive 12; e.g. can_current_user_rsvp_meetup, fn_meetups_inherit_geo, fn_meetups_sync_joining_rule, kan711_events_backfill_batch; trigger: trigger trg_kan713_meetups_a_location; trigger: trigger trg_kan713_meetups_b_joining; trigger: trigger trg_meetups_inherit_geo | KAN-711 map/backfill, KAN-712 compat mirror (KAN-713 intersection rule: kept mirror); KAN-716 realtime column list (pg_depend n, blocks DROP COLUMN); B15 open rows: no ticket |

**What every row has in common:**

- The **KAN-711** mirror triggers and backfill (`kan711_events_map_game` and `kan711_events_map_meetup`,
  plus `kan711_events_backfill_batch`, which uses dynamic SQL) read every column. They are the
  legacy→events sync. They retire only when legacy writes stop.
- The **KAN-712** compatibility mirror and guard (`kan712_events_compat_mirror`, `kan712_legacy_guard`) and
  the wrapped RPC bodies (`*_kan712_inner`) keep legacy values equal to the parent. Under KAN-713's
  "intersection, never widen" rule these are compatibility mirrors that must be kept. **They count as
  PENDING, not retired.**
- The **KAN-713** triggers read joining, location and venue geo (`kan713_games_*`, `kan713_meetups_*`), and
  so do the access helpers (`_can_view_game`, `can_current_user_join_game`, `can_current_user_rsvp_meetup`).
- The **KAN-716** realtime publication column list covers title, start_at, end_at, capacity, is_cancelled,
  cancelled_at, cancelled_reason, sport_id, area_id, geo_location_id and venue_id on both tables. Its
  dependency type is **n**, so `DROP COLUMN` fails until the publication's column list is changed.
- The **KAN-718 D07** index `games_series_id_start_at_key` uses `games.start_at`.
- **B15 open rows** (open-read, open-write, open-trigger and pinned) have no ticket. They are B15's 34
  unconverted functions. Examples are `get_nearby_games`, `getnearbymeetups`, `get_games_needing_players`,
  `_recent_activity_score` and `fn_generate_game_series_occurrences`.
- **Constraints and indexes** (`games_area_id_fkey`, `games_location_required`, `chk_meetups_title_len`,
  `meetups_title_check` and others) are mostly dependency type a, so they go away with the column. They are
  listed for completeness, not as blockers.
- **RLS:** `meetups_select_visible` and the `meetup_attendees_*` policies read `meetups.creator_user_id`
  and `meetups.listing_visibility`. In both the repo and the local catalogue, `games` has no policy that
  reads a slated column.

## 4. What changed against B15

Diff output from the clean run, refreshed by KAN-789 after KAN-785 retired `rpc_meetup_my()` (before KAN-785 the
first line read catalogue=57 repo=63 both=29):

```
DIFF: function consumers catalogue=56 repo=62 both=28 catalogue-only=28 repo-only=34
DIFF: consumers absent from the B15 matrix: 3: harness_host_actor_stub(); k727_ref_meetup_slots_left(uuid); kan611_stamp_request_id()
DIFF: catalogue non-function consumer rows: composite=40, constraint=31, index=5, policy=7, publication=20, trigger=12, view=40
```

1. **New consumer classes that B15 did not inventory:**
   - triggers and `NEW`/`OLD` trigger functions (`handle_game_created`, `trg_games_set_search_tsv`,
     `fn_games_*`/`fn_meetups_*` sync and inherit triggers, which B15 marked name-only);
   - constraints;
   - indexes;
   - the KAN-716 publication column list;
   - the parity view reading whole rows through a function;
   - RLS policies.
2. **Functions absent from the B15 matrix:** there are 3.
   - `kan611_stamp_request_id()` is real and reads request_id.
   - `harness_host_actor_stub()` and `k727_ref_meetup_slots_left(uuid)` are local test harness objects and
     do not exist in production.
3. **Catalogue-only (28):** these are functions the text scan misses but the catalogue finds. They are
   `_kan712_inner` bodies generated at runtime by `kan712_wrap_rpc`, and trigger functions that only
   B15's name-only rows covered.
4. **Repo-only (34):** these functions are defined in the repo migrations but are absent from the local
   chain, mostly B15 open-read functions from the older baseline. Those that still exist in production
   remain consumers until they are dropped or converted. **Whether each one exists in production is not
   documented here.** The production scan answers that.
5. **All 29 B15 anchors still hold** (30 before KAN-785 retired `rpc_meetup_my()`, which was a C6 anchor). These are C6 residual, C7 rowtype, C8 composite and C10 dynamic
   (probe check V2), so nothing B15 found has since stopped consuming a slated column.

## 5. Old store and web builds

**Deleting the columns blocks old builds.** Builds already published to the store and the web select these
columns directly through PostgREST (`games`, `meetups`, `v_game_card`, `v_meetup_list`, `v_my_games`). They
also subscribe to realtime changes using the KAN-716 column list. The approved compatibility path
(KAN-712's mirror and KAN-713's intersection rule) keeps those builds working only while the columns exist.
Removing a column turns their queries into errors, because PostgREST rejects an unknown column. The SQL
layer therefore cannot decide the deletion on its own. A client-side consumer scan (edge functions, Dart,
realtime clients) and a minimum-supported-build cutoff are needed. **This ticket did not scan those, and
no ticket for them is documented in the repo.**

## 6. Probe proof (local PG16, never production)

The clean run is `clean769.sh <sha>`. It runs `git archive` on the commit, builds a fresh `kan769clean`
database, applies the migration chain (with harnesses, B01-B14 and KAN-716), and runs the probe.

- **NEGATIVE 0:** the probe in test mode, run before the B migrations, must FAIL (B15 anchors absent).
- **N1-N6:** inside a transaction, the run plants an alias reader, a view, an RLS policy on games
  (cost_cover), a transitive caller and a dynamic reader. Each one must be flagged. It also plants a reader
  that only touches events, which must not be flagged.
- **N0:** the planted objects are gone after ROLLBACK.
- **V1-V4** check that there are 40 pairs, that the 29 B15 anchors are present (30 before KAN-785), that the parity view,
  mirror and publication are detected, and that all 40 pairs are pending with at least 7 non-heuristic
  consumers each.
- **S1-S5** cover:
  - seeding one game and one meetup through the legacy path;
  - checking that the legacy shapes are unchanged;
  - checking for no duplicates and that the counts per type equal the legacy counts;
  - checking that the owner, a stranger, a blocked user and anon each see nothing extra;
  - checking that md5 fingerprints and shapes are identical after ROLLBACK.

## 7. Limitations

- **The scan has not run on production.** Every verdict here comes from a local database built from the
  migrations. Production may hold functions, policies or views that are not in this repo; the 34 repo-only
  rows show that drift exists. To get production evidence, an ops seat must run `mode=scan` there.
- The harness uses an empty `supabase_realtime` publication as a stand-in. On Supabase the platform
  manages that publication.
- Edge functions, Dart code and realtime clients are not scanned.
- Text detection is heuristic. The loose bare-column matches are counted separately and are never the only
  basis for a pending verdict (V4). Dynamic SQL is flagged when it names the table, not resolved.
  Extension or non-plpgsql/sql languages are not documented.
- PL/pgSQL bodies that build their table name from a variable (not as a literal) are not detected.
  **Whether any exist is not documented.**
- The 5-function audit gap mentioned in B15 is not documented here.
