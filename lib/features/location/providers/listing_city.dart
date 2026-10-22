import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dabbler/data/models/area.dart';
import 'package:dabbler/features/location/providers/active_location_provider.dart';
import 'package:dabbler/features/location/providers/location_providers.dart'
    show areaRepositoryProvider;

/// KAN-588: the city that scopes the Venues, Games and Meetups lists and the
/// Nearby feed. It is the device's current city (KAN-586): the city of the
/// chosen Area, or the City chosen on its own. It is never the account's
/// service region and never the public Profile city.
class ListingCity {
  const ListingCity(this.name, {this.country, this.countryCode});

  final String name;
  final String? country;
  final String? countryCode;

  @override
  bool operator ==(Object other) =>
      other is ListingCity &&
      other.name == name &&
      other.country == country &&
      other.countryCode == countryCode;

  @override
  int get hashCode => Object.hash(name, country, countryCode);
}

String? _clean(String? v) {
  final t = v?.trim();
  return t == null || t.isEmpty ? null : t;
}

/// The listing city of [state], or null when there is none (denied, errored,
/// still loading).
ListingCity? listingCityOf(ActiveLocationState? state) {
  if (state is ActiveLocationReady) {
    final name = _clean(state.location.area.city);
    return name == null
        ? null
        : ListingCity(name, country: _clean(state.location.area.country));
  }
  if (state is ActiveLocationCityOnly) {
    final name = _clean(state.city);
    return name == null
        ? null
        : ListingCity(
            name,
            country: _clean(state.country),
            countryCode: _clean(state.countryCode),
          );
  }
  return null;
}

/// True while the location has not settled yet: a list must wait (show its
/// skeleton), not fetch everything and swap it for the city's rows.
bool listingCityPending(AsyncValue<ActiveLocationState> async) {
  if (async.isLoading && !async.hasValue) return true;
  return async.valueOrNull is ActiveLocationLoading;
}

/// True when the lists should say "Choose city": the location settled with no
/// city. A location that is still loading is not this; the list waits.
bool listingCityMissing(AsyncValue<ActiveLocationState> async) {
  if (listingCityPending(async)) return false;
  return listingCityOf(async.valueOrNull) == null;
}

/// True when only the city is known (no Area, no point): the lists are
/// alphabetical and the distance controls are off.
bool listingCityOnly(ActiveLocationState? state) =>
    state is ActiveLocationCityOnly;

final listingCityProvider = Provider<ListingCity?>(
  (ref) => listingCityOf(ref.watch(activeLocationProvider).valueOrNull),
);

/// Whether the location is still settling.
final listingCityPendingProvider = Provider<bool>(
  (ref) => listingCityPending(ref.watch(activeLocationProvider)),
);

/// Whether the lists should say "Choose city" right now.
final listingCityMissingProvider = Provider<bool>(
  (ref) => listingCityMissing(ref.watch(activeLocationProvider)),
);

/// Whether the city is known without an Area.
final listingCityOnlyProvider = Provider<bool>(
  (ref) => listingCityOnly(ref.watch(activeLocationProvider).valueOrNull),
);

/// The [areas] that belong to [city]. A same-named city of another country
/// (Paris, France / Paris, Texas) does not match when the country is known.
List<Area> areasOfCity(List<Area> areas, ListingCity city) {
  final String c = city.name.toLowerCase();
  bool same(String? a, String? b) =>
      a != null && b != null && a.toLowerCase() == b.toLowerCase();
  final bool anyCountry = city.country == null && city.countryCode == null;
  return <Area>[
    for (final Area a in areas)
      if (a.city.toLowerCase() == c &&
          (anyCountry ||
              same(a.country, city.countryCode) ||
              same(a.country, city.country)))
        a,
  ];
}

/// Ids of the Areas of [city], which is how a game or meetup (they carry an
/// `area_id`) is matched to it. Empty when the city has no Area rows; it
/// errors when the Areas could not be loaded.
final listingCityAreaIdsProvider = FutureProvider.autoDispose
    .family<List<String>, ListingCity>((ref, city) async {
      final repo = ref.watch(areaRepositoryProvider);
      final result = await repo.getActiveAreas();
      // A failed load is an error, never an empty city.
      final List<Area> all = result.fold(
        (err) => throw Exception(err.message),
        (a) => a,
      );
      final ids = <String>[for (final a in areasOfCity(all, city)) a.id]
        ..sort();
      return ids;
    });
