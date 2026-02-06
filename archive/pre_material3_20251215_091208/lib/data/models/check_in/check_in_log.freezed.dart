// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'check_in_log.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

CheckInLog _$CheckInLogFromJson(Map<String, dynamic> json) {
  return _CheckInLog.fromJson(json);
}

/// @nodoc
mixin _$CheckInLog {
  String get id => throw _privateConstructorUsedError;
  @JsonKey(name: 'user_id')
  String get userId => throw _privateConstructorUsedError;
  @JsonKey(name: 'check_in_date')
  DateTime get checkInDate => throw _privateConstructorUsedError;
  @JsonKey(name: 'check_in_timestamp')
  DateTime get checkInTimestamp => throw _privateConstructorUsedError;
  @JsonKey(name: 'streak_at_time')
  int get streakAtTime => throw _privateConstructorUsedError;
  @JsonKey(name: 'device_info')
  Map<String, dynamic>? get deviceInfo => throw _privateConstructorUsedError;

  /// Serializes this CheckInLog to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of CheckInLog
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $CheckInLogCopyWith<CheckInLog> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $CheckInLogCopyWith<$Res> {
  factory $CheckInLogCopyWith(
    CheckInLog value,
    $Res Function(CheckInLog) then,
  ) = _$CheckInLogCopyWithImpl<$Res, CheckInLog>;
  @useResult
  $Res call({
    String id,
    @JsonKey(name: 'user_id') String userId,
    @JsonKey(name: 'check_in_date') DateTime checkInDate,
    @JsonKey(name: 'check_in_timestamp') DateTime checkInTimestamp,
    @JsonKey(name: 'streak_at_time') int streakAtTime,
    @JsonKey(name: 'device_info') Map<String, dynamic>? deviceInfo,
  });
}

/// @nodoc
class _$CheckInLogCopyWithImpl<$Res, $Val extends CheckInLog>
    implements $CheckInLogCopyWith<$Res> {
  _$CheckInLogCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of CheckInLog
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? userId = null,
    Object? checkInDate = null,
    Object? checkInTimestamp = null,
    Object? streakAtTime = null,
    Object? deviceInfo = freezed,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            userId: null == userId
                ? _value.userId
                : userId // ignore: cast_nullable_to_non_nullable
                      as String,
            checkInDate: null == checkInDate
                ? _value.checkInDate
                : checkInDate // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            checkInTimestamp: null == checkInTimestamp
                ? _value.checkInTimestamp
                : checkInTimestamp // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            streakAtTime: null == streakAtTime
                ? _value.streakAtTime
                : streakAtTime // ignore: cast_nullable_to_non_nullable
                      as int,
            deviceInfo: freezed == deviceInfo
                ? _value.deviceInfo
                : deviceInfo // ignore: cast_nullable_to_non_nullable
                      as Map<String, dynamic>?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$CheckInLogImplCopyWith<$Res>
    implements $CheckInLogCopyWith<$Res> {
  factory _$$CheckInLogImplCopyWith(
    _$CheckInLogImpl value,
    $Res Function(_$CheckInLogImpl) then,
  ) = __$$CheckInLogImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    @JsonKey(name: 'user_id') String userId,
    @JsonKey(name: 'check_in_date') DateTime checkInDate,
    @JsonKey(name: 'check_in_timestamp') DateTime checkInTimestamp,
    @JsonKey(name: 'streak_at_time') int streakAtTime,
    @JsonKey(name: 'device_info') Map<String, dynamic>? deviceInfo,
  });
}

