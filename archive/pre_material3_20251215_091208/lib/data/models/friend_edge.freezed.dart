// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'friend_edge.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

FriendEdge _$FriendEdgeFromJson(Map<String, dynamic> json) {
  return _FriendEdge.fromJson(json);
}

/// @nodoc
mixin _$FriendEdge {
  String get id => throw _privateConstructorUsedError;
  @JsonKey(name: 'user_a')
  String get userA => throw _privateConstructorUsedError;
  @JsonKey(name: 'user_b')
  String get userB => throw _privateConstructorUsedError;
  String get status => throw _privateConstructorUsedError;
  @JsonKey(name: 'requested_by')
  String get requestedBy => throw _privateConstructorUsedError;
  @JsonKey(name: 'responded_by')
  String? get respondedBy => throw _privateConstructorUsedError;
  @JsonKey(name: 'created_at')
  DateTime get createdAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'updated_at')
  DateTime get updatedAt => throw _privateConstructorUsedError;

  /// Serializes this FriendEdge to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of FriendEdge
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $FriendEdgeCopyWith<FriendEdge> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $FriendEdgeCopyWith<$Res> {
  factory $FriendEdgeCopyWith(
    FriendEdge value,
    $Res Function(FriendEdge) then,
  ) = _$FriendEdgeCopyWithImpl<$Res, FriendEdge>;
  @useResult
  $Res call({
    String id,
    @JsonKey(name: 'user_a') String userA,
    @JsonKey(name: 'user_b') String userB,
    String status,
    @JsonKey(name: 'requested_by') String requestedBy,
    @JsonKey(name: 'responded_by') String? respondedBy,
    @JsonKey(name: 'created_at') DateTime createdAt,
    @JsonKey(name: 'updated_at') DateTime updatedAt,
  });
}

/// @nodoc
class _$FriendEdgeCopyWithImpl<$Res, $Val extends FriendEdge>
    implements $FriendEdgeCopyWith<$Res> {
  _$FriendEdgeCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of FriendEdge
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? userA = null,
    Object? userB = null,
    Object? status = null,
    Object? requestedBy = null,
    Object? respondedBy = freezed,
    Object? createdAt = null,
    Object? updatedAt = null,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            userA: null == userA
                ? _value.userA
                : userA // ignore: cast_nullable_to_non_nullable
                      as String,
            userB: null == userB
                ? _value.userB
                : userB // ignore: cast_nullable_to_non_nullable
                      as String,
            status: null == status
                ? _value.status
                : status // ignore: cast_nullable_to_non_nullable
                      as String,
            requestedBy: null == requestedBy
                ? _value.requestedBy
                : requestedBy // ignore: cast_nullable_to_non_nullable
                      as String,
            respondedBy: freezed == respondedBy
                ? _value.respondedBy
                : respondedBy // ignore: cast_nullable_to_non_nullable
                      as String?,
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
abstract class _$$FriendEdgeImplCopyWith<$Res>
    implements $FriendEdgeCopyWith<$Res> {
  factory _$$FriendEdgeImplCopyWith(
    _$FriendEdgeImpl value,
    $Res Function(_$FriendEdgeImpl) then,
  ) = __$$FriendEdgeImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    @JsonKey(name: 'user_a') String userA,
    @JsonKey(name: 'user_b') String userB,
    String status,
    @JsonKey(name: 'requested_by') String requestedBy,
    @JsonKey(name: 'responded_by') String? respondedBy,
    @JsonKey(name: 'created_at') DateTime createdAt,
    @JsonKey(name: 'updated_at') DateTime updatedAt,
  });
}

