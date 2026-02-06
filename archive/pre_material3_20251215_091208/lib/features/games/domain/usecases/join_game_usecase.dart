import 'package:fpdart/fpdart.dart';
import 'package:dabbler/core/fp/failure.dart';
import '../../../../features/authentication/domain/usecases/usecase.dart';
import 'package:dabbler/data/models/games/game.dart';
import '../repositories/games_repository.dart';

// Game-specific failures
class GameFailure extends Failure {
  const GameFailure(String message) : super(message: message);
}

class JoinGameUseCase
    extends UseCase<Either<Failure, JoinGameResult>, JoinGameParams> {
  final GamesRepository gamesRepository;

  JoinGameUseCase({required this.gamesRepository});

  @override
  Future<Either<Failure, JoinGameResult>> call(JoinGameParams params) async {
    // Validate parameters
    if (params.gameId.trim().isEmpty) {
      return Left(GameFailure('Game ID cannot be empty'));
    }

    if (params.playerId.trim().isEmpty) {
      return Left(GameFailure('Player ID cannot be empty'));
    }

    // Get the game details first
    final gameResult = await gamesRepository.getGame(params.gameId);

    return gameResult.fold((failure) => Left(failure), (game) async {
      // Validate that the player can join this game
      final validationResult = await _validateJoinRequest(
        game,
        params.playerId,
      );
      if (validationResult != null) {
        return Left(validationResult);
      }

      // Check if user is already in the game
      final playerCheckResult = await _checkIfPlayerAlreadyInGame(
        params.gameId,
        params.playerId,
      );
      if (playerCheckResult != null) {
        return Left(playerCheckResult);
      }

      // Verify game is joinable
      if (!game.isJoinable()) {
        return Left(_getJoinabilityFailure(game));
      }

      // Attempt to join the game
      final joinResult = await gamesRepository.joinGame(
        params.gameId,
        params.playerId,
      );

      return joinResult.fold((failure) => Left(failure), (success) async {
        // Refresh game to get updated player count and status
        final updatedGameResult = await gamesRepository.getGame(params.gameId);

        return updatedGameResult.fold((failure) => Left(failure), (
          updatedGame,
        ) async {
          // Check if player is on waitlist by getting their waitlist position
          // If position is not null, they are on waitlist
          final positionResult = await gamesRepository.getWaitlistPosition(
            params.gameId,
            params.playerId,
          );

          final waitlistPosition = positionResult.fold(
            (failure) => null,
            (position) => position,
          );

          final isOnWaitlist = waitlistPosition != null;

          // Send appropriate notifications
          await _sendNotifications(updatedGame, params.playerId, isOnWaitlist);

          return Right(
            JoinGameResult(
              success: true,
              isOnWaitlist: isOnWaitlist,
              position: waitlistPosition,
              message: _getJoinMessage(isOnWaitlist),
            ),
          );
        });
      });
    });
  }

  /// Validates if the player can join this specific game
  Future<Failure?> _validateJoinRequest(Game game, String playerId) async {
    // Check if player is trying to join their own game
    if (game.organizerId == playerId) {
      return GameFailure('You cannot join your own game as a player');
    }

    // Check game timing
    final now = DateTime.now();
    final gameStartTime = game.getScheduledStartDateTime();

    // Don't allow joining if game starts within 15 minutes
    if (gameStartTime.difference(now).inMinutes <= 15) {
      return GameFailure('Cannot join games that start within 15 minutes');
    }

    // Additional validations could include:
    // - Skill level matching requirements
    // - Age restrictions
    // - Gender restrictions (if applicable)
    // - Payment requirements

    return null;
  }

  /// Checks if the player is already part of this game
  Future<Failure?> _checkIfPlayerAlreadyInGame(
    String gameId,
    String playerId,
  ) async {
    final isInGameResult = await gamesRepository.isPlayerInGame(
      gameId,
      playerId,
    );

    return isInGameResult.fold(
      (failure) => null, // If we can't check, proceed anyway
      (isInGame) {
        if (isInGame) {
          return GameFailure('You are already part of this game');
        }
        return null;
      },
    );
  }

  /// Gets the appropriate failure based on why the game isn't joinable
  Failure _getJoinabilityFailure(Game game) {
    switch (game.status) {
      case GameStatus.draft:
        return GameFailure('This game is not yet published');
      case GameStatus.inProgress:
        return GameFailure('This game is already in progress');
      case GameStatus.completed:
        return GameFailure('This game has already been completed');
      case GameStatus.cancelled:
        return GameFailure('This game has been cancelled');
      case GameStatus.upcoming:
        if (!game.isPublic) {
          return GameFailure('This is a private game');
        }
        if (game.isFull() && !game.allowsWaitlist) {
          return GameFailure('This game is full and does not allow waitlist');
        }
        return GameFailure('Unable to join this game at the moment');
    }
  }

  /// Sends appropriate notifications based on join result
  Future<void> _sendNotifications(
    Game game,
    String playerId,
    bool isOnWaitlist,
  ) async {
    try {
      if (isOnWaitlist) {
        // Notify player they are on waitlist
        await _notifyPlayerAddedToWaitlist(game, playerId);

        // Notify organizer of new waitlist member
        await _notifyOrganizerOfWaitlistJoin(game, playerId);
      } else {
        // Notify player they successfully joined
        await _notifyPlayerJoinedGame(game, playerId);

        // Notify organizer of new player
        await _notifyOrganizerOfPlayerJoin(game, playerId);

        // Notify other players of new member (optional)
        await _notifyOtherPlayersOfNewMember(game, playerId);
      }
    } catch (e) {
      // Notification failures shouldn't prevent game joining
      // Log the error but continue
    }
  }

  /// Notification methods (stubs for now - would integrate with notification service)
  Future<void> _notifyPlayerAddedToWaitlist(Game game, String playerId) async {
    // Implementation would send push notification, email, or in-app notification
  }

  Future<void> _notifyPlayerJoinedGame(Game game, String playerId) async {}

  Future<void> _notifyOrganizerOfWaitlistJoin(
    Game game,
    String playerId,
  ) async {}

  Future<void> _notifyOrganizerOfPlayerJoin(Game game, String playerId) async {}

  Future<void> _notifyOtherPlayersOfNewMember(
    Game game,
    String playerId,
  ) async {}

  /// Gets appropriate join message
  String _getJoinMessage(bool isOnWaitlist) {
    if (isOnWaitlist) {
      return 'You have been added to the waitlist. You will be notified if a spot becomes available.';
    } else {
      return 'Successfully joined the game! Check your schedule for details.';
    }
  }
}

class JoinGameParams {
  final String gameId;
  final String playerId;

  JoinGameParams({required this.gameId, required this.playerId});
}

class JoinGameResult {
  final bool success;
  final bool isOnWaitlist;
  final int? position; // Position in waitlist, null if not on waitlist
  final String message;

  JoinGameResult({
    required this.success,
    required this.isOnWaitlist,
    this.position,
    required this.message,
  });
}
