/// How a user stands on a game's roster. Only [joined] and [confirmed] count
/// as taking part; a user who left, was removed or sits on the waitlist does
/// not.
enum GameParticipation { joined, confirmed, left, removed, waitlisted }

extension GameParticipationX on GameParticipation {
  bool get takesPart =>
      this == GameParticipation.joined || this == GameParticipation.confirmed;

  /// The roster's stored status: `active` is a joined seat.
  static GameParticipation? fromRoster(String? status) => switch (status) {
    'active' || 'joined' => GameParticipation.joined,
    'confirmed' => GameParticipation.confirmed,
    'left' => GameParticipation.left,
    'removed' => GameParticipation.removed,
    'waitlisted' || 'waitlist' => GameParticipation.waitlisted,
    _ => null,
  };
}

/// One game as the counts see it.
class GameCountRow {
  const GameCountRow({
    required this.id,
    required this.startAt,
    required this.isCancelled,
    this.isOrganiser = false,
    this.participation,
    this.title,
  });

  final String id;

  /// The game's title, for rows that list it.
  final String? title;
  final DateTime startAt;
  final bool isCancelled;

  /// The user created the game.
  final bool isOrganiser;

  /// The user's roster standing; null when they hold no seat.
  final GameParticipation? participation;
}

/// The three Contributor profile figures. Each is a count of distinct game
/// ids; meetups are not games and are not counted.
class GameCounts {
  const GameCounts({
    required this.played,
    required this.organised,
    required this.upcoming,
    this.upcomingGames = const <GameCountRow>[],
    this.organisedGames = const <GameCountRow>[],
  });

  final int played;
  final int organised;
  final int upcoming;

  /// The upcoming games, soonest first.
  final List<GameCountRow> upcomingGames;

  /// The organised games, soonest first.
  final List<GameCountRow> organisedGames;
}

/// Played: distinct games the user took part in (joined or confirmed), not
/// cancelled, already started. Organised: distinct games the user created,
/// not cancelled, past and future. Upcoming: distinct games joined or
/// organised, not cancelled, not yet started, soonest first.
GameCounts computeGameCounts(Iterable<GameCountRow> rows, {DateTime? now}) {
  final DateTime at = now ?? DateTime.now();
  final Map<String, GameCountRow> byId = <String, GameCountRow>{};
  for (final GameCountRow r in rows) {
    if (r.isCancelled) continue;
    final GameCountRow? seen = byId[r.id];
    byId[r.id] = seen == null
        ? r
        : GameCountRow(
            id: r.id,
            title: seen.title ?? r.title,
            startAt: seen.startAt,
            isCancelled: false,
            isOrganiser: seen.isOrganiser || r.isOrganiser,
            participation: (seen.participation?.takesPart ?? false)
                ? seen.participation
                : r.participation ?? seen.participation,
          );
  }
  int played = 0;
  final List<GameCountRow> organised = <GameCountRow>[];
  final List<GameCountRow> upcoming = <GameCountRow>[];
  for (final GameCountRow r in byId.values) {
    final bool takesPart = r.participation?.takesPart ?? false;
    final bool future = r.startAt.isAfter(at);
    if (takesPart && !future) played++;
    if (r.isOrganiser) organised.add(r);
    if ((takesPart || r.isOrganiser) && future) upcoming.add(r);
  }
  int byStart(GameCountRow a, GameCountRow b) => a.startAt.compareTo(b.startAt);
  organised.sort(byStart);
  upcoming.sort(byStart);
  return GameCounts(
    played: played,
    organised: organised.length,
    upcoming: upcoming.length,
    upcomingGames: upcoming,
    organisedGames: organised,
  );
}
