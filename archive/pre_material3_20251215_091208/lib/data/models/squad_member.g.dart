// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'squad_member.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$SquadMemberImpl _$$SquadMemberImplFromJson(Map<String, dynamic> json) =>
    _$SquadMemberImpl(
      squadId: json['squad_id'] as String,
      profileId: json['profile_id'] as String,
      userId: json['user_id'] as String,
      role: json['role'] as String,
      joinedAt: DateTime.parse(json['joined_at'] as String),
      leftAt: json['left_at'] == null
          ? null
          : DateTime.parse(json['left_at'] as String),
      status: json['status'] as String,
    );

Map<String, dynamic> _$$SquadMemberImplToJson(_$SquadMemberImpl instance) =>
    <String, dynamic>{
      'squad_id': instance.squadId,
      'profile_id': instance.profileId,
      'user_id': instance.userId,
      'role': instance.role,
      'joined_at': instance.joinedAt.toIso8601String(),
      'left_at': instance.leftAt?.toIso8601String(),
      'status': instance.status,
    };
