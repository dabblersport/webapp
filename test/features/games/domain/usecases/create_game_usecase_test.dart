import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mockito/mockito.dart';
import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/data/models/games/booking.dart';
import 'package:dabbler/data/models/games/game.dart';
import 'package:dabbler/data/models/games/player.dart';
import 'package:dabbler/features/games/domain/usecases/create_game_usecase.dart';
import '../../../../helpers/mock_factories.dart';

void main() {
  late MockGamesRepository mockRepo;
  late MockBookingsRepository mockBookingsRepo;
  late MockVenuesRepository mockVenuesRepo;
  late CreateGameUseCase useCase;

  final tomorrow = DateTime.now().add(const Duration(days: 1));

  CreateGameParams validParams({
    String title = 'Sunday Pickup',
    String sport = 'football',
    String organizerId = 'organizer-1',
    DateTime? scheduledDate,
    String startTime = '10:00',
    String endTime = '11:30',
    int minPlayers = 2,
    int maxPlayers = 10,
    String skillLevel = 'beginner',
    double pricePerPlayer = 0,
    String? venueId,
  }) {
    return CreateGameParams(
      title: title,
      sport: sport,
      organizerId: organizerId,
      scheduledDate: scheduledDate ?? tomorrow,
      startTime: startTime,
      endTime: endTime,
      minPlayers: minPlayers,
      maxPlayers: maxPlayers,
      skillLevel: skillLevel,
      pricePerPlayer: pricePerPlayer,
      venueId: venueId,
    );
  }

  setUp(() {
    mockRepo = MockGamesRepository();
    mockBookingsRepo = MockBookingsRepository();
    mockVenuesRepo = MockVenuesRepository();
    useCase = CreateGameUseCase(
      gamesRepository: mockRepo,
      venuesRepository: mockVenuesRepo,
      bookingsRepository: mockBookingsRepo,
    );

    // fpdart Either has no default constructor — provide dummies for all
    // return types used by repository methods called in these tests.
    provideDummy<Either<Failure, Game>>(
      Left(const ServerFailure(message: 'dummy')),
    );
    provideDummy<Either<Failure, bool>>(
      Left(const ServerFailure(message: 'dummy')),
    );
    provideDummy<Either<Failure, Booking>>(
      Left(const ServerFailure(message: 'dummy')),
    );
    provideDummy<Either<Failure, List<Game>>>(
      Left(const ServerFailure(message: 'dummy')),
    );
    provideDummy<Either<Failure, List<Player>>>(
      Left(const ServerFailure(message: 'dummy')),
    );
    provideDummy<Either<Failure, Map<String, dynamic>>>(
      Left(const ServerFailure(message: 'dummy')),
    );
    provideDummy<Either<Failure, int?>>(
      Left(const ServerFailure(message: 'dummy')),
    );
  });

  group('CreateGameUseCase — validation', () {
    test('returns GameFailure when title is empty', () async {
      final result = await useCase(validParams(title: ''));

      expect(result.isLeft(), true);
      expect(result.getLeft().toNullable(), isA<GameFailure>());
      verifyZeroInteractions(mockRepo);
    });

    test('returns GameFailure when title is whitespace only', () async {
      final result = await useCase(validParams(title: '   '));

      expect(result.isLeft(), true);
      expect(result.getLeft().toNullable(), isA<GameFailure>());
    });

    test('returns GameFailure when sport is empty', () async {
      final result = await useCase(validParams(sport: ''));

      expect(result.isLeft(), true);
      expect(result.getLeft().toNullable(), isA<GameFailure>());
    });

    test('returns GameFailure when organizerId is empty', () async {
      final result = await useCase(validParams(organizerId: ''));

      expect(result.isLeft(), true);
      expect(result.getLeft().toNullable(), isA<GameFailure>());
    });

    test('returns GameFailure when minPlayers is 0', () async {
      final result = await useCase(validParams(minPlayers: 0));

      expect(result.isLeft(), true);
      expect(result.getLeft().toNullable(), isA<GameFailure>());
    });

    test('returns GameFailure when maxPlayers is 0', () async {
      final result = await useCase(validParams(maxPlayers: 0));

      expect(result.isLeft(), true);
      expect(result.getLeft().toNullable(), isA<GameFailure>());
    });

    test('returns GameFailure when minPlayers exceeds maxPlayers', () async {
      final result = await useCase(validParams(minPlayers: 10, maxPlayers: 5));

      expect(result.isLeft(), true);
      final failure = result.getLeft().toNullable() as GameFailure;
      expect(failure.message, contains('cannot exceed'));
    });

    test('returns GameFailure when scheduledDate is in the past', () async {
      final result = await useCase(
        validParams(
          scheduledDate: DateTime.now().subtract(const Duration(days: 1)),
        ),
      );

      expect(result.isLeft(), true);
      final failure = result.getLeft().toNullable() as GameFailure;
      expect(failure.message, contains('past'));
    });

    test('returns GameFailure when endTime is before startTime', () async {
      final result = await useCase(
        validParams(startTime: '14:00', endTime: '13:00'),
      );

      expect(result.isLeft(), true);
      final failure = result.getLeft().toNullable() as GameFailure;
      expect(failure.message, contains('after start time'));
    });

    test('returns GameFailure when endTime equals startTime', () async {
      final result = await useCase(
        validParams(startTime: '10:00', endTime: '10:00'),
      );

      expect(result.isLeft(), true);
    });

    test('returns GameFailure when duration is less than 30 minutes', () async {
      final result = await useCase(
        validParams(startTime: '10:00', endTime: '10:20'),
      );

      expect(result.isLeft(), true);
      final failure = result.getLeft().toNullable() as GameFailure;
      expect(failure.message, contains('30 minutes'));
    });

    test('returns GameFailure when duration exceeds 8 hours', () async {
      final result = await useCase(
        validParams(startTime: '08:00', endTime: '17:01'),
      );

      expect(result.isLeft(), true);
      final failure = result.getLeft().toNullable() as GameFailure;
      expect(failure.message, contains('8 hours'));
    });

    test('returns GameFailure when pricePerPlayer is negative', () async {
      final result = await useCase(validParams(pricePerPlayer: -1));

      expect(result.isLeft(), true);
      final failure = result.getLeft().toNullable() as GameFailure;
      expect(failure.message, contains('negative'));
    });

    test('returns GameFailure for an invalid skillLevel', () async {
      final result = await useCase(validParams(skillLevel: 'expert'));

      expect(result.isLeft(), true);
      final failure = result.getLeft().toNullable() as GameFailure;
      expect(failure.message, contains('skill level'));
    });
  });

  group('CreateGameUseCase — venue availability', () {
    test('returns GameFailure when venue slot is unavailable', () async {
      when(mockBookingsRepo.checkSlotAvailability(any, any, any, any))
          .thenAnswer((_) async => const Right(false));

      final result = await useCase(validParams(venueId: 'venue-1'));

      expect(result.isLeft(), true);
      expect(result.getLeft().toNullable(), isA<GameFailure>());
      verifyZeroInteractions(mockRepo);
    });

    test('proceeds past availability check when slot is free', () async {
      final game = makeGame();
      when(mockBookingsRepo.checkSlotAvailability(any, any, any, any))
          .thenAnswer((_) async => const Right(true));
      when(mockRepo.createGame(any)).thenAnswer((_) async => Right(game));
      when(mockRepo.joinGame(any, any))
          .thenAnswer((_) async => const Right(true));
      when(mockBookingsRepo.createBooking(any))
          .thenAnswer((_) async => Left(const ServerFailure(message: 'fail')));

      final result = await useCase(validParams(venueId: 'venue-1'));

      expect(result.isRight(), true);
    });
  });

  group('CreateGameUseCase — happy path', () {
    test('returns game on success and auto-joins organizer', () async {
      final game = makeGame();
      when(mockRepo.createGame(any)).thenAnswer((_) async => Right(game));
      when(mockRepo.joinGame(game.id, 'organizer-1'))
          .thenAnswer((_) async => const Right(true));

      final result = await useCase(validParams());

      expect(result.isRight(), true);
      expect(result.getRight().toNullable(), game);
      verify(mockRepo.joinGame(game.id, 'organizer-1')).called(1);
    });

    test('still returns game when booking creation fails (non-fatal)',
        () async {
      final game = makeGame();
      when(mockBookingsRepo.checkSlotAvailability(any, any, any, any))
          .thenAnswer((_) async => const Right(true));
      when(mockRepo.createGame(any)).thenAnswer((_) async => Right(game));
      when(mockRepo.joinGame(any, any))
          .thenAnswer((_) async => const Right(true));
      when(mockBookingsRepo.createBooking(any)).thenAnswer(
        (_) async => Left(const ServerFailure(message: 'booking failed')),
      );

      final result = await useCase(validParams(venueId: 'venue-1'));

      expect(result.isRight(), true);
      expect(result.getRight().toNullable(), game);
    });

    test('forwards ServerFailure when createGame fails', () async {
      when(mockRepo.createGame(any)).thenAnswer(
        (_) async => Left(const ServerFailure(message: 'DB error')),
      );

      final result = await useCase(validParams());

      expect(result.isLeft(), true);
      expect(result.getLeft().toNullable(), isA<ServerFailure>());
    });
  });
}
