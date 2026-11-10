# KAN-714 — Events P2: parent reads (contract)

Authored by backend-3 (Shed), team Luxor, 2026-11-02. **Authored, not applied.** Every result below comes
from a throwaway local PostgreSQL 16 cluster (`/tmp/kan714_pg`, port 54714). Live Supabase was not touched.

## 0. Status in one paragraph

The migration `supabase/migrations/20261105100000_kan714_events_parent_reads.sql` moves **11 readers**
(6 views and 5 SECURITY DEFINER functions) from the legacy shared columns on `games` and `meetups` to
`public.events`. On the local copy it keeps shape, ids, order, counts, visibility, owner, ACL and security
attributes the same. It adds two events indexes and a keyset contract, and it can be rolled back in one
transaction. Rollback restores the catalogue fingerprint and data hashes exactly.

**It does NOT finish the ticket's full scope.** The read manifest finds 102 readers. 73 of them are not
repointed: 39 are deferred readers and 34 are write or gate paths. That includes nearby, search,
autocomplete, capacity/join gates, rating, booking, settlement, message, feed, notification and admin
readers. 55 of the 102 are not present in the local harness at all, so they could not be executed here.
Their values match events today only because the KAN-712 compat mirror keeps the legacy columns exact.
They would fail the provenance probe. See section 9.

## 1. Files

| File | Purpose |
|---|---|
| `supabase/migrations/20261105100000_kan714_events_parent_reads.sql` | The migration, one `BEGIN … COMMIT` (917 lines) |
| `supabase/tests/events_p2_kan714/rollback_kan714.sql` | One-transaction rollback from the stored pre-image |
| `supabase/tests/events_p2_kan714/fingerprint_kan714.sql` | Catalogue fingerprint plus data hashes (read-only) |
| `supabase/tests/events_p2_kan714/snapshot_kan714.sql` | Result parity per actor across all repointed readers (ROLLBACK) |
| `supabase/tests/events_p2_kan714/corrupt_legacy_kan714.sql` | Provenance setup: corrupts every legacy shared column with triggers off. Disposable `*c` copies only |
| `supabase/tests/events_p2_kan714/adversarial_kan714.sql` | Posture (A) and in-transaction provenance (P) probes (ROLLBACK) |
| `supabase/tests/events_p2_kan714/explain_kan714.sql` | EXPLAIN (ANALYZE, BUFFERS) set (ROLLBACK) |
| `supabase/tests/events_p2_kan714/local_harness_kan714.sql` | Local-only harness: pre-images plus bulk data (3000 games, 2000 meetups) |
| `supabase/tests/events_p2_kan714/KAN714_CONTRACT.md` | This file |

No `lib/` change, no edge-function change (section 2.3), no existing migration edited. There is no DROP
TABLE, DROP COLUMN or CASCADE, and no data mutation: the DATA hashes are identical before and after.

## 2. Read manifest

### 2.1 Repointed (11)

All 11 read every migrated shared column from `public.events`. Each joins with
`JOIN public.events e ON e.id = <sub>.event_id AND e.event_type = 'game'|'meetup'`, an INNER join (event_id is
NOT NULL under a validated CHECK). Ids stay the subtype ids (`g.id` / `m.id`), so feed, route and
notification payload ids are unchanged. `events.min_skill`/`max_skill` are smallint and are cast back
`::integer`. For meetups, `rsvp_policy` is `e.join_policy AS rsvp_policy`.

| Object | Migration line | Was defined at | Notes |
|---|---|---|---|
| `v_meetup_counts` | 234 | `20260915120000_meetups_hardening.sql:136` | `WITH (security_invoker = off)` kept |
| `v_meetup_list` | 247 | `20261008140000_game_price_meetup_setting…:18` | ORDER BY gains tie-break `, m.id` (see E5) |
| `v_game_card` | 319 | `20261101120000_kan698_v_game_card_series:9` | `total_slots = e.capacity + g.bench_slots` |
| `v_my_games` | 409 | `20260829080500_baseline_schema.sql:25858` | |
| `v_host_weekly_metrics` | 441 | `20260829080500_baseline_schema.sql:25662` | analytics |
| `v_rateable_after_game` | 475 | `20260829080500_baseline_schema.sql:26149` | rating; host = `e.creator_user_id` |
| `meetup_counts(uuid)` | 502 | `20260915120000_meetups_hardening.sql:104` | DEFINER, `search_path=public, pg_temp` |
| `rpc_games_following_joined(uuid[])` | 519 | `20261008170000_games_following_joined.sql:33` | reads `e.is_cancelled`; see E3 |
| `rpc_meetup_attendees(uuid,text,int,int)` | 565 | `20260915120000_meetups_hardening.sql:406` | DEFINER, `search_path=public`; `meetups%rowtype` replaced by scalars; ORDER BY gains `, r.profile_id` |
| `rpc_meetup_card(uuid,text)` | 610 | `20260915130000_meetups_card_fields.sql:78` | DEFINER, `search_path=public`; now `events%rowtype` plus subtype scalars; same JSON keys |
| `rpc_sport_overview(uuid,text)` | 729 | `20261021115000_sport_overview_counts.sql:40` | DEFINER; the games and meetups count subqueries join events |

**Columns that intentionally stay on the subtype** (not shared, or not in events):
description, location_name, game_type, bench_slots, members_only, vibe_key, is_indoor, host_actor_id,
squad_id, price_aed, series_id, venue_space_id, sport_variant_id, rules, allow_spectators, allows_waitlist.

**Each body was authored from the live-equivalent catalogue** (`pg_get_functiondef` / `pg_get_viewdef` on the
local pre-KAN-714 database, which equals the repo text), never from a migration file (T-058). The
migration pins `md5(prosrc)` for each function, plus a view column signature and pg_depend column set. It
refuses to run if the target drifted from what was authored against.

### 2.2 Full manifest (102 rows)

Population source: a scan of every `supabase/migrations/*.sql`, latest definition wins, for any function or
view that references `games`/`meetups` (102 objects). "Local" means the object exists in the local harness
and could be executed. Security mode is read from the local catalogue (`?` = not present locally).

