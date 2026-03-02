// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'post.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

Post _$PostFromJson(Map<String, dynamic> json) {
  return _Post.fromJson(json);
}

/// @nodoc
mixin _$Post {
  String get id => throw _privateConstructorUsedError;
  @JsonKey(name: 'author_profile_id')
  String get authorProfileId => throw _privateConstructorUsedError;
  @JsonKey(name: 'author_user_id')
  String get authorUserId => throw _privateConstructorUsedError;
  @JsonKey(name: 'author_display_name')
  String? get authorDisplayName => throw _privateConstructorUsedError;
  @JsonKey(name: 'author_avatar_url')
  String? get authorAvatarUrl => throw _privateConstructorUsedError;
  @JsonKey(name: 'author_username')
  String? get authorUsername => throw _privateConstructorUsedError;
  @JsonKey(name: 'author_sport_emoji')
  String? get authorSportEmoji => throw _privateConstructorUsedError;

  /// `post_kind` enum column (NOT NULL in DB).
  @JsonKey(fromJson: _postKindFromJson, toJson: _postKindToJson)
  PostKind get kind => throw _privateConstructorUsedError;

  /// `post_type_enum` column (nullable in DB, default 'dab').
  @JsonKey(
    name: 'post_type',
    fromJson: _postTypeFromJson,
    toJson: _postTypeToJson,
  )
  PostType get postType => throw _privateConstructorUsedError;

  /// `origin_type_enum` column (nullable in DB, default 'manual').
  @JsonKey(
    name: 'origin_type',
    fromJson: _originTypeFromJson,
    toJson: _originTypeToJson,
  )
  OriginType get originType => throw _privateConstructorUsedError;

  /// Text column: public | followers | circle | squad | private | link.
  @JsonKey(fromJson: _visibilityFromJson, toJson: _visibilityToJson)
  PostVisibility get visibility => throw _privateConstructorUsedError;
  @JsonKey(name: 'link_token')
  String? get linkToken => throw _privateConstructorUsedError;
  String? get body => throw _privateConstructorUsedError;
  String? get lang => throw _privateConstructorUsedError;
  String? get sport => throw _privateConstructorUsedError;

  /// jsonb column, default '[]'. Supabase returns as List.
  @JsonKey(fromJson: _mediaFromJson, toJson: _mediaToJson)
  List<dynamic> get media => throw _privateConstructorUsedError;
  @JsonKey(name: 'venue_id')
  String? get venueId => throw _privateConstructorUsedError;
  @JsonKey(name: 'geo_lat')
  double? get geoLat => throw _privateConstructorUsedError;
  @JsonKey(name: 'geo_lng')
  double? get geoLng => throw _privateConstructorUsedError;
  @JsonKey(name: 'game_id')
  String? get gameId => throw _privateConstructorUsedError;
  @JsonKey(name: 'sport_id')
  String? get sportId => throw _privateConstructorUsedError;
  @JsonKey(name: 'location_tag_id')
  String? get locationTagId => throw _privateConstructorUsedError;
  @JsonKey(name: 'location_name')
  String? get locationName => throw _privateConstructorUsedError;
  @JsonKey(name: 'vibe_id')
  String? get primaryVibeId => throw _privateConstructorUsedError;
  @JsonKey(name: 'origin_id')
  String? get originId => throw _privateConstructorUsedError;
  @JsonKey(name: 'content_class')
  String? get contentClass => throw _privateConstructorUsedError;

  /// text[] column, nullable in DB, default '{}'.
  @JsonKey(fromJson: _tagsFromJson, toJson: _tagsToJson)
  List<String> get tags => throw _privateConstructorUsedError;
  @JsonKey(name: 'like_count')
  int get likeCount => throw _privateConstructorUsedError;
  @JsonKey(name: 'comment_count')
  int get commentCount => throw _privateConstructorUsedError;
  @JsonKey(name: 'view_count')
  int get viewCount => throw _privateConstructorUsedError;
  @JsonKey(name: 'priority_score')
  int get priorityScore => throw _privateConstructorUsedError;
  @JsonKey(name: 'is_deleted')
  bool get isDeleted => throw _privateConstructorUsedError;
  @JsonKey(name: 'is_hidden_admin')
  bool get isHiddenAdmin => throw _privateConstructorUsedError;
  @JsonKey(name: 'is_active')
  bool get isActive => throw _privateConstructorUsedError;
  @JsonKey(name: 'allow_reposts')
  bool get allowReposts => throw _privateConstructorUsedError;
  @JsonKey(name: 'is_pinned')
  bool get isPinned => throw _privateConstructorUsedError;
  @JsonKey(name: 'is_edited')
  bool get isEdited => throw _privateConstructorUsedError;
  @JsonKey(name: 'requires_moderation')
  bool get requiresModeration => throw _privateConstructorUsedError;
  @JsonKey(name: 'persona_type_snapshot')
  String? get personaTypeSnapshot => throw _privateConstructorUsedError;

  /// jsonb column, nullable in DB, default '{}'. Supabase returns as Map.
  @JsonKey(
    name: 'reaction_breakdown',
    fromJson: _reactionBreakdownFromJson,
    toJson: _reactionBreakdownToJson,
  )
  Map<String, dynamic> get reactionBreakdown =>
      throw _privateConstructorUsedError;

  /// Vibes from the direct `vibe_id` FK, synthesised by the repository
  /// into the `post_vibes` key so [_vibesFromJson] can parse them.
  @JsonKey(name: 'post_vibes', fromJson: _vibesFromJson, toJson: _vibesToJson)
  List<Vibe> get vibes => throw _privateConstructorUsedError;
  @JsonKey(name: 'created_at')
  DateTime get createdAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'updated_at')
  DateTime get updatedAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'expires_at')
  DateTime? get expiresAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'edited_at')
  DateTime? get editedAt => throw _privateConstructorUsedError;

  /// Serializes this Post to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Post
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $PostCopyWith<Post> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PostCopyWith<$Res> {
  factory $PostCopyWith(Post value, $Res Function(Post) then) =
      _$PostCopyWithImpl<$Res, Post>;
  @useResult
  $Res call({
    String id,
    @JsonKey(name: 'author_profile_id') String authorProfileId,
    @JsonKey(name: 'author_user_id') String authorUserId,
    @JsonKey(name: 'author_display_name') String? authorDisplayName,
    @JsonKey(name: 'author_avatar_url') String? authorAvatarUrl,
    @JsonKey(name: 'author_username') String? authorUsername,
    @JsonKey(name: 'author_sport_emoji') String? authorSportEmoji,
    @JsonKey(fromJson: _postKindFromJson, toJson: _postKindToJson)
    PostKind kind,
    @JsonKey(
      name: 'post_type',
      fromJson: _postTypeFromJson,
      toJson: _postTypeToJson,
    )
    PostType postType,
    @JsonKey(
      name: 'origin_type',
      fromJson: _originTypeFromJson,
      toJson: _originTypeToJson,
    )
    OriginType originType,
    @JsonKey(fromJson: _visibilityFromJson, toJson: _visibilityToJson)
    PostVisibility visibility,
    @JsonKey(name: 'link_token') String? linkToken,
    String? body,
    String? lang,
    String? sport,
    @JsonKey(fromJson: _mediaFromJson, toJson: _mediaToJson)
    List<dynamic> media,
    @JsonKey(name: 'venue_id') String? venueId,
    @JsonKey(name: 'geo_lat') double? geoLat,
    @JsonKey(name: 'geo_lng') double? geoLng,
    @JsonKey(name: 'game_id') String? gameId,
    @JsonKey(name: 'sport_id') String? sportId,
    @JsonKey(name: 'location_tag_id') String? locationTagId,
    @JsonKey(name: 'location_name') String? locationName,
    @JsonKey(name: 'vibe_id') String? primaryVibeId,
    @JsonKey(name: 'origin_id') String? originId,
    @JsonKey(name: 'content_class') String? contentClass,
    @JsonKey(fromJson: _tagsFromJson, toJson: _tagsToJson) List<String> tags,
    @JsonKey(name: 'like_count') int likeCount,
    @JsonKey(name: 'comment_count') int commentCount,
    @JsonKey(name: 'view_count') int viewCount,
    @JsonKey(name: 'priority_score') int priorityScore,
    @JsonKey(name: 'is_deleted') bool isDeleted,
    @JsonKey(name: 'is_hidden_admin') bool isHiddenAdmin,
    @JsonKey(name: 'is_active') bool isActive,
    @JsonKey(name: 'allow_reposts') bool allowReposts,
    @JsonKey(name: 'is_pinned') bool isPinned,
    @JsonKey(name: 'is_edited') bool isEdited,
    @JsonKey(name: 'requires_moderation') bool requiresModeration,
    @JsonKey(name: 'persona_type_snapshot') String? personaTypeSnapshot,
    @JsonKey(
      name: 'reaction_breakdown',
      fromJson: _reactionBreakdownFromJson,
      toJson: _reactionBreakdownToJson,
    )
    Map<String, dynamic> reactionBreakdown,
    @JsonKey(name: 'post_vibes', fromJson: _vibesFromJson, toJson: _vibesToJson)
    List<Vibe> vibes,
    @JsonKey(name: 'created_at') DateTime createdAt,
    @JsonKey(name: 'updated_at') DateTime updatedAt,
    @JsonKey(name: 'expires_at') DateTime? expiresAt,
    @JsonKey(name: 'edited_at') DateTime? editedAt,
  });
}

