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

    // ── Envelope v2 (KAN-974). A legacy row (schema_version 1) has none of
    // these; it renders from title / body / action_route as before. ──────

    /// The `notification_kinds` key whose templates rendered the row.
    @JsonKey(name: 'template_key') String? templateKey,

    /// Template arguments; `{name}_en` / `{name}_ar` override `{name}`.
    @JsonKey(name: 'args', fromJson: _argsFromJson)
    @Default(<String, dynamic>{})
    Map<String, dynamic> args,

    /// The domain event that produced the row (e.g. an `event_changes` id).
    @JsonKey(name: 'source_event_id') String? sourceEventId,

    /// Idempotency key, unique per recipient.
    @JsonKey(name: 'dedupe_key') String? dedupeKey,

    /// Grouping key: a grouped row is updated in place (KAN-980).
    @JsonKey(name: 'group_key') String? groupKey,

    /// 1 = legacy row, 2 = written by notify_v2.
    @JsonKey(name: 'schema_version', fromJson: _schemaVersionFromJson)
    @Default(1)
    int schemaVersion,
  }) = _AppNotification;

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      _$AppNotificationFromJson(json);

  // ── Convenience getters ──────────────────────────────────────────────

  /// Whether the notification has been clicked at least once.
  bool get isClicked => clickedAt != null;

  /// Whether this is a high-priority or urgent notification.
  bool get isHighPriority =>
      priority == NotifyPriority.high || priority == NotifyPriority.urgent;

  /// Whether notify_v2 wrote the row (it carries a template and arguments).
  bool get isV2 => schemaVersion >= 2;
}

/// `args` is a jsonb object; anything else (null, a legacy row) is empty.
Map<String, dynamic> _argsFromJson(Object? raw) =>
    raw is Map ? Map<String, dynamic>.from(raw) : const <String, dynamic>{};

/// `schema_version` defaults to 1 (legacy) when absent or not a number.
int _schemaVersionFromJson(Object? raw) => raw is num ? raw.toInt() : 1;