| # | Object | Area | Kind / security | Defined at (file:line) | %ROWTYPE | Local | Classification | Reason |
|---|---|---|---|---|---|---|---|---|
| 1 | `_can_view_game(uuid)` | listing/other | FUNCTION DEFINER | `supabase/migrations/20261104100000_kan713_access_helpers.sql:144` |  | yes | EXCEPTION E3 | KAN-713 intersection helper (legacy AND events); owned by KAN-713 |
| 2 | `_can_view_game_for_join(uuid)` | capacity/join | FUNCTION INVOKER | `supabase/migrations/20261104100000_kan713_access_helpers.sql:194` |  | yes | UNCHANGED-WITH-REASON | KAN-710..713 infrastructure: mirror/backfill/parity/guard/helper that must read legacy by design |
| 3 | `_game_belongs_to_venue(uuid,uuid)` | booking | FUNCTION ? | `supabase/migrations/20260829080500_baseline_schema.sql:1071` |  | NO | NOT REPOINTED (deferred) | still reads legacy shared columns; value-equal only while the KAN-712 mirror holds; would fail a provenance probe |
| 4 | `_is_game_host(uuid)` | listing/other | FUNCTION DEFINER | `supabase/migrations/20261104100000_kan713_access_helpers.sql:230` |  | yes | UNCHANGED-WITH-REASON | KAN-710..713 infrastructure: mirror/backfill/parity/guard/helper that must read legacy by design |
| 5 | `_recent_activity_score(uuid,integer)` | feed/notification | FUNCTION ? | `supabase/migrations/20260829080500_baseline_schema.sql:1490` |  | NO | NOT REPOINTED (deferred) | still reads legacy shared columns; value-equal only while the KAN-712 mirror holds; would fail a provenance probe |
| 6 | `_slot_conflicts_game(uuid,timestamptz,timestamptz)` | booking | FUNCTION ? | `supabase/migrations/20260829080500_baseline_schema.sql:1594` |  | NO | NOT REPOINTED (deferred) | still reads legacy shared columns; value-equal only while the KAN-712 mirror holds; would fail a provenance probe |
| 7 | `_user_hosted_game(uuid,uuid)` | listing/other | FUNCTION ? | `supabase/migrations/20260829080500_baseline_schema.sql:1712` |  | NO | NOT REPOINTED (deferred) | still reads legacy shared columns; value-equal only while the KAN-712 mirror holds; would fail a provenance probe |
| 8 | `active_stream(...)` | feed/notification | FUNCTION ? | `supabase/migrations/20261020120000_kan595_active_stream.sql:44` |  | NO | NOT REPOINTED (deferred) | still reads legacy shared columns; value-equal only while the KAN-712 mirror holds; would fail a provenance probe |
| 9 | `admin_cleanup_user_data(uuid,boolean)` | analytics/admin | FUNCTION DEFINER | `supabase/migrations/20260829080500_baseline_schema.sql:2220` |  | yes | NOT REPOINTED (write path) | write/gate RPC; KAN-712 makes events authoritative and the compat mirror keeps legacy equal in the same statement; reads would fail a provenance probe |
| 10 | `admin_overview_row()` | analytics/admin | FUNCTION ? | `supabase/migrations/20260829080500_baseline_schema.sql:2512` |  | NO | NOT REPOINTED (deferred) | still reads legacy shared columns; value-equal only while the KAN-712 mirror holds; would fail a provenance probe |
| 11 | `can_current_user_join_game(uuid,text,uuid)` | capacity/join | FUNCTION INVOKER | `supabase/migrations/20261104100000_kan713_access_helpers.sql:248` | yes | yes | UNCHANGED-WITH-REASON | KAN-710..713 infrastructure: mirror/backfill/parity/guard/helper that must read legacy by design |
| 12 | `can_current_user_rsvp_meetup(uuid,uuid)` | capacity/join | FUNCTION DEFINER | `supabase/migrations/20261104100000_kan713_access_helpers.sql:323` | yes | yes | UNCHANGED-WITH-REASON | KAN-710..713 infrastructure: mirror/backfill/parity/guard/helper that must read legacy by design |
| 13 | `events_check_parent_children()` | listing/other | FUNCTION DEFINER | `supabase/migrations/20261101140000_kan710_events_parent_schema.sql:197` |  | yes | UNCHANGED-WITH-REASON | KAN-710..713 infrastructure: mirror/backfill/parity/guard/helper that must read legacy by design |
| 14 | `events_check_series_occurrence()` | listing/other | FUNCTION DEFINER | `supabase/migrations/20261101140000_kan710_events_parent_schema.sql:214` |  | yes | UNCHANGED-WITH-REASON | KAN-710..713 infrastructure: mirror/backfill/parity/guard/helper that must read legacy by design |
| 15 | `events_check_subtype_link()` | listing/other | FUNCTION DEFINER | `supabase/migrations/20261101140000_kan710_events_parent_schema.sql:158` |  | yes | UNCHANGED-WITH-REASON | KAN-710..713 infrastructure: mirror/backfill/parity/guard/helper that must read legacy by design |
| 16 | `fn_game_roster_activity_sync()` | feed/notification | FUNCTION ? | `supabase/migrations/20260829080500_baseline_schema.sql:5929` |  | NO | NOT REPOINTED (deferred) | still reads legacy shared columns; value-equal only while the KAN-712 mirror holds; would fail a provenance probe |
| 17 | `fn_generate_game_series_occurrences(uuid)` | rating | FUNCTION DEFINER | `supabase/migrations/20261030140000_kan694_fix_same_day_topup.sql:31` |  | yes | NOT REPOINTED (write path) | write/gate RPC; KAN-712 makes events authoritative and the compat mirror keeps legacy equal in the same statement; reads would fail a provenance probe |
| 18 | `fn_meetup_rsvps_activity_sync()` | feed/notification | FUNCTION ? | `supabase/migrations/20260829080500_baseline_schema.sql:6203` |  | NO | NOT REPOINTED (deferred) | still reads legacy shared columns; value-equal only while the KAN-712 mirror holds; would fail a provenance probe |
| 19 | `game_is_joinable(uuid)` | capacity/join | FUNCTION ? | `supabase/migrations/20260829080500_baseline_schema.sql:6809` |  | NO | NOT REPOINTED (deferred) | still reads legacy shared columns; value-equal only while the KAN-712 mirror holds; would fail a provenance probe |
| 20 | `game_rating_rebuild_all()` | rating | FUNCTION ? | `supabase/migrations/20260829080500_baseline_schema.sql:6824` |  | NO | NOT REPOINTED (deferred) | still reads legacy shared columns; value-equal only while the KAN-712 mirror holds; would fail a provenance probe |
| 21 | `game_slots_left(uuid)` | capacity/join | FUNCTION INVOKER | `supabase/migrations/20260829080500_baseline_schema.sql:6901` |  | yes | NOT REPOINTED (deferred) | still reads legacy shared columns; value-equal only while the KAN-712 mirror holds; would fail a provenance probe |
| 22 | `get_games_needing_players()` | analytics/admin | FUNCTION ? | `supabase/migrations/20260829080500_baseline_schema.sql:7161` |  | NO | NOT REPOINTED (deferred) | still reads legacy shared columns; value-equal only while the KAN-712 mirror holds; would fail a provenance probe |
| 23 | `get_nearby_games(float8,float8,float8)` | nearby | FUNCTION ? | `supabase/migrations/20260829080500_baseline_schema.sql:7378` |  | NO | NOT REPOINTED (deferred) | still reads legacy shared columns; value-equal only while the KAN-712 mirror holds; would fail a provenance probe |
| 24 | `get_nearby_games(float8,float8,integer)` | nearby | FUNCTION ? | `supabase/migrations/20260829080500_baseline_schema.sql:7418` |  | NO | NOT REPOINTED (deferred) | still reads legacy shared columns; value-equal only while the KAN-712 mirror holds; would fail a provenance probe |
| 25 | `get_open_games_for_seeding()` | analytics/admin | FUNCTION ? | `supabase/migrations/20260829080500_baseline_schema.sql:7614` |  | NO | NOT REPOINTED (deferred) | still reads legacy shared columns; value-equal only while the KAN-712 mirror holds; would fail a provenance probe |
| 26 | `getnearbygames(float8,float8,float8)` | nearby | FUNCTION ? | `supabase/migrations/20260829080500_baseline_schema.sql:7820` |  | NO | NOT REPOINTED (deferred) | still reads legacy shared columns; value-equal only while the KAN-712 mirror holds; would fail a provenance probe |
| 27 | `getnearbymeetups(float8,float8,float8)` | nearby | FUNCTION ? | `supabase/migrations/20260829080500_baseline_schema.sql:7847` |  | NO | NOT REPOINTED (deferred) | still reads legacy shared columns; value-equal only while the KAN-712 mirror holds; would fail a provenance probe |
| 28 | `kan711_events_backfill_batch(text,integer)` | listing/other | FUNCTION DEFINER | `supabase/migrations/20261102120000_kan711_events_backfill.sql:140` |  | yes | UNCHANGED-WITH-REASON | KAN-710..713 infrastructure: mirror/backfill/parity/guard/helper that must read legacy by design |
| 29 | `kan711_events_map_game(games)` | listing/other | FUNCTION INVOKER | `supabase/migrations/20261102110000_kan711_events_mirror_triggers.sql:49` |  | yes | UNCHANGED-WITH-REASON | KAN-710..713 infrastructure: mirror/backfill/parity/guard/helper that must read legacy by design |
| 30 | `kan711_events_map_meetup(meetups)` | listing/other | FUNCTION INVOKER | `supabase/migrations/20261102110000_kan711_events_mirror_triggers.sql:62` |  | yes | UNCHANGED-WITH-REASON | KAN-710..713 infrastructure: mirror/backfill/parity/guard/helper that must read legacy by design |
| 31 | `kan711_events_parity` | listing/other | VIEW security_invoker=true | `supabase/migrations/20261102120000_kan711_events_backfill.sql:94` |  | yes | UNCHANGED-WITH-REASON | KAN-710..713 infrastructure: mirror/backfill/parity/guard/helper that must read legacy by design |
| 32 | `kan711_events_validate_links()` | listing/other | FUNCTION DEFINER | `supabase/migrations/20261102120000_kan711_events_backfill.sql:286` |  | yes | UNCHANGED-WITH-REASON | KAN-710..713 infrastructure: mirror/backfill/parity/guard/helper that must read legacy by design |
| 33 | `kan712_events_compat_mirror()` | listing/other | FUNCTION DEFINER | `supabase/migrations/20261103100000_kan712_events_write_contract.sql:230` |  | yes | UNCHANGED-WITH-REASON | KAN-710..713 infrastructure: mirror/backfill/parity/guard/helper that must read legacy by design |
| 34 | `kan712_wrap_rpc(regprocedure,text)` | listing/other | FUNCTION DEFINER | `supabase/migrations/20261103100000_kan712_events_write_contract.sql:334` |  | yes | UNCHANGED-WITH-REASON | KAN-710..713 infrastructure: mirror/backfill/parity/guard/helper that must read legacy by design |
| 35 | `kan713_events_location()` | listing/other | FUNCTION DEFINER | `supabase/migrations/20261104110000_kan713_location_triggers.sql:295` |  | yes | UNCHANGED-WITH-REASON | KAN-710..713 infrastructure: mirror/backfill/parity/guard/helper that must read legacy by design |
| 36 | `meetup_counts(uuid)` | listing/other | FUNCTION DEFINER | `supabase/migrations/20260915120000_meetups_hardening.sql:104` |  | yes | REPOINTED | shared columns now read from public.events (this migration) |
| 37 | `meetup_slots_left(uuid)` | capacity/join | FUNCTION ? | `supabase/migrations/20260829080500_baseline_schema.sql:8971` |  | NO | NOT REPOINTED (deferred) | still reads legacy shared columns; value-equal only while the KAN-712 mirror holds; would fail a provenance probe |
| 38 | `msg_authorize(uuid,text)` | message | FUNCTION ? | `supabase/migrations/20261017130000_kan558_msg_meetup_chat.sql:236` |  | NO | NOT REPOINTED (deferred) | still reads legacy shared columns; value-equal only while the KAN-712 mirror holds; would fail a provenance probe |
| 39 | `msg_evaluate(uuid,uuid,text)` | message | FUNCTION ? | `supabase/migrations/20261017130000_kan558_msg_meetup_chat.sql:64` |  | NO | NOT REPOINTED (deferred) | still reads legacy shared columns; value-equal only while the KAN-712 mirror holds; would fail a provenance probe |
| 40 | `msg_game_conversation(uuid,text)` | message | FUNCTION ? | `supabase/migrations/20261017120000_kan563_msg_game_conversation.sql:25` |  | NO | NOT REPOINTED (deferred) | still reads legacy shared columns; value-equal only while the KAN-712 mirror holds; would fail a provenance probe |
| 41 | `msg_my_conversations(integer)` | message | FUNCTION ? | `supabase/migrations/20261017140000_kan559_msg_my_conversations_meetup_id.sql:15` |  | NO | NOT REPOINTED (deferred) | still reads legacy shared columns; value-equal only while the KAN-712 mirror holds; would fail a provenance probe |
| 42 | `nearby_games(...)` | nearby | FUNCTION ? | `supabase/migrations/20260829080500_baseline_schema.sql:9003` |  | NO | NOT REPOINTED (deferred) | still reads legacy shared columns; value-equal only while the KAN-712 mirror holds; would fail a provenance probe |
| 43 | `rpc_autocomplete_entities(...)` | search/autocomplete | FUNCTION ? | `supabase/migrations/20260829080500_baseline_schema.sql:10758` |  | NO | NOT REPOINTED (deferred) | still reads legacy shared columns; value-equal only while the KAN-712 mirror holds; would fail a provenance probe |
| 44 | `rpc_booking_cancel(uuid)` | booking | FUNCTION ? | `supabase/migrations/20260829080500_baseline_schema.sql:11108` |  | NO | NOT REPOINTED (write path) | write/gate RPC; KAN-712 makes events authoritative and the compat mirror keeps legacy equal in the same statement; reads would fail a provenance probe |
| 45 | `rpc_booking_hold_for_game(uuid,uuid,timestamptz,timestamptz)` | booking | FUNCTION DEFINER | `supabase/migrations/20260829080500_baseline_schema.sql:11145` |  | yes | NOT REPOINTED (write path) | write/gate RPC; KAN-712 makes events authoritative and the compat mirror keeps legacy equal in the same statement; reads would fail a provenance probe |
| 46 | `rpc_booking_hold_for_meetup(uuid,uuid,timestamptz,timestamptz)` | booking | FUNCTION DEFINER | `supabase/migrations/20260829080500_baseline_schema.sql:11180` |  | yes | NOT REPOINTED (write path) | write/gate RPC; KAN-712 makes events authoritative and the compat mirror keeps legacy equal in the same statement; reads would fail a provenance probe |
| 47 | `rpc_cancel_game(uuid,text)` | listing/other | FUNCTION DEFINER | `supabase/migrations/20260829080500_baseline_schema.sql:11243` |  | yes | NOT REPOINTED (write path) | write/gate RPC; KAN-712 makes events authoritative and the compat mirror keeps legacy equal in the same statement; reads would fail a provenance probe |
| 48 | `rpc_cancel_game_series(uuid,text)` | listing/other | FUNCTION DEFINER | `supabase/migrations/20261030130000_kan694_rpc_series_edit_cancel.sql:165` |  | yes | NOT REPOINTED (write path) | write/gate RPC; KAN-712 makes events authoritative and the compat mirror keeps legacy equal in the same statement; reads would fail a provenance probe |
| 49 | `rpc_create_game(...)` | listing/other | FUNCTION DEFINER | `supabase/migrations/20261021120200_kan611_rpc_create_game_request_id.sql:33` |  | yes | NOT REPOINTED (write path) | write/gate RPC; KAN-712 makes events authoritative and the compat mirror keeps legacy equal in the same statement; reads would fail a provenance probe |
| 50 | `rpc_create_meetup(...)` | listing/other | FUNCTION DEFINER | `supabase/migrations/20260915120000_meetups_hardening.sql:224` |  | yes | NOT REPOINTED (write path) | write/gate RPC; KAN-712 makes events authoritative and the compat mirror keeps legacy equal in the same statement; reads would fail a provenance probe |
| 51 | `rpc_create_meetup(...)` | listing/other | FUNCTION DEFINER | `supabase/migrations/20261008140000_game_price_meetup_setting.sql:447` |  | yes | NOT REPOINTED (write path) | write/gate RPC; KAN-712 makes events authoritative and the compat mirror keeps legacy equal in the same statement; reads would fail a provenance probe |
| 52 | `rpc_create_meetup(...)` | listing/other | FUNCTION DEFINER | `supabase/migrations/20261021120300_kan611_rpc_create_meetup_request_id.sql:31` |  | yes | NOT REPOINTED (write path) | write/gate RPC; KAN-712 makes events authoritative and the compat mirror keeps legacy equal in the same statement; reads would fail a provenance probe |
| 53 | `rpc_decide_join_request(uuid,boolean)` | capacity/join | FUNCTION ? | `supabase/migrations/20260829080500_baseline_schema.sql:12061` |  | NO | NOT REPOINTED (write path) | write/gate RPC; KAN-712 makes events authoritative and the compat mirror keeps legacy equal in the same statement; reads would fail a provenance probe |
| 54 | `rpc_edit_game_series_future(...)` | listing/other | FUNCTION DEFINER | `supabase/migrations/20261030130000_kan694_rpc_series_edit_cancel.sql:85` |  | yes | NOT REPOINTED (write path) | write/gate RPC; KAN-712 makes events authoritative and the compat mirror keeps legacy equal in the same statement; reads would fail a provenance probe |
| 55 | `rpc_edit_game_series_occurrence(...)` | listing/other | FUNCTION DEFINER | `supabase/migrations/20261030130000_kan694_rpc_series_edit_cancel.sql:35` | yes | yes | NOT REPOINTED (write path) | write/gate RPC; KAN-712 makes events authoritative and the compat mirror keeps legacy equal in the same statement; reads would fail a provenance probe |
| 56 | `rpc_games_following_joined(uuid[])` | capacity/join | FUNCTION DEFINER | `supabase/migrations/20261008170000_games_following_joined.sql:33` |  | yes | REPOINTED | shared columns now read from public.events (this migration) |
| 57 | `rpc_get_activity_feed(text,integer,timestamptz)` | feed/notification | FUNCTION ? | `supabase/migrations/20261101130000_kan689_rpc_get_activity_feed_fix.sql:7` |  | NO | NOT REPOINTED (deferred) | still reads legacy shared columns; value-equal only while the KAN-712 mirror holds; would fail a provenance probe |
| 58 | `rpc_get_nearby_games(float8,float8,integer,uuid,text)` | nearby | FUNCTION ? | `supabase/migrations/20261008160000_games_nearby_block_guard.sql:24` |  | NO | NOT REPOINTED (deferred) | still reads legacy shared columns; value-equal only while the KAN-712 mirror holds; would fail a provenance probe |
| 59 | `rpc_get_nearby_games(...)` | nearby | FUNCTION ? | `supabase/migrations/20261008140000_game_price_meetup_setting.sql:358` |  | NO | NOT REPOINTED (deferred) | still reads legacy shared columns; value-equal only while the KAN-712 mirror holds; would fail a provenance probe |
| 60 | `rpc_invite_user(uuid,uuid)` | capacity/join | FUNCTION ? | `supabase/migrations/20260829080500_baseline_schema.sql:13364` |  | NO | NOT REPOINTED (write path) | write/gate RPC; KAN-712 makes events authoritative and the compat mirror keeps legacy equal in the same statement; reads would fail a provenance probe |
| 61 | `rpc_join_game(text,uuid,uuid)` | capacity/join | FUNCTION ? | `supabase/migrations/20260829080500_baseline_schema.sql:13414` |  | NO | NOT REPOINTED (write path) | write/gate RPC; KAN-712 makes events authoritative and the compat mirror keeps legacy equal in the same statement; reads would fail a provenance probe |
| 62 | `rpc_meetup_attendees(uuid,text,integer,integer)` | listing/other | FUNCTION DEFINER | `supabase/migrations/20260915120000_meetups_hardening.sql:406` | yes | yes | REPOINTED | shared columns now read from public.events (this migration) |
| 63 | `rpc_meetup_cancel(uuid)` | listing/other | FUNCTION DEFINER | `supabase/migrations/20260915120000_meetups_hardening.sql:373` |  | yes | NOT REPOINTED (write path) | write/gate RPC; KAN-712 makes events authoritative and the compat mirror keeps legacy equal in the same statement; reads would fail a provenance probe |
| 64 | `rpc_meetup_card(uuid,text)` | listing/other | FUNCTION DEFINER | `supabase/migrations/20260915130000_meetups_card_fields.sql:78` | yes | yes | REPOINTED | shared columns now read from public.events (this migration) |
| 65 | `rpc_meetup_decide_request(uuid,uuid,text)` | listing/other | FUNCTION ? | `supabase/migrations/20260915120000_meetups_hardening.sql:622` | yes | NO | NOT REPOINTED (write path) | write/gate RPC; KAN-712 makes events authoritative and the compat mirror keeps legacy equal in the same statement; reads would fail a provenance probe |
| 66 | `rpc_meetup_invite_user(uuid,uuid,timestamptz)` | capacity/join | FUNCTION ? | `supabase/migrations/20260829080500_baseline_schema.sql:13789` |  | NO | NOT REPOINTED (write path) | write/gate RPC; KAN-712 makes events authoritative and the compat mirror keeps legacy equal in the same statement; reads would fail a provenance probe |
| 67 | `rpc_meetup_mint_link(uuid,timestamptz,integer)` | listing/other | FUNCTION ? | `supabase/migrations/20260829080500_baseline_schema.sql:13812` |  | NO | NOT REPOINTED (write path) | write/gate RPC; KAN-712 makes events authoritative and the compat mirror keeps legacy equal in the same statement; reads would fail a provenance probe |
| 68 | `rpc_meetup_my()` | listing/other | FUNCTION INVOKER | `supabase/migrations/20260829080500_baseline_schema.sql:13832` |  | yes | EXCEPTION E1 | body already fails 42703 (m.starts_at); not touched |
| 69 | `rpc_meetup_remove_attendee(uuid,uuid)` | listing/other | FUNCTION ? | `supabase/migrations/20260915120000_meetups_hardening.sql:691` | yes | NO | NOT REPOINTED (write path) | write/gate RPC; KAN-712 makes events authoritative and the compat mirror keeps legacy equal in the same statement; reads would fail a provenance probe |
| 70 | `rpc_meetup_rsvp(uuid,text,uuid,uuid)` | capacity/join | FUNCTION ? | `supabase/migrations/20260912190747_kan180_finding_b_meetup_rsvp_identity_and_profile_derivation.sql:116` |  | NO | NOT REPOINTED (write path) | write/gate RPC; KAN-712 makes events authoritative and the compat mirror keeps legacy equal in the same statement; reads would fail a provenance probe |
| 71 | `rpc_meetup_set_attendee(uuid,uuid,text)` | listing/other | FUNCTION ? | `supabase/migrations/20260829080500_baseline_schema.sql:13978` |  | NO | NOT REPOINTED (write path) | write/gate RPC; KAN-712 makes events authoritative and the compat mirror keeps legacy equal in the same statement; reads would fail a provenance probe |
| 72 | `rpc_meetup_update(...)` | listing/other | FUNCTION DEFINER | `supabase/migrations/20260915120000_meetups_hardening.sql:534` | yes | yes | NOT REPOINTED (write path) | write/gate RPC; KAN-712 makes events authoritative and the compat mirror keeps legacy equal in the same statement; reads would fail a provenance probe |
| 73 | `rpc_meetup_visible()` | listing/other | FUNCTION ? | `supabase/migrations/20260829080500_baseline_schema.sql:14037` |  | NO | NOT REPOINTED (deferred) | still reads legacy shared columns; value-equal only while the KAN-712 mirror holds; would fail a provenance probe |
| 74 | `rpc_mint_join_link(uuid,timestamptz,integer)` | capacity/join | FUNCTION ? | `supabase/migrations/20260829080500_baseline_schema.sql:14050` |  | NO | NOT REPOINTED (write path) | write/gate RPC; KAN-712 makes events authoritative and the compat mirror keeps legacy equal in the same statement; reads would fail a provenance probe |
| 75 | `rpc_rate_game(uuid,uuid,jsonb,text)` | rating | FUNCTION ? | `supabase/migrations/20260829080500_baseline_schema.sql:14581` |  | NO | NOT REPOINTED (write path) | write/gate RPC; KAN-712 makes events authoritative and the compat mirror keeps legacy equal in the same statement; reads would fail a provenance probe |
| 76 | `rpc_rate_user(uuid,uuid,uuid,jsonb,text)` | rating | FUNCTION ? | `supabase/migrations/20260829080500_baseline_schema.sql:14636` |  | NO | NOT REPOINTED (write path) | write/gate RPC; KAN-712 makes events authoritative and the compat mirror keeps legacy equal in the same statement; reads would fail a provenance probe |
| 77 | `rpc_rate_venue(uuid,uuid,uuid,jsonb,text)` | rating | FUNCTION ? | `supabase/migrations/20260829080500_baseline_schema.sql:14716` |  | NO | NOT REPOINTED (write path) | write/gate RPC; KAN-712 makes events authoritative and the compat mirror keeps legacy equal in the same statement; reads would fail a provenance probe |
| 78 | `rpc_recreate_from_game(uuid,boolean)` | listing/other | FUNCTION ? | `supabase/migrations/20260829080500_baseline_schema.sql:14780` |  | NO | NOT REPOINTED (write path) | write/gate RPC; KAN-712 makes events authoritative and the compat mirror keeps legacy equal in the same statement; reads would fail a provenance probe |
| 79 | `rpc_remove_player(uuid,uuid)` | listing/other | FUNCTION ? | `supabase/migrations/20260829080500_baseline_schema.sql:14836` |  | NO | NOT REPOINTED (write path) | write/gate RPC; KAN-712 makes events authoritative and the compat mirror keeps legacy equal in the same statement; reads would fail a provenance probe |
| 80 | `rpc_reschedule_game(uuid,timestamptz,timestamptz)` | listing/other | FUNCTION DEFINER | `supabase/migrations/20260829080500_baseline_schema.sql:14983` |  | yes | NOT REPOINTED (write path) | write/gate RPC; KAN-712 makes events authoritative and the compat mirror keeps legacy equal in the same statement; reads would fail a provenance probe |
| 81 | `rpc_search_entities(...)` | search/autocomplete | FUNCTION ? | `supabase/migrations/20260829080500_baseline_schema.sql:15152` |  | NO | NOT REPOINTED (deferred) | still reads legacy shared columns; value-equal only while the KAN-712 mirror holds; would fail a provenance probe |
| 82 | `rpc_sport_overview(uuid,text)` | listing/other | FUNCTION DEFINER | `supabase/migrations/20261021115000_sport_overview_counts.sql:40` |  | yes | REPOINTED | shared columns now read from public.events (this migration) |
| 83 | `rpc_unified_search_sectioned(text,uuid,float8,float8,float8,integer)` | search/autocomplete | FUNCTION ? | `supabase/migrations/20260829080500_baseline_schema.sql:16243` |  | NO | NOT REPOINTED (deferred) | still reads legacy shared columns; value-equal only while the KAN-712 mirror holds; would fail a provenance probe |
| 84 | `rpc_update_game(...)` | listing/other | FUNCTION DEFINER | `supabase/migrations/20260829080500_baseline_schema.sql:16367` |  | yes | NOT REPOINTED (write path) | write/gate RPC; KAN-712 makes events authoritative and the compat mirror keeps legacy equal in the same statement; reads would fail a provenance probe |
| 85 | `rpc_update_game(...)` | listing/other | FUNCTION DEFINER | `supabase/migrations/20261008140000_game_price_meetup_setting.sql:281` |  | yes | NOT REPOINTED (write path) | write/gate RPC; KAN-712 makes events authoritative and the compat mirror keeps legacy equal in the same statement; reads would fail a provenance probe |
| 86 | `settle_game(uuid,boolean)` | settlement | FUNCTION ? | `supabase/migrations/20260911114500_kan169_settle_game_zero_and_negative_earnings.sql:27` |  | NO | NOT REPOINTED (write path) | write/gate RPC; KAN-712 makes events authoritative and the compat mirror keeps legacy equal in the same statement; reads would fail a provenance probe |
| 87 | `trg_game_join_request_notify()` | feed/notification | FUNCTION ? | `supabase/migrations/20260829080500_baseline_schema.sql:17765` |  | NO | NOT REPOINTED (deferred) | still reads legacy shared columns; value-equal only while the KAN-712 mirror holds; would fail a provenance probe |
| 88 | `trg_game_waitlist_promoted_notify()` | feed/notification | FUNCTION ? | `supabase/migrations/20260829080500_baseline_schema.sql:17803` |  | NO | NOT REPOINTED (deferred) | still reads legacy shared columns; value-equal only while the KAN-712 mirror holds; would fail a provenance probe |
| 89 | `trg_meetup_rsvps_notify()` | feed/notification | FUNCTION ? | `supabase/migrations/20260915150000_meetups_notifications.sql:113` |  | NO | NOT REPOINTED (deferred) | still reads legacy shared columns; value-equal only while the KAN-712 mirror holds; would fail a provenance probe |
| 90 | `trgfn_invite_block_frozen()` | capacity/join | FUNCTION ? | `supabase/migrations/20260829080500_baseline_schema.sql:18958` |  | NO | NOT REPOINTED (deferred) | still reads legacy shared columns; value-equal only while the KAN-712 mirror holds; would fail a provenance probe |
| 91 | `trgfn_invite_block_frozen_guard()` | capacity/join | FUNCTION ? | `supabase/migrations/20260829080500_baseline_schema.sql:18974` |  | NO | NOT REPOINTED (deferred) | still reads legacy shared columns; value-equal only while the KAN-712 mirror holds; would fail a provenance probe |
| 92 | `trgfn_joinreq_block_frozen_guard()` | capacity/join | FUNCTION ? | `supabase/migrations/20260829080500_baseline_schema.sql:19029` |  | NO | NOT REPOINTED (deferred) | still reads legacy shared columns; value-equal only while the KAN-712 mirror holds; would fail a provenance probe |
| 93 | `trgfn_posts_set_geo()` | listing/other | FUNCTION ? | `supabase/migrations/20260829080500_baseline_schema.sql:19381` |  | NO | NOT REPOINTED (deferred) | still reads legacy shared columns; value-equal only while the KAN-712 mirror holds; would fail a provenance probe |
| 94 | `trgfn_roster_block_frozen_guard()` | capacity/join | FUNCTION ? | `supabase/migrations/20260829080500_baseline_schema.sql:19665` |  | NO | NOT REPOINTED (deferred) | still reads legacy shared columns; value-equal only while the KAN-712 mirror holds; would fail a provenance probe |
| 95 | `trgfn_waitlist_block_frozen_guard()` | capacity/join | FUNCTION ? | `supabase/migrations/20260829080500_baseline_schema.sql:20317` |  | NO | NOT REPOINTED (deferred) | still reads legacy shared columns; value-equal only while the KAN-712 mirror holds; would fail a provenance probe |
| 96 | `v_game_card` | listing/other | VIEW owner | `supabase/migrations/20261101120000_kan698_v_game_card_series_columns.sql:9` |  | yes | REPOINTED | shared columns now read from public.events (this migration) |
| 97 | `v_game_rating` | rating | VIEW owner | `supabase/migrations/20260829080500_baseline_schema.sql:25636` |  | yes | UNCHANGED-WITH-REASON | reads games.id only (id is not a migrated shared column) |
| 98 | `v_host_weekly_metrics` | analytics/admin | VIEW owner | `supabase/migrations/20260829080500_baseline_schema.sql:25662` |  | yes | REPOINTED | shared columns now read from public.events (this migration) |
| 99 | `v_meetup_counts` | listing/other | VIEW security_invoker=off | `supabase/migrations/20260915120000_meetups_hardening.sql:136` |  | yes | REPOINTED | shared columns now read from public.events (this migration) |
| 100 | `v_meetup_list` | listing/other | VIEW owner | `supabase/migrations/20261008140000_game_price_meetup_setting.sql:18` |  | yes | REPOINTED | shared columns now read from public.events (this migration) |
| 101 | `v_my_games` | listing/other | VIEW owner | `supabase/migrations/20260829080500_baseline_schema.sql:25858` |  | yes | REPOINTED | shared columns now read from public.events (this migration) |
| 102 | `v_rateable_after_game` | rating | VIEW owner | `supabase/migrations/20260829080500_baseline_schema.sql:26149` |  | yes | REPOINTED | shared columns now read from public.events (this migration) |

