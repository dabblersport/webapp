import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dabbler/features/location/domain/models/nearby_sort_order.dart';
import 'package:dabbler/core/data/supabase_remote_data_source.dart';
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

/// Whether the "nearby" distance filter is active on the games list.
final nearbyGamesFilterEnabledProvider = StateProvider<bool>((ref) => false);

// =============================================================================
// LIST FILTERS (client-side, applied to the fetched list)
// =============================================================================

enum GamesDateFilter { any, today, tomorrow, thisWeek }

extension GamesDateFilterLabel on GamesDateFilter {
  String get label => switch (this) {
        GamesDateFilter.any => 'Any date',
        GamesDateFilter.today => 'Today',
        GamesDateFilter.tomorrow => 'Tomorrow',
        GamesDateFilter.thisWeek => 'This week',
      };

  bool matches(DateTime? scheduledAt, DateTime now) {
    if (this == GamesDateFilter.any) return true;
    if (scheduledAt == null) return false;
    final today = DateTime(now.year, now.month, now.day);
    final gameDay =
        DateTime(scheduledAt.year, scheduledAt.month, scheduledAt.day);
    final diff = gameDay.difference(today).inDays;
    return switch (this) {
      GamesDateFilter.any => true,
      GamesDateFilter.today => diff == 0,
      GamesDateFilter.tomorrow => diff == 1,
      GamesDateFilter.thisWeek => diff >= 0 && diff < 7,
    };
  }
}

/// Date window filter for the games list.
final gamesDateFilterProvider =
    StateProvider<GamesDateFilter>((ref) => GamesDateFilter.any);

/// Only show games with open spots.
final gamesOpenSpotsOnlyProvider = StateProvider<bool>((ref) => false);

/// Skill-level filter — same tiers/ranges as the game composer's skill
/// picker (min_skill/max_skill 1-10 on the game).
enum GamesSkillFilter { any, beginner, intermediate, advanced, pro }

extension GamesSkillFilterX on GamesSkillFilter {
  String get label => switch (this) {
        GamesSkillFilter.any => 'Any skill',
        GamesSkillFilter.beginner => 'Beginner',
        GamesSkillFilter.intermediate => 'Intermediate',
        GamesSkillFilter.advanced => 'Advanced',
        GamesSkillFilter.pro => 'Pro',
      };

  (int, int)? get range => switch (this) {
        GamesSkillFilter.any => null,
        GamesSkillFilter.beginner => (1, 3),
        GamesSkillFilter.intermediate => (4, 6),
        GamesSkillFilter.advanced => (7, 8),
        GamesSkillFilter.pro => (9, 10),
      };

  /// A game matches when its skill window overlaps this tier. Games without
  /// a skill range are open to everyone and always match.
  bool matches(int? gameMin, int? gameMax) {
    final r = range;
    if (r == null) return true;
    if (gameMin == null && gameMax == null) return true;
    final gMin = gameMin ?? 1;
    final gMax = gameMax ?? 10;
    return gMin <= r.$2 && gMax >= r.$1;
  }
}

/// Selected skill tier for the games list.
final gamesSkillFilterProvider =
    StateProvider<GamesSkillFilter>((ref) => GamesSkillFilter.any);

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

  final lat = params.lat;
  final lng = params.lng;
  final result = (lat != null && lng != null)
      ? await repo.getNearbyGames(
          lat: lat,
          lng: lng,
          radiusMeters: params.radiusMeters ?? 10000,
          sportId: params.sportId,
          sortOrder: params.sortOrder,
        )
      : await repo.getAllGames(sportId: params.sportId);
  return result.fold((f) => throw Exception(f.message), (g) => g);
});

/// The viewer's own upcoming games (created or joined), pinned at the top of
/// the games list. Location-independent — a quick game without a venue never
/// shows in the nearby results but still belongs here. Param = sportId.
final myPinnedGamesProvider = FutureProvider.autoDispose
    .family<List<NearbyGameModel>, String?>((ref, sportId) async {
  final svc = ref.read(supabaseServiceProvider);
  if (svc.client.auth.currentUser == null) return const [];

  final repo = ref.read(nearbyGamesRepositoryProvider);
  final result = await repo.getMyUpcomingGames(sportId: sportId);
  return result.fold((f) => throw Exception(f.message), (g) => g);
});
