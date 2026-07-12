import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dabbler/features/location/domain/models/nearby_sort_order.dart';
import 'package:dabbler/features/misc/data/datasources/supabase_remote_data_source.dart';
import 'package:dabbler/features/venues/data/datasources/nearby_venues_datasource.dart';
import 'package:dabbler/features/venues/data/models/nearby_venue_model.dart';
import 'package:dabbler/features/venues/data/repositories/nearby_venues_repository.dart';

// =============================================================================
// PROVIDERS
// =============================================================================

final nearbyVenuesDatasourceProvider = Provider<NearbyVenuesDatasource>((ref) {
  return SupabaseNearbyVenuesDatasource(ref.watch(supabaseServiceProvider));
});

final nearbyVenuesRepositoryProvider = Provider<NearbyVenuesRepository>((ref) {
  return NearbyVenuesRepositoryImpl(
    ref.watch(nearbyVenuesDatasourceProvider),
  );
});

/// Per-screen sort state for nearby venues.
/// Screens read/write this to change the sort order without a full rebuild.
final nearbyVenueSortProvider = StateProvider<NearbySortOrder>(
  (ref) => NearbySortOrder.nearest,
);

/// Whether the "nearby" distance filter is active on the venues list.
final nearbyVenuesFilterEnabledProvider = StateProvider<bool>((ref) => false);

// =============================================================================
// PARAMS
// =============================================================================

/// Parameters that drive a nearby-venues query.
///
/// Using a record so FutureProvider.family equality works correctly.
typedef NearbyVenuesParams = ({
  double lat,
  double lng,
  int radiusMeters,
  String? sportId,
  NearbySortOrder sortOrder,
});

// =============================================================================
// MAIN PROVIDER
// =============================================================================

/// Fetches nearby venues from the PostGIS RPC.
///
/// Returns an empty list (not an error) when location is not yet ready so
/// callers can distinguish "loading" (AsyncLoading) from "no location yet"
/// (AsyncData([])).
///
/// Usage:
/// ```dart
/// final locState = ref.watch(activeLocationProvider).valueOrNull;
/// if (locState is! ActiveLocationReady) { /* show denied state */ }
/// final params = (
///   lat: locState.location.lat,
///   lng: locState.location.lng,
///   radiusMeters: locState.location.nearbyRadiusMeters,
///   sportId: selectedSportId,
///   sortOrder: ref.watch(nearbyVenueSortProvider),
/// );
/// final venuesAsync = ref.watch(nearbyVenuesProvider(params));
/// ```
final nearbyVenuesProvider = FutureProvider.autoDispose
    .family<List<NearbyVenueModel>, NearbyVenuesParams>((ref, params) async {
  final result = await ref.read(nearbyVenuesRepositoryProvider).getNearbyVenues(
        lat: params.lat,
        lng: params.lng,
        radiusMeters: params.radiusMeters,
        sportId: params.sportId,
        sortOrder: params.sortOrder,
      );

  return result.fold(
    (failure) => throw Exception(failure.message),
    (venues) => venues,
  );
});