Totals: REPOINTED 11 · UNCHANGED-WITH-REASON 16 · EXCEPTION 2 (E1, E3) · NOT REPOINTED (write path) 34 ·
NOT REPOINTED (deferred) 39.

### 2.3 Edge functions and transitive readers

- `supabase/functions/*` has 4 functions: broadcast-notification, detect-country, send-export-email and
  send-push-notification. None references `games`, `meetups` or any of the listed views (grep for `games` /
  `meetups` returned 0 files). **Nothing to change.** Messages and media stay on Cloudflare and are untouched.
- Transitive: `v_meetup_list` reads `v_meetup_counts`. Both are repointed. No other view in `public` selects
  from a repointed view (local `pg_depend`).
- Flutter (`lib/`) reads these views and RPCs through the API. Shape is unchanged (section 4), so the app needs
  no change. `lib/` was not edited.

## 3. %ROWTYPE / composite users

| Object | Composite | After KAN-714 |
|---|---|---|
| `rpc_meetup_card(uuid,text)` | `meetups%rowtype` | **changed**: subtype scalars (`v_mid, v_desc, v_loc, v_hostp`) plus `public.events%rowtype` |
| `rpc_meetup_attendees(uuid,text,int,int)` | `meetups%rowtype` | **changed**: scalars `v_creator, v_vis` (read from events); no composite |
| `can_current_user_join_game(uuid,text,uuid)` | `games%rowtype` | unchanged (KAN-713 helper) |
| `can_current_user_rsvp_meetup(uuid,uuid)` | `meetups%rowtype` | unchanged (KAN-713 helper) |
| `rpc_edit_game_series_occurrence(...)` | `games%rowtype` | unchanged (write path) |
| `rpc_meetup_decide_request(uuid,uuid,text)` | `meetups%rowtype` | unchanged (write path) |
| `rpc_meetup_remove_attendee(uuid,uuid)` | `meetups%rowtype` | unchanged (write path) |
| `rpc_meetup_update(...)` | `meetups%rowtype` | unchanged (write path) |
| `kan711_events_map_game(games)` / `kan711_events_map_meetup(meetups)` | composite **argument** | unchanged (KAN-711 mirror) |

