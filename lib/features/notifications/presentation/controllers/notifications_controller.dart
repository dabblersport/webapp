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
  });

  final List<AppNotification> notifications;
  final bool isLoading;
  final bool hasMore;
  final String? error;
  final int unreadCount;

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
  }) {
    return NotificationsState(
      notifications: notifications ?? this.notifications,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      error: error,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Controller
// ════════════════════════════════════════════════════════════════════════════

/// Manages the notification list, keyset pagination, optimistic mutations,
/// and realtime prepend via [NotificationRealtimeService].
class NotificationsController extends StateNotifier<NotificationsState>
    with WidgetsBindingObserver {
  NotificationsController({
    required NotificationsRepository repository,
    required NotificationRealtimeService realtimeService,
    required String userId,
  }) : _repository = repository,
       _realtimeService = realtimeService,
       _userId = userId,
       super(const NotificationsState()) {
    _init();
  }

  final NotificationsRepository _repository;
  final NotificationRealtimeService _realtimeService;
  final String _userId;

  static const _pageSize = 20;

  // ── Lifecycle ────────────────────────────────────────────────────────

  void _init() {
    loadNotifications();
    _realtimeService.subscribe(
      userId: _userId,
      onNewNotification: _onRealtimeInsert,
    );
    // Watch app lifecycle so we can re-subscribe when returning from
    // background (iOS kills websocket connections when suspended).
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycleState) {
    if (lifecycleState == AppLifecycleState.resumed) {
      // Re-subscribe realtime (no-op if already connected for same user,
      // but forces reconnect if the channel was dropped while suspended).
      _realtimeService.unsubscribe();
      _realtimeService.subscribe(
        userId: _userId,
        onNewNotification: _onRealtimeInsert,
      );
      // Fetch latest notifications to catch anything missed while suspended.
      refresh();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _realtimeService.unsubscribe();
    super.dispose();
  }

  // ── Load / Paginate ──────────────────────────────────────────────────

  /// Initial load or pull-to-refresh (pass `refresh: true`).
  Future<void> loadNotifications({bool refresh = false}) async {
    if (state.isLoading) return;

    if (refresh) {
      state = const NotificationsState(isLoading: true);
    } else {
      state = state.copyWith(isLoading: true, error: null);
    }

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
          unreadCount: merged.where((n) => !n.isRead).length,
          error: null,
        );
      },
    );
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
    state = state.copyWith(
      notifications: updated,
      unreadCount: updated.where((n) => !n.isRead).length,
    );

    // Server
    final result = await _repository.markAsRead(id);
    if (result.isFailure) {
      // Rollback
      final rollback = List<AppNotification>.from(state.notifications);
      rollback[idx] = original;
      state = state.copyWith(
        notifications: rollback,
        unreadCount: rollback.where((n) => !n.isRead).length,
      );
    }
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
    state = state.copyWith(notifications: updated, unreadCount: 0);

    final result = await _repository.markAllRead();
    if (result.isFailure) {
      state = state.copyWith(
        notifications: originals,
        unreadCount: originals.where((n) => !n.isRead).length,
      );
    }
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
    // Guard against duplicates.
    if (state.notifications.any((n) => n.id == notification.id)) return;

    final updated = [notification, ...state.notifications];
    state = state.copyWith(
      notifications: updated,
      unreadCount: updated.where((n) => !n.isRead).length,
    );
  }
}
