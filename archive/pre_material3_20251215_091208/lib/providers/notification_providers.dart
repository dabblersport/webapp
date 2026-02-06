import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/notifications/notification_item.dart';
import '../services/notifications/notification_service.dart';

/// Provides the shared [SupabaseClient] instance.
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

/// NotificationService wired to the shared Supabase client.
final notificationServiceProvider = Provider<NotificationService>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return NotificationService(client);
});

/// Stream of the current user's inbox notifications from `v_notifications`.
final inboxStreamProvider = StreamProvider.autoDispose<List<NotificationItem>>((
  ref,
) {
  final service = ref.watch(notificationServiceProvider);
  return service.watchInbox();
});

/// Stream of the current user's unread notification count from `v_unread_counts`.
final unreadCountProvider = StreamProvider.autoDispose<int>((ref) {
  final service = ref.watch(notificationServiceProvider);
  return service.watchUnreadCount();
});
