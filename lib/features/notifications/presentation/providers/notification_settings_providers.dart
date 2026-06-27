import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/notification_settings_repository.dart';
import '../../data/notification_settings_repository_impl.dart';
import '../controllers/notification_settings_controller.dart';

/// Supabase-backed repository for `public.notification_settings`.
final notificationSettingsRepositoryProvider =
    Provider<NotificationSettingsRepository>((ref) {
  return NotificationSettingsRepositoryImpl(Supabase.instance.client);
});

/// Notification preferences controller (loads on first watch, persists on
/// every mutation). AutoDispose: the settings screen is the only consumer.
final notificationSettingsControllerProvider = StateNotifierProvider.autoDispose<
    NotificationSettingsController, NotificationSettingsState>((ref) {
  return NotificationSettingsController(
    ref.watch(notificationSettingsRepositoryProvider),
  );
});
