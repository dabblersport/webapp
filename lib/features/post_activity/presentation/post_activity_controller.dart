// KAN-1000 (G-02): the post-activity flow. Steps: score (competitive only),
// players, organiser, venue. Each step saves on Next and can be skipped; the
// last step's Submit marks the flow submitted. Coming back resumes at the
// first step with nothing saved. One write at a time; a refusal that means
// the state moved on reloads it.

import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/features/post_activity/data/post_activity_repository.dart';
import 'package:dabbler/features/post_activity/domain/post_activity_models.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum PostStep { score, players, organiser, venue }

/// Refusals after which the screen re-reads the server's state.
const Set<String> kPostActivityReload = {
  'window_closed',
  'window_not_open',
  'not_eligible',
  'not_ratable',
  'result_final',
  'not_ended',
  'no_score_step',
  'event_cancelled',
};

@immutable
class PostActivityState {
  const PostActivityState({
    this.flow,
    this.tally,
    this.dims = const [],
    this.loading = true,
    this.loadFailure,
    this.busy = false,
    this.step = 0,
    this.drafts = const {},
    this.score,
    this.side,
    this.tallyFailure,
    this.dismissed = false,
  });

  final RatingFlow? flow;

  /// rpc_result_get failed for a reason other than "no score step"; the
  /// score step shows it with a retry.
  final Failure? tallyFailure;

  /// rpc_rating_dismiss succeeded: no more prompts for this event.
  final bool dismissed;

  /// Null until read; competitive false = no score step.
  final ResultTally? tally;
  final List<RatingDimension> dims;
  final bool loading;
  final Failure? loadFailure;
  final bool busy;
  final int step;

  /// Scores being given, keyed `player:<id>`, `organiser`, `venue`.
  final Map<String, Map<String, int>> drafts;
  final Score? score;
  final String? side;

  List<PostStep> get steps => [
    if (tally?.competitive == true || tallyFailure != null) PostStep.score,
    if (flow?.players.isNotEmpty == true) PostStep.players,
    if (flow?.organiser != null) PostStep.organiser,
    if (flow?.venue != null) PostStep.venue,
  ];

  PostStep? get current {
    final s = steps;
    return s.isEmpty ? null : s[step.clamp(0, s.length - 1)];
  }

  bool get isLast => step >= steps.length - 1;

  List<RatingDimension> dimsFor(RatingSubject s) => [
    for (final d in dims)
      if (d.subjects.contains(s)) d,
  ];

  PostActivityState copyWith({
    RatingFlow? flow,
    ResultTally? tally,
    List<RatingDimension>? dims,
    bool? loading,
    Failure? loadFailure,
    bool? busy,
    int? step,
    Map<String, Map<String, int>>? drafts,
    Score? score,
    String? side,
    Failure? tallyFailure,
    bool? dismissed,
  }) => PostActivityState(
    flow: flow ?? this.flow,
    tally: tally ?? this.tally,
    dims: dims ?? this.dims,
    loading: loading ?? this.loading,
    loadFailure: loadFailure,
    busy: busy ?? this.busy,
    step: step ?? this.step,
    drafts: drafts ?? this.drafts,
    score: score ?? this.score,
    side: side ?? this.side,
    tallyFailure: tallyFailure ?? this.tallyFailure,
    dismissed: dismissed ?? this.dismissed,
  );
}

class PostActivityController extends StateNotifier<PostActivityState> {
  PostActivityController(this._repo, this.eventId)
    : super(const PostActivityState()) {
    load();
  }

  final PostActivityRepository _repo;
  final String eventId;

  Future<void> load() async {
    state = state.copyWith(loading: true);
    final f = await _repo.flow(eventId);
    if (!mounted) return;
    final flow = f.fold((_) => null, (v) => v);
    if (flow == null) {
      state = state.copyWith(
        loading: false,
        loadFailure: f.fold((e) => e, (_) => null),
      );
      return;
    }
    if (flow.state == RatingFlowState.notEligible ||
        flow.state == RatingFlowState.notOpen) {
      state = PostActivityState(flow: flow, loading: false);
      return;
    }
    final t = await _repo.result(eventId);
    final d = await _repo.dimensions();
    if (!mounted) return;
    // Only the server saying "no score step" (or competitive: false) drops
    // the score step; any other refusal or a timeout keeps it with a retry.
    final Failure? tallyFailure = t.fold(
      (e) => e.code == 'no_score_step' ? null : e,
      (_) => null,
    );
    final ResultTally? tally = t.fold(
      (e) => e.code == 'no_score_step'
          ? const ResultTally(competitive: false)
          : null,
      (v) => v,
    );
    final drafts = <String, Map<String, int>>{
      for (final p in flow.players) 'player:${p.id}': p.mine,
      if (flow.organiser != null) 'organiser': flow.organiser!.mine,
      if (flow.venue != null) 'venue': flow.venue!.mine,
    };
    var next = PostActivityState(
      flow: flow,
      tally: tally,
      dims: d.fold((_) => const [], (v) => v),
      loading: false,
      drafts: drafts,
      score: tally?.mine?.score ?? tally?.finalScore ?? const Score(0, 0),
      side: tally?.mine?.side,
      tallyFailure: tallyFailure,
    );
    next = next.copyWith(step: _resumeAt(next));
    state = next;
  }

