import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:dabbler/core/config/notification_preference.dart';
import 'package:dabbler/core/services/app_lifecycle_manager.dart';

import 'push_token_registrar.dart';
import 'security_sign_in_registrar.dart';

/// Web (Chrome) implementation of push notification service.
///
/// Background delivery + notification click handling live in
/// `web/firebase-messaging-sw.js` (registered automatically by the
/// firebase_messaging web plugin). Clicks open the app at the notification's
/// `action_route`, so no in-Dart tap callback is needed. Foreground messages
/// are not shown as OS notifications — the in-app realtime feed and badge
/// already surface them while the app is visible.
class PushNotificationService {
  PushNotificationService._internal();
  static final PushNotificationService instance =
      PushNotificationService._internal();

  /// A separate instance for tests.
  @visibleForTesting
  PushNotificationService.forTest();

  /// Token registration through the v2 RPCs (KAN-977), replaceable in tests.
  @visibleForTesting
  PushTokenRegistrar registrar = PushTokenRegistrar();

  /// The browser permission (never prompts), replaceable in tests.
  @visibleForTesting
  Future<AuthorizationStatus?> Function() readPermission = _browserPermission;

  static Future<AuthorizationStatus?> _browserPermission() async =>
      (await FirebaseMessaging.instance.getNotificationSettings())
          .authorizationStatus;

  /// FCM Web Push certificate key pair (public VAPID key — safe to commit).
  static const String _vapidKey =
      'BPzHkgDUc9cCyB_pXmV_2dz7AE1v-BXDJ-WSrhMjBJP4auHijC7E5kfsti7Yq_wfm2gVPtg9lG77N4QY-egfMDY';

  bool _initialized = false;
  bool _wired = false;
  StreamSubscription<String>? _tokenRefreshSub;
  StreamSubscription<AuthState>? _authStateSub;
  final SecuritySignInRegistrar _securitySignIn = SecuritySignInRegistrar();

  /// Present for API parity with the mobile implementation. On web,
  /// notification taps navigate via URL (service worker), so this is unused.
  void Function(String route)? onNotificationTap;

