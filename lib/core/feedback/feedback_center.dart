import 'package:dabbler/core/feedback/feedback_intent.dart';
import 'package:dabbler/core/feedback/presentation_context.dart';
import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

@immutable
class FeedbackCenterState {
  const FeedbackCenterState({
    this.current,
    this.queue = const [],
    this.outbox = const [],
    this.dismissedKeys = const {},
    this.surface = ShellSurface.absent,
    this.branchIndex,
  });

  /// The one entry the Action Area slot holds (or the running Processing
  /// while the shell is absent).
  final FeedbackEntry? current;

  /// Pending, ordered by priority then arrival.
  final List<FeedbackEntry> queue;

  /// Entries routed to the toast presenter and not yet handed over.
  final List<FeedbackEntry> outbox;

  /// User-dismissed dedup keys; suppress Information re-show for the session.
  final Set<String> dismissedKeys;
  final ShellSurface surface;
  final int? branchIndex;

  FeedbackState get visible => current?.state ?? const FeedbackIdle();

  FeedbackCenterState copyWith({
    FeedbackEntry? Function()? current,
    List<FeedbackEntry>? queue,
    List<FeedbackEntry>? outbox,
    Set<String>? dismissedKeys,
    ShellSurface? surface,
    int? Function()? branchIndex,
  }) => FeedbackCenterState(
    current: current != null ? current() : this.current,
    queue: queue ?? this.queue,
    outbox: outbox ?? this.outbox,
    dismissedKeys: dismissedKeys ?? this.dismissedKeys,
    surface: surface ?? this.surface,
    branchIndex: branchIndex != null ? branchIndex() : this.branchIndex,
  );
}

/// The app's semantic feedback layer (APP_ARCHITECTURE.md §3-§6).
///
/// Feature code emits intents; the center owns one current entry, a
/// deterministic priority queue, and the routing of each entry to exactly one
/// presenter. It runs no timers: presenters report back through [consumed].
class FeedbackCenter extends Notifier<FeedbackCenterState> {
  /// Queue cap (plan §6.6).
  static const int maxQueue = 5;

  int _seq = 0;
  int _ids = 0;
  final Set<String> _presented = <String>{};

  @override
  FeedbackCenterState build() => const FeedbackCenterState();

  // ---------------------------------------------------------------- emission

  /// Starts an operation. Returns its id.
  String begin(
    FeedbackProcessing processing, {
    String? key,
    FeedbackScope scope = FeedbackScope.shell,
    String? id,
  }) => _emit(processing, key: key, scope: scope, id: id);

  /// Determinate progress for operation [id]; replaces in place.
  void progress(String id, double value) {
    final e = _find(id);
    if (e == null) return;
    final s = e.state;
    if (s is! FeedbackProcessing) return;
    _replace(id, s.withProgress(value));
  }

  /// Resolves operation [id] with a success Result (same surface).
  void succeed(String id, FeedbackResult result) => _replace(id, result);

  /// Resolves operation [id] with an error Result (same surface).
  void fail(String id, FeedbackResult result) => _replace(id, result);

  /// Emits an Information. Returns its id.
  String inform(
    FeedbackInformation info, {
    String? key,
    FeedbackScope scope = FeedbackScope.shell,
  }) => _emit(info, key: key, scope: scope);

  /// Emits a standalone Result (no prior Processing). Returns its id.
  String announce(
    FeedbackResult result, {
    String? key,
    FeedbackScope scope = FeedbackScope.shell,
  }) => _emit(result, key: key, scope: scope);

  /// Runs [task] as one operation: Processing, then a success or error Result
  /// on the same id. Never throws; returns the task's own [Result].
  ///
  /// [failure] receives a `retry` callback that re-runs the same operation
  /// (same id, same key) — wire it to the error Result's action.
  Future<Result<T, Failure>> run<T>({
    required FeedbackProcessing processing,
    required Future<Result<T, Failure>> Function() task,
    required FeedbackResult Function(T value) success,
    required FeedbackResult Function(Failure failure, VoidCallback retry)
    failure,
    String? key,
    FeedbackScope scope = FeedbackScope.shell,
    String? id,
  }) async {
    final opId = begin(processing, key: key, scope: scope, id: id);
    final guarded = await Result.guard<Result<T, Failure>, Failure>(
      task,
      (e) => Failure.from(e),
    );
    final Result<T, Failure> r = guarded.fold(
      (f) => Err<T, Failure>(f),
      (inner) => inner,
    );
    r.fold(
      (f) => fail(
        opId,
        failure(f, () {
          run<T>(
            processing: processing,
            task: task,
            success: success,
            failure: failure,
            key: key,
            scope: scope,
            id: opId,
          );
        }),
      ),
      (v) => succeed(opId, success(v)),
    );
    return r;
  }

