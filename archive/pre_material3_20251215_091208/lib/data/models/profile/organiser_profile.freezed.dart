// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'organiser_profile.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

OrganiserProfile _$OrganiserProfileFromJson(Map<String, dynamic> json) {
  return _OrganiserProfile.fromJson(json);
}

/// @nodoc
mixin _$OrganiserProfile {
  String get id => throw _privateConstructorUsedError;
  @JsonKey(name: 'profile_id')
  String get profileId => throw _privateConstructorUsedError; // FK to profiles.id
  String get sport => throw _privateConstructorUsedError;
  @JsonKey(name: 'organiser_level')
  int get organiserLevel => throw _privateConstructorUsedError;
  @JsonKey(name: 'commission_type')
  String get commissionType => throw _privateConstructorUsedError;
  @JsonKey(name: 'commission_value')
  double get commissionValue => throw _privateConstructorUsedError;
  @JsonKey(name: 'is_verified')
  bool get isVerified => throw _privateConstructorUsedError;
  @JsonKey(name: 'is_active')
  bool get isActive => throw _privateConstructorUsedError;
  @JsonKey(name: 'created_at')
  DateTime get createdAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'updated_at')
  DateTime get updatedAt => throw _privateConstructorUsedError;

  /// Serializes this OrganiserProfile to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of OrganiserProfile
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $OrganiserProfileCopyWith<OrganiserProfile> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $OrganiserProfileCopyWith<$Res> {
  factory $OrganiserProfileCopyWith(
    OrganiserProfile value,
    $Res Function(OrganiserProfile) then,
  ) = _$OrganiserProfileCopyWithImpl<$Res, OrganiserProfile>;
  @useResult
  $Res call({
    String id,
    @JsonKey(name: 'profile_id') String profileId,
    String sport,
    @JsonKey(name: 'organiser_level') int organiserLevel,
    @JsonKey(name: 'commission_type') String commissionType,
    @JsonKey(name: 'commission_value') double commissionValue,
    @JsonKey(name: 'is_verified') bool isVerified,
    @JsonKey(name: 'is_active') bool isActive,
    @JsonKey(name: 'created_at') DateTime createdAt,
    @JsonKey(name: 'updated_at') DateTime updatedAt,
  });
}

/// @nodoc
class _$OrganiserProfileCopyWithImpl<$Res, $Val extends OrganiserProfile>
    implements $OrganiserProfileCopyWith<$Res> {
  _$OrganiserProfileCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of OrganiserProfile
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? profileId = null,
    Object? sport = null,
    Object? organiserLevel = null,
    Object? commissionType = null,
    Object? commissionValue = null,
    Object? isVerified = null,
    Object? isActive = null,
    Object? createdAt = null,
    Object? updatedAt = null,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            profileId: null == profileId
                ? _value.profileId
                : profileId // ignore: cast_nullable_to_non_nullable
                      as String,
            sport: null == sport
                ? _value.sport
                : sport // ignore: cast_nullable_to_non_nullable
                      as String,
            organiserLevel: null == organiserLevel
                ? _value.organiserLevel
                : organiserLevel // ignore: cast_nullable_to_non_nullable
                      as int,
            commissionType: null == commissionType
                ? _value.commissionType
                : commissionType // ignore: cast_nullable_to_non_nullable
                      as String,
            commissionValue: null == commissionValue
                ? _value.commissionValue
                : commissionValue // ignore: cast_nullable_to_non_nullable
                      as double,
            isVerified: null == isVerified
                ? _value.isVerified
                : isVerified // ignore: cast_nullable_to_non_nullable
                      as bool,
            isActive: null == isActive
                ? _value.isActive
                : isActive // ignore: cast_nullable_to_non_nullable
                      as bool,
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
abstract class _$$OrganiserProfileImplCopyWith<$Res>
    implements $OrganiserProfileCopyWith<$Res> {
  factory _$$OrganiserProfileImplCopyWith(
    _$OrganiserProfileImpl value,
    $Res Function(_$OrganiserProfileImpl) then,
  ) = __$$OrganiserProfileImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    @JsonKey(name: 'profile_id') String profileId,
    String sport,
    @JsonKey(name: 'organiser_level') int organiserLevel,
    @JsonKey(name: 'commission_type') String commissionType,
    @JsonKey(name: 'commission_value') double commissionValue,
    @JsonKey(name: 'is_verified') bool isVerified,
    @JsonKey(name: 'is_active') bool isActive,
    @JsonKey(name: 'created_at') DateTime createdAt,
    @JsonKey(name: 'updated_at') DateTime updatedAt,
  });
}

