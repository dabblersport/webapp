// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'friendship.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$FriendshipImpl _$$FriendshipImplFromJson(Map<String, dynamic> json) =>
    _$FriendshipImpl(
      userId: json['user_id'] as String,
      peerUserId: json['peer_user_id'] as String,
      requestedBy: json['requested_by'] as String?,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );

Map<String, dynamic> _$$FriendshipImplToJson(_$FriendshipImpl instance) =>
    <String, dynamic>{
      'user_id': instance.userId,
      'peer_user_id': instance.peerUserId,
      'requested_by': instance.requestedBy,
      'status': instance.status,
      'created_at': instance.createdAt.toIso8601String(),
      'updated_at': instance.updatedAt.toIso8601String(),
    };
