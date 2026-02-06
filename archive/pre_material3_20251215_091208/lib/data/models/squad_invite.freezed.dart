// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'squad_invite.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

SquadInvite _$SquadInviteFromJson(Map<String, dynamic> json) {
  return _SquadInvite.fromJson(json);
}

/// @nodoc
mixin _$SquadInvite {
  String get id => throw _privateConstructorUsedError;
  @JsonKey(name: 'squad_id')
  String get squadId => throw _privateConstructorUsedError;
  @JsonKey(name: 'to_profile_id')
  String get toProfileId => throw _privateConstructorUsedError;
  @JsonKey(name: 'to_user_id')
  String get toUserId => throw _privateConstructorUsedError;
  @JsonKey(name: 'created_by_profile_id')
  String get createdByProfileId => throw _privateConstructorUsedError;
  @JsonKey(name: 'created_at')
  DateTime get createdAt => throw _privateConstructorUsedError;
  String get status => throw _privateConstructorUsedError;
  @JsonKey(name: 'expires_at')
  DateTime? get expiresAt => throw _privateConstructorUsedError;

  /// Serializes this SquadInvite to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of SquadInvite
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SquadInviteCopyWith<SquadInvite> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SquadInviteCopyWith<$Res> {
  factory $SquadInviteCopyWith(
    SquadInvite value,
    $Res Function(SquadInvite) then,
  ) = _$SquadInviteCopyWithImpl<$Res, SquadInvite>;
  @useResult
  $Res call({
    String id,
    @JsonKey(name: 'squad_id') String squadId,
    @JsonKey(name: 'to_profile_id') String toProfileId,
    @JsonKey(name: 'to_user_id') String toUserId,
    @JsonKey(name: 'created_by_profile_id') String createdByProfileId,
    @JsonKey(name: 'created_at') DateTime createdAt,
    String status,
    @JsonKey(name: 'expires_at') DateTime? expiresAt,
  });
}

/// @nodoc
class _$SquadInviteCopyWithImpl<$Res, $Val extends SquadInvite>
    implements $SquadInviteCopyWith<$Res> {
  _$SquadInviteCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SquadInvite
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? squadId = null,
    Object? toProfileId = null,
    Object? toUserId = null,
    Object? createdByProfileId = null,
    Object? createdAt = null,
    Object? status = null,
    Object? expiresAt = freezed,
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
            toProfileId: null == toProfileId
                ? _value.toProfileId
                : toProfileId // ignore: cast_nullable_to_non_nullable
                      as String,
            toUserId: null == toUserId
                ? _value.toUserId
                : toUserId // ignore: cast_nullable_to_non_nullable
                      as String,
            createdByProfileId: null == createdByProfileId
                ? _value.createdByProfileId
                : createdByProfileId // ignore: cast_nullable_to_non_nullable
                      as String,
            createdAt: null == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            status: null == status
                ? _value.status
                : status // ignore: cast_nullable_to_non_nullable
                      as String,
            expiresAt: freezed == expiresAt
                ? _value.expiresAt
                : expiresAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$SquadInviteImplCopyWith<$Res>
    implements $SquadInviteCopyWith<$Res> {
  factory _$$SquadInviteImplCopyWith(
    _$SquadInviteImpl value,
    $Res Function(_$SquadInviteImpl) then,
  ) = __$$SquadInviteImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    @JsonKey(name: 'squad_id') String squadId,
    @JsonKey(name: 'to_profile_id') String toProfileId,
    @JsonKey(name: 'to_user_id') String toUserId,
    @JsonKey(name: 'created_by_profile_id') String createdByProfileId,
    @JsonKey(name: 'created_at') DateTime createdAt,
    String status,
    @JsonKey(name: 'expires_at') DateTime? expiresAt,
  });
}

