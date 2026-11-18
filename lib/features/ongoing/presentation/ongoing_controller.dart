// KAN-1008 (W3-F1): the caller's ongoing activities, read from
// rpc_my_ongoing_events. Read again, never on a polling loop:
// - at the next boundary (a start, check-in close, a scheduled end, an
//   auto-close) by a one-shot timer, as LifecycleController does;
// - when the app resumes;
// - when a new activity.* notice (or a cancel, time change or removal of a
//   game or meetup) arrives in the inbox.
// What the server stops returning (closed or cancelled for 2h, left, removed)
// leaves the card at the next read; while a closed or cancelled card is shown
// one read is armed 2h after it was first seen. A burst of notices is
// debounced into one read; a failed read is retried once.

import 'dart:async';

import 'package:dabbler/core/constants/timing/notification_timing.dart';
import 'package:dabbler/features/lifecycle/presentation/lifecycle_controller.dart'
    show lifecycleClockProvider;
import 'package:dabbler/features/notifications/presentation/providers/notifications_providers.dart';
import 'package:dabbler/features/ongoing/data/ongoing_repository.dart';
import 'package:dabbler/features/ongoing/domain/ongoing_models.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

@immutable
class OngoingState {
  const OngoingState({this.events = const <OngoingEvent>[]});

  /// Ordered by [orderOngoing]; empty until the first read, or when the
  /// server returns nothing.
  final List<OngoingEvent> events;
}

/// Notice kinds that can change what rpc_my_ongoing_events returns.
bool ongoingNoticeKind(String kind) =>
    kind.startsWith('activity.') ||
    const <String>{
      'game.cancelled',
      'game.occurrence_cancelled',
      'game.time_changed',
      'game.removed',
      'meetup.cancelled',
      'meetup.occurrence_cancelled',
      'meetup.time_changed',
      'meetup.removed',
    }.contains(kind);

/// The id of the newest inbox notice of an [ongoingNoticeKind]; null when
/// signed out or there is none. It changes when such a notice arrives.
final ongoingNoticeSignalProvider = Provider<String?>((ref) {
  final uid = ref.watch(notificationUserIdProvider);
  if (uid == null) return null;
  return ref.watch(
    notificationsControllerProvider(uid).select((s) {
      for (final n in s.notifications) {
        if (ongoingNoticeKind(n.kindKey)) return n.id;
      }
      return null;
    }),
  );
});

class OngoingController extends StateNotifier<OngoingState>
    with WidgetsBindingObserver {
  OngoingController(this._ref) : super(const OngoingState()) {
    WidgetsBinding.instance.addObserver(this);
    try {
      _ref.listen<String?>(ongoingNoticeSignalProvider, (prev, next) {
        if (next != null && next != prev) _onNotice();
      });
    } catch (_) {
      // No inbox (signed out, no client): the timer and resume still read.
    }
    load();
  }

  final Ref _ref;
  Timer? _boundary;
  Timer? _debounce;
  int _request = 0;

  /// The one retry after a failed read is spent; reset by a good read.
  bool _retried = false;

  /// When each closed or cancelled event was first seen closed; the server
  /// drops it [NotificationTiming.ongoingClosedExpiry] after its close.
  final Map<String, DateTime> _closedSeen = <String, DateTime>{};

  DateTime _now() => _ref.read(lifecycleClockProvider)();

  void _onNotice() {
    _debounce?.cancel();
    _debounce = Timer(NotificationTiming.ongoingNoticeDebounce, load);
  }

  /// Reads the server and re-arms the boundary timer. A failed read keeps
  /// what is shown and arms one retry instead.
  Future<void> load() async {
    final request = ++_request;
    List<OngoingEvent>? fresh;
    try {
      final r = await _ref.read(ongoingRepositoryProvider).read();
      fresh = r.fold((_) => null, (v) => v);
    } catch (_) {
      fresh = null;
    }
    if (!mounted || request != _request) return;
    _boundary?.cancel();
    _boundary = null;
    if (fresh == null) {
      // Never re-arm from stale data: a single retry; after that the next
      // resume or notice reads again.
      if (!_retried) {
        _retried = true;
        _boundary = Timer(NotificationTiming.ongoingRetryAfterFailure, load);
      }
      return;
    }
    _retried = false;
    final now = _now();
    state = OngoingState(events: orderOngoing(fresh, now));
    _arm(now);
  }

  void _arm(DateTime now) {
    final closedIds = <String>{
      for (final e in state.events)
        if (e.isClosed) e.eventId,
    };
    _closedSeen.removeWhere((id, _) => !closedIds.contains(id));
    for (final id in closedIds) {
      _closedSeen.putIfAbsent(id, () => now);
    }
    DateTime? next;
    void consider(DateTime t) {
      if (t.isAfter(now) && (next == null || t.isBefore(next!))) next = t;
    }

    for (final e in state.events) {
      e.boundaries.forEach(consider);
    }
    for (final seen in _closedSeen.values) {
      consider(seen.add(NotificationTiming.ongoingClosedExpiry));
    }
    final at = next;
    if (at == null) return;
    // A second past the boundary, so the server's now() is past it too.
    _boundary = Timer(
      at.difference(now) + NotificationTiming.lifecycleBoundarySlack,
      load,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) load();
  }

  @override
  void dispose() {
    _boundary?.cancel();
    _debounce?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}

final ongoingControllerProvider =
    StateNotifierProvider.autoDispose<OngoingController, OngoingState>(
      OngoingController.new,
    );
