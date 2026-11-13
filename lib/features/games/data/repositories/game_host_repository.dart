import 'package:dabbler/core/config/supabase_config.dart';
import 'package:dabbler/core/data/supabase_client.dart';
import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Host-only actions on one game, both checked by the server (`not_host`).
///
/// * KAN-937: `rpc_cancel_game(p_game_id uuid, p_reason text)` — the reason
///   is optional, but the argument is always sent (the function has no
///   default for it).
/// * KAN-939: `rpc_mint_join_link(p_game_id, p_expires_at, p_max_uses)`
///   returns the token a link-policy game's share URL carries.
class GameHostRepository {
  GameHostRepository(this._db);
  final SupabaseClient _db;

  Future<Result<void, Failure>> cancelGame(String gameId, {String? reason}) =>
      Result.guard(() async {
        final trimmed = reason?.trim();
        await _db.rpc(
          SupabaseConfig.rpcCancelGameFn,
          params: {
            'p_game_id': gameId,
            'p_reason': (trimmed == null || trimmed.isEmpty) ? null : trimmed,
          },
        );
      }, Failure.from);

  Future<Result<String, Failure>> mintJoinLink(String gameId) =>
      Result.guard(() async {
        final res = await _db.rpc(
          SupabaseConfig.rpcMintJoinLinkFn,
          params: {'p_game_id': gameId},
        );
        final token = res?.toString() ?? '';
        if (token.isEmpty) throw StateError('empty_token');
        return token;
      }, Failure.from);
}

final gameHostRepositoryProvider = Provider<GameHostRepository>(
  (ref) => GameHostRepository(ref.watch(supabaseClientProvider)),
);
