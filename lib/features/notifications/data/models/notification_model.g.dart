// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notification_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$AppNotificationImpl _$$AppNotificationImplFromJson(
  Map<String, dynamic> json,
) => _$AppNotificationImpl(
  id: json['id'] as String,
  toUserId: json['to_user_id'] as String,
  kindKey: json['kind_key'] as String,
  title: json['title'] as String,
  body: json['body'] as String?,
  actionRoute: json['action_route'] as String?,
  payload: json['context'] as Map<String, dynamic>?,
  priority:
      $enumDecodeNullable(_$NotifyPriorityEnumMap, json['priority']) ??
      NotifyPriority.normal,
  aiScore: (json['ai_score'] as num?)?.toDouble(),
  isRead: json['is_read'] as bool? ?? false,
  readAt: json['read_at'] == null
      ? null
      : DateTime.parse(json['read_at'] as String),
  clickedAt: json['clicked_at'] == null
      ? null
      : DateTime.parse(json['clicked_at'] as String),
  interactionCount: (json['interaction_count'] as num?)?.toInt() ?? 0,
  createdAt: DateTime.parse(json['created_at'] as String),
  templateKey: json['template_key'] as String?,
  args: json['args'] == null
      ? const <String, dynamic>{}
      : _argsFromJson(json['args']),
  sourceEventId: json['source_event_id'] as String?,
  dedupeKey: json['dedupe_key'] as String?,
  groupKey: json['group_key'] as String?,
  schemaVersion: json['schema_version'] == null
      ? 1
      : _schemaVersionFromJson(json['schema_version']),
);

Map<String, dynamic> _$$AppNotificationImplToJson(
  _$AppNotificationImpl instance,
) => <String, dynamic>{
  'id': instance.id,
  'to_user_id': instance.toUserId,
  'kind_key': instance.kindKey,
  'title': instance.title,
  'body': instance.body,
  'action_route': instance.actionRoute,
  'context': instance.payload,
  'priority': _$NotifyPriorityEnumMap[instance.priority]!,
  'ai_score': instance.aiScore,
  'is_read': instance.isRead,
  'read_at': instance.readAt?.toIso8601String(),
  'clicked_at': instance.clickedAt?.toIso8601String(),
  'interaction_count': instance.interactionCount,
  'created_at': instance.createdAt.toIso8601String(),
  'template_key': instance.templateKey,
  'args': instance.args,
  'source_event_id': instance.sourceEventId,
  'dedupe_key': instance.dedupeKey,
  'group_key': instance.groupKey,
  'schema_version': instance.schemaVersion,
};

const _$NotifyPriorityEnumMap = {
  NotifyPriority.low: 'low',
  NotifyPriority.normal: 'normal',
  NotifyPriority.high: 'high',
  NotifyPriority.urgent: 'urgent',
};
