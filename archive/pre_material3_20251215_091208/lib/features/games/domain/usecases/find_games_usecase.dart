import 'package:fpdart/fpdart.dart';
import 'package:dabbler/core/fp/failure.dart';
import '../../../../features/authentication/domain/usecases/usecase.dart';
import 'package:dabbler/data/models/games/game.dart';
import '../repositories/games_repository.dart';
import 'dart:math' as math;

// Game-specific failures
class GameFailure extends Failure {
  const GameFailure(String message) : super(message: message);
}

class FindGamesUseCase
    extends UseCase<Either<Failure, List<GameWithDistance>>, FindGamesParams> {
  final GamesRepository gamesRepository;

  FindGamesUseCase({required this.gamesRepository});

  @override
  Future<Either<Failure, List<GameWithDistance>>> call(
    FindGamesParams params,
  ) async {
    // Validate parameters
    final validationResult = _validateSearchParameters(params);
    if (validationResult != null) {
      return Left(validationResult);
    }

    // Build search filters
    final filters = _buildSearchFilters(params);

    // Get games from repository
    final gamesResult = await gamesRepository.getGames(
      filters: filters,
      page: params.page,
      limit: params.limit,
      sortBy: params.sortBy ?? 'scheduledDate',
      ascending: params.ascending,
    );

    return gamesResult.fold((failure) => Left(failure), (games) async {
      // Filter and process games
      final processedGames = await _processGames(games, params);

      // Sort by distance if location provided and not already sorting by distance
      if (params.userLatitude != null &&
          params.userLongitude != null &&
          params.sortBy != 'distance') {
        processedGames.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
      }

      return Right(processedGames);
    });
  }

  /// Validates search parameters
  Failure? _validateSearchParameters(FindGamesParams params) {
    // Validate date range
    if (params.startDate != null && params.endDate != null) {
      if (params.startDate!.isAfter(params.endDate!)) {
        return const GameFailure('Start date cannot be after end date');
      }
    }

    // Validate location coordinates
    if ((params.userLatitude != null) != (params.userLongitude != null)) {
      return const GameFailure(
        'Both latitude and longitude must be provided for location-based search',
      );
    }

    if (params.userLatitude != null) {
      if (params.userLatitude! < -90 || params.userLatitude! > 90) {
        return const GameFailure(
          'Invalid latitude. Must be between -90 and 90',
        );
      }
    }

    if (params.userLongitude != null) {
      if (params.userLongitude! < -180 || params.userLongitude! > 180) {
        return const GameFailure(
          'Invalid longitude. Must be between -180 and 180',
        );
      }
    }

    // Validate radius
    if (params.radiusKm != null && params.radiusKm! <= 0) {
      return const GameFailure('Radius must be greater than 0');
    }

    // Validate skill level
    if (params.skillLevel != null) {
      const validSkillLevels = [
        'beginner',
        'intermediate',
        'advanced',
        'mixed',
      ];
      if (!validSkillLevels.contains(params.skillLevel!.toLowerCase())) {
        return const GameFailure(
          'Invalid skill level. Must be: beginner, intermediate, advanced, or mixed',
        );
      }
    }

    // Validate pagination
    if (params.page < 1) {
      return const GameFailure('Page must be greater than 0');
    }

    if (params.limit < 1 || params.limit > 100) {
      return const GameFailure('Limit must be between 1 and 100');
    }

    return null;
  }

  /// Builds search filters map from parameters
  Map<String, dynamic> _buildSearchFilters(FindGamesParams params) {
    final filters = <String, dynamic>{};

    // Sport filter
    if (params.sport != null && params.sport!.isNotEmpty) {
      filters['sport'] = params.sport!.toLowerCase();
    }

    // Date range filters
    if (params.startDate != null) {
      filters['scheduledDate_gte'] = params.startDate!.toIso8601String();
    }
    if (params.endDate != null) {
      filters['scheduledDate_lte'] = params.endDate!.toIso8601String();
    }

    // Skill level filter
    if (params.skillLevel != null) {
      filters['skillLevel'] = params.skillLevel!.toLowerCase();
    }

    // Location-based filters
    if (params.userLatitude != null && params.userLongitude != null) {
      filters['latitude'] = params.userLatitude;
      filters['longitude'] = params.userLongitude;
      if (params.radiusKm != null) {
        filters['radius_km'] = params.radiusKm;
      }
    }

    // Price range filters
    if (params.maxPricePerPlayer != null) {
      filters['pricePerPlayer_lte'] = params.maxPricePerPlayer;
    }
    if (params.minPricePerPlayer != null) {
      filters['pricePerPlayer_gte'] = params.minPricePerPlayer;
    }

    // Only show public games
    filters['isPublic'] = true;

    // Only show upcoming games by default
    if (!filters.containsKey('status')) {
      filters['status'] = 'upcoming';
    }

    return filters;
  }

  /// Processes and filters games based on additional criteria
  Future<List<GameWithDistance>> _processGames(
    List<Game> games,
    FindGamesParams params,
  ) async {
    final processedGames = <GameWithDistance>[];

    for (final game in games) {
      // Exclude user's own games
      if (params.excludeUserId != null &&
          game.organizerId == params.excludeUserId) {
        continue;
      }

      // Exclude full games unless they allow waitlist and user wants waitlist games
      if (game.isFull() &&
          (!game.allowsWaitlist || !params.includeWaitlistGames)) {
        continue;
      }

      // Check if game is still joinable (time-wise)
      if (!game.isJoinable()) {
        continue;
      }

      // Calculate distance if user location provided and venue ID exists
      double? distance;
      if (params.userLatitude != null &&
          params.userLongitude != null &&
          game.venueId != null) {
        // For now, we'll set distance to 0 and note this limitation
        distance = 0.0;

        // In a real implementation, you would:
        // 1. Fetch venue details using venuesRepository.getVenue(game.venueId)
        // 2. Extract venue coordinates
        // 3. Calculate distance using _calculateDistance method

        // Example:
        // final venueResult = await venuesRepository.getVenue(game.venueId!);
        // if (venueResult.isRight()) {
        //   final venue = venueResult.getOrElse(() => null);
        //   if (venue != null && venue.latitude != null && venue.longitude != null) {
        //     distance = _calculateDistance(
        //       params.userLatitude!,
        //       params.userLongitude!,
        //       venue.latitude!,
        //       venue.longitude!,
        //     );
        //
        //     // Filter by radius if specified
        //     if (params.radiusKm != null && distance > params.radiusKm!) {
        //       continue;
        //     }
        //   }
        // }
      }

      // Additional filtering based on user preferences
      if (params.onlyWithMinPlayers && game.currentPlayers < game.minPlayers) {
        continue;
      }

      processedGames.add(
        GameWithDistance(game: game, distanceKm: distance ?? 0.0),
      );
    }

    return processedGames;
  }

  /// Calculates distance between two points using Haversine formula
  // ignore: unused_element
  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadius = 6371; // Earth's radius in kilometers

    final double dLat = _degreesToRadians(lat2 - lat1);
    final double dLon = _degreesToRadians(lon2 - lon1);

    final double a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degreesToRadians(lat1)) *
            math.cos(_degreesToRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadius * c;
  }

  /// Converts degrees to radians
  double _degreesToRadians(double degrees) {
    return degrees * (math.pi / 180);
  }
}

