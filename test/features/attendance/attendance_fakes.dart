// KAN-998: an attendance repository for screens that embed the check-in row
// but do not test it: every read says not eligible, so the row draws nothing.

import 'dart:async';

import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/features/attendance/data/attendance_repository.dart';
import 'package:dabbler/features/attendance/domain/check_in_models.dart';
import 'package:dabbler/features/attendance/presentation/check_in_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class NoCheckInRepository implements AttendanceRepository {
  @override
  Future<Result<MyAttendance, Failure>> my(String eventId) async => Ok(
    MyAttendance(
      phase: CheckInPhase.notEligible,
      opensAt: DateTime(2026),
      closesAt: DateTime(2026),
    ),
  );

  @override
  Future<Result<DateTime?, Failure>> checkIn(String eventId) async =>
      const Err(Failure(code: 'not_eligible'));
}

final Override noCheckInOverride = attendanceRepositoryProvider
    .overrideWithValue(NoCheckInRepository());

/// The check-in state of a detail screen's bottom bar: every read answers
/// [phase]; [CheckInPhase.submitting] is an open window with a call in flight.
Override checkInPhaseOverride(CheckInPhase phase, {DateTime? checkedInAt}) =>
    attendanceCheckInProvider.overrideWith(
      (ref, id) => _PhaseController(phase, checkedInAt, id),
    );

class _PhaseRepository implements AttendanceRepository {
  _PhaseRepository(this.phase, this.checkedInAt);
  final CheckInPhase phase;
  final DateTime? checkedInAt;

  @override
  Future<Result<MyAttendance, Failure>> my(String eventId) async {
    final now = DateTime.now();
    return Ok(
      MyAttendance(
        phase: phase == CheckInPhase.submitting ? CheckInPhase.open : phase,
        opensAt: now.subtract(const Duration(minutes: 10)),
        closesAt: now.add(const Duration(minutes: 35)),
        checkedInAt: checkedInAt,
      ),
    );
  }

  @override
  Future<Result<DateTime?, Failure>> checkIn(String eventId) =>
      Completer<Result<DateTime?, Failure>>().future;
}

class _PhaseController extends AttendanceCheckInController {
  _PhaseController(CheckInPhase phase, DateTime? at, String id)
    : super(_PhaseRepository(phase, at), id) {
    if (phase == CheckInPhase.submitting) {
      state = state.copyWith(submitting: true);
    }
  }
}
