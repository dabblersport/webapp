# KAN-711 — Events P1 migration contract

**Status: AUTHORED ONLY, NOT APPLIED. needs-ops.** Nothing here has touched Supabase project
`wtncuzcskpigqpmnxwws`. Everything was executed only on a local, throwaway PostgreSQL 16
cluster against a stand-in harness (see "Local verification" below).

**Every decision is PROVISIONAL (E1 absent).** KAN-710 (E1, the canonical Events model) is not on
Alpha. This contract fixes the phase-1 shape so the parent can be backfilled now. All of it is
re-decided when E1 lands. The mapping lives in exactly two functions
(`kan711_events_map_game` and `kan711_events_map_meetup`), which the mirror, the backfill and the
parity view all share. Changing a rule therefore means changing one function.

**Route:** PEER (schema_change). The reviewer must be another `backend-N`.
**Running the backfill** (stage 3 `CALL`) writes `event_id` on existing live rows. That is
user-data mutation, so it needs a separate CEO/ops authorisation. Applying migrations 1 to 3 does
**not** run it.

## Files

| File | Kind | Purpose |
|---|---|---|
| `supabase/migrations/20261102100000_kan711_events_parent_schema.sql` | migration 1 | `public.events`, `games.event_id`, `meetups.event_id`, deferred NOT VALID FKs |
| `supabase/migrations/20261102110000_kan711_events_mirror_triggers.sql` | migration 2 | mapping functions, one-way transactional mirror, deferred integrity triggers |
| `supabase/migrations/20261102120000_kan711_events_backfill.sql` | migration 3 | checkpoint and exception tables, parity view, batch/run/reset/validate routines. **Does not run the backfill** |
| `supabase/tests/events_p1/parity_kan711.sql` | read-only report | populations, parity by issue and field, checkpoint, exceptions, series and request cross-checks, verdict |
| `supabase/tests/events_p1/rollback_kan711.sql` | runbook | reverses all three migrations; drops only KAN-711 objects |
| `supabase/tests/events_p1/probes_kan711.sql` | probes | 82 assertions, BEGIN…ROLLBACK, negative controls |
| `supabase/tests/events_p1/local_harness_kan711.sql`, `local_seed_kan711.sql` | LOCAL ONLY | stand-in schema and seed rows. **Never run against Supabase** |

## Order of application

1. Migration 1. It creates the parent and the link columns and takes no row scans. Its preconditions
   are that the applying role is a superuser or has BYPASSRLS, and that `public.events` does not
   exist.
2. Migration 2. The mirror is live from this commit, so every new or touched legacy row is captured
   from here on. **It must be installed before the backfill**, so that no row changes between being
   backfilled and being captured.
3. Migration 3. It installs the tooling only.
4. **[CEO/ops authorised]** `CALL public.kan711_events_backfill_run(500);`
   - It commits per batch and is resumable from its checkpoint.
   - `p_max_batches` limits a single session.
   - Rows that fail go to `events_backfill_exceptions` without stopping the run.
5. Run `parity_kan711.sql`. The verdict must be `parity_ok = t`.
6. `SELECT public.kan711_events_validate_links();`
   - It refuses, and returns `validated: false`, unless all three are zero: parity rows, unresolved
     exceptions and unfinished kinds.
   - When those are zero, it validates both FKs and adds and validates
     `CHECK (event_id IS NOT NULL)` on both legacy tables.
7. If needed, `rollback_kan711.sql`, then `supabase migration repair --status reverted …`.

## Classification table

Classes:
- **copied**: the same name and meaning, taken verbatim.
- **alias**: the same meaning under a different name.
- **conflict**: the legacy tables disagree; the resolution is stated.
- **not-copied**: no events column in phase 1.

`NN` means NOT NULL.