  // ------------------------------------------------------- presenter replies

  /// A presenter finished showing [id] (timeout, action or dismiss).
  void consumed(String id) {
    final cur = state.current;
    if (cur != null && cur.id == id) {
      state = state.copyWith(current: () => null);
    } else {
      state = state.copyWith(
        queue: state.queue.where((e) => e.id != id).toList(),
      );
    }
    _reconcile();
  }

  /// The user dismissed [id]. Action-free dismissible Information records its
  /// dedup key so it is not re-shown this session (plan §6.7, G3).
  void dismiss(String id) {
    final e = _find(id) ?? _inOutbox(id);
    final s = e?.state;
    if (e?.dedupKey != null &&
        s is FeedbackInformation &&
        s.dismissible &&
        s.action == null) {
      state = state.copyWith(
        dismissedKeys: {...state.dismissedKeys, e!.dedupKey!},
      );
    }
    consumed(id);
  }

  /// The toast presenter took [id] from the outbox.
  void delivered(String id) {
    state = state.copyWith(
      outbox: state.outbox.where((e) => e.id != id).toList(),
    );
  }

  // ------------------------------------------------------ context changes

  void setSurface(ShellSurface surface) {
    if (surface == state.surface) return;
    state = state.copyWith(surface: surface);
    _reconcile();
  }

  /// The shell's active branch. A change clears `page`-scoped entries.
  void setBranch(int index) {
    final prev = state.branchIndex;
    state = state.copyWith(branchIndex: () => index);
    if (prev == null || prev == index) return;
    final cur = state.current;
    state = state.copyWith(
      current: () => cur?.scope == FeedbackScope.page ? null : cur,
      queue: state.queue.where((e) => e.scope != FeedbackScope.page).toList(),
    );
    _reconcile();
  }

  // ------------------------------------------------------------- internals

  String _emit(
    FeedbackState s, {
    String? key,
    required FeedbackScope scope,
    String? id,
  }) {
    // Same operation id: replacement, never queueing.
    if (id != null && _find(id) != null) {
      _replace(id, s);
      return id;
    }
    // Dedup by key.
    if (key != null) {
      if (s is FeedbackInformation && state.dismissedKeys.contains(key)) {
        return id ?? _nextId();
      }
      final existing = _findByKey(key);
      if (existing != null) {
        _replace(existing.id, s);
        return existing.id;
      }
    }
    final entry = FeedbackEntry(
      id: id ?? _nextId(),
      state: s,
      seq: ++_seq,
      dedupKey: key,
      scope: scope,
    );
    _arrive(entry);
    return entry.id;
  }

  String _nextId() => 'fb-${++_ids}';

  void _arrive(FeedbackEntry entry) {
    final cur = state.current;
    if (cur == null) {
      state = state.copyWith(current: () => entry);
    } else if (_preempts(entry, cur, arriving: true)) {
      state = state.copyWith(
        current: () => entry,
        queue: _requeue(cur, state.queue),
      );
    } else {
      state = state.copyWith(queue: _insert(entry, state.queue));
    }
    _reconcile();
  }

  /// Whether [a] takes the slot from [cur] (plan §6.3, §6.6).
  bool _preempts(FeedbackEntry a, FeedbackEntry cur, {bool arriving = false}) {
    final cs = cur.state;
    if (cs is FeedbackProcessing) {
      if (a.state is FeedbackResult &&
          (a.state as FeedbackResult).kind == ResultKind.error) {
        return true;
      }
      // Two operations: the newest Processing is current.
      return arriving && a.isProcessing;
    }
    if (cs is FeedbackResult && cs.kind == ResultKind.error) return false;
    return a.priority < cur.priority;
  }

  /// Puts a preempted entry back. Information is kept only when it is
  /// non-dismissible and sticky; otherwise it is dropped.
  List<FeedbackEntry> _requeue(FeedbackEntry e, List<FeedbackEntry> q) {
    final s = e.state;
    if (s is FeedbackInformation &&
        (s.dismissible || s.duration != Duration.zero)) {
      return q;
    }
    return _insert(e.copyWith(target: FeedbackTarget.none), q);
  }

