# KAN-718 D09 — final duplicate-count, parity and invariant precheck

Ticket KAN-777 (Epic KAN-708, Events P4). Companion to `kan718_d09_parity_precheck.sql`.
**Status: authored. Executed on a LOCAL throwaway Postgres 16 only. Nothing was applied to, or read from,
production.** Whether the real database passes is not known until the authorised operator runs it there.

## What it is for

The destructive step (phase 4, KAN-718: dropping the legacy mirror columns) must not start until this script
reports `d09_ok = true` and every `BLOCK` row is `0`. It is **read-only**: one `BEGIN TRANSACTION READ ONLY`,
no temp tables, ends in `ROLLBACK`. A write inside it fails with `25006`.

## How to run (on a target the operator is authorised to read)

```
psql "$TARGET" -v ON_ERROR_STOP=1 -P pager=off -f supabase/tests/events_p4/kan718_d09_parity_precheck.sql
```

Run as a role that is superuser or `BYPASSRLS` (`meetups` is `FORCE RLS`, `events` is closed to API roles).
Any other role is refused by the guard instead of undercounting. The script stands alone: it does not use
`kan711_events_parity` or the KAN-711 mapping functions, so a defect there cannot hide a mismatch here.

## What it checks

| Group | Checks (BLOCK = must be 0) |
|---|---|
| Counts | `games` = game events; `meetups` = meetup events; events total = games + meetups |
| Duplicates | `events.id`; `games.event_id`; `meetups.event_id`; event linked from both subtypes; id in both tables; `(event_type, creator_profile_id, request_id)`; `(series_id, start_at)` on games |
| Identity / links | every legacy row has an events row of the same id; no events row without a subtype; `event_id` not null and equal to `id`; `event_type` matches the subtype; no dangling `event_id`; both `*_event_id_fkey` present and VALID; meetup events carry no `cancelled_at`/`cancelled_reason`; `updated_at >= created_at` and `end_at > start_at`; no unresolved `events_backfill_exceptions` |
| Per-field parity (23 fields, per subtype) | `event_type`, `title`, `creator_profile_id`, `creator_user_id`, `sport_id`, `start_at`, `end_at`, `capacity`, `venue_id`, `geo_location_id`, `area_id`, `listing_visibility`, `join_policy` (= `meetups.rsvp_policy`), `min_skill`, `max_skill`, `joining_rule`, `cost_cover`, `is_cancelled`, `cancelled_at`, `cancelled_reason`, `request_id`, `created_at`, `updated_at`. `IS DISTINCT FROM`, so NULL = NULL is parity and an invented value is a mismatch. One row per mismatching field |
| Null preservation | NULL counts of `games.title`, `meetups.end_at`, `meetups.capacity`, meetup `sport/area/geo` equal on both sides |
| Known conflicts (INFO, reported, **not fixed**) | meetup-only visibilities (`circle/invite/link/hidden`); `rsvp_policy = closed`; `meta.venue_space_id` not copied; NULL game title; NULL meetup `end_at` and `capacity`; meetup `creator_user_id` ≠ profile `user_id` |

The last result row (`verdict`) gives `games_with_field_mismatch`, `meetups_with_field_mismatch`,
`missing_or_orphan`, `unlinked_or_wrong_link` and `d09_ok`.

## Evidence (local throwaway PG 16, harness `events_p1/local_harness_kan711.sql`)

Setup: harness, one game + one meetup (meetup has NULL `end_at`, NULL `capacity`), then KAN-710
(`20261101140000`), KAN-711 triggers (`20261102110000`) and backfill definition (`20261102120000`).

1. **Before backfill** (events empty): `d09_ok = f`; BLOCK rows non-zero: `count.games_eq_events 1`,
   `count.meetups_eq_events 1`, `count.events_eq_sum 2`, `inv.game_missing_event 1`,
   `inv.meetup_missing_event 1`, `inv.game_event_id_null 1`, `inv.meetup_event_id_null 1`, plus the meetup null-preservation rows.
   The precheck refuses a database that has not been mirrored.
2. **After `CALL public.kan711_events_backfill_run(500)`**: counts 1 / 1 / 1 / 1 / 2 (games, game events,
   meetups, meetup events, events total); all 28 BLOCK rows `0`; INFO `known.null_end_meetup 1`,
   `known.null_cap_meetup 1`; verdict
   `games_with_field_mismatch 0 | meetups_with_field_mismatch 0 | missing_or_orphan 0 | unlinked_or_wrong_link 0 | d09_ok t`.
3. **Read-only proof**: md5 of `events`, `games`, `meetups` before and after the run are identical
   (`5ed57679…`, `981e5165…`, `50f222e2…`); nothing to roll back, data intact.
4. **Tampered copy** (template copy with mirror triggers bypassed; `tamper777`: edited event title, invented
   meetup capacity, widened meetup visibility, an orphan events row, a lost `meetups.event_id`): the run flags
   `field.games.title 1`, `field.meetups.capacity 1`, `field.meetups.listing_visibility 1`,
   `inv.event_orphan 1`, `inv.meetup_event_id_null 1` and the count rows; `d09_ok = f`.
   KAN-710's own `events_meetup_cancel_null` CHECK refused the attempt to put a `cancelled_reason` on a meetup event,
   so that invariant is enforced twice.

## Limitations (named, not hidden)

- **Not run against production.** Pass/fail on the real data is unknown until the operator runs it. Only the
  KAN-710/711 migrations were loaded locally; KAN-712 (write contract / cutover) and KAN-713 (access helpers)
  were not, so the precheck was not exercised against rows written through the KAN-712 contract.
- The harness is a stand-in for the live schema (see `events_p1/local_harness_kan711.sql` header); a column or
  trigger that exists only on live is not covered.
- It checks the **mirror columns that exist today**. It does not cover subtype-only columns (`games.rules`,
  `meetups.description`, `meetups.meta`, `location_name`, `is_indoor`, `squad_id`, `price_aed`, `bench_slots`, …)
  because those never move to `events`.
- `search_tsv` is deliberately not compared (derived by KAN-710, not copied).
- A point-in-time read: a legacy write that lands after the run is not seen. Run it inside the freeze window.

## C3 — consumers, compatibility and rollback (statement for the reviewer)

- **Consumers of slated columns:** this script does not prove there are none. It proves data parity only.
  Whether any supported consumer (old app builds, RPCs, views, edge functions, the Dart models) still reads a
  column phase 4 would drop is a separate inventory (`events_p2/KAN712_MUTATION_INVENTORY.md`,
  `KAN715_ACTIVE_CALL_SITES.md`). **Deletion stays blocked until that inventory is signed off and this precheck is green**;
  no pending dependency may be reported as retired on the strength of this script alone.
- **Rollback:** the script is read-only, so running it cannot change data. Post-cutover rollback of the
  destructive step is not defined here; it must preserve rows written to `events` after cutover (they are
  authoritative) and is KAN-718's to define before the drop is applied.
- **Applied vs authored:** authored only. Applied: nothing. No migration is part of this ticket.

## Known conflicts (reported, not fixed — none is a blocker for this precheck)

Visibility vocabularies differ (games `public/followers/private`, meetups `public/circle/invite/link/hidden`);
`join_policy` (games) vs `rsvp_policy` (meetups, includes `closed`); `title`, `capacity`, `end_at` nullability
differs per subtype; `min/max_skill` integer in legacy vs smallint in `events`; `meetups.meta.venue_space_id`
has no parent column; `trgfn_meetups_outbox` in the repo reads `NEW.owner_user_id`, which `meetups` lacks
(the harness works around it; the live body is unknown to this author).