| events column | games source | meetups source | events nullability | class | null / invalid handling |
|---|---|---|---|---|---|
| `id` | `id` NN | `id` NN | NN, PK | copied | Same uuid. No new ids are minted. An id present in both tables raises `kan711_event_type_mismatch` |
| `event_type` | literal `'game'` | literal `'meetup'` | NN, CHECK | derived | Immutable (`kan711_event_identity_immutable`) |
| `title` | `title` nullable | `title` NN (3–80 / 3–120) | nullable | conflict | Copied as is. A null game title stays null and is not synthesised |
| `description` | — | `description` | nullable | copied (meetup) | NULL for games |
| `creator_profile_id` | NN | NN | NN | copied | — |
| `creator_user_id` | NN (forced from the profile by `trg_games_set_host`) | NN (not forced) | NN | copied | Meetups can drift from the profile's user. See Risks R2 |
| `sport_id` | NN | nullable | nullable | conflict | Copied. Null for meetups that have no sport |
| `start_at` | NN | NN | NN | copied | — |
| `end_at` | NN | nullable | nullable | conflict | Copied. **Never inferred** from start_at or duration |
| `capacity` | NN, CHECK 2..64 | nullable (unlimited), CHECK > 0 | nullable, CHECK null or > 0 | conflict | Copied raw. Null stays null (unlimited). The 2..64 bound stays enforced on games only |
| `venue_id` | `venue_id` → venues | `venue_id` → venues | nullable | conflict (see C7) | Copied raw. `games.venue_space_id` and `meetups.meta->>'venue_space_id'` are **not** copied |
| `geo_location_id` | NN (but ON DELETE SET NULL) | nullable | nullable | copied | — |
| `area_id` | NN | nullable | nullable | copied | — |
| `location_name` | — | `location_name` | nullable | copied (meetup) | NULL for games, not inferred from the venue |
| `is_indoor` | — | `is_indoor` | nullable | copied (meetup) | NULL for games, not inferred from the space |
| `listing_visibility` | {public, followers, private} | {public, circle, invite, link, hidden} | NN, CHECK = union of 7 | conflict (C1) | Raw value kept, **not normalised** |
| `join_policy` | `join_policy` {open, request, invite, link} | `rsvp_policy` {open, request, invite, link, closed} | NN, CHECK = union of 7 | alias + conflict (C2) | Raw value kept |
| `min_skill`, `max_skill` | nullable, 1..10 | nullable | nullable | copied | — |
| `joining_rule`, `cost_cover` | NN + logic CHECK | NN + logic CHECK | NN + the same logic CHECK | copied | The CHECKs are identical on both, so a refusal cannot happen |
| `is_cancelled` | NN | NN | NN | copied | — |
| `cancelled_at` | nullable | — | nullable | copied (game) | NULL for meetups. **Not inferred** from updated_at |
| `cancelled_reason` | nullable | — | nullable | copied (game) | NULL for meetups |
| `request_id` | nullable; unique (creator_user_id, request_id) | nullable; unique (creator_user_id, request_id) | nullable; unique (event_type, creator_profile_id, request_id) | conflict (C9) | See R2 |
| `created_at`, `updated_at` | NN | NN | NN, **no default** | copied | Copied, never `now()`. The backfill does not bump legacy updated_at |
| `search_tsv` | trigger-maintained | trigger-maintained | nullable | copied | Copied verbatim and not recomputed |

**Not copied in phase 1.** These remain only on the legacy tables, which stay authoritative:

- **games:** `game_type`, `venue_space_id`, `allow_spectators`, `rules` (including min/max players),
  `squad_id`, `sport_specific_data`, `allows_waitlist`, `sport_variant_id`, `bench_slots`,
  `price_aed`, `series_id`.
- **meetups:** `vibe_key`, `meta` (including `venue_space_id`), `host_actor_id`, `members_only`.

## Conflicts

- **C1 — visibility domains.** The domains are disjoint apart from `public`. Events stores the raw
  value under a CHECK that is the union of both, so the mirror can never refuse a value a legacy
  table accepted. Mapping these to one canonical audience model is E1's decision.