  List<FeedbackEntry> _insert(FeedbackEntry e, List<FeedbackEntry> q) {
    final next = [...q, e]..sort(_order);
    while (next.length > maxQueue) {
      final info = next.indexWhere((x) => x.state is FeedbackInformation);
      final drop = info >= 0
          ? _oldestWhere(next, (x) => x.state is FeedbackInformation)
          : _oldestWhere(next, (x) => !x.isProcessing);
      if (drop < 0) break;
      next.removeAt(drop);
    }
    return next;
  }

  int _oldestWhere(List<FeedbackEntry> q, bool Function(FeedbackEntry) test) {
    var best = -1;
    for (var i = 0; i < q.length; i++) {
      if (test(q[i]) && (best < 0 || q[i].seq < q[best].seq)) best = i;
    }
    return best;
  }

  static int _order(FeedbackEntry a, FeedbackEntry b) {
    final p = a.priority.compareTo(b.priority);
    return p != 0 ? p : a.seq.compareTo(b.seq);
  }

  void _replace(String id, FeedbackState s) {
    final cur = state.current;
    if (cur != null && cur.id == id) {
      // In place: the morph. A resolved op loses the "presented" mark only if
      // it is re-presented by the reconcile below.
      _presented.remove(id);
      state = state.copyWith(
        current: () => cur.copyWith(state: s, target: FeedbackTarget.none),
      );
    } else {
      final q = state.queue
          .map((e) => e.id == id ? e.copyWith(state: s) : e)
          .toList();
      state = state.copyWith(queue: q..sort(_order));
      final head = state.queue.where((e) => e.id == id).firstOrNull;
      final c = state.current;
      if (head != null && c != null && _preempts(head, c)) {
        state = state.copyWith(
          current: () => head,
          queue: _requeue(c, state.queue.where((e) => e.id != id).toList()),
        );
      }
    }
    _reconcile();
  }

  /// Applies the surface: fills the slot and routes every entry to exactly
  /// one presenter (plan §5).
  void _reconcile() {
    var cur = state.current;
    var queue = [...state.queue];
    final outbox = [...state.outbox];

    if (state.surface == ShellSurface.absent) {
      // Information/Result go to the standard toast, once, in arrival order.
      final moved = <FeedbackEntry>[
        if (cur != null && !cur.isProcessing) cur,
        ...queue.where((e) => !e.isProcessing),
      ]..sort((a, b) => a.seq.compareTo(b.seq));
      for (final e in moved) {
        if (_presented.add(e.id)) {
          outbox.add(e.copyWith(target: FeedbackTarget.toast));
        }
      }
      queue = queue.where((e) => e.isProcessing).toList();
      if (cur != null && !cur.isProcessing) cur = null;
      if (cur == null && queue.isNotEmpty) {
        // Newest running operation holds the (invisible) slot.
        queue.sort((a, b) => b.seq.compareTo(a.seq));
        cur = queue.removeAt(0);
        queue.sort(_order);
      }
      if (cur != null) cur = cur.copyWith(target: FeedbackTarget.none);
    } else {
      if (cur == null && queue.isNotEmpty) cur = queue.removeAt(0);
      if (cur != null) {
        final t = state.surface == ShellSurface.current
            ? FeedbackTarget.actionArea
            : FeedbackTarget.hold;
        if (t == FeedbackTarget.actionArea) _presented.add(cur.id);
        cur = cur.copyWith(target: t);
      }
    }
    state = state.copyWith(current: () => cur, queue: queue, outbox: outbox);
  }

  FeedbackEntry? _find(String id) {
    final c = state.current;
    if (c != null && c.id == id) return c;
    return state.queue.where((e) => e.id == id).firstOrNull;
  }

  FeedbackEntry? _inOutbox(String id) =>
      state.outbox.where((e) => e.id == id).firstOrNull;

  FeedbackEntry? _findByKey(String key) {
    final c = state.current;
    if (c != null && c.dedupKey == key) return c;
    return state.queue.where((e) => e.dedupKey == key).firstOrNull;
  }
}

final feedbackCenterProvider =
    NotifierProvider<FeedbackCenter, FeedbackCenterState>(FeedbackCenter.new);
