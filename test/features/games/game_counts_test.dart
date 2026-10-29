import 'package:dabbler/features/games/presentation/controllers/game_counts.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final DateTime now = DateTime(2026, 10, 29, 12);
  final DateTime past = now.subtract(const Duration(days: 2));
  final DateTime future = now.add(const Duration(days: 2));

  GameCountRow row(
    String id, {
    DateTime? at,
    bool cancelled = false,
    bool organiser = false,
    GameParticipation? part,
  }) => GameCountRow(
    id: id,
    startAt: at ?? past,
    isCancelled: cancelled,
    isOrganiser: organiser,
    participation: part,
  );

  group('Played', () {
    test('joined and confirmed past games count', () {
      final GameCounts c = computeGameCounts(<GameCountRow>[
        row('a', part: GameParticipation.joined),
        row('b', part: GameParticipation.confirmed),
      ], now: now);
      expect(c.played, 2);
    });

    for (final GameParticipation s in <GameParticipation>[
      GameParticipation.left,
      GameParticipation.removed,
      GameParticipation.waitlisted,
    ]) {
      test('${s.name} does not count as played or upcoming', () {
        final GameCounts c = computeGameCounts(<GameCountRow>[
          row('a', part: s),
          row('b', at: future, part: s),
        ], now: now);
        expect(c.played, 0);
        expect(c.upcoming, 0);
      });
    }

    test('a cancelled game never counts', () {
      final GameCounts c = computeGameCounts(<GameCountRow>[
        row('a', cancelled: true, part: GameParticipation.joined),
        row('b', cancelled: true, organiser: true),
        row(
          'c',
          at: future,
          cancelled: true,
          organiser: true,
          part: GameParticipation.joined,
        ),
      ], now: now);
      expect((c.played, c.organised, c.upcoming), (0, 0, 0));
    });

    test('a future game is not played', () {
      final GameCounts c = computeGameCounts(<GameCountRow>[
        row('a', at: future, part: GameParticipation.joined),
      ], now: now);
      expect(c.played, 0);
    });

    test('a game only organised, not joined, is not played', () {
      final GameCounts c = computeGameCounts(<GameCountRow>[
        row('a', organiser: true),
      ], now: now);
      expect(c.played, 0);
      expect(c.organised, 1);
    });
  });

  group('Organised', () {
    test('counts past and future, not cancelled', () {
      final GameCounts c = computeGameCounts(<GameCountRow>[
        row('a', organiser: true),
        row('b', at: future, organiser: true),
        row('c', at: future, cancelled: true, organiser: true),
      ], now: now);
      expect(c.organised, 2);
    });
  });

  group('Upcoming', () {
    test('joined or organised, future, soonest first', () {
      final GameCounts c = computeGameCounts(<GameCountRow>[
        row(
          'late',
          at: future.add(const Duration(days: 3)),
          part: GameParticipation.joined,
        ),
        row('soon', at: future, organiser: true),
        row('old', part: GameParticipation.joined),
      ], now: now);
      expect(c.upcoming, 2);
      expect(<String>[for (final GameCountRow r in c.upcomingGames) r.id], <String>[
        'soon',
        'late',
      ]);
    });
  });

  group('Dedupe', () {
    test('one game id is one game however many rows carry it', () {
      final GameCounts c = computeGameCounts(<GameCountRow>[
        row('a', organiser: true),
        row('a', part: GameParticipation.joined),
        row('a', part: GameParticipation.joined),
      ], now: now);
      expect((c.played, c.organised), (1, 1));
    });

    test('a left row cannot hide a joined row for the same game', () {
      final GameCounts c = computeGameCounts(<GameCountRow>[
        row('a', part: GameParticipation.joined),
        row('a', part: GameParticipation.left),
      ], now: now);
      expect(c.played, 1);
    });
  });

  test('roster status maps; active is joined', () {
    expect(GameParticipationX.fromRoster('active'), GameParticipation.joined);
    expect(GameParticipationX.fromRoster('left'), GameParticipation.left);
    expect(GameParticipationX.fromRoster('nope'), isNull);
  });
}
