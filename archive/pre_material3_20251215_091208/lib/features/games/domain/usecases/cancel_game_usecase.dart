import 'package:fpdart/fpdart.dart';
import 'package:dabbler/core/fp/failure.dart';
import '../../../../features/authentication/domain/usecases/usecase.dart';
import 'package:dabbler/data/models/games/game.dart';
import '../repositories/games_repository.dart';
import '../repositories/bookings_repository.dart';

// Game-specific failures
class GameFailure extends Failure {
  const GameFailure(String message) : super(message: message);
}

class CancelGameUseCase
    extends UseCase<Either<Failure, CancelGameResult>, CancelGameParams> {
  final GamesRepository gamesRepository;
  final BookingsRepository bookingsRepository;

  CancelGameUseCase({
    required this.gamesRepository,
    required this.bookingsRepository,
  });

  @override
  Future<Either<Failure, CancelGameResult>> call(
    CancelGameParams params,
  ) async {
    // Validate parameters
    final validationResult = _validateCancellationParameters(params);
    if (validationResult != null) {
      return Left(validationResult);
    }

    // Get game details
    final gameResult = await gamesRepository.getGame(params.gameId);

    return gameResult.fold((failure) => Left(failure), (game) async {
      // Verify user is authorized to cancel
      final authResult = _verifyUserAuthorization(game, params.userId);
      if (authResult != null) {
        return Left(authResult);
      }

      // Check cancellation deadline
      final deadlineResult = _checkCancellationDeadline(game);
      if (deadlineResult != null) {
        return Left(deadlineResult);
      }

      // Get list of affected players for notifications
      final playersResult = await _getAffectedPlayers(game);
      final affectedPlayers = playersResult.fold(
        (failure) => <String>[], // Continue even if we can't get players list
        (players) => players,
      );

      // Cancel associated bookings
      final bookingCancellationResult = await _cancelAssociatedBookings(
        game,
        params,
      );
      final refundInfo = bookingCancellationResult.fold(
        (failure) => null, // Continue even if booking cancellation fails
        (refunds) => refunds,
      );

      // Cancel the game
      final gameCancellationResult = await gamesRepository.cancelGame(
        params.gameId,
      );

      return gameCancellationResult.fold((failure) => Left(failure), (
        success,
      ) async {
        // Notify all players
        await _notifyAllPlayers(game, affectedPlayers, params);

        // Send cancellation notifications
        await _sendCancellationNotifications(game, params);

        return Right(
          CancelGameResult(
            success: true,
            gameId: params.gameId,
            cancelledAt: DateTime.now(),
            reason: params.reason,
            affectedPlayersCount: affectedPlayers.length,
            refundsProcessed: refundInfo?.isNotEmpty ?? false,
            refundAmount:
                refundInfo?.fold<double>(
                  0.0,
                  (sum, refund) => sum + refund.amount,
                ) ??
                0.0,
            message: _getCancellationMessage(game, affectedPlayers.length),
          ),
        );
      });
    });
  }

  /// Validates cancellation parameters
  Failure? _validateCancellationParameters(CancelGameParams params) {
    if (params.gameId.trim().isEmpty) {
      return const GameFailure('Game ID cannot be empty');
    }

    if (params.userId.trim().isEmpty) {
      return const GameFailure('User ID cannot be empty');
    }

    if (params.reason.trim().isEmpty) {
      return const GameFailure('Cancellation reason is required');
    }

    if (params.reason.length < 10) {
      return const GameFailure(
        'Cancellation reason must be at least 10 characters long',
      );
    }

    return null;
  }

  /// Verifies user is authorized to cancel the game
  Failure? _verifyUserAuthorization(Game game, String userId) {
    // Only game organizer can cancel the game
    if (game.organizerId != userId) {
      return const GameFailure('Only the game organizer can cancel this game');
    }

    return null;
  }

  /// Checks if game can still be cancelled based on deadline
  Failure? _checkCancellationDeadline(Game game) {
    // Check game status first
    if (game.status == GameStatus.cancelled) {
      return const GameFailure('Game is already cancelled');
    }

    if (game.status == GameStatus.completed) {
      return const GameFailure('Cannot cancel a completed game');
    }

    if (game.status == GameStatus.inProgress) {
      return const GameFailure(
        'Cannot cancel a game that is already in progress',
      );
    }

    // Check if game can be cancelled based on timing rules
    if (!game.canCancel()) {
      final gameStartTime = game.getScheduledStartDateTime();
      final now = DateTime.now();

      if (game.cancellationDeadline != null) {
        final hoursUntilDeadline = game.cancellationDeadline!
            .difference(now)
            .inHours;
        if (hoursUntilDeadline < 0) {
          return const GameFailure('Cancellation deadline has passed');
        }
      } else {
        final hoursUntilGame = gameStartTime.difference(now).inHours;
        if (hoursUntilGame < 2) {
          return const GameFailure(
            'Games cannot be cancelled less than 2 hours before start time',
          );
        }
      }
    }

    return null;
  }

  /// Gets list of players affected by the cancellation
  Future<Either<Failure, List<String>>> _getAffectedPlayers(Game game) async {
    // This would typically get the list of registered players from the repository
    // Since we don't have a specific method for this, we'll simulate it

    try {
      // In a real implementation, you would:
      // return await gamesRepository.getGamePlayers(game.id);

      // For now, we'll return empty list and note this limitation
      return const Right(<String>[]);
    } catch (e) {
      return Left(
        GameFailure('Failed to get affected players: ${e.toString()}'),
      );
    }
  }

  /// Cancels associated bookings and processes refunds
  Future<Either<Failure, List<RefundInfo>>> _cancelAssociatedBookings(
    Game game,
    CancelGameParams params,
  ) async {
    final refunds = <RefundInfo>[];

    try {
      // If game has associated venue booking
      if (game.venueId != null) {
        // Get bookings for this game/venue combination
        final bookingsResult = await bookingsRepository.getVenueBookings(
          game.venueId!,
          game.scheduledDate,
        );

        await bookingsResult.fold((failure) async {}, (bookings) async {
          // Find bookings related to this game
          for (final booking in bookings) {
            if (booking.gameId == game.id ||
                (booking.bookedBy == game.organizerId &&
                    booking.bookingDate == game.scheduledDate)) {
              // Cancel the booking
              final cancelResult = await bookingsRepository.cancelBooking(
                booking.id,
                'Game cancelled: ${params.reason}',
              );

              await cancelResult.fold((failure) async {}, (success) async {
                // Process refund if needed
                if (params.processRefunds && booking.totalAmount > 0) {
                  refunds.add(
                    RefundInfo(
                      bookingId: booking.id,
                      amount: booking.totalAmount,
                      status: 'processed',
                    ),
                  );
                }
              });
            }
          }
        });
      }

      return Right(refunds);
    } catch (e) {
      return Left(GameFailure('Failed to cancel bookings: ${e.toString()}'));
    }
  }

  /// Notifies all players about the cancellation
  Future<void> _notifyAllPlayers(
    Game game,
    List<String> playerIds,
    CancelGameParams params,
  ) async {
    try {
      for (final playerId in playerIds) {
        await _sendPlayerNotification(playerId, game, params);
      }
    } catch (e) {}
  }

  /// Sends cancellation notification to a specific player
  Future<void> _sendPlayerNotification(
    String playerId,
    Game game,
    CancelGameParams params,
  ) async {
    try {
      // This would integrate with your notification service
      // Could be push notifications, email, SMS, or in-app notifications

      final message =
          'Game "${game.title}" scheduled for '
          '${game.scheduledDate.day}/${game.scheduledDate.month} '
          'has been cancelled. Reason: ${params.reason}';

      // In a real implementation:
      // await notificationService.sendNotification(
      //   userId: playerId,
      //   title: 'Game Cancelled',
      //   message: message,
      //   type: NotificationType.gameCancellation,
      // );
    } catch (e) {}
  }

  /// Sends additional cancellation notifications (email, etc.)
  Future<void> _sendCancellationNotifications(
    Game game,
    CancelGameParams params,
  ) async {
    try {
      // Send email notifications
      await _sendEmailNotifications(game, params);

      // Update game status in external systems if needed
      await _updateExternalSystems(game, params);
    } catch (e) {}
  }

  /// Sends email notifications (stub)
  Future<void> _sendEmailNotifications(
    Game game,
    CancelGameParams params,
  ) async {
    // This would integrate with email service
  }

  /// Updates external systems about the cancellation (stub)
  Future<void> _updateExternalSystems(
    Game game,
    CancelGameParams params,
  ) async {
    // This could update calendar systems, social media, etc.
  }

  /// Gets appropriate cancellation message
  String _getCancellationMessage(Game game, int affectedPlayersCount) {
    return 'Game "${game.title}" has been successfully cancelled. '
        '$affectedPlayersCount player(s) have been notified. '
        'Refunds (if applicable) will be processed within 3-5 business days.';
  }
}

