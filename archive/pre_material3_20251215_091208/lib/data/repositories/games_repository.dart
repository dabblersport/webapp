import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/data/models/games/game.dart';

abstract class GamesRepository {
  /// Create a game (hosted by current user). RLS: games_modify_owner (host_user_id = auth.uid()).
  Future<Result<Game, Failure>> createGame({
    required String gameType,
    required String sport,
    String? title,
    required String hostProfileId,
    String? venueSpaceId,
    required DateTime startAt,
    required DateTime endAt,
    required int capacity,
    required String listingVisibility,
    required String joinPolicy,
    bool allowSpectators = false,
    int? minSkill,
    int? maxSkill,
    Map<String, dynamic> rules = const {},
    String? squadId,
  });

  /// Update mutable fields. RLS: games_modify_owner.
  Future<Result<void, Failure>> updateGame(
    String gameId, {
    String? title,
    String? venueSpaceId,
    DateTime? startAt,
    DateTime? endAt,
    int? capacity,
    String? listingVisibility,
    String? joinPolicy,
    bool? allowSpectators,
    int? minSkill,
    int? maxSkill,
    Map<String, dynamic>? rules,
  });

  /// Cancel a game. RLS: games_modify_owner.
  Future<Result<void, Failure>> cancelGame(String gameId, {String? reason});

  /// Get by id. RLS: games_select (owner/admin or can_view_with_scope()).
  Future<Result<Game, Failure>> getGameById(String gameId);

  /// Discoverable list (public scope). RLS: games_select.
  Future<Result<List<Game>, Failure>> listDiscoverableGames({
    String? sport,
    DateTime? from, // start_at >= from
    DateTime? to, // end_at   <= to
    String? visibility, // e.g., 'public', 'invite', 'link'
    bool includeCancelled = false,
    String? q, // title contains (simple ILIKE)
    int limit = 50,
    int offset = 0,
  });

  /// My hosted games. RLS: games_select (owner scope).
  Future<Result<List<Game>, Failure>> listMyHostedGames({
    DateTime? from,
    DateTime? to,
    bool includeCancelled = false,
    int limit = 50,
    int offset = 0,
  });

  /// Realtime: watch a single game row by id.
  Stream<Result<Game, Failure>> watchGame(String gameId);
}
