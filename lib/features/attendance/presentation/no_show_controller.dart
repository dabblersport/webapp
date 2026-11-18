// KAN-999 (G-06 player side): the player's no-show state and the review
// request in flight. A refusal is reported and the state stays as the server
// has it; one request at a time.

import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/features/attendance/data/attendance_review_repository.dart';
import 'package:dabbler/features/attendance/domain/attendance_list_models.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

@immutable
class NoShowState {
  const NoShowState({
    this.status,
    this.loading = true,
    this.loadFailure,
    this.sending = false,
  });

  final NoShowStatus? status;
  final bool loading;
  final Failure? loadFailure;
  final bool sending;

  NoShowState copyWith({
    NoShowStatus? status,
    bool? loading,
    Failure? loadFailure,
    bool? sending,
  }) => NoShowState(
    status: status ?? this.status,
    loading: loading ?? this.loading,
    loadFailure: loadFailure,
    sending: sending ?? this.sending,
  );
}

class NoShowController extends StateNotifier<NoShowState> {
  NoShowController(this._repo, this.eventId) : super(const NoShowState()) {
    load();
  }

  final AttendanceReviewRepository _repo;
  final String eventId;

  Future<void> load() async {
    state = state.copyWith(loading: true);
    final r = await _repo.myNoShow(eventId);
    if (!mounted) return;
    r.fold(
      (f) => state = state.copyWith(loading: false, loadFailure: f),
      (s) => state = state.copyWith(loading: false, status: s),
    );
  }

  /// Null on success (the state moves to review requested); the failure
  /// otherwise, `busy` when dropped as a second tap.
  Future<Failure?> requestReview(String? note) async {
    final current = state.status;
    if (state.sending || current == null) return const Failure(code: 'busy');
    state = state.copyWith(sending: true);
    final r = await _repo.requestReview(eventId, note);
    if (!mounted) return null;
    return r.fold(
      (f) {
        state = state.copyWith(sending: false);
        if (f.code == 'review_window_closed' ||
            f.code == 'no_pending_no_show') {
          load();
        }
        return f;
      },
      (deadline) {
        state = state.copyWith(
          sending: false,
          status: current.copyWith(
            phase: NoShowPhase.reviewRequested,
            reviewDeadline: deadline,
          ),
        );
        return null;
      },
    );
  }
}

final noShowProvider = StateNotifierProvider.autoDispose
    .family<NoShowController, NoShowState, String>(
      (ref, eventId) => NoShowController(
        ref.watch(attendanceReviewRepositoryProvider),
        eventId,
      ),
    );
