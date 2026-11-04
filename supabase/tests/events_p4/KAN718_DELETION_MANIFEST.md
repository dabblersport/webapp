# KAN-718 D06: exact deletion manifest (KAN-774)

Epic KAN-708, parent KAN-718. **Authored for review; nothing here is applied.** Production Supabase was not
read or written. The manifest is the TEMP table `k774_manifest` in
`supabase/tests/events_p4/kan718_d06_manifest_check.sql`; the table in section 4 is generated from it, so the
two cannot drift.

## 1. Verdict

> 2026-11-04: exact only on a chain without D05; see `KAN718_HANDOFF.md` (d).

**Deletion stays BLOCKED.** Every one of the 130 entries is blocked today:

- **D01** (`KAN718_D01_SQL_CONSUMERS.md`): all 40 column pairs still have SQL consumers.
- **D02** (`KAN718_D02_NON_SQL_CONSUMERS.md`): 28 functions, 21 consumer triggers, 4 policies and 1 dynamic-SQL
  function still read the slated columns. The KAN-711/712/713/718 infra (mirror, guard, location and
  joining triggers) is a pending dependency, not a retired one. It goes in the same migration as the columns.
- **D03** (`KAN718_D03_OLD_CLIENT_MATRIX.md`): 18 direct `games` reads in `lib/`. Every store build since 1.3.0
  breaks when a games column goes. Meetups has no direct client read.

What this ticket adds is the exact statement list, a replacement or a named gap for each one, and a check
that proves the list matches the catalogue.

## 2. Slated set

Slated = every column of `games` / `meetups` minus the KAN-718 PRODUCT CONTRACT "Retained subtype data" list.

- **Retained games (13):** `id, event_id, game_type, venue_space_id, sport_variant_id, allow_spectators, rules,
  squad_id, sport_specific_data, allows_waitlist, bench_slots, price_aed, series_id`
- **Retained meetups (6):** `id, event_id, vibe_key, meta, host_actor_id, members_only`
- **Slated:** 23 games columns and 24 meetups columns (M1). Every retained column exists.

### Evidence gaps (the D-series slated sets are narrower than this one)

| Column | D01 | D02 | D03 | Note |
|---|---|---|---|---|
| `games.search_tsv`, `meetups.search_tsv` | yes | no | no | `trg_events_search_tsv` and the events tsv indexes replace them |
| `games/meetups.created_at`, `updated_at` | no | yes | yes | D01 used the B15 set of 40 pairs, without these |
| `meetups.description`, `location_name`, `is_indoor` | no | no | no | **No consumer evidence at all.** `v_meetup_list` reads all three |

### Contract gap: three meetups columns have no home

`events` has no `description`, `location_name` or `is_indoor` column, and KAN-718 does not retain them on
`meetups`. Dropping them **loses data**. `v_meetup_list` also reads them (a column-level view dependency), so
`DROP COLUMN` without CASCADE refuses (D1 output, entries 704/722/723). This needs a product decision, either:

- (a) add them to the retained meetups list, or
- (b) add events columns and backfill them before phase 4.

This manifest does not choose. `meetups.rsvp_policy` lands on `events.join_policy`. That carries the known
value conflict between `rsvp_policy` and `join_policy` (`events_meetup_join_policy_check`).

## 3. Phase-4 order (authored, not run)

0. **Preconditions** in the same migration, which aborts if any fails:
   - D01, D02 and D03 re-run and report 0 consumers;
   - `kan718_d09_parity_precheck.sql` passes;
   - the three decisions below are recorded.
1. **100 policies:** `ALTER POLICY` ×4. Each keeps the KAN-713 events half it already ANDs in. `ALTER POLICY`
   keeps cmd and roles.
2. **200 publication:** `ALTER PUBLICATION supabase_realtime SET TABLE ONLY` with the retained columns only.
3. **300 triggers:** `DROP TRIGGER` ×33.
4. **400 indexes:** `DROP INDEX` ×16. 13 of them are in the repo baseline but absent from the local harness.
5. **500 constraints:** `ALTER TABLE … DROP CONSTRAINT` ×28.
6. **600/700 columns:** `ALTER TABLE … DROP COLUMN` ×47, one statement per column. Defaults go with their column.

No statement uses CASCADE, IF EXISTS or a wildcard (M4). Dropping the trigger functions (for example
`kan711_events_map_*`, `handle_game_created`) is out of scope. It is a follow-up once phase 4 lands.

**Rollback:** phase 4 is one transaction, so a failure rolls back everything (D1 and S5 prove that here).
**After commit, a dropped column cannot be restored from the migration.** Restoring needs the pre-phase-4
backup, which is why the preconditions gate it.

### Decisions this manifest surfaces (none taken here)

1. **Meetups columns with no home:** `description`, `location_name`, `is_indoor` (section 2).
2. **Realtime:** after the mirror stops, a games/meetups row no longer changes when its event does. D03 2d lists
   the listeners. Options are to publish `events`, or to accept no subtype realtime. Entries 201/202 only
   shrink the column lists.
3. **Old-client floor (D03):**
   - old store and web builds read `games` columns directly;
   - phase 4 waits for a minimum-version gate, or it breaks them;
   - deletion stays blocked until that floor exists.

