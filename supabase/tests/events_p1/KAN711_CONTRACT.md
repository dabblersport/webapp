# KAN-711 — Events P1 migration contract

**Status: AUTHORED ONLY, NOT APPLIED. needs-ops.** Nothing here has touched Supabase project
`wtncuzcskpigqpmnxwws`. Everything was executed only on a local, throwaway PostgreSQL 16.15
cluster against a stand-in harness (see "Local verification" below).

**Built on KAN-710.** The parent schema is KAN-710's
`supabase/migrations/20261101140000_kan710_events_parent_schema.sql` (cited below as `KAN-710:<line>`).
KAN-711 creates no table column, constraint or integrity trigger on `events`, `games.event_id` or
`meetups.event_id`. It adds only:

- the one-way transactional mirror (games/meetups → events);
- one non-integrity BEFORE UPDATE trigger on `events`, `trg_kan711_events_keep_updated_at`, which
  keeps the parent's `updated_at` equal to the exact legacy value on mirror and backfill writes
  (see "updated_at" below);
- the resumable backfill tooling, the parity view and the exception/checkpoint tables;
- two `CHECK (event_id IS NOT NULL)` constraints, added only by `kan711_events_validate_links()`
  once parity is 0.

The earlier PROVISIONAL marks (E1 absent) are settled by KAN-710 wherever a row below cites it. What
KAN-710 does not settle is still marked **open**.

The mapping lives in exactly two functions, `kan711_events_map_game` and `kan711_events_map_meetup`.
The mirror, the backfill and the parity view all share them, so changing a rule means changing one
function.

**Route:** PEER (schema_change). The reviewer must be another `backend-N`.

**Running the backfill** (the stage 3 `CALL`) writes `event_id` on existing live rows and inserts
`events` rows. That is user-data mutation, so it needs a separate CEO/ops authorisation. Applying
migrations 2 and 3 does **not** run it.

## Files

| File | Kind | Purpose |
|---|---|---|
| ~~`supabase/migrations/20261102100000_kan711_events_parent_schema.sql`~~ | **deleted** | replaced by KAN-710 (`20261101140000`) |
| `supabase/migrations/20261102110000_kan711_events_mirror_triggers.sql` | migration 2 | mapping functions, upsert, event_id assignment, one-way mirror, `updated_at` keeper on `events`. No integrity triggers (KAN-710 owns them) |
| `supabase/migrations/20261102120000_kan711_events_backfill.sql` | migration 3 | checkpoint and exception tables, parity view, batch/run/reset/validate routines. **Does not run the backfill** |
| `supabase/tests/events_p1/parity_kan711.sql` | read-only report | KAN-710 pre-check (0b), populations, parity by issue and field, checkpoint, exceptions, series and request cross-checks, link constraints, verdict |
| `supabase/tests/events_p1/rollback_kan711.sql` | runbook | removes only KAN-711's objects; KAN-710 stays |
| `supabase/tests/events_p1/probes_kan711.sql` | probes | 101 assertions, BEGIN…ROLLBACK, negative controls and FINDING probes (P15 = updated_at) |
| `supabase/tests/events_p1/reviewer_repro_kan711.sql` | LOCAL ONLY, COMMITS | the Codex reviewer's two counterexamples (b2903455) verbatim, plus a forced-drift check. Fresh throwaway database only |
| `supabase/tests/events_p1/local_harness_kan711.sql`, `local_seed_kan711.sql` | LOCAL ONLY | stand-in legacy schema and seed rows. **Never run against Supabase** |

## Order of application

0. **KAN-710** (`20261101140000`) must already be applied. Migrations 2 and 3 assert that `events`,
   both FKs (KAN-710:282-285) and both link checks (KAN-710:287-292) exist.
   - Run `parity_kan711.sql` section 0b first. It lists the legacy rows that KAN-710's CHECKs would
     refuse (see R9).
1. **Migration 2.** The mirror is live from this commit, so every new or touched legacy row is
   captured from here on.
   - **It must be installed before the backfill**, so no row changes between being backfilled and
     being captured.
   - Precondition: the applying role is a superuser or has BYPASSRLS.
