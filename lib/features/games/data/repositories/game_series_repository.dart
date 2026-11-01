import 'package:dabbler/core/config/supabase_config.dart';
import 'package:dabbler/core/data/supabase_client.dart';
import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// KAN-698: what `rpc_edit_game_series_future` did, from its JSON.
class SeriesFutureEditOutcome {
  const SeriesFutureEditOutcome({
    required this.updated,
    required this.keptWithPlayers,
    required this.created,
  });

  final int updated;

  /// Joined games that were not rebuilt; they keep their old details.
  final int keptWithPlayers;
  final int created;

  factory SeriesFutureEditOutcome.fromJson(Map<String, dynamic> j) =>
      SeriesFutureEditOutcome(
        updated: (j['updated'] as num?)?.toInt() ?? 0,
        keptWithPlayers: (j['kept_with_players'] as num?)?.toInt() ?? 0,
        created: (j['created'] as num?)?.toInt() ?? 0,
      );
}

/// KAN-698: what `rpc_cancel_game_series` did, from its JSON.
class SeriesCancelOutcome {
  const SeriesCancelOutcome({
    required this.cancelled,
    required this.playerNotifications,
    required this.pastKept,
  });

  final int cancelled;
  final int playerNotifications;
  final int pastKept;

  factory SeriesCancelOutcome.fromJson(Map<String, dynamic> j) =>
      SeriesCancelOutcome(
        cancelled: (j['cancelled'] as num?)?.toInt() ?? 0,
        playerNotifications: (j['player_notifications'] as num?)?.toInt() ?? 0,
        pastKept: (j['past_kept'] as num?)?.toInt() ?? 0,
      );
}

/// Edit and cancel calls for a recurring series (KAN-694 RPCs). The server
/// enforces who may call them; the screen only decides what to show.
class GameSeriesRepository {
  const GameSeriesRepository(this._db);

  final SupabaseClient _db;

  Future<Result<SeriesFutureEditOutcome, Failure>> editFuture({
    required String seriesId,
    String? title,
    int? capacity,
  }) => Result.guard(() async {
    final res = await _db.rpc(
      SupabaseConfig.rpcEditGameSeriesFutureFn,
      params: {
        'p_series_id': seriesId,
        'p_title': ?title,
        'p_capacity': ?capacity,
      },
    );
    return SeriesFutureEditOutcome.fromJson(_asMap(res));
  }, Failure.from);

  Future<Result<SeriesCancelOutcome, Failure>> cancelSeries({
    required String seriesId,
    String? reason,
  }) => Result.guard(() async {
    final res = await _db.rpc(
      SupabaseConfig.rpcCancelGameSeriesFn,
      params: {'p_series_id': seriesId, 'p_reason': ?reason},
    );
    return SeriesCancelOutcome.fromJson(_asMap(res));
  }, Failure.from);

  static Map<String, dynamic> _asMap(Object? res) =>
      res is Map ? Map<String, dynamic>.from(res) : <String, dynamic>{};
}

final gameSeriesRepositoryProvider = Provider<GameSeriesRepository>(
  (ref) => GameSeriesRepository(ref.watch(supabaseClientProvider)),
);
