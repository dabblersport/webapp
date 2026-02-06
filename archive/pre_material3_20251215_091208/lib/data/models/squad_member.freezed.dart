// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'squad_member.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

SquadMember _$SquadMemberFromJson(Map<String, dynamic> json) {
  return _SquadMember.fromJson(json);
}

/// @nodoc
mixin _$SquadMember {
  @JsonKey(name: 'squad_id')
  String get squadId => throw _privateConstructorUsedError;
  @JsonKey(name: 'profile_id')
  String get profileId => throw _privateConstructorUsedError;
  @JsonKey(name: 'user_id')
  String get userId => throw _privateConstructorUsedError;
  String get role => throw _privateConstructorUsedError;
  @JsonKey(name: 'joined_at')
  DateTime get joinedAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'left_at')
  DateTime? get leftAt => throw _privateConstructorUsedError;
  String get status => throw _privateConstructorUsedError;

  /// Serializes this SquadMember to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of SquadMember
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SquadMemberCopyWith<SquadMember> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SquadMemberCopyWith<$Res> {
  factory $SquadMemberCopyWith(
    SquadMember value,
    $Res Function(SquadMember) then,
  ) = _$SquadMemberCopyWithImpl<$Res, SquadMember>;
  @useResult
  $Res call({
    @JsonKey(name: 'squad_id') String squadId,
    @JsonKey(name: 'profile_id') String profileId,
    @JsonKey(name: 'user_id') String userId,
    String role,
    @JsonKey(name: 'joined_at') DateTime joinedAt,
    @JsonKey(name: 'left_at') DateTime? leftAt,
    String status,
  });
}

