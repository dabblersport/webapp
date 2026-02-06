// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'squad_invite.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$SquadInviteImpl _$$SquadInviteImplFromJson(Map<String, dynamic> json) =>
    _$SquadInviteImpl(
      id: json['id'] as String,
      squadId: json['squad_id'] as String,
      toProfileId: json['to_profile_id'] as String,
      toUserId: json['to_user_id'] as String,
      createdByProfileId: json['created_by_profile_id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      status: json['status'] as String,
      expiresAt: json['expires_at'] == null
          ? null
          : DateTime.parse(json['expires_at'] as String),
    );

Map<String, dynamic> _$$SquadInviteImplToJson(_$SquadInviteImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'squad_id': instance.squadId,
      'to_profile_id': instance.toProfileId,
      'to_user_id': instance.toUserId,
      'created_by_profile_id': instance.createdByProfileId,
      'created_at': instance.createdAt.toIso8601String(),
      'status': instance.status,
      'expires_at': instance.expiresAt?.toIso8601String(),
    };
