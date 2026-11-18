// KAN-1002 (W2-F5): the server's lifecycle view, the call in flight, and the
// last refusal. One call at a time: a second tap while one is in flight is
// dropped. After every call the view is read again from the server. The view
// is also read again when the next boundary passes (start_at, then
// scheduled_end_at) by a one-shot timer, and when the app resumes.

import 'dart:async';

import 'package:dabbler/core/constants/timing/notification_timing.dart';
import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/features/lifecycle/data/lifecycle_repository.dart';
import 'package:dabbler/features/lifecycle/domain/lifecycle_models.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The clock the lifecycle card reads (only to offer Start); tests pin it.
final lifecycleClockProvider = Provider<DateTime Function()>(
  (_) => DateTime.now,
);

enum LifecycleAction { start, confirm, didNotHappen }

@immutable
class LifecycleState {
  const LifecycleState({
    this.view,
    this.busy,
    this.failure,
    this.loadFailed = false,
  });

  /// The last server read; null until it arrives, or when the event is
  /// hidden or missing (event_not_found) or the read failed.
  final LifecycleView? view;

  /// The call in flight, if any.
  final LifecycleAction? busy;

  /// The last call's refusal, or a failed re-read; never shown as a success.
  final Failure? failure;

  /// The first read failed (not event_not_found): the card offers a retry.
  final bool loadFailed;
}

class LifecycleController extends StateNotifier<LifecycleState>
    with WidgetsBindingObserver {
  LifecycleController(this._ref, this.eventId) : super(const LifecycleState()) {
    WidgetsBinding.instance.addObserver(this);
    load();
  }

  final Ref _ref;
  LifecycleRepository get _repo => _ref.read(lifecycleRepositoryProvider);
  final String eventId;
  Timer? _boundary;

  /// The read, or its failure; a thrown error (no client) is a failure too.
  Future<(LifecycleView?, Failure?)> _read() async {
    try {
      final r = await _repo.read(eventId);
      return r.fold<(LifecycleView?, Failure?)>(
        (f) => (null, f),
        (v) => (v, null),
      );
    } catch (e) {
      return (null, Failure.from(e));
    }
  }

  /// Reads the server and re-arms the boundary timer.
  Future<void> load() async {
    final (v, f) = await _read();
    if (!mounted) return;
    final hidden = f?.code == 'event_not_found';
    state = LifecycleState(
      view: v ?? state.view,
      busy: state.busy,
      failure: state.failure,
      loadFailed: v == null && state.view == null && f != null && !hidden,
    );
    _arm();
  }

  void _arm() {
    _boundary?.cancel();
    _boundary = null;
    final v = state.view;
    if (v == null) return;
    final now = _ref.read(lifecycleClockProvider)();
    DateTime? next;
    for (final t in [v.startAt, v.scheduledEnd]) {
      if (t != null && t.isAfter(now)) {
        next = t;
        break;
      }
    }
    if (next == null) return;
    // A second past the boundary, so the server's now() is past it too.
    _boundary = Timer(
      next.difference(now) + NotificationTiming.lifecycleBoundarySlack,
      load,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) load();
  }

  Future<void> run(LifecycleAction action) async {
    if (state.busy != null) return;
    final kept = state.view;
    state = LifecycleState(view: kept, busy: action);
    final result = switch (action) {
      LifecycleAction.start => await _repo.start(eventId),
      LifecycleAction.confirm => await _repo.confirmEnd(eventId, played: true),
      LifecycleAction.didNotHappen => await _repo.confirmEnd(
        eventId,
        played: false,
      ),
    };
    final (fresh, readFailure) = await _read();
    if (!mounted) return;
    state = LifecycleState(
      view: fresh ?? kept,
      failure: result.fold((f) => f, (_) => readFailure),
    );
    _arm();
  }

  @override
  void dispose() {
    _boundary?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}

final lifecycleControllerProvider = StateNotifierProvider.autoDispose
    .family<LifecycleController, LifecycleState, String>(
      (ref, eventId) => LifecycleController(ref, eventId),
    );