/// @nodoc
class _$PostCopyWithImpl<$Res, $Val extends Post>
    implements $PostCopyWith<$Res> {
  _$PostCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Post
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? authorProfileId = null,
    Object? authorUserId = null,
    Object? authorDisplayName = freezed,
    Object? authorAvatarUrl = freezed,
    Object? authorUsername = freezed,
    Object? authorSportEmoji = freezed,
    Object? kind = null,
    Object? postType = null,
    Object? originType = null,
    Object? visibility = null,
    Object? linkToken = freezed,
    Object? body = freezed,
    Object? lang = freezed,
    Object? sport = freezed,
    Object? media = null,
    Object? venueId = freezed,
    Object? geoLat = freezed,
    Object? geoLng = freezed,
    Object? gameId = freezed,
    Object? sportId = freezed,
    Object? locationTagId = freezed,
    Object? locationName = freezed,
    Object? primaryVibeId = freezed,
    Object? originId = freezed,
    Object? contentClass = freezed,
    Object? tags = null,
    Object? likeCount = null,
    Object? commentCount = null,
    Object? viewCount = null,
    Object? priorityScore = null,
    Object? isDeleted = null,
    Object? isHiddenAdmin = null,
    Object? isActive = null,
    Object? allowReposts = null,
    Object? isPinned = null,
    Object? isEdited = null,
    Object? requiresModeration = null,
    Object? personaTypeSnapshot = freezed,
    Object? reactionBreakdown = null,
    Object? vibes = null,
    Object? createdAt = null,
    Object? updatedAt = null,
    Object? expiresAt = freezed,
    Object? editedAt = freezed,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            authorProfileId: null == authorProfileId
                ? _value.authorProfileId
                : authorProfileId // ignore: cast_nullable_to_non_nullable
                      as String,
            authorUserId: null == authorUserId
                ? _value.authorUserId
                : authorUserId // ignore: cast_nullable_to_non_nullable
                      as String,
            authorDisplayName: freezed == authorDisplayName
                ? _value.authorDisplayName
                : authorDisplayName // ignore: cast_nullable_to_non_nullable
                      as String?,
            authorAvatarUrl: freezed == authorAvatarUrl
                ? _value.authorAvatarUrl
                : authorAvatarUrl // ignore: cast_nullable_to_non_nullable
                      as String?,
            authorUsername: freezed == authorUsername
                ? _value.authorUsername
                : authorUsername // ignore: cast_nullable_to_non_nullable
                      as String?,
            authorSportEmoji: freezed == authorSportEmoji
                ? _value.authorSportEmoji
                : authorSportEmoji // ignore: cast_nullable_to_non_nullable
                      as String?,
            kind: null == kind
                ? _value.kind
                : kind // ignore: cast_nullable_to_non_nullable
                      as PostKind,
            postType: null == postType
                ? _value.postType
                : postType // ignore: cast_nullable_to_non_nullable
                      as PostType,
            originType: null == originType
                ? _value.originType
                : originType // ignore: cast_nullable_to_non_nullable
                      as OriginType,
            visibility: null == visibility
                ? _value.visibility
                : visibility // ignore: cast_nullable_to_non_nullable
                      as PostVisibility,
            linkToken: freezed == linkToken
                ? _value.linkToken
                : linkToken // ignore: cast_nullable_to_non_nullable
                      as String?,
            body: freezed == body
                ? _value.body
                : body // ignore: cast_nullable_to_non_nullable
                      as String?,
            lang: freezed == lang
                ? _value.lang
                : lang // ignore: cast_nullable_to_non_nullable
                      as String?,
            sport: freezed == sport
                ? _value.sport
                : sport // ignore: cast_nullable_to_non_nullable
                      as String?,
            media: null == media
                ? _value.media
                : media // ignore: cast_nullable_to_non_nullable
                      as List<dynamic>,
            venueId: freezed == venueId
                ? _value.venueId
                : venueId // ignore: cast_nullable_to_non_nullable
                      as String?,
            geoLat: freezed == geoLat
                ? _value.geoLat
                : geoLat // ignore: cast_nullable_to_non_nullable
                      as double?,
            geoLng: freezed == geoLng
                ? _value.geoLng
                : geoLng // ignore: cast_nullable_to_non_nullable
                      as double?,
            gameId: freezed == gameId
                ? _value.gameId
                : gameId // ignore: cast_nullable_to_non_nullable
                      as String?,
            sportId: freezed == sportId
                ? _value.sportId
                : sportId // ignore: cast_nullable_to_non_nullable
                      as String?,
            locationTagId: freezed == locationTagId
                ? _value.locationTagId
                : locationTagId // ignore: cast_nullable_to_non_nullable
                      as String?,
            locationName: freezed == locationName
                ? _value.locationName
                : locationName // ignore: cast_nullable_to_non_nullable
                      as String?,
            primaryVibeId: freezed == primaryVibeId
                ? _value.primaryVibeId
                : primaryVibeId // ignore: cast_nullable_to_non_nullable
                      as String?,
            originId: freezed == originId
                ? _value.originId
                : originId // ignore: cast_nullable_to_non_nullable
                      as String?,
            contentClass: freezed == contentClass
                ? _value.contentClass
                : contentClass // ignore: cast_nullable_to_non_nullable
                      as String?,
            tags: null == tags
                ? _value.tags
                : tags // ignore: cast_nullable_to_non_nullable
                      as List<String>,
            likeCount: null == likeCount
                ? _value.likeCount
                : likeCount // ignore: cast_nullable_to_non_nullable
                      as int,
            commentCount: null == commentCount
                ? _value.commentCount
                : commentCount // ignore: cast_nullable_to_non_nullable
                      as int,
            viewCount: null == viewCount
                ? _value.viewCount
                : viewCount // ignore: cast_nullable_to_non_nullable
                      as int,
            priorityScore: null == priorityScore
                ? _value.priorityScore
                : priorityScore // ignore: cast_nullable_to_non_nullable
                      as int,
            isDeleted: null == isDeleted
                ? _value.isDeleted
                : isDeleted // ignore: cast_nullable_to_non_nullable
                      as bool,
            isHiddenAdmin: null == isHiddenAdmin
                ? _value.isHiddenAdmin
                : isHiddenAdmin // ignore: cast_nullable_to_non_nullable
                      as bool,
            isActive: null == isActive
                ? _value.isActive
                : isActive // ignore: cast_nullable_to_non_nullable
                      as bool,
            allowReposts: null == allowReposts
                ? _value.allowReposts
                : allowReposts // ignore: cast_nullable_to_non_nullable
                      as bool,
            isPinned: null == isPinned
                ? _value.isPinned
                : isPinned // ignore: cast_nullable_to_non_nullable
                      as bool,
            isEdited: null == isEdited
                ? _value.isEdited
                : isEdited // ignore: cast_nullable_to_non_nullable
                      as bool,
            requiresModeration: null == requiresModeration
                ? _value.requiresModeration
                : requiresModeration // ignore: cast_nullable_to_non_nullable
                      as bool,
            personaTypeSnapshot: freezed == personaTypeSnapshot
                ? _value.personaTypeSnapshot
                : personaTypeSnapshot // ignore: cast_nullable_to_non_nullable
                      as String?,
            reactionBreakdown: null == reactionBreakdown
                ? _value.reactionBreakdown
                : reactionBreakdown // ignore: cast_nullable_to_non_nullable
                      as Map<String, dynamic>,
            vibes: null == vibes
                ? _value.vibes
                : vibes // ignore: cast_nullable_to_non_nullable
                      as List<Vibe>,
            createdAt: null == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            updatedAt: null == updatedAt
                ? _value.updatedAt
                : updatedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            expiresAt: freezed == expiresAt
                ? _value.expiresAt
                : expiresAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            editedAt: freezed == editedAt
                ? _value.editedAt
                : editedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$PostImplCopyWith<$Res> implements $PostCopyWith<$Res> {
  factory _$$PostImplCopyWith(
    _$PostImpl value,
    $Res Function(_$PostImpl) then,
  ) = __$$PostImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    @JsonKey(name: 'author_profile_id') String authorProfileId,
    @JsonKey(name: 'author_user_id') String authorUserId,
    @JsonKey(name: 'author_display_name') String? authorDisplayName,
    @JsonKey(name: 'author_avatar_url') String? authorAvatarUrl,
    @JsonKey(name: 'author_username') String? authorUsername,
    @JsonKey(name: 'author_sport_emoji') String? authorSportEmoji,
    @JsonKey(fromJson: _postKindFromJson, toJson: _postKindToJson)
    PostKind kind,
    @JsonKey(
      name: 'post_type',
      fromJson: _postTypeFromJson,
      toJson: _postTypeToJson,
    )
    PostType postType,
    @JsonKey(
      name: 'origin_type',
      fromJson: _originTypeFromJson,
      toJson: _originTypeToJson,
    )
    OriginType originType,
    @JsonKey(fromJson: _visibilityFromJson, toJson: _visibilityToJson)
    PostVisibility visibility,
    @JsonKey(name: 'link_token') String? linkToken,
    String? body,
    String? lang,
    String? sport,
    @JsonKey(fromJson: _mediaFromJson, toJson: _mediaToJson)
    List<dynamic> media,
    @JsonKey(name: 'venue_id') String? venueId,
    @JsonKey(name: 'geo_lat') double? geoLat,
    @JsonKey(name: 'geo_lng') double? geoLng,
    @JsonKey(name: 'game_id') String? gameId,
    @JsonKey(name: 'sport_id') String? sportId,
    @JsonKey(name: 'location_tag_id') String? locationTagId,
    @JsonKey(name: 'location_name') String? locationName,
    @JsonKey(name: 'vibe_id') String? primaryVibeId,
    @JsonKey(name: 'origin_id') String? originId,
    @JsonKey(name: 'content_class') String? contentClass,
    @JsonKey(fromJson: _tagsFromJson, toJson: _tagsToJson) List<String> tags,
    @JsonKey(name: 'like_count') int likeCount,
    @JsonKey(name: 'comment_count') int commentCount,
    @JsonKey(name: 'view_count') int viewCount,
    @JsonKey(name: 'priority_score') int priorityScore,
    @JsonKey(name: 'is_deleted') bool isDeleted,
    @JsonKey(name: 'is_hidden_admin') bool isHiddenAdmin,
    @JsonKey(name: 'is_active') bool isActive,
    @JsonKey(name: 'allow_reposts') bool allowReposts,
    @JsonKey(name: 'is_pinned') bool isPinned,
    @JsonKey(name: 'is_edited') bool isEdited,
    @JsonKey(name: 'requires_moderation') bool requiresModeration,
    @JsonKey(name: 'persona_type_snapshot') String? personaTypeSnapshot,
    @JsonKey(
      name: 'reaction_breakdown',
      fromJson: _reactionBreakdownFromJson,
      toJson: _reactionBreakdownToJson,
    )
    Map<String, dynamic> reactionBreakdown,
    @JsonKey(name: 'post_vibes', fromJson: _vibesFromJson, toJson: _vibesToJson)
    List<Vibe> vibes,
    @JsonKey(name: 'created_at') DateTime createdAt,
    @JsonKey(name: 'updated_at') DateTime updatedAt,
    @JsonKey(name: 'expires_at') DateTime? expiresAt,
    @JsonKey(name: 'edited_at') DateTime? editedAt,
  });
}