  // Same SharedPreferences keys as the mobile implementation so a user's
  // prompt preference survives switching platforms on the same browser.
  static const String _notificationPromptPreferenceKey =
      'notification_prompt_preference';
  static const String _notificationPromptNextAtKey =
      'notification_prompt_next_at_ms';
  static const Duration _remindLaterCooldown = Duration(hours: 72);

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    // Never prompt at launch on web — browsers penalize unsolicited
    // permission requests. The Home drawer / onboarding step asks instead.
    try {
      final settings = await FirebaseMessaging.instance
          .getNotificationSettings();
      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        await _wireUp();
      }
    } catch (e) {
      debugPrint('Web push init failed: $e');
    }

    _listenAuthState();
    // KAN-977: the browser permission may change while the tab is away.
    AppLifecycleManager().onResume(_onResume);
  }

  /// Token fetch/save + listeners. Idempotent.
  Future<void> _wireUp() async {
    if (_wired) return;
    _wired = true;

    FirebaseMessaging.onMessage.listen((message) {
      // App is visible; the in-app feed shows it. Log for diagnostics only.
      debugPrint('Foreground web push: ${message.notification?.title}');
    });

    await _fetchAndSaveToken();

    _tokenRefreshSub?.cancel();
    _tokenRefreshSub = FirebaseMessaging.instance.onTokenRefresh.listen((
      newToken,
    ) async {
      debugPrint('Web FCM token refreshed');
      await registerToken(newToken);
    }, onError: (e) => debugPrint('Web FCM token refresh error: $e'));
  }

  /// Re-save the token whenever the user signs in (fresh sign-ups happen
  /// after init, when the launch-time save was skipped for lack of a user).
  void _listenAuthState() {
    _authStateSub?.cancel();
    _authStateSub = Supabase.instance.client.auth.onAuthStateChange.listen((
      state,
    ) async {
      final signedIn =
          state.event == AuthChangeEvent.signedIn ||
          (state.event == AuthChangeEvent.initialSession &&
              state.session != null);
      // Every sign-in is registered with the server, push or not.
      unawaited(_securitySignIn.onAuthState(state));
      if (signedIn && _wired) {
        await _fetchAndSaveToken();
      }
    }, onError: (e) => debugPrint('Web auth-state FCM token sync error: $e'));
  }

  Future<void> _fetchAndSaveToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken(
        vapidKey: _vapidKey,
      );
      if (token != null) {
        await registerToken(token);
      }
    } catch (e) {
      debugPrint('Failed to get/save web FCM token: $e');
    }
  }

  static const String _platform = 'web';

  Future<AuthorizationStatus?> _statusOrNull() async {
    try {
      return await readPermission();
    } catch (_) {
      return null;
    }
  }

  /// Registers [token] for this browser installation (KAN-977), with app
  /// version, locale and permission. No-op when signed out.
  @visibleForTesting
  Future<void> registerToken(String token) async {
    final result = await registrar.register(
      token: token,
      platform: _platform,
      permission: await _statusOrNull(),
    );
    result.fold(
      (f) => debugPrint('Failed to register web FCM token: $f'),
      (_) {},
    );
  }

  Future<void> _resync() async {
    final result = await registrar.resync(
      platform: _platform,
      permission: await _statusOrNull(),
    );
    result.fold(
      (f) => debugPrint('Web FCM registration sync failed: $f'),
      (_) {},
    );
  }

  void _onResume() => unawaited(_resync());

  /// The app locale changed (or was first read): send it with the token.
  Future<void> updateLocale(Locale locale) async {
    if (registrar.setLocale(locale)) await _resync();
  }

  /// Revoke this browser's push registration on logout: removes this
  /// installation's `fcm_tokens` row through `rpc_unregister_push_token`
  /// (needs auth.uid(), so this MUST be called before
  /// `supabase.auth.signOut()` per T-004's teardown order) and, best-effort,
  /// invalidates the local FCM registration. The installation id is kept.
  Future<void> revokeToken() async {
    final result = await registrar.unregister();
    result.fold(
      (f) => debugPrint('Failed to unregister web FCM token: $f'),
      (_) {},
    );

    try {
      await FirebaseMessaging.instance.deleteToken();
    } catch (e) {
      debugPrint('Failed to delete local web FCM token: $e');
    }
  }

  /// Check if we should show the notification permission prompt.
  Future<bool> shouldShowNotificationPrompt() async {
    final prefs = await SharedPreferences.getInstance();
    final preference = prefs.getString(_notificationPromptPreferenceKey);

    if (preference == 'never' || preference == 'allow') {
      return false;
    }

    if (preference == 'remind_later') {
      final nextAt = prefs.getInt(_notificationPromptNextAtKey);
      if (nextAt != null && DateTime.now().millisecondsSinceEpoch < nextAt) {
        return false;
      }
    }

    return true;
  }

  /// Save user's notification permission preference.
  Future<void> saveNotificationPreference(
    NotificationPreference preference,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _notificationPromptPreferenceKey,
      preference.wireValue,
    );
    if (preference == NotificationPreference.remindLater) {
      await prefs.setInt(
        _notificationPromptNextAtKey,
        DateTime.now().add(_remindLaterCooldown).millisecondsSinceEpoch,
      );
    }
  }

  /// Current browser permission status (AuthorizationStatus) without prompting.
  Future<dynamic> checkPermissionStatus() async {
    try {
      final settings = await FirebaseMessaging.instance
          .getNotificationSettings();
      return settings.authorizationStatus;
    } catch (e) {
      debugPrint('Web permission status check failed: $e');
      return null;
    }
  }

  /// Show the browser permission prompt; on grant, fetch and save the token.
  Future<bool> requestNotificationPermission() async {
    try {
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      final granted =
          settings.authorizationStatus == AuthorizationStatus.authorized;
      if (granted) {
        await _wireUp();
        await _fetchAndSaveToken();
      }
      return granted;
    } catch (e) {
      debugPrint('Web permission request failed: $e');
      return false;
    }
  }
}
