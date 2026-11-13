import 'package:dabbler/core/config/supabase_config.dart';
import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/features/bench/data/bench_status.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Bench mode reads and writes (KAN-706). Never throws: every call returns a
/// [Result], and a backend error (including `not_authenticated`) becomes a
/// [Failure].
class BenchRepository {
  BenchRepository(this._client);

  final SupabaseClient _client;

  static const String _columns =
      'is_benched, benched_at, reason, bench_until, hide_in_feed, '
      'hide_in_search, block_friend_requests, suppress_social_notifications, '
      'updated_at';

  /// The viewer's own row. `v_bench_status` carries neither `reason` nor
  /// `benched_at` and is not granted SELECT to `authenticated`, so this reads
  /// the table under its select-own policy. No row is [BenchStatus.none].
  Future<Result<BenchStatus, Failure>> load() => Result.guard(() async {
    final query = _client.from(SupabaseConfig.userStatusTable).select(_columns);
    final String? uid = _client.auth.currentUser?.id;
    final Map<String, dynamic>? row =
        await (uid == null ? query : query.eq('user_id', uid)).maybeSingle();
    return BenchStatus.fromRow(row);
  }, Failure.from);

  /// Starts a bench, or saves an edit to the current one.
  Future<Result<Unit, Failure>> save(BenchSettings settings) =>
      Result.guard(() async {
        await _client.rpc<dynamic>(
          SupabaseConfig.rpcToggleBenchFn,
          params: settings.toToggleParams(),
        );
        return unit;
      }, Failure.from);

  /// Ends the bench now.
  Future<Result<Unit, Failure>> end() => Result.guard(() async {
    await _client.rpc<dynamic>(SupabaseConfig.rpcEndBenchFn);
    return unit;
  }, Failure.from);
}
