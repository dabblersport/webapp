// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'friend_requests_audit.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

FriendRequestAudit _$FriendRequestAuditFromJson(Map<String, dynamic> json) {
  return _FriendRequestAudit.fromJson(json);
}

/// @nodoc
mixin _$FriendRequestAudit {
  String get id => throw _privateConstructorUsedError;
  @JsonKey(name: 'from_user')
  String get fromUser => throw _privateConstructorUsedError;
  @JsonKey(name: 'to_user')
  String get toUser => throw _privateConstructorUsedError;
  String get action => throw _privateConstructorUsedError;
  @JsonKey(name: 'edge_id')
  String? get edgeId => throw _privateConstructorUsedError;
  @JsonKey(name: 'created_at')
  DateTime get createdAt => throw _privateConstructorUsedError;

  /// Serializes this FriendRequestAudit to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of FriendRequestAudit
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $FriendRequestAuditCopyWith<FriendRequestAudit> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $FriendRequestAuditCopyWith<$Res> {
  factory $FriendRequestAuditCopyWith(
    FriendRequestAudit value,
    $Res Function(FriendRequestAudit) then,
  ) = _$FriendRequestAuditCopyWithImpl<$Res, FriendRequestAudit>;
  @useResult
  $Res call({
    String id,
    @JsonKey(name: 'from_user') String fromUser,
    @JsonKey(name: 'to_user') String toUser,
    String action,
    @JsonKey(name: 'edge_id') String? edgeId,
    @JsonKey(name: 'created_at') DateTime createdAt,
  });
}

/// @nodoc
class _$FriendRequestAuditCopyWithImpl<$Res, $Val extends FriendRequestAudit>
    implements $FriendRequestAuditCopyWith<$Res> {
  _$FriendRequestAuditCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of FriendRequestAudit
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? fromUser = null,
    Object? toUser = null,
    Object? action = null,
    Object? edgeId = freezed,
    Object? createdAt = null,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            fromUser: null == fromUser
                ? _value.fromUser
                : fromUser // ignore: cast_nullable_to_non_nullable
                      as String,
            toUser: null == toUser
                ? _value.toUser
                : toUser // ignore: cast_nullable_to_non_nullable
                      as String,
            action: null == action
                ? _value.action
                : action // ignore: cast_nullable_to_non_nullable
                      as String,
            edgeId: freezed == edgeId
                ? _value.edgeId
                : edgeId // ignore: cast_nullable_to_non_nullable
                      as String?,
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
abstract class _$$FriendRequestAuditImplCopyWith<$Res>
    implements $FriendRequestAuditCopyWith<$Res> {
  factory _$$FriendRequestAuditImplCopyWith(
    _$FriendRequestAuditImpl value,
    $Res Function(_$FriendRequestAuditImpl) then,
  ) = __$$FriendRequestAuditImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    @JsonKey(name: 'from_user') String fromUser,
    @JsonKey(name: 'to_user') String toUser,
    String action,
    @JsonKey(name: 'edge_id') String? edgeId,
    @JsonKey(name: 'created_at') DateTime createdAt,
  });
}

/// @nodoc
class __$$FriendRequestAuditImplCopyWithImpl<$Res>
    extends _$FriendRequestAuditCopyWithImpl<$Res, _$FriendRequestAuditImpl>
    implements _$$FriendRequestAuditImplCopyWith<$Res> {
  __$$FriendRequestAuditImplCopyWithImpl(
    _$FriendRequestAuditImpl _value,
    $Res Function(_$FriendRequestAuditImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of FriendRequestAudit
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? fromUser = null,
    Object? toUser = null,
    Object? action = null,
    Object? edgeId = freezed,
    Object? createdAt = null,
  }) {
    return _then(
      _$FriendRequestAuditImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        fromUser: null == fromUser
            ? _value.fromUser
            : fromUser // ignore: cast_nullable_to_non_nullable
                  as String,
        toUser: null == toUser
            ? _value.toUser
            : toUser // ignore: cast_nullable_to_non_nullable
                  as String,
        action: null == action
            ? _value.action
            : action // ignore: cast_nullable_to_non_nullable
                  as String,
        edgeId: freezed == edgeId
            ? _value.edgeId
            : edgeId // ignore: cast_nullable_to_non_nullable
                  as String?,
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
class _$FriendRequestAuditImpl implements _FriendRequestAudit {
  const _$FriendRequestAuditImpl({
    required this.id,
    @JsonKey(name: 'from_user') required this.fromUser,
    @JsonKey(name: 'to_user') required this.toUser,
    required this.action,
    @JsonKey(name: 'edge_id') this.edgeId,
    @JsonKey(name: 'created_at') required this.createdAt,
  });

  factory _$FriendRequestAuditImpl.fromJson(Map<String, dynamic> json) =>
      _$$FriendRequestAuditImplFromJson(json);

  @override
  final String id;
  @override
  @JsonKey(name: 'from_user')
  final String fromUser;
  @override
  @JsonKey(name: 'to_user')
  final String toUser;
  @override
  final String action;
  @override
  @JsonKey(name: 'edge_id')
  final String? edgeId;
  @override
  @JsonKey(name: 'created_at')
  final DateTime createdAt;

  @override
  String toString() {
    return 'FriendRequestAudit(id: $id, fromUser: $fromUser, toUser: $toUser, action: $action, edgeId: $edgeId, createdAt: $createdAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$FriendRequestAuditImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.fromUser, fromUser) ||
                other.fromUser == fromUser) &&
            (identical(other.toUser, toUser) || other.toUser == toUser) &&
            (identical(other.action, action) || other.action == action) &&
            (identical(other.edgeId, edgeId) || other.edgeId == edgeId) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, id, fromUser, toUser, action, edgeId, createdAt);

  /// Create a copy of FriendRequestAudit
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$FriendRequestAuditImplCopyWith<_$FriendRequestAuditImpl> get copyWith =>
      __$$FriendRequestAuditImplCopyWithImpl<_$FriendRequestAuditImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$FriendRequestAuditImplToJson(this);
  }
}

abstract class _FriendRequestAudit implements FriendRequestAudit {
  const factory _FriendRequestAudit({
    required final String id,
    @JsonKey(name: 'from_user') required final String fromUser,
    @JsonKey(name: 'to_user') required final String toUser,
    required final String action,
    @JsonKey(name: 'edge_id') final String? edgeId,
    @JsonKey(name: 'created_at') required final DateTime createdAt,
  }) = _$FriendRequestAuditImpl;

  factory _FriendRequestAudit.fromJson(Map<String, dynamic> json) =
      _$FriendRequestAuditImpl.fromJson;

  @override
  String get id;
  @override
  @JsonKey(name: 'from_user')
  String get fromUser;
  @override
  @JsonKey(name: 'to_user')
  String get toUser;
  @override
  String get action;
  @override
  @JsonKey(name: 'edge_id')
  String? get edgeId;
  @override
  @JsonKey(name: 'created_at')
  DateTime get createdAt;

  /// Create a copy of FriendRequestAudit
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$FriendRequestAuditImplCopyWith<_$FriendRequestAuditImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
