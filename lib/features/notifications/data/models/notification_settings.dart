import 'package:freezed_annotation/freezed_annotation.dart';

part 'notification_settings.freezed.dart';
part 'notification_settings.g.dart';

// ────────────────────────────────────────────────────────────────────────────
// Model: maps 1:1 to `public.notification_settings` (PK user_id)
// ────────────────────────────────────────────────────────────────────────────

/// Per-user notification preferences.
///
/// Channel toggles (`pushEnabled` / `emailEnabled` / `smsEnabled`), quiet
/// hours, and a list of muted `notification_kinds.key`s. The push trigger
/// (`trg_push_on_notification_insert`) consults these before sending a push,
/// honoring the override flags for high-priority / urgent kinds.
///
/// `created_at` / `updated_at` exist in the table but are server-managed and
/// intentionally omitted from the model.
@freezed
class NotificationSettings with _$NotificationSettings {
  const NotificationSettings._();

  const factory NotificationSettings({
    @JsonKey(name: 'user_id') required String userId,
    @Default('Asia/Dubai') String tz,

    /// Quiet-hours window as minutes-since-midnight (0–1439), local to [tz].
    /// Null when quiet hours are disabled.
    @JsonKey(name: 'quiet_start_min') int? quietStartMin,
    @JsonKey(name: 'quiet_end_min') int? quietEndMin,

    @JsonKey(name: 'push_enabled') @Default(true) bool pushEnabled,
    @JsonKey(name: 'email_enabled') @Default(false) bool emailEnabled,
    @JsonKey(name: 'sms_enabled') @Default(false) bool smsEnabled,

    /// `notification_kinds.key`s the user has muted.
    @JsonKey(name: 'muted_kinds') @Default(<String>[]) List<String> mutedKinds,

    @JsonKey(name: 'allow_high_priority_override')
    @Default(false)
    bool allowHighPriorityOverride,
    @JsonKey(name: 'allow_all_override') @Default(false) bool allowAllOverride,
  }) = _NotificationSettings;

  factory NotificationSettings.fromJson(Map<String, dynamic> json) =>
      _$NotificationSettingsFromJson(json);

  /// Sensible defaults for a user with no row yet (mirrors the table defaults).
  factory NotificationSettings.defaults(String userId) =>
      NotificationSettings(userId: userId);

  // ── Convenience ──────────────────────────────────────────────────────

  /// Whether quiet hours are configured.
  bool get hasQuietHours => quietStartMin != null && quietEndMin != null;

  /// Whether [kindKey] is currently muted.
  bool isKindMuted(String kindKey) => mutedKinds.contains(kindKey);

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
}
