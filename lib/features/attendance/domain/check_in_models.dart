// KAN-998 (G-04): the player's check-in state, read from rpc_attendance_my.

import 'package:dabbler/core/constants/timing/notification_timing.dart';
import 'package:dabbler/core/utils/instant.dart';
import 'package:flutter/foundation.dart';

/// The G-04 states the server can put the player in. [submitting] is the
/// screen's own state while the check-in call is in flight.
enum CheckInPhase {
  beforeWindow,
  open,
  submitting,
  checkedIn,
  closed,
  notEligible,
  cancelled,
}

/// One answer of `rpc_attendance_my`.
@immutable
class MyAttendance {
  const MyAttendance({
    required this.phase,
    required this.opensAt,
    required this.closesAt,
    this.checkedInAt,
  });

  final CheckInPhase phase;

  /// 30 minutes before the start.
  final DateTime opensAt;

  /// 15 minutes after the start.
  final DateTime closesAt;
  final DateTime? checkedInAt;

  /// The start, derived from the window the server sends.
  DateTime get startAt => opensAt.add(NotificationTiming.checkInOpens);

  factory MyAttendance.fromJson(Map<String, dynamic> j) {
    final checkedInAt = parseInstantLocal(j['checked_in_at']);
    return MyAttendance(
      phase: phaseFromServer(
        j['state'] as String?,
        checkedIn: checkedInAt != null,
      ),
      opensAt: parseInstantLocal(j['opens_at'])!,
      closesAt: parseInstantLocal(j['closes_at'])!,
      checkedInAt: checkedInAt,
    );
  }

  MyAttendance copyWith({CheckInPhase? phase, DateTime? checkedInAt}) =>
      MyAttendance(
        phase: phase ?? this.phase,
        opensAt: opensAt,
        closesAt: closesAt,
        checkedInAt: checkedInAt ?? this.checkedInAt,
      );
}

/// `rpc_attendance_my.state` to a phase. After the organiser finalizes, the
/// state is the outcome: `attended` (or any check-in) reads as checked in,
/// every other outcome as closed.
CheckInPhase phaseFromServer(String? state, {required bool checkedIn}) {
  switch (state) {
    case 'before_window':
      return CheckInPhase.beforeWindow;
    case 'open':
      return CheckInPhase.open;
    case 'checked_in':
    case 'attended':
      return CheckInPhase.checkedIn;
    case 'not_eligible':
      return CheckInPhase.notEligible;
    case 'cancelled':
      return CheckInPhase.cancelled;
    default:
      return checkedIn ? CheckInPhase.checkedIn : CheckInPhase.closed;
  }
}

/// A refusal of `rpc_attendance_check_in` (its error message) to the phase the
/// screen shows instead; null when the refusal is not a state (a network or
/// unknown error), which the screen reports and stays open.
CheckInPhase? phaseForRefusal(String? code) => switch (code) {
  'check_in_closed' || 'attendance_finalized' => CheckInPhase.closed,
  'not_eligible' => CheckInPhase.notEligible,
  'event_cancelled' => CheckInPhase.cancelled,
  _ => null,
};