No column of `games`/`meetups` is added or dropped, so no composite changes shape.

## 4. Coverage matrix and results (local, observed)

Databases on the throwaway cluster:
- `k713`: pre-KAN-714 (KAN-710..713 applied, harness data: 5021 events = 3010 games + 2011 meetups).
- `k714a`: clone of it with KAN-714 applied, rolled back, then re-applied.
- `k713c` / `k714ac`: corrupted copies of each.

| Test | Command | Result |
|---|---|---|
| Result parity per actor (anon, a1..a7, a9, service_role, service_role+a1) | `snapshot_kan714.sql` on k713 vs k714a | 275 lines each, ERR 35 each (contract errors: 42501 for anon/svc on gated objects, 42703 for `rpc_meetup_my`); **diff empty** |
| Shape | snapshot includes column signatures; migration post-check asserts view signature md5 unchanged | equal |
| Counts / ordering / keyset / dup | snapshot cases `sorted`, `natural`, `ties`, `dup`, `keyset-p1/p2`, `filter`, `by-id` | equal (diff empty) |
| Provenance, before KAN-714 (must FAIL) | `corrupt_legacy_kan714.sql` on k713c, snapshot vs uncorrupted | **FAILS**: 187 snapshot lines differ across every repointed reader |
| Provenance, after KAN-714 (must PASS) | same on k714ac vs k714a | **1 line differs**: `rpc_games_following_joined|sample|a2` n=64 → n=0 (E3) |
| In-transaction provenance plus posture | `adversarial_kan714.sql` | pre k713: `pass=10 fail=14` (all 14 P probes fail, all 10 A pass); post k714a: **`pass=24 fail=0`** |
| Stage guard refusal | apply on a k713 clone with `trg_kan713_games_a_location` disabled | refused: `prerequisite stage missing: public.games.trg_kan713_games_a_location`, rc=3 |
| | same, with `trg_zz_kan712_events_compat_mirror` disabled | refused, rc=3 |
| | apply as a NOSUPERUSER NOBYPASSRLS role | refused: `applying role kan714_nb must be superuser or BYPASSRLS`, rc=3 |
| | after refusals | `kan714_preimage` absent, 0 KAN-714 indexes (nothing left behind) |
| Re-apply guard | second apply on k714a | refused: `already applied (public.kan714_preimage has rows)` |
| KAN-712 probes | `tests/events_p2/probes_kan712.sql` | pre `55/0`, post `55/0` |
| KAN-713 probes | `tests/events_p2_kan713/probes_kan713.sql` | pre `28/0`, post `28/0` |
| KAN-713 recursion | `recursion_kan713.sql` | pre `6/0`, post `6/0` |
| KAN-713 matrix | `matrix_kan713.sql` | 1955 cells pre and post, **diff empty**, 0 FAIL |
| Rollback | section 6 | fingerprint and snapshot diffs empty |

