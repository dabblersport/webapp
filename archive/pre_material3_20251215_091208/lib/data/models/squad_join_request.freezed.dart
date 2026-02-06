// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'squad_join_request.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

SquadJoinRequest _$SquadJoinRequestFromJson(Map<String, dynamic> json) {
  return _SquadJoinRequest.fromJson(json);
}

/// @nodoc
mixin _$SquadJoinRequest {
  String get id => throw _privateConstructorUsedError;
  @JsonKey(name: 'squad_id')
  String get squadId => throw _privateConstructorUsedError;
  @JsonKey(name: 'user_id')
  String get userId => throw _privateConstructorUsedError;
  @JsonKey(name: 'profile_id')
  String get profileId => throw _privateConstructorUsedError;
  String get status => throw _privateConstructorUsedError;
  String? get message => throw _privateConstructorUsedError;
  @JsonKey(name: 'created_at')
  DateTime get createdAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'decided_at')
  DateTime? get decidedAt => throw _privateConstructorUsedError;

  /// Serializes this SquadJoinRequest to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of SquadJoinRequest
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SquadJoinRequestCopyWith<SquadJoinRequest> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SquadJoinRequestCopyWith<$Res> {
  factory $SquadJoinRequestCopyWith(
    SquadJoinRequest value,
    $Res Function(SquadJoinRequest) then,
  ) = _$SquadJoinRequestCopyWithImpl<$Res, SquadJoinRequest>;
  @useResult
  $Res call({
    String id,
    @JsonKey(name: 'squad_id') String squadId,
    @JsonKey(name: 'user_id') String userId,
    @JsonKey(name: 'profile_id') String profileId,
    String status,
    String? message,
    @JsonKey(name: 'created_at') DateTime createdAt,
    @JsonKey(name: 'decided_at') DateTime? decidedAt,
  });
}

/// @nodoc
class _$SquadJoinRequestCopyWithImpl<$Res, $Val extends SquadJoinRequest>
    implements $SquadJoinRequestCopyWith<$Res> {
  _$SquadJoinRequestCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SquadJoinRequest
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? squadId = null,
    Object? userId = null,
    Object? profileId = null,
    Object? status = null,
    Object? message = freezed,
    Object? createdAt = null,
    Object? decidedAt = freezed,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            squadId: null == squadId
                ? _value.squadId
                : squadId // ignore: cast_nullable_to_non_nullable
                      as String,
            userId: null == userId
                ? _value.userId
                : userId // ignore: cast_nullable_to_non_nullable
                      as String,
            profileId: null == profileId
                ? _value.profileId
                : profileId // ignore: cast_nullable_to_non_nullable
                      as String,
            status: null == status
                ? _value.status
                : status // ignore: cast_nullable_to_non_nullable
                      as String,
            message: freezed == message
                ? _value.message
                : message // ignore: cast_nullable_to_non_nullable
                      as String?,
            createdAt: null == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            decidedAt: freezed == decidedAt
                ? _value.decidedAt
                : decidedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$SquadJoinRequestImplCopyWith<$Res>
    implements $SquadJoinRequestCopyWith<$Res> {
  factory _$$SquadJoinRequestImplCopyWith(
    _$SquadJoinRequestImpl value,
    $Res Function(_$SquadJoinRequestImpl) then,
  ) = __$$SquadJoinRequestImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    @JsonKey(name: 'squad_id') String squadId,
    @JsonKey(name: 'user_id') String userId,
    @JsonKey(name: 'profile_id') String profileId,
    String status,
    String? message,
    @JsonKey(name: 'created_at') DateTime createdAt,
    @JsonKey(name: 'decided_at') DateTime? decidedAt,
  });
}

