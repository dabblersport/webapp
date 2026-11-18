// KAN-998 (G-04): the check-in screen's state: the server's answer, and the
// check-in in flight.

import 'dart:async';

import 'package:dabbler/core/constants/timing/notification_timing.dart';
import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/features/attendance/data/attendance_repository.dart';
import 'package:dabbler/features/attendance/domain/check_in_models.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

@immutable
class AttendanceCheckInState {
  const AttendanceCheckInState({
    this.attendance,
    this.loading = true,
    this.loadFailure,
    this.submitting = false,
    this.submitFailure,
  });

  final MyAttendance? attendance;
  final bool loading;

  /// The read failed and there is nothing to show.
  final Failure? loadFailure;
  final bool submitting;

  /// The last check-in failed for a reason that is not a state (network,
  /// unknown); the screen reports it once and stays open.
  final Failure? submitFailure;

  /// The G-04 state to draw; null while loading or after a failed read.
  CheckInPhase? get phase =>
      submitting ? CheckInPhase.submitting : attendance?.phase;

  AttendanceCheckInState copyWith({
    MyAttendance? attendance,
    bool? loading,
    Failure? loadFailure,
    bool? submitting,
    Failure? submitFailure,
  }) => AttendanceCheckInState(
    attendance: attendance ?? this.attendance,
    loading: loading ?? this.loading,
    loadFailure: loadFailure,
    submitting: submitting ?? this.submitting,
    submitFailure: submitFailure,
  );
}

class AttendanceCheckInController
    extends StateNotifier<AttendanceCheckInState> {
  AttendanceCheckInController(this._repo, this.eventId)
    : super(const AttendanceCheckInState()) {
    load();
  }

  final AttendanceRepository _repo;
  final String eventId;
  Timer? _edge;

  Future<void> load() async {
    state = state.copyWith(loading: true);
    final result = await _repo.my(eventId);
    if (!mounted) return;
    result.fold((f) => state = state.copyWith(loading: false, loadFailure: f), (
      a,
    ) {
      state = state.copyWith(loading: false, attendance: a);
      _scheduleEdge(a);
    });
  }

  /// Calls the real RPC. A refusal shows the state it names (outside the
  /// window: closed), never a success.
  Future<void> checkIn() async {
    final current = state.attendance;
    if (current == null || state.submitting) return;
    state = state.copyWith(submitting: true);
    final result = await _repo.checkIn(eventId);
    if (!mounted) return;
    result.fold(
      (f) {
        final phase = phaseForRefusal(f.code);
        state = phase == null
            ? state.copyWith(submitting: false, submitFailure: f)
            : state.copyWith(
                submitting: false,
                attendance: current.copyWith(phase: phase),
              );
      },
      (at) => state = state.copyWith(
        submitting: false,
        attendance: current.copyWith(
          phase: CheckInPhase.checkedIn,
          checkedInAt: at ?? DateTime.now(),
        ),
      ),
    );
  }

  /// Re-reads when the window opens or closes while the screen is up.
  void _scheduleEdge(MyAttendance a) {
    _edge?.cancel();
    final DateTime? at = switch (a.phase) {
      CheckInPhase.beforeWindow => a.opensAt,
      CheckInPhase.open => a.closesAt,
      _ => null,
    };
    if (at == null) return;
    final wait = at.difference(DateTime.now());
    if (wait.isNegative || wait > NotificationTiming.checkInEdgeHorizon) return;
    _edge = Timer(wait + NotificationTiming.checkInEdgeGrace, load);
  }

  @override
  void dispose() {
    _edge?.cancel();
    super.dispose();
  }
}

final attendanceCheckInProvider = StateNotifierProvider.autoDispose
    .family<AttendanceCheckInController, AttendanceCheckInState, String>(
      (ref, eventId) => AttendanceCheckInController(
        ref.watch(attendanceRepositoryProvider),
        eventId,
      ),
    );
