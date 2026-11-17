import 'package:flutter/foundation.dart' show immutable, listEquals, mapEquals;

import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';

import '../notification_settings_repository.dart';
import 'notification_settings_keys.dart';

/// Writes a whole settings value through the RPC (every setting it accepts).
/// For callers that load, change and write back (the row menu's "Turn off
/// notifications like this"); the settings screen sends partial patches.
extension NotificationSettingsSave on NotificationSettingsRepository {
  Future<Result<NotificationSettings, Failure>> save(NotificationSettings s) {
    if (s.mutedKinds.any(notificationKindIsUnmutable)) {
      // SET-13: a security kind is never muted (the server says 22023).
      return Future.value(
        const Err(
          Failure(category: FailureCode.validation, message: 'security-mute'),
        ),
      );
    }
    return update(notificationSettingsFullPatch(s));
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Model: maps 1:1 to `public.notification_settings` (PK user_id), as returned
// by `rpc_get_my_notification_settings` (KAN-975, SCHEMA.md section 17).
// ────────────────────────────────────────────────────────────────────────────

/// Per-user notification preferences.
///
/// KAN-991: in-app and push per category ([categoryPrefs]), the message
/// preview, quiet hours, a switch per reminder rung ([reminderRungs]), muted
/// kinds and the push master switch. Security notices have no setting: they
/// are always on. `email_enabled` / `sms_enabled` and the two override flags
/// are legacy (F-15): read, never shown, never written.
///
/// Hand-written rather than freezed (KAN-991): `build_runner` fails on this
/// codebase today (the analyzer it ships cannot read dot shorthands), and the
/// nested maps need their own equality anyway.
///
/// `created_at` / `updated_at` / `quiet_hours_enabled` exist on the row but
/// are server-managed and intentionally omitted from the model.
@immutable
class NotificationSettings {
  const NotificationSettings({
    required this.userId,
    this.tz = 'Asia/Dubai',
    this.quietStartMin,
    this.quietEndMin,
    this.pushEnabled = true,
    this.emailEnabled = false,
    this.smsEnabled = false,
    this.mutedKinds = const <String>[],
    this.allowHighPriorityOverride = false,
    this.allowAllOverride = false,
    this.messagePreview = NotifPreview.senderAndMessage,
    this.reminderRungs = kDefaultReminderRungs,
    this.categoryPrefs = kDefaultCategoryPrefs,
  });

  final String userId;
  final String tz;

  /// Quiet-hours window as minutes-since-midnight (0–1439), local to [tz].
  /// Both null when quiet hours are off.
  final int? quietStartMin;
  final int? quietEndMin;

  final bool pushEnabled;
  final bool emailEnabled;
  final bool smsEnabled;

  /// `notification_kinds.key`s the user has muted.
  final List<String> mutedKinds;
  final bool allowHighPriorityOverride;
  final bool allowAllOverride;

  /// [NotifPreview.senderAndMessage] (default) or [NotifPreview.senderOnly].
  final String messagePreview;

  /// `{going|interested: {24h, 09:00, 2h, 30m: bool}}`.
  final Map<String, Map<String, bool>> reminderRungs;

  /// `{<category>: {in_app, push: bool}}`.
  final Map<String, Map<String, bool>> categoryPrefs;

  /// Sensible defaults for a user with no row yet (mirrors the table defaults).
  factory NotificationSettings.defaults(String userId) =>
      NotificationSettings(userId: userId);

  static Map<String, Map<String, bool>> _nested(
    Object? raw,
    Map<String, Map<String, bool>> fallback,
  ) {
    if (raw is! Map) return fallback;
    final Map<String, Map<String, bool>> out = <String, Map<String, bool>>{};
    raw.forEach((Object? k, Object? v) {
      if (k is! String || v is! Map) return;
      out[k] = <String, bool>{
        for (final MapEntry<Object?, Object?> e in v.entries)
          if (e.key is String && e.value is bool)
            e.key! as String: e.value! as bool,
      };
    });
    return out;
  }

  factory NotificationSettings.fromJson(Map<String, dynamic> json) {
    final Object? muted = json['muted_kinds'];
    return NotificationSettings(
      userId: json['user_id'] as String,
      tz: json['tz'] as String? ?? 'Asia/Dubai',
      quietStartMin: (json['quiet_start_min'] as num?)?.toInt(),
      quietEndMin: (json['quiet_end_min'] as num?)?.toInt(),
      pushEnabled: json['push_enabled'] as bool? ?? true,
      emailEnabled: json['email_enabled'] as bool? ?? false,
      smsEnabled: json['sms_enabled'] as bool? ?? false,
      mutedKinds: muted is List
          ? muted.whereType<String>().toList()
          : const <String>[],
      allowHighPriorityOverride:
          json['allow_high_priority_override'] as bool? ?? false,
      allowAllOverride: json['allow_all_override'] as bool? ?? false,
      messagePreview:
          json['message_preview'] as String? ?? NotifPreview.senderAndMessage,
      reminderRungs: _nested(json['reminder_rungs'], kDefaultReminderRungs),
      categoryPrefs: _nested(json['category_prefs'], kDefaultCategoryPrefs),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'user_id': userId,
    'tz': tz,
    'quiet_start_min': quietStartMin,
    'quiet_end_min': quietEndMin,
    'push_enabled': pushEnabled,
    'email_enabled': emailEnabled,
    'sms_enabled': smsEnabled,
    'muted_kinds': mutedKinds,
    'allow_high_priority_override': allowHighPriorityOverride,
    'allow_all_override': allowAllOverride,
    'message_preview': messagePreview,
    'reminder_rungs': reminderRungs,
    'category_prefs': categoryPrefs,
  };

  static const Object _keep = Object();

  /// A copy with the given fields replaced. [quietStartMin] / [quietEndMin]
  /// accept null (quiet hours off).
  NotificationSettings copyWith({
    String? userId,
    String? tz,
    Object? quietStartMin = _keep,
    Object? quietEndMin = _keep,
    bool? pushEnabled,
    bool? emailEnabled,
    bool? smsEnabled,
    List<String>? mutedKinds,
    bool? allowHighPriorityOverride,
    bool? allowAllOverride,
    String? messagePreview,
    Map<String, Map<String, bool>>? reminderRungs,
    Map<String, Map<String, bool>>? categoryPrefs,
  }) => NotificationSettings(
    userId: userId ?? this.userId,
    tz: tz ?? this.tz,
    quietStartMin: identical(quietStartMin, _keep)
        ? this.quietStartMin
        : quietStartMin as int?,
    quietEndMin: identical(quietEndMin, _keep)
        ? this.quietEndMin
        : quietEndMin as int?,
    pushEnabled: pushEnabled ?? this.pushEnabled,
    emailEnabled: emailEnabled ?? this.emailEnabled,
    smsEnabled: smsEnabled ?? this.smsEnabled,
    mutedKinds: mutedKinds ?? this.mutedKinds,
    allowHighPriorityOverride:
        allowHighPriorityOverride ?? this.allowHighPriorityOverride,
    allowAllOverride: allowAllOverride ?? this.allowAllOverride,
    messagePreview: messagePreview ?? this.messagePreview,
    reminderRungs: reminderRungs ?? this.reminderRungs,
    categoryPrefs: categoryPrefs ?? this.categoryPrefs,
  );

  // ── Convenience ──────────────────────────────────────────────────────

  /// Whether quiet hours are configured.
  bool get hasQuietHours => quietStartMin != null && quietEndMin != null;

  /// Whether the preview shows the sender name only.
  bool get previewSenderOnly => messagePreview == NotifPreview.senderOnly;

  /// Whether [kindKey] is currently muted.
  bool isKindMuted(String kindKey) => mutedKinds.contains(kindKey);

  /// Whether [category] is on for [channel]; a missing key reads as on.
  bool categoryOn(String category, String channel) =>
      categoryPrefs[category]?[channel] ?? true;

  /// Whether the reminder [rung] of [group] is on; a missing key reads as on.
  bool rungOn(String group, String rung) => reminderRungs[group]?[rung] ?? true;

  /// Returns a copy with [category] / [channel] set to [on].
  NotificationSettings withCategory(String category, String channel, bool on) =>
      copyWith(
        categoryPrefs: {
          ...categoryPrefs,
          category: {...?categoryPrefs[category], channel: on},
        },
      );

  /// Returns a copy with the reminder [rung] of [group] set to [on].
  NotificationSettings withRung(String group, String rung, bool on) => copyWith(
    reminderRungs: {
      ...reminderRungs,
      group: {...?reminderRungs[group], rung: on},
    },
  );

  /// Returns a copy with [kindKeys] muted (when [muted]) or unmuted.
  NotificationSettings withKindsMuted(List<String> kindKeys, bool muted) {
    final next = {...mutedKinds};
    if (muted) {
      next.addAll(kindKeys);
    } else {
      next.removeAll(kindKeys);
    }
    return copyWith(mutedKinds: next.toList()..sort());
  }

  static bool _nestedEquals(
    Map<String, Map<String, bool>> a,
    Map<String, Map<String, bool>> b,
  ) {
    if (a.length != b.length) return false;
    for (final MapEntry<String, Map<String, bool>> e in a.entries) {
      if (!mapEquals(e.value, b[e.key])) return false;
    }
    return true;
  }

  @override
  bool operator ==(Object other) =>
      other is NotificationSettings &&
      other.userId == userId &&
      other.tz == tz &&
      other.quietStartMin == quietStartMin &&
      other.quietEndMin == quietEndMin &&
      other.pushEnabled == pushEnabled &&
      other.emailEnabled == emailEnabled &&
      other.smsEnabled == smsEnabled &&
      listEquals(other.mutedKinds, mutedKinds) &&
      other.allowHighPriorityOverride == allowHighPriorityOverride &&
      other.allowAllOverride == allowAllOverride &&
      other.messagePreview == messagePreview &&
      _nestedEquals(other.reminderRungs, reminderRungs) &&
      _nestedEquals(other.categoryPrefs, categoryPrefs);

  @override
  int get hashCode => Object.hash(
    userId,
    tz,
    quietStartMin,
    quietEndMin,
    pushEnabled,
    Object.hashAll(mutedKinds),
    messagePreview,
  );
}

/// The `rpc_update_my_notification_settings` patch that writes every setting
/// of [s] the RPC accepts (the timezone has its own RPC). The legacy email,
/// SMS and override flags are never sent: the RPC rejects them (22023).
Map<String, dynamic> notificationSettingsFullPatch(NotificationSettings s) => {
  'quiet_hours_enabled': s.hasQuietHours,
  if (s.hasQuietHours) ...{
    'quiet_start_min': s.quietStartMin,
    'quiet_end_min': s.quietEndMin,
  },
  'message_preview': s.messagePreview,
  'reminder_rungs': s.reminderRungs,
  'category_prefs': s.categoryPrefs,
  'muted_kinds': s.mutedKinds,
  'push_enabled': s.pushEnabled,
};
