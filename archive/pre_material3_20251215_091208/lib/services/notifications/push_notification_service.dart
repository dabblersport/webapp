// Conditionally import Firebase only on mobile platforms
// On web (dart.library.html exists), use stub. On mobile (dart.library.io exists), use mobile implementation.
import 'push_notification_service_stub.dart'
    if (dart.library.html) 'push_notification_service_stub.dart'
    if (dart.library.io) 'push_notification_service_mobile.dart'
    as impl;

/// Handles push notification setup (Firebase Messaging + local notifications)
/// and requests OS notification permissions on supported platforms.
///
/// On web, this is a no-op to avoid Firebase Messaging web compatibility issues.
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
  Future<void> saveNotificationPreference(String preference) async {
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
}