  /// The first step with nothing saved yet.
  int _resumeAt(PostActivityState s) {
    final steps = s.steps;
    for (var i = 0; i < steps.length; i++) {
      final done = switch (steps[i]) {
        PostStep.score => s.tally?.mine != null,
        PostStep.players => s.flow!.players.any((p) => p.mine.isNotEmpty),
        PostStep.organiser => s.flow!.organiser!.mine.isNotEmpty,
        PostStep.venue => s.flow!.venue!.mine.isNotEmpty,
      };
      if (!done) return i;
    }
    return steps.isEmpty ? 0 : steps.length - 1;
  }

  /// Re-reads the tally after a failed read (the score step's retry).
  Future<void> retryResult() async {
    if (state.busy) return;
    final t = await _repo.result(eventId);
    if (!mounted) return;
    t.fold((e) {
      if (e.code == 'no_score_step') {
        state = _withTally(const ResultTally(competitive: false), null);
      } else {
        state = _withTally(state.tally, e);
      }
    }, (v) => state = _withTally(v, null));
  }

  PostActivityState _withTally(ResultTally? t, Failure? f) {
    final s = state;
    return PostActivityState(
      flow: s.flow,
      tally: t,
      dims: s.dims,
      loading: false,
      step: s.step,
      drafts: s.drafts,
      score: t?.mine?.score ?? t?.finalScore ?? s.score,
      side: t?.mine?.side ?? s.side,
      tallyFailure: f,
    );
  }

  /// rpc_rating_dismiss. Null on success.
  Future<Failure?> dismiss() async {
    if (state.busy || state.flow == null) return const Failure(code: 'busy');
    state = state.copyWith(busy: true);
    final r = await _repo.dismiss(eventId);
    if (!mounted) return null;
    final Failure? f = r.fold((e) => e, (_) => null);
    state = state.copyWith(busy: false, dismissed: f == null);
    if (f != null && kPostActivityReload.contains(f.code)) await load();
    return f;
  }

  void setScore(Score s) => state = state.copyWith(score: s);

  void setSide(String side) => state = state.copyWith(side: side);

  void setRating(String target, String dim, int value) {
    final drafts = Map<String, Map<String, int>>.of(state.drafts);
    drafts[target] = {...?drafts[target], dim: value};
    state = state.copyWith(drafts: drafts);
  }

  void back() {
    if (state.step > 0) state = state.copyWith(step: state.step - 1);
  }

  /// Saves the step, then moves on (Submit on the last). Null on success.
  Future<Failure?> next() => _run(save: true);

  /// Moves on without saving (Submit on the last).
  Future<Failure?> skip() => _run(save: false);

  Future<Failure?> _run({required bool save}) async {
    if (state.busy || state.flow == null) return const Failure(code: 'busy');
    state = state.copyWith(busy: true);
    final f =
        (save ? await _save() : null) ??
        (state.isLast ? await _submit() : null);
    if (!mounted) return null;
    if (f != null) {
      state = state.copyWith(busy: false);
      if (kPostActivityReload.contains(f.code)) await load();
      return f;
    }
    if (state.isLast) {
      await load();
    } else {
      state = state.copyWith(busy: false, step: state.step + 1);
    }
    return null;
  }

  Future<Failure?> _submit() async =>
      (await _repo.submitFlow(eventId)).fold((f) => f, (_) => null);

  Future<Failure?> _save() async {
    final s = state;
    final flow = s.flow!;
    Future<Failure?> rate(RatingSubject sub, String key, RatingTarget t) async {
      final d = s.drafts[key] ?? const {};
      if (d.isEmpty || mapEquals(d, t.mine)) return null;
      final r = await _repo.rate(
        eventId,
        sub,
        sub == RatingSubject.player ? t.id : null,
        d,
      );
      return r.fold((f) => f, (_) => null);
    }

    switch (s.current) {
      case PostStep.score:
        final score = s.score, side = s.side;
        if (score == null || side == null || s.tally?.open != true) return null;
        final mine = s.tally?.mine;
        if (mine != null && mine.score == score && mine.side == side) {
          return null;
        }
        final r = await _repo.submitScore(eventId, score, side);
        return r.fold((f) => f, (_) => null);
      case PostStep.players:
        for (final p in flow.players) {
          final f = await rate(RatingSubject.player, 'player:${p.id}', p);
          if (f != null) return f;
        }
        return null;
      case PostStep.organiser:
        return rate(RatingSubject.organiser, 'organiser', flow.organiser!);
      case PostStep.venue:
        return rate(RatingSubject.venue, 'venue', flow.venue!);
      case null:
        return null;
    }
  }
}

final postActivityProvider = StateNotifierProvider.autoDispose
    .family<PostActivityController, PostActivityState, String>(
      (ref, eventId) => PostActivityController(
        ref.watch(postActivityRepositoryProvider),
        eventId,
      ),
    );

/// The clock the post-activity screens count down from; overridden in tests.
final postActivityNowProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);
