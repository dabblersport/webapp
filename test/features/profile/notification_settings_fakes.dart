// KAN-991: a recording NotificationSettingsRepository for the settings tests.

import 'dart:async';

import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/features/notifications/data/models/notification_settings.dart';
import 'package:dabbler/features/notifications/data/notification_settings_repository.dart';

class FakeNotificationSettingsRepo implements NotificationSettingsRepository {
  FakeNotificationSettingsRepo(this.settings, {this.failUpdates = false});

  /// Null keeps the screen in its loading state.
  NotificationSettings? settings;

  /// Every update fails (a failed save).
  bool failUpdates;
  final List<Map<String, dynamic>> patches = <Map<String, dynamic>>[];
  final List<String> timezones = <String>[];

  @override
  Future<Result<NotificationSettings, Failure>> load() {
    final s = settings;
    if (s == null) {
      return Completer<Result<NotificationSettings, Failure>>().future;
    }
    return Future.value(Ok(s));
  }

  @override
  Future<Result<NotificationSettings, Failure>> update(
    Map<String, dynamic> patch,
  ) async {
    patches.add(patch);
    if (failUpdates) {
      return const Err(Failure(category: FailureCode.server, message: 'boom'));
    }
    final s = settings!;
    settings = _apply(s, patch);
    return Ok(settings!);
  }

  @override
  Future<Result<NotificationSettings, Failure>> setTimezone(String tz) async {
    timezones.add(tz);
    settings = settings?.copyWith(tz: tz);
    return Ok(settings ?? NotificationSettings.defaults('u1'));
  }

  /// The server's merge rules (SCHEMA.md section 17), enough for the tests.
  static NotificationSettings _apply(
    NotificationSettings s,
    Map<String, dynamic> p,
  ) {
    var out = s;
    if (p['push_enabled'] is bool) {
      out = out.copyWith(pushEnabled: p['push_enabled'] as bool);
    }
    if (p['message_preview'] is String) {
      out = out.copyWith(messagePreview: p['message_preview'] as String);
    }
    final Object? cats = p['category_prefs'];
    if (cats is Map) {
      cats.forEach((k, v) {
        (v as Map).forEach((ch, on) {
          out = out.withCategory(k as String, ch as String, on as bool);
        });
      });
    }
    final Object? rungs = p['reminder_rungs'];
    if (rungs is Map) {
      rungs.forEach((g, v) {
        (v as Map).forEach((r, on) {
          out = out.withRung(g as String, r as String, on as bool);
        });
      });
    }
    if (p['muted_kinds'] is List) {
      out = out.copyWith(
        mutedKinds: List<String>.from(p['muted_kinds'] as List),
      );
    }
    if (p['quiet_hours_enabled'] == false) {
      out = out.copyWith(quietStartMin: null, quietEndMin: null);
    } else if (p['quiet_hours_enabled'] == true) {
      out = out.copyWith(
        quietStartMin: p['quiet_start_min'] as int? ?? 0,
        quietEndMin: p['quiet_end_min'] as int? ?? 480,
      );
    }
    return out;
  }
}
