import 'package:fpdart/fpdart.dart';
import 'package:dabbler/core/fp/failure.dart';
import '../../../../features/authentication/domain/usecases/usecase.dart';
import 'package:dabbler/data/models/games/game.dart';
import '../repositories/games_repository.dart';
import '../repositories/venues_repository.dart';
import '../repositories/bookings_repository.dart';

class CreateGameUseCase
    extends UseCase<Either<Failure, Game>, CreateGameParams> {
  final GamesRepository gamesRepository;
  final VenuesRepository venuesRepository;
  final BookingsRepository bookingsRepository;

  CreateGameUseCase({
    required this.gamesRepository,
    required this.venuesRepository,
    required this.bookingsRepository,
  });

  @override
  Future<Either<Failure, Game>> call(CreateGameParams params) async {
    // Validate parameters
    final validationResult = await _validateGameParameters(params);
    if (validationResult != null) {
      return Left(validationResult);
    }

    // Check venue availability if venue is specified
    if (params.venueId != null) {
      final venueAvailabilityResult = await _checkVenueAvailability(params);
      if (venueAvailabilityResult != null) {
        return Left(venueAvailabilityResult);
      }
    }

    // Create the game
    final gameData = _buildGameData(params);
    final gameResult = await gamesRepository.createGame(gameData);

    return gameResult.fold((failure) => Left(failure), (game) async {
      // Create initial booking if venue is specified
      if (params.venueId != null) {
        await _createInitialBooking(game, params);
      }

      // Auto-join the organizer to the game
      await gamesRepository.joinGame(game.id, params.organizerId);

      return Right(game);
    });
  }

  /// Validates all game creation parameters
  Future<Failure?> _validateGameParameters(CreateGameParams params) async {
    // Check basic required fields
    if (params.title.trim().isEmpty) {
      return const GameFailure('Game title cannot be empty');
    }

    if (params.sport.trim().isEmpty) {
      return const GameFailure('Sport must be specified');
    }

    if (params.organizerId.trim().isEmpty) {
      return const GameFailure('Organizer ID is required');
    }

    // Validate player limits
    if (params.minPlayers <= 0) {
      return const GameFailure('Minimum players must be greater than 0');
    }

    if (params.maxPlayers <= 0) {
      return const GameFailure('Maximum players must be greater than 0');
    }

    if (params.minPlayers > params.maxPlayers) {
      return const GameFailure('Minimum players cannot exceed maximum players');
    }

    // Validate date is in the future
    final scheduledDateTime = DateTime(
      params.scheduledDate.year,
      params.scheduledDate.month,
      params.scheduledDate.day,
    ).add(_parseTime(params.startTime));

    if (scheduledDateTime.isBefore(DateTime.now())) {
      return const GameFailure('Game cannot be scheduled in the past');
    }

    // Validate time format and logic
    final startTime = _parseTime(params.startTime);
    final endTime = _parseTime(params.endTime);

    if (endTime.inMinutes <= startTime.inMinutes) {
      return const GameFailure('End time must be after start time');
    }

    // Validate game duration (reasonable limits)
    final duration = endTime - startTime;
    if (duration.inMinutes < 30) {
      return const GameFailure('Game duration must be at least 30 minutes');
    }

    if (duration.inHours > 8) {
      return const GameFailure('Game duration cannot exceed 8 hours');
    }

    // Validate price
    if (params.pricePerPlayer < 0) {
      return const GameFailure('Price per player cannot be negative');
    }

    // Validate skill level
    const validSkillLevels = ['beginner', 'intermediate', 'advanced', 'mixed'];
    if (!validSkillLevels.contains(params.skillLevel.toLowerCase())) {
      return const GameFailure(
        'Invalid skill level. Must be: beginner, intermediate, advanced, or mixed',
      );
    }

    return null;
  }

  /// Checks if the venue is available for the specified time slot
  Future<Failure?> _checkVenueAvailability(CreateGameParams params) async {
    final availability = await bookingsRepository.checkSlotAvailability(
      params.venueId!,
      params.scheduledDate,
      params.startTime,
      params.endTime,
    );

    return availability.fold((failure) => failure, (isAvailable) {
      if (!isAvailable) {
        return const GameFailure(
          'Selected venue is not available for the chosen time slot',
        );
      }
      return null;
    });
  }

  /// Creates initial booking for the game if venue is specified
  Future<void> _createInitialBooking(Game game, CreateGameParams params) async {
    if (params.venueId == null) return;

    final bookingData = {
      'gameId': game.id,
      'venueId': params.venueId,
      'userId': params.organizerId,
      'date': params.scheduledDate.toIso8601String(),
      'startTime': params.startTime,
      'endTime': params.endTime,
      'sport': params.sport,
      'totalCost': params.pricePerPlayer * params.maxPlayers,
      'status': 'confirmed',
      'bookingType': 'game_session',
    };

    // Note: We don't handle the result here as booking failure
    // shouldn't prevent game creation, but this could be improved
    await bookingsRepository.createBooking(bookingData);
  }

  /// Builds the game data map for creation
  Map<String, dynamic> _buildGameData(CreateGameParams params) {
    return {
      'title': params.title.trim(),
      'description': params.description?.trim() ?? '',
      'sport': params.sport.toLowerCase(),
      'venueId': params.venueId,
      'scheduledDate': params.scheduledDate.toIso8601String(),
      'startTime': params.startTime,
      'endTime': params.endTime,
      'minPlayers': params.minPlayers,
      'maxPlayers': params.maxPlayers,
      'currentPlayers': 0, // Will be 1 after auto-joining organizer
      'organizerId': params.organizerId,
      'skillLevel': params.skillLevel.toLowerCase(),
      'pricePerPlayer': params.pricePerPlayer,
      'status': 'upcoming',
      'isPublic': params.isPublic,
      'allowsWaitlist': params.allowsWaitlist,
      'checkInEnabled': params.checkInEnabled,
      'cancellationDeadline': params.cancellationDeadline?.toIso8601String(),
      'createdAt': DateTime.now().toIso8601String(),
      'updatedAt': DateTime.now().toIso8601String(),
    };
  }

  /// Parses time string (HH:mm) to Duration
  Duration _parseTime(String timeStr) {
    final parts = timeStr.split(':');
    if (parts.length != 2) {
      throw const GameFailure('Invalid time format. Use HH:mm');
    }

    final hours = int.tryParse(parts[0]);
    final minutes = int.tryParse(parts[1]);

    if (hours == null ||
        minutes == null ||
        hours < 0 ||
        hours > 23 ||
        minutes < 0 ||
        minutes > 59) {
      throw const GameFailure(
        'Invalid time format. Use HH:mm (24-hour format)',
      );
    }

    return Duration(hours: hours, minutes: minutes);
  }
}

