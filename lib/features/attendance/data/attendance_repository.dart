// KAN-998 (G-04): the player's check-in calls. The attendance tables are
// server-only (T-020); the client reads and writes through these two RPCs.

import 'package:dabbler/core/config/supabase_config.dart';
import 'package:dabbler/core/data/supabase_client.dart';
import 'package:dabbler/core/errors/request_timeout.dart';
import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/core/utils/instant.dart';
import 'package:dabbler/features/attendance/domain/check_in_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract class AttendanceRepository {
  /// The caller's check-in state and window for [eventId].
  Future<Result<MyAttendance, Failure>> my(String eventId);

  /// Checks the caller in. A refusal keeps the server's message as
  /// [Failure.code] (`check_in_closed`, `not_eligible`, ...).
  Future<Result<DateTime?, Failure>> checkIn(String eventId);
}

/// The server's refusal message as [Failure.code]; everything else as
/// [Failure.from] classifies it.
Failure attendanceFailure(Object error) {
  final base = Failure.from(error);
  if (error is PostgrestException) {
    return Failure(
      category: base.category,
      message: error.message,
      cause: error,
      code: error.message,
    );
  }
  return base;
}

class SupabaseAttendanceRepository implements AttendanceRepository {
  SupabaseAttendanceRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<Result<MyAttendance, Failure>> my(String eventId) =>
      guardWithTimeout(() async {
        final data = await _client.rpc(
          SupabaseConfig.rpcAttendanceMyFn,
          params: {'p_event_id': eventId},
        );
        return MyAttendance.fromJson(Map<String, dynamic>.from(data as Map));
      }, mapError: attendanceFailure);

  @override
  Future<Result<DateTime?, Failure>> checkIn(String eventId) =>
      guardWithTimeout(() async {
        final data = await _client.rpc(
          SupabaseConfig.rpcAttendanceCheckInFn,
          params: {'p_event_id': eventId},
        );
        return parseInstantLocal((data as Map)['checked_in_at']);
      }, mapError: attendanceFailure);
}

final attendanceRepositoryProvider = Provider<AttendanceRepository>(
  (ref) => SupabaseAttendanceRepository(ref.watch(supabaseClientProvider)),
);
