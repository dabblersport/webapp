import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dabbler/features/location/domain/models/nearby_sort_order.dart';
import 'package:dabbler/features/misc/data/datasources/supabase_remote_data_source.dart';
import 'package:dabbler/features/games/data/datasources/nearby_games_datasource.dart';
import 'package:dabbler/features/games/data/models/nearby_game_model.dart';
import 'package:dabbler/features/games/data/repositories/nearby_games_repository.dart';

// =============================================================================
// PROVIDERS
// =============================================================================

final nearbyGamesDatasourceProvider = Provider<NearbyGamesDatasource>((ref) {
  return SupabaseNearbyGamesDatasource(ref.watch(supabaseServiceProvider));
});

final nearbyGamesRepositoryProvider = Provider<NearbyGamesRepository>((ref) {
  return NearbyGamesRepositoryImpl(
    ref.watch(nearbyGamesDatasourceProvider),
  );
});

/// Per-screen sort state for nearby games.
final nearbyGameSortProvider = StateProvider<NearbySortOrder>(
  (ref) => NearbySortOrder.nearest,
);

// =============================================================================
// PARAMS
// =============================================================================

/// Parameters that drive a nearby-games query.
///
/// Using a record so FutureProvider.family equality works correctly.
typedef NearbyGamesParams = ({
  double lat,
  double lng,
  int radiusMeters,
  String? sportId,
  NearbySortOrder sortOrder,
});

// =============================================================================
// MAIN PROVIDER
// =============================================================================

/// Fetches nearby games from the PostGIS RPC.
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
///   sortOrder: ref.watch(nearbyGameSortProvider),
/// );
/// final gamesAsync = ref.watch(nearbyGamesProvider(params));
/// ```
final nearbyGamesProvider = FutureProvider.autoDispose
    .family<List<NearbyGameModel>, NearbyGamesParams>((ref, params) async {
  final result = await ref.read(nearbyGamesRepositoryProvider).getNearbyGames(
        lat: params.lat,
        lng: params.lng,
        radiusMeters: params.radiusMeters,
        sportId: params.sportId,
        sortOrder: params.sortOrder,
      );

  return result.fold(
    (failure) => throw Exception(failure.message),
    (games) => games,
  );
});
