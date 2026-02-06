import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../presentation/controllers/games_controller.dart';
import '../presentation/controllers/game_detail_controller.dart';
import '../presentation/controllers/venues_controller.dart';
import '../presentation/controllers/my_games_controller.dart';
import '../presentation/controllers/bookings_controller.dart';
import 'package:dabbler/core/providers/geo_providers.dart';
import '../domain/usecases/find_games_usecase.dart';
import '../domain/usecases/join_game_usecase.dart';
import 'package:dabbler/data/models/games/game.dart';
import 'package:dabbler/data/models/games/venue.dart';
import '../domain/repositories/bookings_repository.dart';
import '../data/repositories/games_repository_impl.dart';
import '../data/repositories/venues_repository_impl.dart';
import '../data/repositories/bookings_repository_impl.dart';
import '../data/datasources/supabase_games_datasource.dart';
import '../data/datasources/venues_datasource.dart';
import '../data/datasources/bookings_datasource.dart';
import '../data/datasources/bookings_remote_data_source.dart';
import 'package:dabbler/data/repositories/joinability_repository_impl.dart';
import '../services/game_completion_rewards_handler.dart';
import 'package:dabbler/services/sport_profile_service.dart';

// =============================================================================
// DATA SOURCE PROVIDERS
// =============================================================================

/// Provides the Supabase client instance
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

final gamesSportProfileServiceProvider = Provider<SportProfileService>((ref) {
  return SportProfileService(supabase: ref.watch(supabaseClientProvider));
});

final gameCompletionRewardsHandlerProvider =
    Provider<GameCompletionRewardsHandler>((ref) {
      return GameCompletionRewardsHandler(
        sportProfileService: ref.watch(gamesSportProfileServiceProvider),
      );
    });

/// Provides the games remote data source
final gamesDataSourceProvider = Provider<SupabaseGamesDataSource>((ref) {
  return SupabaseGamesDataSource(ref.watch(supabaseClientProvider));
});

/// Provides the venues remote data source
final venuesDataSourceProvider = Provider<SupabaseVenuesDataSource>((ref) {
  return SupabaseVenuesDataSource(ref.watch(supabaseClientProvider));
});

/// Provides the bookings remote data source
final bookingsDataSourceProvider = Provider<BookingsDataSource>((ref) {
  return SupabaseBookingsDataSource(ref.watch(supabaseClientProvider));
});

// =============================================================================
// REPOSITORY PROVIDERS
// =============================================================================

/// Provides the games repository with Supabase implementation
final gamesRepositoryProvider = Provider((ref) {
  return ref.watch(featuresGamesRepositoryProvider);
});

/// Features layer games repository (the correct one to use)
final featuresGamesRepositoryProvider = Provider((ref) {
  return GamesRepositoryImpl(
    remoteDataSource: ref.watch(gamesDataSourceProvider),
  );
});

/// Provides the venues repository
final venuesRepositoryProvider = Provider((ref) {
  return VenuesRepositoryImpl(
    remoteDataSource: ref.watch(venuesDataSourceProvider),
  );
});

/// Provides the bookings repository
final bookingsRepositoryProvider = Provider<BookingsRepository>((ref) {
  return BookingsRepositoryImpl(
    remoteDataSource:
        ref.watch(bookingsDataSourceProvider) as BookingsRemoteDataSource,
  );
});

// =============================================================================
// USE CASE PROVIDERS
// =============================================================================

final findGamesUseCaseProvider = Provider<FindGamesUseCase>((ref) {
  return FindGamesUseCase(gamesRepository: ref.watch(gamesRepositoryProvider));
});

// final createGameUseCaseProvider = Provider<CreateGameUseCase>((ref) {
//   final bookingsRepo = ref.watch(bookingsRepositoryProvider);
//   // Throw error if bookings repo is accessed before implementation
//   if (bookingsRepo == null) {
//     throw UnimplementedError('BookingsRepository not yet implemented');
//   }
//   return CreateGameUseCase(
//     gamesRepository: ref.watch(gamesRepositoryProvider),
//     venuesRepository: ref.watch(venuesRepositoryProvider),
//     bookingsRepository: bookingsRepo,
//   );
// });

