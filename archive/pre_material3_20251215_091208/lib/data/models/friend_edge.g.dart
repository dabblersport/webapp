// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'friend_edge.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$FriendEdgeImpl _$$FriendEdgeImplFromJson(Map<String, dynamic> json) =>
    _$FriendEdgeImpl(
      id: json['id'] as String,
      userA: json['user_a'] as String,
      userB: json['user_b'] as String,
      status: json['status'] as String,
      requestedBy: json['requested_by'] as String,
      respondedBy: json['responded_by'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );

Map<String, dynamic> _$$FriendEdgeImplToJson(_$FriendEdgeImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'user_a': instance.userA,
      'user_b': instance.userB,
      'status': instance.status,
      'requested_by': instance.requestedBy,
      'responded_by': instance.respondedBy,
      'created_at': instance.createdAt.toIso8601String(),
      'updated_at': instance.updatedAt.toIso8601String(),
    };
