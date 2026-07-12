# Location — Current Capabilities

What the Dabbler platform can do with location today, across the Flutter app and the Supabase backend. Verified against the live database (project `wtncuzcskpigqpmnxwws`, PostGIS 3.3.7) on 2026-07-11.

---

## 1. What users can do

| Capability | Where |
|---|---|
| Filter **venues** by nearby distance (radius 1–50 km, nearest-first or default sort) | Sports → Venues tab (`/sports/venues`) via the "Nearby" chip |
| Filter **games** by nearby distance (same radius/sort controls) | Games tab via the "Nearby" chip |
| See distance on venue and game cards ("850 m", "1.2 km") | Both tabs when the nearby filter is on |
| Save named locations (home/work/custom) with a per-location default radius, and mark one as primary | Saved locations screen (opened from the home location picker) |
| Pick a location manually — search places via Mapbox, drop a pin on an embedded map | `save_location_sheet.dart` (flutter_map + OSM tiles) |
| Switch the app's active location between live GPS, a saved location, or a manually picked area | Home location bar / picker sheet |
| Tag posts with a location (venue, free-text place, or coordinates) | Post composer; feeds can rank nearby posts |
| Submit new venues with address + coordinates (organisers) | Venue submission flow |
| Control location privacy: hide location from others, opt out of location tracking | Privacy settings (`show_location`, `allow_location_tracking`) |
| Country auto-detection on first run (IP-based, no permission needed) | `detect-country` edge function |

## 2. How the app resolves "where am I" (active location)

`activeLocationProvider` (`lib/features/location/providers/active_location_provider.dart`) is the single source of truth. Degradation order:

1. **Saved primary location** — instant, no GPS wait.
2. **Silent background GPS** — upgrades the state if accuracy ≤ 100 m.
3. **Denied state** — GPS refused and nothing saved; UI shows a retry affordance.

Every resolved location is snapped to the nearest **area** (city district) via the `resolve_nearest_area` RPC. The active radius (default 10 km) comes from the primary saved location and can be overridden per-screen; the radius slider persists changes back to `profile_locations`.

GPS itself is handled by `GpsService` (`lib/core/services/gps_service.dart`): high-accuracy attempt with a 10 s timeout, then a medium-accuracy 6 s retry, returning a sealed `LocationResult` (success / denied / denied-forever / service-off / timeout / error). The older `LocationService` singleton still exists (SharedPreferences caching, 15-min refresh) but new code should use `GpsService` + `activeLocationProvider`.

**Stack:** `geolocator` (GPS), `geocoding` (reverse geocode), **Mapbox** geocoding v6 (place search, proximity-biased), `flutter_map` + OpenStreetMap tiles (map rendering — no Google Maps). Mapbox token comes from `--dart-define` (note: two env names are in use, `MAPBOX_TOKEN` and `MAPBOX_ACCESS_TOKEN`).

**Permissions:** iOS `NSLocationWhenInUseUsageDescription` + `NSLocationAlwaysAndWhenInUseUsageDescription`; Android `ACCESS_FINE_LOCATION` + `ACCESS_COARSE_LOCATION`.

## 3. Backend model (Supabase)

### Canonical tables

- **`geo_locations`** — the single geo store: `location geography(Point,4326)`, `geohash`, required `area_id`. A GiST index (`idx_geo_location_gist`) powers all radius searches.
- **`areas`** — curated district catalog: name/district/city/country, `center_lat/lng`, optional polygon `boundary`, `is_verified`. New areas can be created from Mapbox results via `upsert_area_from_mapbox` (dedupes within 500 m).
- **`profile_locations`** — per-user saved locations: lat/lng, label (`home` default), `nearby_radius_meters` (default 10 000), `is_primary`. RLS: strictly own-row CRUD.
- **`profiles`** — last known coordinates (`latitude`/`longitude`, `last_location_updated_at`) + city/country.
- **`location_tags`** — reusable post location labels with use counts.

### Location is inherited automatically (triggers, not app code)

| Entity | How it gets its location |
|---|---|
| `venues` | Raw lat/lng on insert → trigger creates a `geo_locations` row |
| `games` | Inherited from `venue_space_id` → venue (or `venue_id` directly) |
| `meetups` | Inherited from `venue_id`; supports free-text `location_name` |
| `posts` | 5-path resolver: venue → game → manual lat/lng → author's last profile location → busiest area's center |

This means games/meetups/posts are directly geo-searchable without joining venues at query time.

### Nearby search RPCs (what the app calls)

| RPC | Used by | Notes |
|---|---|---|
| `rpc_get_nearby_games(p_lat, p_lng, p_radius_meters, p_sport_id, p_sort)` | Games tab nearby filter | Upcoming, non-cancelled games; returns distance, player count, spots remaining, computed status |
| `rpc_get_nearby_venues(p_lat, p_lng, p_radius_meters, p_sport_id, p_sort)` | Venues tab nearby filter | Active venues; sports/indoor/price derived from `venue_spaces` |
| `get_nearby_games` / `get_nearby_venues` / `get_nearby_posts` / `get_nearby_profiles` | `NearbyRepositoryImpl` (explore) | Simple `(p_lat, p_lng, p_radius)` family; profiles variant respects `privacy_settings.show_location` and excludes the caller |
| `geo_nearby_venues(in_lat, in_lng, in_radius_m, in_limit, in_offset)` | `GeoRepositoryImpl` | Paginated, returns Venue-model-shaped rows |
| `resolve_nearest_area(p_lat, p_lng)` | Active location snapping | Nearest active area + distance |
| `search_areas(p_query, p_limit)` | Area picker | Text search over areas |
| `search_venues_with_filters(...)` | Advanced venue search | Radius + price/indoor/surface/rating/amenities/city filters |
| `rpc_nearby_users(p_lat, p_lng, p_delta, p_limit)` | People discovery | Bounding-box (not PostGIS) over profile coordinates |

All PostGIS-based RPCs use `ST_DWithin` on `geography` (meters, spheroid-accurate) ordered by `ST_Distance`.

### RLS posture

- `geo_locations`, `areas`: world-readable (areas are read-only reference data).
- `profile_locations`: own-row only.
- `venues`: public when active; inactive visible to venue members; edits gated by `can_edit_venue_details`.
- Nearby-profile exposure honors `privacy_settings.show_location`.

### Edge function

- **`detect-country`** — IP geolocation (Cloudflare `CF-IPCountry` header, `ipapi.co` fallback); returns `{country, city, countryCode}`. Gulf-region focused.

## 4. Known limitations / debt

- **`generate_geohash()` is not a real geohash** — it's a SHA-256 of the coordinates. Fine as a dedup key; useless for prefix-based proximity. All proximity relies on the GiST index.
- **Legacy RPC duplicates** remain deployed (`getnearby*` camel-case family, older `get_nearby_*` overloads) — prefer the `rpc_get_nearby_*` family for new work.
- **Local repo SQL is stale** — the live schema is the source of truth; `supabase/schema/migrations/` holds only two outdated location files.
- **Duplicate providers** — `nearbyVenuesProvider`/`nearbyGamesProvider` are each defined in three places; the routed screens use `features/venues/...` and `features/games/...` versions.
- `explore/data/nearby_location_service.dart` still returns mock coordinates (superseded by `activeLocationProvider`).
- Venue coordinate naming is inconsistent across Dart models (`lat/lng` vs `latitude/longitude`).
- The sport tab-bar venue count ignores the nearby filter (counts all venues for the sport).
- `rpc_nearby_users` uses a flat bounding box, so distances aren't returned and results aren't distance-sorted.