/// @nodoc
class _$SquadMemberCopyWithImpl<$Res, $Val extends SquadMember>
    implements $SquadMemberCopyWith<$Res> {
  _$SquadMemberCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SquadMember
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? squadId = null,
    Object? profileId = null,
    Object? userId = null,
    Object? role = null,
    Object? joinedAt = null,
    Object? leftAt = freezed,
    Object? status = null,
  }) {
    return _then(
      _value.copyWith(
            squadId: null == squadId
                ? _value.squadId
                : squadId // ignore: cast_nullable_to_non_nullable
                      as String,
            profileId: null == profileId
                ? _value.profileId
                : profileId // ignore: cast_nullable_to_non_nullable
                      as String,
            userId: null == userId
                ? _value.userId
                : userId // ignore: cast_nullable_to_non_nullable
                      as String,
            role: null == role
                ? _value.role
                : role // ignore: cast_nullable_to_non_nullable
                      as String,
            joinedAt: null == joinedAt
                ? _value.joinedAt
                : joinedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            leftAt: freezed == leftAt
                ? _value.leftAt
                : leftAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            status: null == status
                ? _value.status
                : status // ignore: cast_nullable_to_non_nullable
                      as String,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$SquadMemberImplCopyWith<$Res>
    implements $SquadMemberCopyWith<$Res> {
  factory _$$SquadMemberImplCopyWith(
    _$SquadMemberImpl value,
    $Res Function(_$SquadMemberImpl) then,
  ) = __$$SquadMemberImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    @JsonKey(name: 'squad_id') String squadId,
    @JsonKey(name: 'profile_id') String profileId,
    @JsonKey(name: 'user_id') String userId,
    String role,
    @JsonKey(name: 'joined_at') DateTime joinedAt,
    @JsonKey(name: 'left_at') DateTime? leftAt,
    String status,
  });
}

/// @nodoc
class __$$SquadMemberImplCopyWithImpl<$Res>
    extends _$SquadMemberCopyWithImpl<$Res, _$SquadMemberImpl>
    implements _$$SquadMemberImplCopyWith<$Res> {
  __$$SquadMemberImplCopyWithImpl(
    _$SquadMemberImpl _value,
    $Res Function(_$SquadMemberImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of SquadMember
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? squadId = null,
    Object? profileId = null,
    Object? userId = null,
    Object? role = null,
    Object? joinedAt = null,
    Object? leftAt = freezed,
    Object? status = null,
  }) {
    return _then(
      _$SquadMemberImpl(
        squadId: null == squadId
            ? _value.squadId
            : squadId // ignore: cast_nullable_to_non_nullable
                  as String,
        profileId: null == profileId
            ? _value.profileId
            : profileId // ignore: cast_nullable_to_non_nullable
                  as String,
        userId: null == userId
            ? _value.userId
            : userId // ignore: cast_nullable_to_non_nullable
                  as String,
        role: null == role
            ? _value.role
            : role // ignore: cast_nullable_to_non_nullable
                  as String,
        joinedAt: null == joinedAt
            ? _value.joinedAt
            : joinedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        leftAt: freezed == leftAt
            ? _value.leftAt
            : leftAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        status: null == status
            ? _value.status
            : status // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$SquadMemberImpl implements _SquadMember {
  const _$SquadMemberImpl({
    @JsonKey(name: 'squad_id') required this.squadId,
    @JsonKey(name: 'profile_id') required this.profileId,
    @JsonKey(name: 'user_id') required this.userId,
    required this.role,
    @JsonKey(name: 'joined_at') required this.joinedAt,
    @JsonKey(name: 'left_at') this.leftAt,
    required this.status,
  });

  factory _$SquadMemberImpl.fromJson(Map<String, dynamic> json) =>
      _$$SquadMemberImplFromJson(json);

  @override
  @JsonKey(name: 'squad_id')
  final String squadId;
  @override
  @JsonKey(name: 'profile_id')
  final String profileId;
  @override
  @JsonKey(name: 'user_id')
  final String userId;
  @override
  final String role;
  @override
  @JsonKey(name: 'joined_at')
  final DateTime joinedAt;
  @override
  @JsonKey(name: 'left_at')
  final DateTime? leftAt;
  @override
  final String status;

  @override
  String toString() {
    return 'SquadMember(squadId: $squadId, profileId: $profileId, userId: $userId, role: $role, joinedAt: $joinedAt, leftAt: $leftAt, status: $status)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SquadMemberImpl &&
            (identical(other.squadId, squadId) || other.squadId == squadId) &&
            (identical(other.profileId, profileId) ||
                other.profileId == profileId) &&
            (identical(other.userId, userId) || other.userId == userId) &&
            (identical(other.role, role) || other.role == role) &&
            (identical(other.joinedAt, joinedAt) ||
                other.joinedAt == joinedAt) &&
            (identical(other.leftAt, leftAt) || other.leftAt == leftAt) &&
            (identical(other.status, status) || other.status == status));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    squadId,
    profileId,
    userId,
    role,
    joinedAt,
    leftAt,
    status,
  );

  /// Create a copy of SquadMember
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SquadMemberImplCopyWith<_$SquadMemberImpl> get copyWith =>
      __$$SquadMemberImplCopyWithImpl<_$SquadMemberImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$SquadMemberImplToJson(this);
  }
}

abstract class _SquadMember implements SquadMember {
  const factory _SquadMember({
    @JsonKey(name: 'squad_id') required final String squadId,
    @JsonKey(name: 'profile_id') required final String profileId,
    @JsonKey(name: 'user_id') required final String userId,
    required final String role,
    @JsonKey(name: 'joined_at') required final DateTime joinedAt,
    @JsonKey(name: 'left_at') final DateTime? leftAt,
    required final String status,
  }) = _$SquadMemberImpl;

  factory _SquadMember.fromJson(Map<String, dynamic> json) =
      _$SquadMemberImpl.fromJson;

  @override
  @JsonKey(name: 'squad_id')
  String get squadId;
  @override
  @JsonKey(name: 'profile_id')
  String get profileId;
  @override
  @JsonKey(name: 'user_id')
  String get userId;
  @override
  String get role;
  @override
  @JsonKey(name: 'joined_at')
  DateTime get joinedAt;
  @override
  @JsonKey(name: 'left_at')
  DateTime? get leftAt;
  @override
  String get status;

  /// Create a copy of SquadMember
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SquadMemberImplCopyWith<_$SquadMemberImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