final joinGameUseCaseProvider = Provider<JoinGameUseCase>((ref) {
  return JoinGameUseCase(gamesRepository: ref.watch(gamesRepositoryProvider));
});

// final cancelGameUseCaseProvider = Provider<CancelGameUseCase>((ref) {
//   final bookingsRepo = ref.watch(bookingsRepositoryProvider);
//   // Throw error if bookings repo is accessed before implementation
//   if (bookingsRepo == null) {
//     throw UnimplementedError('BookingsRepository not yet implemented');
//   }
//   return CancelGameUseCase(
//     gamesRepository: ref.watch(gamesRepositoryProvider),
//     bookingsRepository: bookingsRepo,
//   );
// });

// =============================================================================
// CONTROLLER PROVIDERS
// =============================================================================

/// Main games controller for discovering and browsing games
final gamesControllerProvider =
    StateNotifierProvider<GamesController, GamesState>((ref) {
      return GamesController(
        findGamesUseCase: ref.watch(findGamesUseCaseProvider),
      );
    });

// Create game controller for multi-step game creation
// final createGameControllerProvider = StateNotifierProvider<CreateGameController, CreateGameState>((ref) {
//   return CreateGameController(
//     createGameUseCase: ref.watch(createGameUseCaseProvider),
//   );
// });

/// Venues controller for venue discovery and management
final venuesControllerProvider =
    StateNotifierProvider<VenuesController, VenuesState>((ref) {
      final venuesRepository = ref.watch(venuesRepositoryProvider);
      final geoRepository = ref.watch(geoRepositoryProvider);
      return VenuesController(venuesRepository, geoRepository: geoRepository);
    });

/// My games controller for user's personal game management
final myGamesControllerProvider =
    StateNotifierProvider.family<MyGamesController, MyGamesState, String>((
      ref,
      userId,
    ) {
      return MyGamesController(
        cancelGameUseCase: null,
        gamesRepository: ref.watch(gamesRepositoryProvider),
        userId: userId,
        completionHandler: ref.watch(gameCompletionRewardsHandlerProvider),
      );
    });

/// Bookings controller for user's venue bookings
final bookingsControllerProvider =
    StateNotifierProvider.family<BookingsController, BookingsState, String>((
      ref,
      userId,
    ) {
      return BookingsController(ref.watch(bookingsRepositoryProvider));
    });

/// Game detail controller for individual game management (family provider for different games)
final gameDetailControllerProvider =
    StateNotifierProvider.family<
      GameDetailController,
      GameDetailState,
      GameDetailParams
    >((ref, params) {
      return GameDetailController(
        joinGameUseCase: ref.watch(joinGameUseCaseProvider),
        gamesRepository: ref.watch(gamesRepositoryProvider),
        venuesRepository: ref.watch(venuesRepositoryProvider),
        joinabilityRepository: ref.watch(joinabilityRepositoryProvider),
        gameId: params.gameId,
        currentUserId: params.currentUserId,
      );
    });

/// Convenience state-only provider to simplify overriding in tests/widgets
final gameDetailStateProvider =
    Provider.family<GameDetailState, GameDetailParams>((ref, params) {
      return ref.watch(gameDetailControllerProvider(params));
    });

// =============================================================================
// CONVENIENCE PROVIDERS
// =============================================================================

/// Current user's games
final myGamesProvider = Provider.family<MyGamesController, String>((
  ref,
  userId,
) {
  return ref.watch(myGamesControllerProvider(userId).notifier);
});

/// Nearby games based on current location
final nearbyGamesProvider = Provider((ref) {
  final gamesState = ref.watch(gamesControllerProvider);
  return gamesState.nearbyGames;
});

/// Upcoming games from all sources
final upcomingGamesProvider = Provider((ref) {
  final gamesState = ref.watch(gamesControllerProvider);
  return gamesState.upcomingGames;
});

/// Today's games for current user
final todayGamesProvider = Provider.family<List<Game>, String>((ref, userId) {
  final myGamesState = ref.watch(myGamesControllerProvider(userId));
  return myGamesState.todayGames;
});

/// This week's games for current user
final thisWeekGamesProvider = Provider.family<List<Game>, String>((
  ref,
  userId,
) {
  final myGamesState = ref.watch(myGamesControllerProvider(userId));
  return myGamesState.thisWeekGames;
});