/// @nodoc
class __$$SquadJoinRequestImplCopyWithImpl<$Res>
    extends _$SquadJoinRequestCopyWithImpl<$Res, _$SquadJoinRequestImpl>
    implements _$$SquadJoinRequestImplCopyWith<$Res> {
  __$$SquadJoinRequestImplCopyWithImpl(
    _$SquadJoinRequestImpl _value,
    $Res Function(_$SquadJoinRequestImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of SquadJoinRequest
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? squadId = null,
    Object? userId = null,
    Object? profileId = null,
    Object? status = null,
    Object? message = freezed,
    Object? createdAt = null,
    Object? decidedAt = freezed,
  }) {
    return _then(
      _$SquadJoinRequestImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        squadId: null == squadId
            ? _value.squadId
            : squadId // ignore: cast_nullable_to_non_nullable
                  as String,
        userId: null == userId
            ? _value.userId
            : userId // ignore: cast_nullable_to_non_nullable
                  as String,
        profileId: null == profileId
            ? _value.profileId
            : profileId // ignore: cast_nullable_to_non_nullable
                  as String,
        status: null == status
            ? _value.status
            : status // ignore: cast_nullable_to_non_nullable
                  as String,
        message: freezed == message
            ? _value.message
            : message // ignore: cast_nullable_to_non_nullable
                  as String?,
        createdAt: null == createdAt
            ? _value.createdAt
            : createdAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        decidedAt: freezed == decidedAt
            ? _value.decidedAt
            : decidedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$SquadJoinRequestImpl implements _SquadJoinRequest {
  const _$SquadJoinRequestImpl({
    required this.id,
    @JsonKey(name: 'squad_id') required this.squadId,
    @JsonKey(name: 'user_id') required this.userId,
    @JsonKey(name: 'profile_id') required this.profileId,
    required this.status,
    this.message,
    @JsonKey(name: 'created_at') required this.createdAt,
    @JsonKey(name: 'decided_at') this.decidedAt,
  });

  factory _$SquadJoinRequestImpl.fromJson(Map<String, dynamic> json) =>
      _$$SquadJoinRequestImplFromJson(json);

  @override
  final String id;
  @override
  @JsonKey(name: 'squad_id')
  final String squadId;
  @override
  @JsonKey(name: 'user_id')
  final String userId;
  @override
  @JsonKey(name: 'profile_id')
  final String profileId;
  @override
  final String status;
  @override
  final String? message;
  @override
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  @override
  @JsonKey(name: 'decided_at')
  final DateTime? decidedAt;

  @override
  String toString() {
    return 'SquadJoinRequest(id: $id, squadId: $squadId, userId: $userId, profileId: $profileId, status: $status, message: $message, createdAt: $createdAt, decidedAt: $decidedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SquadJoinRequestImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.squadId, squadId) || other.squadId == squadId) &&
            (identical(other.userId, userId) || other.userId == userId) &&
            (identical(other.profileId, profileId) ||
                other.profileId == profileId) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.message, message) || other.message == message) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.decidedAt, decidedAt) ||
                other.decidedAt == decidedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    squadId,
    userId,
    profileId,
    status,
    message,
    createdAt,
    decidedAt,
  );

  /// Create a copy of SquadJoinRequest
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SquadJoinRequestImplCopyWith<_$SquadJoinRequestImpl> get copyWith =>
      __$$SquadJoinRequestImplCopyWithImpl<_$SquadJoinRequestImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$SquadJoinRequestImplToJson(this);
  }
}

abstract class _SquadJoinRequest implements SquadJoinRequest {
  const factory _SquadJoinRequest({
    required final String id,
    @JsonKey(name: 'squad_id') required final String squadId,
    @JsonKey(name: 'user_id') required final String userId,
    @JsonKey(name: 'profile_id') required final String profileId,
    required final String status,
    final String? message,
    @JsonKey(name: 'created_at') required final DateTime createdAt,
    @JsonKey(name: 'decided_at') final DateTime? decidedAt,
  }) = _$SquadJoinRequestImpl;

  factory _SquadJoinRequest.fromJson(Map<String, dynamic> json) =
      _$SquadJoinRequestImpl.fromJson;

  @override
  String get id;
  @override
  @JsonKey(name: 'squad_id')
  String get squadId;
  @override
  @JsonKey(name: 'user_id')
  String get userId;
  @override
  @JsonKey(name: 'profile_id')
  String get profileId;
  @override
  String get status;
  @override
  String? get message;
  @override
  @JsonKey(name: 'created_at')
  DateTime get createdAt;
  @override
  @JsonKey(name: 'decided_at')
  DateTime? get decidedAt;

  /// Create a copy of SquadJoinRequest
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SquadJoinRequestImplCopyWith<_$SquadJoinRequestImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
