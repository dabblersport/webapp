// KAN-999 (G-05, G-06): the organiser's attendance list, correction,
// finalize and review decision, and the player's no-show read and review
// request. The attendance tables are server-only (T-020); every call is an
// RPC. A refusal keeps the server's message as Failure.code.

import 'package:dabbler/core/config/supabase_config.dart';
import 'package:dabbler/core/data/supabase_client.dart';
import 'package:dabbler/core/errors/request_timeout.dart';
import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/core/utils/instant.dart';
import 'package:dabbler/features/attendance/data/attendance_repository.dart'
    show attendanceFailure;
import 'package:dabbler/features/attendance/domain/attendance_list_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// `attended` or `no_show`, as the server spells them.
enum AttendanceMark {
  attended('attended'),
  noShow('no_show');

  const AttendanceMark(this.wire);
  final String wire;
}

abstract class AttendanceReviewRepository {
  /// The roster with check-ins, corrections and outcomes, and the window's
  /// close. `not_organiser` for anyone else.
  Future<Result<AttendanceList, Failure>> list(String eventId);

  Future<Result<void, Failure>> correct(
    String eventId,
    String userId,
    AttendanceMark mark,
    String reason,
  );

  Future<Result<void, Failure>> finalize(String eventId);

  /// [accept] true marks attended; false keeps the no-show.
  Future<Result<void, Failure>> decide(
    String eventId,
    String userId, {
    required bool accept,
  });

  /// The caller's own no-show state.
  Future<Result<NoShowStatus, Failure>> myNoShow(String eventId);

  /// Asks for a review; returns the organiser's deadline.
  Future<Result<DateTime?, Failure>> requestReview(
    String eventId,
    String? note,
  );
}

class SupabaseAttendanceReviewRepository implements AttendanceReviewRepository {
  SupabaseAttendanceReviewRepository(this._client);

  final SupabaseClient _client;

  Future<Object?> _rpc(String fn, Map<String, dynamic> params) =>
      _client.rpc(fn, params: params);

  @override
  Future<Result<AttendanceList, Failure>> list(String eventId) =>
      guardWithTimeout(() async {
        final rows = await _rpc(SupabaseConfig.rpcAttendanceListFn, {
          'p_event_id': eventId,
        });
        // The window is the same for every caller; the organiser reads it
        // from rpc_attendance_my (state not_eligible, times still sent).
        final my = await _rpc(SupabaseConfig.rpcAttendanceMyFn, {
          'p_event_id': eventId,
        });
        return AttendanceList(
          rows: [
            for (final r in (rows as List? ?? const []))
              AttendanceRow.fromJson(Map<String, dynamic>.from(r as Map)),
          ],
          closesAt: parseInstantLocal((my as Map)['closes_at'])!,
        );
      }, mapError: attendanceFailure);

  @override
  Future<Result<void, Failure>> correct(
    String eventId,
    String userId,
    AttendanceMark mark,
    String reason,
  ) => guardWithTimeout(() async {
    await _rpc(SupabaseConfig.rpcAttendanceCorrectFn, {
      'p_event_id': eventId,
      'p_user_id': userId,
      'p_mark': mark.wire,
      'p_reason': reason,
    });
  }, mapError: attendanceFailure);

  @override
  Future<Result<void, Failure>> finalize(String eventId) =>
      guardWithTimeout(() async {
        await _rpc(SupabaseConfig.rpcAttendanceFinalizeFn, {
          'p_event_id': eventId,
        });
      }, mapError: attendanceFailure);

  @override
  Future<Result<void, Failure>> decide(
    String eventId,
    String userId, {
    required bool accept,
  }) => guardWithTimeout(() async {
    await _rpc(SupabaseConfig.rpcAttendanceDecideReviewFn, {
      'p_event_id': eventId,
      'p_user_id': userId,
      'p_decision': accept ? 'accept' : 'keep',
    });
  }, mapError: attendanceFailure);

  @override
  Future<Result<NoShowStatus, Failure>> myNoShow(String eventId) =>
      guardWithTimeout(() async {
        final data = await _rpc(SupabaseConfig.rpcAttendanceMyFn, {
          'p_event_id': eventId,
        });
        return NoShowStatus.fromJson(Map<String, dynamic>.from(data as Map));
      }, mapError: attendanceFailure);

  @override
  Future<Result<DateTime?, Failure>> requestReview(
    String eventId,
    String? note,
  ) => guardWithTimeout(() async {
    final data = await _rpc(SupabaseConfig.rpcAttendanceRequestReviewFn, {
      'p_event_id': eventId,
      'p_note': (note == null || note.trim().isEmpty) ? null : note.trim(),
    });
    return parseInstantLocal((data as Map?)?['review_deadline']);
  }, mapError: attendanceFailure);
}

final attendanceReviewRepositoryProvider = Provider<AttendanceReviewRepository>(
  (ref) =>
      SupabaseAttendanceReviewRepository(ref.watch(supabaseClientProvider)),
);