Provenance probe IDs (adversarial, group P). Every one fails on k713 and passes on k714a:
- **v_game_card:** P1/P2 stale legacy `public` must not leak G-pri. P3 events-public must show despite legacy private. P4 title/capacity/total_slots/start_at come from events.
- **v_my_games:** P5 shared fields, P13 creator.
- **rpc_meetup_card:** P6 hidden refusal, P11 fields.
- **rpc_meetup_attendees:** P7 hidden refusal.
- **meetup_counts:** P8 hidden counts zeroed.
- **v_meetup_list / v_meetup_counts:** P9 hidden, P10 fields.
- **v_rateable_after_game:** P14 host from events.
- **v_host_weekly_metrics:** P15 creator from events.

`rpc_sport_overview` provenance is covered by the corruption snapshot (8 + 8 lines differ pre, 0 post).

## 5. Indexes, keyset pagination, plans

Added (both `IF NOT EXISTS`, plain `CREATE INDEX` inside the migration transaction):
- `events_kan714_type_start_id_idx ON public.events (event_type, start_at, id)` is the keyset index for
  `ORDER BY start_at, id` with `WHERE (start_at, id) > (:last_start, :last_id)`.
- `events_kan714_sport_type_start_idx ON public.events (sport_id, event_type, start_at) WHERE NOT is_cancelled`
  serves the `rpc_sport_overview` counts.

