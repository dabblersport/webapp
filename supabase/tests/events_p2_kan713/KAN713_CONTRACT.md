# KAN-713: Events P2, access policies and location rules on events (no visibility change)

**Status: authored, NOT applied.** Every run below used a throwaway local PostgreSQL 16 cluster
(`/tmp/kan713_pg`, port 54410). That cluster has been stopped. Nothing touched the live Supabase project.
Author: backend-3 (Shed), Team Luxor. Nothing is committed; Luxor reviews and commits.

| File | Purpose |
|---|---|
| `supabase/migrations/20261104100000_kan713_access_helpers.sql` | Access helpers and policies also read events |
| `supabase/migrations/20261104110000_kan713_location_triggers.sql` | Location / joining_rule triggers consolidated, validated, events-aware |
| `supabase/tests/events_p2_kan713/local_harness_kan713.sql` | Local-only fixture (actors, 4 games, 5 meetups, venues/spaces/geo) |
| `supabase/tests/events_p2_kan713/matrix_kan713.sql` | Permission matrix, 1955 cells |
| `supabase/tests/events_p2_kan713/probes_kan713.sql` | 28 probes (16 K, 10 =, 2 named-exception E) |
| `supabase/tests/events_p2_kan713/recursion_kan713.sql` | RLS recursion probe (control + 80-cell sweep + static) |
| `supabase/tests/events_p2_kan713/fingerprint_kan713.sql` | Catalogue fingerprint and data hashes |
| `supabase/tests/events_p2_kan713/rollback_kan713.sql` | One-transaction rollback of both migrations |

## 1. Rule

**An events field can only narrow access, never widen it.** Each access answer is now *legacy answer AND
events answer*, and each vocabulary is checked within its own type (game: `public/followers/private/link`
+ `open/request/invite/link`; meetup: `public/circle/invite/link/hidden`). Missing or wrong-type events
rows fail closed. If `join_policy` disagrees between the two sides, the answer fails closed with
`policy_mismatch`. **events stays closed to the API roles**:
- zero policies;
- FORCE RLS;
- no anon/authenticated grant.

Policies reach events only through four SECURITY DEFINER helpers. Those helpers read only `public.events`.

While the KAN-712 compat mirror keeps events equal to legacy, every answer is identical to today's. The
matrix diff (section 4) proves it. The K probes prove the events conjunct is real by making events narrower
with the mirror disabled.

## 2. Manifest: every replaced definition, with its prior source

Baseline file = `supabase/migrations/20260829080500_baseline_schema.sql`.

| Row | Object | Prior definition | KAN-713 change | Attributes kept |
|---|---|---|---|---|
| G-1 | `_can_view_game(uuid)` | baseline:784-810 | JOIN events (type game); events visibility must also pass | SECURITY DEFINER, `search_path public`, owner, ACL |
| G-2 | `_can_view_game_for_join(uuid)` | baseline:816-829 | sql to plpgsql only to branch on `has_table_privilege('public.events','SELECT')`; intersection where readable | INVOKER, `search_path public, pg_temp`, owner, ACL |
| G-3 | `_is_game_host(uuid)` | baseline:1139-1148 | legacy creator AND events creator must both be the caller | SECURITY DEFINER, `search_path public`, owner, ACL |
| G-4 | `can_current_user_join_game(uuid,text,uuid)` | baseline:3630-3686 | events row required; visibility intersect; cancelled/started union; `policy_mismatch` fail-closed; E-2 kept byte-for-byte | INVOKER, `search_path public`, owner, ACL |
| M-1 (G-5) | `can_current_user_rsvp_meetup(uuid,uuid)` | `20260912190747_kan180_finding_b_...sql:33-109` + `20260915120000_meetups_hardening.sql:78-79` | events row required; visibility intersect; `policy_mismatch` fail-closed | SECURITY DEFINER, search_path, owner, ACL |
| P-1 | policy `meetups_select_visible` | baseline:32570 | `AND kan713_meetup_visible(event_id)` | roles, cmd, permissive |
| P-2 | policy `meetup_attendees_select` | baseline:32534 | `AND kan713_meetup_can_read_row(m.event_id)` | same |
| P-3 | policy `meetup_attendees_select_visible` | baseline:32540 | `AND kan713_meetup_attendee_visible(m.event_id)` | same |
| P-4 | policy `meetup_attendees_write` (USING and WITH CHECK) | baseline:32546 | `AND (kan713_meetup_can_write_row(m.event_id) OR auth.uid() = user_id)` | same |
| T-1 | trigger `trg_games_inherit_geo` / `fn_games_inherit_geo` | baseline:29843 / 6014-6050 | disabled; logic moved to `trg_kan713_games_a_location` | trigger kept (state D) |
| T-2 | trigger `trg_games_inherit_venue_geo` / `trg_fn_games_inherit_venue_geo` | baseline:29851 / 17616-17645 | disabled; logic moved to `trg_kan713_games_c_venue_geo` | kept (D) |
| T-3 | trigger `trg_games_sync_joining_rule` / `fn_games_sync_joining_rule` | baseline:29871 / 6053-6075 | disabled; moved to `trg_kan713_games_b_joining` | kept (D) |
| T-4 | trigger `trg_meetups_inherit_geo` / `fn_meetups_inherit_geo` | baseline:29939 / 6312-6334 | disabled; moved to `trg_kan713_meetups_a_location` | kept (D) |
| T-5 | trigger `trg_meetups_sync_joining_rule` / `fn_meetups_sync_joining_rule` | baseline:29955 / 6340-6367 | disabled; moved to `trg_kan713_meetups_b_joining` (D-1 fixed) | kept (D) |

