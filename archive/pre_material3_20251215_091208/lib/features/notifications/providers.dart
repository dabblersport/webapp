import 'package:dabbler/core/fp/failure.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:dabbler/data/models/notification.dart';
import '../../data/repositories/notifications_repository.dart';
import '../../data/repositories/notifications_repository_impl.dart';
import '../../features/misc/data/datasources/supabase_remote_data_source.dart';
import 'package:dabbler/core/fp/result.dart';

final notificationsRepositoryProvider = Provider<NotificationsRepository>((
  ref,
) {
  final svc = ref.read(supabaseServiceProvider);
  return NotificationsRepositoryImpl(svc);
});

/// Stream of latest notifications for the authenticated user.
final notificationsStreamProvider =
    StreamProvider.autoDispose<List<AppNotification>>((ref) {
      final repo = ref.watch(notificationsRepositoryProvider);
      return repo.watchUserNotifications(limit: 50);
    });

/// One-shot fetch (e.g., for pull-to-refresh).
final notificationsLatestProvider =
    FutureProvider.autoDispose<Result<List<AppNotification>, Failure>>((
      ref,
    ) async {
      final repo = ref.read(notificationsRepositoryProvider);
      return repo.getLatest(limit: 50);
    });

/// Mark a single notification as read.
final markNotificationReadProvider = FutureProvider.family
    .autoDispose<Result<int, Failure>, String>((ref, id) async {
      final repo = ref.read(notificationsRepositoryProvider);
      return repo.markAsRead(id);
    });

/// Mark all notifications as read (optionally before a timestamp).
final markAllNotificationsReadProvider = FutureProvider.family
    .autoDispose<Result<int, Failure>, DateTime?>((ref, before) async {
      final repo = ref.read(notificationsRepositoryProvider);
      return repo.markAllAsRead(before: before);
    });

/// Convenience to expose current user id if needed by UI (optional).
final currentUserIdProvider = Provider<String?>((ref) {
  return Supabase.instance.client.auth.currentUser?.id;
});