**Keyset contract:** pages are ordered by `(start_at, id)` with a row-comparison cursor. `id` is the subtype id
and equals `events.id` for every row (3010/3010 games, 2011/2011 meetups locally).

EXPLAIN (ANALYZE, BUFFERS), 5021 events, as `authenticated` a1 (`explain_kan714.sql`):

| Query | Before (k713) | After (k714a) |
|---|---|---|
| Q1 `v_game_card` keyset page 1, LIMIT 25 | 24.206 ms, 5667 buf | 23.984 ms, 5830 buf |
| Q2 `v_game_card` keyset page n | 0.490 ms, 228 buf | 1.891 ms, 394 buf |
| Q3 `v_meetup_list` keyset | 18.117 ms, 2982 buf | 18.749 ms, 3104 buf |
| Q4 `rpc_sport_overview(football)` | 4.670 ms, 910 buf | 3.445 ms, 777 buf |
| Q5 `v_my_games` LIMIT 50 | 3.851 ms, 271 buf | 0.318 ms, 438 buf (index scan `events_type_start_at_idx` + `games_event_id_key`) |

Direct keyset on events (postgres):
- After: `Index Only Scan using events_kan714_type_start_id_idx`, Index Cond includes the row comparison,
  0.053 ms, 9 buffers.