- **C2 — join_policy vs rsvp_policy.** They mean the same thing, so this is an alias. `closed` is
  meetup-only. `games_join_policy_chk` allows `circle`, `squad` and `closed`, but the stricter
  `games_join_policy_check` limits games to four values. The events CHECK takes the 7-value union,
  which is the wider of the two.
- **C3 — title nullability.** Games allow NULL and meetups require 3+ characters, so events allows
  NULL. No placeholder title is invented. The UI fallback stays a client concern.
- **C4 — capacity.** Games require 2..64 and meetups allow null (unlimited) or > 0. Events stores
  `null or > 0`, and the game-specific bound stays on `games`.
- **C5 — end_at null.** Meetups allow an open end. It is copied as NULL, and no duration is assumed.
- **C6 — min/max players vs capacity.** Games keep player bounds inside `rules` jsonb, which is
  separate from `capacity`. They are **not** extracted or reconciled with capacity in phase 1,
  because extracting from jsonb would make the mirror depend on the shape of a rules document.
  `rules` stays authoritative on `games`.
- **C7 — Venue/Space mix (`meetups.meta.venue_space_id`, `fn_meetups_sync_joining_rule`).**
  - Baseline `20260829080500_baseline_schema.sql:6340` computes
    `COALESCE(NEW.venue_id, (NEW.meta->>'venue_space_id')::uuid)` and looks the result up in
    **`venue_spaces`**.
  - `meetups.venue_id` has an FK to **`venues`**, so a real venue id can never match a space id, and
    the lookup silently falls back to `joining_rule = 'free'` whenever `venue_id` is set.
  - Events copies `venue_id` raw, because the FK guarantees it is a venue. The `meta` space id is not
    copied, and `joining_rule` and `cost_cover` are copied **as the legacy trigger computed them**.
  - The trigger is reported here and **not fixed**: that is legacy behaviour and outside this
    ticket's allowed paths.
- **C8 — `rpc_booking_hold_for_meetup` reads `m.owner_user_id`** (baseline `:11183`). Meetups has no
  such column, so as written the RPC would raise at runtime.
  - **Report only.** It is not touched, it is a booking surface (forbidden), and the live body is
    unknown to this seat.
  - Under T-058 the live body must be read with `pg_get_functiondef` before anyone relies on it.
- **C9 — request uniqueness.**
  - Legacy keys on `(creator_user_id, request_id)` per table. Events keys on
    `(event_type, creator_profile_id, request_id)`.
  - Games force the user from the profile, so the two keys are equivalent for games.
  - Meetups do not force it, so two meetups with the same profile and request but different users
    are legal in legacy and collide in events. See R2.
- **C10 — `trgfn_meetups_outbox` reads `new.owner_user_id`** (baseline `:19094`, AFTER INSERT on
  meetups). As written, every meetup INSERT would fail.
  - KAN-711 does not touch it. The mirror runs alongside it and never calls emit_event.
  - The harness installs it with `creator_user_id` so that local inserts can run at all.
  - **Ops must read the live body before apply.** If it is as the repo says, meetup creation is
    already broken in production regardless of KAN-711.

## Series uniqueness

Events carries no `series_id` in phase 1.

- `games_series_id_start_at_key` (unique `(series_id, start_at) WHERE series_id IS NOT NULL`)
  **remains the enforcement**.
- The mirror copies `start_at` in the same transaction, so events cannot drift from it.
- `parity_kan711.sql` section 7 re-checks this by joining games to events.
- Probe P13 shows the legacy index still refusing a duplicate after the mirror is installed.
- **Phase 2 must add `series_id` to events with an equivalent partial unique index before games
  stop being authoritative.**

## Risks

- **R1 — a mirror failure aborts the user's write.**
  - The mirror runs in the user's transaction. That is the point: it is transactional and cannot
    drift.
  - The events CHECKs are union domains, so for valid legacy rows the only reachable failure is R2.
  - The cost of an unexpected events-side error is a failed create or edit, which is visible and
    safe, rather than silent divergence.
