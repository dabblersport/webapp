import 'package:flutter_test/flutter_test.dart';
import 'package:dabbler/data/models/games/game.dart';
import '../../../../helpers/mock_factories.dart';

void main() {
  group('Game.isJoinable()', () {
    test('returns true for an upcoming public game with available spots', () {
      final game = makeGame();
      expect(game.isJoinable(), true);
    });

    test('returns false when status is cancelled', () {
      final game = makeGame(status: GameStatus.cancelled);
      expect(game.isJoinable(), false);
    });

    test('returns false when status is completed', () {
      final game = makeGame(status: GameStatus.completed);
      expect(game.isJoinable(), false);
    });

    test('returns false when status is inProgress', () {
      final game = makeGame(status: GameStatus.inProgress);
      expect(game.isJoinable(), false);
    });

    test('returns false when game is not public', () {
      final game = makeGame(isPublic: false);
      expect(game.isJoinable(), false);
    });

    test('returns false when game is in the past', () {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final game = makeGame(scheduledDate: yesterday);
      expect(game.isJoinable(), false);
    });

    test('returns true when full but waitlist is allowed', () {
      final game = makeGame(
        maxPlayers: 5,
        currentPlayers: 5,
        allowsWaitlist: true,
      );
      expect(game.isJoinable(), true);
    });

    test('returns false when full and waitlist is not allowed', () {
      final game = makeGame(
        maxPlayers: 5,
        currentPlayers: 5,
        allowsWaitlist: false,
      );
      expect(game.isJoinable(), false);
    });
  });

  group('Game.isFull()', () {
    test('returns false when currentPlayers < maxPlayers', () {
      final game = makeGame(maxPlayers: 10, currentPlayers: 5);
      expect(game.isFull(), false);
    });

    test('returns true when currentPlayers == maxPlayers', () {
      final game = makeGame(maxPlayers: 10, currentPlayers: 10);
      expect(game.isFull(), true);
    });

    test('returns true when currentPlayers > maxPlayers', () {
      final game = makeGame(maxPlayers: 10, currentPlayers: 11);
      expect(game.isFull(), true);
    });

    test('returns false when game is empty', () {
      final game = makeGame(maxPlayers: 10, currentPlayers: 0);
      expect(game.isFull(), false);
    });
  });

  group('Game.canCancel()', () {
    test('returns false when game is already cancelled', () {
      final game = makeGame(status: GameStatus.cancelled);
      expect(game.canCancel(), false);
    });

    test('returns false when game is completed', () {
      final game = makeGame(status: GameStatus.completed);
      expect(game.canCancel(), false);
    });

    test('returns true when before custom cancellationDeadline', () {
      final deadline = DateTime.now().add(const Duration(hours: 2));
      final game = makeGame(cancellationDeadline: deadline);
      expect(game.canCancel(), true);
    });

    test('returns false when past custom cancellationDeadline', () {
      final deadline = DateTime.now().subtract(const Duration(minutes: 1));
      final game = makeGame(cancellationDeadline: deadline);
      expect(game.canCancel(), false);
    });

    test('returns true by default when more than 2 hours before start', () {
      // scheduledDate is tomorrow at 10:00 by default — well over 2h away
      final game = makeGame();
      expect(game.canCancel(), true);
    });
  });

  group('Game.getDurationMinutes()', () {
    test('returns 60 for a 1-hour game', () {
      final game = makeGame(startTime: '10:00', endTime: '11:00');
      expect(game.getDurationMinutes(), 60);
    });

    test('returns 90 for a 90-minute game', () {
      final game = makeGame(startTime: '09:00', endTime: '10:30');
      expect(game.getDurationMinutes(), 90);
    });

    test('returns 120 for a 2-hour game', () {
      final game = makeGame(startTime: '14:00', endTime: '16:00');
      expect(game.getDurationMinutes(), 120);
    });
  });

  group('Game.timeUntilStart()', () {
    test('returns Duration.zero when game is in the past', () {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final game = makeGame(scheduledDate: yesterday);
      expect(game.timeUntilStart(), Duration.zero);
    });

    test('returns positive duration for a future game', () {
      final game = makeGame(); // defaults to tomorrow
      expect(game.timeUntilStart().inSeconds, greaterThan(0));
    });
  });

  group('Game.isToday()', () {
    test('returns true when scheduledDate is today', () {
      final today = DateTime.now();
      final game = makeGame(scheduledDate: today);
      expect(game.isToday(), true);
    });

    test('returns false when scheduledDate is tomorrow', () {
      final game = makeGame(); // defaults to tomorrow
      expect(game.isToday(), false);
    });
  });
}
