// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'squad_join_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$SquadJoinRequestImpl _$$SquadJoinRequestImplFromJson(
  Map<String, dynamic> json,
) => _$SquadJoinRequestImpl(
  id: json['id'] as String,
  squadId: json['squad_id'] as String,
  userId: json['user_id'] as String,
  profileId: json['profile_id'] as String,
  status: json['status'] as String,
  message: json['message'] as String?,
  createdAt: DateTime.parse(json['created_at'] as String),
  decidedAt: json['decided_at'] == null
      ? null
      : DateTime.parse(json['decided_at'] as String),
);

Map<String, dynamic> _$$SquadJoinRequestImplToJson(
  _$SquadJoinRequestImpl instance,
) => <String, dynamic>{
  'id': instance.id,
  'squad_id': instance.squadId,
  'user_id': instance.userId,
  'profile_id': instance.profileId,
  'status': instance.status,
  'message': instance.message,
  'created_at': instance.createdAt.toIso8601String(),
  'decided_at': instance.decidedAt?.toIso8601String(),
};
