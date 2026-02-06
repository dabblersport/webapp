import 'package:fpdart/fpdart.dart';
import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/data/models/games/game.dart';
import 'package:dabbler/data/models/games/player.dart';

abstract class GamesRepository {
  /// Creates a new game with the provided data
  /// Returns the created Game on success, or a Failure on error
  Future<Either<Failure, Game>> createGame(Map<String, dynamic> gameData);

  /// Updates an existing game with new data
  /// Returns the updated Game on success, or a Failure on error
  Future<Either<Failure, Game>> updateGame(
    String gameId,
    Map<String, dynamic> updates,
  );

  /// Retrieves a single game by its ID
  /// Returns the Game on success, or a Failure on error
  Future<Either<Failure, Game>> getGame(String gameId);

  /// Retrieves a list of games based on filters
  /// Filters can include: sport, location, date, status, etc.
  Future<Either<Failure, List<Game>>> getGames({
    Map<String, dynamic>? filters,
    int page = 1,
    int limit = 20,
    String? sortBy,
    bool ascending = true,
  });

  /// Allows a player to join a game
  /// Returns true on success, or a Failure on error
  Future<Either<Failure, bool>> joinGame(String gameId, String playerId);

  /// Allows a player to leave a game
  /// Returns true on success, or a Failure on error
  Future<Either<Failure, bool>> leaveGame(String gameId, String playerId);

  /// Cancels a game (only by game creator or admin)
  /// Returns true on success, or a Failure on error
  Future<Either<Failure, bool>> cancelGame(String gameId);

  /// Retrieves games for a specific user
  /// Status can filter by: 'upcoming', 'completed', 'cancelled', etc.
  Future<Either<Failure, List<Game>>> getMyGames(
    String userId, {
    String? status,
    int page = 1,
    int limit = 20,
  });

  /// Searches games based on query and filters
  /// Query searches in game title, description, venue name, etc.
  Future<Either<Failure, List<Game>>> searchGames(
    String query, {
    Map<String, dynamic>? filters,
    int page = 1,
    int limit = 20,
  });

  /// Gets games near a specific location
  Future<Either<Failure, List<Game>>> getNearbyGames(
    double latitude,
    double longitude,
    double radiusKm, {
    Map<String, dynamic>? filters,
    int page = 1,
    int limit = 20,
  });

  /// Gets games by sport type
  Future<Either<Failure, List<Game>>> getGamesBySport(
    String sportType, {
    Map<String, dynamic>? filters,
    int page = 1,
    int limit = 20,
  });

  /// Gets popular/trending games
  Future<Either<Failure, List<Game>>> getTrendingGames({
    int page = 1,
    int limit = 20,
  });

  /// Gets games recommended for a user
  Future<Either<Failure, List<Game>>> getRecommendedGames(
    String userId, {
    int page = 1,
    int limit = 20,
  });

  /// Updates game status (e.g., from scheduled to in-progress)
  Future<Either<Failure, bool>> updateGameStatus(
    String gameId,
    GameStatus status,
  );

  /// Invites players to a game
  Future<Either<Failure, bool>> invitePlayersToGame(
    String gameId,
    List<String> playerIds,
    String? message,
  );

  /// Responds to a game invitation
  Future<Either<Failure, bool>> respondToGameInvitation(
    String gameId,
    String playerId,
    bool accepted,
  );

  /// Gets game statistics for a user
  Future<Either<Failure, Map<String, dynamic>>> getUserGameStats(String userId);

  /// Reports a game for inappropriate content or behavior
  Future<Either<Failure, bool>> reportGame(
    String gameId,
    String reason,
    String? description,
  );

  /// Marks a game as favorite for a user
  Future<Either<Failure, bool>> toggleGameFavorite(
    String gameId,
    String userId,
  );

  /// Gets user's favorite games
  Future<Either<Failure, List<Game>>> getFavoriteGames(
    String userId, {
    int page = 1,
    int limit = 20,
  });

  /// Checks if a user can join a specific game
  Future<Either<Failure, bool>> canUserJoinGame(String gameId, String userId);

  /// Gets game history for a user (past games)
  Future<Either<Failure, List<Game>>> getGameHistory(
    String userId, {
    int page = 1,
    int limit = 20,
  });

  /// Duplicates a game with new date/time
  Future<Either<Failure, Game>> duplicateGame(
    String gameId,
    DateTime newDate,
    String newStartTime,
    String newEndTime,
  );

  /// Gets all players for a specific game
  Future<Either<Failure, List<Player>>> getGamePlayers(String gameId);

  /// Checks if a player is already in a game (any status)
  Future<Either<Failure, bool>> isPlayerInGame(String gameId, String userId);

  /// Gets the waitlist position for a player in a game
  /// Returns null if player is not on waitlist
  Future<Either<Failure, int?>> getWaitlistPosition(
    String gameId,
    String userId,
  );

  /// Checks if a user has a pending join request for a game
  Future<Either<Failure, bool>> hasPendingJoinRequest(
    String gameId,
    String userId,
  );

  /// Cancels a pending join request for a game
  Future<Either<Failure, bool>> cancelJoinRequest(String gameId, String userId);
}
