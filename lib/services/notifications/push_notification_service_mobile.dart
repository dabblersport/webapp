import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:dabbler/core/config/feature_flags.dart';
import 'package:dabbler/core/services/app_lifecycle_manager.dart';
import 'package:dabbler/features/notifications/presentation/widgets/notif_target_states.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

import 'package:dabbler/core/config/notification_preference.dart';

import 'push_contract.dart';
import 'push_local_display.dart';
import 'push_presence.dart';
import 'push_token_registrar.dart';

/// The native notification permission, behind a seam so a test can prove when
/// the system prompt is (not) asked for. [request] shows the native alert;
/// [status] never does.
abstract class PushPermissionGateway {
  Future<AuthorizationStatus> status();
  Future<AuthorizationStatus> request();
}

class _FirebasePermissionGateway implements PushPermissionGateway {
  const _FirebasePermissionGateway();

  @override
  Future<AuthorizationStatus> status() async =>
      (await FirebaseMessaging.instance.getNotificationSettings())
          .authorizationStatus;

  @override
  Future<AuthorizationStatus> request() async =>
      (await FirebaseMessaging.instance.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      )).authorizationStatus;
}

/// Mobile implementation of push notification service (Android/iOS).
///
/// The native permission prompt is never shown at app start: [init] only wires
/// listeners (and, when the user already allowed notifications earlier, the
/// token and topics). The prompt is asked for by [requestNotificationPermission],
/// which runs only when the signed-in user turns notifications on in the app.
/// The FCM token is registered only once the permission is granted.
class PushNotificationService {
  PushNotificationService._internal();

  /// A separate instance for tests.
  @visibleForTesting
  PushNotificationService.forTest();

  static final PushNotificationService instance =
      PushNotificationService._internal();

  /// The native permission, replaceable in tests.
  @visibleForTesting
  PushPermissionGateway permission = const _FirebasePermissionGateway();

  /// Token registration through the v2 RPCs (KAN-977), replaceable in tests.
  @visibleForTesting
  PushTokenRegistrar registrar = PushTokenRegistrar();

  final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  /// KAN-992: Android channels and foreground display.
  late final PushLocalDisplay _display = PushLocalDisplay(
    _localNotificationsPlugin,
  );

  /// The app's language, for the action titles.
  Locale _locale = const Locale('en');

  bool _initialized = false;
  bool _activated = false;
  StreamSubscription<String>? _tokenRefreshSub;
  StreamSubscription<AuthState>? _authStateSub;

  /// Callback invoked when user taps a notification.
  /// Receives the action_route string from the notification data payload.
  /// Set this from your app's navigation layer (e.g. main.dart or router).
  void Function(String route)? onNotificationTap;

  /// KAN-992: a tapped push whose target cannot open (deleted, cancelled,
  /// expired, no access, already handled): the app shows W1-F3's sheet.
  void Function(NotifTargetState state)? onTargetUnavailable;

  static const String _notificationPromptPreferenceKey =
      'notification_prompt_preference';
  static const String _notificationPromptNextAtKey =
      'notification_prompt_next_at_ms';
  static const Duration _remindLaterCooldown = Duration(hours: 72);