/// @nodoc
class __$$PostImplCopyWithImpl<$Res>
    extends _$PostCopyWithImpl<$Res, _$PostImpl>
    implements _$$PostImplCopyWith<$Res> {
  __$$PostImplCopyWithImpl(_$PostImpl _value, $Res Function(_$PostImpl) _then)
    : super(_value, _then);

  /// Create a copy of Post
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? authorProfileId = null,
    Object? authorUserId = null,
    Object? authorDisplayName = freezed,
    Object? authorAvatarUrl = freezed,
    Object? authorUsername = freezed,
    Object? authorSportEmoji = freezed,
    Object? kind = null,
    Object? postType = null,
    Object? originType = null,
    Object? visibility = null,
    Object? linkToken = freezed,
    Object? body = freezed,
    Object? lang = freezed,
    Object? sport = freezed,
    Object? media = null,
    Object? venueId = freezed,
    Object? geoLat = freezed,
    Object? geoLng = freezed,
    Object? gameId = freezed,
    Object? sportId = freezed,
    Object? locationTagId = freezed,
    Object? locationName = freezed,
    Object? primaryVibeId = freezed,
    Object? originId = freezed,
    Object? contentClass = freezed,
    Object? tags = null,
    Object? likeCount = null,
    Object? commentCount = null,
    Object? viewCount = null,
    Object? priorityScore = null,
    Object? isDeleted = null,
    Object? isHiddenAdmin = null,
    Object? isActive = null,
    Object? allowReposts = null,
    Object? isPinned = null,
    Object? isEdited = null,
    Object? requiresModeration = null,
    Object? personaTypeSnapshot = freezed,
    Object? reactionBreakdown = null,
    Object? vibes = null,
    Object? createdAt = null,
    Object? updatedAt = null,
    Object? expiresAt = freezed,
    Object? editedAt = freezed,
  }) {
    return _then(
      _$PostImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        authorProfileId: null == authorProfileId
            ? _value.authorProfileId
            : authorProfileId // ignore: cast_nullable_to_non_nullable
                  as String,
        authorUserId: null == authorUserId
            ? _value.authorUserId
            : authorUserId // ignore: cast_nullable_to_non_nullable
                  as String,
        authorDisplayName: freezed == authorDisplayName
            ? _value.authorDisplayName
            : authorDisplayName // ignore: cast_nullable_to_non_nullable
                  as String?,
        authorAvatarUrl: freezed == authorAvatarUrl
            ? _value.authorAvatarUrl
            : authorAvatarUrl // ignore: cast_nullable_to_non_nullable
                  as String?,
        authorUsername: freezed == authorUsername
            ? _value.authorUsername
            : authorUsername // ignore: cast_nullable_to_non_nullable
                  as String?,
        authorSportEmoji: freezed == authorSportEmoji
            ? _value.authorSportEmoji
            : authorSportEmoji // ignore: cast_nullable_to_non_nullable
                  as String?,
        kind: null == kind
            ? _value.kind
            : kind // ignore: cast_nullable_to_non_nullable
                  as PostKind,
        postType: null == postType
            ? _value.postType
            : postType // ignore: cast_nullable_to_non_nullable
                  as PostType,
        originType: null == originType
            ? _value.originType
            : originType // ignore: cast_nullable_to_non_nullable
                  as OriginType,
        visibility: null == visibility
            ? _value.visibility
            : visibility // ignore: cast_nullable_to_non_nullable
                  as PostVisibility,
        linkToken: freezed == linkToken
            ? _value.linkToken
            : linkToken // ignore: cast_nullable_to_non_nullable
                  as String?,
        body: freezed == body
            ? _value.body
            : body // ignore: cast_nullable_to_non_nullable
                  as String?,
        lang: freezed == lang
            ? _value.lang
            : lang // ignore: cast_nullable_to_non_nullable
                  as String?,
        sport: freezed == sport
            ? _value.sport
            : sport // ignore: cast_nullable_to_non_nullable
                  as String?,
        media: null == media
            ? _value._media
            : media // ignore: cast_nullable_to_non_nullable
                  as List<dynamic>,
        venueId: freezed == venueId
            ? _value.venueId
            : venueId // ignore: cast_nullable_to_non_nullable
                  as String?,
        geoLat: freezed == geoLat
            ? _value.geoLat
            : geoLat // ignore: cast_nullable_to_non_nullable
                  as double?,
        geoLng: freezed == geoLng
            ? _value.geoLng
            : geoLng // ignore: cast_nullable_to_non_nullable
                  as double?,
        gameId: freezed == gameId
            ? _value.gameId
            : gameId // ignore: cast_nullable_to_non_nullable
                  as String?,
        sportId: freezed == sportId
            ? _value.sportId
            : sportId // ignore: cast_nullable_to_non_nullable
                  as String?,
        locationTagId: freezed == locationTagId
            ? _value.locationTagId
            : locationTagId // ignore: cast_nullable_to_non_nullable
                  as String?,
        locationName: freezed == locationName
            ? _value.locationName
            : locationName // ignore: cast_nullable_to_non_nullable
                  as String?,
        primaryVibeId: freezed == primaryVibeId
            ? _value.primaryVibeId
            : primaryVibeId // ignore: cast_nullable_to_non_nullable
                  as String?,
        originId: freezed == originId
            ? _value.originId
            : originId // ignore: cast_nullable_to_non_nullable
                  as String?,
        contentClass: freezed == contentClass
            ? _value.contentClass
            : contentClass // ignore: cast_nullable_to_non_nullable
                  as String?,
        tags: null == tags
            ? _value._tags
            : tags // ignore: cast_nullable_to_non_nullable
                  as List<String>,
        likeCount: null == likeCount
            ? _value.likeCount
            : likeCount // ignore: cast_nullable_to_non_nullable
                  as int,
        commentCount: null == commentCount
            ? _value.commentCount
            : commentCount // ignore: cast_nullable_to_non_nullable
                  as int,
        viewCount: null == viewCount
            ? _value.viewCount
            : viewCount // ignore: cast_nullable_to_non_nullable
                  as int,
        priorityScore: null == priorityScore
            ? _value.priorityScore
            : priorityScore // ignore: cast_nullable_to_non_nullable
                  as int,
        isDeleted: null == isDeleted
            ? _value.isDeleted
            : isDeleted // ignore: cast_nullable_to_non_nullable
                  as bool,
        isHiddenAdmin: null == isHiddenAdmin
            ? _value.isHiddenAdmin
            : isHiddenAdmin // ignore: cast_nullable_to_non_nullable
                  as bool,
        isActive: null == isActive
            ? _value.isActive
            : isActive // ignore: cast_nullable_to_non_nullable
                  as bool,
        allowReposts: null == allowReposts
            ? _value.allowReposts
            : allowReposts // ignore: cast_nullable_to_non_nullable
                  as bool,
        isPinned: null == isPinned
            ? _value.isPinned
            : isPinned // ignore: cast_nullable_to_non_nullable
                  as bool,
        isEdited: null == isEdited
            ? _value.isEdited
            : isEdited // ignore: cast_nullable_to_non_nullable
                  as bool,
        requiresModeration: null == requiresModeration
            ? _value.requiresModeration
            : requiresModeration // ignore: cast_nullable_to_non_nullable
                  as bool,
        personaTypeSnapshot: freezed == personaTypeSnapshot
            ? _value.personaTypeSnapshot
            : personaTypeSnapshot // ignore: cast_nullable_to_non_nullable
                  as String?,
        reactionBreakdown: null == reactionBreakdown
            ? _value._reactionBreakdown
            : reactionBreakdown // ignore: cast_nullable_to_non_nullable
                  as Map<String, dynamic>,
        vibes: null == vibes
            ? _value._vibes
            : vibes // ignore: cast_nullable_to_non_nullable
                  as List<Vibe>,
        createdAt: null == createdAt
            ? _value.createdAt
            : createdAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        updatedAt: null == updatedAt
            ? _value.updatedAt
            : updatedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        expiresAt: freezed == expiresAt
            ? _value.expiresAt
            : expiresAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        editedAt: freezed == editedAt
            ? _value.editedAt
            : editedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$PostImpl implements _Post {
  const _$PostImpl({
    required this.id,
    @JsonKey(name: 'author_profile_id') required this.authorProfileId,
    @JsonKey(name: 'author_user_id') required this.authorUserId,
    @JsonKey(name: 'author_display_name') this.authorDisplayName,
    @JsonKey(name: 'author_avatar_url') this.authorAvatarUrl,
    @JsonKey(name: 'author_username') this.authorUsername,
    @JsonKey(name: 'author_sport_emoji') this.authorSportEmoji,
    @JsonKey(fromJson: _postKindFromJson, toJson: _postKindToJson)
    required this.kind,
    @JsonKey(
      name: 'post_type',
      fromJson: _postTypeFromJson,
      toJson: _postTypeToJson,
    )
    this.postType = PostType.dab,
    @JsonKey(
      name: 'origin_type',
      fromJson: _originTypeFromJson,
      toJson: _originTypeToJson,
    )
    this.originType = OriginType.manual,
    @JsonKey(fromJson: _visibilityFromJson, toJson: _visibilityToJson)
    required this.visibility,
    @JsonKey(name: 'link_token') this.linkToken,
    this.body,
    this.lang,
    this.sport,
    @JsonKey(fromJson: _mediaFromJson, toJson: _mediaToJson)
    final List<dynamic> media = const <dynamic>[],
    @JsonKey(name: 'venue_id') this.venueId,
    @JsonKey(name: 'geo_lat') this.geoLat,
    @JsonKey(name: 'geo_lng') this.geoLng,
    @JsonKey(name: 'game_id') this.gameId,
    @JsonKey(name: 'sport_id') this.sportId,
    @JsonKey(name: 'location_tag_id') this.locationTagId,
    @JsonKey(name: 'location_name') this.locationName,
    @JsonKey(name: 'vibe_id') this.primaryVibeId,
    @JsonKey(name: 'origin_id') this.originId,
    @JsonKey(name: 'content_class') this.contentClass,
    @JsonKey(fromJson: _tagsFromJson, toJson: _tagsToJson)
    final List<String> tags = const <String>[],
    @JsonKey(name: 'like_count') this.likeCount = 0,
    @JsonKey(name: 'comment_count') this.commentCount = 0,
    @JsonKey(name: 'view_count') this.viewCount = 0,
    @JsonKey(name: 'priority_score') this.priorityScore = 0,
    @JsonKey(name: 'is_deleted') this.isDeleted = false,
    @JsonKey(name: 'is_hidden_admin') this.isHiddenAdmin = false,
    @JsonKey(name: 'is_active') this.isActive = true,
    @JsonKey(name: 'allow_reposts') this.allowReposts = true,
    @JsonKey(name: 'is_pinned') this.isPinned = false,
    @JsonKey(name: 'is_edited') this.isEdited = false,
    @JsonKey(name: 'requires_moderation') this.requiresModeration = false,
    @JsonKey(name: 'persona_type_snapshot') this.personaTypeSnapshot,
    @JsonKey(
      name: 'reaction_breakdown',
      fromJson: _reactionBreakdownFromJson,
      toJson: _reactionBreakdownToJson,
    )
    final Map<String, dynamic> reactionBreakdown = const <String, dynamic>{},
    @JsonKey(name: 'post_vibes', fromJson: _vibesFromJson, toJson: _vibesToJson)
    final List<Vibe> vibes = const <Vibe>[],
    @JsonKey(name: 'created_at') required this.createdAt,
    @JsonKey(name: 'updated_at') required this.updatedAt,
    @JsonKey(name: 'expires_at') this.expiresAt,
    @JsonKey(name: 'edited_at') this.editedAt,
  }) : _media = media,
       _tags = tags,
       _reactionBreakdown = reactionBreakdown,
       _vibes = vibes;

  factory _$PostImpl.fromJson(Map<String, dynamic> json) =>
      _$$PostImplFromJson(json);

  @override
  final String id;
  @override
  @JsonKey(name: 'author_profile_id')
  final String authorProfileId;
  @override
  @JsonKey(name: 'author_user_id')
  final String authorUserId;
  @override
  @JsonKey(name: 'author_display_name')
  final String? authorDisplayName;
  @override
  @JsonKey(name: 'author_avatar_url')
  final String? authorAvatarUrl;
  @override
  @JsonKey(name: 'author_username')
  final String? authorUsername;
  @override
  @JsonKey(name: 'author_sport_emoji')
  final String? authorSportEmoji;

  /// `post_kind` enum column (NOT NULL in DB).
  @override
  @JsonKey(fromJson: _postKindFromJson, toJson: _postKindToJson)
  final PostKind kind;

  /// `post_type_enum` column (nullable in DB, default 'dab').
  @override
  @JsonKey(
    name: 'post_type',
    fromJson: _postTypeFromJson,
    toJson: _postTypeToJson,
  )
  final PostType postType;

  /// `origin_type_enum` column (nullable in DB, default 'manual').
  @override
  @JsonKey(
    name: 'origin_type',
    fromJson: _originTypeFromJson,
    toJson: _originTypeToJson,
  )
  final OriginType originType;

  /// Text column: public | followers | circle | squad | private | link.
  @override
  @JsonKey(fromJson: _visibilityFromJson, toJson: _visibilityToJson)
  final PostVisibility visibility;
  @override
  @JsonKey(name: 'link_token')
  final String? linkToken;
  @override
  final String? body;
  @override
  final String? lang;
  @override
  final String? sport;

  /// jsonb column, default '[]'. Supabase returns as List.
  final List<dynamic> _media;

  /// jsonb column, default '[]'. Supabase returns as List.
  @override
  @JsonKey(fromJson: _mediaFromJson, toJson: _mediaToJson)
  List<dynamic> get media {
    if (_media is EqualUnmodifiableListView) return _media;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_media);
  }

  @override
  @JsonKey(name: 'venue_id')
  final String? venueId;
  @override
  @JsonKey(name: 'geo_lat')
  final double? geoLat;
  @override
  @JsonKey(name: 'geo_lng')
  final double? geoLng;
  @override
  @JsonKey(name: 'game_id')
  final String? gameId;
  @override
  @JsonKey(name: 'sport_id')
  final String? sportId;
  @override
  @JsonKey(name: 'location_tag_id')
  final String? locationTagId;
  @override
  @JsonKey(name: 'location_name')
  final String? locationName;
  @override
  @JsonKey(name: 'vibe_id')
  final String? primaryVibeId;
  @override
  @JsonKey(name: 'origin_id')
  final String? originId;
  @override
  @JsonKey(name: 'content_class')
  final String? contentClass;

  /// text[] column, nullable in DB, default '{}'.
  final List<String> _tags;

  /// text[] column, nullable in DB, default '{}'.
  @override
  @JsonKey(fromJson: _tagsFromJson, toJson: _tagsToJson)
  List<String> get tags {
    if (_tags is EqualUnmodifiableListView) return _tags;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_tags);
  }

  @override
  @JsonKey(name: 'like_count')
  final int likeCount;
  @override
  @JsonKey(name: 'comment_count')
  final int commentCount;
  @override
  @JsonKey(name: 'view_count')
  final int viewCount;
  @override
  @JsonKey(name: 'priority_score')
  final int priorityScore;
  @override
  @JsonKey(name: 'is_deleted')
  final bool isDeleted;
  @override
  @JsonKey(name: 'is_hidden_admin')
  final bool isHiddenAdmin;
  @override
  @JsonKey(name: 'is_active')
  final bool isActive;
  @override
  @JsonKey(name: 'allow_reposts')
  final bool allowReposts;
  @override
  @JsonKey(name: 'is_pinned')
  final bool isPinned;
  @override
  @JsonKey(name: 'is_edited')
  final bool isEdited;
  @override
  @JsonKey(name: 'requires_moderation')
  final bool requiresModeration;
  @override
  @JsonKey(name: 'persona_type_snapshot')
  final String? personaTypeSnapshot;

  /// jsonb column, nullable in DB, default '{}'. Supabase returns as Map.
  final Map<String, dynamic> _reactionBreakdown;

  /// jsonb column, nullable in DB, default '{}'. Supabase returns as Map.
  @override
  @JsonKey(
    name: 'reaction_breakdown',
    fromJson: _reactionBreakdownFromJson,
    toJson: _reactionBreakdownToJson,
  )
  Map<String, dynamic> get reactionBreakdown {
    if (_reactionBreakdown is EqualUnmodifiableMapView)
      return _reactionBreakdown;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_reactionBreakdown);
  }

  /// Vibes from the direct `vibe_id` FK, synthesised by the repository
  /// into the `post_vibes` key so [_vibesFromJson] can parse them.
  final List<Vibe> _vibes;

  /// Vibes from the direct `vibe_id` FK, synthesised by the repository
  /// into the `post_vibes` key so [_vibesFromJson] can parse them.
  @override
  @JsonKey(name: 'post_vibes', fromJson: _vibesFromJson, toJson: _vibesToJson)
  List<Vibe> get vibes {
    if (_vibes is EqualUnmodifiableListView) return _vibes;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_vibes);
  }

  @override
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  @override
  @JsonKey(name: 'updated_at')
  final DateTime updatedAt;
  @override
  @JsonKey(name: 'expires_at')
  final DateTime? expiresAt;
  @override
  @JsonKey(name: 'edited_at')
  final DateTime? editedAt;

  @override
  String toString() {
    return 'Post(id: $id, authorProfileId: $authorProfileId, authorUserId: $authorUserId, authorDisplayName: $authorDisplayName, authorAvatarUrl: $authorAvatarUrl, authorUsername: $authorUsername, authorSportEmoji: $authorSportEmoji, kind: $kind, postType: $postType, originType: $originType, visibility: $visibility, linkToken: $linkToken, body: $body, lang: $lang, sport: $sport, media: $media, venueId: $venueId, geoLat: $geoLat, geoLng: $geoLng, gameId: $gameId, sportId: $sportId, locationTagId: $locationTagId, locationName: $locationName, primaryVibeId: $primaryVibeId, originId: $originId, contentClass: $contentClass, tags: $tags, likeCount: $likeCount, commentCount: $commentCount, viewCount: $viewCount, priorityScore: $priorityScore, isDeleted: $isDeleted, isHiddenAdmin: $isHiddenAdmin, isActive: $isActive, allowReposts: $allowReposts, isPinned: $isPinned, isEdited: $isEdited, requiresModeration: $requiresModeration, personaTypeSnapshot: $personaTypeSnapshot, reactionBreakdown: $reactionBreakdown, vibes: $vibes, createdAt: $createdAt, updatedAt: $updatedAt, expiresAt: $expiresAt, editedAt: $editedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PostImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.authorProfileId, authorProfileId) ||
                other.authorProfileId == authorProfileId) &&
            (identical(other.authorUserId, authorUserId) ||
                other.authorUserId == authorUserId) &&
            (identical(other.authorDisplayName, authorDisplayName) ||
                other.authorDisplayName == authorDisplayName) &&
            (identical(other.authorAvatarUrl, authorAvatarUrl) ||
                other.authorAvatarUrl == authorAvatarUrl) &&
            (identical(other.authorUsername, authorUsername) ||
                other.authorUsername == authorUsername) &&
            (identical(other.authorSportEmoji, authorSportEmoji) ||
                other.authorSportEmoji == authorSportEmoji) &&
            (identical(other.kind, kind) || other.kind == kind) &&
            (identical(other.postType, postType) ||
                other.postType == postType) &&
            (identical(other.originType, originType) ||
                other.originType == originType) &&
            (identical(other.visibility, visibility) ||
                other.visibility == visibility) &&
            (identical(other.linkToken, linkToken) ||
                other.linkToken == linkToken) &&
            (identical(other.body, body) || other.body == body) &&
            (identical(other.lang, lang) || other.lang == lang) &&
            (identical(other.sport, sport) || other.sport == sport) &&
            const DeepCollectionEquality().equals(other._media, _media) &&
            (identical(other.venueId, venueId) || other.venueId == venueId) &&
            (identical(other.geoLat, geoLat) || other.geoLat == geoLat) &&
            (identical(other.geoLng, geoLng) || other.geoLng == geoLng) &&
            (identical(other.gameId, gameId) || other.gameId == gameId) &&
            (identical(other.sportId, sportId) || other.sportId == sportId) &&
            (identical(other.locationTagId, locationTagId) ||
                other.locationTagId == locationTagId) &&
            (identical(other.locationName, locationName) ||
                other.locationName == locationName) &&
            (identical(other.primaryVibeId, primaryVibeId) ||
                other.primaryVibeId == primaryVibeId) &&
            (identical(other.originId, originId) ||
                other.originId == originId) &&
            (identical(other.contentClass, contentClass) ||
                other.contentClass == contentClass) &&
            const DeepCollectionEquality().equals(other._tags, _tags) &&
            (identical(other.likeCount, likeCount) ||
                other.likeCount == likeCount) &&
            (identical(other.commentCount, commentCount) ||
                other.commentCount == commentCount) &&
            (identical(other.viewCount, viewCount) ||
                other.viewCount == viewCount) &&
            (identical(other.priorityScore, priorityScore) ||
                other.priorityScore == priorityScore) &&
            (identical(other.isDeleted, isDeleted) ||
                other.isDeleted == isDeleted) &&
            (identical(other.isHiddenAdmin, isHiddenAdmin) ||
                other.isHiddenAdmin == isHiddenAdmin) &&
            (identical(other.isActive, isActive) ||
                other.isActive == isActive) &&
            (identical(other.allowReposts, allowReposts) ||
                other.allowReposts == allowReposts) &&
            (identical(other.isPinned, isPinned) ||
                other.isPinned == isPinned) &&
            (identical(other.isEdited, isEdited) ||
                other.isEdited == isEdited) &&
            (identical(other.requiresModeration, requiresModeration) ||
                other.requiresModeration == requiresModeration) &&
            (identical(other.personaTypeSnapshot, personaTypeSnapshot) ||
                other.personaTypeSnapshot == personaTypeSnapshot) &&
            const DeepCollectionEquality().equals(
              other._reactionBreakdown,
              _reactionBreakdown,
            ) &&
            const DeepCollectionEquality().equals(other._vibes, _vibes) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt) &&
            (identical(other.expiresAt, expiresAt) ||
                other.expiresAt == expiresAt) &&
            (identical(other.editedAt, editedAt) ||
                other.editedAt == editedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hashAll([
    runtimeType,
    id,
    authorProfileId,
    authorUserId,
    authorDisplayName,
    authorAvatarUrl,
    authorUsername,
    authorSportEmoji,
    kind,
    postType,
    originType,
    visibility,
    linkToken,
    body,
    lang,
    sport,
    const DeepCollectionEquality().hash(_media),
    venueId,
    geoLat,
    geoLng,
    gameId,
    sportId,
    locationTagId,
    locationName,
    primaryVibeId,
    originId,
    contentClass,
    const DeepCollectionEquality().hash(_tags),
    likeCount,
    commentCount,
    viewCount,
    priorityScore,
    isDeleted,
    isHiddenAdmin,
    isActive,
    allowReposts,
    isPinned,
    isEdited,
    requiresModeration,
    personaTypeSnapshot,
    const DeepCollectionEquality().hash(_reactionBreakdown),
    const DeepCollectionEquality().hash(_vibes),
    createdAt,
    updatedAt,
    expiresAt,
    editedAt,
  ]);

  /// Create a copy of Post
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$PostImplCopyWith<_$PostImpl> get copyWith =>
      __$$PostImplCopyWithImpl<_$PostImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$PostImplToJson(this);
  }
}

