import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/notification_model.dart';
import '../../data/notification_realtime_service.dart';
import '../../data/notifications_repository.dart';

// ════════════════════════════════════════════════════════════════════════════
// State
// ════════════════════════════════════════════════════════════════════════════

class NotificationsState {
  const NotificationsState({
    this.notifications = const [],
    this.isLoading = false,
    this.hasMore = true,
    this.error,
    this.unreadCount = 0,
    this.loadedAt,
  });

  final List<AppNotification> notifications;
  final bool isLoading;
  final bool hasMore;
  final String? error;

  /// KAN-987: the server's unread count (a HEAD count query), not the loaded
  /// pages; kept current by Realtime and the read mutations.
  final int unreadCount;

  /// KAN-989: when the list last loaded from the server (the offline banner's
  /// "saved at"); null before the first load.
  final DateTime? loadedAt;

  /// [createdAt] of the last item — used as keyset cursor for the next page.
  DateTime? get cursor =>
      notifications.isNotEmpty ? notifications.last.createdAt : null;

  List<AppNotification> get unreadNotifications =>
      notifications.where((n) => !n.isRead).toList();

  NotificationsState copyWith({
    List<AppNotification>? notifications,
    bool? isLoading,
    bool? hasMore,
    String? error,
    int? unreadCount,
    DateTime? loadedAt,
  }) {
    return NotificationsState(
      notifications: notifications ?? this.notifications,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      error: error,
      unreadCount: unreadCount ?? this.unreadCount,
      loadedAt: loadedAt ?? this.loadedAt,
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Controller
// ════════════════════════════════════════════════════════════════════════════

/// Manages the notification list, keyset pagination, optimistic mutations,
/// and realtime inserts and in-place updates via [NotificationRealtimeService].
///
/// [enabled] false (the signed-in user is not [userId]: signed out or another
/// account) is an empty controller: no load, no count, no subscription.
class NotificationsController extends StateNotifier<NotificationsState>
    with WidgetsBindingObserver {
  NotificationsController({
    required NotificationsRepository repository,
    required NotificationRealtimeService realtimeService,
    required String userId,
    bool enabled = true,
  }) : _repository = repository,
       _realtimeService = realtimeService,
       _userId = userId,
       _enabled = enabled,
       super(const NotificationsState(hasMore: false)) {
    if (_enabled) _init();
  }

  final NotificationsRepository _repository;
  final NotificationRealtimeService _realtimeService;
  final String _userId;
  final bool _enabled;

  static const _pageSize = 20;

  /// Bumped by every count request; an older answer is dropped.
  int _countRequest = 0;

  // ── Lifecycle ────────────────────────────────────────────────────────

  void _init() {
    loadNotifications();
    _subscribe();
    // Watch app lifecycle so we can re-subscribe when returning from
    // background (iOS kills websocket connections when suspended).
    WidgetsBinding.instance.addObserver(this);
  }

  // The base signature names this parameter `state`, which would shadow
  // StateNotifier.state inside the method body. Renamed deliberately.
  @override
  // ignore: avoid_renaming_method_parameters
  void didChangeAppLifecycleState(AppLifecycleState lifecycleState) {
    if (lifecycleState == AppLifecycleState.resumed) {
      // Re-subscribe realtime (no-op if already connected for same user,
      // but forces reconnect if the channel was dropped while suspended).
      _realtimeService.unsubscribe();
      _subscribe();
      // Fetch latest notifications to catch anything missed while suspended.
      refresh();
    }
  }

  void _subscribe() => _realtimeService.subscribe(
    userId: _userId,
    onNewNotification: _onRealtimeInsert,
    onUpdatedNotification: _onRealtimeUpdate,
  );

  @override
  void dispose() {
    if (_enabled) {
      WidgetsBinding.instance.removeObserver(this);
      _realtimeService.unsubscribe();
    }
    super.dispose();
  }

  // ── Unread count (server) ────────────────────────────────────────────

  /// Re-reads the unread count from the server; a failure keeps the last one.
  Future<void> refreshUnreadCount() async {
    if (!_enabled) return;
    final request = ++_countRequest;
    final result = await _repository.getUnreadCount();
    if (!mounted || request != _countRequest) return;
    result.fold(
      (failure) =>
          debugPrint('[Notifications] COUNT ERROR: ${failure.message}'),
      (count) => state = state.copyWith(unreadCount: count, error: state.error),
    );
  }

  /// Sets the count now (optimistic); a pending server answer is dropped.
  void _setCount(int count) {
    _countRequest++;
    state = state.copyWith(
      unreadCount: count < 0 ? 0 : count,
      error: state.error,
    );
  }

  // ── Load / Paginate ──────────────────────────────────────────────────

  /// Initial load or pull-to-refresh (pass `refresh: true`).
  Future<void> loadNotifications({bool refresh = false}) async {
    if (!_enabled || state.isLoading) return;

    // KAN-989: a refresh keeps the list on screen while it runs, and when it
    // fails (the Center shows "Couldn't refresh" over the earlier list).
    state = state.copyWith(isLoading: true, error: null);

    debugPrint(
      '[Notifications] loading page, refresh=$refresh, cursor=${refresh ? null : state.cursor}',
    );
    final result = await _repository.getPage(
      limit: _pageSize,
      cursor: refresh ? null : state.cursor,
    );

    result.fold(
      (failure) {
        debugPrint('[Notifications] FETCH ERROR: ${failure.message}');
        state = state.copyWith(isLoading: false, error: failure.message);
      },
      (page) {
        debugPrint('[Notifications] loaded ${page.length} items');
        final merged = refresh ? page : [...state.notifications, ...page];
        state = state.copyWith(
          notifications: merged,
          isLoading: false,
          hasMore: page.length >= _pageSize,
          error: null,
          loadedAt: DateTime.now(),
        );
      },
    );
    await refreshUnreadCount();
  }

  /// Append next page (infinite scroll).
  Future<void> loadMore() async {
    if (state.isLoading || !state.hasMore) return;
    await loadNotifications();
  }

  /// Pull-to-refresh.
  Future<void> refresh() => loadNotifications(refresh: true);

  // ── Mutations (optimistic) ───────────────────────────────────────────

  /// Mark a single notification as read — optimistic then server.
  Future<void> markAsRead(String id) async {
    final idx = state.notifications.indexWhere((n) => n.id == id);
    if (idx == -1) return;
    final original = state.notifications[idx];
    if (original.isRead) return;

    // Optimistic
    final updated = List<AppNotification>.from(state.notifications);
    updated[idx] = original.copyWith(
      isRead: true,
      readAt: DateTime.now().toUtc(),
    );
    state = state.copyWith(notifications: updated);
    _setCount(state.unreadCount - 1);

    // Server (writes is_read and read_at only: the columns authenticated may
    // update since KAN-974b).
    final result = await _repository.markAsRead(id);
    if (!mounted) return;
    if (result.isFailure) {
      // Rollback
      final rollback = List<AppNotification>.from(state.notifications);
      final at = rollback.indexWhere((n) => n.id == id);
      if (at != -1) rollback[at] = original;
      state = state.copyWith(notifications: rollback);
      _setCount(state.unreadCount + 1);
    }
    await refreshUnreadCount();
  }

  /// Record a click / interaction — optimistic then server.
  Future<void> markClicked(String id) async {
    final idx = state.notifications.indexWhere((n) => n.id == id);
    if (idx == -1) return;

    final original = state.notifications[idx];
    final updated = List<AppNotification>.from(state.notifications);
    updated[idx] = original.copyWith(
      clickedAt: DateTime.now().toUtc(),
      interactionCount: original.interactionCount + 1,
    );
    state = state.copyWith(notifications: updated);

    final result = await _repository.markClicked(id);
    if (result.isFailure) {
      final rollback = List<AppNotification>.from(state.notifications);
      rollback[idx] = original;
      state = state.copyWith(notifications: rollback);
    }
  }

  /// Mark all unread as read — optimistic then server.
  Future<void> markAllRead() async {
    final originals = List<AppNotification>.from(state.notifications);
    final updated = state.notifications
        .map(
          (n) => n.isRead
              ? n
              : n.copyWith(isRead: true, readAt: DateTime.now().toUtc()),
        )
        .toList();
    final before = state.unreadCount;
    state = state.copyWith(notifications: updated);
    _setCount(0);

    // Writes is_read and read_at only (KAN-974b column grant).
    final result = await _repository.markAllRead();
    if (!mounted) return;
    if (result.isFailure) {
      state = state.copyWith(notifications: originals);
      _setCount(before);
    }
    await refreshUnreadCount();
  }

  // ── Filtering helpers ────────────────────────────────────────────────

  /// Filter by `kind_key` prefix (e.g. `'social'`, `'games'`).
  List<AppNotification> filterByKind(String? kindPrefix) {
    if (kindPrefix == null || kindPrefix.isEmpty) return state.notifications;
    return state.notifications
        .where((n) => n.kindKey.startsWith(kindPrefix))
        .toList();
  }

  // ── Realtime callback ───────────────────────────────────────────────

  void _onRealtimeInsert(AppNotification notification) {
    if (!mounted) return;
    // The same row twice (a resubscribe, an insert after a refresh) is one.
    if (state.notifications.any((n) => n.id == notification.id)) {
      _onRealtimeUpdate(notification);
      return;
    }
    state = state.copyWith(
      notifications: _placed(state.notifications, notification),
    );
    if (!notification.isRead) _setCount(state.unreadCount + 1);
    refreshUnreadCount();
  }

  /// KAN-987: a row changed in place (G-01): a grouped row with a new actor
  /// (it can turn unread again and move to the top), or a read made on
  /// another device. The row is replaced and re-placed by its time; a row
  /// not loaded yet is added when it now falls inside the loaded range.
  void _onRealtimeUpdate(AppNotification notification) {
    if (!mounted) return;
    final current = state.notifications;
    final idx = current.indexWhere((n) => n.id == notification.id);
    final previous = idx == -1 ? null : current[idx];
    final rest = [
      for (final n in current)
        if (n.id != notification.id) n,
    ];
    final oldest = current.isEmpty ? null : current.last.createdAt;
    final inRange =
        previous != null ||
        oldest == null ||
        !notification.createdAt.isBefore(oldest);
    if (inRange) {
      state = state.copyWith(notifications: _placed(rest, notification));
    }
    final wasUnread = previous == null ? null : !previous.isRead;
    if (wasUnread != null && wasUnread != !notification.isRead) {
      _setCount(state.unreadCount + (notification.isRead ? -1 : 1));
    }
    refreshUnreadCount();
  }

  /// [list] (newest first) with [n] at its place by `created_at`.
  static List<AppNotification> _placed(
    List<AppNotification> list,
    AppNotification n,
  ) {
    final at = list.indexWhere((x) => x.createdAt.isBefore(n.createdAt));
    return [
      ...list.take(at == -1 ? list.length : at),
      n,
      ...list.skip(at == -1 ? list.length : at),
    ];
  }
}
