# KAN-629: Google Places UI Kit for venue card images (experiment)

Branch: `alpha-629-luxor`, cut from `origin/Alpha` at `1d4963f8`. Isolated PoC, not a production feature.
Status: Phase A done (everything that needs no Google account). Phases B to E are blocked on owner-required setup (section 7).

## 1. What is on this branch

| Item | Where |
|---|---|
| Default-off flag `FeatureFlags.placesUiKitExperiment` (`--dart-define=PLACES_UI_KIT_EXPERIMENT=true`) | `lib/core/config/feature_flags.dart` |
| Nine-venue allowlist, attempt guard (ceiling 2000), host seam, `experimentCover` | `lib/features/venues/experiment/places_ui_kit_experiment.dart` |
| Cover injection in the venue card (baseline `DabblerImage` is passed in and returned untouched when off) | `lib/features/explore/presentation/screens/venues_screen.dart` |
| Focused tests | `test/features/venues/experiment/places_ui_kit_experiment_test.dart` |

No native Places SDK is added to Android or iOS yet: adding it needs the restricted keys from section 7, and no key may be committed. With the flag off there is no SDK, no counter and no Google request by construction (the function returns the baseline first).

## 2. Pinned SDK versions (official docs, read 2026-10-23)

| Platform | Artifact | Version | Notes |
|---|---|---|---|
| Android | `com.google.android.libraries.places:places` | 6.0.2 (2026-09-30) | Place Details UI Kit GA since 4.3.1. 6.0.2 adds Compose `AdvancedPlaceDetailsCompact`; thumbnails show in views under 350 px wide. 6.0.2 removes several legacy `PlacesClient` methods. |
| iOS | `GooglePlaces` / `GooglePlacesSwift` via Swift Package Manager (`github.com/googlemaps/ios-places-sdk`) | Places SDK for iOS 11.2.0 (2026-09-30) | UI Kit GA since 10.0.0. 11.2.0: `PlaceDetailsCompactView` thumbnails in views under 350 px wide; default content now includes the name. |

Docs conflict, resolved in favour of the version-specific entry: the Android Versions page and release notes disagree on the 4.0.0 minSdk (API 23 vs 21); the iOS summary says minimum iOS 15 but the 10.0.0 entry says iOS 16; the iOS config page says Xcode 26+ while an older summary says 15.

## 3. Compatibility with this app

