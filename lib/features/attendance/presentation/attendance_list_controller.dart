// KAN-999 (G-05, G-06 organiser side): the attendance list's state, and the
// correction, finalize and review decision in flight. Every write is the real
// RPC; a refusal leaves the list as the server has it and is reported, never
// shown as done. One call at a time: a second tap while one runs is dropped.

import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/features/attendance/data/attendance_review_repository.dart';
import 'package:dabbler/features/attendance/domain/attendance_list_models.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

@immutable
class AttendanceListState {
  const AttendanceListState({
    this.list,
    this.loading = true,
    this.loadFailure,
    this.busy = false,
    this.decisions = const <String, bool>{},
  });

  final AttendanceList? list;
  final bool loading;
  final Failure? loadFailure;

  /// A correction, finalize or decision is in flight.
  final bool busy;

  /// The decisions made on this screen (user id -> accepted), shown as the
  /// review card's result.
  final Map<String, bool> decisions;

  AttendanceListState copyWith({
    AttendanceList? list,
    bool? loading,
    Failure? loadFailure,
    bool? busy,
    Map<String, bool>? decisions,
  }) => AttendanceListState(
    list: list ?? this.list,
    loading: loading ?? this.loading,
    loadFailure: loadFailure,
    busy: busy ?? this.busy,
    decisions: decisions ?? this.decisions,
  );
}

class AttendanceListController extends StateNotifier<AttendanceListState> {
  AttendanceListController(this._repo, this.eventId)
    : super(const AttendanceListState()) {
    load();
  }

  final AttendanceReviewRepository _repo;
  final String eventId;

  Future<void> load() async {
    state = state.copyWith(loading: true);
    final r = await _repo.list(eventId);
    if (!mounted) return;
    r.fold(
      (f) => state = state.copyWith(loading: false, loadFailure: f),
      (l) => state = state.copyWith(loading: false, list: l),
    );
  }

  /// Refusals that mean the list on screen is stale: reload it.
  static const Set<String> staleCodes = <String>{
    'no_open_review',
    'attendance_finalized',
  };

  /// Runs [call] if nothing else is in flight; reloads on success and on a
  /// [staleCodes] refusal. Returns
  /// null on success, the failure otherwise (also when dropped as a double
  /// tap: [Failure.code] `busy`).
  Future<Failure?> _write(Future<Failure?> Function() call) async {
    if (state.busy || state.list == null) {
      return const Failure(code: 'busy');
    }
    state = state.copyWith(busy: true);
    final f = await call();
    if (!mounted) return f;
    state = state.copyWith(busy: false);
    if (f == null || staleCodes.contains(f.code)) await load();
    return f;
  }

  Future<Failure?> correct(String userId, AttendanceMark mark, String reason) =>
      _write(() async {
        final r = await _repo.correct(eventId, userId, mark, reason.trim());
        return r.fold((f) => f, (_) => null);
      });

  Future<Failure?> finalize() => _write(() async {
    final r = await _repo.finalize(eventId);
    return r.fold((f) => f, (_) => null);
  });

  Future<Failure?> decide(String userId, {required bool accept}) =>
      _write(() async {
        final r = await _repo.decide(eventId, userId, accept: accept);
        return r.fold((f) => f, (_) {
          state = state.copyWith(
            decisions: <String, bool>{...state.decisions, userId: accept},
          );
          return null;
        });
      });
}

final attendanceListProvider = StateNotifierProvider.autoDispose
    .family<AttendanceListController, AttendanceListState, String>(
      (ref, eventId) => AttendanceListController(
        ref.watch(attendanceReviewRepositoryProvider),
        eventId,
      ),
    );

/// The clock the attendance screens read; tests override it.
final attendanceNowProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);