**Pinned pre-images.** Both migrations refuse to run unless every live object matches the reviewed
pre-image:
- `md5(prosrc)`, `prosecdef` and `proconfig` for G-1..G-5;
- the `qual`/`with_check` md5 for P-1..P-4;
- `md5(prosrc)` for the five legacy trigger functions.

These are the trigger-function pins:

| Function | md5 |
|---|---|
| `fn_games_inherit_geo` | `5814c38b...` |
| `trg_fn_games_inherit_venue_geo` | `518dbad6...` |
| `fn_games_sync_joining_rule` | `ce429c69...` |
| `fn_meetups_inherit_geo` | `9eb95300...` |
| `fn_meetups_sync_joining_rule` | `ffbc58a3...` |

Every function body was authored from `pg_get_functiondef`, and the exact saved text is stored in
`public.kan713_preimage`.

**New objects.** Function EXECUTE grants were asserted after apply:

| Object | Grants and attributes |
|---|---|
| `kan713_meetup_visible`, `kan713_meetup_can_read_row`, `kan713_meetup_attendee_visible`, `kan713_meetup_can_write_row` (uuid) | Owner, anon, authenticated, service_role, exactly as asserted. The policies run as the querying role, so they need this grant. SECURITY DEFINER, `search_path ''`, STABLE |
| `kan713_games_location`, `kan713_games_joining`, `kan713_games_venue_geo`, `kan713_meetups_location`, `kan713_meetups_joining` | Owner only. INVOKER, `search_path ''` |
| `kan713_events_location` | Owner only. SECURITY DEFINER, `search_path ''` |
| `kan713_preimage` table | RLS on; ALL revoked from PUBLIC, anon, authenticated, service_role |

## 3. Trigger ownership: old trigger to new owner

Every field is now written once, by exactly one BEFORE trigger. At compat depth, when the KAN-712 mirror
writes legacy at `pg_trigger_depth()>1` with `kan712.compat = id`, every KAN-713 legacy trigger returns
NEW unchanged. The KAN-712 guard then copies the events values onto the row. Before KAN-713, the legacy
triggers recomputed the values and the guard overwrote them, so skipping produces the same result with no
double write. A session-level spoof at depth 1 is ignored (probe L15).