| Check | Result |
|---|---|
| Android effective minSdk | **24**. `android/app/build.gradle.kts` uses `flutter.minSdkVersion`, which is 24 in the installed Flutter 3.47.5 (`FlutterExtension.kt:26`). The source comment "pinned: minSdk 21" is stale. Places SDK minimum is API 24, so it is compatible. No OS-target increase needed. |
| Android compile/target | compileSdk 36, targetSdk 36, AGP 8.13.0, Kotlin 2.2.20, Gradle 8.14.3, JVM 11. |
| Android host | `MainActivity` extends `FlutterActivity`, not `FlutterFragmentActivity`. The Fragment based component (`PlaceDetailsCompactFragment`) needs a `FragmentManager`. Options: switch the activity base (a native change outside the experiment's current scope), or use the 6.0.2 Compose component inside the platform view. Needs a decision before Phase C native work. |
| iOS deployment target | 17.0 (Podfile), above the SDK minimum (iOS 16). |
| iOS install | The docs describe Swift Package Manager (and manual XCFrameworks); CocoaPods is not covered by the config page. This app is CocoaPods based. Adding an SPM dependency to the Runner target is possible but is a project-file change; the ticket forbids an unrelated CocoaPods/SPM migration, so it must be scoped to this one dependency. |
| Xcode | Installed 27.1 (docs require 26+). |
| Flutter hosting | Native Platform Views (`AndroidView` / `UiKitView`). Lifecycle, nested scrolling, gestures, semantics and clipping inside a `ListView` card are untested; they need a running component. |

## 4. Mandatory content and size (official docs)

- Google Maps logo (16 to 19 dp high, 10 dp clear space left/right/top, 5 dp bottom) or the text "Google Maps" when space is limited; attribution must stay visible, in the same container, never removed, hidden, obscured or mixed with other content; Google content must be visually separated (border, fill, shadow or whitespace).
- Photo attributions/author attributions and third-party attributions come with the component; they must stay legible.
- Terms of Use and Privacy Policy must be public and link Google's terms.
- Other SDK content may not be pre-fetched, indexed, stored or cached; Place IDs may be stored indefinitely.
- Compact component: recommended width 180 to 300 (vertical) and 180 to 500 (horizontal); widths under 160 may not render correctly; **height is not set on compact views, the content sizes it**. Thumbnails appear under 350 wide. No official minimum height is published. The component defaults to a dark theme; light and dark must both be styled.
- Billing: each `loadWith...` / `PlaceDetailsQuery` is billed, repeats included; do not call load from `onResume`.

**Fit hypothesis to test, not a verdict:** the venue cover is 170 logical px high at full card width. A vertical compact view (photo + name + attribution) is content sized and probably exceeds 170 px; a horizontal compact view or a thumbnail layout may fit but with a small photo. This needs measuring on a device with a key. If mandatory content does not fit 170 px without scaling, cropping or covering, the ticket's rule is to record the failure, not bypass it.

## 5. Nine-venue identity (Phase B inputs, read-only from `public.venues`, 2026-10-23)

Google Place IDs, branch/address matches and photo availability need Google calls and are not filled in. Supabase facts only:

| Venue | Supabase id | Address on record | lat, lng on record | Active/verified | Google match |
|---|---|---|---|---|---|
| All Star Sport | b53aea46-f61e-4d81-9de7-9ca515f0b9f9 | Umm Suqeim Road, Al Barsha | 25.1090448, 55.2192127 | yes / yes | pending |
| Champs Sports Club (Al Quoz) | 608c44d5-0d3e-4f9f-ace3-a9e7bf565dc4 | 9, 15th Street, Al Quoz Industrial Area 3, Hadaeq Mohammed Bin Rashid | 25.1308, 55.2328 | yes / yes | pending |
| Aktiv Nation | 85de82d7-9470-408c-ba3d-3559ea9248b6 | Building 72, 10th Street, Al Quoz Industrial Area 4 | 25.1164, 55.22691 | yes / yes | pending |
| Ahdaaf Sports Club | c68d6c80-54a4-4d17-ac93-395be1fa8ba4 | 18B Street, Al Quoz Industrial Area 2 | 25.12832, 55.24163 | yes / yes | pending |
| ISD Dubai Sports City | 387f6a70-760b-47d5-a991-495d07aa869f | ISD Padel Building, Sports Village, Al Hebiah 4, Dubai Sports City | 25.03867, 55.22442 | yes / yes | pending |
| United Pro Sports | c5aefd96-474d-4171-b7e6-64155a1d6fa3 | "Al Quoz, Dubai" (no street) | 25.15, 55.19 (rounded; needs verification, not corrected) | yes / **no** | pending |
| 365 Open Sports | 069a13d4-8994-462c-9226-0024d1d4006c | Falcon City of Wonders, Wadi Al Safa 2, Dubailand | 25.1015, 55.3374 | yes / yes | pending |
| Jebel Ali Recreation Club | e91d8b43-360f-4da6-ad0b-d89b5402db85 | Jebel Ali Village | 25.0349392, 55.1177546 | yes / **no** | pending |
| Danube Sports World | cbcb52c5-9ffd-42e3-bec3-a3447a18cf3f | 57H3+P29 Al Habtoor City, Al Meydan Rd | 25.1791, 55.253 | yes / yes | pending |

Observations: the ticket's four "existing research" coordinates match the database. United Pro Sports is labelled Al Quoz but its coordinates (25.15, 55.19) are about 4.8 km from the Al Quoz Industrial Area 3 Champs point, and both values are round numbers, so the point looks like an area centroid, not a verified location. No website on record for United Pro Sports or All Star Sport (empty string).

### Champs duplicate (no writes)

| | Champs Sports Club (`608c44d5`, rendering venue) | Champs UAE (`4b83429f`, research only) |
|---|---|---|
| Address | 9, 15th Street, Al Quoz Industrial Area 3, Hadaeq Mohammed Bin Rashid | 9 15th Street, Al Quoz Industrial Area 4 |
| Coordinates | 25.1308, 55.2328 | 25.1250, 55.2290 (rounded) |
| Website | champssc.ae | champs-sportsclub.com |
| Google rating on record | 4.6 | 4.5 |
| Area ids | 5454002b-8eb3-4dc3-806d-fb59314bbb14 | 7b903557-10ce-48ca-b078-c0dcc388bd31 |

Same building number and street, different Al Quoz Industrial Area labels, 750 m apart on the stored points. Two competing explanations: one branch recorded twice with a wrong area label, or two branches sharing a street name. Independent web evidence could not be collected from this environment (champssc.ae does not resolve, champs-sportsclub.com returned 403). The question is for the Google match step (name, address and location bias around both points); it stays **ambiguous**, nothing is merged or edited, and `Champs UAE` is never rendered.

## 6. Test plan (Phase D), unchanged from the ticket

Per platform: all nine venues in the real card, light/dark, text scale, attribution legibility, gestures, scroll off/on, rebuild, refresh, navigate away/back, background/resume, rotation, disposal; latency p50/p95, success numerator/denominator, jank, memory vs baseline. Load tiers 10/20/50/100 as repeated instances of the nine venues (cold, then revisit), ascending, stopping if the budget is threatened. Counters: native component creates and loads. Budget: USD 0, ceiling 2000 attempts including matching. Billing reconciliation after up to 48 h; delayed billing is "pending", never zero.

Pricing snapshot to re-verify at execution (ticket): Essentials UI Kit query 10,000 free events/month then USD 1/1,000; Pro 5,000 free then USD 5/1,000; Photos 1,000 free then USD 7/1,000 (not authorized).

## 7. Owner action required before any live work (single question)

Nothing below can be done by the engineering seat, and no secret or card detail may be sent in chat:

1. Create or nominate an isolated experiment Google Cloud project with a billing account (confirm EEA or non-EEA billing jurisdiction and accept the Places UI Kit terms).
2. Enable only the Places UI Kit API (`placewidgets.googleapis.com`) plus the one matching API chosen for Phase B.
3. Create two restricted keys: Android (package `com.dabbler.dabblerapp` plus the debug SHA-1) and iOS (the app bundle id), each limited to those APIs; and, if server matching is wanted, a separately restricted server key.
4. Put the keys in the approved local/CI secret store (never in source, logs, Jira or chat) and set a per-API daily quota well under the free allowance, plus a budget alert.
5. Say who has the physical Android and iOS devices (otherwise results are simulator-only).

## 8. Rollback

Flag off (default) restores the current cover with no SDK initialisation and no Google request. Retire the PoC by deleting the `experiment` folder, the one `experimentCover` call in `venues_screen.dart`, the flag, this document, and any native integration added later; revoke only the experiment project's keys.
