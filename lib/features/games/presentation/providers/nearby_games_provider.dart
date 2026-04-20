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

/// Parameters that drive a games query.
/// lat/lng/radiusMeters are null when no location filter is active.
typedef NearbyGamesParams = ({
  double? lat,
  double? lng,
  int? radiusMeters,
  String? sportId,
  NearbySortOrder sortOrder,
});

// =============================================================================
// MAIN PROVIDER
// =============================================================================

/// Fetches games. When lat/lng are null, returns all public upcoming games.
/// When lat/lng are provided, uses the PostGIS RPC for proximity filtering.
final nearbyGamesProvider = FutureProvider.autoDispose
    .family<List<NearbyGameModel>, NearbyGamesParams>((ref, params) async {
  final repo = ref.read(nearbyGamesRepositoryProvider);

  final result = await repo.getAllGames(sportId: params.sportId);
  return result.fold((f) => throw Exception(f.message), (g) => g);
});
