# KAN-710 handoff: events parent schema (E2)

Status: **AUTHORED, NOT APPLIED.** Memphis applies after review. Contract: KAN-709.

## Files
| file | purpose |
|---|---|
| `supabase/migrations/20261101140000_kan710_events_parent_schema.sql` | the migration (migration id `20261101140000`) |
| `supabase/tests/events_parent/probes_kan710.sql` | Part A read-only probes; Part B adversarial probes (branch DB only) |
| `supabase/tests/events_parent/rollback_kan710.sql` | rollback (needs DROP authority; refuses once data exists) |
| `supabase/tests/events_parent/HANDOFF_KAN710.md` | this file |

Apply: run the migration once. Rollback: run `rollback_kan710.sql`, then KAN-709/09 P-11.

## Schema / permissions / index manifest (for operations)
- Table `public.events`, owner postgres, RLS enabled + forced, **0 policies**, all grants to PUBLIC/anon/authenticated revoked (service_role keeps the Supabase default).
- 24 columns per KAN-709/01 (`min_skill`/`max_skill` smallint per contract; Jira said integer).
- FKs: creator_profile RESTRICT; sport, area, venue SET NULL; geo_location NO ACTION. `creator_user_id` has no FK.
- Per-type named checks: event_type, end_after_start, joining_rule, cost_cover, cost_cover_logic, game_{end_required,capacity,visibility,join_policy,sport_required,area_required,geo_required,skill}, meetup_{title,capacity,visibility,join_policy,cancel_null}.
- Indexes (11): pkey, start_at, (event_type,start_at), (creator_user_id,start_at desc), creator_profile, (event_type,listing_visibility,join_policy), geo_location, area, partial upcoming, lower(unaccent_immutable(title)) text_pattern_ops, GIN search_tsv, plus unique partial `events_type_creator_request_id_key`.
- `games.event_id`, `meetups.event_id`: uuid NULL, UNIQUE, FK events(id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED.
- Functions (all owner postgres, EXECUTE revoked from PUBLIC/anon/authenticated): `events_set_search_tsv`, `events_guard_type_immutable` (invoker), `events_check_subtype_link`, `events_check_parent_children`, `events_check_series_occurrence` (SECURITY DEFINER, `search_path = public, pg_temp`).
- Triggers: on events touch, tsv, type-immutable, deferred exclusive check, deferred series start check; on games/meetups deferred link check; on games deferred series check. Reuses existing `touch_updated_at()`.
- No publication, no notify, no outbox, no activity trigger.

## Contract rows owned by KAN-710
| contract | covered by |
|---|---|
| 01 columns, per-type checks, FKs | migration §1 |
| 04 / 03 §D: forced RLS, 0 policies, REVOKE ALL, postgres-owned, search_path | §2, §4 |
| 01 §6 indexes + request-id partial unique | §3 |
| 03 §B touch_updated_at KEEP attached to events | §5 |
| 03 §B events tsv trigger (trg_games_search_tsv / trg_meetups_search_tsv REWRITE partially) | §4a (see limitation 1) |
| 01 subtype link, exclusive ownership | §4c, §4d, §6 |
| 01 §7 series uniqueness (phase 2 mechanism) | §4e, inert in phase 1 |
| 03 §C inbound FK semantics | no FK on any existing table is touched; NO ACTION FKs on posts/msg_conversations still block a hard game delete |

## Known limitations and open decisions
1. **meetup full-text on the parent is title-only**: description and location_name live on the meetups subtype. `meetups.search_tsv` stays authoritative until KAN-718.
2. **SET NULL vs game NOT NULL**: `events.sport_id`/`area_id` are SET NULL per contract, but game events require both; a delete of a referenced sport/area is therefore refused by the check (effectively NO ACTION). Same outcome as legacy games.
3. **Parent exactly-one-child is not enforced** (phase 1); E4 (KAN-712) enables it. Deleting a game/meetup leaves its parent until then.
4. **Series trigger is untested against real data** (no events-linked games exist). It counts cancelled slots as occupied.
5. **Assumption E-02**: role postgres has BYPASSRLS, so FORCE RLS does not block the definer functions. Probe E-02 checks it; if false, the link checks fail on first use.
6. **Not run**: no local Postgres in the authoring environment, so no SQL here has been executed (C2 = not run). The live baseline re-check (games 232 / meetups 8 / 20 inbound FKs) was refused by the ops guard on `execute_sql`; not performed.
7. Unknowns unchanged and not resolved here: U7 (venue geo mismatch), U10 (id collision), U11 (series_id count), U12 (request_id collisions), U13 (host_actor_id equality). U10/U12 gate KAN-711.

## Next-stage prerequisites (KAN-711)
Apply this migration; run Part A; run Part B on a branch DB; measure U10 and U12 before the backfill.
