import 'package:freezed_annotation/freezed_annotation.dart';

part 'notification_model.freezed.dart';
part 'notification_model.g.dart';

// ────────────────────────────────────────────────────────────────────────────
// Enum: maps 1:1 to the Postgres `notify_priority` enum
// ────────────────────────────────────────────────────────────────────────────

@JsonEnum(valueField: 'value')
enum NotifyPriority {
  low('low'),
  normal('normal'),
  high('high'),
  urgent('urgent');

  const NotifyPriority(this.value);
  final String value;
}

// ────────────────────────────────────────────────────────────────────────────
// Model: maps 1:1 to `public.notifications`
// ────────────────────────────────────────────────────────────────────────────

/// Single source-of-truth model for the `public.notifications` table.
///
/// Named `AppNotification` to avoid shadowing Flutter's built-in
/// `Notification` widget class.
@freezed
class AppNotification with _$AppNotification {
  const AppNotification._();

  const factory AppNotification({
    required String id,
    @JsonKey(name: 'to_user_id') required String toUserId,
    @JsonKey(name: 'kind_key') required String kindKey,
    required String title,
    String? body,
    @JsonKey(name: 'action_route') String? actionRoute,

    /// Arbitrary JSONB payload from the DB (e.g. actor info, post id, etc.)
    @JsonKey(name: 'context') Map<String, dynamic>? payload,

    @Default(NotifyPriority.normal) NotifyPriority priority,
    @JsonKey(name: 'ai_score') double? aiScore,

    @JsonKey(name: 'is_read') @Default(false) bool isRead,
    @JsonKey(name: 'read_at') DateTime? readAt,
    @JsonKey(name: 'clicked_at') DateTime? clickedAt,

    @JsonKey(name: 'interaction_count') @Default(0) int interactionCount,
    @JsonKey(name: 'created_at') required DateTime createdAt,
  }) = _AppNotification;

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      _$AppNotificationFromJson(json);

  // ── Convenience getters ──────────────────────────────────────────────

  /// Whether the notification has been clicked at least once.
  bool get isClicked => clickedAt != null;

  /// Whether this is a high-priority or urgent notification.
  bool get isHighPriority =>
      priority == NotifyPriority.high || priority == NotifyPriority.urgent;
}
