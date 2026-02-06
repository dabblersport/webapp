// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'sport_profile.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

SportProfile _$SportProfileFromJson(Map<String, dynamic> json) {
  return _SportProfile.fromJson(json);
}

/// @nodoc
mixin _$SportProfile {
  /// Owning user identifier.
  @JsonKey(name: 'user_id')
  String get userId => throw _privateConstructorUsedError;

  /// Unique identifier for the sport.
  @JsonKey(name: 'sport_key')
  String get sportKey => throw _privateConstructorUsedError;

  /// Skill level reported by the user (1..10).
  @JsonKey(name: 'skill_level')
  int get skillLevel => throw _privateConstructorUsedError;

  /// Serializes this SportProfile to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of SportProfile
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SportProfileCopyWith<SportProfile> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SportProfileCopyWith<$Res> {
  factory $SportProfileCopyWith(
    SportProfile value,
    $Res Function(SportProfile) then,
  ) = _$SportProfileCopyWithImpl<$Res, SportProfile>;
  @useResult
  $Res call({
    @JsonKey(name: 'user_id') String userId,
    @JsonKey(name: 'sport_key') String sportKey,
    @JsonKey(name: 'skill_level') int skillLevel,
  });
}

/// @nodoc
class _$SportProfileCopyWithImpl<$Res, $Val extends SportProfile>
    implements $SportProfileCopyWith<$Res> {
  _$SportProfileCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SportProfile
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? userId = null,
    Object? sportKey = null,
    Object? skillLevel = null,
  }) {
    return _then(
      _value.copyWith(
            userId: null == userId
                ? _value.userId
                : userId // ignore: cast_nullable_to_non_nullable
                      as String,
            sportKey: null == sportKey
                ? _value.sportKey
                : sportKey // ignore: cast_nullable_to_non_nullable
                      as String,
            skillLevel: null == skillLevel
                ? _value.skillLevel
                : skillLevel // ignore: cast_nullable_to_non_nullable
                      as int,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$SportProfileImplCopyWith<$Res>
    implements $SportProfileCopyWith<$Res> {
  factory _$$SportProfileImplCopyWith(
    _$SportProfileImpl value,
    $Res Function(_$SportProfileImpl) then,
  ) = __$$SportProfileImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    @JsonKey(name: 'user_id') String userId,
    @JsonKey(name: 'sport_key') String sportKey,
    @JsonKey(name: 'skill_level') int skillLevel,
  });
}

/// @nodoc
class __$$SportProfileImplCopyWithImpl<$Res>
    extends _$SportProfileCopyWithImpl<$Res, _$SportProfileImpl>
    implements _$$SportProfileImplCopyWith<$Res> {
  __$$SportProfileImplCopyWithImpl(
    _$SportProfileImpl _value,
    $Res Function(_$SportProfileImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of SportProfile
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? userId = null,
    Object? sportKey = null,
    Object? skillLevel = null,
  }) {
    return _then(
      _$SportProfileImpl(
        userId: null == userId
            ? _value.userId
            : userId // ignore: cast_nullable_to_non_nullable
                  as String,
        sportKey: null == sportKey
            ? _value.sportKey
            : sportKey // ignore: cast_nullable_to_non_nullable
                  as String,
        skillLevel: null == skillLevel
            ? _value.skillLevel
            : skillLevel // ignore: cast_nullable_to_non_nullable
                  as int,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$SportProfileImpl implements _SportProfile {
  const _$SportProfileImpl({
    @JsonKey(name: 'user_id') required this.userId,
    @JsonKey(name: 'sport_key') required this.sportKey,
    @JsonKey(name: 'skill_level') required this.skillLevel,
  });

  factory _$SportProfileImpl.fromJson(Map<String, dynamic> json) =>
      _$$SportProfileImplFromJson(json);

  /// Owning user identifier.
  @override
  @JsonKey(name: 'user_id')
  final String userId;

  /// Unique identifier for the sport.
  @override
  @JsonKey(name: 'sport_key')
  final String sportKey;

  /// Skill level reported by the user (1..10).
  @override
  @JsonKey(name: 'skill_level')
  final int skillLevel;

  @override
  String toString() {
    return 'SportProfile(userId: $userId, sportKey: $sportKey, skillLevel: $skillLevel)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SportProfileImpl &&
            (identical(other.userId, userId) || other.userId == userId) &&
            (identical(other.sportKey, sportKey) ||
                other.sportKey == sportKey) &&
            (identical(other.skillLevel, skillLevel) ||
                other.skillLevel == skillLevel));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, userId, sportKey, skillLevel);

  /// Create a copy of SportProfile
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SportProfileImplCopyWith<_$SportProfileImpl> get copyWith =>
      __$$SportProfileImplCopyWithImpl<_$SportProfileImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$SportProfileImplToJson(this);
  }
}

abstract class _SportProfile implements SportProfile {
  const factory _SportProfile({
    @JsonKey(name: 'user_id') required final String userId,
    @JsonKey(name: 'sport_key') required final String sportKey,
    @JsonKey(name: 'skill_level') required final int skillLevel,
  }) = _$SportProfileImpl;

  factory _SportProfile.fromJson(Map<String, dynamic> json) =
      _$SportProfileImpl.fromJson;

  /// Owning user identifier.
  @override
  @JsonKey(name: 'user_id')
  String get userId;

  /// Unique identifier for the sport.
  @override
  @JsonKey(name: 'sport_key')
  String get sportKey;

  /// Skill level reported by the user (1..10).
  @override
  @JsonKey(name: 'skill_level')
  int get skillLevel;

  /// Create a copy of SportProfile
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SportProfileImplCopyWith<_$SportProfileImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
