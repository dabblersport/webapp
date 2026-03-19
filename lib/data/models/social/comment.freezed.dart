// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'comment.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

PostComment _$PostCommentFromJson(Map<String, dynamic> json) {
  return _PostComment.fromJson(json);
}

/// @nodoc
mixin _$PostComment {
  String get id => throw _privateConstructorUsedError;
  @JsonKey(name: 'post_id')
  String get postId => throw _privateConstructorUsedError;
  @JsonKey(name: 'author_user_id')
  String get authorUserId => throw _privateConstructorUsedError;
  @JsonKey(name: 'author_profile_id')
  String get authorProfileId => throw _privateConstructorUsedError;
  @JsonKey(name: 'author_display_name')
  String? get authorDisplayName => throw _privateConstructorUsedError;
  @JsonKey(name: 'author_avatar_url')
  String? get authorAvatarUrl => throw _privateConstructorUsedError;
  String get body => throw _privateConstructorUsedError;
  @JsonKey(name: 'parent_comment_id')
  String? get parentCommentId => throw _privateConstructorUsedError;
  @JsonKey(name: 'image_url')
  String? get imageUrl => throw _privateConstructorUsedError;
  @JsonKey(name: 'gif_url')
  String? get gifUrl => throw _privateConstructorUsedError;
  @JsonKey(name: 'location_name')
  String? get locationName => throw _privateConstructorUsedError;
  @JsonKey(name: 'location_lat')
  double? get locationLat => throw _privateConstructorUsedError;
  @JsonKey(name: 'location_lng')
  double? get locationLng => throw _privateConstructorUsedError;
  @JsonKey(name: 'is_deleted')
  bool get isDeleted => throw _privateConstructorUsedError;
  @JsonKey(name: 'is_hidden_admin')
  bool get isHiddenAdmin => throw _privateConstructorUsedError;
  @JsonKey(name: 'created_at')
  DateTime get createdAt => throw _privateConstructorUsedError;

  /// Serializes this PostComment to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of PostComment
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $PostCommentCopyWith<PostComment> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PostCommentCopyWith<$Res> {
  factory $PostCommentCopyWith(
    PostComment value,
    $Res Function(PostComment) then,
  ) = _$PostCommentCopyWithImpl<$Res, PostComment>;
  @useResult
  $Res call({
    String id,
    @JsonKey(name: 'post_id') String postId,
    @JsonKey(name: 'author_user_id') String authorUserId,
    @JsonKey(name: 'author_profile_id') String authorProfileId,
    @JsonKey(name: 'author_display_name') String? authorDisplayName,
    @JsonKey(name: 'author_avatar_url') String? authorAvatarUrl,
    String body,
    @JsonKey(name: 'parent_comment_id') String? parentCommentId,
    @JsonKey(name: 'image_url') String? imageUrl,
    @JsonKey(name: 'gif_url') String? gifUrl,
    @JsonKey(name: 'location_name') String? locationName,
    @JsonKey(name: 'location_lat') double? locationLat,
    @JsonKey(name: 'location_lng') double? locationLng,
    @JsonKey(name: 'is_deleted') bool isDeleted,
    @JsonKey(name: 'is_hidden_admin') bool isHiddenAdmin,
    @JsonKey(name: 'created_at') DateTime createdAt,
  });
}

/// @nodoc
class _$PostCommentCopyWithImpl<$Res, $Val extends PostComment>
    implements $PostCommentCopyWith<$Res> {
  _$PostCommentCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of PostComment
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? postId = null,
    Object? authorUserId = null,
    Object? authorProfileId = null,
    Object? authorDisplayName = freezed,
    Object? authorAvatarUrl = freezed,
    Object? body = null,
    Object? parentCommentId = freezed,
    Object? imageUrl = freezed,
    Object? gifUrl = freezed,
    Object? locationName = freezed,
    Object? locationLat = freezed,
    Object? locationLng = freezed,
    Object? isDeleted = null,
    Object? isHiddenAdmin = null,
    Object? createdAt = null,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            postId: null == postId
                ? _value.postId
                : postId // ignore: cast_nullable_to_non_nullable
                      as String,
            authorUserId: null == authorUserId
                ? _value.authorUserId
                : authorUserId // ignore: cast_nullable_to_non_nullable
                      as String,
            authorProfileId: null == authorProfileId
                ? _value.authorProfileId
                : authorProfileId // ignore: cast_nullable_to_non_nullable
                      as String,
            authorDisplayName: freezed == authorDisplayName
                ? _value.authorDisplayName
                : authorDisplayName // ignore: cast_nullable_to_non_nullable
                      as String?,
            authorAvatarUrl: freezed == authorAvatarUrl
                ? _value.authorAvatarUrl
                : authorAvatarUrl // ignore: cast_nullable_to_non_nullable
                      as String?,
            body: null == body
                ? _value.body
                : body // ignore: cast_nullable_to_non_nullable
                      as String,
            parentCommentId: freezed == parentCommentId
                ? _value.parentCommentId
                : parentCommentId // ignore: cast_nullable_to_non_nullable
                      as String?,
            imageUrl: freezed == imageUrl
                ? _value.imageUrl
                : imageUrl // ignore: cast_nullable_to_non_nullable
                      as String?,
            gifUrl: freezed == gifUrl
                ? _value.gifUrl
                : gifUrl // ignore: cast_nullable_to_non_nullable
                      as String?,
            locationName: freezed == locationName
                ? _value.locationName
                : locationName // ignore: cast_nullable_to_non_nullable
                      as String?,
            locationLat: freezed == locationLat
                ? _value.locationLat
                : locationLat // ignore: cast_nullable_to_non_nullable
                      as double?,
            locationLng: freezed == locationLng
                ? _value.locationLng
                : locationLng // ignore: cast_nullable_to_non_nullable
                      as double?,
            isDeleted: null == isDeleted
                ? _value.isDeleted
                : isDeleted // ignore: cast_nullable_to_non_nullable
                      as bool,
            isHiddenAdmin: null == isHiddenAdmin
                ? _value.isHiddenAdmin
                : isHiddenAdmin // ignore: cast_nullable_to_non_nullable
                      as bool,
            createdAt: null == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$PostCommentImplCopyWith<$Res>
    implements $PostCommentCopyWith<$Res> {
  factory _$$PostCommentImplCopyWith(
    _$PostCommentImpl value,
    $Res Function(_$PostCommentImpl) then,
  ) = __$$PostCommentImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    @JsonKey(name: 'post_id') String postId,
    @JsonKey(name: 'author_user_id') String authorUserId,
    @JsonKey(name: 'author_profile_id') String authorProfileId,
    @JsonKey(name: 'author_display_name') String? authorDisplayName,
    @JsonKey(name: 'author_avatar_url') String? authorAvatarUrl,
    String body,
    @JsonKey(name: 'parent_comment_id') String? parentCommentId,
    @JsonKey(name: 'image_url') String? imageUrl,
    @JsonKey(name: 'gif_url') String? gifUrl,
    @JsonKey(name: 'location_name') String? locationName,
    @JsonKey(name: 'location_lat') double? locationLat,
    @JsonKey(name: 'location_lng') double? locationLng,
    @JsonKey(name: 'is_deleted') bool isDeleted,
    @JsonKey(name: 'is_hidden_admin') bool isHiddenAdmin,
    @JsonKey(name: 'created_at') DateTime createdAt,
  });
}

