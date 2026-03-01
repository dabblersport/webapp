import 'dart:convert';

import 'package:freezed_annotation/freezed_annotation.dart';

import 'post_enums.dart';
import 'vibe.dart';

part 'post.freezed.dart';
part 'post.g.dart';

/// Domain model for a post, mapping 1:1 to the `posts` table.
@freezed
class Post with _$Post {
  const factory Post({
    required String id,
    @JsonKey(name: 'author_profile_id') required String authorProfileId,
    @JsonKey(name: 'author_user_id') required String authorUserId,
    @JsonKey(name: 'author_display_name') String? authorDisplayName,
    @JsonKey(name: 'author_avatar_url') String? authorAvatarUrl,
    @JsonKey(name: 'author_username') String? authorUsername,
    @JsonKey(name: 'author_sport_emoji') String? authorSportEmoji,

    /// `post_kind` enum column (NOT NULL in DB).
    @JsonKey(fromJson: _postKindFromJson, toJson: _postKindToJson)
    required PostKind kind,

    /// `post_type_enum` column (nullable in DB, default 'dab').
    @JsonKey(
      name: 'post_type',
      fromJson: _postTypeFromJson,
      toJson: _postTypeToJson,
    )
    @Default(PostType.dab)
    PostType postType,

    /// `origin_type_enum` column (nullable in DB, default 'manual').
    @JsonKey(
      name: 'origin_type',
      fromJson: _originTypeFromJson,
      toJson: _originTypeToJson,
    )
    @Default(OriginType.manual)
    OriginType originType,

    /// Text column: public | followers | circle | squad | private | link.
    @JsonKey(fromJson: _visibilityFromJson, toJson: _visibilityToJson)
    required PostVisibility visibility,

    @JsonKey(name: 'link_token') String? linkToken,
    String? body,
    String? lang,
    String? sport,

    /// jsonb column, default '[]'. Supabase returns as List.
    @JsonKey(fromJson: _mediaFromJson, toJson: _mediaToJson)
    @Default(<dynamic>[])
    List<dynamic> media,

    @JsonKey(name: 'venue_id') String? venueId,
    @JsonKey(name: 'geo_lat') double? geoLat,
    @JsonKey(name: 'geo_lng') double? geoLng,
    @JsonKey(name: 'game_id') String? gameId,
    @JsonKey(name: 'sport_id') String? sportId,
    @JsonKey(name: 'location_tag_id') String? locationTagId,
    @JsonKey(name: 'vibe_id') String? primaryVibeId,
    @JsonKey(name: 'origin_id') String? originId,
    @JsonKey(name: 'content_class') String? contentClass,

    /// text[] column, nullable in DB, default '{}'.
    @JsonKey(fromJson: _tagsFromJson, toJson: _tagsToJson)
    @Default(<String>[])
    List<String> tags,

    @JsonKey(name: 'like_count') @Default(0) int likeCount,
    @JsonKey(name: 'comment_count') @Default(0) int commentCount,
    @JsonKey(name: 'view_count') @Default(0) int viewCount,
    @JsonKey(name: 'priority_score') @Default(0) int priorityScore,

    @JsonKey(name: 'is_deleted') @Default(false) bool isDeleted,
    @JsonKey(name: 'is_hidden_admin') @Default(false) bool isHiddenAdmin,
    @JsonKey(name: 'is_active') @Default(true) bool isActive,
    @JsonKey(name: 'allow_reposts') @Default(true) bool allowReposts,
    @JsonKey(name: 'is_pinned') @Default(false) bool isPinned,
    @JsonKey(name: 'is_edited') @Default(false) bool isEdited,
    @JsonKey(name: 'requires_moderation')
    @Default(false)
    bool requiresModeration,

    @JsonKey(name: 'persona_type_snapshot') String? personaTypeSnapshot,

    /// jsonb column, nullable in DB, default '{}'. Supabase returns as Map.
    @JsonKey(
      name: 'reaction_breakdown',
      fromJson: _reactionBreakdownFromJson,
      toJson: _reactionBreakdownToJson,
    )
    @Default(<String, dynamic>{})
    Map<String, dynamic> reactionBreakdown,

    /// Vibes from the direct `vibe_id` FK, synthesised by the repository
    /// into the `post_vibes` key so [_vibesFromJson] can parse them.
    @JsonKey(name: 'post_vibes', fromJson: _vibesFromJson, toJson: _vibesToJson)
    @Default(<Vibe>[])
    List<Vibe> vibes,

    @JsonKey(name: 'created_at') required DateTime createdAt,
    @JsonKey(name: 'updated_at') required DateTime updatedAt,
    @JsonKey(name: 'expires_at') DateTime? expiresAt,
    @JsonKey(name: 'edited_at') DateTime? editedAt,
  }) = _Post;

  factory Post.fromJson(Map<String, dynamic> json) => _$PostFromJson(json);
}

// ── Private helpers for enum serialization ────────────────────────────

PostKind _postKindFromJson(String value) => PostKind.fromString(value);
String _postKindToJson(PostKind v) => v.name;

PostType _postTypeFromJson(String? value) =>
    value == null ? PostType.dab : PostType.fromString(value);
String _postTypeToJson(PostType v) => v.dbValue;

OriginType _originTypeFromJson(String? value) =>
    value == null ? OriginType.manual : OriginType.fromString(value);
String _originTypeToJson(OriginType v) => v.name;

PostVisibility _visibilityFromJson(String value) =>
    PostVisibility.fromString(value);
String _visibilityToJson(PostVisibility v) => v.name;

// ── Private helpers for JSON collection fields ────────────────────────

List<dynamic> _mediaFromJson(dynamic value) {
  if (value is List) return value;
  if (value is String && value.trim().isNotEmpty) {
    try {
      final decoded = jsonDecode(value);
      if (decoded is List) return decoded;
    } catch (_) {
      return [];
    }
  }
  return [];
}

List<dynamic> _mediaToJson(List<dynamic> v) => v;

List<String> _tagsFromJson(dynamic value) =>
    _toDynamicList(value).map((e) => e.toString()).toList();
List<String> _tagsToJson(List<String> v) => v;

Map<String, dynamic> _reactionBreakdownFromJson(dynamic value) {
  if (value is Map) {
    return value.cast<String, dynamic>();
  }
  if (value is String && value.trim().isNotEmpty) {
    try {
      final decoded = jsonDecode(value);
      if (decoded is Map) return decoded.cast<String, dynamic>();
    } catch (_) {
      return {};
    }
  }
  return {};
}

Map<String, dynamic> _reactionBreakdownToJson(Map<String, dynamic> v) => v;

// ── Vibes nested-select helpers ───────────────────────────────────

/// Parse the synthetic `post_vibes` key injected by the repository from
/// the direct `vibe_id` FK join. Each element: `{ "vibe": { "id": ... } }`
List<Vibe> _vibesFromJson(dynamic value) {
  if (value is! List) return [];
  return value
      .whereType<Map<String, dynamic>>()
      .map((pv) => pv['vibe'])
      .where((v) => v != null && v is Map<String, dynamic>)
      .map((v) => Vibe.fromMap(v as Map<String, dynamic>))
      .toList();
}

List<Map<String, dynamic>> _vibesToJson(List<Vibe> vibes) =>
    vibes.map((v) => {'vibe': v.toMap()}).toList();

List<dynamic> _toDynamicList(dynamic value) {
  if (value is List) return value;
  if (value is String && value.trim().isNotEmpty) {
    try {
      final decoded = jsonDecode(value);
      if (decoded is List) return decoded;
    } catch (_) {
      return [];
    }
  }
  return [];
}