/// @nodoc
class __$$SquadInviteImplCopyWithImpl<$Res>
    extends _$SquadInviteCopyWithImpl<$Res, _$SquadInviteImpl>
    implements _$$SquadInviteImplCopyWith<$Res> {
  __$$SquadInviteImplCopyWithImpl(
    _$SquadInviteImpl _value,
    $Res Function(_$SquadInviteImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of SquadInvite
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? squadId = null,
    Object? toProfileId = null,
    Object? toUserId = null,
    Object? createdByProfileId = null,
    Object? createdAt = null,
    Object? status = null,
    Object? expiresAt = freezed,
  }) {
    return _then(
      _$SquadInviteImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        squadId: null == squadId
            ? _value.squadId
            : squadId // ignore: cast_nullable_to_non_nullable
                  as String,
        toProfileId: null == toProfileId
            ? _value.toProfileId
            : toProfileId // ignore: cast_nullable_to_non_nullable
                  as String,
        toUserId: null == toUserId
            ? _value.toUserId
            : toUserId // ignore: cast_nullable_to_non_nullable
                  as String,
        createdByProfileId: null == createdByProfileId
            ? _value.createdByProfileId
            : createdByProfileId // ignore: cast_nullable_to_non_nullable
                  as String,
        createdAt: null == createdAt
            ? _value.createdAt
            : createdAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        status: null == status
            ? _value.status
            : status // ignore: cast_nullable_to_non_nullable
                  as String,
        expiresAt: freezed == expiresAt
            ? _value.expiresAt
            : expiresAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$SquadInviteImpl implements _SquadInvite {
  const _$SquadInviteImpl({
    required this.id,
    @JsonKey(name: 'squad_id') required this.squadId,
    @JsonKey(name: 'to_profile_id') required this.toProfileId,
    @JsonKey(name: 'to_user_id') required this.toUserId,
    @JsonKey(name: 'created_by_profile_id') required this.createdByProfileId,
    @JsonKey(name: 'created_at') required this.createdAt,
    required this.status,
    @JsonKey(name: 'expires_at') this.expiresAt,
  });

  factory _$SquadInviteImpl.fromJson(Map<String, dynamic> json) =>
      _$$SquadInviteImplFromJson(json);

  @override
  final String id;
  @override
  @JsonKey(name: 'squad_id')
  final String squadId;
  @override
  @JsonKey(name: 'to_profile_id')
  final String toProfileId;
  @override
  @JsonKey(name: 'to_user_id')
  final String toUserId;
  @override
  @JsonKey(name: 'created_by_profile_id')
  final String createdByProfileId;
  @override
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  @override
  final String status;
  @override
  @JsonKey(name: 'expires_at')
  final DateTime? expiresAt;

  @override
  String toString() {
    return 'SquadInvite(id: $id, squadId: $squadId, toProfileId: $toProfileId, toUserId: $toUserId, createdByProfileId: $createdByProfileId, createdAt: $createdAt, status: $status, expiresAt: $expiresAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SquadInviteImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.squadId, squadId) || other.squadId == squadId) &&
            (identical(other.toProfileId, toProfileId) ||
                other.toProfileId == toProfileId) &&
            (identical(other.toUserId, toUserId) ||
                other.toUserId == toUserId) &&
            (identical(other.createdByProfileId, createdByProfileId) ||
                other.createdByProfileId == createdByProfileId) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.expiresAt, expiresAt) ||
                other.expiresAt == expiresAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    squadId,
    toProfileId,
    toUserId,
    createdByProfileId,
    createdAt,
    status,
    expiresAt,
  );

  /// Create a copy of SquadInvite
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SquadInviteImplCopyWith<_$SquadInviteImpl> get copyWith =>
      __$$SquadInviteImplCopyWithImpl<_$SquadInviteImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$SquadInviteImplToJson(this);
  }
}

abstract class _SquadInvite implements SquadInvite {
  const factory _SquadInvite({
    required final String id,
    @JsonKey(name: 'squad_id') required final String squadId,
    @JsonKey(name: 'to_profile_id') required final String toProfileId,
    @JsonKey(name: 'to_user_id') required final String toUserId,
    @JsonKey(name: 'created_by_profile_id')
    required final String createdByProfileId,
    @JsonKey(name: 'created_at') required final DateTime createdAt,
    required final String status,
    @JsonKey(name: 'expires_at') final DateTime? expiresAt,
  }) = _$SquadInviteImpl;

  factory _SquadInvite.fromJson(Map<String, dynamic> json) =
      _$SquadInviteImpl.fromJson;

  @override
  String get id;
  @override
  @JsonKey(name: 'squad_id')
  String get squadId;
  @override
  @JsonKey(name: 'to_profile_id')
  String get toProfileId;
  @override
  @JsonKey(name: 'to_user_id')
  String get toUserId;
  @override
  @JsonKey(name: 'created_by_profile_id')
  String get createdByProfileId;
  @override
  @JsonKey(name: 'created_at')
  DateTime get createdAt;
  @override
  String get status;
  @override
  @JsonKey(name: 'expires_at')
  DateTime? get expiresAt;

  /// Create a copy of SquadInvite
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SquadInviteImplCopyWith<_$SquadInviteImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
