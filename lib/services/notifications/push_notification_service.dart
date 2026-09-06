// Conditional platform implementations: web uses the FCM web-push service
// (VAPID + firebase-messaging-sw.js), mobile uses the full Firebase +
// local-notifications implementation.
import 'package:dabbler/core/config/notification_preference.dart';

import 'push_notification_service_stub.dart'
    if (dart.library.html) 'push_notification_service_web.dart'
    if (dart.library.io) 'push_notification_service_mobile.dart'
    as impl;

/// Handles push notification setup (Firebase Messaging + local notifications)
/// and requests notification permissions on supported platforms.
class PushNotificationService {
  PushNotificationService._internal();
  static final PushNotificationService instance =
      PushNotificationService._internal();

  Future<void> init() async {
    // Delegate to platform-specific implementation
    // On web: uses stub (no Firebase)
    // On mobile: uses full Firebase implementation
    await impl.PushNotificationService.instance.init();
  }

  /// Check if we should show the notification permission prompt
  Future<bool> shouldShowNotificationPrompt() async {
    return await impl.PushNotificationService.instance
        .shouldShowNotificationPrompt();
  }

  /// Save user's notification permission preference
  Future<void> saveNotificationPreference(
    NotificationPreference preference,
  ) async {
    await impl.PushNotificationService.instance.saveNotificationPreference(
      preference,
    );
  }

  /// Check current permission status without requesting
  Future<dynamic> checkPermissionStatus() async {
    return await impl.PushNotificationService.instance.checkPermissionStatus();
  }

  /// Request notification permissions
  Future<bool> requestNotificationPermission() async {
    return await impl.PushNotificationService.instance
        .requestNotificationPermission();
  }

  /// Revoke this device's push registration on logout. Deletes the current
  /// user's `fcm_tokens` row for this platform and best-effort invalidates
  /// the local FCM registration. Per T-004's teardown contract, callers
  /// MUST invoke this before `supabase.auth.signOut()` — the delete relies
  /// on `auth.uid()` still resolving to the signed-in user (RLS), and once
  /// signed out there is no session left to authorize it.
  Future<void> revokeToken() async {
    await impl.PushNotificationService.instance.revokeToken();
  }
}