abstract class _Post implements Post {
  const factory _Post({
    required final String id,
    @JsonKey(name: 'author_profile_id') required final String authorProfileId,
    @JsonKey(name: 'author_user_id') required final String authorUserId,
    @JsonKey(name: 'author_display_name') final String? authorDisplayName,
    @JsonKey(name: 'author_avatar_url') final String? authorAvatarUrl,
    @JsonKey(name: 'author_username') final String? authorUsername,
    @JsonKey(name: 'author_sport_emoji') final String? authorSportEmoji,
    @JsonKey(fromJson: _postKindFromJson, toJson: _postKindToJson)
    required final PostKind kind,
    @JsonKey(
      name: 'post_type',
      fromJson: _postTypeFromJson,
      toJson: _postTypeToJson,
    )
    final PostType postType,
    @JsonKey(
      name: 'origin_type',
      fromJson: _originTypeFromJson,
      toJson: _originTypeToJson,
    )
    final OriginType originType,
    @JsonKey(fromJson: _visibilityFromJson, toJson: _visibilityToJson)
    required final PostVisibility visibility,
    @JsonKey(name: 'link_token') final String? linkToken,
    final String? body,
    final String? lang,
    final String? sport,
    @JsonKey(fromJson: _mediaFromJson, toJson: _mediaToJson)
    final List<dynamic> media,
    @JsonKey(name: 'venue_id') final String? venueId,
    @JsonKey(name: 'geo_lat') final double? geoLat,
    @JsonKey(name: 'geo_lng') final double? geoLng,
    @JsonKey(name: 'game_id') final String? gameId,
    @JsonKey(name: 'sport_id') final String? sportId,
    @JsonKey(name: 'location_tag_id') final String? locationTagId,
    @JsonKey(name: 'location_name') final String? locationName,
    @JsonKey(name: 'vibe_id') final String? primaryVibeId,
    @JsonKey(name: 'origin_id') final String? originId,
    @JsonKey(name: 'content_class') final String? contentClass,
    @JsonKey(fromJson: _tagsFromJson, toJson: _tagsToJson)
    final List<String> tags,
    @JsonKey(name: 'like_count') final int likeCount,
    @JsonKey(name: 'comment_count') final int commentCount,
    @JsonKey(name: 'view_count') final int viewCount,
    @JsonKey(name: 'priority_score') final int priorityScore,
    @JsonKey(name: 'is_deleted') final bool isDeleted,
    @JsonKey(name: 'is_hidden_admin') final bool isHiddenAdmin,
    @JsonKey(name: 'is_active') final bool isActive,
    @JsonKey(name: 'allow_reposts') final bool allowReposts,
    @JsonKey(name: 'is_pinned') final bool isPinned,
    @JsonKey(name: 'is_edited') final bool isEdited,
    @JsonKey(name: 'requires_moderation') final bool requiresModeration,
    @JsonKey(name: 'persona_type_snapshot') final String? personaTypeSnapshot,
    @JsonKey(
      name: 'reaction_breakdown',
      fromJson: _reactionBreakdownFromJson,
      toJson: _reactionBreakdownToJson,
    )
    final Map<String, dynamic> reactionBreakdown,
    @JsonKey(name: 'post_vibes', fromJson: _vibesFromJson, toJson: _vibesToJson)
    final List<Vibe> vibes,
    @JsonKey(name: 'created_at') required final DateTime createdAt,
    @JsonKey(name: 'updated_at') required final DateTime updatedAt,
    @JsonKey(name: 'expires_at') final DateTime? expiresAt,
    @JsonKey(name: 'edited_at') final DateTime? editedAt,
  }) = _$PostImpl;

