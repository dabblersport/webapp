// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'friendship.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

Friendship _$FriendshipFromJson(Map<String, dynamic> json) {
  return _Friendship.fromJson(json);
}

/// @nodoc
mixin _$Friendship {
  @JsonKey(name: 'user_id')
  String get userId => throw _privateConstructorUsedError;
  @JsonKey(name: 'peer_user_id')
  String get peerUserId => throw _privateConstructorUsedError;
  @JsonKey(name: 'requested_by')
  String? get requestedBy => throw _privateConstructorUsedError;
  String get status => throw _privateConstructorUsedError;
  @JsonKey(name: 'created_at')
  DateTime get createdAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'updated_at')
  DateTime get updatedAt => throw _privateConstructorUsedError;

  /// Serializes this Friendship to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Friendship
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $FriendshipCopyWith<Friendship> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $FriendshipCopyWith<$Res> {
  factory $FriendshipCopyWith(
    Friendship value,
    $Res Function(Friendship) then,
  ) = _$FriendshipCopyWithImpl<$Res, Friendship>;
  @useResult
  $Res call({
    @JsonKey(name: 'user_id') String userId,
    @JsonKey(name: 'peer_user_id') String peerUserId,
    @JsonKey(name: 'requested_by') String? requestedBy,
    String status,
    @JsonKey(name: 'created_at') DateTime createdAt,
    @JsonKey(name: 'updated_at') DateTime updatedAt,
  });
}

/// @nodoc
class _$FriendshipCopyWithImpl<$Res, $Val extends Friendship>
    implements $FriendshipCopyWith<$Res> {
  _$FriendshipCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Friendship
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? userId = null,
    Object? peerUserId = null,
    Object? requestedBy = freezed,
    Object? status = null,
    Object? createdAt = null,
    Object? updatedAt = null,
  }) {
    return _then(
      _value.copyWith(
            userId: null == userId
                ? _value.userId
                : userId // ignore: cast_nullable_to_non_nullable
                      as String,
            peerUserId: null == peerUserId
                ? _value.peerUserId
                : peerUserId // ignore: cast_nullable_to_non_nullable
                      as String,
            requestedBy: freezed == requestedBy
                ? _value.requestedBy
                : requestedBy // ignore: cast_nullable_to_non_nullable
                      as String?,
            status: null == status
                ? _value.status
                : status // ignore: cast_nullable_to_non_nullable
                      as String,
            createdAt: null == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            updatedAt: null == updatedAt
                ? _value.updatedAt
                : updatedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$FriendshipImplCopyWith<$Res>
    implements $FriendshipCopyWith<$Res> {
  factory _$$FriendshipImplCopyWith(
    _$FriendshipImpl value,
    $Res Function(_$FriendshipImpl) then,
  ) = __$$FriendshipImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    @JsonKey(name: 'user_id') String userId,
    @JsonKey(name: 'peer_user_id') String peerUserId,
    @JsonKey(name: 'requested_by') String? requestedBy,
    String status,
    @JsonKey(name: 'created_at') DateTime createdAt,
    @JsonKey(name: 'updated_at') DateTime updatedAt,
  });
}

/// @nodoc
class __$$FriendshipImplCopyWithImpl<$Res>
    extends _$FriendshipCopyWithImpl<$Res, _$FriendshipImpl>
    implements _$$FriendshipImplCopyWith<$Res> {
  __$$FriendshipImplCopyWithImpl(
    _$FriendshipImpl _value,
    $Res Function(_$FriendshipImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of Friendship
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? userId = null,
    Object? peerUserId = null,
    Object? requestedBy = freezed,
    Object? status = null,
    Object? createdAt = null,
    Object? updatedAt = null,
  }) {
    return _then(
      _$FriendshipImpl(
        userId: null == userId
            ? _value.userId
            : userId // ignore: cast_nullable_to_non_nullable
                  as String,
        peerUserId: null == peerUserId
            ? _value.peerUserId
            : peerUserId // ignore: cast_nullable_to_non_nullable
                  as String,
        requestedBy: freezed == requestedBy
            ? _value.requestedBy
            : requestedBy // ignore: cast_nullable_to_non_nullable
                  as String?,
        status: null == status
            ? _value.status
            : status // ignore: cast_nullable_to_non_nullable
                  as String,
        createdAt: null == createdAt
            ? _value.createdAt
            : createdAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        updatedAt: null == updatedAt
            ? _value.updatedAt
            : updatedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$FriendshipImpl implements _Friendship {
  const _$FriendshipImpl({
    @JsonKey(name: 'user_id') required this.userId,
    @JsonKey(name: 'peer_user_id') required this.peerUserId,
    @JsonKey(name: 'requested_by') this.requestedBy,
    required this.status,
    @JsonKey(name: 'created_at') required this.createdAt,
    @JsonKey(name: 'updated_at') required this.updatedAt,
  });

  factory _$FriendshipImpl.fromJson(Map<String, dynamic> json) =>
      _$$FriendshipImplFromJson(json);

  @override
  @JsonKey(name: 'user_id')
  final String userId;
  @override
  @JsonKey(name: 'peer_user_id')
  final String peerUserId;
  @override
  @JsonKey(name: 'requested_by')
  final String? requestedBy;
  @override
  final String status;
  @override
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  @override
  @JsonKey(name: 'updated_at')
  final DateTime updatedAt;

  @override
  String toString() {
    return 'Friendship(userId: $userId, peerUserId: $peerUserId, requestedBy: $requestedBy, status: $status, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$FriendshipImpl &&
            (identical(other.userId, userId) || other.userId == userId) &&
            (identical(other.peerUserId, peerUserId) ||
                other.peerUserId == peerUserId) &&
            (identical(other.requestedBy, requestedBy) ||
                other.requestedBy == requestedBy) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    userId,
    peerUserId,
    requestedBy,
    status,
    createdAt,
    updatedAt,
  );

  /// Create a copy of Friendship
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$FriendshipImplCopyWith<_$FriendshipImpl> get copyWith =>
      __$$FriendshipImplCopyWithImpl<_$FriendshipImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$FriendshipImplToJson(this);
  }
}

abstract class _Friendship implements Friendship {
  const factory _Friendship({
    @JsonKey(name: 'user_id') required final String userId,
    @JsonKey(name: 'peer_user_id') required final String peerUserId,
    @JsonKey(name: 'requested_by') final String? requestedBy,
    required final String status,
    @JsonKey(name: 'created_at') required final DateTime createdAt,
    @JsonKey(name: 'updated_at') required final DateTime updatedAt,
  }) = _$FriendshipImpl;

  factory _Friendship.fromJson(Map<String, dynamic> json) =
      _$FriendshipImpl.fromJson;

  @override
  @JsonKey(name: 'user_id')
  String get userId;
  @override
  @JsonKey(name: 'peer_user_id')
  String get peerUserId;
  @override
  @JsonKey(name: 'requested_by')
  String? get requestedBy;
  @override
  String get status;
  @override
  @JsonKey(name: 'created_at')
  DateTime get createdAt;
  @override
  @JsonKey(name: 'updated_at')
  DateTime get updatedAt;

  /// Create a copy of Friendship
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$FriendshipImplCopyWith<_$FriendshipImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
