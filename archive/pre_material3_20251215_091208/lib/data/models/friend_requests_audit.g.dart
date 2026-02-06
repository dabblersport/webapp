// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'friend_requests_audit.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$FriendRequestAuditImpl _$$FriendRequestAuditImplFromJson(
  Map<String, dynamic> json,
) => _$FriendRequestAuditImpl(
  id: json['id'] as String,
  fromUser: json['from_user'] as String,
  toUser: json['to_user'] as String,
  action: json['action'] as String,
  edgeId: json['edge_id'] as String?,
  createdAt: DateTime.parse(json['created_at'] as String),
);

Map<String, dynamic> _$$FriendRequestAuditImplToJson(
  _$FriendRequestAuditImpl instance,
) => <String, dynamic>{
  'id': instance.id,
  'from_user': instance.fromUser,
  'to_user': instance.toUser,
  'action': instance.action,
  'edge_id': instance.edgeId,
  'created_at': instance.createdAt.toIso8601String(),
};
