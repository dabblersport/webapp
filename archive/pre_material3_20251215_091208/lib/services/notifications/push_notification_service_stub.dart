/// Stub implementation for web platform (no-op).
class PushNotificationService {
  PushNotificationService._internal();
  static final PushNotificationService instance =
      PushNotificationService._internal();

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    // Push notifications are not supported on web in this app.
    _initialized = true;
  }

  /// Web stub - always return false (no prompt on web)
  Future<bool> shouldShowNotificationPrompt() async {
    return false;
  }

  /// Web stub - no-op
  Future<void> saveNotificationPreference(String preference) async {
    // No-op on web
  }

  /// Web stub - return null status
  Future<dynamic> checkPermissionStatus() async {
    return null;
  }

  /// Web stub - return false (not supported)
  Future<bool> requestNotificationPermission() async {
    return false;
  }
}