2. **Migration 3.** It installs the tooling only.
3. **[CEO/ops authorised]** `CALL public.kan711_events_backfill_run(200);`. Use a batch size of
   200–500 and run at a quiet time (see R4).
   - It commits per batch and resumes from its checkpoint.
   - `p_max_batches` limits a single session.
   - Rows that fail go to `events_backfill_exceptions`, and the run continues.
4. Run `parity_kan711.sql`. The verdict must be `parity_ok = t`.
5. Run `SELECT public.kan711_events_validate_links();`.
   - It refuses, returning `validated: false` and adding no constraint, unless parity rows,
     unresolved exceptions and unfinished kinds are all zero.
   - When they are, it reports `fk_valid` (KAN-710's FKs are VALID from creation, so it does not
     re-validate them), then adds and validates `games_event_id_not_null` and
     `meetups_event_id_not_null`.
6. If needed, run `rollback_kan711.sql`, then
   `supabase migration repair --status reverted 20261102120000 20261102110000`.

## Classification table

Classes:
- **copied**: same name and meaning, verbatim.
- **alias**: same meaning, different name.
- **conflict**: the legacy tables disagree; the resolution is stated.
- **derived**: computed, not copied.
- **not-copied**: no events column.

`NN` means NOT NULL. Every events column and check is KAN-710's, and its order (KAN-710:22-46,
25 columns) is what the positional map functions follow.

| events column | games source | meetups source | events (KAN-710) | class | handling |
|---|---|---|---|---|---|
| `id` | `id` NN | `id` NN | NN, PK (48) | copied | Same uuid; no new ids. An id already present as the other type raises `kan711_event_type_mismatch` (23514) |
| `event_type` | literal `'game'` | literal `'meetup'` | NN, CHECK (62) | derived | Immutable: KAN-710 guard (141-153, 264) |
| `title` | `title` nullable | `title` NN, 3–80 | nullable; meetups 3..80 (86) | conflict (C3) | Copied as is. A null game title stays null |
| `creator_profile_id` | NN | NN | NN, FK (50) | copied | — |
| `creator_user_id` | NN (forced from the profile by `trg_games_set_host`) | NN (not forced) | NN | copied | Meetups can drift from the profile's user. See R2 |
| `sport_id` | NN | nullable | nullable; NN for games (79) | conflict | Copied |
| `start_at` | NN | NN | NN | copied | — |
| `end_at` | NN | nullable | nullable; NN for games (75); **`end_at > start_at` (65)** | conflict (C5) | Copied, **never inferred**. The 65 check is stricter than legacy (R9) |
| `capacity` | NN, 2..64 | nullable, > 0 | games 2..64 (76); meetups null or > 0 (87) | conflict (C4) | Copied raw |
| `venue_id` | `venue_id` → venues | `venue_id` → venues | nullable, FK (58) | conflict (C7) | Copied raw. `games.venue_space_id` and `meetups.meta->>'venue_space_id'` are **not** copied |
| `geo_location_id` | NN (but ON DELETE SET NULL) | nullable | nullable; NN for games (81) | copied | — |
| `area_id` | NN | nullable | nullable; NN for games (80) | copied | — |
| `listing_visibility` | {public, followers, private} | {public, circle, invite, link, hidden} | per-type CHECK: games (77), meetups (88) | conflict (C1) | Raw value kept, **not normalised** |
| `join_policy` | `join_policy` {open, request, invite, link} | `rsvp_policy` {open, request, invite, link, closed} | per-type CHECK: games (78), meetups (89) | alias + conflict (C2) | Raw value kept |
| `min_skill`, `max_skill` | integer, nullable, 1..10 | integer, nullable | **smallint** (39-40); games 1..10 (82-83) | copied | Cast `::smallint`. A meetup value outside smallint would raise; 0b counts these |
| `joining_rule`, `cost_cover` | NN + logic CHECK | NN + logic CHECK | NN + the same logic CHECK (66-71) | copied | Identical on both, so no refusal is possible |
| `is_cancelled` | NN | NN | NN | copied | — |
| `cancelled_at`, `cancelled_reason` | nullable | — | nullable; **must be NULL for meetups (90)** | copied (game) | NULL for meetups. **Not inferred** |
| `request_id` | nullable; unique (creator_user_id, request_id) | same | unique (event_type, creator_profile_id, request_id) (118-119) | conflict (C9) | See R2 |
| `search_tsv` | trigger-maintained | trigger-maintained | derived by `trg_events_search_tsv` (124-137, 262), title only | **derived** | Passed as NULL; KAN-710 computes it. Not compared by parity |
| `created_at` | NN | NN | NN | copied | Copied, never `now()` |
| `updated_at` | NN | NN | NN; **touched by `trg_events_touch` (260)** | **copied exactly, on INSERT and on every UPDATE** (KAN-709/02 row 54) | The upsert sets and compares it. KAN-710's touch overwrites it with `now()`; `trg_kan711_events_keep_updated_at` restores the exact legacy value (see "updated_at"). Parity compares it. The backfill does not bump legacy `updated_at` |

