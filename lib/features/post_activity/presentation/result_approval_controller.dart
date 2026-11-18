// KAN-1000 (G-03): the organiser's result tally, Approve, and the final
// score entry (the reject path and the tie path). One write at a time; a
// refusal is reported and the tally re-read when the state moved on.

import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/features/post_activity/data/post_activity_repository.dart';
import 'package:dabbler/features/post_activity/domain/post_activity_models.dart';
import 'package:dabbler/features/post_activity/presentation/post_activity_controller.dart'
    show kPostActivityReload;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

@immutable
class ResultApprovalState {
  const ResultApprovalState({
    this.tally,
    this.loading = true,
    this.loadFailure,
    this.busy = false,
  });

  final ResultTally? tally;
  final bool loading;
  final Failure? loadFailure;
  final bool busy;

  ResultApprovalState copyWith({
    ResultTally? tally,
    bool? loading,
    Failure? loadFailure,
    bool? busy,
  }) => ResultApprovalState(
    tally: tally ?? this.tally,
    loading: loading ?? this.loading,
    loadFailure: loadFailure,
    busy: busy ?? this.busy,
  );
}

const Set<String> _reloadOn = {
  ...kPostActivityReload,
  'no_majority',
  'no_submissions',
};

class ResultApprovalController extends StateNotifier<ResultApprovalState> {
  ResultApprovalController(this._repo, this.eventId)
    : super(const ResultApprovalState()) {
    load();
  }

  final PostActivityRepository _repo;
  final String eventId;

  Future<void> load() async {
    state = state.copyWith(loading: true);
    final r = await _repo.result(eventId);
    if (!mounted) return;
    r.fold(
      (f) => state = state.copyWith(loading: false, loadFailure: f),
      (t) => state = state.copyWith(loading: false, tally: t),
    );
  }

  Future<Failure?> approve() => _write(() => _repo.approve(eventId));

  Future<Failure?> setFinal(Score score) =>
      _write(() => _repo.setFinal(eventId, score));

  Future<Failure?> _write(Future<Result<void, Failure>> Function() call) async {
    if (state.busy) return const Failure(code: 'busy');
    state = state.copyWith(busy: true);
    final r = await call();
    if (!mounted) return null;
    final Failure? f = r.fold((e) => e, (_) => null);
    state = state.copyWith(busy: false);
    if (f == null || _reloadOn.contains(f.code)) await load();
    return f;
  }
}

final resultApprovalProvider = StateNotifierProvider.autoDispose
    .family<ResultApprovalController, ResultApprovalState, String>(
      (ref, eventId) => ResultApprovalController(
        ref.watch(postActivityRepositoryProvider),
        eventId,
      ),
    );
