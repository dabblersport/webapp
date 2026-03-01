// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'comment.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$PostCommentImpl _$$PostCommentImplFromJson(Map<String, dynamic> json) =>
    _$PostCommentImpl(
      id: json['id'] as String,
      postId: json['post_id'] as String,
      authorUserId: json['author_user_id'] as String,
      authorProfileId: json['author_profile_id'] as String,
      authorDisplayName: json['author_display_name'] as String?,
      authorAvatarUrl: json['author_avatar_url'] as String?,
      body: json['body'] as String,
      parentCommentId: json['parent_comment_id'] as String?,
      isDeleted: json['is_deleted'] as bool? ?? false,
      isHiddenAdmin: json['is_hidden_admin'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );

Map<String, dynamic> _$$PostCommentImplToJson(_$PostCommentImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'post_id': instance.postId,
      'author_user_id': instance.authorUserId,
      'author_profile_id': instance.authorProfileId,
      'author_display_name': instance.authorDisplayName,
      'author_avatar_url': instance.authorAvatarUrl,
      'body': instance.body,
      'parent_comment_id': instance.parentCommentId,
      'is_deleted': instance.isDeleted,
      'is_hidden_admin': instance.isHiddenAdmin,
      'created_at': instance.createdAt.toIso8601String(),
    };