**Not on the parent, by KAN-710's design** (KAN-710:124-126, handoff limitation 1):
`meetups.description`, `meetups.location_name` and `meetups.is_indoor` stay on the meetups subtype.
The earlier KAN-711 draft carried them on `events`. That was dropped: **no column the mirror needs is
missing from KAN-710.**

**Not copied in phase 1.** These remain only on the legacy tables, which stay authoritative:

- **games:** `game_type`, `venue_space_id`, `allow_spectators`, `rules` (including min/max players),
  `squad_id`, `sport_specific_data`, `allows_waitlist`, `sport_variant_id`, `bench_slots`,
  `price_aed`, `series_id`.
- **meetups:** `vibe_key`, `meta` (including `venue_space_id`), `host_actor_id`, `members_only`,
  `description`, `location_name`, `is_indoor`.

**Parity compares 23 fields:** event_type, title, creator_profile_id, creator_user_id, sport_id,
start_at, end_at, capacity, venue_id, geo_location_id, area_id, listing_visibility, join_policy,
min_skill, max_skill, joining_rule, cost_cover, is_cancelled, cancelled_at, cancelled_reason,
request_id, created_at and **updated_at**. Only `search_tsv` (derived by KAN-710) is excluded.

**Legacy is authoritative.** The earlier "never overwrite a newer events row" guard is removed.
`kan711_events_upsert` overwrites a same-type events row whenever any of the 22 mirrored non-key
columns (now including `updated_at`) differs. A direct edit of `events` is therefore reverted by the
next legacy write (probe P7).

## updated_at (rework after Codex review of b2903455)

**Defect found by the reviewer.** After a full backfill, `UPDATE games SET rules = …` advanced
`games.updated_at`, but `events.updated_at` kept its old value. The upsert neither set nor compared
`updated_at`, and `rules` is not a parent column, so the mirror wrote nothing. Parity excluded
`updated_at`, so it reported 0 and `validate_links()` returned `validated: true` over a real drift.
A repaired parent got `now()`, not the source value.

**Why the upsert cannot just write it.** KAN-710's `trg_events_touch` (KAN-710:260-261) is
`BEFORE UPDATE ON public.events FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at()`. The body
(baseline `20260829080500_baseline_schema.sql:17390-17394`) is `new.updated_at = now()`, and it is
unconditional. Any UPDATE of `events`, whatever its SET list says, stores `now()`. An AFTER trigger
or a second UPDATE would fire touch again.

**The KAN-711-only fix** (migration 2, sections 2 and 2a):
1. `kan711_events_upsert` publishes the source value for its one statement:
   `set_config('kan711.src_updated_at', r.updated_at::text, true)`. It is transaction-local, and
   it is cleared to `''` straight after the INSERT … ON CONFLICT.
2. It sets `updated_at = EXCLUDED.updated_at` and includes `updated_at` in the IS DISTINCT FROM
   comparison, so a subtype-only edit, which changes only `updated_at`, still rewrites the parent.
3. `trg_kan711_events_keep_updated_at` is a BEFORE UPDATE row trigger on `events`. Same-timing
   triggers fire in name order, and `trg_kan711_…` sorts after every `trg_events_…` (P14 asserts
   the order). So it runs after touch and sets `NEW.updated_at := <published text>::timestamptz`.
   - That is a copy, never a clock read. The text round-trip of `timestamptz` is exact to the
     microsecond (P15b pins `2024-01-02 03:04:05.678901+00`).
   - With the setting unset or `''` it returns NEW unchanged, so every non-KAN-711 events UPDATE
     keeps KAN-710's `now()` (P15c).
