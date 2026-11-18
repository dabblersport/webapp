// KAN-998: an attendance repository for screens that embed the check-in row
// but do not test it: every read says not eligible, so the row draws nothing.

import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/features/attendance/data/attendance_repository.dart';
import 'package:dabbler/features/attendance/domain/check_in_models.dart';
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
