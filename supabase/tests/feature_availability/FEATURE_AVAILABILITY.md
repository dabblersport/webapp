# KAN-585 Feature availability by service region

Migration `supabase/migrations/20261022100000_kan585_feature_availability.sql` - **AUTHORED, NOT APPLIED.**

## Inventory

| Compile-time flag (`FeatureFlags`) | Stable id | Seeded? |
|---|---|---|
| `enableMeetups` | `meetups` | yes, 6 regions, enabled |
| `enableFavourites` | `favourites` | yes |
| `enableGameBrowsing` | `game_browsing` | yes |
| `enablePlayerGameCreation` | `player_game_creation` | yes |
| `enableOrganiserGameCreation` | `organiser_game_creation` | yes |
| `enablePlayerGameJoining` | `player_game_joining` | yes |
| `enableOrganiserGameJoining` | `organiser_game_joining` | yes |
| `socialFeed` | `social_feed` | yes |
| `messaging` | `messaging` | yes |
| `enableMessagingGameChat` | `messaging_game_chat` | yes |
| `enableMessagingDirect` | `messaging_direct` | yes |
| `enableMessagingReporting` | `messaging_reporting` | yes |
| `messagingRealtime` | `messaging_realtime` | yes |
| `notifications` | `notifications` | yes |
| `multiSport` | `multi_sport` | yes |
| `organiserProfile` | `organiser_profile` | yes |
| `venuesBooking` | `venues_booking` | yes |
| `enableBookingFlow` | `booking_flow` | yes |
| `enableEarlyBirdCheckIn` | `early_bird_check_in` | **excluded** (compile-time false) |
| `enableDataExport` | `data_export` | **excluded** (compile-time false) |
| `enablePayments` | `payments` | **excluded** (compile-time false) |
| `enableCommunityMobileNav` | `community_mobile_nav` | **excluded** (compile-time false) |

The four excluded ids are reserved. Seeding them is a future rollout, done by a new migration once the compile-time flag ships true.

Regions: `Egypt`, `Morocco`, `Qatar`, `Saudi Arabia`, `United Arab Emirates`, `Global` (same set as KAN-584).

## Stable-id rules

- Format `^[a-z][a-z0-9_]{1,63}$` (enforced by CHECK).
- An id is **never renamed and never reused** for a different feature. A retired feature keeps its id (rows may be left disabled); a new feature gets a new id.

## Read permissions

- `authenticated`: SELECT on the table (RLS policy `feature_availability_select_authenticated`) and EXECUTE on `get_feature_availability()`.
- `anon` and `PUBLIC`: nothing.

## Who may edit

Only `service_role` or a migration. There are no INSERT/UPDATE/DELETE policies or grants for `authenticated`, and no admin UI.

## Evaluation rule

`get_feature_availability()` (SECURITY DEFINER, `search_path = pg_catalog, public`) resolves the caller's region from `public.account_service_region` where `user_id = auth.uid()`, falls back to `Global` when there is no row, and returns that region's `(feature_id, enabled)` rows. Never GPS or IP.

App side: **effective = compile-time flag AND remote value.** Remote config can never turn on a compile-off feature.

## Refresh, cache, unavailable config

- The app fetches on sign-in / app start / region change and caches the last good result.
- Missing row for an id, RPC error, offline, or signed out => keep the last good cached value, else the compile-time default. **Never silently disable an available feature.**

## Rollout (needs ops)

1. Peer-review the migration (backend PEER route).
2. Operations applies the migration to project `wtncuzcskpigqpmnxwws`.
3. Run `probes.sql` (P1-P9) and record results; P6 and P9 must fail as stated.
4. Ship the app build that reads the RPC.
5. To disable a feature in a region: a new migration (or service_role) runs `UPDATE public.feature_availability SET enabled = false, updated_at = now() WHERE feature_id = ... AND region = ...`.

## Rollback

`rollback.sql` drops the function, policy and table (only what this migration created). The app then keeps its cached value or the compile-time default.