/// @nodoc
class __$$OrganiserProfileImplCopyWithImpl<$Res>
    extends _$OrganiserProfileCopyWithImpl<$Res, _$OrganiserProfileImpl>
    implements _$$OrganiserProfileImplCopyWith<$Res> {
  __$$OrganiserProfileImplCopyWithImpl(
    _$OrganiserProfileImpl _value,
    $Res Function(_$OrganiserProfileImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of OrganiserProfile
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? profileId = null,
    Object? sport = null,
    Object? organiserLevel = null,
    Object? commissionType = null,
    Object? commissionValue = null,
    Object? isVerified = null,
    Object? isActive = null,
    Object? createdAt = null,
    Object? updatedAt = null,
  }) {
    return _then(
      _$OrganiserProfileImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        profileId: null == profileId
            ? _value.profileId
            : profileId // ignore: cast_nullable_to_non_nullable
                  as String,
        sport: null == sport
            ? _value.sport
            : sport // ignore: cast_nullable_to_non_nullable
                  as String,
        organiserLevel: null == organiserLevel
            ? _value.organiserLevel
            : organiserLevel // ignore: cast_nullable_to_non_nullable
                  as int,
        commissionType: null == commissionType
            ? _value.commissionType
            : commissionType // ignore: cast_nullable_to_non_nullable
                  as String,
        commissionValue: null == commissionValue
            ? _value.commissionValue
            : commissionValue // ignore: cast_nullable_to_non_nullable
                  as double,
        isVerified: null == isVerified
            ? _value.isVerified
            : isVerified // ignore: cast_nullable_to_non_nullable
                  as bool,
        isActive: null == isActive
            ? _value.isActive
            : isActive // ignore: cast_nullable_to_non_nullable
                  as bool,
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
class _$OrganiserProfileImpl implements _OrganiserProfile {
  const _$OrganiserProfileImpl({
    required this.id,
    @JsonKey(name: 'profile_id') required this.profileId,
    required this.sport,
    @JsonKey(name: 'organiser_level') this.organiserLevel = 1,
    @JsonKey(name: 'commission_type') this.commissionType = 'percent',
    @JsonKey(name: 'commission_value') this.commissionValue = 0.0,
    @JsonKey(name: 'is_verified') this.isVerified = false,
    @JsonKey(name: 'is_active') this.isActive = true,
    @JsonKey(name: 'created_at') required this.createdAt,
    @JsonKey(name: 'updated_at') required this.updatedAt,
  });

  factory _$OrganiserProfileImpl.fromJson(Map<String, dynamic> json) =>
      _$$OrganiserProfileImplFromJson(json);

  @override
  final String id;
  @override
  @JsonKey(name: 'profile_id')
  final String profileId;
  // FK to profiles.id
  @override
  final String sport;
  @override
  @JsonKey(name: 'organiser_level')
  final int organiserLevel;
  @override
  @JsonKey(name: 'commission_type')
  final String commissionType;
  @override
  @JsonKey(name: 'commission_value')
  final double commissionValue;
  @override
  @JsonKey(name: 'is_verified')
  final bool isVerified;
  @override
  @JsonKey(name: 'is_active')
  final bool isActive;
  @override
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  @override
  @JsonKey(name: 'updated_at')
  final DateTime updatedAt;

  @override
  String toString() {
    return 'OrganiserProfile(id: $id, profileId: $profileId, sport: $sport, organiserLevel: $organiserLevel, commissionType: $commissionType, commissionValue: $commissionValue, isVerified: $isVerified, isActive: $isActive, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$OrganiserProfileImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.profileId, profileId) ||
                other.profileId == profileId) &&
            (identical(other.sport, sport) || other.sport == sport) &&
            (identical(other.organiserLevel, organiserLevel) ||
                other.organiserLevel == organiserLevel) &&
            (identical(other.commissionType, commissionType) ||
                other.commissionType == commissionType) &&
            (identical(other.commissionValue, commissionValue) ||
                other.commissionValue == commissionValue) &&
            (identical(other.isVerified, isVerified) ||
                other.isVerified == isVerified) &&
            (identical(other.isActive, isActive) ||
                other.isActive == isActive) &&
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
    profileId,
    sport,
    organiserLevel,
    commissionType,
    commissionValue,
    isVerified,
    isActive,
    createdAt,
    updatedAt,
  );

  /// Create a copy of OrganiserProfile
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$OrganiserProfileImplCopyWith<_$OrganiserProfileImpl> get copyWith =>
      __$$OrganiserProfileImplCopyWithImpl<_$OrganiserProfileImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$OrganiserProfileImplToJson(this);
  }
}

abstract class _OrganiserProfile implements OrganiserProfile {
  const factory _OrganiserProfile({
    required final String id,
    @JsonKey(name: 'profile_id') required final String profileId,
    required final String sport,
    @JsonKey(name: 'organiser_level') final int organiserLevel,
    @JsonKey(name: 'commission_type') final String commissionType,
    @JsonKey(name: 'commission_value') final double commissionValue,
    @JsonKey(name: 'is_verified') final bool isVerified,
    @JsonKey(name: 'is_active') final bool isActive,
    @JsonKey(name: 'created_at') required final DateTime createdAt,
    @JsonKey(name: 'updated_at') required final DateTime updatedAt,
  }) = _$OrganiserProfileImpl;

  factory _OrganiserProfile.fromJson(Map<String, dynamic> json) =
      _$OrganiserProfileImpl.fromJson;

  @override
  String get id;
  @override
  @JsonKey(name: 'profile_id')
  String get profileId; // FK to profiles.id
  @override
  String get sport;
  @override
  @JsonKey(name: 'organiser_level')
  int get organiserLevel;
  @override
  @JsonKey(name: 'commission_type')
  String get commissionType;
  @override
  @JsonKey(name: 'commission_value')
  double get commissionValue;
  @override
  @JsonKey(name: 'is_verified')
  bool get isVerified;
  @override
  @JsonKey(name: 'is_active')
  bool get isActive;
  @override
  @JsonKey(name: 'created_at')
  DateTime get createdAt;
  @override
  @JsonKey(name: 'updated_at')
  DateTime get updatedAt;

  /// Create a copy of OrganiserProfile
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$OrganiserProfileImplCopyWith<_$OrganiserProfileImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