  factory _Post.fromJson(Map<String, dynamic> json) = _$PostImpl.fromJson;

  @override
  String get id;
  @override
  @JsonKey(name: 'author_profile_id')
  String get authorProfileId;
  @override
  @JsonKey(name: 'author_user_id')
  String get authorUserId;
  @override
  @JsonKey(name: 'author_display_name')
  String? get authorDisplayName;
  @override
  @JsonKey(name: 'author_avatar_url')
  String? get authorAvatarUrl;
  @override
  @JsonKey(name: 'author_username')
  String? get authorUsername;
  @override
  @JsonKey(name: 'author_sport_emoji')
  String? get authorSportEmoji;

  /// `post_kind` enum column (NOT NULL in DB).
  @override
  @JsonKey(fromJson: _postKindFromJson, toJson: _postKindToJson)
  PostKind get kind;

  /// `post_type_enum` column (nullable in DB, default 'dab').
  @override
  @JsonKey(
    name: 'post_type',
    fromJson: _postTypeFromJson,
    toJson: _postTypeToJson,
  )
  PostType get postType;

  /// `origin_type_enum` column (nullable in DB, default 'manual').
  @override
  @JsonKey(
    name: 'origin_type',
    fromJson: _originTypeFromJson,
    toJson: _originTypeToJson,
  )
  OriginType get originType;

