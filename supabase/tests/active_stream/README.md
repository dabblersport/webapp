# KAN-595 Active stream (backend half)

Migration: `supabase/migrations/20261020120000_kan595_active_stream.sql` (AUTHORED, NOT APPLIED).
Probes: `probes.sql`, rollback: `rollback.sql` (both AUTHORED, NOT RUN).

**The UI waits for the approved Claude Design reference.** No Flutter UI, no `lib/` change and no visual has been
written for this ticket. The RPC name constant (`supabase_config.dart`) is added with the UI half.

## RPC

`public.active_stream(p_event_types text[] = NULL, p_city text = NULL, p_limit int = 30, p_before timestamptz = NULL,
p_before_type text = NULL, p_before_entity uuid = NULL)` returns
`(event_type, event_at, entity_kind, entity_id, actor_profile_id, city, title)`, newest first
(`event_at DESC, event_type DESC, entity_id DESC`). Keyset: pass the last row's `(event_at, event_type, entity_id)`.
`p_limit` is clamped to 1..50. SECURITY DEFINER, `search_path = public, pg_temp`, EXECUTE for `authenticated` only.

## Event table

| event_type | source | event_at |
|---|---|---|
| player_joined | `profiles` (`profile_type = 'personal'`) | `profiles.created_at` |
| venue_added | `venues` | `venues.created_at` |
| game_created | `games` | `games.created_at` |
| game_started | `games` | `games.start_at` (when `<= now()`) |
| game_ended | `games` | `games.end_at` (when `<= now()`) |
| meetup_created | `meetups` | `meetups.created_at` |
| meetup_started | `meetups` | `meetups.start_at` (when `<= now()`) |
| meetup_completed | `meetups` | `COALESCE(end_at, start_at)` (when `<= now()`) |

"Started/ended" are the scheduled times passing: neither table has a status column or a transition timestamp.
Cancelled games/meetups are excluded from every type. "New event" is a classification of an activity, not a listing.

## Visibility and blocks

- games: `_can_view_game(id)`; meetups: `can_view_owner(creator_user_id, listing_visibility)`;
  venues: `is_active`; profiles: `is_profile_publicly_visible(id)`.
- Every branch: `NOT is_blocked(auth.uid(), <actor user>)`, both directions.
- City: selected-city text matched case-insensitively to `areas.city` / `profiles.city`; NULL = all cities.
  The RPC takes no coordinates and never needs location permission.
- No posts, news or message content are read; no counters.
