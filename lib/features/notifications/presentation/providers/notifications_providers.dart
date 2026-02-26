import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/notification_realtime_service.dart';
import '../../data/notifications_repository.dart';
import '../../data/notifications_repository_impl.dart';
import '../controllers/notifications_controller.dart';

// ════════════════════════════════════════════════════════════════════════════
// Data-layer providers
// ════════════════════════════════════════════════════════════════════════════

/// Supabase-backed repository for `public.notifications`.
final notificationsRepositoryProvider = Provider<NotificationsRepository>((
  ref,
) {
  return NotificationsRepositoryImpl(Supabase.instance.client);
});

/// Per-user realtime INSERT subscription.
///
/// Must NOT be autoDispose — the controller that depends on it is a
/// `.family` provider (not autoDispose). Mismatched lifecycles caused
/// the realtime channel to be torn down while the controller was still
/// alive, silently killing the subscription.
final notificationRealtimeServiceProvider =
    Provider<NotificationRealtimeService>((ref) {
      final service = NotificationRealtimeService();
      ref.onDispose(service.dispose);
      return service;
    });

// ════════════════════════════════════════════════════════════════════════════
// Controller provider (family by userId)
// ════════════════════════════════════════════════════════════════════════════

/// Notification list + pagination + realtime, keyed by the authenticated user.
final notificationsControllerProvider =
    StateNotifierProvider.family<
      NotificationsController,
      NotificationsState,
      String
    >((ref, userId) {
      final repository = ref.watch(notificationsRepositoryProvider);
      final realtimeService = ref.watch(notificationRealtimeServiceProvider);
      return NotificationsController(
        repository: repository,
        realtimeService: realtimeService,
        userId: userId,
      );
    });

// ════════════════════════════════════════════════════════════════════════════
// Derived / convenience providers
// ════════════════════════════════════════════════════════════════════════════

/// Unread badge count — derived from the controller state for the current user.
///
/// Usage: `ref.watch(unreadNotificationCountProvider)`.
/// Returns `0` when no user is authenticated.
final unreadNotificationCountProvider = Provider<int>((ref) {
  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId == null) return 0;
  final state = ref.watch(notificationsControllerProvider(userId));
  return state.unreadCount;
});
