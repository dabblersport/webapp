import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/core/services/app_lifecycle_manager.dart';

import 'models/notification_settings.dart';
import 'notification_settings_repository_impl.dart';

/// KAN-991: keeps `notification_settings.tz` on the device's time zone, so
/// quiet hours and the 09:00 reminder follow the phone.
///
/// [sync] sends the IANA name through `rpc_set_my_notification_timezone`
/// when a user is signed in and the (user, zone) pair differs from the last
/// one sent. [start] runs it now, on every sign-in and on every app resume
/// (a trip across zones changes it while the app sleeps).
class NotificationSettingsTimezoneSync {
  NotificationSettingsTimezoneSync({
    Future<String?> Function()? readTimezone,
    Future<Result<NotificationSettings, Failure>> Function(String tz)? send,
    String? Function()? currentUserId,
  }) : _readTimezone = readTimezone ?? _deviceTimezone,
       _send = send ?? _rpcSend,
       _currentUserId = currentUserId ?? _supabaseUserId;

  static final NotificationSettingsTimezoneSync instance =
      NotificationSettingsTimezoneSync();

  final Future<String?> Function() _readTimezone;
  final Future<Result<NotificationSettings, Failure>> Function(String) _send;
  final String? Function() _currentUserId;

  String? _lastSent;
  bool _started = false;
  StreamSubscription<AuthState>? _authSub;

  static Future<String?> _deviceTimezone() async =>
      (await FlutterTimezone.getLocalTimezone()).identifier;

  static Future<Result<NotificationSettings, Failure>> _rpcSend(String tz) =>
      NotificationSettingsRepositoryImpl(
        Supabase.instance.client,
      ).setTimezone(tz);

  static String? _supabaseUserId() =>
      Supabase.instance.client.auth.currentUser?.id;

  /// Sends the device zone when it (or the user) changed. True when a call
  /// was made and succeeded.
  Future<bool> sync() async {
    final String? userId = _currentUserId();
    if (userId == null) return false;
    final String? tz;
    try {
      tz = (await _readTimezone())?.trim();
    } catch (e) {
      debugPrint('Device time zone read failed: $e');
      return false;
    }
    if (tz == null || tz.isEmpty) return false;
    final String key = '$userId|$tz';
    if (key == _lastSent) return false;
    final result = await _send(tz);
    return result.fold(
      (f) {
        debugPrint('Notification time zone not saved: $f');
        return false;
      },
      (_) {
        _lastSent = key;
        return true;
      },
    );
  }

  void _onResume() => unawaited(sync());

  /// Wires the sign-in and resume triggers and syncs once. Safe to call twice.
  void start() {
    if (_started) return;
    _started = true;
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((s) {
      final bool signedIn =
          s.event == AuthChangeEvent.signedIn ||
          (s.event == AuthChangeEvent.initialSession && s.session != null);
      if (signedIn) unawaited(sync());
    }, onError: (Object e) => debugPrint('Time zone auth listener: $e'));
    AppLifecycleManager().onResume(_onResume);
    unawaited(sync());
  }

  /// Stops the triggers (tests).
  @visibleForTesting
  Future<void> stop() async {
    await _authSub?.cancel();
    AppLifecycleManager().offResume(_onResume);
    _started = false;
  }
}