4. Leak safety:
   - `set_config(…, true)` is undone with the (sub)transaction on any error. P15e shows a refused
     upsert leaves the setting empty.
   - `FOUND` is captured before the clearing `PERFORM`; without that, the type-mismatch guard was
     skipped, and P8 caught it during development.
5. The function is SECURITY DEFINER with `search_path = ''`, revoked from PUBLIC, anon,
   authenticated and service_role. No GRANT, no DROP, no CASCADE.

**Residual risk.** A role that can already UPDATE `events` directly could set
`kan711.src_updated_at` itself and choose the stored `updated_at`. No API role can write `events`
(KAN-710:98-102: forced RLS and revokes), so in practice only owner or superuser sessions can, and
they could write any value anyway.

## Conflicts

- **C1 — visibility domains.** *Settled by KAN-710 (77, 88).* Each type keeps its own domain under a
  per-type CHECK. No union and no normalisation. Every value a legacy table accepts is accepted for
  its type.
- **C2 — join_policy vs rsvp_policy.** *Settled by KAN-710 (78, 89).* `rsvp_policy` maps to
  `join_policy`, and each type keeps its own domain. `closed` is meetup-only.
- **C3 — title nullability.** *Settled by KAN-710 (86).* Games may be NULL; meetups must be 3..80,
  which equals legacy `chk_meetups_title_len`, so it is not stricter. No placeholder title is
  invented.
- **C4 — capacity.** *Settled by KAN-710 (76, 87).* Games 2..64; meetups null (unlimited) or > 0.
- **C5 — end_at null.** *Settled by KAN-710 (65, 75).* Meetups allow an open end, copied as NULL. No
  duration is assumed. **New:** `end_at > start_at` (65) is stricter than legacy (R9).
- **C6 — min/max players vs capacity.** *Open (not in KAN-710).* Games keep player bounds inside
  `rules` jsonb, separate from `capacity`. They are **not** extracted in phase 1, and `rules` stays
  authoritative on `games`.
- **C7 — Venue/Space mix (`meetups.meta.venue_space_id`, `fn_meetups_sync_joining_rule`).**
  *Unchanged, report only.*
  - Baseline `20260829080500_baseline_schema.sql:6340` computes
    `COALESCE(NEW.venue_id, (NEW.meta->>'venue_space_id')::uuid)` and looks the result up in
    **`venue_spaces`**.
  - `meetups.venue_id` has an FK to **`venues`**, so a real venue id can never match a space id, and
    the lookup silently falls back to `joining_rule = 'free'` whenever `venue_id` is set.
  - Events copies `venue_id` raw. The `meta` space id is not copied, and `joining_rule` and
    `cost_cover` are copied **as the legacy trigger computed them**.
  - The trigger is reported and **not fixed**: that is legacy behaviour, outside this ticket's
    allowed paths.
- **C8 — `rpc_booking_hold_for_meetup` reads `m.owner_user_id`** (baseline `:11183`). *Unchanged,
  report only.* Meetups has no such column, so as written the RPC would raise at runtime.
  - It is not touched: it is a booking surface (forbidden), and the live body is unknown to this
    seat.
  - Under T-058 the live body must be read with `pg_get_functiondef` before anyone relies on it.
- **C9 — request uniqueness.** *Key settled by KAN-710 (118-119).*
  - Legacy keys on `(creator_user_id, request_id)` per table. Events keys on
    `(event_type, creator_profile_id, request_id)`.
  - The keys are equivalent for games, which force the user from the profile.
  - For meetups they are not: two meetups with the same profile and request but different users are
    legal in legacy and collide in events. See R2.
- **C10 — `trgfn_meetups_outbox` reads `new.owner_user_id`** (baseline `:19094`, AFTER INSERT on
  meetups). *Unchanged, report only.* As written, every meetup INSERT would fail.
  - KAN-711 does not touch it, and the mirror never calls emit_event.
  - The harness installs it with `creator_user_id` so local inserts can run.
  - **Ops must read the live body before apply.**

## Series uniqueness

Events carries no `series_id` (KAN-710:22-46).