class FindGamesParams {
  final double? userLatitude;
  final double? userLongitude;
  final double? radiusKm;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? sport;
  final String? skillLevel;
  final double? minPricePerPlayer;
  final double? maxPricePerPlayer;
  final String? excludeUserId;
  final bool includeWaitlistGames;
  final bool onlyWithMinPlayers;
  final int page;
  final int limit;
  final String? sortBy;
  final bool ascending;

  FindGamesParams({
    this.userLatitude,
    this.userLongitude,
    this.radiusKm = 50.0, // Default 50km radius
    this.startDate,
    this.endDate,
    this.sport,
    this.skillLevel,
    this.minPricePerPlayer,
    this.maxPricePerPlayer,
    this.excludeUserId,
    this.includeWaitlistGames = true,
    this.onlyWithMinPlayers = false,
    this.page = 1,
    this.limit = 20,
    this.sortBy,
    this.ascending = true,
  });
}

class GameWithDistance {
  final Game game;
  final double distanceKm;

  GameWithDistance({required this.game, required this.distanceKm});

  // Convenience getters
  String get formattedDistance {
    if (distanceKm < 1) {
      return '${(distanceKm * 1000).round()}m away';
    } else if (distanceKm < 10) {
      return '${distanceKm.toStringAsFixed(1)}km away';
    } else {
      return '${distanceKm.round()}km away';
    }
  }

  bool get isNearby => distanceKm < 5.0; // Within 5km
  bool get isVeryClose => distanceKm < 1.0; // Within 1km
}
