import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Service to schedule local notifications for check-in reminders.
///
/// WARNING (iOS): initializing flutter_local_notifications takes over the
/// UNUserNotificationCenter delegate, which breaks push-notification tap
/// deep-links (firebase_messaging's onMessageOpenedApp stops firing). The
/// push service deliberately avoids fln on iOS for this reason
/// (push_notification_service_mobile.dart). If this service is re-enabled,
/// either keep it Android-only or solve the delegate conflict first.
class CheckInNotificationService {
  static final CheckInNotificationService _instance =
      CheckInNotificationService._internal();
  factory CheckInNotificationService() => _instance;
  CheckInNotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  /// Initialize the notification service
  Future<void> init() async {
    if (_isInitialized) return;

    tz_data.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(initSettings);
    _isInitialized = true;
  }

  /// Schedule a daily reminder notification (24 hours from now)
  Future<void> scheduleCheckInReminder() async {
    if (!_isInitialized) await init();

    // Request permissions first (iOS)
    if (Platform.isIOS) {
      await _notifications
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    }

    // Schedule notification for 24 hours from now
    const androidDetails = AndroidNotificationDetails(
      'check_in_reminders',
      'Check-in Reminders',
      channelDescription:
          'Daily reminders to check in and maintain your streak',
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // Schedule for 24 hours from now. The delay is a fixed offset from the
    // current instant, so tz.local (even if uninitialized/UTC) yields the
    // correct absolute fire time.
    final scheduledTime =
        tz.TZDateTime.now(tz.local).add(const Duration(hours: 24));

    await _notifications.zonedSchedule(
      0, // Notification ID
      'Don\'t lose your streak! 🔥',
      'You\'re one day closer to the Early Bird badge. Check in now!',
      scheduledTime,
      notificationDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  /// Cancel all pending notifications
  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }
}