/// @nodoc
class __$$PostCommentImplCopyWithImpl<$Res>
    extends _$PostCommentCopyWithImpl<$Res, _$PostCommentImpl>
    implements _$$PostCommentImplCopyWith<$Res> {
  __$$PostCommentImplCopyWithImpl(
    _$PostCommentImpl _value,
    $Res Function(_$PostCommentImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of PostComment
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? postId = null,
    Object? authorUserId = null,
    Object? authorProfileId = null,
    Object? authorDisplayName = freezed,
    Object? authorAvatarUrl = freezed,
    Object? body = null,
    Object? parentCommentId = freezed,
    Object? imageUrl = freezed,
    Object? gifUrl = freezed,
    Object? locationName = freezed,
    Object? locationLat = freezed,
    Object? locationLng = freezed,
    Object? isDeleted = null,
    Object? isHiddenAdmin = null,
    Object? createdAt = null,
  }) {
    return _then(
      _$PostCommentImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        postId: null == postId
            ? _value.postId
            : postId // ignore: cast_nullable_to_non_nullable
                  as String,
        authorUserId: null == authorUserId
            ? _value.authorUserId
            : authorUserId // ignore: cast_nullable_to_non_nullable
                  as String,
        authorProfileId: null == authorProfileId
            ? _value.authorProfileId
            : authorProfileId // ignore: cast_nullable_to_non_nullable
                  as String,
        authorDisplayName: freezed == authorDisplayName
            ? _value.authorDisplayName
            : authorDisplayName // ignore: cast_nullable_to_non_nullable
                  as String?,
        authorAvatarUrl: freezed == authorAvatarUrl
            ? _value.authorAvatarUrl
            : authorAvatarUrl // ignore: cast_nullable_to_non_nullable
                  as String?,
        body: null == body
            ? _value.body
            : body // ignore: cast_nullable_to_non_nullable
                  as String,
        parentCommentId: freezed == parentCommentId
            ? _value.parentCommentId
            : parentCommentId // ignore: cast_nullable_to_non_nullable
                  as String?,
        imageUrl: freezed == imageUrl
            ? _value.imageUrl
            : imageUrl // ignore: cast_nullable_to_non_nullable
                  as String?,
        gifUrl: freezed == gifUrl
            ? _value.gifUrl
            : gifUrl // ignore: cast_nullable_to_non_nullable
                  as String?,
        locationName: freezed == locationName
            ? _value.locationName
            : locationName // ignore: cast_nullable_to_non_nullable
                  as String?,
        locationLat: freezed == locationLat
            ? _value.locationLat
            : locationLat // ignore: cast_nullable_to_non_nullable
                  as double?,
        locationLng: freezed == locationLng
            ? _value.locationLng
            : locationLng // ignore: cast_nullable_to_non_nullable
                  as double?,
        isDeleted: null == isDeleted
            ? _value.isDeleted
            : isDeleted // ignore: cast_nullable_to_non_nullable
                  as bool,
        isHiddenAdmin: null == isHiddenAdmin
            ? _value.isHiddenAdmin
            : isHiddenAdmin // ignore: cast_nullable_to_non_nullable
                  as bool,
        createdAt: null == createdAt
            ? _value.createdAt
            : createdAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$PostCommentImpl implements _PostComment {
  const _$PostCommentImpl({
    required this.id,
    @JsonKey(name: 'post_id') required this.postId,
    @JsonKey(name: 'author_user_id') required this.authorUserId,
    @JsonKey(name: 'author_profile_id') required this.authorProfileId,
    @JsonKey(name: 'author_display_name') this.authorDisplayName,
    @JsonKey(name: 'author_avatar_url') this.authorAvatarUrl,
    required this.body,
    @JsonKey(name: 'parent_comment_id') this.parentCommentId,
    @JsonKey(name: 'image_url') this.imageUrl,
    @JsonKey(name: 'gif_url') this.gifUrl,
    @JsonKey(name: 'location_name') this.locationName,
    @JsonKey(name: 'location_lat') this.locationLat,
    @JsonKey(name: 'location_lng') this.locationLng,
    @JsonKey(name: 'is_deleted') this.isDeleted = false,
    @JsonKey(name: 'is_hidden_admin') this.isHiddenAdmin = false,
    @JsonKey(name: 'created_at') required this.createdAt,
  });

  factory _$PostCommentImpl.fromJson(Map<String, dynamic> json) =>
      _$$PostCommentImplFromJson(json);

  @override
  final String id;
  @override
  @JsonKey(name: 'post_id')
  final String postId;
  @override
  @JsonKey(name: 'author_user_id')
  final String authorUserId;
  @override
  @JsonKey(name: 'author_profile_id')
  final String authorProfileId;
  @override
  @JsonKey(name: 'author_display_name')
  final String? authorDisplayName;
  @override
  @JsonKey(name: 'author_avatar_url')
  final String? authorAvatarUrl;
  @override
  final String body;
  @override
  @JsonKey(name: 'parent_comment_id')
  final String? parentCommentId;
  @override
  @JsonKey(name: 'image_url')
  final String? imageUrl;
  @override
  @JsonKey(name: 'gif_url')
  final String? gifUrl;
  @override
  @JsonKey(name: 'location_name')
  final String? locationName;
  @override
  @JsonKey(name: 'location_lat')
  final double? locationLat;
  @override
  @JsonKey(name: 'location_lng')
  final double? locationLng;
  @override
  @JsonKey(name: 'is_deleted')
  final bool isDeleted;
  @override
  @JsonKey(name: 'is_hidden_admin')
  final bool isHiddenAdmin;
  @override
  @JsonKey(name: 'created_at')
  final DateTime createdAt;

  @override
  String toString() {
    return 'PostComment(id: $id, postId: $postId, authorUserId: $authorUserId, authorProfileId: $authorProfileId, authorDisplayName: $authorDisplayName, authorAvatarUrl: $authorAvatarUrl, body: $body, parentCommentId: $parentCommentId, imageUrl: $imageUrl, gifUrl: $gifUrl, locationName: $locationName, locationLat: $locationLat, locationLng: $locationLng, isDeleted: $isDeleted, isHiddenAdmin: $isHiddenAdmin, createdAt: $createdAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PostCommentImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.postId, postId) || other.postId == postId) &&
            (identical(other.authorUserId, authorUserId) ||
                other.authorUserId == authorUserId) &&
            (identical(other.authorProfileId, authorProfileId) ||
                other.authorProfileId == authorProfileId) &&
            (identical(other.authorDisplayName, authorDisplayName) ||
                other.authorDisplayName == authorDisplayName) &&
            (identical(other.authorAvatarUrl, authorAvatarUrl) ||
                other.authorAvatarUrl == authorAvatarUrl) &&
            (identical(other.body, body) || other.body == body) &&
            (identical(other.parentCommentId, parentCommentId) ||
                other.parentCommentId == parentCommentId) &&
            (identical(other.imageUrl, imageUrl) ||
                other.imageUrl == imageUrl) &&
            (identical(other.gifUrl, gifUrl) || other.gifUrl == gifUrl) &&
            (identical(other.locationName, locationName) ||
                other.locationName == locationName) &&
            (identical(other.locationLat, locationLat) ||
                other.locationLat == locationLat) &&
            (identical(other.locationLng, locationLng) ||
                other.locationLng == locationLng) &&
            (identical(other.isDeleted, isDeleted) ||
                other.isDeleted == isDeleted) &&
            (identical(other.isHiddenAdmin, isHiddenAdmin) ||
                other.isHiddenAdmin == isHiddenAdmin) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    postId,
    authorUserId,
    authorProfileId,
    authorDisplayName,
    authorAvatarUrl,
    body,
    parentCommentId,
    imageUrl,
    gifUrl,
    locationName,
    locationLat,
    locationLng,
    isDeleted,
    isHiddenAdmin,
    createdAt,
  );

  /// Create a copy of PostComment
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$PostCommentImplCopyWith<_$PostCommentImpl> get copyWith =>
      __$$PostCommentImplCopyWithImpl<_$PostCommentImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$PostCommentImplToJson(this);
  }
}

abstract class _PostComment implements PostComment {
  const factory _PostComment({
    required final String id,
    @JsonKey(name: 'post_id') required final String postId,
    @JsonKey(name: 'author_user_id') required final String authorUserId,
    @JsonKey(name: 'author_profile_id') required final String authorProfileId,
    @JsonKey(name: 'author_display_name') final String? authorDisplayName,
    @JsonKey(name: 'author_avatar_url') final String? authorAvatarUrl,
    required final String body,
    @JsonKey(name: 'parent_comment_id') final String? parentCommentId,
    @JsonKey(name: 'image_url') final String? imageUrl,
    @JsonKey(name: 'gif_url') final String? gifUrl,
    @JsonKey(name: 'location_name') final String? locationName,
    @JsonKey(name: 'location_lat') final double? locationLat,
    @JsonKey(name: 'location_lng') final double? locationLng,
    @JsonKey(name: 'is_deleted') final bool isDeleted,
    @JsonKey(name: 'is_hidden_admin') final bool isHiddenAdmin,
    @JsonKey(name: 'created_at') required final DateTime createdAt,
  }) = _$PostCommentImpl;

  factory _PostComment.fromJson(Map<String, dynamic> json) =
      _$PostCommentImpl.fromJson;

  @override
  String get id;
  @override
  @JsonKey(name: 'post_id')
  String get postId;
  @override
  @JsonKey(name: 'author_user_id')
  String get authorUserId;
  @override
  @JsonKey(name: 'author_profile_id')
  String get authorProfileId;
  @override
  @JsonKey(name: 'author_display_name')
  String? get authorDisplayName;
  @override
  @JsonKey(name: 'author_avatar_url')
  String? get authorAvatarUrl;
  @override
  String get body;
  @override
  @JsonKey(name: 'parent_comment_id')
  String? get parentCommentId;
  @override
  @JsonKey(name: 'image_url')
  String? get imageUrl;
  @override
  @JsonKey(name: 'gif_url')
  String? get gifUrl;
  @override
  @JsonKey(name: 'location_name')
  String? get locationName;
  @override
  @JsonKey(name: 'location_lat')
  double? get locationLat;
  @override
  @JsonKey(name: 'location_lng')
  double? get locationLng;
  @override
  @JsonKey(name: 'is_deleted')
  bool get isDeleted;
  @override
  @JsonKey(name: 'is_hidden_admin')
  bool get isHiddenAdmin;
  @override
  @JsonKey(name: 'created_at')
  DateTime get createdAt;

  /// Create a copy of PostComment
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PostCommentImplCopyWith<_$PostCommentImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