- `games_series_id_start_at_key` remains the legacy enforcement.
- Once `event_id` is set, KAN-710's `trg_games_series_occurrence_check` and
  `trg_events_series_start_check` (214-249, 269, 293) also check one start_at per series across
  linked games. The backfill keeps them enabled (they are constraint triggers).
- The mirror copies `start_at` in the same transaction, so events cannot drift from games.
  `parity_kan711.sql` section 7 re-checks this, and probe P13 shows the legacy index still refusing
  a duplicate.

## Locking

**Observed, not inferred.** On PostgreSQL 16.15 I ran `pg_locks` inside one real
`kan711_events_backfill_batch('games', 2)` transaction.

- `games` held `AccessShareLock`, `RowShareLock`, `RowExclusiveLock` and `ShareRowExclusiveLock`.
- `events` held `AccessShareLock`, `RowShareLock` and `RowExclusiveLock`.
- `meetups` held `AccessShareLock`.
- **No relation held `AccessExclusiveLock`.**

A bare `ALTER TABLE public.games DISABLE TRIGGER trg_games_touch` likewise took only
`ShareRowExclusiveLock`.

**This contradicts the coordinator's correction** ("DISABLE TRIGGER takes ACCESS EXCLUSIVE"), and my
earlier "ACCESS EXCLUSIVE, briefly", on this version. PostgreSQL documents SHARE ROW EXCLUSIVE for
ENABLE/DISABLE TRIGGER. Supabase runs a newer major version, which should be re-observed on the
target before apply.

What the lock does in practice:
- The batch takes `SHARE ROW EXCLUSIVE` first (step 1), so the DISABLE adds nothing stronger.
- It is held until the batch commits.
- While it is held, **every INSERT, UPDATE and DELETE of that table waits, app writes included.
  Plain reads do not.**

**Runbook:** run small batches (200–500) at a quiet time.

## Risks

- **R1 — a mirror failure aborts the user's write.**
  - The mirror runs in the user's transaction. That is deliberate: it is transactional and cannot
    drift.
  - KAN-710's CHECKs are per-type and match legacy, except `end_at > start_at` (R9). So for valid
    legacy rows the reachable failures are R2 and R9.
  - The cost is a failed create or edit (visible and safe), never silent divergence.
- **R2 — meetup profile/user drift and request conflict.**
  - A meetup can share `(creator_profile_id, request_id)` with another meetup that has a different
    `creator_user_id`.
  - During the backfill, that row goes to `events_backfill_exceptions` as 23505 and the batch
    continues (P11). During a live write, it aborts that write.
  - Parity section 8b lists every such pair. **Run it before apply.**
- **R3 — FK ordering under `SET CONSTRAINTS ALL IMMEDIATE`.**
  - Same-timing triggers fire in name order, and `RI_ConstraintTrigger_*` sorts before
    `trg_kan711_*`.
  - Under IMMEDIATE, a legacy INSERT checks KAN-710's FK before the mirror has written the parent,
    and fails.
  - The production default is DEFERRED (KAN-710:283, 285), and no repo code uses `SET CONSTRAINTS`.
  - **Reviewer decision:** accept this, or rename the mirror triggers to sort first.
- **R4 — locks per batch.** See "Locking" above: SHARE ROW EXCLUSIVE, held per batch, blocks writes
  but not reads.
  - Trigger modes are recorded and restored exactly (P4).
  - Use batches of 200–500 at a quiet time.
- **R5 — BYPASSRLS required.**
  - meetups is FORCE RLS, and `events` is FORCE RLS with zero policies (KAN-710:98-102).
  - The SECURITY DEFINER functions must be owned by a role that bypasses RLS. KAN-710 handoff
    assumption E-02 is the same.
  - Both KAN-711 migrations assert it.
- **R6 — live catalogue drift (T-058).**
  - The harness copies repo DDL, not the live catalogue.
  - Before apply, ops must diff live `games` and `meetups` (columns, CHECKs, triggers via
    `pg_get_functiondef` and `pg_get_triggerdef`) against the harness header.
  - The map functions are positional over `public.events`. If KAN-710 is applied with a different
    column order, migration 2's `ROW(...)::public.events` breaks.