**20 entries have no authored replacement:** 15 trigger entries (319-333) for legacy behaviours with no events equivalent:
activity sync, created/cancel notify, outbox, set_host, stamp_request_id, solo and challenge sport, inherit
sport from space, and joining-rule sync; plus the 2 realtime entries (201/202) and the 3 homeless columns. Each needs
its own events-side ticket before its row can go.

## 4. Manifest (generated from `k774_manifest`)

Status meanings:

- **consumer evidence:** a D01/D02/D03 consumer remains.
- **no replacement:** no events-side object exists.
- **hard:** the catalogue refuses the statement without CASCADE.
- **baseline-only:** defined in the repo baseline but absent locally; verify it in production.

| seq | kind | exact statement | replacement | evidence | status |
|---|---|---|---|---|---|
| 101 | policy | `ALTER POLICY meetups_select_visible ON public.meetups USING (public.kan713_meetup_visible(event_id))` | events half kept: kan713_meetup_visible(event_id) | D01 s3 RLS; D02 s5.3 | BLOCKED (consumer evidence) |
| 102 | policy | `ALTER POLICY meetup_attendees_select ON public.meetup_attendees USING (EXISTS (SELECT 1 FROM public.meetups m WHERE m.id = meetup_attendees.meetup_id AND public.kan713_meetup_can_read_row(m.event_id)))` | events half kept: kan713_meetup_can_read_row(m.event_id) | D01 s3 RLS; D02 A1/A5 | BLOCKED (consumer evidence) |
| 103 | policy | `ALTER POLICY meetup_attendees_select_visible ON public.meetup_attendees USING ((auth.uid() = user_id) OR EXISTS (SELECT 1 FROM public.meetups m WHERE m.id = meetup_attendees.meetup_id AND public.kan713_meetup_attendee_visible(m.event_id)))` | events half kept: kan713_meetup_attendee_visible(m.event_id) | D01 s3 RLS; D02 A1/A5 | BLOCKED (consumer evidence) |
| 104 | policy | `ALTER POLICY meetup_attendees_write ON public.meetup_attendees USING (EXISTS (SELECT 1 FROM public.meetups m WHERE m.id = meetup_attendees.meetup_id AND (public.kan713_meetup_can_write_row(m.event_id) OR auth.uid() = meetup_attendees.user_id))) WITH CHECK (EXISTS (SELECT 1 FROM public.meetups m WHERE m.id = meetup_attendees.meetup_id AND (public.kan713_meetup_can_write_row(m.event_id) OR auth.uid() = meetup_attendees.user_id)))` | events half kept: kan713_meetup_can_write_row(m.event_id) | D01 s3 RLS; D02 A1/A5 | BLOCKED (consumer evidence) |
| 201 | publication | `ALTER PUBLICATION supabase_realtime SET TABLE ONLY public.games (id)` | NOT AUTHORED: change signal for games listeners (D03 2d) needs a decision | D01 s3 KAN-716; D03 2d | BLOCKED (no replacement) |
| 202 | publication | `ALTER PUBLICATION supabase_realtime SET TABLE ONLY public.meetups (id, vibe_key)` | NOT AUTHORED: change signal for meetups listeners (D03 2d) needs a decision | D01 s3 KAN-716; D03 2d | BLOCKED (no replacement) |
| 301 | trigger | `DROP TRIGGER trg_kan711_games_mirror ON public.games` | infra: retired with the columns, same migration | D01 s3 KAN-711; D02 s5.4 | BLOCKED (consumer evidence) |
| 302 | trigger | `DROP TRIGGER trg_kan711_meetups_mirror ON public.meetups` | infra: retired with the columns, same migration | D01 s3 KAN-711; D02 s5.4 | BLOCKED (consumer evidence) |
| 303 | trigger | `DROP TRIGGER trg_zz_kan712_games_guard ON public.games` | infra: retired with the columns, same migration | D01 s3 KAN-712; D02 s5.4 | BLOCKED (consumer evidence) |
| 304 | trigger | `DROP TRIGGER trg_zz_kan712_meetups_guard ON public.meetups` | infra: retired with the columns, same migration | D01 s3 KAN-712; D02 s5.4 | BLOCKED (consumer evidence) |
| 305 | trigger | `DROP TRIGGER trg_kan713_games_a_location ON public.games` | infra; events side kept: trg_kan713_events_location | D01 s3 KAN-713; D02 s5.4 | BLOCKED (consumer evidence) |
| 306 | trigger | `DROP TRIGGER trg_kan713_games_b_joining ON public.games` | infra: retired with the columns, same migration | D01 s3 KAN-713; D02 s5.4 | BLOCKED (consumer evidence) |
| 307 | trigger | `DROP TRIGGER trg_kan713_games_c_venue_geo ON public.games` | infra; events side kept: trg_kan713_events_location | D01 s3 KAN-713; D02 s5.4 | BLOCKED (consumer evidence) |
| 308 | trigger | `DROP TRIGGER trg_kan713_meetups_a_location ON public.meetups` | infra; events side kept: trg_kan713_events_location | D01 s3 KAN-713; D02 s5.4 | BLOCKED (consumer evidence) |
| 309 | trigger | `DROP TRIGGER trg_kan713_meetups_b_joining ON public.meetups` | infra: retired with the columns, same migration | D01 s3 KAN-713; D02 s5.4 | BLOCKED (consumer evidence) |
| 310 | trigger | `DROP TRIGGER trg_kan718_games_series_occurrence ON public.games` | events side kept: trg_kan718_events_series_occurrence (D07) | D07 kan718_d07_series_unique.sql; D02 s5.4 | BLOCKED (consumer evidence) |
| 311 | trigger | `DROP TRIGGER trg_games_search_tsv ON public.games` | trg_events_search_tsv | D01 games.search_tsv; D02 A4 | BLOCKED (consumer evidence) |
| 312 | trigger | `DROP TRIGGER trg_meetups_search_tsv ON public.meetups` | trg_events_search_tsv | D01 meetups.search_tsv; D02 A4 | BLOCKED (consumer evidence) |
| 313 | trigger | `DROP TRIGGER trg_games_touch ON public.games` | trg_events_touch | D02 A4 | BLOCKED (consumer evidence) |
| 314 | trigger | `DROP TRIGGER trg_meetups_touch ON public.meetups` | trg_events_touch | D02 A4 | BLOCKED (consumer evidence) |
| 315 | trigger | `DROP TRIGGER trg_meetups_updated ON public.meetups` | trg_events_touch | D02 A4 | BLOCKED (consumer evidence) |
| 316 | trigger | `DROP TRIGGER trg_games_inherit_geo ON public.games` | trg_kan713_events_location (equivalence not proven here) | D01 games.venue_id; D02 A4 | BLOCKED (consumer evidence) |
| 317 | trigger | `DROP TRIGGER trg_games_inherit_venue_geo ON public.games` | trg_kan713_events_location (equivalence not proven here) | D02 A4 | BLOCKED (consumer evidence) |
| 318 | trigger | `DROP TRIGGER trg_meetups_inherit_geo ON public.meetups` | trg_kan713_events_location (equivalence not proven here) | D01 meetups.venue_id; D02 A4 | BLOCKED (consumer evidence) |
| 319 | trigger | `DROP TRIGGER tr_games_activity_sync ON public.games` | NOT AUTHORED: no events-side activity sync | D01 games.area_id; D02 A2 trigger fn_games_activity_sync | BLOCKED (no replacement) |
| 320 | trigger | `DROP TRIGGER tr_meetups_activity_sync ON public.meetups` | NOT AUTHORED: no events-side activity sync | D02 A2 trigger fn_meetups_activity_sync | BLOCKED (no replacement) |
| 321 | trigger | `DROP TRIGGER trg_game_created ON public.games` | NOT AUTHORED: handle_game_created reads creator_profile_id/start_at | D01 games.creator_profile_id; D02 A4 | BLOCKED (no replacement) |
| 322 | trigger | `DROP TRIGGER trg_game_updated_notify ON public.games` | NOT AUTHORED: cancel notification on events.is_cancelled | D01 games.is_cancelled; D02 A4 | BLOCKED (no replacement) |
| 323 | trigger | `DROP TRIGGER msg_system_game_cancelled ON public.games` | NOT AUTHORED: messaging system event on events.is_cancelled | D01 games.is_cancelled; D02 A4 | BLOCKED (no replacement) |
| 324 | trigger | `DROP TRIGGER trg_meetups_cancel_notify ON public.meetups` | NOT AUTHORED: cancel notification on events.is_cancelled | D01 meetups.is_cancelled; D02 A4 | BLOCKED (no replacement) |
| 325 | trigger | `DROP TRIGGER trg_meetups_outbox ON public.meetups` | NOT AUTHORED: outbox reads creator_user_id/is_cancelled/start_at | D02 A4 | BLOCKED (no replacement) |
| 326 | trigger | `DROP TRIGGER trg_games_set_host ON public.games` | NOT AUTHORED: host stamp reads creator_profile_id | D01 games.creator_profile_id; D02 A4 | BLOCKED (no replacement) |
| 327 | trigger | `DROP TRIGGER trg_games_stamp_request_id ON public.games` | NOT AUTHORED: kan611_stamp_request_id has no events trigger | D01 s4 kan611_stamp_request_id | BLOCKED (no replacement) |
| 328 | trigger | `DROP TRIGGER trg_meetups_stamp_request_id ON public.meetups` | NOT AUTHORED: kan611_stamp_request_id has no events trigger | D01 s4 kan611_stamp_request_id | BLOCKED (no replacement) |
| 329 | trigger | `DROP TRIGGER trg_games_require_challenge_sport ON public.games` | NOT AUTHORED: challenge sport rule on events.sport_id | D01 games.sport_id; D02 A4 | BLOCKED (no replacement) |
| 330 | trigger | `DROP TRIGGER trg_games_inherit_sport_from_space ON public.games` | NOT AUTHORED: space sport/capacity inheritance on events | D02 A4 | BLOCKED (no replacement) |
| 331 | trigger | `DROP TRIGGER trg_meetups_enforce_solo_sport ON public.meetups` | NOT AUTHORED: solo sport rule on events.sport_id | D01 meetups.sport_id; D02 A2 trigger | BLOCKED (no replacement) |
| 332 | trigger | `DROP TRIGGER trg_games_sync_joining_rule ON public.games` | NOT AUTHORED: joining-rule sync on events | D01 games.joining_rule; D02 A4 | BLOCKED (no replacement) |
| 333 | trigger | `DROP TRIGGER trg_meetups_sync_joining_rule ON public.meetups` | NOT AUTHORED: joining-rule sync on events (known conflict: Venue vs Space ids) | D01 meetups.venue_id; D02 A4 | BLOCKED (no replacement) |
| 401 | index | `DROP INDEX public.games_series_id_start_at_key` | D07 guard + games_series_id_idx + KAN-710 backstop | D07 kan718_d07_series_unique.sql; D01 s3 D07 | BLOCKED (consumer evidence) |
| 402 | index | `DROP INDEX public.games_creator_user_request_id_key` | events_type_creator_request_id_key (contract scope: event_type + creator_profile_id) | D01 games.request_id | BLOCKED (consumer evidence) |
| 403 | index | `DROP INDEX public.meetups_creator_user_request_id_key` | events_type_creator_request_id_key (contract scope: event_type + creator_profile_id) | D01 meetups.request_id | BLOCKED (consumer evidence) |
| 404 | index | `DROP INDEX public.idx_games_area` | events_area_idx | B05 header I3; baseline | BLOCKED (consumer evidence), baseline-only |
| 405 | index | `DROP INDEX public.idx_games_cancelled` | events_upcoming_idx | B05 header I3; baseline | BLOCKED (consumer evidence), baseline-only |
| 406 | index | `DROP INDEX public.idx_games_is_cancelled` | events_upcoming_idx | B05 header I3; baseline | BLOCKED (consumer evidence), baseline-only |
| 407 | index | `DROP INDEX public.idx_games_geo` | events_geo_location_idx | B05 header I3; baseline | BLOCKED (consumer evidence), baseline-only |
| 408 | index | `DROP INDEX public.idx_games_host` | events_creator_user_start_idx, events_creator_profile_idx | KAN-170 note; baseline | BLOCKED (consumer evidence), baseline-only |
| 409 | index | `DROP INDEX public.idx_games_search_tsv` | events_search_tsv_idx, events_game_public_search_tsv_idx | B05 header I1; baseline | BLOCKED (consumer evidence), baseline-only |
| 410 | index | `DROP INDEX public.idx_games_start_at` | events_start_at_idx | B05 header I3; baseline | BLOCKED (consumer evidence), baseline-only |
| 411 | index | `DROP INDEX public.idx_games_time` | events_type_start_at_idx | B05 header I3; baseline | BLOCKED (consumer evidence), baseline-only |
| 412 | index | `DROP INDEX public.idx_games_title_prefix` | events_title_lower_idx | B05 header I2; baseline | BLOCKED (consumer evidence), baseline-only |
| 413 | index | `DROP INDEX public.idx_games_visibility` | events_type_vis_join_idx | B05 header I3; baseline | BLOCKED (consumer evidence), baseline-only |
| 414 | index | `DROP INDEX public.idx_meetups_owner` | events_creator_user_start_idx | B05 header I5; baseline | BLOCKED (consumer evidence), baseline-only |
| 415 | index | `DROP INDEX public.idx_meetups_owner_time` | events_creator_user_start_idx | B05 header I5; baseline | BLOCKED (consumer evidence), baseline-only |
| 416 | index | `DROP INDEX public.idx_meetups_search_tsv` | events_search_tsv_idx | B05 header I4; baseline | BLOCKED (consumer evidence), baseline-only |
| 501 | constraint | `ALTER TABLE public.games DROP CONSTRAINT games_area_id_fkey` | events_area_id_fkey | D01 s3 constraints | BLOCKED (consumer evidence) |
| 502 | constraint | `ALTER TABLE public.games DROP CONSTRAINT games_capacity_check` | events_game_capacity_check | D01 s3 constraints | BLOCKED (consumer evidence) |
| 503 | constraint | `ALTER TABLE public.games DROP CONSTRAINT games_cost_cover_check` | events_cost_cover_check | D01 s3 constraints | BLOCKED (consumer evidence) |
| 504 | constraint | `ALTER TABLE public.games DROP CONSTRAINT games_cost_cover_logic` | events_cost_cover_logic | D01 s3 constraints | BLOCKED (consumer evidence) |
| 505 | constraint | `ALTER TABLE public.games DROP CONSTRAINT games_creator_profile_id_fkey` | events_creator_profile_id_fkey | D01 s3 constraints | BLOCKED (consumer evidence) |
| 506 | constraint | `ALTER TABLE public.games DROP CONSTRAINT games_geo_location_id_fkey` | events_geo_location_id_fkey | D01 s3 constraints | BLOCKED (consumer evidence) |
| 507 | constraint | `ALTER TABLE public.games DROP CONSTRAINT games_join_policy_check` | events_game_join_policy_check | D01 s3 constraints | BLOCKED (consumer evidence) |
| 508 | constraint | `ALTER TABLE public.games DROP CONSTRAINT games_join_policy_chk` | events_game_join_policy_check | D01 s3 constraints | BLOCKED (consumer evidence) |
| 509 | constraint | `ALTER TABLE public.games DROP CONSTRAINT games_joining_rule_check` | events_joining_rule_check | D01 s3 constraints | BLOCKED (consumer evidence) |
| 510 | constraint | `ALTER TABLE public.games DROP CONSTRAINT games_listing_visibility_check` | events_game_visibility_check | D01 s3 constraints | BLOCKED (consumer evidence) |
| 511 | constraint | `ALTER TABLE public.games DROP CONSTRAINT games_location_required` | events_game_area_required + events_game_geo_required (verify equal or stricter) | D01 s3 constraints | BLOCKED (consumer evidence) |
| 512 | constraint | `ALTER TABLE public.games DROP CONSTRAINT games_max_skill_check` | events_game_skill_check | D01 s3 constraints | BLOCKED (consumer evidence) |
| 513 | constraint | `ALTER TABLE public.games DROP CONSTRAINT games_min_skill_check` | events_game_skill_check | D01 s3 constraints | BLOCKED (consumer evidence) |
| 514 | constraint | `ALTER TABLE public.games DROP CONSTRAINT games_sport_id_fkey` | events_sport_id_fkey | D01 s3 constraints | BLOCKED (consumer evidence) |
| 515 | constraint | `ALTER TABLE public.games DROP CONSTRAINT games_venue_id_fkey` | events_venue_id_fkey | D01 s3 constraints | BLOCKED (consumer evidence) |
| 516 | constraint | `ALTER TABLE public.meetups DROP CONSTRAINT chk_meetups_title_len` | events_meetup_title_check | D01 s3 constraints | BLOCKED (consumer evidence) |
| 517 | constraint | `ALTER TABLE public.meetups DROP CONSTRAINT meetups_area_id_fkey` | events_area_id_fkey | D01 s3 constraints | BLOCKED (consumer evidence) |
| 518 | constraint | `ALTER TABLE public.meetups DROP CONSTRAINT meetups_capacity_check` | events_meetup_capacity_check | D01 s3 constraints | BLOCKED (consumer evidence) |
| 519 | constraint | `ALTER TABLE public.meetups DROP CONSTRAINT meetups_cost_cover_check` | events_cost_cover_check | D01 s3 constraints | BLOCKED (consumer evidence) |
| 520 | constraint | `ALTER TABLE public.meetups DROP CONSTRAINT meetups_cost_cover_logic` | events_cost_cover_logic | D01 s3 constraints | BLOCKED (consumer evidence) |
| 521 | constraint | `ALTER TABLE public.meetups DROP CONSTRAINT meetups_creator_profile_id_fkey` | events_creator_profile_id_fkey | D01 s3 constraints | BLOCKED (consumer evidence) |
| 522 | constraint | `ALTER TABLE public.meetups DROP CONSTRAINT meetups_geo_location_id_fkey` | events_geo_location_id_fkey | D01 s3 constraints | BLOCKED (consumer evidence) |
| 523 | constraint | `ALTER TABLE public.meetups DROP CONSTRAINT meetups_joining_rule_check` | events_joining_rule_check | D01 s3 constraints | BLOCKED (consumer evidence) |
| 524 | constraint | `ALTER TABLE public.meetups DROP CONSTRAINT meetups_listing_visibility_check` | events_meetup_visibility_check | D01 s3 constraints | BLOCKED (consumer evidence) |
| 525 | constraint | `ALTER TABLE public.meetups DROP CONSTRAINT meetups_rsvp_policy_check` | events_meetup_join_policy_check (known conflict: rsvp_policy vs join_policy) | D01 s3 constraints | BLOCKED (consumer evidence) |
| 526 | constraint | `ALTER TABLE public.meetups DROP CONSTRAINT meetups_sport_id_fkey` | events_sport_id_fkey | D01 s3 constraints | BLOCKED (consumer evidence) |
| 527 | constraint | `ALTER TABLE public.meetups DROP CONSTRAINT meetups_title_check` | events_meetup_title_check | D01 s3 constraints | BLOCKED (consumer evidence) |
| 528 | constraint | `ALTER TABLE public.meetups DROP CONSTRAINT meetups_venue_id_fkey` | events_venue_id_fkey | D01 s3 constraints | BLOCKED (consumer evidence) |
| 601 | column | `ALTER TABLE public.games DROP COLUMN title` | events.title via event_id | D01 games.title; D02 A2/A4; D03 2a (old store/web builds read games directly) | BLOCKED (consumer evidence) |
| 602 | column | `ALTER TABLE public.games DROP COLUMN creator_profile_id` | events.creator_profile_id via event_id | D01 games.creator_profile_id; D02 A2/A4; D03 2a (old store/web builds read games directly) | BLOCKED (consumer evidence) |
| 603 | column | `ALTER TABLE public.games DROP COLUMN creator_user_id` | events.creator_user_id via event_id | D01 games.creator_user_id; D02 A2/A4; D03 2a (old store/web builds read games directly) | BLOCKED (consumer evidence) |
| 604 | column | `ALTER TABLE public.games DROP COLUMN start_at` | events.start_at via event_id | D01 games.start_at; D02 A2/A4; D03 2a (old store/web builds read games directly) | BLOCKED (consumer evidence) |
| 605 | column | `ALTER TABLE public.games DROP COLUMN end_at` | events.end_at via event_id | D01 games.end_at; D02 A2/A4; D03 2a (old store/web builds read games directly) | BLOCKED (consumer evidence) |
| 606 | column | `ALTER TABLE public.games DROP COLUMN capacity` | events.capacity via event_id | D01 games.capacity; D02 A2/A4; D03 2a (old store/web builds read games directly) | BLOCKED (consumer evidence) |
| 607 | column | `ALTER TABLE public.games DROP COLUMN listing_visibility` | events.listing_visibility via event_id | D01 games.listing_visibility; D02 A2/A4; D03 2a (old store/web builds read games directly) | BLOCKED (consumer evidence) |
| 608 | column | `ALTER TABLE public.games DROP COLUMN join_policy` | events.join_policy via event_id | D01 games.join_policy; D02 A2/A4; D03 2a (old store/web builds read games directly) | BLOCKED (consumer evidence) |
| 609 | column | `ALTER TABLE public.games DROP COLUMN min_skill` | events.min_skill via event_id | D01 games.min_skill; D02 A2/A4; D03 2a (old store/web builds read games directly) | BLOCKED (consumer evidence) |
| 610 | column | `ALTER TABLE public.games DROP COLUMN max_skill` | events.max_skill via event_id | D01 games.max_skill; D02 A2/A4; D03 2a (old store/web builds read games directly) | BLOCKED (consumer evidence) |
| 611 | column | `ALTER TABLE public.games DROP COLUMN is_cancelled` | events.is_cancelled via event_id | D01 games.is_cancelled; D02 A2/A4; D03 2a (old store/web builds read games directly) | BLOCKED (consumer evidence) |
| 612 | column | `ALTER TABLE public.games DROP COLUMN cancelled_at` | events.cancelled_at via event_id | D01 games.cancelled_at; D02 A2/A4; D03 2a (old store/web builds read games directly) | BLOCKED (consumer evidence) |
| 613 | column | `ALTER TABLE public.games DROP COLUMN cancelled_reason` | events.cancelled_reason via event_id | D01 games.cancelled_reason; D02 A2/A4; D03 2a (old store/web builds read games directly) | BLOCKED (consumer evidence) |
| 614 | column | `ALTER TABLE public.games DROP COLUMN created_at` | events.created_at via event_id | D02 s0 / D03 s1 (not in D01's 40 pairs) | BLOCKED (consumer evidence) |
| 615 | column | `ALTER TABLE public.games DROP COLUMN updated_at` | events.updated_at via event_id | D02 s0 / D03 s1 (not in D01's 40 pairs) | BLOCKED (consumer evidence) |
| 616 | column | `ALTER TABLE public.games DROP COLUMN search_tsv` | events.search_tsv via event_id | D01 games.search_tsv; not in the D02/D03 slated sets | BLOCKED (consumer evidence) |
| 617 | column | `ALTER TABLE public.games DROP COLUMN sport_id` | events.sport_id via event_id | D01 games.sport_id; D02 A2/A4; D03 2a (old store/web builds read games directly) | BLOCKED (consumer evidence) |
| 618 | column | `ALTER TABLE public.games DROP COLUMN geo_location_id` | events.geo_location_id via event_id | D01 games.geo_location_id; D02 A2/A4; D03 2a (old store/web builds read games directly) | BLOCKED (consumer evidence) |
| 619 | column | `ALTER TABLE public.games DROP COLUMN area_id` | events.area_id via event_id | D01 games.area_id; D02 A2/A4; D03 2a (old store/web builds read games directly) | BLOCKED (consumer evidence) |
| 620 | column | `ALTER TABLE public.games DROP COLUMN venue_id` | events.venue_id via event_id | D01 games.venue_id; D02 A2/A4; D03 2a (old store/web builds read games directly) | BLOCKED (consumer evidence) |
| 621 | column | `ALTER TABLE public.games DROP COLUMN joining_rule` | events.joining_rule via event_id | D01 games.joining_rule; D02 A2/A4; D03 2a (old store/web builds read games directly) | BLOCKED (consumer evidence) |
| 622 | column | `ALTER TABLE public.games DROP COLUMN cost_cover` | events.cost_cover via event_id | D01 games.cost_cover; D02 A2/A4; D03 2a (old store/web builds read games directly) | BLOCKED (consumer evidence) |
| 623 | column | `ALTER TABLE public.games DROP COLUMN request_id` | events.request_id via event_id | D01 games.request_id; D02 A2/A4; D03 2a (old store/web builds read games directly) | BLOCKED (consumer evidence) |
| 701 | column | `ALTER TABLE public.meetups DROP COLUMN creator_profile_id` | events.creator_profile_id via event_id | D01 meetups.creator_profile_id; D02 A2/A4; D03 2c (no direct client read) | BLOCKED (consumer evidence) |
| 702 | column | `ALTER TABLE public.meetups DROP COLUMN creator_user_id` | events.creator_user_id via event_id | D01 meetups.creator_user_id; D02 A2/A4; D03 2c (no direct client read) | BLOCKED (consumer evidence) |
| 703 | column | `ALTER TABLE public.meetups DROP COLUMN title` | events.title via event_id | D01 meetups.title; D02 A2/A4; D03 2c (no direct client read) | BLOCKED (consumer evidence) |
| 704 | column | `ALTER TABLE public.meetups DROP COLUMN description` | NO HOME: events has no description column and KAN-718 does not retain it; dropping loses data | EVIDENCE GAP: not in the D01/D02/D03 slated sets; v_meetup_list reads it; no events column holds it | BLOCKED (hard: v_meetup_list) |
| 705 | column | `ALTER TABLE public.meetups DROP COLUMN listing_visibility` | events.listing_visibility via event_id | D01 meetups.listing_visibility; D02 A2/A4; D03 2c (no direct client read) | BLOCKED (consumer evidence) |
| 706 | column | `ALTER TABLE public.meetups DROP COLUMN rsvp_policy` | events.join_policy via event_id (renamed; known value conflict) | D01 meetups.rsvp_policy; D02 A2/A4; D03 2c (no direct client read) | BLOCKED (consumer evidence) |
| 707 | column | `ALTER TABLE public.meetups DROP COLUMN capacity` | events.capacity via event_id | D01 meetups.capacity; D02 A2/A4; D03 2c (no direct client read) | BLOCKED (consumer evidence) |
| 708 | column | `ALTER TABLE public.meetups DROP COLUMN start_at` | events.start_at via event_id | D01 meetups.start_at; D02 A2/A4; D03 2c (no direct client read) | BLOCKED (consumer evidence) |
| 709 | column | `ALTER TABLE public.meetups DROP COLUMN end_at` | events.end_at via event_id | D01 meetups.end_at; D02 A2/A4; D03 2c (no direct client read) | BLOCKED (consumer evidence) |
| 710 | column | `ALTER TABLE public.meetups DROP COLUMN is_cancelled` | events.is_cancelled via event_id | D01 meetups.is_cancelled; D02 A2/A4; D03 2c (no direct client read) | BLOCKED (consumer evidence) |
| 711 | column | `ALTER TABLE public.meetups DROP COLUMN created_at` | events.created_at via event_id | D02 s0 / D03 s1 (not in D01's 40 pairs) | BLOCKED (consumer evidence) |
| 712 | column | `ALTER TABLE public.meetups DROP COLUMN updated_at` | events.updated_at via event_id | D02 s0 / D03 s1 (not in D01's 40 pairs) | BLOCKED (consumer evidence) |
| 713 | column | `ALTER TABLE public.meetups DROP COLUMN search_tsv` | events.search_tsv via event_id | D01 meetups.search_tsv; not in the D02/D03 slated sets | BLOCKED (consumer evidence) |
| 714 | column | `ALTER TABLE public.meetups DROP COLUMN geo_location_id` | events.geo_location_id via event_id | D01 meetups.geo_location_id; D02 A2/A4; D03 2c (no direct client read) | BLOCKED (consumer evidence) |
| 715 | column | `ALTER TABLE public.meetups DROP COLUMN sport_id` | events.sport_id via event_id | D01 meetups.sport_id; D02 A2/A4; D03 2c (no direct client read) | BLOCKED (consumer evidence) |
| 716 | column | `ALTER TABLE public.meetups DROP COLUMN area_id` | events.area_id via event_id | D01 meetups.area_id; D02 A2/A4; D03 2c (no direct client read) | BLOCKED (consumer evidence) |
| 717 | column | `ALTER TABLE public.meetups DROP COLUMN venue_id` | events.venue_id via event_id | D01 meetups.venue_id; D02 A2/A4; D03 2c (no direct client read) | BLOCKED (consumer evidence) |
| 718 | column | `ALTER TABLE public.meetups DROP COLUMN min_skill` | events.min_skill via event_id | D01 meetups.min_skill; D02 A2/A4; D03 2c (no direct client read) | BLOCKED (consumer evidence) |
| 719 | column | `ALTER TABLE public.meetups DROP COLUMN max_skill` | events.max_skill via event_id | D01 meetups.max_skill; D02 A2/A4; D03 2c (no direct client read) | BLOCKED (consumer evidence) |
| 720 | column | `ALTER TABLE public.meetups DROP COLUMN joining_rule` | events.joining_rule via event_id | D01 meetups.joining_rule; D02 A2/A4; D03 2c (no direct client read) | BLOCKED (consumer evidence) |
| 721 | column | `ALTER TABLE public.meetups DROP COLUMN cost_cover` | events.cost_cover via event_id | D01 meetups.cost_cover; D02 A2/A4; D03 2c (no direct client read) | BLOCKED (consumer evidence) |
| 722 | column | `ALTER TABLE public.meetups DROP COLUMN location_name` | NO HOME: events has no location_name column and KAN-718 does not retain it; dropping loses data | EVIDENCE GAP: not in the D01/D02/D03 slated sets; v_meetup_list reads it; no events column holds it | BLOCKED (hard: v_meetup_list) |
| 723 | column | `ALTER TABLE public.meetups DROP COLUMN is_indoor` | NO HOME: events has no is_indoor column and KAN-718 does not retain it; dropping loses data | EVIDENCE GAP: not in the D01/D02/D03 slated sets; v_meetup_list reads it; no events column holds it | BLOCKED (hard: v_meetup_list) |
| 724 | column | `ALTER TABLE public.meetups DROP COLUMN request_id` | events.request_id via event_id | D01 meetups.request_id; D02 A2/A4; D03 2c (no direct client read) | BLOCKED (consumer evidence) |

**Kept, not in the manifest**, because these read only `id`/`event_id`:

- `*_event_link_check`;
- the KAN-711 `assign_event_id` triggers;
- the KAN-712 after-delete triggers;
- `trg_games_series_occurrence_check`.

`trg_meetups_aaa_host_actor_stub` is a local harness object and is excluded.

## 5. What the check proves (`kan718_d06_manifest_check.sql`)

- **Guard:** it refuses any database with Supabase roles or namespaces, any database not named
  `k788*`/`k774*`, and any non-superuser. It was run against `postgres` and refused, as expected.
- **M1:** one `DROP COLUMN` per slated column, and every retained column exists.
- **M2:** every column-level `pg_depend` dependent of a slated column has its own entry:
  - constraints, indexes, triggers, policies and the publication;
  - `v_meetup_list` is the named hard block.
- **M3:** every non-internal trigger whose function reads a slated `NEW.`/`OLD.` column, or the whole row, has
  an entry.
- **M4:**
  - no CASCADE, wildcard or IF EXISTS;
  - every local object exists;
  - every named replacement object exists on `events` or in `public`.
- **M5:** every entry carries evidence and a replacement (or a named gap).
- **D1:**
  - a dry run of all 117 local statements, in order, inside `BEGIN … ROLLBACK`, each in a savepoint;
  - everything runs except the 3 hard-blocked entries, which the catalogue refuses because of `v_meetup_list`;
  - after ROLLBACK the columns, triggers, constraints, policies and publication lists are identical.
- **S1–S5:** one game and one meetup through the legacy path, on the intact schema:
  - S1: no doubling;
  - S2: counts equal legacy;
  - S3: legacy shapes unchanged and NULLs preserved;
  - S4: a stranger and a blocked user see nothing extra;
  - S5: the md5 of games, meetups and events is identical after ROLLBACK.

## 6. Run (local throwaway cluster only)

```
bash supabase/tests/events_p2/build_kan788.sh <tmpdir>/k774_pg 54774
psql -X -h /tmp -p 54774 -U postgres -d k788 -c 'CREATE PUBLICATION supabase_realtime'   # local stand-in
for f in 20261104102000_kan716_events_realtime_publication 20261104110300_kan718_d07_series_occurrence_unique \
         20261104110400_kan785*; do psql -X -h /tmp -p 54774 -U postgres -d k788 -v ON_ERROR_STOP=1 -f supabase/migrations/$f*.sql; done
psql -X -h /tmp -p 54774 -U postgres -d k788 -v ON_ERROR_STOP=1 -P pager=off -f supabase/tests/events_p4/kan718_d06_manifest_check.sql
```

Output (2026-11-03, exit 0):

```
NOTICE:  KAN-774 M1 PASS: 47 DROP COLUMN entries (games 23, meetups 24); all 19 retained columns present
NOTICE:  KAN-774 M2 PASS: every column-level dependent (constraint, index, trigger, policy, publication) has an entry; v_meetup_list is the named hard block
NOTICE:  KAN-774 M3 PASS: 33 trigger entries cover every trigger reading a slated column or the whole row
NOTICE:  KAN-774 M4 PASS: 130 statements, no CASCADE/wildcard/IF EXISTS; 117 local objects exist (13 baseline-only, verify in production); 104 named replacements exist
NOTICE:  KAN-774 M5 PASS: every entry cites evidence; 20 entries have NO authored replacement; deletion stays BLOCKED (D01 40/40 pending, D02 BLOCKED, D03 BLOCKED)
NOTICE:  KAN-774 D1 refused as expected: 704 meetups.description -> cannot drop column description of table meetups because other objects depend on it (view v_meetup_list depends on column description of table meetups)
NOTICE:  KAN-774 D1 refused as expected: 722 meetups.location_name -> cannot drop column location_name of table meetups because other objects depend on it (view v_meetup_list depends on column location_name of table meetups)
NOTICE:  KAN-774 D1 refused as expected: 723 meetups.is_indoor -> cannot drop column is_indoor of table meetups because other objects depend on it (view v_meetup_list depends on column is_indoor of table meetups)
NOTICE:  KAN-774 D1 PASS: 114 statements ran without CASCADE, 3 refused exactly where marked hard (v_meetup_list), 13 baseline-only skipped
NOTICE:  KAN-774 D1 rollback PASS: columns, triggers, constraints, policies and publication lists identical after ROLLBACK
NOTICE:  KAN-774 S1 PASS: 1 game + 1 meetup seeded; one events parent each, id kept, no duplicate events ids
NOTICE:  KAN-774 S2 PASS: games 3011 = game events, meetups 2012 = meetup events, events 5023 = sum
NOTICE:  KAN-774 S3 PASS: all 47 manifest columns still present (nothing deleted); legacy rows equal their events parent; NULLs preserved
NOTICE:  KAN-774 S4: events refused to API roles (42501), as designed
NOTICE:  KAN-774 S4 PASS: stranger and blocked see 0 new games/events; stranger sees the public meetup (legacy), blocked sees 0
NOTICE:  KAN-774 S5 PASS: md5 of games 47f59aac, meetups 1ece1c51, events 80877ca9 identical after ROLLBACK
NOTICE:  KAN-774 PASS: manifest matches the catalogue; deletion remains BLOCKED
```

## 7. Limitations

- **The local harness is a subset of production.**
  - 13 baseline indexes are absent locally, so they were skipped in D1.
  - Production may hold objects this catalogue does not.
  - Before phase 4, M2/M3 must be re-run read-only against a production schema dump.
- **Equivalences not proven here:**
  - `trg_kan713_events_location` versus the three inherit-geo triggers;
  - `events_game_area_required` + `events_game_geo_required` versus `games_location_required`;
  - `events_type_creator_request_id_key` is scoped to profile, while the legacy key is scoped to user (this is
    the contract scope).
- **plpgsql references do not block `DROP COLUMN`.** Functions that read slated columns fail only at run time.
  Their evidence is D01/D02, not D1.
- **No migration is authored.** This is the manifest only. The phase-4 migration is a later ticket.
