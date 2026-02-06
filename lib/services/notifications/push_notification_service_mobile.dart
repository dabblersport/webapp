import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Mobile implementation of push notification service (Android/iOS).
class PushNotificationService {
  PushNotificationService._internal();
  static final PushNotificationService instance =
      PushNotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  static const String _notificationPromptPreferenceKey =
      'notification_prompt_preference';
  static const String _notificationPromptNextAtKey =
      'notification_prompt_next_at_ms';
  static const Duration _remindLaterCooldown = Duration(hours: 72);

  Future<void> init() async {
    if (_initialized) return;

    // Initialize Firebase (uses platform-specific config files)
    await Firebase.initializeApp();

    await _requestPermissions();
    await _configureForegroundHandling();
    await _logFcmToken();
    await _subscribeToTopics();

    _initialized = true;
  }

  /// Subscribe to Firebase topics for broadcast notifications
  Future<void> _subscribeToTopics() async {
    try {
      // Subscribe to announcements topic (for app updates, news, etc.)
      await FirebaseMessaging.instance.subscribeToTopic('announcements');
      // Subscribe to platform-specific topic
      await FirebaseMessaging.instance.subscribeToTopic(
        defaultTargetPlatform.name.toLowerCase(),
      );
    } catch (e) {
      debugPrint('Failed to subscribe to topics: $e');
    }
  }

  Future<void> _requestPermissions() async {
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      provisional: false,
      sound: true,
    );

    // Initialize local notifications for foreground display
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinInit = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: darwinInit,
      macOS: darwinInit,
    );

    await _localNotificationsPlugin.initialize(initSettings);
  }

  Future<void> _configureForegroundHandling() async {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      final notification = message.notification;
      if (notification == null) return;

      await _showLocalNotification(
        notification.hashCode,
        notification.title,
        notification.body,
      );
    });
  }

  Future<void> _showLocalNotification(
    int id,
    String? title,
    String? body,
  ) async {
    const androidDetails = AndroidNotificationDetails(
      'default_channel',
      'General',
      channelDescription: 'General notifications',
      importance: Importance.max,
      priority: Priority.high,
    );

    const darwinDetails = DarwinNotificationDetails();

    const details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
    );

    await _localNotificationsPlugin.show(id, title, body, details);
  }

  Future<void> _logFcmToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();

      if (token != null) {
        await _saveTokenToSupabase(token);
      }
    } catch (e) {}
  }

  Future<void> _saveTokenToSupabase(String token) async {
    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;

      if (userId == null) {
        return;
      }

      await supabase.from('fcm_tokens').upsert({
        'user_id': userId,
        'token': token,
        'platform': defaultTargetPlatform.name,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id,platform');
    } catch (e) {}
  }

  /// Check if we should show the notification permission prompt
  /// Returns true if user hasn't decided yet (remind later or never asked)
  Future<bool> shouldShowNotificationPrompt() async {
    final prefs = await SharedPreferences.getInstance();
    final preference = prefs.getString(_notificationPromptPreferenceKey);

    // Never prompt again
    if (preference == 'never' || preference == 'allow') {
      return false;
    }

    // First time
    if (preference == null) {
      return true;
    }

    // Cooldown gating for "remind_later"
    if (preference == 'remind_later') {
      final nextAtMs = prefs.getInt(_notificationPromptNextAtKey);

      // Backward-compat: older installs stored only the string.
      // Apply the cooldown starting now.
      if (nextAtMs == null) {
        final nextAt = DateTime.now().add(_remindLaterCooldown);
        await prefs.setInt(
          _notificationPromptNextAtKey,
          nextAt.millisecondsSinceEpoch,
        );
        return false;
      }

      return DateTime.now().millisecondsSinceEpoch >= nextAtMs;
    }

    // Unknown value -> treat as eligible
    return true;
  }

  /// Save user's notification permission preference
  /// Options: 'allow', 'remind_later', 'never'
  Future<void> saveNotificationPreference(String preference) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_notificationPromptPreferenceKey, preference);

    if (preference == 'remind_later') {
      final nextAt = DateTime.now().add(_remindLaterCooldown);
      await prefs.setInt(
        _notificationPromptNextAtKey,
        nextAt.millisecondsSinceEpoch,
      );
    } else {
      // If user allowed or never wants prompts, clear any scheduled reminder.
      await prefs.remove(_notificationPromptNextAtKey);
    }
  }

  /// Check current permission status without requesting
  Future<AuthorizationStatus> checkPermissionStatus() async {
    // Initialize Firebase if not already initialized
    try {
      await Firebase.initializeApp();
    } catch (e) {
      // Already initialized, ignore error
    }
    final settings = await FirebaseMessaging.instance.getNotificationSettings();
    return settings.authorizationStatus;
  }

  /// Request notification permissions (called when user clicks "Enable")
  Future<bool> requestNotificationPermission() async {
    await Firebase.initializeApp();
    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional) {
      await _configureForegroundHandling();
      await _logFcmToken();
      await _subscribeToTopics();

      // Initialize local notifications
      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const darwinInit = DarwinInitializationSettings();
      const initSettings = InitializationSettings(
        android: androidInit,
        iOS: darwinInit,
        macOS: darwinInit,
      );
      await _localNotificationsPlugin.initialize(initSettings);

      return true;
    }
    return false;
  }
}