- **R7 — legacy trigger bodies unknown to this seat** (C8, C10). Confirm them live.
- **R8 — the backfill's ALTER TABLE needs no pending trigger events.**
  - Each batch runs in its own transaction from the `run` procedure, so this holds operationally.
  - Calling `kan711_events_backfill_batch` inside a larger transaction that has already queued
    deferred events on that table raises "pending trigger events".
- **R9 — `events_end_after_start` (KAN-710:65) is stricter than legacy.**
  - Legacy accepted a meetup with `end_at = start_at` locally (control run: 1 row).
  - Such a row cannot be mirrored. A live edit of it aborts, and the backfill sends it to exceptions
    as 23514.
  - `parity_kan711.sql` section 0b counts these, and every other KAN-710 rule, before apply.
- **R10 — FINDING: KAN-710's FK is `ON DELETE CASCADE`** (KAN-710:282-285).
  - Deleting an `events` row **deletes its legacy game or meetup** (probe P9).
  - Only postgres and service_role can reach `events`, but any manual cleanup of `events` must NULL
    `event_id` first (rollback section B).
  - Reported to KAN-710. Not changed here.
- **R11 — FINDING: no exactly-one-child rule** (KAN-710 handoff limitation 3).
  - An `events` row with no legacy child is not refused.
  - With the mirror in place none is created (P9 CTRL). A path that bypasses the mirror can leave
    one, and parity reports it as `orphan_event` (P9).
- **R12 — FINDING: KAN-710's link check does not fire when `event_id` is set by a BEFORE trigger.**
  - `UPDATE OF id, event_id` (KAN-710:287-292) fires only when `event_id` is in the statement's SET
    list.
  - When `trg_kan711_*_assign_event_id` fills `event_id` during a user UPDATE of other columns, the
    check does not run.
  - KAN-711 covers this path itself: the upsert raises `kan711_event_type_mismatch` (23514) on a
    wrong-type parent. The backfill's `SET event_id = id` does fire the check.
- **R13 — FINDING: a game or meetup created AND deleted in one transaction fails at COMMIT.**
  - KAN-711's assign trigger sets `event_id` on INSERT, which queues KAN-710's deferred link check.
  - The DELETE removes the row and, through the mirror, its parent.
  - At commit the queued check reads the stale NEW tuple and raises
    `orphan: meetups … links to missing event …` (23503). `events_check_subtype_link`
    (KAN-710:172-176) never re-checks that the subtype row still exists.
  - Probe P7 FINDING demonstrates it.
  - **The fix belongs to KAN-710:** return early when the subtype row no longer exists. KAN-711 does
    not modify KAN-710.
  - Production impact depends on whether any RPC creates and deletes in one transaction. This seat
    does not know.
- **R14 — the parent's `updated_at` depends on trigger name order.**
  - `trg_kan711_events_keep_updated_at` must keep sorting after `trg_events_touch`.
  - A future events BEFORE UPDATE trigger whose name sorts after `trg_kan711_…`, and which writes
    `updated_at`, would win.
  - The migration 2 post-condition and P14 assert the exact trigger set and order.
  - Parity (23 fields) catches any resulting drift, and `validate_links()` refuses on it.

## Rollback

Run `rollback_kan711.sql`. It is a single transaction with `lock_timeout 5s` and no `CASCADE`.

**It drops only KAN-711's objects:**
1. the two `*_event_id_not_null` checks;
2. the 5 `trg_kan711_*` triggers (4 on games/meetups, plus `trg_kan711_events_keep_updated_at` on
   `events`);
3. the stage 3 procedure, functions, view and both bookkeeping tables;
4. the 7 stage 2 functions (including `kan711_events_keep_updated_at`).

**It does not drop** `events`, the `event_id` columns, `games/meetups_event_id_key`,
`games/meetups_event_id_fkey`, or any KAN-710 trigger or function. Its post-conditions assert both:
nothing of KAN-711 survives, and all of KAN-710 does.

**Data stays.** The `events` rows and `event_id` values that KAN-711 wrote are left in place.
Removing them mutates existing live rows (CEO-only, 019). It is section B of the runbook, commented
out and not run. Its order is mandatory:
1. NULL `event_id`;
2. assert no links remain;
3. then delete `events`.

Otherwise R10's CASCADE deletes the legacy rows. KAN-710's own rollback refuses while `events` has
rows, so section B must run before it.