| Field(s) | Old owner (now disabled) | New owner | Fires on |
|---|---|---|---|
| games: venue_id fill-in, geo_location_id, area_id | `trg_games_inherit_geo` | `trg_kan713_games_a_location` (+ Venue/Space validation, D-2) | BEFORE INSERT / UPDATE OF venue_id, venue_space_id |
| games: joining_rule, cost_cover | `trg_games_sync_joining_rule` | `trg_kan713_games_b_joining` (verbatim) | BEFORE INSERT / UPDATE OF venue_space_id |
| games: geo/area COALESCE from space's venue | `trg_games_inherit_venue_geo` | `trg_kan713_games_c_venue_geo` (verbatim) | BEFORE INSERT / UPDATE OF venue_space_id |
| meetups: geo_location_id, area_id | `trg_meetups_inherit_geo` | `trg_kan713_meetups_a_location` (verbatim) | BEFORE INSERT / UPDATE OF venue_id |
| meetups: joining_rule, cost_cover | `trg_meetups_sync_joining_rule` | `trg_kan713_meetups_b_joining` (space only from `meta.venue_space_id`, validated, D-1) | BEFORE INSERT / UPDATE OF venue_id, meta |
| events: geo_location_id, area_id on a venue change (ops path) | none (left stale before) | `trg_kan713_events_location` (validates against the child's space) | BEFORE UPDATE OF venue_id ON events |
| search_tsv (games, meetups) | unchanged | unchanged (reads only title / description / location_name) | unchanged |
| sport guard, venue_space guard | unchanged | unchanged, still 'O' (asserted) | unchanged |

**Venue vs Space** is resolved only through `venue_spaces.id -> venue_spaces.venue_id`, which links to
`venues`:
- a space that does not exist is refused with `23503 kan713_space_not_found`;
- a venue/space pair that disagrees is refused with `23514 kan713_space_venue_mismatch`;
- both refusals fire only when the venue or the space is being changed, so an existing row with junk keeps
  working (L11).

**Behaviour fixes**, both flagged as K probes:

- **D-1.** `fn_meetups_sync_joining_rule` looked the meetup's *venue* id up as a *space* id, so it always
  returned 'free'. The space now comes from `meta.venue_space_id` only.
- **D-2.** Changing a game's space alone kept the old venue, which gave an inconsistent pair. The venue now
  follows the space.

## 4. Permission matrix

`matrix_kan713.sql` covers 17 actors on 13 events:

- **Actors:**
  - anon;
  - authenticated a1 owner, a2 non-member with a pending request, a3 admin, a4 member, a5
    follower/friend, a6 blocked, a7 invitee/link-holder/waitlisted, a9 with no profile;
  - service_role with no uid, and as a1–a7.
- **Events:**
  - every visibility value of each type (G-pub, G-fol, G-pri, G-link; M-pub, M-cir, M-inv, M-lnk, M-hid);
  - adversarial ids: X-none, a meetup id fed through every game cell, and a game id fed through every
    meetup cell.
- **Cells per game:**
  - the three game helpers;
  - join with no token, the right token and the wrong token;
  - rows in games, game_roster, game_waitlist, game_join_requests and events.
- **Cells per meetup:**
  - rsvp with no token, the right token and the wrong token;
  - rows in meetups and meetup_attendees;
  - an attendee write;
  - rows in events.

**Result: 1955 cells, and the diff is EMPTY at every comparison:**
- pre-KAN-713 vs post-KAN-713 (separate builds);
- state 0 vs 1 vs 2 on one database;
- pre vs the final fresh build.

The fail-first counterpart is probes A1–A8. With the mirror disabled and events made narrower, each answer
changes after KAN-713 and does not change before it. A9 asserts that events is still closed.

## 5. Ops apply order

1. Confirm that KAN-712 stage B (`20261103110000`) is live. Migration 1 refuses otherwise, naming the five
   `trg_zz_kan712_*` triggers.
2. `20261104100000_kan713_access_helpers.sql`, as the migration owner (superuser or BYPASSRLS).
3. `20261104110000_kan713_location_triggers.sql`. It refuses unless step 2 is in.
4. Run `probes_kan713.sql` only where test writes are permitted, never on production data. The read-only
   check is `fingerprint_kan713.sql` diffed against the expectations in section 8.

Each migration is a single transaction with a 10s `lock_timeout` and a SHARE ROW EXCLUSIVE lock on events,
games, meetups and meetup_attendees. A re-run refuses (`already applied`).

## 6. Rollback

`rollback_kan713.sql`, one transaction, same locks.

1. **Gate.** KAN-713 is fully applied. The pre-images are complete (5 function, 4 policy, 5 trigger). The
   five KAN-712 stage B triggers are still present.
2. Recreate G-1..G-5 from the saved `pg_get_functiondef`.
3. `ALTER POLICY` P-1..P-4 back to the saved USING / WITH CHECK, with `search_path public, pg_catalog`.
4. Drop the six `trg_kan713_*` triggers and the six trigger functions. No CASCADE.
5. Drop the four helpers. No CASCADE. This succeeds only because step 3 removed every reference.
6. Return the five legacy triggers to their saved `tgenabled`.
7. **Postconditions:**
   - `md5(pg_get_functiondef)`, `proacl` and owner equal the pre-image;
   - policy text equals the pre-image;
   - `pg_get_triggerdef` and `tgenabled` equal the pre-image;
   - no `kan713_*` function or trigger remains;
   - events is still closed.

`public.kan713_preimage` is kept as evidence. It is excluded from the fingerprint.

**Order: KAN-713 rollback BEFORE KAN-712 rollback.** This was observed both ways:
- `rollback_kan712.sql` on a database with KAN-713 applied refuses with
  `events trigger set is not KAN-710 five + KAN-711 keeper`;
- after `rollback_kan713.sql` it succeeds, with equal before and after hashes.

## 7. Limitations and named exceptions

**E-1 (does not block): `rpc_booking_hold_for_meetup` reads `m.owner_user_id`, which does not exist on
meetups.**
- **Source:** baseline:11183-11211, at line 11198. Grants were later narrowed by
  `20260915120000_meetups_hardening.sql:767-768`.
- **Before KAN-713:** `ERR 42703 record "m" has no field "owner_user_id"`.
- **After KAN-713:** the identical error (probe E-1).
- KAN-713 does not touch this function. A fix (`creator_user_id`, which also needs an events-aware host
  check) is follow-up work for `backend`.

**E-2 (pre-existing, kept byte-for-byte):** the invite branch of `can_current_user_join_game` reads
`game_invites.to_profile_id`, which does not exist. An invite game that reaches that branch raises
`ERR 42703 column i.to_profile_id does not exist`, both before and after (probe E-2). No matrix actor
reaches it, because G-pri is private.

**Limitations:**

- **Capacity.** `game_slots_left` still reads `games.capacity`. Capacity is not an access field, so it is
  unchanged.
- **No FK on `games.venue_space_id`.** The triggers now validate it on change. Existing junk rows are
  tolerated until they are edited.
- **Harness assumptions.** The local `venue_spaces.venue_id` has no FK, and the harness adds grants that
  production is assumed to have (`local_harness_kan713.sql`). Verify these against live with a read before
  applying.
- **Migration owner bypasses RLS.** The helpers are owned by `postgres`, which bypasses RLS, so their events
  read evaluates no policy. If the owner ever changes to a non-bypass role, revisit this, because events has
  FORCE RLS and zero policies, so the helpers would read nothing and every answer would fail closed.
- **NULL venue refills.** `UPDATE games SET venue_id = NULL` while a space is set refills the venue from the
  space. The old trigger did the same.
- **Unparseable meta.** A `meta.venue_space_id` that is not a uuid is treated as no space.
- **Venue's geo wins.** An ops patch that sets `geo_location_id` together with `venue_id` is overridden by
  the venue's geo.
- **Cross-database data hashes are not comparable.** The seed uses `now()`. The data-hash evidence is
  therefore taken on one database through all three states (section 8).

## 8. Run output (local PG16, observed)

**Probes (`probes_kan713.sql`):**

| Database | Result | Detail |
|---|---|---|
| Pre-KAN-713 (KAN-712 A+B) | `#SUMMARY pass=12 fail=16` | All 16 K probes FAIL; all 10 `=` and 2 E probes PASS |
| KAN-713 applied | `#SUMMARY pass=28 fail=0` | |
| Fresh final build | `#SUMMARY pass=28 fail=0` | |

**Other test runs:**

| Test | Result |
|---|---|
| `probes_kan712.sql` on KAN-713 (twice, incl. fresh build) | `#TOTAL pass=55 fail=0` |
| `recursion_kan713.sql` | `#SUMMARY pass=6 fail=0` |
| Matrix (all comparisons) | `#CELLS 1955`, `diff` empty |

The recursion run, in detail:
- **R0 control:** a planted recursive pair is detected (`ERR 42P17`).
- **R1:** 80 cells, 0 × 42P17/54001. The only error is anon UPDATE meetup_attendees → 42501, because
  there is no grant.
- **R2:** the helpers name only `public.events`; their callees never read meetups or attendees; owner =
  bypass.

**Rollback proof, one database (`k713_rb`): state 0 pre → 1 applied → 2 rolled back.**

| Comparison | Result |
|---|---|
| fingerprint 0 vs 1 | non-empty (fail-first). 5 function md5s, 10 new functions, 4 policy md5s, 6 new triggers, 5 legacy 'O' to 'D'; 210 to 226 lines |
| fingerprint 0 vs 2 | EMPTY (210 = 210 lines) |
| matrix 0 vs 1, 0 vs 2 | EMPTY (1955 cells) |

Data hashes were identical in all three states:

```
data|events|21|c4b4b7b1267d004a73e63df0cbf5b857
data|games|10|1251ebbbfe24beb6cf8d6e4bf4690e06
data|meetups|11|3cea8555223dbe8fd71be62cde40d62f
data|meetup_attendees|5|072cc9a9761420d0217b840a8c18bd86
data|game_roster|4|f5e153692cf618892e6a6c5c6e4f1326
```

The rollback reported `NOTICE: KAN-713 rollback: OK (5 functions, 4 policies, 5 legacy triggers restored;
10 kan713 functions and 6 triggers removed)`.

**Gate refusals observed:**

| Attempt | Refusal |
|---|---|
| Migration 1 re-run | `KAN-713: already applied (public.kan713_meetup_visible exists)` |
| Migration 1 after KAN-712 rolled back | `KAN-712 stage B (20261103110000) not live; missing or disabled: <five trg_zz_kan712_*>` |
| Migration 2 without migration 1 | `KAN-713: 20261104100000_kan713_access_helpers.sql must be applied first` |
| KAN-712 rollback with KAN-713 applied | refused, as in section 6 |
