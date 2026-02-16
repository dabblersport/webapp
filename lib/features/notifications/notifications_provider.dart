import 'dart:developer' as dev;

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:dabbler/data/models/notifications/notification_model.dart';
import 'package:dabbler/features/notifications/data/notification_realtime_service.dart';

/// Holds notification state and drives the realtime subscription lifecycle.
///
/// Usage:
/// ```dart
/// final provider = NotificationProvider();
/// provider.init();          // call once after login
/// provider.dispose();       // call on logout / widget teardown
/// ```
class NotificationProvider extends ChangeNotifier {
  NotificationProvider({
    SupabaseClient? client,
    NotificationRealtimeService? realtimeService,
  }) : _client = client ?? Supabase.instance.client,
       _realtimeService =
           realtimeService ?? NotificationRealtimeService(client: client);

  final SupabaseClient _client;
  final NotificationRealtimeService _realtimeService;

  // ──────────────────────────── State ────────────────────────────

  List<NotificationModel> _notifications = [];
  bool _isLoading = false;
  String? _error;

  /// Newest-first list of notifications.
  List<NotificationModel> get notifications =>
      List.unmodifiable(_notifications);

  /// Number of unread notifications.
  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  /// Whether the initial fetch is in progress.
  bool get isLoading => _isLoading;

  /// Last error message, or `null`.
  String? get error => _error;

  // ───────────────────────── Lifecycle ───────────────────────────

  /// Initialise: load existing notifications + start realtime.
  ///
  /// Safe to call multiple times; duplicate subscriptions are avoided
  /// internally by [NotificationRealtimeService].
  Future<void> init() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      dev.log(
        'NotificationProvider.init: no authenticated user – skipping',
        name: 'notifications',
      );
      return;
    }

    await loadInitialNotifications();

    _realtimeService.subscribe(
      userId: userId,
      onNewNotification: _onNewNotification,
    );
  }

  /// Fetch the latest notifications from the database.
  Future<void> loadInitialNotifications({int limit = 50}) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _client
          .from('notifications')
          .select()
          .eq('to_user_id', userId)
          .order('created_at', ascending: false)
          .limit(limit);

      _notifications = (response as List<dynamic>)
          .map((row) => NotificationModel.fromJson(row as Map<String, dynamic>))
          .toList();
    } catch (e, st) {
      _error = 'Failed to load notifications';
      dev.log(
        'NotificationProvider.loadInitialNotifications: $e',
        name: 'notifications',
        error: e,
        stackTrace: st,
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ───────────────────────── Actions ─────────────────────────────

  /// Mark a single notification as read (optimistic + server).
  Future<void> markAsRead(String notificationId) async {
    // Optimistic update.
    final index = _notifications.indexWhere((n) => n.id == notificationId);
    if (index == -1) return;

    final original = _notifications[index];
    if (original.isRead) return;

    _notifications[index] = original.copyWith(
      isRead: true,
      readAt: DateTime.now().toUtc(),
    );
    notifyListeners();

    try {
      await _client
          .from('notifications')
          .update({
            'is_read': true,
            'read_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', notificationId);
    } catch (e, st) {
      // Rollback on failure.
      _notifications[index] = original;
      notifyListeners();
      dev.log(
        'NotificationProvider.markAsRead failed: $e',
        name: 'notifications',
        error: e,
        stackTrace: st,
      );
    }
  }

  /// Mark every notification as read.
  Future<void> markAllAsRead() async {
    final unread = _notifications.where((n) => !n.isRead).toList();
    if (unread.isEmpty) return;

    // Optimistic update.
    final originals = List<NotificationModel>.from(_notifications);
    _notifications = _notifications
        .map(
          (n) => n.isRead
              ? n
              : n.copyWith(isRead: true, readAt: DateTime.now().toUtc()),
        )
        .toList();
    notifyListeners();

    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return;

      await _client
          .from('notifications')
          .update({
            'is_read': true,
            'read_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('to_user_id', userId)
          .eq('is_read', false);
    } catch (e, st) {
      _notifications = originals;
      notifyListeners();
      dev.log(
        'NotificationProvider.markAllAsRead failed: $e',
        name: 'notifications',
        error: e,
        stackTrace: st,
      );
    }
  }

  /// Remove a notification locally (e.g. after swipe-to-dismiss).
  void removeLocally(String notificationId) {
    _notifications.removeWhere((n) => n.id == notificationId);
    notifyListeners();
  }

  // ────────────────────── Realtime callback ──────────────────────

  void _onNewNotification(NotificationModel notification) {
    // Guard against duplicates (race between initial load and realtime).
    if (_notifications.any((n) => n.id == notification.id)) return;

    _notifications.insert(0, notification);
    notifyListeners();
  }

  // ──────────────────────── Cleanup ──────────────────────────────

  @override
  void dispose() {
    _realtimeService.dispose();
    super.dispose();
  }
}