// =============================================================================
// ASYNC PROVIDERS FOR REAL-TIME DATA
// =============================================================================

/// Current user's ID from Supabase auth
final currentUserIdProvider = Provider<String?>((ref) {
  return ref.watch(supabaseClientProvider).auth.currentUser?.id;
});

/// Fetches user's upcoming games from Supabase
final userUpcomingGamesProvider = FutureProvider.autoDispose<List<Game>>((
  ref,
) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return [];

  final repository = ref.watch(gamesRepositoryProvider);
  final result = await repository.getMyGames(
    userId,
    status: 'upcoming',
    limit: 50,
  );

  return result.fold(
    (failure) {
      // Log error but return empty list to avoid breaking UI
      return [];
    },
    (games) {
      final now = DateTime.now();
      final upcomingGames = games.where((game) {
        try {
          return game.getScheduledStartDateTime().isAfter(now);
        } catch (_) {
          // If we can't parse the date, default to keeping the game so it can be
          // inspected in logs and fixed at the data source level.
          return true;
        }
      }).toList();

      // Sort by date (earliest first)
      upcomingGames.sort((a, b) => a.scheduledDate.compareTo(b.scheduledDate));
      return upcomingGames;
    },
  );
});

/// Fetches user's next upcoming game
final nextUpcomingGameProvider = Provider.autoDispose<AsyncValue<Game?>>((ref) {
  final gamesAsync = ref.watch(userUpcomingGamesProvider);

  return gamesAsync.when(
    data: (games) {
      if (games.isEmpty) return const AsyncValue.data(null);
      // Return the first game (earliest scheduled)
      return AsyncValue.data(games.first);
    },
    loading: () => const AsyncValue.loading(),
    error: (error, stack) => AsyncValue.error(error, stack),
  );
});

/// Fetches all public games from Supabase (for Explore screen)
final publicGamesProvider = FutureProvider.autoDispose<List<Game>>((ref) async {
  final repository = ref.watch(gamesRepositoryProvider);
  final result = await repository.getGames(
    filters: {'is_public': true, 'status': 'upcoming'},
    limit: 100,
  );

  return result.fold(
    (failure) {
      throw Exception(failure.message);
    },
    (games) {
      // Sort by date (earliest first)
      games.sort((a, b) => a.scheduledDate.compareTo(b.scheduledDate));
      return games;
    },
  );
});

/// Active check-in reminders
final activeRemindersProvider = Provider.family<List<CheckInReminder>, String>((
  ref,
  userId,
) {
  final myGamesState = ref.watch(myGamesControllerProvider(userId));
  return myGamesState.checkInReminders
      .where((r) => r.isActive && r.shouldShowReminder)
      .toList();
});

/// User's game statistics
final gameStatisticsProvider = Provider.family<GameStatistics?, String>((
  ref,
  userId,
) {
  final myGamesState = ref.watch(myGamesControllerProvider(userId));
  return myGamesState.statistics;
});

/// Available venues near user
final nearbyVenuesProvider = Provider((ref) {
  final venuesState = ref.watch(venuesControllerProvider);
  return venuesState.nearbyVenues;
});

/// User's favorite venues
final favoriteVenuesProvider = Provider((ref) {
  final venuesState = ref.watch(venuesControllerProvider);
  return venuesState.favoriteVenues;
});

/// Available venues (only those that are currently available)
final availableVenuesProvider = Provider((ref) {
  final venuesState = ref.watch(venuesControllerProvider);
  return venuesState.availableVenues;
});

/// Games loading state (true if any games are loading)
final gamesLoadingProvider = Provider((ref) {
  final gamesState = ref.watch(gamesControllerProvider);
  return gamesState.isLoading;
});

/// Venues loading state
final venuesLoadingProvider = Provider((ref) {
  final venuesState = ref.watch(venuesControllerProvider);
  return venuesState.isLoading;
});

/// Current game filters
final currentFiltersProvider = Provider((ref) {
  final gamesState = ref.watch(gamesControllerProvider);
  return gamesState.filters;
});

