import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mockito/mockito.dart';
import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/data/models/games/game.dart';
import 'package:dabbler/data/models/games/player.dart';
import 'package:dabbler/features/games/domain/usecases/join_game_usecase.dart';
import '../../../../helpers/mock_factories.dart';

void main() {
  late MockGamesRepository mockRepo;
  late JoinGameUseCase useCase;

  setUp(() {
    mockRepo = MockGamesRepository();
    useCase = JoinGameUseCase(gamesRepository: mockRepo);

    // fpdart Either has no default constructor — provide dummies for all
    // return types used by GamesRepository methods called in these tests.
    provideDummy<Either<Failure, Game>>(
      Left(const ServerFailure(message: 'dummy')),
    );
    provideDummy<Either<Failure, bool>>(
      Left(const ServerFailure(message: 'dummy')),
    );
    provideDummy<Either<Failure, int?>>(
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
  });

  void stubHappyPath(Game game) {
    when(mockRepo.getGame(game.id)).thenAnswer((_) async => Right(game));
    when(mockRepo.isPlayerInGame(any, any))
        .thenAnswer((_) async => const Right(false));
    when(mockRepo.joinGame(any, any))
        .thenAnswer((_) async => const Right(true));
    when(mockRepo.getWaitlistPosition(any, any))
        .thenAnswer((_) async => const Right(null));
  }

  group('JoinGameUseCase — parameter validation', () {
    test('returns GameFailure when gameId is empty', () async {
      final result = await useCase(
        JoinGameParams(gameId: '', playerId: 'player-1'),
      );

      expect(result.isLeft(), true);
      expect(result.getLeft().toNullable(), isA<GameFailure>());
      verifyZeroInteractions(mockRepo);
    });

    test('returns GameFailure when playerId is empty', () async {
      final result = await useCase(
        JoinGameParams(gameId: 'game-1', playerId: ''),
      );

      expect(result.isLeft(), true);
      expect(result.getLeft().toNullable(), isA<GameFailure>());
      verifyZeroInteractions(mockRepo);
    });

    test('returns GameFailure when both ids are whitespace only', () async {
      final result = await useCase(
        JoinGameParams(gameId: '   ', playerId: '   '),
      );

      expect(result.isLeft(), true);
      verifyZeroInteractions(mockRepo);
    });
  });

  group('JoinGameUseCase — own game check', () {
    test('returns GameFailure when player tries to join their own game',
        () async {
      final game = makeGame(id: 'game-1', organizerId: 'player-1');
      when(mockRepo.getGame('game-1')).thenAnswer((_) async => Right(game));

      final result = await useCase(
        JoinGameParams(gameId: 'game-1', playerId: 'player-1'),
      );

      expect(result.isLeft(), true);
      final failure = result.getLeft().toNullable() as GameFailure;
      expect(failure.message, contains('own game'));
    });
  });

  group('JoinGameUseCase — timing restriction', () {
    test('returns GameFailure when game starts within 15 minutes', () async {
      final soon = DateTime.now().add(const Duration(minutes: 5));
      final game = makeGame(
        id: 'game-1',
        organizerId: 'organizer-1',
        scheduledDate: soon,
        startTime:
            '${soon.hour.toString().padLeft(2, '0')}:${soon.minute.toString().padLeft(2, '0')}',
        endTime:
            '${(soon.hour + 1).toString().padLeft(2, '0')}:${soon.minute.toString().padLeft(2, '0')}',
      );
      when(mockRepo.getGame('game-1')).thenAnswer((_) async => Right(game));

      final result = await useCase(
        JoinGameParams(gameId: 'game-1', playerId: 'player-1'),
      );

      expect(result.isLeft(), true);
      final failure = result.getLeft().toNullable() as GameFailure;
      expect(failure.message, contains('15 minutes'));
    });
  });

  group('JoinGameUseCase — already in game', () {
    test('returns GameFailure when player is already in the game', () async {
      final game = makeGame(id: 'game-1', organizerId: 'organizer-1');
      when(mockRepo.getGame('game-1')).thenAnswer((_) async => Right(game));
      when(mockRepo.isPlayerInGame('game-1', 'player-1'))
          .thenAnswer((_) async => const Right(true));

      final result = await useCase(
        JoinGameParams(gameId: 'game-1', playerId: 'player-1'),
      );

      expect(result.isLeft(), true);
      final failure = result.getLeft().toNullable() as GameFailure;
      expect(failure.message, contains('already part'));
    });
  });

  group('JoinGameUseCase — game not joinable', () {
    test('returns GameFailure when game is cancelled', () async {
      final game = makeGame(
        id: 'game-1',
        organizerId: 'organizer-1',
        status: GameStatus.cancelled,
      );
      when(mockRepo.getGame('game-1')).thenAnswer((_) async => Right(game));
      when(mockRepo.isPlayerInGame(any, any))
          .thenAnswer((_) async => const Right(false));

      final result = await useCase(
        JoinGameParams(gameId: 'game-1', playerId: 'player-1'),
      );

      expect(result.isLeft(), true);
      expect(result.getLeft().toNullable(), isA<GameFailure>());
    });

    test('returns GameFailure when game is full with no waitlist', () async {
      final game = makeGame(
        id: 'game-1',
        organizerId: 'organizer-1',
        maxPlayers: 5,
        currentPlayers: 5,
        allowsWaitlist: false,
      );
      when(mockRepo.getGame('game-1')).thenAnswer((_) async => Right(game));
      when(mockRepo.isPlayerInGame(any, any))
          .thenAnswer((_) async => const Right(false));

      final result = await useCase(
        JoinGameParams(gameId: 'game-1', playerId: 'player-1'),
      );

      expect(result.isLeft(), true);
    });
  });

  group('JoinGameUseCase — happy path', () {
    test('returns success with isOnWaitlist=false when a spot is available',
        () async {
      final game = makeGame(
        id: 'game-1',
        organizerId: 'organizer-1',
        maxPlayers: 10,
        currentPlayers: 5,
      );
      stubHappyPath(game);

      final result = await useCase(
        JoinGameParams(gameId: 'game-1', playerId: 'player-1'),
      );

      expect(result.isRight(), true);
      final joinResult = result.getRight().toNullable()!;
      expect(joinResult.success, true);
      expect(joinResult.isOnWaitlist, false);
      expect(joinResult.position, null);
    });

    test('returns success with isOnWaitlist=true when game is full but waitlist is open',
        () async {
      final game = makeGame(
        id: 'game-1',
        organizerId: 'organizer-1',
        maxPlayers: 5,
        currentPlayers: 5,
        allowsWaitlist: true,
      );
      when(mockRepo.getGame('game-1')).thenAnswer((_) async => Right(game));
      when(mockRepo.isPlayerInGame(any, any))
          .thenAnswer((_) async => const Right(false));
      when(mockRepo.joinGame(any, any))
          .thenAnswer((_) async => const Right(true));
      when(mockRepo.getWaitlistPosition(any, any))
          .thenAnswer((_) async => const Right(1));

      final result = await useCase(
        JoinGameParams(gameId: 'game-1', playerId: 'player-1'),
      );

      expect(result.isRight(), true);
      final joinResult = result.getRight().toNullable()!;
      expect(joinResult.success, true);
      expect(joinResult.isOnWaitlist, true);
      expect(joinResult.position, 1);
    });

    test('forwards NetworkFailure when getGame fails', () async {
      when(mockRepo.getGame(any)).thenAnswer(
        (_) async => Left(const NetworkFailure(message: 'offline')),
      );

      final result = await useCase(
        JoinGameParams(gameId: 'game-1', playerId: 'player-1'),
      );

      expect(result.isLeft(), true);
      expect(result.getLeft().toNullable(), isA<NetworkFailure>());
    });
  });
}