class CreateGameParams {
  final String title;
  final String? description;
  final String sport;
  final String? venueId;
  final DateTime scheduledDate;
  final String startTime; // Format: "HH:mm"
  final String endTime; // Format: "HH:mm"
  final int minPlayers;
  final int maxPlayers;
  final String organizerId;
  final String skillLevel; // beginner, intermediate, advanced, mixed
  final double pricePerPlayer;
  final bool isPublic;
  final bool allowsWaitlist;
  final bool checkInEnabled;
  final DateTime? cancellationDeadline;

  CreateGameParams({
    required this.title,
    this.description,
    required this.sport,
    this.venueId,
    required this.scheduledDate,
    required this.startTime,
    required this.endTime,
    required this.minPlayers,
    required this.maxPlayers,
    required this.organizerId,
    required this.skillLevel,
    required this.pricePerPlayer,
    this.isPublic = true,
    this.allowsWaitlist = true,
    this.checkInEnabled = false,
    this.cancellationDeadline,
  });
}

// Game-specific failures
class GameFailure extends Failure {
  const GameFailure(String message) : super(message: message);
}

class VenueUnavailableFailure extends GameFailure {
  const VenueUnavailableFailure([
    super.message = 'Venue is not available for the selected time',
  ]);
}

class InvalidGameParametersFailure extends GameFailure {
  const InvalidGameParametersFailure([
    super.message = 'Invalid game parameters provided',
  ]);
}
