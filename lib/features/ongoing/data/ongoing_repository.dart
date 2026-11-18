// KAN-1008 (W3-F1): rpc_my_ongoing_events, the caller's ongoing or
// about-to-start games and meetups (at most 10, ordered by start_at).

import 'package:dabbler/core/config/supabase_config.dart';
import 'package:dabbler/core/data/supabase_client.dart';
import 'package:dabbler/core/errors/request_timeout.dart';
import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/features/attendance/data/attendance_repository.dart'
    show attendanceFailure;
import 'package:dabbler/features/ongoing/domain/ongoing_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract class OngoingRepository {
  Future<Result<List<OngoingEvent>, Failure>> read();
}

class SupabaseOngoingRepository implements OngoingRepository {
  SupabaseOngoingRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<Result<List<OngoingEvent>, Failure>> read() =>
      guardWithTimeout(() async {
        final data = await _client.rpc(SupabaseConfig.rpcMyOngoingEventsFn);
        final rows = data is List ? data : const <Object?>[];
        return <OngoingEvent>[for (final r in rows) ?OngoingEvent.tryParse(r)];
      }, mapError: attendanceFailure);
}

final ongoingRepositoryProvider = Provider<OngoingRepository>(
  (ref) => SupabaseOngoingRepository(ref.watch(supabaseClientProvider)),
);
