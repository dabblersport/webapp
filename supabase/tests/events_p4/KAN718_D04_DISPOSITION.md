# KAN-772 (KAN-718 D04) — disposition of the 34 D01 "B15 open" functions

Source list: `supabase/tests/events_p2/KAN714_READ_MANIFEST.md` §"Open functions (34)" (row numbers below are its `#`).
Fix condition (Codex, KAN-772 comments 15160 / 15187): replace each open read, or name it with a bounded blocker.
"Not in D02 §3" is not used as a blocker anywhere below.

Migration: `supabase/migrations/20261104110100_kan718_d04_last_shared_field_reads.sql` (authored, not applied).
Proof: `supabase/tests/events_p4/kan718_d04_last_reads.sql` checks T2–T5 and D01–D12 (they fail on a chain without the migration).
Rollback: `supabase/tests/events_p4/kan718_d04_rollback.sql` (pg_get_functiondef pre-images).
Local harness for baseline-only functions: `supabase/tests/events_p4/local_harness_kan772.sql`.

Totals: **CONVERTED 8 · NO LEGACY READ (proved, no change needed) 2 · RETIRE 2 · BLOCKER 22** (8 readers broken on every chain:
#5 #6 #8 #9 #11 #12 #25 #29; 9 write RPCs absent from the local chain; 5 trigger functions absent from the local
chain; RETIRE #20 #21 per KAN-812). 8 + 2 + 2 + 22 = 34.
> Stale 2026-11-04: most BLOCKER rows are now converted by follow-ups; see `KAN718_HANDOFF.md` (b).

## Table

| # | Function | Disposition | Evidence / blocker (specific) | Owner |
|---|---|---|---|---|
| 1 | `_recent_activity_score(uuid,integer)` | **CONVERTED** | `start_at` from events (INVOKER branch pattern, KAN-727 B08). D09, T2 | backend (this ticket) |
| 2 | `_user_hosted_game(uuid,uuid)` | **CONVERTED** | `creator_user_id` from events (INVOKER branch). D01 (follows events), D02 (client role: no 42501, same answer), T2, T4 (rpc_rate_venue's host gate) | backend (this ticket) |
| 3 | `game_is_joinable(uuid)` | **CONVERTED** | `is_cancelled`, `start_at` from events (INVOKER branch); unknown game still NULL. D08, T2 | backend (this ticket) |
| 4 | `get_games_needing_players()` | **CONVERTED** | `sport_id, area_id, capacity, is_cancelled, start_at` from events; JSON keys unchanged. D10, T2, T3 | backend (this ticket) |
| 5 | `get_nearby_games(double precision,double precision,double precision)` | **BLOCKER — broken on every chain** | body reads `g.lat`, `g.lng`, which no migration in the repo creates on `games`; also needs PostGIS. Every call errors today, so there is no behaviour to preserve; a "conversion" is a rewrite. Needs a retire-or-rewrite decision recorded in the KAN-719 removal manifest | po (ticket: retire/rewrite decision) → cto if DROP |
| 6 | `get_nearby_games(double precision,double precision,integer)` | **BLOCKER — broken on every chain** | same as #5 (`g.lat`, `g.lng`) | po → cto if DROP |
| 7 | `get_open_games_for_seeding()` | **CONVERTED** | `sport_id, area_id (→ city), capacity, is_cancelled, start_at` from events; keys, DISTINCT ON / random / LIMIT unchanged. D11, T2, T3 | backend (this ticket) |
| 8 | `getnearbygames(double precision,double precision,double precision)` | **BLOCKER — broken on every chain** | reads `g.sport`, `g.lat`, `g.areaid`, `g.geolocationid` and `public.geolocations` — none exist in the repo schema | po → cto if DROP |
| 9 | `getnearbymeetups(double precision,double precision,double precision)` | **BLOCKER — broken on every chain** | reads `m.starts_at`, `m.lat` and `public.geolocations` — none exist in the repo schema | po → cto if DROP |
| 10 | `meetup_counts(uuid)` | **CONVERTED** | visibility gate `can_view_owner(e.creator_user_id, e.listing_visibility)` from events (as B02's `v_meetup_counts`). D03 (stranger loses counts when events narrows; owner keeps them), D04 (blocked user 0/0/0), T2, T3 | backend (this ticket) |
| 11 | `nearby_games(double precision,double precision,integer,text,integer,integer)` | **BLOCKER — broken on every chain** | reads `g.sport`, which does not exist on `games` (it is `sport_id`) | po → cto if DROP |
| 12 | `rpc_autocomplete_entities(text,text[],text,integer)` | **BLOCKER — broken on every chain** | its games branch reads `g.sport` from `games` and the default scope includes games, so the default call errors | po (ticket: rewrite on events or retire) |
| 13 | `rpc_challenge_spawn_game(uuid,timestamptz,uuid)` | **NO LEGACY READ — no change needed** | games appears only as its `INSERT` target (KAN-712 guarded write path; not changed, no dual write); `title` is `public.challenges.title`. T5 | — |
| 14 | `rpc_create_game(26 args)` | **CONVERTED** | both idempotency lookups key on `events (creator_user_id, request_id)`; INSERT still inside `rpc_create_game_legacy_v2` via the KAN-712 guard; the `unique_violation` handler still keys on the constraint name the guard re-raises. D05 (replay served from events), D06 (non-creator never served), T2, T3 | backend (this ticket) |
| 15 | `rpc_create_meetup(21 args)` | **CONVERTED** | same as #14 for meetups. D07, T2, T3 | backend (this ticket) |
| 16 | `rpc_decide_join_request(uuid,boolean)` | **BLOCKER — absent from the local chain** | defined only in baseline `20260829080500`; not on the local chain, so no test can run against it. Its legacy read is the host gate inside a write path (KAN-712 contract) | backend (follow-up via po: local harness of the baseline definition + write fixtures, then convert) |
| 17 | `rpc_invite_user(uuid,uuid)` | **BLOCKER — absent from the local chain** | as #16 (host gate in a write path; baseline only) | backend (follow-up via po) |
| 18 | `rpc_join_game(text,uuid,uuid)` | **NO LEGACY READ — no change needed** | `SELECT * INTO g FROM games … FOR UPDATE` is a row lock; `g` is never read. Every decision comes from `can_current_user_join_game` and `game_slots_left` (both events, B08/B15). D12: events capacity full → `waitlisted` while legacy capacity says 10 | — |
| 19 | `rpc_meetup_decide_request(uuid,uuid,text)` | **BLOCKER — absent from the local chain** | latest def `20260915120000` (meetups_hardening); not on the local chain; rowtype read of `meetups` inside a write path | backend (follow-up via po) |
| 20 | `rpc_meetup_invite_user(uuid,uuid,timestamptz)` | **RETIRE (class B, DROP FUNCTION) — not a Z01 blocker (KAN-802)** | baseline-only (baseline:13792; ACL only at 20260915120000:749-750); host gate reads nonexistent meetups.owner_user_id → 42703 on every chain; no caller in lib/ or supabase/functions on Alpha/main/Canary; dropped after Z01 per KAN-812 | backend (follow-up via po) |
| 21 | `rpc_meetup_mint_link(uuid,timestamptz,integer)` | **RETIRE (class B, DROP FUNCTION) — not a Z01 blocker (KAN-802)** | baseline-only (baseline:13815; ACL only at 20260915120000:752-753); host gate reads nonexistent meetups.owner_user_id → 42703 on every chain; no caller in lib/ or supabase/functions on Alpha/main/Canary; dropped after Z01 per KAN-812 | backend (follow-up via po) |
| 22 | `rpc_meetup_remove_attendee(uuid,uuid)` | **BLOCKER — absent from the local chain** | latest def `20260915120000`; rowtype read in a write path | backend (follow-up via po) |
| 23 | `rpc_meetup_rsvp(uuid,text,uuid,uuid)` | **BLOCKER — absent from the local chain** | latest def `20260912190747`; gate in a write path | backend (follow-up via po) |
| 24 | `rpc_meetup_set_attendee(uuid,uuid,text)` | **BLOCKER — absent from the local chain** | baseline only; host gate in a write path | backend (follow-up via po) |
| 25 | `rpc_meetup_visible()` | **BLOCKER — broken on every chain** | reads `m.starts_at`, `m.visibility`, `m.owner_user_id` — none exist on `meetups` (meetups_hardening `20260915120000` records that the baseline bodies reference non-existent columns) | po → cto if DROP |
| 26 | `rpc_mint_join_link(uuid,timestamptz,integer)` | **BLOCKER — absent from the local chain** | baseline only; host gate in a write path | backend (follow-up via po) |
| 27 | `rpc_recreate_from_game(uuid,boolean)` | **BLOCKER — absent from the local chain** | baseline only; reads the source game to build a new one (write path) | backend (follow-up via po) |
| 28 | `rpc_remove_player(uuid,uuid)` | **BLOCKER — absent from the local chain** | baseline only; host gate in a write path | backend (follow-up via po) |
| 29 | `rpc_search_entities(text,text[],text,integer)` | **BLOCKER — broken on every chain** | games branch reads `g.sport` from `v_game_card` (which exposes `sport_key`, not `sport`) and `gm.search_tsv` from games; unconditional `RETURN QUERY`, so every call errors. Also `events_set_search_tsv` (unaccent_immutable) ≠ `trg_games_set_search_tsv` (unaccent): a rewrite must decide which tsv is canonical | po (ticket: rewrite on events or retire) |
| 30 | `trgfn_invite_block_frozen_guard()` | **BLOCKER — absent from the local chain** | trigger function; latest def baseline / `20261013135000` (revoke only); not on the local chain; write-side guard reading `g.creator_user_id`. D02 §5 condition 1 | backend (follow-up via po) |
| 31 | `trgfn_joinreq_block_frozen_guard()` | **BLOCKER — absent from the local chain** | as #30 | backend (follow-up via po) |
| 32 | `trgfn_posts_set_geo()` | **BLOCKER — absent from the local chain** | as #30; reads `g.area_id`, `g.geo_location_id` | backend (follow-up via po) |
| 33 | `trgfn_roster_block_frozen_guard()` | **BLOCKER — absent from the local chain** | as #30 | backend (follow-up via po) |
| 34 | `trgfn_waitlist_block_frozen_guard()` | **BLOCKER — absent from the local chain** | as #30 | backend (follow-up via po) |

## Notes

- "Absent from the local chain" means the function is not created by any migration the local cluster replays
  (`KAN714_READ_MANIFEST.md` column `Local = no`), so a conversion could not be shown to FAIL before and PASS after.
  Converting them blind would violate "demonstrate each probe failing before it counts". They also sit inside write
  paths governed by the KAN-712 contract (no dual writes), which is the second reason they were not touched here.
- "Broken on every chain" was established by searching every file under `supabase/migrations/` for an `ADD COLUMN` or
  `CREATE TABLE` of the named columns/tables; none exists. These bodies cannot run today on any database built from
  this repository.
- The three INVOKER conversions (#1, #2, #3) keep the pre-image read in their no-events-privilege branch, exactly as
  KAN-727 B08 did for `game_slots_left`; that branch is retired with the legacy columns (KAN-719 Z01).
- D02 re-scan on the fixed chain: the eight converted functions move from `open` to `converted`
  (A2: converted 27→35, open 26→18; A8 `functions_open` 29→21). A8 stays `DELETION BLOCKED` because of the
  remaining items above and the KAN-712 inner write paths, which are outside D01's 34.
- Found while scanning, not in D01's 34 and not changed: `_game_belongs_to_venue(uuid,uuid)` and
  `rpc_booking_cancel(uuid)` are classed `open` by D02 on the local chain. They need a disposition of their own.