/// Current venue filters
final currentVenueFiltersProvider = Provider((ref) {
  final venuesState = ref.watch(venuesControllerProvider);
  return venuesState.filters;
});

// =============================================================================
// SPECIFIC GAME PROVIDERS
// =============================================================================

/// Specific game detail by ID
final gameByIdProvider = Provider.family<Game?, String>((ref, gameId) {
  final gamesState = ref.watch(gamesControllerProvider);

  // Search in all game lists
  for (final game in [
    ...gamesState.upcomingGames,
    ...gamesState.nearbyGames,
    ...gamesState.allGames,
  ]) {
    if (game.id == gameId) return game;
  }

  return null;
});

/// Venue detail by ID
final venueByIdProvider = Provider.family<Venue?, String>((ref, venueId) {
  final venuesState = ref.watch(venuesControllerProvider);

  for (final venueWithDistance in venuesState.venues) {
    if (venueWithDistance.venue.id == venueId) {
      return venueWithDistance.venue;
    }
  }

  return null;
});

/// Games organized by specific user
final gamesByOrganizerProvider = Provider.family<List<Game>, String>((
  ref,
  organizerId,
) {
  final gamesState = ref.watch(gamesControllerProvider);

  return [
    ...gamesState.upcomingGames.where((g) => g.organizerId == organizerId),
    ...gamesState.allGames.where((g) => g.organizerId == organizerId),
  ];
});

/// Games by sport
final gamesBySportProvider = Provider.family<List<Game>, String>((ref, sport) {
  final gamesState = ref.watch(gamesControllerProvider);

  return [
    ...gamesState.upcomingGames.where(
      (g) => g.sport.toLowerCase() == sport.toLowerCase(),
    ),
    ...gamesState.allGames.where(
      (g) => g.sport.toLowerCase() == sport.toLowerCase(),
    ),
  ];
});

/// Venues by sport
final venuesBySportProvider = Provider.family<List<VenueWithDistance>, String>((
  ref,
  sport,
) {
  final venuesState = ref.watch(venuesControllerProvider);

  return venuesState.venues
      .where(
        (vwd) => vwd.venue.supportedSports.any(
          (s) => s.toLowerCase() == sport.toLowerCase(),
        ),
      )
      .toList();
});

// =============================================================================
// ACTION PROVIDERS (for UI to call controller methods)
// =============================================================================

/// Games actions provider
final gamesActionsProvider = Provider((ref) {
  return GamesActions(ref);
});

/// Venues actions provider
final venuesActionsProvider = Provider((ref) {
  return VenuesActions(ref);
});

/// My games actions provider
final myGamesActionsProvider = Provider.family<MyGamesActions, String>((
  ref,
  userId,
) {
  return MyGamesActions(ref, userId);
});

// /// Create game actions provider
// final createGameActionsProvider = Provider((ref) {
//   return CreateGameActions(ref);
// });

// =============================================================================
// SUPPORTING CLASSES
// =============================================================================

/// Parameters for game detail controller
class GameDetailParams {
  final String gameId;
  final String? currentUserId;

  const GameDetailParams({required this.gameId, this.currentUserId});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GameDetailParams &&
          runtimeType == other.runtimeType &&
          gameId == other.gameId &&
          currentUserId == other.currentUserId;

  @override
  int get hashCode => gameId.hashCode ^ currentUserId.hashCode;
}

/// Action wrapper classes for easier UI integration
class GamesActions {
  final Ref _ref;
  GamesActions(this._ref);

  Future<void> loadGames({GameListType type = GameListType.all}) async {
    await _ref.read(gamesControllerProvider.notifier).loadGames(type: type);
  }

  Future<void> refreshGames() async {
    await _ref.read(gamesControllerProvider.notifier).refreshGames();
  }

  Future<void> updateFilters(GameFilters filters) async {
    await _ref.read(gamesControllerProvider.notifier).updateFilters(filters);
  }

  Future<void> setUserLocation(double latitude, double longitude) async {
    await _ref
        .read(gamesControllerProvider.notifier)
        .setUserLocation(latitude, longitude);
  }

  Future<void> loadMore() async {
    await _ref.read(gamesControllerProvider.notifier).loadMore();
  }

