import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:dabbler/core/cache/cache_providers.dart'
    show cacheAccountIdProvider;

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

/// KAN-987: the signed-in user the inbox belongs to. Follows the auth
/// session (sign-in, sign-out, account switch); null when signed out.
final notificationUserIdProvider = Provider<String?>(
  (ref) => ref.watch(cacheAccountIdProvider),
);

/// Per-user realtime INSERT and UPDATE subscription, one service per user so
/// tearing down one account's channel never touches another's.
///
/// Must NOT be autoDispose — the controller that depends on it is a
/// `.family` provider (not autoDispose). Mismatched lifecycles caused
/// the realtime channel to be torn down while the controller was still
/// alive, silently killing the subscription.
final notificationRealtimeServiceProvider =
    Provider.family<NotificationRealtimeService, String>((ref, userId) {
      final service = NotificationRealtimeService();
      ref.onDispose(service.dispose);
      return service;
    });

// ════════════════════════════════════════════════════════════════════════════
// Controller provider (family by userId)
// ════════════════════════════════════════════════════════════════════════════

/// Notification list + pagination + realtime, keyed by the authenticated user.
///
/// KAN-987: rebuilt when the auth user changes. For a user who is no longer
/// signed in it is an empty controller with no subscription, so a sign-out or
/// an account switch clears the list, the count and the channel.
final notificationsControllerProvider =
    StateNotifierProvider.family<
      NotificationsController,
      NotificationsState,
      String
    >((ref, userId) {
      final repository = ref.watch(notificationsRepositoryProvider);
      final realtimeService = ref.watch(
        notificationRealtimeServiceProvider(userId),
      );
      final signedIn = ref.watch(notificationUserIdProvider) == userId;
      return NotificationsController(
        repository: repository,
        realtimeService: realtimeService,
        userId: userId,
        enabled: signedIn,
      );
    });

// ════════════════════════════════════════════════════════════════════════════
// Derived / convenience providers
// ════════════════════════════════════════════════════════════════════════════

/// The bell badge: the server's unread count for the signed-in user.
///
/// Usage: `ref.watch(unreadNotificationCountProvider)` (the Home header and
/// [NotificationBadge] read it). KAN-987: it follows the auth user, so it
/// changes on sign-in, sign-out and account switch without a reload, and
/// with every Realtime row and read. `0` when signed out.
final unreadNotificationCountProvider = Provider<int>((ref) {
  final userId = ref.watch(notificationUserIdProvider);
  if (userId == null) return 0;
  final state = ref.watch(notificationsControllerProvider(userId));
  return state.unreadCount;
});
