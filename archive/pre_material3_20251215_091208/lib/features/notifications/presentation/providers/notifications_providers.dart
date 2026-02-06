import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/notifications_repository.dart';
import '../controllers/notifications_controller_v2.dart';

/// Provider for the new notifications repository with keyset pagination and realtime
final notificationsRepositoryProvider = Provider<NotificationsRepository>((
  ref,
) {
  return NotificationsRepository(Supabase.instance.client);
});

/// Family provider for notifications controller (by user ID)
/// Uses the new NotificationsController with pagination and realtime support
final notificationsControllerProvider =
    StateNotifierProvider.family<
      NotificationsController,
      NotificationsState,
      String
    >((ref, userId) {
      final repository = ref.watch(notificationsRepositoryProvider);
      return NotificationsController(repository: repository, userId: userId);
    });
