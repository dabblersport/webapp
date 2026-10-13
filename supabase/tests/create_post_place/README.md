# KAN-524: create_post keeps the place for circle posts

**Status: AUTHORED, NOT APPLIED, NOT RUN.** The team applied nothing and ran nothing against any database. Memphis
applies the migration under the CEO approval of 2026-10-13 (execute_sql only, never apply_migration, test data only,
stop on real user data) and records the real PASS/FAIL of the probes. Until then no document here claims a probe was run.
Only project `wtncuzcskpigqpmnxwws` is referenced; no secret, key or connection string is in any file.

| File | Purpose |
|---|---|
| `supabase/migrations/20261013150000_create_post_keeps_place.sql` | Renames the 15-argument `create_post` to `create_post_legacy_v1` (revoked from PUBLIC, anon, authenticated), creates `create_post` with the 15 old parameters then `p_venue_id, p_location_name, p_geo_lat, p_geo_lng, p_area_id` (all `DEFAULT NULL`), stores them on the post, raises `geo_incomplete` for half a coordinate pair, restores the baseline ACL. Nothing is removed. |
| `CALLERS.md` | Caller map: three app calls, all named parameters. |
| `probes.sql` | Pre-apply and post-apply probes; every block `BEGIN ... ROLLBACK`, marked READ-ONLY or WRITE-IN-TRANSACTION-ROLLBACK. AUTHORED, NOT RUN. |
| `rollback.sql` | Undo (itself an apply by Memphis). |
| `test/supabase/create_post_place_migration_test.dart` | Static checks of the files. Runs no SQL. |

## What `trg_posts_set_geo` does with a supplied place (read from baseline `trgfn_posts_set_geo`, line 19384; a fact for the frontend ticket, not a reason to edit the trigger)

The trigger runs BEFORE INSERT OR UPDATE and the first matching path wins:

1. **`venue_id` supplied: the venue wins.** `geo_location_id`, `area_id`, `geo_lat` and `geo_lng` are all OVERWRITTEN from the venue. A supplied `area_id`, `geo_lat` and `geo_lng` are discarded. `venue_id` and `location_name` are kept as supplied.
2. **else `game_id` supplied: the game wins** (same four columns overwritten from the game). A supplied venue-less point is discarded.
3. **else `geo_lat` and `geo_lng` supplied:** the supplied coordinates are KEPT; `area_id` is OVERWRITTEN with the nearest area (a supplied `area_id` is discarded) and a `geo_locations` row is created. `location_name` is kept.
4. **else:** the author profile's last known location, else the first active area's centre, with the nearest area.

Consequences: the trigger never rejects a supplied `area_id`; it ignores it on every path. So `p_area_id` is accepted and stored by the INSERT but the trigger rewrites it; a circle post with a venue gets the venue's area, a post with a point gets the nearest area. `p_location_name` and `p_venue_id` survive. Probes B3 and B4 record what actually happens on a real database.

## Backward compatibility

A call naming only the old parameters resolves to the new function (the defaulted trailing parameters are omitted) and inserts NULL for the five new columns, which is what the omitted columns were before, so the trigger takes the same path as before. The legacy function is callable by `service_role` only. There is exactly one `create_post`, so named-argument calls stay unambiguous.

## Apply order and rollback

1. KAN-497 and KAN-499's migrations come first if they are being applied (this file sorts after them).
2. Memphis runs section A of `probes.sql`, applies the migration, then runs section B; every B assertion should FAIL before the migration (that is the proof the probe can fail).
3. Rollback: `rollback.sql` renames the new 20-argument function to `create_post_v2_rolledback` (revoked), renames `create_post_legacy_v1` back to `create_post`, and restores the baseline ACL. It uses no DROP. **Rollback is itself an apply and needs Memphis.** It re-opens the bug; posts already created with a place keep it.
