// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'squad_link_token.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$SquadLinkTokenImpl _$$SquadLinkTokenImplFromJson(Map<String, dynamic> json) =>
    _$SquadLinkTokenImpl(
      id: json['id'] as String,
      squadId: json['squad_id'] as String,
      token: json['token'] as String,
      createdBy: json['created_by'] as String,
      active: json['active'] as bool,
      maxUses: (json['max_uses'] as num?)?.toInt(),
      usedCount: (json['used_count'] as num).toInt(),
      expiresAt: json['expires_at'] == null
          ? null
          : DateTime.parse(json['expires_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
    );

Map<String, dynamic> _$$SquadLinkTokenImplToJson(
  _$SquadLinkTokenImpl instance,
) => <String, dynamic>{
  'id': instance.id,
  'squad_id': instance.squadId,
  'token': instance.token,
  'created_by': instance.createdBy,
  'active': instance.active,
  'max_uses': instance.maxUses,
  'used_count': instance.usedCount,
  'expires_at': instance.expiresAt?.toIso8601String(),
  'created_at': instance.createdAt.toIso8601String(),
};
