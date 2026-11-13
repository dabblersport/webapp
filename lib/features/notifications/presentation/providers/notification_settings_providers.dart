import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dabbler/core/cache/cache_providers.dart';
import 'package:dabbler/core/sync/settings_sync.dart';
import 'package:dabbler/core/sync/settings_sync_handlers.dart';
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
final notificationSettingsControllerProvider =
    StateNotifierProvider.autoDispose<
      NotificationSettingsController,
      NotificationSettingsState
    >((ref) {
      final sync = ref.watch(settingsSyncProvider.notifier);
      final controller = NotificationSettingsController(
        ref.watch(notificationSettingsRepositoryProvider),
        sync: sync,
        accountId: ref.watch(cacheAccountIdProvider),
      );
      // KAN-608: the server held a newer value; show it.
      final adopted = sync.adopted.listen((key) {
        if (key == SettingKeys.notifications) controller.load();
      });
      ref.onDispose(adopted.cancel);
      return controller;
    });
