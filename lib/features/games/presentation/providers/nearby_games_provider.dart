import 'package:dabbler/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dabbler/features/location/domain/models/nearby_sort_order.dart';
import 'package:dabbler/features/location/providers/active_location_provider.dart';
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
  return NearbyGamesRepositoryImpl(ref.watch(nearbyGamesDatasourceProvider));
});

/// The games list's default radius (`Listings.2026-10-08.dc.html:1989`: the
/// design opens on "Within 5 km").
const int kGamesDefaultRadiusMeters = 5000;

/// A value that starts as [ifReady] when the viewer's location is ready, and
/// otherwise as [otherwise] — switching to [ifReady] once, the first time the
/// location becomes ready, as long as nothing has been applied by hand before.
///
/// This never asks for a location: it only listens to [activeLocationProvider],
/// which the games screen already watches for its header. No location, no
/// default — the filters stay off.
T _defaultOnLocation<T>(StateProviderRef<T> ref, T ifReady, T otherwise) {
  final bool readyNow =
      ref.read(activeLocationProvider).valueOrNull is ActiveLocationReady;
  var settled = readyNow;
  final T initial = readyNow ? ifReady : otherwise;
  ref.listen<AsyncValue<ActiveLocationState>>(activeLocationProvider, (_, next) {
    if (settled || next.valueOrNull is! ActiveLocationReady) return;
    settled = true;
    // Only when the viewer has not changed it meanwhile.
    if (ref.controller.state == initial) ref.controller.state = ifReady;
  });
  return initial;
}

/// The games list's sort, or null when none is applied (the list then runs in
/// start-time order). Defaults to "Nearest" once a location is ready
/// (`Listings.2026-10-08.dc.html:1989`). Without a location "Nearest" stays a
/// chip only: the unlocated query is always ordered by start time.
final nearbyGameSortProvider = StateProvider<NearbySortOrder?>(
  (ref) => _defaultOnLocation<NearbySortOrder?>(
    ref,
    NearbySortOrder.nearest,
    null,
  ),
);

/// Whether the "nearby" distance filter is active on the games list. On by
/// default only when the viewer's location is ready.
final nearbyGamesFilterEnabledProvider = StateProvider<bool>(
  (ref) => _defaultOnLocation<bool>(ref, true, false),
);

/// The games list's own radius, in metres — "Within 5 km" until the viewer
/// picks another preset. Kept apart from the location's saved radius so the
/// games default does not move other listings.
final gamesRadiusProvider = StateProvider<int>(
  (ref) => kGamesDefaultRadiusMeters,
);

// =============================================================================
// LIST FILTERS (client-side, applied to the fetched list)
// =============================================================================

enum GamesDateFilter { any, today, tomorrow, thisWeek, thisWeekend }

extension GamesDateFilterLabel on GamesDateFilter {
  String get label => switch (this) {
    GamesDateFilter.any => 'Any date',
    GamesDateFilter.today => 'Today',
    GamesDateFilter.tomorrow => 'Tomorrow',
    GamesDateFilter.thisWeek => 'This week',
    GamesDateFilter.thisWeekend => 'This weekend',
  };

  /// Whether a game at [scheduledAt] falls in this window, seen from [now].
  ///
  /// "This weekend" is the UAE weekend, Saturday and Sunday (since 2022): the
  /// coming Saturday and Sunday, or what is left of them when [now] is already
  /// on one. A Friday is not weekend. Days are local calendar days.
  bool matches(DateTime? scheduledAt, DateTime now) {
    if (this == GamesDateFilter.any) return true;
    if (scheduledAt == null) return false;
    final today = DateTime(now.year, now.month, now.day);
    final gameDay = DateTime(
      scheduledAt.year,
      scheduledAt.month,
      scheduledAt.day,
    );
    final diff = gameDay.difference(today).inDays;
    return switch (this) {
      GamesDateFilter.any => true,
      GamesDateFilter.today => diff == 0,
      GamesDateFilter.tomorrow => diff == 1,
      GamesDateFilter.thisWeek => diff >= 0 && diff < 7,
      GamesDateFilter.thisWeekend =>
        diff >= 0 &&
            diff <= (DateTime.sunday - now.weekday) % 7 &&
            (gameDay.weekday == DateTime.saturday ||
                gameDay.weekday == DateTime.sunday),
    };
  }
}

/// Date window filter for the games list.
final gamesDateFilterProvider = StateProvider<GamesDateFilter>(
  (ref) => GamesDateFilter.any,
);

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

/// The tier name for a skill window, by its lower bound — the same bands the
/// skill filter uses — or null when the game sets no skill range.
GamesSkillFilter? gamesSkillTierFor(int? min, int? max) {
  final level = min ?? max;
  if (level == null) return null;
  for (final tier in GamesSkillFilter.values) {
    final r = tier.range;
    if (r != null && level >= r.$1 && level <= r.$2) return tier;
  }
  return null;
}

/// The tier's localised name.
String gamesSkillTierLabel(AppLocalizations l, GamesSkillFilter f) =>
    switch (f) {
      GamesSkillFilter.any => l.listing_skill_any,
      GamesSkillFilter.beginner => l.listing_skill_beginner,
      GamesSkillFilter.intermediate => l.listing_skill_intermediate,
      GamesSkillFilter.advanced => l.listing_skill_advanced,
      GamesSkillFilter.pro => l.listing_skill_pro,
    };

/// Selected skill tier for the games list.
final gamesSkillFilterProvider = StateProvider<GamesSkillFilter>(
  (ref) => GamesSkillFilter.any,
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