- Before: incremental sort over `events_type_start_at_idx` with the row comparison as a Filter, 0.063 ms,
  20 buffers.
- Sport counts after: `Index Only Scan using events_kan714_sport_type_start_idx`, 3.725 ms.

**Plan summary, said plainly:**
- At this size the view plans are dominated by per-row visibility function calls, not by scans. Q1 and Q3
  stay seq-scan plus filter, at about the same time.
- The new keyset index is **not chosen inside the views** at 5021 rows. It is chosen for the direct events
  keyset query and for the sport counts.
- Q2 is slower in absolute terms (0.49 → 1.89 ms). The cause is the extra events join, which adds about
  166 buffers.
- No plan regressed by an order of magnitude.
- The live dataset size and distribution were not measured. Live plans must be re-checked at apply time.

## 6. Rollback

`rollback_kan714.sql` runs as one transaction, as a superuser or BYPASSRLS role:
1. Refuse unless `kan714_preimage` has exactly 11 rows.
2. EXECUTE each stored `pg_get_functiondef` text. `CREATE OR REPLACE` keeps the owner and ACL.
3. Recreate each view from its stored `pg_get_viewdef` text with the stored `reloptions`.
4. Assert that every definition, ACL, owner, secdef, config, volatility and reloptions value equals the
   pre-image.
5. `DROP INDEX IF EXISTS` on the two KAN-714 indexes.
6. `DELETE FROM kan714_preimage`. The table stays: empty, RLS on, no API grants. There is no DROP TABLE.

**Evidence (k714a: apply → rollback):**
- rc=0.
- `diff fp_pre fp_rb`: **empty**. That covers FN, VW, REL, COL, IDX, CON, TRG and POL, plus the DATA hashes.
- `diff snap_pre snap_rb`: **empty**.
- Re-apply after rollback: rc=0. A second apply is refused.

