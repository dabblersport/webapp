import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/notifications_repository.dart';

/// State for notifications with pagination support
class NotificationsState {
  final List<NotificationItem> notifications;
  final bool isLoading;
  final bool hasMore;
  final String? error;
  final NotificationCursor? cursor;
  final int unreadCount;

  const NotificationsState({
    this.notifications = const [],
    this.isLoading = false,
    this.hasMore = true,
    this.error,
    this.cursor,
    this.unreadCount = 0,
  });

  NotificationsState copyWith({
    List<NotificationItem>? notifications,
    bool? isLoading,
    bool? hasMore,
    String? error,
    NotificationCursor? cursor,
    int? unreadCount,
  }) {
    return NotificationsState(
      notifications: notifications ?? this.notifications,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      error: error,
      cursor: cursor ?? this.cursor,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }

  List<NotificationItem> get unreadNotifications =>
      notifications.where((n) => !n.isRead).toList();
}

/// Controller for notifications with keyset pagination and realtime
class NotificationsController extends StateNotifier<NotificationsState> {
  final NotificationsRepository _repository;
  final String _userId;
  StreamSubscription<NotificationItem>? _realtimeSub;

  NotificationsController({
    required NotificationsRepository repository,
    required String userId,
  }) : _repository = repository,
       _userId = userId,
       super(const NotificationsState()) {
    _init();
  }

  void _init() {
    // Load initial notifications
    loadNotifications();

    // Subscribe to realtime updates
    _realtimeSub = _repository
        .subscribeUserNotifications(_userId)
        .listen(
          (notification) {
            // Handle INSERT: prepend new notification
            if (!state.notifications.any(
              (item) => item.id == notification.id,
            )) {
              final updatedList = [notification, ...state.notifications];
              final unreadCount = updatedList.where((n) => !n.isRead).length;

              state = state.copyWith(
                notifications: updatedList,
                unreadCount: unreadCount,
              );
            } else {
              // Handle UPDATE: patch existing item
              final index = state.notifications.indexWhere(
                (item) => item.id == notification.id,
              );
              if (index != -1) {
                final updatedList = [...state.notifications];
                updatedList[index] = notification;
                final unreadCount = updatedList.where((n) => !n.isRead).length;

                state = state.copyWith(
                  notifications: updatedList,
                  unreadCount: unreadCount,
                );
              }
            }
          },
          onError: (error) {
            state = state.copyWith(error: error.toString());
          },
        );
  }

  /// Load notifications (initial or refresh)
  Future<void> loadNotifications({bool refresh = false}) async {
    if (state.isLoading) return;

    if (refresh) {
      state = const NotificationsState(isLoading: true);
    } else {
      state = state.copyWith(isLoading: true, error: null);
    }

    try {
      final notifications = await _repository.list(
        userId: _userId,
        limit: 20,
        cursor: refresh ? null : state.cursor,
      );

      if (notifications.isEmpty) {
        state = state.copyWith(isLoading: false, hasMore: false);
      } else {
        final updatedList = refresh
            ? notifications
            : [...state.notifications, ...notifications];
        final unreadCount = updatedList.where((n) => !n.isRead).length;

        state = state.copyWith(
          notifications: updatedList,
          cursor: notifications.last.cursor,
          isLoading: false,
          hasMore: notifications.length >= 20,
          unreadCount: unreadCount,
          error: null,
        );
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Load more notifications (pagination)
  Future<void> loadMore() async {
    if (state.isLoading || !state.hasMore) return;
    await loadNotifications();
  }

  /// Refresh notifications (pull to refresh)
  Future<void> refresh() async {
    await loadNotifications(refresh: true);
  }

  /// Mark notification as read
  Future<void> markAsRead(String notificationId) async {
    try {
      await _repository.markRead(notificationId: notificationId);
      // Update will come via realtime subscription
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// Mark all notifications as read
  Future<void> markAllAsRead() async {
    try {
      await _repository.markAllReadForUser(userId: _userId);
      // Updates will come via realtime subscription
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// Delete notification
  Future<void> deleteNotification(String notificationId) async {
    try {
      await _repository.delete(notificationId: notificationId);

      // Remove from local state
      final updatedList = state.notifications
          .where((n) => n.id != notificationId)
          .toList();
      final unreadCount = updatedList.where((n) => !n.isRead).length;

      state = state.copyWith(
        notifications: updatedList,
        unreadCount: unreadCount,
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// Filter notifications by type
  List<NotificationItem> filterByType(NotificationType? type) {
    if (type == null) return state.notifications;
    return state.notifications.where((n) => n.type == type).toList();
  }

  /// Filter notifications by priority
  List<NotificationItem> filterByPriority(NotificationPriority? priority) {
    if (priority == null) return state.notifications;
    return state.notifications.where((n) => n.priority == priority).toList();
  }

  /// Filter unread notifications
  List<NotificationItem> get unreadNotifications {
    return state.notifications.where((n) => !n.isRead).toList();
  }

  @override
  void dispose() {
    _realtimeSub?.cancel();
    super.dispose();
  }
}
