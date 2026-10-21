# Sport Overview counts: `rpc_sport_overview` (KAN-621)

Status: authored, not applied. Migration `supabase/migrations/20261021130000_sport_overview_counts.sql`, probes and rollback in `supabase/tests/sport_overview/`. Frontend consumer: KAN-622.

## Signature
`public.rpc_sport_overview(p_sport_id uuid, p_city_code text default null)` returns one row. STABLE, SECURITY DEFINER, `search_path = public, pg_temp`, EXECUTE for `authenticated` only (revoked from PUBLIC and anon). Read-only; no table, column or policy is touched.

## Parameters
| Parameter | Meaning |
|---|---|
| `p_sport_id` | `sports.id`. An unknown id returns zeros and `[]`, not an error. |
| `p_city_code` | `ref_cities.code`. `NULL` = all cities. It is text, not uuid: no uuid city exists in the schema (`ref_cities` is keyed by `code`). Decision dreq-d8a48630. |
| 7-day window | Constant `v_window` inside the function (games and meetups). Changed by `CREATE OR REPLACE`. |

## Area-to-city join
`<games|meetups|venues|news>.area_id -> areas.id`, then `areas.city_code = p_city_code` (`areas.city_code` is a FK to `ref_cities.code`). Spaces use their venue's area. Posts are not city-scoped.

## Output and rules
| Field | Rule |
|---|---|
| `followers` | Global (never city-scoped). Distinct `profiles` with `interests @> {sport}`; profiles the caller has a block with, either way (`user_blocks`), are left out. |
| `games_next7`, `meetups_next7` | `listing_visibility = 'public'`, not cancelled, `start_at` in the next 7 days, creator not blocked with the caller. City-scoped. |
| `venues` | Active venues offering the sport: an active space of the sport, or the sport key in `venues.sports`. One per venue. City-scoped. |
| `spaces` | Active `venue_spaces` of the sport inside an active venue. Counted separately; never summed with venues (a venue with 3 spaces = 1 venue, 3 spaces). |
| `posts` | `visibility = 'public'`, not deleted, not admin-hidden, active, unexpired, author not blocked. **Not city-scoped:** the app has no post city (KAN-592 `posted_from_city` is unapplied), so none is invented and `posts.area_id` is not used. The value is the same for every `p_city_code`. |
| `news` | `status = 'published'`, `published_at <= now()`, unexpired. City-scoped; news with no area counts only when `p_city_code` is NULL. |
| `mutual_followers` | At most 3 `{display_name, avatar_url, username}`: profiles the caller follows (`profile_follows`) who follow the sport; excludes the caller and blocked users; `[]` if none. No other user field. |

Every count is `count(DISTINCT id)`.

## Not done here
No Places table and no `sport_follows` table (the prototype's); no change to `profiles.interests`, `preferred_sport` or `primary_sport`; no client change. Probes are authored, not executed.