Pre-KAN-714 fingerprint (equal after rollback):
```
FN|1756ad7dfcb30ba29075c03f13fe3ee8|n=167
VW|f0f75b7ccebc9cca4748e58559535d0e|n=8
REL|bd4b19431cebe695ab01b66712c5fcba|n=107
IDX|532e1f7ad8c21f8089ab3b86771f80c8|n=55
DATA|events|4fda06f4021af3d8e41acc82f8b3b988|n=5021
DATA|games|c76c72390a190398351c05016993973c|n=3010
DATA|meetups|6668adc08594cf9b8f2a306369992ce0|n=2011
DATA|game_roster|1b8a7c908d3012f36f687af6d4cf8fb4|n=4004
DATA|meetup_rsvps|9597a5cb6968e1925f6afe283c4b3f48|n=8044
PRE|kan714_preimage|empty
```
After KAN-714, only these lines change:
- FN → d3cdfae0…
- VW → 4d44fda1…
- REL → 8cac7656…, n=109 (the pre-image table plus its pkey)
- IDX → ef6e1626…, n=57
- PRE → ROWS-PRESENT

The DATA lines are identical, so the migration changes no data.

## 7. Operations order

1. KAN-710 → KAN-711 (mirror, backfill, parity clean) → KAN-712 **stage B** (events-authoritative writes,
   compat mirror, guards) → KAN-713 (access helpers, location triggers) → **KAN-714**.
2. The KAN-714 guard checks all of the following, and refuses otherwise. On refusal nothing is left behind.
   - **Applying role:** superuser or BYPASSRLS.
   - **Not already applied:** `kan714_preimage` has no rows.
   - **KAN-712 markers enabled:** `trg_zz_kan712_events_compat_mirror`, and the games/meetups
     `trg_zz_kan712_*_guard` / `*_after_delete` triggers.
   - **KAN-713 markers enabled:** `trg_kan713_events_location`, `trg_kan713_games_a_location`/`b_joining`/`c_venue_geo`,
     `trg_kan713_meetups_a_location`/`b_joining`.
   - **KAN-712 registry populated:** `kan712_wrapped_rpcs` is non-empty.
   - **KAN-713 helper present:** `kan713_meetup_visible(uuid)` exists.
   - **events still closed:** no policy, FORCE RLS, no anon/authenticated SELECT.
   - **Typed parents:** every subtype row has a typed events parent.
   - **Owners can read events:** every repointed object's owner bypasses RLS.
   - **No drift:** the function md5 pins and view pins match.
3. Apply: `psql -v ON_ERROR_STOP=1 -f supabase/migrations/20261105100000_kan714_events_parent_reads.sql`
   under G-002's apply conditions.
4. Verify: run `fingerprint_kan714.sql` and the snapshot before and after. The DATA lines must be equal and
   the snapshot diff empty for real actors. Re-run the KAN-712/713 probes.
5. Rollback if needed: `rollback_kan714.sql`, then the fingerprint must equal the pre-apply capture.

## 8. Named exceptions

- **E1 `rpc_meetup_my()`.** The existing body references `m.starts_at`, a column that does not exist, so it
  raises 42703 before and after. It is not repointed and not fixed, because a fix would be a behaviour change
  outside this ticket. It needs its own ticket.
- **E2 `meetups.search_tsv`.** It differs from `events.search_tsv`, and this migration does not touch search
  vectors (KAN-718).
- **E3 `_can_view_game` (KAN-713).** It is a deliberate intersection: legacy predicate AND events predicate,
  "never wider". When legacy diverges from events it can only narrow. `rpc_games_following_joined` calls it,
  so under legacy corruption a2's result drops from 64 to 0. This is the single post-KAN-714 provenance diff.
  It fails closed and is owned by KAN-713, which is why KAN-714 does not repoint it.
- **E4 SECURITY INVOKER readers.** `game_slots_left`, `_can_view_game_for_join`, `can_current_user_join_game`,
  `kan711_events_map_*` and `kan711_events_parity` cannot read events, which stays closed with no API
  grants. They keep reading legacy, which the KAN-712 compat mirror holds exact. Repointing them would mean
  either opening events or converting them to DEFINER, and both are shape decisions for `cto`.
- **E5 tie-break added.**
  - `v_meetup_list` ORDER BY gains `, m.id` and `rpc_meetup_attendees` gains `, r.profile_id`. Without
    them, the order inside equal keys was undefined and could differ after the join changed.
  - The ORDER BY key sequence is asserted equal ("natural" case). Rows inside a tie group may legitimately
    reorder; a3 has 2 tie groups locally.
- **E6 `v_game_rating`.** Not changed. It reads only `games.id`.

## 9. Not covered, said plainly

1. **73 of the 102 readers are not repointed.** Their bodies were not edited:
   - 39 deferred readers: nearby (`get_nearby_games` ×2, `getnearbygames`, `getnearbymeetups`, `nearby_games`,
     `rpc_get_nearby_games` ×2), search/autocomplete (`rpc_search_entities`, `rpc_autocomplete_entities`,
     `rpc_unified_search_sectioned`), feed/notification (`active_stream`, `rpc_get_activity_feed`,
     `trg_*_notify`, `fn_*_activity_sync`), messaging (`msg_*`), admin/analytics (`admin_overview_row`,
     `get_games_needing_players`, `get_open_games_for_seeding`), slots and joinability helpers, frozen guards.
   - 34 write or gate paths: create, update, cancel, reschedule, booking, join, rate, settle, invite, rsvp.

   Today they return events-equal values only because the KAN-712 compat mirror keeps legacy exact. **They
   would fail the provenance probe.** The ticket's "existing consumers" scope is therefore incomplete.
2. **55 of the 102 manifest objects do not exist in the local harness**, so they were never executed here.
   The local baseline is partial. This includes most of the deferred list above. Their file:line comes from
   the migration scan only.
3. Plans were measured on 5021 synthetic events, not live volume or distribution.
4. Live catalogue pins were not checked against live. The md5 pins were authored against the local
   catalogue, which equals the repo text. If live has drifted, the migration refuses to apply. That is the
   intended behaviour, but whether live will pass is unknown until apply time.
5. No Jira transition was made from this worktree, and nothing was committed or pushed (brief). The route is
   PEER: the reviewer must be another `backend-N`.

## 10. Local run output (verbatim summary lines)

```
snapshot k713   : #LINES 275 ERR 35
snapshot k714a  : #LINES 275 ERR 35          diff: empty
snapshot rb     :                             diff vs pre: empty
fingerprint rb  :                             diff vs pre: empty
corrupt pre     : 187 differing snapshot lines (provenance FAILS before KAN-714)
corrupt post    : 1 differing line  rpc_games_following_joined|sample|a2 n=64 -> n=0  (E3)
adversarial k713 : #SUMMARY|pass=10|fail=14
adversarial k714a: #SUMMARY|pass=24|fail=0
probes_kan712   : #TOTAL|pass=55|fail=0   (pre and post)
probes_kan713   : #SUMMARY|pass=28|fail=0 (pre and post)
recursion_kan713: #SUMMARY|pass=6|fail=0  (pre and post)
matrix_kan713   : #CELLS|1955 pre and post, diff empty, 0 FAIL
guard           : refused x3 (KAN-713 marker, KAN-712 marker, non-bypass role); re-apply refused
```