  /// Startup: wires what needs no permission and never shows the native
  /// prompt. When notifications were already allowed (an earlier session), the
  /// token and topics are registered too.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    // Each step on its own: one failing (a missing plugin, no Firebase yet)
    // must not stop the others, least of all the permission read.
    await _step('platform setup', _configurePlatform);
    await _step('auth listener', () async => _listenAuthState());
    await _step('initial message', _handleInitialMessage);
    await _step('opened-app listener', () async => _listenMessageOpenedApp());
    // KAN-977: the OS permission may change in system settings meanwhile.
    await _step(
      'resume sync',
      () async => AppLifecycleManager().onResume(_onResume),
    );
    await _step('activation', () async {
      if (await _permissionGranted()) await _activate();
    });
  }

  Future<void> _step(String name, Future<void> Function() run) async {
    try {
      await run();
    } catch (e) {
      debugPrint('Push init ($name) error: $e');
    }
  }

  /// Whether the user has allowed notifications (never prompts).
  Future<bool> _permissionGranted() async {
    final status = await permission.status();
    return status == AuthorizationStatus.authorized ||
        status == AuthorizationStatus.provisional;
  }

  /// Everything that follows a granted permission: foreground handling, the
  /// token, topics and the refresh listener. Safe to call twice.
  Future<void> _activate() async {
    if (_activated) return;
    _activated = true;
    await _configureForegroundHandling();
    await _logFcmToken();
    await _subscribeToTopics();
    _listenTokenRefresh();
  }

  /// Re-save the FCM token whenever the user signs in. On a fresh install
  /// init() runs before authentication, so the launch-time save is skipped
  /// (no auth user) — without this listener the device would never get an
  /// fcm_tokens row and would receive no pushes. Registration is idempotent,
  /// so overlapping saves are harmless.
  void _listenAuthState() {
    _authStateSub?.cancel();
    _authStateSub = Supabase.instance.client.auth.onAuthStateChange.listen((
      state,
    ) async {
      final signedIn =
          state.event == AuthChangeEvent.signedIn ||
          (state.event == AuthChangeEvent.initialSession &&
              state.session != null);
      // Only once notifications are allowed: no permission, no token.
      if (signedIn && await _permissionGranted()) {
        await _logFcmToken();
      }
    }, onError: (e) => debugPrint('Auth-state FCM token sync error: $e'));
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

  /// Channel and presentation setup. Asks for nothing: the native permission
  /// prompt belongs to [requestNotificationPermission].
  Future<void> _configurePlatform() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      // Android: foreground messages are displayed via flutter_local_notifications.
      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const initSettings = InitializationSettings(android: androidInit);

      await _localNotificationsPlugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onLocalNotificationTap,
      );

      // KAN-992: every channel KAN-979 sends to, created up front so a
      // background FCM push (system-drawn) lands in its own channel;
      // dabbler_default is the manifest's fallback.
      await _display.createChannels();
    } else {
      // iOS/macOS: DO NOT initialize flutter_local_notifications here — it
      // takes over the UNUserNotificationCenter delegate and swallows the
      // notification taps firebase_messaging needs for onMessageOpenedApp
      // (deep links stop working). Instead let FCM present foreground
      // notifications natively; taps then flow through onMessageOpenedApp
      // for foreground and background alike.
      await FirebaseMessaging.instance
          .setForegroundNotificationPresentationOptions(
            alert: true,
            badge: true,
            sound: true,
          );
      // KAN-992: the AppDelegate registers the categories, forwards their
      // actions and leaves out the alert for the chat open on screen.
      await PushPresence.instance.wireNative();
      _sendActionTitles();
    }
  }

  void _sendActionTitles() {
    final l = lookupAppLocalizations(_locale);
    PushPresence.instance.setActionTitles({
      for (final a in PushActionId.values) a.wire: pushActionLabel(a, l),
    });
  }

  /// Called when user taps a local notification (foreground-displayed).
  void _onLocalNotificationTap(NotificationResponse response) {
    final data = PushLocalDisplay.handleResponse(response);
    if (data != null && data.isNotEmpty) routeTap(data);
  }

  /// A tapped push: W1-F3's sheet when its target cannot open, else its
  /// route (KAN-992).
  @visibleForTesting
  void routeTap(Map<String, dynamic> data) {
    final target = pushTarget(
      data,
      now: DateTime.now(),
      meetupsEnabled: FeatureFlags.enableMeetups,
    );
    if (target.showsSheet) {
      onTargetUnavailable?.call(target.state);
    } else if (target.opens) {
      onNotificationTap?.call(target.route!);
    } else {
      debugPrint('Push tap: no route for ${data['kind_key']}');
    }
  }

  Future<void> _configureForegroundHandling() async {
    FirebaseMessaging.onMessage.listen(onForegroundMessage);
  }

  /// KAN-992: a foreground push — badge, open-chat rule, its channel and
  /// actions (iOS presents natively); W1-F7 hears each with its de-dup key.
  @visibleForTesting
  Future<void> onForegroundMessage(RemoteMessage message) async {
    final data = Map<String, dynamic>.from(message.data);
    final notification = message.notification;
    final badge = pushBadge(
      data,
      appleBadge: notification?.apple?.badge,
      androidCount: notification?.android?.count,
    );
    if (badge != null) PushPresence.instance.setBadge(badge);

    final presence = PushPresence.instance;
    final suppressed = suppressForegroundAlert(
      data,
      openChat: presence.openChat,
      inAppBannerShows: presence.inAppBannerShows,
    );
    final drawsHere =
        defaultTargetPlatform == TargetPlatform.android && notification != null;
    presence.reportForeground(
      ForegroundPush(
        // KAN-993: title and body, for a push that beats its Realtime row.
        <String, dynamic>{
          ...data,
          if (notification?.title != null && data['title'] == null)
            'title': notification!.title,
          if (notification?.body != null && data['body'] == null)
            'body': notification!.body,
        },
        dedupeKey: pushDedupeKey(data),
        alerted: !suppressed && (drawsHere || notification != null),
      ),
    );
    if (suppressed || !drawsHere) return;
    await _display.show(
      data: data,
      title: notification.title,
      body: notification.body,
      channelId: notification.android?.channelId,
      tag: notification.android?.tag ?? message.collapseKey,
      l10n: lookupAppLocalizations(_locale),
    );
  }

  Future<void> _logFcmToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();

      if (token != null) {
        await registerToken(token);
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
      await registerToken(newToken);
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

  /// A system-drawn push was tapped (cold start or background).
  void _handleRemoteMessageTap(RemoteMessage message) =>
      routeTap(Map<String, dynamic>.from(message.data));

  String get _platform =>
      pushPlatformName(isWeb: false, platform: defaultTargetPlatform);

  Future<AuthorizationStatus?> _statusOrNull() async {
    try {
      return await permission.status();
    } catch (_) {
      return null;
    }
  }

  /// Registers [token] for this installation (KAN-977): installation id, app
  /// version, locale and OS permission go with it. No-op when signed out.
  @visibleForTesting
  Future<void> registerToken(String token) async {
    final result = await registrar.register(
      token: token,
      platform: _platform,
      permission: await _statusOrNull(),
    );
    result.fold((f) => debugPrint('Failed to register FCM token: $f'), (_) {});
  }

  /// Sends the registration again when the permission or locale changed.
  Future<void> _resync() async {
    final result = await registrar.resync(
      platform: _platform,
      permission: await _statusOrNull(),
    );
    result.fold((f) => debugPrint('FCM registration sync failed: $f'), (_) {});
  }

  void _onResume() => unawaited(_resync());

  /// The app locale changed (or was first read): send it with the token.
  Future<void> updateLocale(Locale locale) async {
    _locale = locale;
    if (_initialized && defaultTargetPlatform == TargetPlatform.iOS) {
      _sendActionTitles();
    }
    if (registrar.setLocale(locale)) await _resync();
  }

  /// Revoke this installation's push registration on logout: removes its
  /// `fcm_tokens` row through `rpc_unregister_push_token` (it needs
  /// auth.uid(), so this MUST be called before `supabase.auth.signOut()` per
  /// T-004's teardown order) and, best-effort, invalidates the local FCM
  /// registration so a re-login gets a fresh token. The installation id is
  /// kept: it names the device, not the user.
  Future<void> revokeToken() async {
    final result = await registrar.unregister();
    result.fold(
      (f) => debugPrint('Failed to unregister FCM token: $f'),
      (_) {},
    );

    try {
      await FirebaseMessaging.instance.deleteToken();
    } catch (e) {
      debugPrint('Failed to delete local FCM token: $e');
    }
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
  Future<void> saveNotificationPreference(
    NotificationPreference preference,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _notificationPromptPreferenceKey,
      preference.wireValue,
    );

    if (preference == NotificationPreference.remindLater) {
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
    final settings = await FirebaseMessaging.instance.getNotificationSettings();
    return settings.authorizationStatus;
  }

  /// Request notification permissions: the one place the native prompt is
  /// asked for, called when the signed-in user turns notifications on in the
  /// app (the settings switch, the Home sheet's Enable, the onboarding step).
  Future<bool> requestNotificationPermission() async {
    final status = await permission.request();

    if (status == AuthorizationStatus.authorized ||
        status == AuthorizationStatus.provisional) {
      try {
        await _configurePlatform();
        // KAN-572: no Darwin initialize here. _configurePlatform already
        // initialized local notifications on Android; initializing them on
        // iOS takes over the UNUserNotificationCenter delegate, which FCM's
        // native foreground presentation and onMessageOpenedApp rely on.
        await _activate();
      } catch (e) {
        debugPrint('Push activation error: $e');
      }
      return true;
    }
    return false;
  }
}