  void clearFilters() {
    _ref.read(gamesControllerProvider.notifier).clearFilters();
  }
}

class VenuesActions {
  final Ref _ref;
  VenuesActions(this._ref);

  Future<void> loadVenues() async {
    await _ref.read(venuesControllerProvider.notifier).loadVenues();
  }

  Future<void> setUserLocation(double latitude, double longitude) async {
    await _ref
        .read(venuesControllerProvider.notifier)
        .setUserLocation(latitude, longitude);
  }

  Future<void> updateFilters(VenueFilters filters) async {
    await _ref.read(venuesControllerProvider.notifier).updateFilters(filters);
  }

  Future<void> searchVenues(String query) async {
    await _ref.read(venuesControllerProvider.notifier).searchVenues(query);
  }

  Future<void> addToFavorites(String venueId) async {
    await _ref.read(venuesControllerProvider.notifier).addToFavorites(venueId);
  }

  Future<void> removeFromFavorites(String venueId) async {
    await _ref
        .read(venuesControllerProvider.notifier)
        .removeFromFavorites(venueId);
  }

  Future<void> refresh() async {
    await _ref.read(venuesControllerProvider.notifier).refresh();
  }
}

class MyGamesActions {
  final Ref _ref;
  final String _userId;
  MyGamesActions(this._ref, this._userId);

  Future<void> refresh() async {
    await _ref.read(myGamesControllerProvider(_userId).notifier).refresh();
  }

  Future<void> cancelGame(String gameId, String reason) async {
    await _ref
        .read(myGamesControllerProvider(_userId).notifier)
        .cancelGame(gameId, reason);
  }

  Future<String> shareGame(String gameId) async {
    return await _ref
        .read(myGamesControllerProvider(_userId).notifier)
        .shareGame(gameId);
  }

  Future<void> checkInToGame(String gameId) async {
    await _ref
        .read(myGamesControllerProvider(_userId).notifier)
        .checkInToGame(gameId);
  }

  Future<void> executeQuickAction(
    QuickAction action,
    String gameId, {
    Map<String, dynamic>? completionStats,
  }) async {
    await _ref
        .read(myGamesControllerProvider(_userId).notifier)
        .executeQuickAction(action, gameId, completionStats: completionStats);
  }
}

// class CreateGameActions {
//   final Ref _ref;
//   CreateGameActions(this._ref);

//   void selectSport(String sport) {
//     _ref.read(createGameControllerProvider.notifier).selectSport(sport);
//   }

//   void setDateTime({DateTime? date, String? startTime, String? endTime}) {
//     _ref.read(createGameControllerProvider.notifier).setDateTime(
//       date: date,
//       startTime: startTime,
//       endTime: endTime,
//     );
//   }

//   void selectVenue(Venue? venue) {
//     _ref.read(createGameControllerProvider.notifier).selectVenue(venue);
//   }

//   void configureGame({
//     String? title,
//     String? description,
//     String? skillLevel,
//     double? pricePerPlayer,
//     bool? isPublic,
//     bool? allowWaitlist,
//   }) {
//     _ref.read(createGameControllerProvider.notifier).configureGame(
//       title: title,
//       description: description,
//       skillLevel: skillLevel,
//       pricePerPlayer: pricePerPlayer,
//       isPublic: isPublic,
//       allowWaitlist: allowWaitlist,
//     );
//   }

//   void configurePlayerSettings({int? minPlayers, int? maxPlayers}) {
//     _ref.read(createGameControllerProvider.notifier).configurePlayerSettings(
//       minPlayers: minPlayers,
//       maxPlayers: maxPlayers,
//     );
//   }

//   void nextStep() {
//     _ref.read(createGameControllerProvider.notifier).nextStep();
//   }

//   void previousStep() {
//     _ref.read(createGameControllerProvider.notifier).previousStep();
//   }

//   void goToStep(CreateGameStep step) {
//     _ref.read(createGameControllerProvider.notifier).goToStep(step);
//   }

//   Future<void> reviewAndCreate(String organizerId) async {
//     await _ref.read(createGameControllerProvider.notifier).reviewAndCreate(organizerId);
//   }

//   void reset() {
//     _ref.read(createGameControllerProvider.notifier).reset();
//   }
// }
