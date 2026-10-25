# KAN-594 Nearby ranking: examples for product approval (AC3)

Status: PROPOSAL. No weight below is approved and none is in code. Today's code (`getNearbyFeed`, post_repository_impl.dart) sorts by distance only inside a ~111 km box, over-fetches 3x and slices by offset, which drops posts without coordinates and can duplicate or skip rows between pages.

Illustrative shape only: score = 0.5^(age / H) x 1 / (1 + distance / D), higher first. H = 24 h and D = 5 km are placeholders to react to.

| Post | Age | Distance | Recency | Distance | Score | Rank |
|---|---|---|---|---|---|---|
| C | 6 h | 4 km | 0.84 | 0.56 | 0.47 | 1 |
| B (older, closer) | 30 h | 0.8 km | 0.42 | 0.86 | 0.36 | 2 |
| A (newer, farther) | 1 h | 12 km | 0.97 | 0.29 | 0.28 | 3 |
| D (new, far) | 3 h | 25 km | 0.92 | 0.17 | 0.15 | 4 |
| E (old, very close) | 72 h | 0.3 km | 0.13 | 0.94 | 0.12 | 5 |

Reading: a 30 h post 0.8 km away beats a 1 h post 12 km away, and a 3-day-old post next door still loses to fresh content. Distance-only would put E first and time-only would put A first; both are what AC2 forbids.

## Cases
- **City only (no Area, no usable location):** candidates = posted_from_city = selected City (NULL = Dubai). Newest first, id as tiebreak. No distance, sort or radius. Needs no weights.
- **Area selected:** origin = the Area's centroid. Blended score above.
- **Auto location unavailable:** origin = last known device position, with a visible "last known" label (TC6). Never re-prompts for permission.
- **City changed:** the candidate set is the new City only; old City posts vanish (TC5).
- **Post without coordinates (TC4), choose one:** (a) recommended: treat distance as 2 x D (factor 0.33), so it ranks by recency but never above a nearby post of similar age; (b) neutral factor 0.5; (c) after all coordinate posts, newest first. Under (a) a 10-minute-old post without coordinates scores 0.33 and lands between B and A.
- **Pagination and duplicates:** page 1 fixes `as_of`; every page uses that same value, so scores cannot drift. Cursor = (score, id) of the last row; id breaks ties. A post can never appear twice and a new post never shifts a later page. Pull-to-refresh starts a new `as_of`.
- **Privacy and Following:** same visibility predicate as other feeds; KAN-593 Following filter applies (untagged always shown, empty Following unfiltered).

## Open choices for product
1. H (recency half-life) and D (distance scale), or a different blend shape.
2. Missing-coordinate rule: (a), (b) or (c).
3. Whether a hard radius cap applies inside the City (proposal: none, the City is the boundary).
4. Last-known origin: how old is too old before falling back to City-only (proposal: 24 h).

Candidate-set SQL draft (no weights, not applied): docs/kan594/nearby_candidate_set.draft.sql

## Implemented (step 2, product ruling of 2026-10-22)
Approved: H = 24 h, D = 5 km, missing coordinates = distance 2 x D (factor 0.33), no radius cap (the selected City is the boundary), last-known origin valid for 24 h then City-only newest first. All values are in `lib/features/social/domain/nearby_ranking_config.dart`.

- `nearby_ranking.dart`: pure score, rank, `(score, id)` cursor, origin resolution.
- `nearby_feed_loader.dart`: fixes `as_of` and the origin on page 1; later pages continue after the cursor.
- `data/nearby_candidate_source.dart`: the City candidate set (Following filter from KAN-593; a legacy post with NULL city counts as Dubai).
- `providers/tab_feed_notifier.dart`: `nearbyFeedProvider` uses the loader. Only Home > Nearby changed.
- Optional index (not authored here: a later migration breaks the KAN-611 test that pins its own file as the last migration): `posts (posted_from_city, created_at desc, id) where kind = 'original' and is_deleted = false and is_hidden_admin = false`. Memphis may add it in a later migration if the City read is slow.
- Tests: `test/features/social/nearby_ranking_test.dart` (the five-post table, City-only, missing coordinates, last-known over 24 h, paging, config not hardcoded).
The candidate set is the whole City (no row-count cap; the selected City is the boundary). It is read once per session in 1000-row range pages under the frozen `as_of`, then paged by the `(score, id)` cursor. With no selected City nothing is queried; the home header opens the manual 'Set location' drawer.
