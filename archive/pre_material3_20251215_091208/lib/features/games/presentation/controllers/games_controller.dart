import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dabbler/data/models/games/game.dart';
import '../../domain/usecases/find_games_usecase.dart';

enum GameListType { upcoming, nearby, all }

class GameFilters {
  final String? sport;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? skillLevel;
  final double? maxPricePerPlayer;
  final double? radiusKm;
  final double? userLatitude;
  final double? userLongitude;
  final bool includeWaitlisted;

  const GameFilters({
    this.sport,
    this.startDate,
    this.endDate,
    this.skillLevel,
    this.maxPricePerPlayer,
    this.radiusKm,
    this.userLatitude,
    this.userLongitude,
    this.includeWaitlisted = false,
  });

  GameFilters copyWith({
    String? sport,
    DateTime? startDate,
    DateTime? endDate,
    String? skillLevel,
    double? maxPricePerPlayer,
    double? radiusKm,
    double? userLatitude,
    double? userLongitude,
    bool? includeWaitlisted,
  }) {
    return GameFilters(
      sport: sport ?? this.sport,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      skillLevel: skillLevel ?? this.skillLevel,
      maxPricePerPlayer: maxPricePerPlayer ?? this.maxPricePerPlayer,
      radiusKm: radiusKm ?? this.radiusKm,
      userLatitude: userLatitude ?? this.userLatitude,
      userLongitude: userLongitude ?? this.userLongitude,
      includeWaitlisted: includeWaitlisted ?? this.includeWaitlisted,
    );
  }
}

class PaginationInfo {
  final int currentPage;
  final int totalPages;
  final int totalItems;
  final bool hasNextPage;
  final bool hasPreviousPage;

  const PaginationInfo({
    required this.currentPage,
    required this.totalPages,
    required this.totalItems,
    required this.hasNextPage,
    required this.hasPreviousPage,
  });

  PaginationInfo copyWith({
    int? currentPage,
    int? totalPages,
    int? totalItems,
    bool? hasNextPage,
    bool? hasPreviousPage,
  }) {
    return PaginationInfo(
      currentPage: currentPage ?? this.currentPage,
      totalPages: totalPages ?? this.totalPages,
      totalItems: totalItems ?? this.totalItems,
      hasNextPage: hasNextPage ?? this.hasNextPage,
      hasPreviousPage: hasPreviousPage ?? this.hasPreviousPage,
    );
  }
}

class GamesState {
  final List<Game> upcomingGames;
  final List<Game> nearbyGames;
  final List<Game> allGames;
  final bool isLoadingUpcoming;
  final bool isLoadingNearby;
  final bool isLoadingAll;
  final bool isRefreshing;
  final String? error;
  final GameFilters filters;
  final PaginationInfo? paginationInfo;
  final DateTime? lastUpdated;

  const GamesState({
    this.upcomingGames = const [],
    this.nearbyGames = const [],
    this.allGames = const [],
    this.isLoadingUpcoming = false,
    this.isLoadingNearby = false,
    this.isLoadingAll = false,
    this.isRefreshing = false,
    this.error,
    this.filters = const GameFilters(),
    this.paginationInfo,
    this.lastUpdated,
  });

  bool get isLoading => isLoadingUpcoming || isLoadingNearby || isLoadingAll;
  bool get hasError => error != null;
  bool get hasGames =>
      upcomingGames.isNotEmpty || nearbyGames.isNotEmpty || allGames.isNotEmpty;

