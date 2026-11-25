import 'package:firebase_messaging/firebase_messaging.dart'
    show AuthorizationStatus;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart' show Geolocator;
import 'package:dabbler/core/cache/cache_providers.dart';
import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/core/sync/settings_sync.dart';
import 'package:dabbler/core/sync/settings_sync_handlers.dart';
import 'package:dabbler/features/messaging/domain/models/my_conversation.dart';
import 'package:dabbler/features/messaging/presentation/providers/messages_list_providers.dart';
import 'package:dabbler/services/notifications/push_notification_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/notification_channels_repository.dart';
import '../../data/notification_settings_repository.dart';
import '../../data/notification_settings_repository_impl.dart';
import '../controllers/notification_channels_controller.dart';
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

/// KAN-991: true when the phone's notification permission for Dabbler is
/// denied. The push switches are then disabled and a banner leads to the
/// system settings; in-app switches keep working. Invalidate to re-read (on
/// resume).
final notificationOsPushDeniedProvider = FutureProvider.autoDispose<bool>((
  ref,
) async {
  try {
    final Object? status = await PushNotificationService.instance
        .checkPermissionStatus();
    return status == AuthorizationStatus.denied;
  } catch (_) {
    return false;
  }
});

/// Opens the app's page in the system settings ("Open settings").
final notificationOpenSystemSettingsProvider =
    Provider<Future<void> Function()>(
      (ref) => () async {
        try {
          await Geolocator.openAppSettings();
        } catch (_) {
          // Not available on this platform (web): nothing to open.
        }
      },
    );

/// KAN-991: the conversations the caller muted ("Mute this conversation"),
/// for the muted list. Empty while the Messages list is not enabled.
final notificationMutedConversationsProvider =
    FutureProvider.autoDispose<List<MyConversation>>((ref) async {
      if (!messagesListEnabled(ref.watch(messagesListFlagsProvider))) {
        return const <MyConversation>[];
      }
      final Result<List<MyConversation>, Failure> result = await ref.watch(
        messagesListProvider.future,
      );
      return result.fold(
        (_) => const <MyConversation>[],
        (list) => list.where((c) => c.muted).toList(),
      );
    });

/// Mutes or unmutes one conversation through the messaging mute API
/// (`POST /v1/conversations/{id}/mute`), then reloads the list.
final notificationSetConversationMutedProvider =
    Provider<Future<bool> Function(String conversationId, bool muted)>(
      (ref) => (String id, bool muted) async {
        final result = await ref.read(dmRepositoryProvider).setMuted(id, muted);
        ref.invalidate(messagesListProvider);
        return result.isSuccess;
      },
    );

/// KAN-1048: Supabase-backed repository for the notification channels.
final notificationChannelsRepositoryProvider =
    Provider<NotificationChannelsRepository>(
      (ref) => NotificationChannelsRepositoryImpl(Supabase.instance.client),
    );

/// KAN-1048: the caller's channels and mutes (loads on first watch).
final notificationChannelsControllerProvider =
    StateNotifierProvider.autoDispose<
      NotificationChannelsController,
      NotificationChannelsState
    >(
      (ref) => NotificationChannelsController(
        ref.watch(notificationChannelsRepositoryProvider),
      ),
    );
