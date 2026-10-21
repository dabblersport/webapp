# Sport Overview page (KAN-622)

The public page of one sport (not a user's Sport Profile). Route `/sport/:sportId`
(`RoutePaths.sportOverview`), behind `FeatureFlags.sportOverview`. Code: `lib/features/sports/`.

## Data (all read-only)

| Section | Source |
|---|---|
| Identity, formats | `sports` + `sport_variants` |
| Followers (global), counts, mutual followers | `rpc_sport_overview(p_sport_id, p_city_code)` (KAN-621, **migration not yet applied**) |
| Games / Meetups | `v_game_card` / `v_meetup_list`, public, not cancelled, next 7 days, soonest first, areas of the city |
| Venues / Spaces | `venues` (top-rated first) / `venue_spaces` (lowest price first), city via `areas.city_code` |
| Posts | `posts` ids for `sport_id`, newest first, then `PostRepository.getPostsByIds`. No Following filter, not city-scoped |
| Follow / Unfollow | `profiles.interests` of the active persona only; guards read Primary (`primary_sport`/`preferred_sport`), Practicing (`sport_profiles` / `organiser`) and the last-Following rule fresh from the database |

Named constants (one-line change on a ruling): `kSportOverviewWindow`, `kSportOverviewPreviewCount`,
`kSportOverviewListLimit`, `kSportOverviewPostsPage` in `data/sport_overview_repository.dart`.

## City

Default from the device city (read only). A page-local choice uses the map-service city search and is
never written to the device location, saved places, service region or profile. The RPC takes a
`ref_cities.code`; the page maps the city name to a code through `ref_cities` (`name_en`/`name_ar`).
A city with no code shows every city and says so.

## Not built (recorded on the ticket, unresolved product decisions)

- Share, More, tapping the follower count: no specified destination.
- Places tab/tile: no source exists.
- News tab: the news repository only serves the Home news tab, not a sport's news.
- Create game opens the existing flow with `?sport=<id>`; the composer does not read it yet (see below).

## Gaps found

1. **Create game preselect.** `GameComposerScreen` has no input for a preselected sport and its state is
   private; reading `?sport=` needs a small edit in `lib/features/games/` (outside this ticket's allowed paths).
2. **"Do you want to create profile?"** did not exist in the app. The sport page asks it itself before a
   join/RSVP (`join_gate.dart`): Yes calls `rpc_create_sport_profile` and adds Following; No joins nothing.
   The Games/Meetups listings are unchanged and still join without it.
3. **Protected-state visuals.** The existing copy was a hard-coded "You must have at least one sport"; the
   Practicing and Primary refusals have no designed visual. They use plain toasts (l10n keys
   `sport_overview_unfollow_*`).
4. Arabic strings (`sport_overview_*`) are provisional, for content review.
