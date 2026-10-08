import 'package:dabbler/core/config/supabase_config.dart';
import 'package:dabbler/core/data/supabase_remote_data_source.dart';
import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';

/// The most game ids one call sends; the RPC caps its input at the same 200.
const int kGamesFollowingMaxIds = 200;

/// Calls a Supabase RPC by name; the seam the tests replace.
typedef GamesFollowingRpcCall =
    Future<dynamic> Function(String fn, Map<String, dynamic> params);

/// How many people the viewer follows are in each game (the card's
/// "N following" note). A count only: no names, no avatars.
abstract class GamesFollowingRepository {
  /// Game id → count, for the games in [gameIds] with a count above zero.
  /// Empty without a call when [gameIds] is empty or nobody is signed in.
  Future<Result<Map<String, int>, Failure>> getFollowingJoined(
    List<String> gameIds,
  );
}

class SupabaseGamesFollowingRepository implements GamesFollowingRepository {
  SupabaseGamesFollowingRepository({
    required GamesFollowingRpcCall rpc,
    required bool Function() signedIn,
  }) : _rpc = rpc,
       _signedIn = signedIn;

  /// Wired to the app's Supabase client.
  factory SupabaseGamesFollowingRepository.fromService(SupabaseService svc) =>
      SupabaseGamesFollowingRepository(
        rpc: (fn, params) => svc.client.rpc(fn, params: params),
        signedIn: () => svc.client.auth.currentUser != null,
      );

  final GamesFollowingRpcCall _rpc;
  final bool Function() _signedIn;

  @override
  Future<Result<Map<String, int>, Failure>> getFollowingJoined(
    List<String> gameIds,
  ) async {
    if (gameIds.isEmpty || !_signedIn()) return const Ok({});
    final List<String> ids = gameIds.length > kGamesFollowingMaxIds
        ? gameIds.sublist(0, kGamesFollowingMaxIds)
        : gameIds;
    return Result.guard(() async {
      final dynamic response = await _rpc(
        SupabaseConfig.gamesFollowingJoinedRpc,
        {'p_game_ids': ids},
      );
      final Map<String, int> out = {};
      if (response is List) {
        for (final dynamic row in response) {
          if (row is! Map) continue;
          final String? id = row['game_id'] as String?;
          final int count = (row['following_count'] as num?)?.toInt() ?? 0;
          if (id != null && count > 0) out[id] = count;
        }
      }
      return out;
    }, (e) => Failure.from(e));
  }
}