/// @nodoc
class __$$FriendEdgeImplCopyWithImpl<$Res>
    extends _$FriendEdgeCopyWithImpl<$Res, _$FriendEdgeImpl>
    implements _$$FriendEdgeImplCopyWith<$Res> {
  __$$FriendEdgeImplCopyWithImpl(
    _$FriendEdgeImpl _value,
    $Res Function(_$FriendEdgeImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of FriendEdge
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? userA = null,
    Object? userB = null,
    Object? status = null,
    Object? requestedBy = null,
    Object? respondedBy = freezed,
    Object? createdAt = null,
    Object? updatedAt = null,
  }) {
    return _then(
      _$FriendEdgeImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        userA: null == userA
            ? _value.userA
            : userA // ignore: cast_nullable_to_non_nullable
                  as String,
        userB: null == userB
            ? _value.userB
            : userB // ignore: cast_nullable_to_non_nullable
                  as String,
        status: null == status
            ? _value.status
            : status // ignore: cast_nullable_to_non_nullable
                  as String,
        requestedBy: null == requestedBy
            ? _value.requestedBy
            : requestedBy // ignore: cast_nullable_to_non_nullable
                  as String,
        respondedBy: freezed == respondedBy
            ? _value.respondedBy
            : respondedBy // ignore: cast_nullable_to_non_nullable
                  as String?,
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
class _$FriendEdgeImpl implements _FriendEdge {
  const _$FriendEdgeImpl({
    required this.id,
    @JsonKey(name: 'user_a') required this.userA,
    @JsonKey(name: 'user_b') required this.userB,
    required this.status,
    @JsonKey(name: 'requested_by') required this.requestedBy,
    @JsonKey(name: 'responded_by') this.respondedBy,
    @JsonKey(name: 'created_at') required this.createdAt,
    @JsonKey(name: 'updated_at') required this.updatedAt,
  });

  factory _$FriendEdgeImpl.fromJson(Map<String, dynamic> json) =>
      _$$FriendEdgeImplFromJson(json);

  @override
  final String id;
  @override
  @JsonKey(name: 'user_a')
  final String userA;
  @override
  @JsonKey(name: 'user_b')
  final String userB;
  @override
  final String status;
  @override
  @JsonKey(name: 'requested_by')
  final String requestedBy;
  @override
  @JsonKey(name: 'responded_by')
  final String? respondedBy;
  @override
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  @override
  @JsonKey(name: 'updated_at')
  final DateTime updatedAt;

  @override
  String toString() {
    return 'FriendEdge(id: $id, userA: $userA, userB: $userB, status: $status, requestedBy: $requestedBy, respondedBy: $respondedBy, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$FriendEdgeImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.userA, userA) || other.userA == userA) &&
            (identical(other.userB, userB) || other.userB == userB) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.requestedBy, requestedBy) ||
                other.requestedBy == requestedBy) &&
            (identical(other.respondedBy, respondedBy) ||
                other.respondedBy == respondedBy) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    userA,
    userB,
    status,
    requestedBy,
    respondedBy,
    createdAt,
    updatedAt,
  );

  /// Create a copy of FriendEdge
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$FriendEdgeImplCopyWith<_$FriendEdgeImpl> get copyWith =>
      __$$FriendEdgeImplCopyWithImpl<_$FriendEdgeImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$FriendEdgeImplToJson(this);
  }
}

abstract class _FriendEdge implements FriendEdge {
  const factory _FriendEdge({
    required final String id,
    @JsonKey(name: 'user_a') required final String userA,
    @JsonKey(name: 'user_b') required final String userB,
    required final String status,
    @JsonKey(name: 'requested_by') required final String requestedBy,
    @JsonKey(name: 'responded_by') final String? respondedBy,
    @JsonKey(name: 'created_at') required final DateTime createdAt,
    @JsonKey(name: 'updated_at') required final DateTime updatedAt,
  }) = _$FriendEdgeImpl;

  factory _FriendEdge.fromJson(Map<String, dynamic> json) =
      _$FriendEdgeImpl.fromJson;

  @override
  String get id;
  @override
  @JsonKey(name: 'user_a')
  String get userA;
  @override
  @JsonKey(name: 'user_b')
  String get userB;
  @override
  String get status;
  @override
  @JsonKey(name: 'requested_by')
  String get requestedBy;
  @override
  @JsonKey(name: 'responded_by')
  String? get respondedBy;
  @override
  @JsonKey(name: 'created_at')
  DateTime get createdAt;
  @override
  @JsonKey(name: 'updated_at')
  DateTime get updatedAt;

  /// Create a copy of FriendEdge
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$FriendEdgeImplCopyWith<_$FriendEdgeImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