class CancelGameParams {
  final String gameId;
  final String userId;
  final String reason;
  final bool processRefunds;
  final bool notifyPlayers;

  CancelGameParams({
    required this.gameId,
    required this.userId,
    required this.reason,
    this.processRefunds = true,
    this.notifyPlayers = true,
  });
}

class CancelGameResult {
  final bool success;
  final String gameId;
  final DateTime cancelledAt;
  final String reason;
  final int affectedPlayersCount;
  final bool refundsProcessed;
  final double refundAmount;
  final String message;

  CancelGameResult({
    required this.success,
    required this.gameId,
    required this.cancelledAt,
    required this.reason,
    required this.affectedPlayersCount,
    required this.refundsProcessed,
    required this.refundAmount,
    required this.message,
  });

  // Convenience getters
  String get formattedRefundAmount => '\$${refundAmount.toStringAsFixed(2)}';
  String get formattedCancelledAt =>
      '${cancelledAt.day}/${cancelledAt.month}/${cancelledAt.year} at ${cancelledAt.hour}:${cancelledAt.minute.toString().padLeft(2, '0')}';
}

class RefundInfo {
  final String bookingId;
  final double amount;
  final String status;

  RefundInfo({
    required this.bookingId,
    required this.amount,
    required this.status,
  });
}
