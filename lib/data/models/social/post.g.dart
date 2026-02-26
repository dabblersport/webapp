// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'post.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$PostImpl _$$PostImplFromJson(Map<String, dynamic> json) => _$PostImpl(
  id: json['id'] as String,
  authorProfileId: json['author_profile_id'] as String,
  authorUserId: json['author_user_id'] as String,
  authorDisplayName: json['author_display_name'] as String?,
  authorAvatarUrl: json['author_avatar_url'] as String?,
  authorUsername: json['author_username'] as String?,
  kind: _postKindFromJson(json['kind'] as String),
  postType: json['post_type'] == null
      ? PostType.dab
      : _postTypeFromJson(json['post_type'] as String?),
  originType: json['origin_type'] == null
      ? OriginType.manual
      : _originTypeFromJson(json['origin_type'] as String?),
  visibility: _visibilityFromJson(json['visibility'] as String),
  linkToken: json['link_token'] as String?,
  body: json['body'] as String?,
  lang: json['lang'] as String?,
  sport: json['sport'] as String?,
  media: json['media'] == null
      ? const <dynamic>[]
      : _mediaFromJson(json['media']),
  venueId: json['venue_id'] as String?,
  geoLat: (json['geo_lat'] as num?)?.toDouble(),
  geoLng: (json['geo_lng'] as num?)?.toDouble(),
  gameId: json['game_id'] as String?,
  sportId: json['sport_id'] as String?,
  locationTagId: json['location_tag_id'] as String?,
  primaryVibeId: json['vibe_id'] as String?,
  originId: json['origin_id'] as String?,
  contentClass: json['content_class'] as String?,
  tags: json['tags'] == null ? const <String>[] : _tagsFromJson(json['tags']),
  likeCount: (json['like_count'] as num?)?.toInt() ?? 0,
  commentCount: (json['comment_count'] as num?)?.toInt() ?? 0,
  viewCount: (json['view_count'] as num?)?.toInt() ?? 0,
  priorityScore: (json['priority_score'] as num?)?.toInt() ?? 0,
  isDeleted: json['is_deleted'] as bool? ?? false,
  isHiddenAdmin: json['is_hidden_admin'] as bool? ?? false,
  isActive: json['is_active'] as bool? ?? true,
  allowReposts: json['allow_reposts'] as bool? ?? true,
  isPinned: json['is_pinned'] as bool? ?? false,
  isEdited: json['is_edited'] as bool? ?? false,
  requiresModeration: json['requires_moderation'] as bool? ?? false,
  personaTypeSnapshot: json['persona_type_snapshot'] as String?,
  reactionBreakdown: json['reaction_breakdown'] == null
      ? const <String, dynamic>{}
      : _reactionBreakdownFromJson(json['reaction_breakdown']),
  vibes: json['post_vibes'] == null
      ? const <Vibe>[]
      : _vibesFromJson(json['post_vibes']),
  createdAt: DateTime.parse(json['created_at'] as String),
  updatedAt: DateTime.parse(json['updated_at'] as String),
  expiresAt: json['expires_at'] == null
      ? null
      : DateTime.parse(json['expires_at'] as String),
  editedAt: json['edited_at'] == null
      ? null
      : DateTime.parse(json['edited_at'] as String),
);

Map<String, dynamic> _$$PostImplToJson(
  _$PostImpl instance,
) => <String, dynamic>{
  'id': instance.id,
  'author_profile_id': instance.authorProfileId,
  'author_user_id': instance.authorUserId,
  'author_display_name': instance.authorDisplayName,
  'author_avatar_url': instance.authorAvatarUrl,
  'author_username': instance.authorUsername,
  'kind': _postKindToJson(instance.kind),
  'post_type': _postTypeToJson(instance.postType),
  'origin_type': _originTypeToJson(instance.originType),
  'visibility': _visibilityToJson(instance.visibility),
  'link_token': instance.linkToken,
  'body': instance.body,
  'lang': instance.lang,
  'sport': instance.sport,
  'media': _mediaToJson(instance.media),
  'venue_id': instance.venueId,
  'geo_lat': instance.geoLat,
  'geo_lng': instance.geoLng,
  'game_id': instance.gameId,
  'sport_id': instance.sportId,
  'location_tag_id': instance.locationTagId,
  'vibe_id': instance.primaryVibeId,
  'origin_id': instance.originId,
  'content_class': instance.contentClass,
  'tags': _tagsToJson(instance.tags),
  'like_count': instance.likeCount,
  'comment_count': instance.commentCount,
  'view_count': instance.viewCount,
  'priority_score': instance.priorityScore,
  'is_deleted': instance.isDeleted,
  'is_hidden_admin': instance.isHiddenAdmin,
  'is_active': instance.isActive,
  'allow_reposts': instance.allowReposts,
  'is_pinned': instance.isPinned,
  'is_edited': instance.isEdited,
  'requires_moderation': instance.requiresModeration,
  'persona_type_snapshot': instance.personaTypeSnapshot,
  'reaction_breakdown': _reactionBreakdownToJson(instance.reactionBreakdown),
  'post_vibes': _vibesToJson(instance.vibes),
  'created_at': instance.createdAt.toIso8601String(),
  'updated_at': instance.updatedAt.toIso8601String(),
  'expires_at': instance.expiresAt?.toIso8601String(),
  'edited_at': instance.editedAt?.toIso8601String(),
};