  /// Text column: public | followers | circle | squad | private | link.
  @override
  @JsonKey(fromJson: _visibilityFromJson, toJson: _visibilityToJson)
  PostVisibility get visibility;
  @override
  @JsonKey(name: 'link_token')
  String? get linkToken;
  @override
  String? get body;
  @override
  String? get lang;
  @override
  String? get sport;

  /// jsonb column, default '[]'. Supabase returns as List.
  @override
  @JsonKey(fromJson: _mediaFromJson, toJson: _mediaToJson)
  List<dynamic> get media;
  @override
  @JsonKey(name: 'venue_id')
  String? get venueId;
  @override
  @JsonKey(name: 'geo_lat')
  double? get geoLat;
  @override
  @JsonKey(name: 'geo_lng')
  double? get geoLng;
  @override
  @JsonKey(name: 'game_id')
  String? get gameId;
  @override
  @JsonKey(name: 'sport_id')
  String? get sportId;
  @override
  @JsonKey(name: 'location_tag_id')
  String? get locationTagId;
  @override
  @JsonKey(name: 'location_name')
  String? get locationName;
  @override
  @JsonKey(name: 'vibe_id')
  String? get primaryVibeId;
  @override
  @JsonKey(name: 'origin_id')
  String? get originId;
  @override
  @JsonKey(name: 'content_class')
  String? get contentClass;

