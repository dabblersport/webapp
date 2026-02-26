import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:convert';

/// Mobile implementation of push notification service (Android/iOS).
class PushNotificationService {
  PushNotificationService._internal();
  static final PushNotificationService instance =
      PushNotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  StreamSubscription<String>? _tokenRefreshSub;

  /// Callback invoked when user taps a notification.
  /// Receives the action_route string from the notification data payload.
  /// Set this from your app's navigation layer (e.g. main.dart or router).
  void Function(String route)? onNotificationTap;

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
    _listenTokenRefresh();
    await _handleInitialMessage();
    _listenMessageOpenedApp();

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

    await _localNotificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onLocalNotificationTap,
    );
  }

  /// Called when user taps a local notification (foreground-displayed).
  void _onLocalNotificationTap(NotificationResponse response) {
    final raw = response.payload;
    if (raw == null || raw.isEmpty) return;
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final route = data['action_route'] as String?;
      if (route != null && route.isNotEmpty) {
        onNotificationTap?.call(route);
      }
    } catch (e) {
      debugPrint('Failed to parse local notification payload: $e');
    }
  }

  Future<void> _configureForegroundHandling() async {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      final notification = message.notification;
      if (notification == null) return;

      // Pass data payload so local-notification tap can route correctly
      final payload = message.data.isNotEmpty ? jsonEncode(message.data) : null;

      await _showLocalNotification(
        notification.hashCode,
        notification.title,
        notification.body,
        payload: payload,
      );
    });
  }

  Future<void> _showLocalNotification(
    int id,
    String? title,
    String? body, {
    String? payload,
  }) async {
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

    await _localNotificationsPlugin.show(
      id,
      title,
      body,
      details,
      payload: payload,
    );
  }

  Future<void> _logFcmToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();

      if (token != null) {
        await _saveTokenToSupabase(token);
      }
    } catch (e) {
      debugPrint('Failed to get/save FCM token: $e');
    }
  }

  /// Listen for FCM token refreshes and persist new token to Supabase.
  void _listenTokenRefresh() {
    _tokenRefreshSub?.cancel();
    _tokenRefreshSub = FirebaseMessaging.instance.onTokenRefresh.listen((
      newToken,
    ) async {
      debugPrint('FCM token refreshed');
      await _saveTokenToSupabase(newToken);
    }, onError: (e) => debugPrint('FCM token refresh error: $e'));
  }

  /// Handle the case where the app was terminated and opened via notification tap.
  Future<void> _handleInitialMessage() async {
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) {
      _handleRemoteMessageTap(initial);
    }
  }

  /// Listen for notification taps when the app is in background (not terminated).
  void _listenMessageOpenedApp() {
    FirebaseMessaging.onMessageOpenedApp.listen(_handleRemoteMessageTap);
  }

  /// Extract action_route from the remote message data and invoke the tap callback.
  void _handleRemoteMessageTap(RemoteMessage message) {
    debugPrint('Push tap received — data: ${message.data}');
    final route = message.data['action_route'] as String?;
    debugPrint('Push tap action_route: $route');
    if (route != null && route.isNotEmpty) {
      onNotificationTap?.call(route);
    } else {
      debugPrint('Push tap: no action_route in data payload');
    }
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
      _listenTokenRefresh();

      // Initialize local notifications with tap callback
      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const darwinInit = DarwinInitializationSettings();
      const initSettings = InitializationSettings(
        android: androidInit,
        iOS: darwinInit,
        macOS: darwinInit,
      );
      await _localNotificationsPlugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onLocalNotificationTap,
      );

      return true;
    }
    return false;
  }
}