  GamesState copyWith({
    List<Game>? upcomingGames,
    List<Game>? nearbyGames,
    List<Game>? allGames,
    bool? isLoadingUpcoming,
    bool? isLoadingNearby,
    bool? isLoadingAll,
    bool? isRefreshing,
    String? error,
    GameFilters? filters,
    PaginationInfo? paginationInfo,
    DateTime? lastUpdated,
  }) {
    return GamesState(
      upcomingGames: upcomingGames ?? this.upcomingGames,
      nearbyGames: nearbyGames ?? this.nearbyGames,
      allGames: allGames ?? this.allGames,
      isLoadingUpcoming: isLoadingUpcoming ?? this.isLoadingUpcoming,
      isLoadingNearby: isLoadingNearby ?? this.isLoadingNearby,
      isLoadingAll: isLoadingAll ?? this.isLoadingAll,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      error: error,
      filters: filters ?? this.filters,
      paginationInfo: paginationInfo ?? this.paginationInfo,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}

class GamesController extends StateNotifier<GamesState> {
  final FindGamesUseCase _findGamesUseCase;
  static const int _pageSize = 20;
  static const Duration _cacheValidity = Duration(minutes: 5);

  GamesController({required FindGamesUseCase findGamesUseCase})
    : _findGamesUseCase = findGamesUseCase,
      super(const GamesState());

  /// Load games with current filters
  Future<void> loadGames({
    GameListType type = GameListType.all,
    int page = 1,
    bool append = false,
  }) async {
    // Check if we need to refresh based on cache validity
    if (state.lastUpdated != null && !_shouldRefresh()) {
      return;
    }

    // Set loading state based on type
    switch (type) {
      case GameListType.upcoming:
        state = state.copyWith(isLoadingUpcoming: true, error: null);
        break;
      case GameListType.nearby:
        state = state.copyWith(isLoadingNearby: true, error: null);
        break;
      case GameListType.all:
        state = state.copyWith(isLoadingAll: true, error: null);
        break;
    }

    try {
      final filters = _buildFiltersForType(type);
      final result = await _findGamesUseCase(
        FindGamesParams(
          sport: filters.sport,
          startDate: filters.startDate,
          endDate: filters.endDate,
          skillLevel: filters.skillLevel,
          maxPricePerPlayer: filters.maxPricePerPlayer,
          userLatitude: filters.userLatitude,
          userLongitude: filters.userLongitude,
          radiusKm: filters.radiusKm,
          includeWaitlistGames: filters.includeWaitlisted,
          page: page,
          limit: _pageSize,
        ),
      );

      result.fold(
        (failure) => _handleError(failure.message),
        (gamesWithDistance) =>
            _handleGamesLoaded(gamesWithDistance, type, page, append),
      );
    } catch (e) {
      _handleError('Failed to load games: $e');
    }
  }

  /// Refresh all game lists
  Future<void> refreshGames() async {
    state = state.copyWith(isRefreshing: true, error: null);

    try {
      // Load all types concurrently
      await Future.wait([
        loadGames(type: GameListType.upcoming),
        loadGames(type: GameListType.nearby),
        loadGames(type: GameListType.all),
      ]);
    } finally {
      state = state.copyWith(isRefreshing: false, lastUpdated: DateTime.now());
    }
  }

  /// Update filters and reload games
  Future<void> updateFilters(GameFilters newFilters) async {
    state = state.copyWith(filters: newFilters);
    await loadGames(type: GameListType.all);
  }

  /// Clear current search and filters
  void clearFilters() {
    state = state.copyWith(
      filters: const GameFilters(),
      allGames: [],
      paginationInfo: null,
    );
  }

  /// Load more games for pagination
  Future<void> loadMore() async {
    final pagination = state.paginationInfo;
    if (pagination != null && pagination.hasNextPage) {
      await loadGames(
        type: GameListType.all,
        page: pagination.currentPage + 1,
        append: true,
      );
    }
  }

  /// Set user location for nearby games
  Future<void> setUserLocation(double latitude, double longitude) async {
    final newFilters = state.filters.copyWith(
      userLatitude: latitude,
      userLongitude: longitude,
      radiusKm: state.filters.radiusKm ?? 10.0, // Default 10km radius
    );

    state = state.copyWith(filters: newFilters);
    await loadGames(type: GameListType.nearby);
  }

  /// Subscribe to real-time game updates (stub for future implementation)
  void subscribeToUpdates() {
    // This would listen to game changes and update the state accordingly
  }

  /// Unsubscribe from real-time updates
  void unsubscribeFromUpdates() {}

  /// Private helper methods

  GameFilters _buildFiltersForType(GameListType type) {
    final baseFilters = state.filters;

    switch (type) {
      case GameListType.upcoming:
        return baseFilters.copyWith(
          startDate: DateTime.now(),
          endDate: DateTime.now().add(const Duration(days: 7)),
        );

      case GameListType.nearby:
        return baseFilters.copyWith(radiusKm: baseFilters.radiusKm ?? 10.0);

      case GameListType.all:
        return baseFilters;
    }
  }

  bool _shouldRefresh() {
    if (state.lastUpdated == null) return true;
    return DateTime.now().difference(state.lastUpdated!) > _cacheValidity;
  }

  void _handleGamesLoaded(
    List<GameWithDistance> gamesWithDistance,
    GameListType type,
    int page,
    bool append,
  ) {
    final currentTime = DateTime.now();
    final games = gamesWithDistance.map((gwd) => gwd.game).toList();

    // Calculate pagination info
    final paginationInfo = PaginationInfo(
      currentPage: page,
      totalPages: (games.length / _pageSize).ceil(),
      totalItems: games.length,
      hasNextPage: games.length == _pageSize,
      hasPreviousPage: page > 1,
    );

    switch (type) {
      case GameListType.upcoming:
        final filteredGames = games
            .where(
              (game) =>
                  game.scheduledDate.isAfter(currentTime) &&
                  game.status == GameStatus.upcoming,
            )
            .toList();

        state = state.copyWith(
          upcomingGames: append
              ? [...state.upcomingGames, ...filteredGames]
              : filteredGames,
          isLoadingUpcoming: false,
          lastUpdated: currentTime,
        );
        break;

      case GameListType.nearby:
        state = state.copyWith(
          nearbyGames: append ? [...state.nearbyGames, ...games] : games,
          isLoadingNearby: false,
          lastUpdated: currentTime,
        );
        break;

      case GameListType.all:
        state = state.copyWith(
          allGames: append ? [...state.allGames, ...games] : games,
          isLoadingAll: false,
          paginationInfo: paginationInfo,
          lastUpdated: currentTime,
        );
        break;
    }
  }

  void _handleError(String error) {
    state = state.copyWith(
      error: error,
      isLoadingUpcoming: false,
      isLoadingNearby: false,
      isLoadingAll: false,
      isRefreshing: false,
    );
  }

  @override
  void dispose() {
    unsubscribeFromUpdates();
    super.dispose();
  }
}