  /// text[] column, nullable in DB, default '{}'.
  @override
  @JsonKey(fromJson: _tagsFromJson, toJson: _tagsToJson)
  List<String> get tags;
  @override
  @JsonKey(name: 'like_count')
  int get likeCount;
  @override
  @JsonKey(name: 'comment_count')
  int get commentCount;
  @override
  @JsonKey(name: 'view_count')
  int get viewCount;
  @override
  @JsonKey(name: 'priority_score')
  int get priorityScore;
  @override
  @JsonKey(name: 'is_deleted')
  bool get isDeleted;
  @override
  @JsonKey(name: 'is_hidden_admin')
  bool get isHiddenAdmin;
  @override
  @JsonKey(name: 'is_active')
  bool get isActive;
  @override
  @JsonKey(name: 'allow_reposts')
  bool get allowReposts;
  @override
  @JsonKey(name: 'is_pinned')
  bool get isPinned;
  @override
  @JsonKey(name: 'is_edited')
  bool get isEdited;
  @override
  @JsonKey(name: 'requires_moderation')
  bool get requiresModeration;
  @override
  @JsonKey(name: 'persona_type_snapshot')
  String? get personaTypeSnapshot;

  /// jsonb column, nullable in DB, default '{}'. Supabase returns as Map.
  @override
  @JsonKey(
    name: 'reaction_breakdown',
    fromJson: _reactionBreakdownFromJson,
    toJson: _reactionBreakdownToJson,
  )
  Map<String, dynamic> get reactionBreakdown;

  /// Vibes from the direct `vibe_id` FK, synthesised by the repository
  /// into the `post_vibes` key so [_vibesFromJson] can parse them.
  @override
  @JsonKey(name: 'post_vibes', fromJson: _vibesFromJson, toJson: _vibesToJson)
  List<Vibe> get vibes;
  @override
  @JsonKey(name: 'created_at')
  DateTime get createdAt;
  @override
  @JsonKey(name: 'updated_at')
  DateTime get updatedAt;
  @override
  @JsonKey(name: 'expires_at')
  DateTime? get expiresAt;
  @override
  @JsonKey(name: 'edited_at')
  DateTime? get editedAt;

  /// Create a copy of Post
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PostImplCopyWith<_$PostImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