/// @nodoc
class __$$CheckInLogImplCopyWithImpl<$Res>
    extends _$CheckInLogCopyWithImpl<$Res, _$CheckInLogImpl>
    implements _$$CheckInLogImplCopyWith<$Res> {
  __$$CheckInLogImplCopyWithImpl(
    _$CheckInLogImpl _value,
    $Res Function(_$CheckInLogImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of CheckInLog
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? userId = null,
    Object? checkInDate = null,
    Object? checkInTimestamp = null,
    Object? streakAtTime = null,
    Object? deviceInfo = freezed,
  }) {
    return _then(
      _$CheckInLogImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        userId: null == userId
            ? _value.userId
            : userId // ignore: cast_nullable_to_non_nullable
                  as String,
        checkInDate: null == checkInDate
            ? _value.checkInDate
            : checkInDate // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        checkInTimestamp: null == checkInTimestamp
            ? _value.checkInTimestamp
            : checkInTimestamp // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        streakAtTime: null == streakAtTime
            ? _value.streakAtTime
            : streakAtTime // ignore: cast_nullable_to_non_nullable
                  as int,
        deviceInfo: freezed == deviceInfo
            ? _value._deviceInfo
            : deviceInfo // ignore: cast_nullable_to_non_nullable
                  as Map<String, dynamic>?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$CheckInLogImpl implements _CheckInLog {
  const _$CheckInLogImpl({
    required this.id,
    @JsonKey(name: 'user_id') required this.userId,
    @JsonKey(name: 'check_in_date') required this.checkInDate,
    @JsonKey(name: 'check_in_timestamp') required this.checkInTimestamp,
    @JsonKey(name: 'streak_at_time') required this.streakAtTime,
    @JsonKey(name: 'device_info') final Map<String, dynamic>? deviceInfo,
  }) : _deviceInfo = deviceInfo;

  factory _$CheckInLogImpl.fromJson(Map<String, dynamic> json) =>
      _$$CheckInLogImplFromJson(json);

  @override
  final String id;
  @override
  @JsonKey(name: 'user_id')
  final String userId;
  @override
  @JsonKey(name: 'check_in_date')
  final DateTime checkInDate;
  @override
  @JsonKey(name: 'check_in_timestamp')
  final DateTime checkInTimestamp;
  @override
  @JsonKey(name: 'streak_at_time')
  final int streakAtTime;
  final Map<String, dynamic>? _deviceInfo;
  @override
  @JsonKey(name: 'device_info')
  Map<String, dynamic>? get deviceInfo {
    final value = _deviceInfo;
    if (value == null) return null;
    if (_deviceInfo is EqualUnmodifiableMapView) return _deviceInfo;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(value);
  }

  @override
  String toString() {
    return 'CheckInLog(id: $id, userId: $userId, checkInDate: $checkInDate, checkInTimestamp: $checkInTimestamp, streakAtTime: $streakAtTime, deviceInfo: $deviceInfo)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$CheckInLogImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.userId, userId) || other.userId == userId) &&
            (identical(other.checkInDate, checkInDate) ||
                other.checkInDate == checkInDate) &&
            (identical(other.checkInTimestamp, checkInTimestamp) ||
                other.checkInTimestamp == checkInTimestamp) &&
            (identical(other.streakAtTime, streakAtTime) ||
                other.streakAtTime == streakAtTime) &&
            const DeepCollectionEquality().equals(
              other._deviceInfo,
              _deviceInfo,
            ));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    userId,
    checkInDate,
    checkInTimestamp,
    streakAtTime,
    const DeepCollectionEquality().hash(_deviceInfo),
  );

  /// Create a copy of CheckInLog
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$CheckInLogImplCopyWith<_$CheckInLogImpl> get copyWith =>
      __$$CheckInLogImplCopyWithImpl<_$CheckInLogImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$CheckInLogImplToJson(this);
  }
}

abstract class _CheckInLog implements CheckInLog {
  const factory _CheckInLog({
    required final String id,
    @JsonKey(name: 'user_id') required final String userId,
    @JsonKey(name: 'check_in_date') required final DateTime checkInDate,
    @JsonKey(name: 'check_in_timestamp')
    required final DateTime checkInTimestamp,
    @JsonKey(name: 'streak_at_time') required final int streakAtTime,
    @JsonKey(name: 'device_info') final Map<String, dynamic>? deviceInfo,
  }) = _$CheckInLogImpl;

  factory _CheckInLog.fromJson(Map<String, dynamic> json) =
      _$CheckInLogImpl.fromJson;

  @override
  String get id;
  @override
  @JsonKey(name: 'user_id')
  String get userId;
  @override
  @JsonKey(name: 'check_in_date')
  DateTime get checkInDate;
  @override
  @JsonKey(name: 'check_in_timestamp')
  DateTime get checkInTimestamp;
  @override
  @JsonKey(name: 'streak_at_time')
  int get streakAtTime;
  @override
  @JsonKey(name: 'device_info')
  Map<String, dynamic>? get deviceInfo;

  /// Create a copy of CheckInLog
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$CheckInLogImplCopyWith<_$CheckInLogImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
