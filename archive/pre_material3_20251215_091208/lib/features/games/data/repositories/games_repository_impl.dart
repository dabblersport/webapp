import 'package:fpdart/fpdart.dart' hide Unit, unit;
import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/core/fp/result_guard.dart';
import '../../../../core/errors/exceptions.dart';
import 'package:dabbler/data/models/games/game.dart';
import 'package:dabbler/data/models/games/player.dart';
import '../../domain/repositories/games_repository.dart';
import '../datasources/games_remote_data_source.dart';
import 'package:dabbler/data/models/games/game_model.dart';

// Additional failures for games
class ServerFailure extends Failure {
  const ServerFailure(String message) : super(message: message);
}

class CacheFailure extends Failure {
  const CacheFailure(String message) : super(message: message);
}

class UnknownFailure extends Failure {
  const UnknownFailure(String message) : super(message: message);
}

// Additional exceptions for games
class ServerException implements Exception {
  final String message;
  const ServerException(this.message);
}

class CacheException implements Exception {
  final String message;
  const CacheException(this.message);
}

// In-session tracker to avoid re-prompt spam
final Set<String> _ratedInSession = <String>{};

class GamesRepositoryImpl implements GamesRepository {
  final GamesRemoteDataSource remoteDataSource;

  // In-memory cache for games
  final Map<String, GameModel> _gamesCache = {};
  final Map<String, List<GameModel>> _listCache = {};

  GamesRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, Game>> createGame(
    Map<String, dynamic> gameData,
  ) async {
    try {
      final gameModel = await remoteDataSource.createGame(gameData);

      // Cache the created game
      _gamesCache[gameModel.id] = gameModel;

      // Clear list caches to force refresh
      _listCache.clear();

      return Right(gameModel);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    } catch (e) {
      return Left(UnknownFailure('Failed to create game: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, Game>> updateGame(
    String gameId,
    Map<String, dynamic> updates,
  ) async {
    try {
      final gameModel = await remoteDataSource.updateGame(gameId, updates);

      // Update cache
      _gamesCache[gameModel.id] = gameModel;

      // Clear list caches to force refresh
      _listCache.clear();

      return Right(gameModel);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    } catch (e) {
      return Left(UnknownFailure('Failed to update game: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, Game>> getGame(String gameId) async {
    try {
      // Check cache first
      if (_gamesCache.containsKey(gameId)) {
        return Right(_gamesCache[gameId]!);
      }

      final gameModel = await remoteDataSource.getGame(gameId);

      // Cache the game
      _gamesCache[gameModel.id] = gameModel;

      return Right(gameModel);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    } catch (e) {
      return Left(UnknownFailure('Failed to get game: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, List<Game>>> getGames({
    Map<String, dynamic>? filters,
    int page = 1,
    int limit = 20,
    String? sortBy,
    bool ascending = true,
  }) async {
    try {
      final cacheKey = _generateCacheKey(
        'games',
        filters,
        page,
        limit,
        sortBy,
        ascending,
      );

      // Check cache first
      if (_listCache.containsKey(cacheKey)) {
        return Right(_listCache[cacheKey]!.cast<Game>());
      }

      final games = await remoteDataSource.getGames(
        filters: filters,
        page: page,
        limit: limit,
        sortBy: sortBy,
        ascending: ascending,
      );

      // Cache individual games and the list
      for (final game in games) {
        _gamesCache[game.id] = game;
      }
      _listCache[cacheKey] = games;

      return Right(games.cast<Game>());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    } catch (e) {
      return Left(UnknownFailure('Failed to get games: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, bool>> joinGame(String gameId, String playerId) async {
    try {
      // Optimistic update - update local cache first
      if (_gamesCache.containsKey(gameId)) {
        // Update the game's player list optimistically if needed
      }

      final result = await remoteDataSource.joinGame(gameId, playerId);

      if (result) {
        // Clear cache to force refresh on next get
        _gamesCache.remove(gameId);
        _listCache.clear();
      }

      return Right(result);
    } on GameFullException catch (e) {
      _gamesCache.remove(gameId);
      return Left(ValidationFailure(message: e.message));
    } on GameAlreadyStartedException catch (e) {
      _gamesCache.remove(gameId);
      return Left(ValidationFailure(message: e.message));
    } on GameNotFoundException catch (e) {
      return Left(NotFoundFailure(message: e.message));
    } on ServerException catch (e) {
      // Revert optimistic update if failed
      _gamesCache.remove(gameId);
      return Left(ServerFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    } catch (e) {
      return Left(UnknownFailure('Failed to join game: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, bool>> leaveGame(
    String gameId,
    String playerId,
  ) async {
    try {
      final result = await remoteDataSource.leaveGame(gameId, playerId);

      if (result) {
        // Clear cache to force refresh
        _gamesCache.remove(gameId);
        _listCache.clear();
      }

      return Right(result);
    } on GameNotFoundException catch (e) {
      return Left(NotFoundFailure(message: e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    } catch (e) {
      return Left(UnknownFailure('Failed to leave game: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, bool>> cancelGame(String gameId) async {
    try {
      final result = await remoteDataSource.cancelGame(gameId);

      if (result) {
        // Clear cache to force refresh
        _gamesCache.remove(gameId);
        _listCache.clear();
      }

      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    } catch (e) {
      return Left(UnknownFailure('Failed to cancel game: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, List<Game>>> getMyGames(
    String userId, {
    String? status,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final cacheKey = _generateCacheKey(
        'my_games',
        {'userId': userId, 'status': status},
        page,
        limit,
      );

      // Check cache first
      if (_listCache.containsKey(cacheKey)) {
        return Right(_listCache[cacheKey]!.cast<Game>());
      }

      final games = await remoteDataSource.getMyGames(
        userId,
        status: status,
        page: page,
        limit: limit,
      );

      // Cache individual games and the list
      for (final game in games) {
        _gamesCache[game.id] = game;
      }
      _listCache[cacheKey] = games;

      return Right(games.cast<Game>());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    } catch (e) {
      return Left(UnknownFailure('Failed to get user games: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, List<Game>>> searchGames(
    String query, {
    Map<String, dynamic>? filters,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      // For search, we'll skip cache to always get fresh results
      final games = await remoteDataSource.searchGames(
        query,
        filters: filters,
        page: page,
        limit: limit,
      );

      // Cache individual games but not the search list (as it may change frequently)
      for (final game in games) {
        _gamesCache[game.id] = game;
      }

      return Right(games.cast<Game>());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    } catch (e) {
      return Left(UnknownFailure('Failed to search games: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, List<Game>>> getNearbyGames(
    double latitude,
    double longitude,
    double radiusKm, {
    Map<String, dynamic>? filters,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final games = await remoteDataSource.getNearbyGames(
        latitude,
        longitude,
        radiusKm,
        filters: filters,
        page: page,
        limit: limit,
      );

      // Cache individual games
      for (final game in games) {
        _gamesCache[game.id] = game;
      }

      return Right(games.cast<Game>());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    } catch (e) {
      return Left(
        UnknownFailure('Failed to get nearby games: ${e.toString()}'),
      );
    }
  }

  @override
  Future<Either<Failure, List<Game>>> getGamesBySport(
    String sportType, {
    Map<String, dynamic>? filters,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final games = await remoteDataSource.getGamesBySport(
        sportType,
        filters: filters,
        page: page,
        limit: limit,
      );
      return Right(games.cast<Game>());
    } catch (e) {
      return Left(
        UnknownFailure('Failed to get games by sport: ${e.toString()}'),
      );
    }
  }

  @override
  Future<Either<Failure, List<Game>>> getTrendingGames({
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final games = await remoteDataSource.getTrendingGames(
        page: page,
        limit: limit,
      );
      return Right(games.cast<Game>());
    } catch (e) {
      return Left(
        UnknownFailure('Failed to get trending games: ${e.toString()}'),
      );
    }
  }

  @override
  Future<Either<Failure, List<Game>>> getRecommendedGames(
    String userId, {
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final games = await remoteDataSource.getRecommendedGames(
        userId,
        page: page,
        limit: limit,
      );
      return Right(games.cast<Game>());
    } catch (e) {
      return Left(
        UnknownFailure('Failed to get recommended games: ${e.toString()}'),
      );
    }
  }

  @override
  Future<Either<Failure, bool>> updateGameStatus(
    String gameId,
    GameStatus status,
  ) async {
    try {
      final result = await remoteDataSource.updateGameStatus(
        gameId,
        status.toString().split('.').last,
      );
      if (result) {
        _gamesCache.remove(gameId);
        _listCache.clear();
      }
      return Right(result);
    } catch (e) {
      return Left(
        UnknownFailure('Failed to update game status: ${e.toString()}'),
      );
    }
  }

  @override
  Future<Either<Failure, bool>> invitePlayersToGame(
    String gameId,
    List<String> playerIds,
    String? message,
  ) async {
    try {
      final result = await remoteDataSource.invitePlayersToGame(
        gameId,
        playerIds,
        message,
      );
      return Right(result);
    } catch (e) {
      return Left(UnknownFailure('Failed to invite players: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, bool>> respondToGameInvitation(
    String gameId,
    String playerId,
    bool accepted,
  ) async {
    try {
      final result = await remoteDataSource.respondToGameInvitation(
        gameId,
        playerId,
        accepted,
      );
      if (result) {
        _gamesCache.remove(gameId);
        _listCache.clear();
      }
      return Right(result);
    } catch (e) {
      return Left(
        UnknownFailure('Failed to respond to invitation: ${e.toString()}'),
      );
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> getUserGameStats(
    String userId,
  ) async {
    try {
      final stats = await remoteDataSource.getUserGameStats(userId);
      return Right(stats);
    } catch (e) {
      return Left(UnknownFailure('Failed to get user stats: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, bool>> reportGame(
    String gameId,
    String reason,
    String? description,
  ) async {
    try {
      final result = await remoteDataSource.reportGame(
        gameId,
        reason,
        description,
      );
      return Right(result);
    } catch (e) {
      return Left(UnknownFailure('Failed to report game: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, bool>> toggleGameFavorite(
    String gameId,
    String userId,
  ) async {
    try {
      final result = await remoteDataSource.toggleGameFavorite(gameId, userId);
      return Right(result);
    } catch (e) {
      return Left(UnknownFailure('Failed to toggle favorite: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, List<Game>>> getFavoriteGames(
    String userId, {
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final games = await remoteDataSource.getFavoriteGames(
        userId,
        page: page,
        limit: limit,
      );
      return Right(games.cast<Game>());
    } catch (e) {
      return Left(
        UnknownFailure('Failed to get favorite games: ${e.toString()}'),
      );
    }
  }

  @override
  Future<Either<Failure, bool>> canUserJoinGame(
    String gameId,
    String userId,
  ) async {
    try {
      final result = await remoteDataSource.canUserJoinGame(gameId, userId);
      return Right(result);
    } catch (e) {
      return Left(
        UnknownFailure('Failed to check join eligibility: ${e.toString()}'),
      );
    }
  }

  @override
  Future<Either<Failure, List<Game>>> getGameHistory(
    String userId, {
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final games = await remoteDataSource.getGameHistory(
        userId,
        page: page,
        limit: limit,
      );
      return Right(games.cast<Game>());
    } catch (e) {
      return Left(
        UnknownFailure('Failed to get game history: ${e.toString()}'),
      );
    }
  }

  @override
  Future<Either<Failure, Game>> duplicateGame(
    String gameId,
    DateTime newDate,
    String newStartTime,
    String newEndTime,
  ) async {
    try {
      final gameModel = await remoteDataSource.duplicateGame(
        gameId,
        newDate.toIso8601String().split('T')[0],
        newStartTime,
        newEndTime,
      );

      // Cache the new game
      _gamesCache[gameModel.id] = gameModel;
      _listCache.clear();

      return Right(gameModel);
    } catch (e) {
      return Left(UnknownFailure('Failed to duplicate game: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, List<Player>>> getGamePlayers(String gameId) async {
    try {
      final players = await remoteDataSource.getGamePlayers(gameId);
      return Right(players.cast<Player>());
    } catch (e) {
      return Left(
        UnknownFailure('Failed to get game players: ${e.toString()}'),
      );
    }
  }

  @override
  Future<Either<Failure, bool>> hasPendingJoinRequest(
    String gameId,
    String userId,
  ) async {
    try {
      final hasRequest = await remoteDataSource.hasPendingJoinRequest(
        gameId,
        userId,
      );
      return Right(hasRequest);
    } catch (e) {
      return Left(
        UnknownFailure('Failed to check join request: ${e.toString()}'),
      );
    }
  }

  @override
  Future<Either<Failure, bool>> cancelJoinRequest(
    String gameId,
    String userId,
  ) async {
    try {
      final cancelled = await remoteDataSource.cancelJoinRequest(
        gameId,
        userId,
      );
      return Right(cancelled);
    } catch (e) {
      return Left(
        UnknownFailure('Failed to cancel join request: ${e.toString()}'),
      );
    }
  }

  // Helper method to generate cache keys
  String _generateCacheKey(
    String prefix,
    Map<String, dynamic>? params,
    int page,
    int limit, [
    String? sortBy,
    bool? ascending,
  ]) {
    final buffer = StringBuffer(prefix);
    if (params != null) {
      params.forEach((key, value) {
        buffer.write('_${key}_${value?.toString() ?? 'null'}');
      });
    }
    buffer.write('_page_$page');
    buffer.write('_limit_$limit');
    if (sortBy != null) buffer.write('_sort_$sortBy');
    if (ascending != null) buffer.write('_asc_$ascending');
    return buffer.toString();
  }

  /// Submit a game rating (1-5 stars) with optional note.
  /// Returns Unit on success. Idempotent: treats duplicate/conflict as success.
  Future<Result<Unit, Failure>> rateGame(
    String gameId,
    int rating, {
    String? note,
  }) async {
    // Clamp rating defensively 1..5
    final r = rating.clamp(1, 5);
    final res = await guardResult(() async {
      await remoteDataSource.submitGameRating(gameId, r, note: note);
      _ratedInSession.add(gameId);
      return unit;
    });
    // Treat duplicate/conflict as success (idempotent)
    if (res.isFailure) {
      final e = res.requireError.message.toLowerCase();
      if (e.contains('already') ||
          e.contains('duplicate') ||
          e.contains('conflict') ||
          e.contains('23505')) {
        _ratedInSession.add(gameId);
        return Ok(unit);
      }
    }
    return res;
  }

  /// Fetch the current user's average game rating (0.0-5.0).
  /// Returns 0.0 if no ratings or if backend not implemented.
  Future<Result<double, Failure>> myAverageRating() async {
    return await guardResult(() async {
      final v = await remoteDataSource.fetchMyAverageRating();
      if (v.isNaN || v.isInfinite) return 0.0;
      if (v < 0) return 0.0;
      if (v > 5) return 5.0;
      return v;
    });
  }

  /// Helper to check if a game has been rated in this session.
  /// Prevents re-prompting the user for the same game.
  bool hasRatedInSession(String gameId) => _ratedInSession.contains(gameId);

  // Clear cache method for external use
  @override
  Future<Either<Failure, bool>> isPlayerInGame(
    String gameId,
    String userId,
  ) async {
    try {
      final isInGame = await remoteDataSource.isPlayerInGame(gameId, userId);
      return Right(isInGame);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    } catch (e) {
      return Left(
        UnknownFailure('Failed to check player status: ${e.toString()}'),
      );
    }
  }

  @override
  Future<Either<Failure, int?>> getWaitlistPosition(
    String gameId,
    String userId,
  ) async {
    try {
      final position = await remoteDataSource.getWaitlistPosition(
        gameId,
        userId,
      );
      return Right(position);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    } catch (e) {
      return Left(
        UnknownFailure('Failed to get waitlist position: ${e.toString()}'),
      );
    }
  }

  void clearCache() {
    _gamesCache.clear();
    _listCache.clear();
  }
}