## Local verification (what actually ran)

PostgreSQL 16.15 (Homebrew), throwaway cluster `/tmp/kan711_pg`, socket only on port 54399,
superuser `postgres`. The order:

1. harness → seed (6 games, 6 meetups) → KAN-710 `20261101140000` → migration 2 → migration 3: all
   exit 0, and every post-condition assert passed.
2. `probes_kan711.sql`: **101/101 PASS**, `ALL KAN-711 PROBES PASSED`, rolled back. The 17 new P15
   probes cover the `updated_at` rework. They include negative controls: with the keeper disabled,
   parity reports `{updated_at}` and `validate_links()` refuses.
3. Parity section 0b before the backfill: 0 rows on the seed.
   - Control: with a meetup set to `end_at = start_at` in a rolled-back transaction, the predicate
     counted 1.
4. Legacy hash before the backfill (md5 over `to_jsonb(row) - 'event_id'`, games then meetups,
   ordered by id): `c5b7688d0ed36c39316519077fde58a1`.
5. `CALL kan711_events_backfill_run(4)`: games batches 4/2/0 and meetups batches 4/2/0.
6. `parity_kan711.sql`:
   - populations games 6/6/6, meetups 6/6/6;
   - parity rows 0, exceptions 0, both kinds finished;
   - both FKs `convalidated = t`;
   - **`parity_ok = t`**.
   - The legacy hash excluding `event_id` was unchanged (`c5b7688d…`), so `updated_at` was not
     bumped.
7. `validate_links()`:
   `{"fk_valid": {"games_event_id_fkey": true, "meetups_event_id_fkey": true}, "validated": true, "parity_rows": 0, "not_null_valid": {"games_event_id_not_null": true, "meetups_event_id_not_null": true}, "unfinished_kinds": 0, "unresolved_exceptions": 0}`.
8. `rollback_kan711.sql`: exit 0, and the post-conditions passed.
   - Legacy hash before and after: excluding `event_id` `c5b7688d0ed36c39316519077fde58a1` both
     times; full `08118d2421f1a0e6ffea0c5a8dc439da` both times.
   - KAN-711 objects remaining: 0. KAN-710's `events` and its 4 link constraints were present. The
     12 events rows and 12 links remained, as designed.
9. Migrations 2 and 3 re-applied on that populated database: exit 0.
   - The backfill re-ran idempotently (no exceptions), `parity_ok = t`, `validate_links()` returned
     `validated: true`, and the legacy hashes were unchanged.
   - The probes **cannot** run on this database: they assume the pre-backfill state (P0 failed with
     "events empty before backfill", as expected).
10. Full rebuild on a fresh database (harness → seed → KAN-710 → 2 → 3), then the probes:
    **84/84 PASS** (before the updated_at rework; see 13).
11. Lock observation: see "Locking".
12. The cluster was stopped.
13. **updated_at rework (2026-11-02), on fresh databases:**
    - The probes: **101/101 PASS**.
    - `reviewer_repro_kan711.sql`:
      - **with b2903455's migrations: FAIL** at the first assertion (parity did not report
        `updated_at` on the stale parent);
      - **with the reworked migrations: all PASS.** The repaired parent carries
        `2025-12-02 10:00+00`; after the rules edit parent = legacy (`timestamp_mismatch f`) and
        parity is 0; a forced drift gives parity 1 `{updated_at}` and `validated: false`.
    - Backfill 4/2/0 + 4/2/0, parity 0, `parity_ok = t`, `validate_links()` `validated: true`.
    - 12/12 parents carry the exact legacy `updated_at`.
    - Rollback: legacy hashes unchanged before and after (`c5b7688d0ed36c39316519077fde58a1` /
      `08118d2421f1a0e6ffea0c5a8dc439da`). 0 kan711 routines and 0 kan711 triggers remain, and
      `events` is back to KAN-710's five triggers.

**Limitations.**
- The harness is not the live schema. PostGIS, unaccent, sports and venues validation, persona and
  frozen guards, and the notification fan-out are stubbed.
- Data volume is 12 rows, so lock duration and batch timing at production volume are **not
  measured**.
- Supabase roles, grants and default privileges are imitated, not real.
- Locks were observed on PG 16.15 only.