- **R2 — meetup profile/user drift and request conflict.**
  - A meetup can share `(creator_profile_id, request_id)` with another meetup that has a different
    `creator_user_id`.
  - During the backfill that row lands in `events_backfill_exceptions` as 23505, and the batch
    continues (probe P11).
  - During a live write it aborts that write.
  - Parity section 8b lists every such pair before or after the run. **Run it before apply.**
- **R3 — FK ordering under `SET CONSTRAINTS ALL IMMEDIATE`.**
  - Postgres fires triggers in name order, and the internal `RI_ConstraintTrigger_*` sorts before
    `trg_kan711_*`.
  - Under IMMEDIATE, a legacy INSERT therefore checks the event FK before the mirror has written the
    event, and fails.
  - The production default is DEFERRED, and a grep found no repo code using `SET CONSTRAINTS`.
  - **Reviewer decision:** accept this, or rename the mirror triggers to sort first (for example
    `"AAA_kan711_…"`).
- **R4 — locks per batch.**
  - Each batch takes `SHARE ROW EXCLUSIVE` on the table it is filling, which blocks concurrent
    writes but not reads. It disables and re-enables the non-KAN-711 UPDATE triggers for that batch
    only (ACCESS EXCLUSIVE, briefly).
  - With batch 500 and a commit per batch, the window is short. Run off-peak.
  - Trigger modes are recorded and restored exactly (P4).
- **R5 — BYPASSRLS required.**
  - meetups is FORCE RLS. The SECURITY DEFINER functions must be owned by a role that bypasses RLS,
    or the integrity check would treat invisible meetups as missing.
  - All three migrations assert this.
- **R6 — live catalogue drift (T-058).**
  - The harness copies repo DDL, not the live catalogue.
  - Before apply, ops must diff the live `games` and `meetups` columns, their CHECKs and their
    triggers (`pg_get_functiondef`, `pg_get_triggerdef`) against the harness header.
  - Column **order** must match, because the map functions are positional over `public.events`,
    which this migration creates. Legacy order does not matter, since the functions reference
    columns by name.
- **R7 — legacy trigger bodies unknown to this seat** (C8, C10). Confirm them live.
- **R8 — the backfill's ALTER TABLE needs no pending trigger events.**
  - Each batch runs in its own transaction from the `run` procedure, so this holds in operations.
  - Calling `kan711_events_backfill_batch` inside a larger transaction that has already queued
    deferred events on that table will raise "pending trigger events".

## Rollback

Run `rollback_kan711.sql`. It is a single transaction with `lock_timeout 5s` and no `CASCADE`,
followed by post-condition asserts. It drops these objects, in order:

1. the validate CHECKs and FKs;
2. the triggers;
3. the stage 3 routines, view and tables;
4. the stage 2 functions;
5. the `event_id` columns and their indexes;
6. `events`.

Legacy data is untouched, because events only ever held copies. It is destructive to the mirror,
so on production it is a CEO-authorised step.

## Local verification (what actually ran)

PostgreSQL 16, throwaway cluster `/tmp/kan711_pg` on port 54399, superuser `postgres`. The run
order was:

1. harness;
2. seed (6 games and 6 meetups covering the edge cases);
3. migrations 1 to 3 (all post-condition asserts passed);
4. `probes_kan711.sql`: **82/82 PASS**;
5. `CALL kan711_events_backfill_run(4)`;
6. `parity_kan711.sql`: populations 6/6/6 and 6/6/6, every issue count 0,
   `verdict parity_ok = t`;
7. `validate_links()`, which returned `{"validated": true, ...}`;
8. `rollback_kan711.sql`: exit 0, post-conditions passed, and the legacy row hash was unchanged
   (`b575547008743d37f6d32f5f10cbf477` before and after);
9. migrations 1 to 3 re-applied, then the probes again: **82/82 PASS**.

**Limitations.**
- The harness is not the live schema. PostGIS, unaccent, sports and venues validation, persona and
  frozen guards, and the notification fan-out are stubbed.
- Data volume is 12 rows, so lock duration and batch timing on production volumes are **not
  measured**.
- Supabase-specific roles, grants and default privileges are imitated, not real.
