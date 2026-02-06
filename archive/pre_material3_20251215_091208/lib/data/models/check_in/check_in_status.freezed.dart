// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'check_in_status.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

CheckInStatus _$CheckInStatusFromJson(Map<String, dynamic> json) {
  return _CheckInStatus.fromJson(json);
}

/// @nodoc
mixin _$CheckInStatus {
  @JsonKey(name: 'user_id')
  String get userId => throw _privateConstructorUsedError;
  @JsonKey(name: 'last_check_in')
  DateTime get lastCheckIn => throw _privateConstructorUsedError;
  @JsonKey(name: 'streak_count')
  int get streakCount => throw _privateConstructorUsedError;
  @JsonKey(name: 'total_days_completed')
  int get totalDaysCompleted => throw _privateConstructorUsedError;
  @JsonKey(name: 'is_completed')
  bool get isCompleted => throw _privateConstructorUsedError;
  @JsonKey(name: 'badge_awarded_at')
  DateTime? get badgeAwardedAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'created_at')
  DateTime get createdAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'updated_at')
  DateTime get updatedAt => throw _privateConstructorUsedError;

  /// Serializes this CheckInStatus to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of CheckInStatus
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $CheckInStatusCopyWith<CheckInStatus> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $CheckInStatusCopyWith<$Res> {
  factory $CheckInStatusCopyWith(
    CheckInStatus value,
    $Res Function(CheckInStatus) then,
  ) = _$CheckInStatusCopyWithImpl<$Res, CheckInStatus>;
  @useResult
  $Res call({
    @JsonKey(name: 'user_id') String userId,
    @JsonKey(name: 'last_check_in') DateTime lastCheckIn,
    @JsonKey(name: 'streak_count') int streakCount,
    @JsonKey(name: 'total_days_completed') int totalDaysCompleted,
    @JsonKey(name: 'is_completed') bool isCompleted,
    @JsonKey(name: 'badge_awarded_at') DateTime? badgeAwardedAt,
    @JsonKey(name: 'created_at') DateTime createdAt,
    @JsonKey(name: 'updated_at') DateTime updatedAt,
  });
}

/// @nodoc
class _$CheckInStatusCopyWithImpl<$Res, $Val extends CheckInStatus>
    implements $CheckInStatusCopyWith<$Res> {
  _$CheckInStatusCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of CheckInStatus
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? userId = null,
    Object? lastCheckIn = null,
    Object? streakCount = null,
    Object? totalDaysCompleted = null,
    Object? isCompleted = null,
    Object? badgeAwardedAt = freezed,
    Object? createdAt = null,
    Object? updatedAt = null,
  }) {
    return _then(
      _value.copyWith(
            userId: null == userId
                ? _value.userId
                : userId // ignore: cast_nullable_to_non_nullable
                      as String,
            lastCheckIn: null == lastCheckIn
                ? _value.lastCheckIn
                : lastCheckIn // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            streakCount: null == streakCount
                ? _value.streakCount
                : streakCount // ignore: cast_nullable_to_non_nullable
                      as int,
            totalDaysCompleted: null == totalDaysCompleted
                ? _value.totalDaysCompleted
                : totalDaysCompleted // ignore: cast_nullable_to_non_nullable
                      as int,
            isCompleted: null == isCompleted
                ? _value.isCompleted
                : isCompleted // ignore: cast_nullable_to_non_nullable
                      as bool,
            badgeAwardedAt: freezed == badgeAwardedAt
                ? _value.badgeAwardedAt
                : badgeAwardedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
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
abstract class _$$CheckInStatusImplCopyWith<$Res>
    implements $CheckInStatusCopyWith<$Res> {
  factory _$$CheckInStatusImplCopyWith(
    _$CheckInStatusImpl value,
    $Res Function(_$CheckInStatusImpl) then,
  ) = __$$CheckInStatusImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    @JsonKey(name: 'user_id') String userId,
    @JsonKey(name: 'last_check_in') DateTime lastCheckIn,
    @JsonKey(name: 'streak_count') int streakCount,
    @JsonKey(name: 'total_days_completed') int totalDaysCompleted,
    @JsonKey(name: 'is_completed') bool isCompleted,
    @JsonKey(name: 'badge_awarded_at') DateTime? badgeAwardedAt,
    @JsonKey(name: 'created_at') DateTime createdAt,
    @JsonKey(name: 'updated_at') DateTime updatedAt,
  });
}

/// @nodoc
class __$$CheckInStatusImplCopyWithImpl<$Res>
    extends _$CheckInStatusCopyWithImpl<$Res, _$CheckInStatusImpl>
    implements _$$CheckInStatusImplCopyWith<$Res> {
  __$$CheckInStatusImplCopyWithImpl(
    _$CheckInStatusImpl _value,
    $Res Function(_$CheckInStatusImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of CheckInStatus
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? userId = null,
    Object? lastCheckIn = null,
    Object? streakCount = null,
    Object? totalDaysCompleted = null,
    Object? isCompleted = null,
    Object? badgeAwardedAt = freezed,
    Object? createdAt = null,
    Object? updatedAt = null,
  }) {
    return _then(
      _$CheckInStatusImpl(
        userId: null == userId
            ? _value.userId
            : userId // ignore: cast_nullable_to_non_nullable
                  as String,
        lastCheckIn: null == lastCheckIn
            ? _value.lastCheckIn
            : lastCheckIn // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        streakCount: null == streakCount
            ? _value.streakCount
            : streakCount // ignore: cast_nullable_to_non_nullable
                  as int,
        totalDaysCompleted: null == totalDaysCompleted
            ? _value.totalDaysCompleted
            : totalDaysCompleted // ignore: cast_nullable_to_non_nullable
                  as int,
        isCompleted: null == isCompleted
            ? _value.isCompleted
            : isCompleted // ignore: cast_nullable_to_non_nullable
                  as bool,
        badgeAwardedAt: freezed == badgeAwardedAt
            ? _value.badgeAwardedAt
            : badgeAwardedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
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
class _$CheckInStatusImpl implements _CheckInStatus {
  const _$CheckInStatusImpl({
    @JsonKey(name: 'user_id') required this.userId,
    @JsonKey(name: 'last_check_in') required this.lastCheckIn,
    @JsonKey(name: 'streak_count') required this.streakCount,
    @JsonKey(name: 'total_days_completed') required this.totalDaysCompleted,
    @JsonKey(name: 'is_completed') required this.isCompleted,
    @JsonKey(name: 'badge_awarded_at') this.badgeAwardedAt,
    @JsonKey(name: 'created_at') required this.createdAt,
    @JsonKey(name: 'updated_at') required this.updatedAt,
  });

  factory _$CheckInStatusImpl.fromJson(Map<String, dynamic> json) =>
      _$$CheckInStatusImplFromJson(json);

  @override
  @JsonKey(name: 'user_id')
  final String userId;
  @override
  @JsonKey(name: 'last_check_in')
  final DateTime lastCheckIn;
  @override
  @JsonKey(name: 'streak_count')
  final int streakCount;
  @override
  @JsonKey(name: 'total_days_completed')
  final int totalDaysCompleted;
  @override
  @JsonKey(name: 'is_completed')
  final bool isCompleted;
  @override
  @JsonKey(name: 'badge_awarded_at')
  final DateTime? badgeAwardedAt;
  @override
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  @override
  @JsonKey(name: 'updated_at')
  final DateTime updatedAt;

  @override
  String toString() {
    return 'CheckInStatus(userId: $userId, lastCheckIn: $lastCheckIn, streakCount: $streakCount, totalDaysCompleted: $totalDaysCompleted, isCompleted: $isCompleted, badgeAwardedAt: $badgeAwardedAt, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$CheckInStatusImpl &&
            (identical(other.userId, userId) || other.userId == userId) &&
            (identical(other.lastCheckIn, lastCheckIn) ||
                other.lastCheckIn == lastCheckIn) &&
            (identical(other.streakCount, streakCount) ||
                other.streakCount == streakCount) &&
            (identical(other.totalDaysCompleted, totalDaysCompleted) ||
                other.totalDaysCompleted == totalDaysCompleted) &&
            (identical(other.isCompleted, isCompleted) ||
                other.isCompleted == isCompleted) &&
            (identical(other.badgeAwardedAt, badgeAwardedAt) ||
                other.badgeAwardedAt == badgeAwardedAt) &&
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
    lastCheckIn,
    streakCount,
    totalDaysCompleted,
    isCompleted,
    badgeAwardedAt,
    createdAt,
    updatedAt,
  );

  /// Create a copy of CheckInStatus
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$CheckInStatusImplCopyWith<_$CheckInStatusImpl> get copyWith =>
      __$$CheckInStatusImplCopyWithImpl<_$CheckInStatusImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$CheckInStatusImplToJson(this);
  }
}

abstract class _CheckInStatus implements CheckInStatus {
  const factory _CheckInStatus({
    @JsonKey(name: 'user_id') required final String userId,
    @JsonKey(name: 'last_check_in') required final DateTime lastCheckIn,
    @JsonKey(name: 'streak_count') required final int streakCount,
    @JsonKey(name: 'total_days_completed')
    required final int totalDaysCompleted,
    @JsonKey(name: 'is_completed') required final bool isCompleted,
    @JsonKey(name: 'badge_awarded_at') final DateTime? badgeAwardedAt,
    @JsonKey(name: 'created_at') required final DateTime createdAt,
    @JsonKey(name: 'updated_at') required final DateTime updatedAt,
  }) = _$CheckInStatusImpl;

  factory _CheckInStatus.fromJson(Map<String, dynamic> json) =
      _$CheckInStatusImpl.fromJson;

  @override
  @JsonKey(name: 'user_id')
  String get userId;
  @override
  @JsonKey(name: 'last_check_in')
  DateTime get lastCheckIn;
  @override
  @JsonKey(name: 'streak_count')
  int get streakCount;
  @override
  @JsonKey(name: 'total_days_completed')
  int get totalDaysCompleted;
  @override
  @JsonKey(name: 'is_completed')
  bool get isCompleted;
  @override
  @JsonKey(name: 'badge_awarded_at')
  DateTime? get badgeAwardedAt;
  @override
  @JsonKey(name: 'created_at')
  DateTime get createdAt;
  @override
  @JsonKey(name: 'updated_at')
  DateTime get updatedAt;

  /// Create a copy of CheckInStatus
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$CheckInStatusImplCopyWith<_$CheckInStatusImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

CheckInResponse _$CheckInResponseFromJson(Map<String, dynamic> json) {
  return _CheckInResponse.fromJson(json);
}

/// @nodoc
mixin _$CheckInResponse {
  bool get success => throw _privateConstructorUsedError;
  String get message => throw _privateConstructorUsedError;
  @JsonKey(name: 'streak_count')
  int get streakCount => throw _privateConstructorUsedError;
  @JsonKey(name: 'total_days_completed')
  int get totalDaysCompleted => throw _privateConstructorUsedError;
  @JsonKey(name: 'is_completed')
  bool get isCompleted => throw _privateConstructorUsedError;
  @JsonKey(name: 'is_first_check_in_today')
  bool get isFirstCheckInToday => throw _privateConstructorUsedError;

  /// Serializes this CheckInResponse to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of CheckInResponse
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $CheckInResponseCopyWith<CheckInResponse> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $CheckInResponseCopyWith<$Res> {
  factory $CheckInResponseCopyWith(
    CheckInResponse value,
    $Res Function(CheckInResponse) then,
  ) = _$CheckInResponseCopyWithImpl<$Res, CheckInResponse>;
  @useResult
  $Res call({
    bool success,
    String message,
    @JsonKey(name: 'streak_count') int streakCount,
    @JsonKey(name: 'total_days_completed') int totalDaysCompleted,
    @JsonKey(name: 'is_completed') bool isCompleted,
    @JsonKey(name: 'is_first_check_in_today') bool isFirstCheckInToday,
  });
}

/// @nodoc
class _$CheckInResponseCopyWithImpl<$Res, $Val extends CheckInResponse>
    implements $CheckInResponseCopyWith<$Res> {
  _$CheckInResponseCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of CheckInResponse
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? success = null,
    Object? message = null,
    Object? streakCount = null,
    Object? totalDaysCompleted = null,
    Object? isCompleted = null,
    Object? isFirstCheckInToday = null,
  }) {
    return _then(
      _value.copyWith(
            success: null == success
                ? _value.success
                : success // ignore: cast_nullable_to_non_nullable
                      as bool,
            message: null == message
                ? _value.message
                : message // ignore: cast_nullable_to_non_nullable
                      as String,
            streakCount: null == streakCount
                ? _value.streakCount
                : streakCount // ignore: cast_nullable_to_non_nullable
                      as int,
            totalDaysCompleted: null == totalDaysCompleted
                ? _value.totalDaysCompleted
                : totalDaysCompleted // ignore: cast_nullable_to_non_nullable
                      as int,
            isCompleted: null == isCompleted
                ? _value.isCompleted
                : isCompleted // ignore: cast_nullable_to_non_nullable
                      as bool,
            isFirstCheckInToday: null == isFirstCheckInToday
                ? _value.isFirstCheckInToday
                : isFirstCheckInToday // ignore: cast_nullable_to_non_nullable
                      as bool,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$CheckInResponseImplCopyWith<$Res>
    implements $CheckInResponseCopyWith<$Res> {
  factory _$$CheckInResponseImplCopyWith(
    _$CheckInResponseImpl value,
    $Res Function(_$CheckInResponseImpl) then,
  ) = __$$CheckInResponseImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    bool success,
    String message,
    @JsonKey(name: 'streak_count') int streakCount,
    @JsonKey(name: 'total_days_completed') int totalDaysCompleted,
    @JsonKey(name: 'is_completed') bool isCompleted,
    @JsonKey(name: 'is_first_check_in_today') bool isFirstCheckInToday,
  });
}

/// @nodoc
class __$$CheckInResponseImplCopyWithImpl<$Res>
    extends _$CheckInResponseCopyWithImpl<$Res, _$CheckInResponseImpl>
    implements _$$CheckInResponseImplCopyWith<$Res> {
  __$$CheckInResponseImplCopyWithImpl(
    _$CheckInResponseImpl _value,
    $Res Function(_$CheckInResponseImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of CheckInResponse
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? success = null,
    Object? message = null,
    Object? streakCount = null,
    Object? totalDaysCompleted = null,
    Object? isCompleted = null,
    Object? isFirstCheckInToday = null,
  }) {
    return _then(
      _$CheckInResponseImpl(
        success: null == success
            ? _value.success
            : success // ignore: cast_nullable_to_non_nullable
                  as bool,
        message: null == message
            ? _value.message
            : message // ignore: cast_nullable_to_non_nullable
                  as String,
        streakCount: null == streakCount
            ? _value.streakCount
            : streakCount // ignore: cast_nullable_to_non_nullable
                  as int,
        totalDaysCompleted: null == totalDaysCompleted
            ? _value.totalDaysCompleted
            : totalDaysCompleted // ignore: cast_nullable_to_non_nullable
                  as int,
        isCompleted: null == isCompleted
            ? _value.isCompleted
            : isCompleted // ignore: cast_nullable_to_non_nullable
                  as bool,
        isFirstCheckInToday: null == isFirstCheckInToday
            ? _value.isFirstCheckInToday
            : isFirstCheckInToday // ignore: cast_nullable_to_non_nullable
                  as bool,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$CheckInResponseImpl implements _CheckInResponse {
  const _$CheckInResponseImpl({
    required this.success,
    required this.message,
    @JsonKey(name: 'streak_count') required this.streakCount,
    @JsonKey(name: 'total_days_completed') required this.totalDaysCompleted,
    @JsonKey(name: 'is_completed') required this.isCompleted,
    @JsonKey(name: 'is_first_check_in_today') required this.isFirstCheckInToday,
  });

  factory _$CheckInResponseImpl.fromJson(Map<String, dynamic> json) =>
      _$$CheckInResponseImplFromJson(json);

  @override
  final bool success;
  @override
  final String message;
  @override
  @JsonKey(name: 'streak_count')
  final int streakCount;
  @override
  @JsonKey(name: 'total_days_completed')
  final int totalDaysCompleted;
  @override
  @JsonKey(name: 'is_completed')
  final bool isCompleted;
  @override
  @JsonKey(name: 'is_first_check_in_today')
  final bool isFirstCheckInToday;

  @override
  String toString() {
    return 'CheckInResponse(success: $success, message: $message, streakCount: $streakCount, totalDaysCompleted: $totalDaysCompleted, isCompleted: $isCompleted, isFirstCheckInToday: $isFirstCheckInToday)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$CheckInResponseImpl &&
            (identical(other.success, success) || other.success == success) &&
            (identical(other.message, message) || other.message == message) &&
            (identical(other.streakCount, streakCount) ||
                other.streakCount == streakCount) &&
            (identical(other.totalDaysCompleted, totalDaysCompleted) ||
                other.totalDaysCompleted == totalDaysCompleted) &&
            (identical(other.isCompleted, isCompleted) ||
                other.isCompleted == isCompleted) &&
            (identical(other.isFirstCheckInToday, isFirstCheckInToday) ||
                other.isFirstCheckInToday == isFirstCheckInToday));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    success,
    message,
    streakCount,
    totalDaysCompleted,
    isCompleted,
    isFirstCheckInToday,
  );

  /// Create a copy of CheckInResponse
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$CheckInResponseImplCopyWith<_$CheckInResponseImpl> get copyWith =>
      __$$CheckInResponseImplCopyWithImpl<_$CheckInResponseImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$CheckInResponseImplToJson(this);
  }
}

abstract class _CheckInResponse implements CheckInResponse {
  const factory _CheckInResponse({
    required final bool success,
    required final String message,
    @JsonKey(name: 'streak_count') required final int streakCount,
    @JsonKey(name: 'total_days_completed')
    required final int totalDaysCompleted,
    @JsonKey(name: 'is_completed') required final bool isCompleted,
    @JsonKey(name: 'is_first_check_in_today')
    required final bool isFirstCheckInToday,
  }) = _$CheckInResponseImpl;

  factory _CheckInResponse.fromJson(Map<String, dynamic> json) =
      _$CheckInResponseImpl.fromJson;

  @override
  bool get success;
  @override
  String get message;
  @override
  @JsonKey(name: 'streak_count')
  int get streakCount;
  @override
  @JsonKey(name: 'total_days_completed')
  int get totalDaysCompleted;
  @override
  @JsonKey(name: 'is_completed')
  bool get isCompleted;
  @override
  @JsonKey(name: 'is_first_check_in_today')
  bool get isFirstCheckInToday;

  /// Create a copy of CheckInResponse
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$CheckInResponseImplCopyWith<_$CheckInResponseImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

CheckInStatusDetail _$CheckInStatusDetailFromJson(Map<String, dynamic> json) {
  return _CheckInStatusDetail.fromJson(json);
}

/// @nodoc
mixin _$CheckInStatusDetail {
  @JsonKey(name: 'streak_count')
  int get streakCount => throw _privateConstructorUsedError;
  @JsonKey(name: 'total_days_completed')
  int get totalDaysCompleted => throw _privateConstructorUsedError;
  @JsonKey(name: 'is_completed')
  bool get isCompleted => throw _privateConstructorUsedError;
  @JsonKey(name: 'last_check_in')
  DateTime? get lastCheckIn => throw _privateConstructorUsedError;
  @JsonKey(name: 'checked_in_today')
  bool get checkedInToday => throw _privateConstructorUsedError;
  @JsonKey(name: 'days_remaining')
  int get daysRemaining => throw _privateConstructorUsedError;

  /// Serializes this CheckInStatusDetail to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of CheckInStatusDetail
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $CheckInStatusDetailCopyWith<CheckInStatusDetail> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $CheckInStatusDetailCopyWith<$Res> {
  factory $CheckInStatusDetailCopyWith(
    CheckInStatusDetail value,
    $Res Function(CheckInStatusDetail) then,
  ) = _$CheckInStatusDetailCopyWithImpl<$Res, CheckInStatusDetail>;
  @useResult
  $Res call({
    @JsonKey(name: 'streak_count') int streakCount,
    @JsonKey(name: 'total_days_completed') int totalDaysCompleted,
    @JsonKey(name: 'is_completed') bool isCompleted,
    @JsonKey(name: 'last_check_in') DateTime? lastCheckIn,
    @JsonKey(name: 'checked_in_today') bool checkedInToday,
    @JsonKey(name: 'days_remaining') int daysRemaining,
  });
}

/// @nodoc
class _$CheckInStatusDetailCopyWithImpl<$Res, $Val extends CheckInStatusDetail>
    implements $CheckInStatusDetailCopyWith<$Res> {
  _$CheckInStatusDetailCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of CheckInStatusDetail
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? streakCount = null,
    Object? totalDaysCompleted = null,
    Object? isCompleted = null,
    Object? lastCheckIn = freezed,
    Object? checkedInToday = null,
    Object? daysRemaining = null,
  }) {
    return _then(
      _value.copyWith(
            streakCount: null == streakCount
                ? _value.streakCount
                : streakCount // ignore: cast_nullable_to_non_nullable
                      as int,
            totalDaysCompleted: null == totalDaysCompleted
                ? _value.totalDaysCompleted
                : totalDaysCompleted // ignore: cast_nullable_to_non_nullable
                      as int,
            isCompleted: null == isCompleted
                ? _value.isCompleted
                : isCompleted // ignore: cast_nullable_to_non_nullable
                      as bool,
            lastCheckIn: freezed == lastCheckIn
                ? _value.lastCheckIn
                : lastCheckIn // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            checkedInToday: null == checkedInToday
                ? _value.checkedInToday
                : checkedInToday // ignore: cast_nullable_to_non_nullable
                      as bool,
            daysRemaining: null == daysRemaining
                ? _value.daysRemaining
                : daysRemaining // ignore: cast_nullable_to_non_nullable
                      as int,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$CheckInStatusDetailImplCopyWith<$Res>
    implements $CheckInStatusDetailCopyWith<$Res> {
  factory _$$CheckInStatusDetailImplCopyWith(
    _$CheckInStatusDetailImpl value,
    $Res Function(_$CheckInStatusDetailImpl) then,
  ) = __$$CheckInStatusDetailImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    @JsonKey(name: 'streak_count') int streakCount,
    @JsonKey(name: 'total_days_completed') int totalDaysCompleted,
    @JsonKey(name: 'is_completed') bool isCompleted,
    @JsonKey(name: 'last_check_in') DateTime? lastCheckIn,
    @JsonKey(name: 'checked_in_today') bool checkedInToday,
    @JsonKey(name: 'days_remaining') int daysRemaining,
  });
}

/// @nodoc
class __$$CheckInStatusDetailImplCopyWithImpl<$Res>
    extends _$CheckInStatusDetailCopyWithImpl<$Res, _$CheckInStatusDetailImpl>
    implements _$$CheckInStatusDetailImplCopyWith<$Res> {
  __$$CheckInStatusDetailImplCopyWithImpl(
    _$CheckInStatusDetailImpl _value,
    $Res Function(_$CheckInStatusDetailImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of CheckInStatusDetail
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? streakCount = null,
    Object? totalDaysCompleted = null,
    Object? isCompleted = null,
    Object? lastCheckIn = freezed,
    Object? checkedInToday = null,
    Object? daysRemaining = null,
  }) {
    return _then(
      _$CheckInStatusDetailImpl(
        streakCount: null == streakCount
            ? _value.streakCount
            : streakCount // ignore: cast_nullable_to_non_nullable
                  as int,
        totalDaysCompleted: null == totalDaysCompleted
            ? _value.totalDaysCompleted
            : totalDaysCompleted // ignore: cast_nullable_to_non_nullable
                  as int,
        isCompleted: null == isCompleted
            ? _value.isCompleted
            : isCompleted // ignore: cast_nullable_to_non_nullable
                  as bool,
        lastCheckIn: freezed == lastCheckIn
            ? _value.lastCheckIn
            : lastCheckIn // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        checkedInToday: null == checkedInToday
            ? _value.checkedInToday
            : checkedInToday // ignore: cast_nullable_to_non_nullable
                  as bool,
        daysRemaining: null == daysRemaining
            ? _value.daysRemaining
            : daysRemaining // ignore: cast_nullable_to_non_nullable
                  as int,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$CheckInStatusDetailImpl implements _CheckInStatusDetail {
  const _$CheckInStatusDetailImpl({
    @JsonKey(name: 'streak_count') required this.streakCount,
    @JsonKey(name: 'total_days_completed') required this.totalDaysCompleted,
    @JsonKey(name: 'is_completed') required this.isCompleted,
    @JsonKey(name: 'last_check_in') this.lastCheckIn,
    @JsonKey(name: 'checked_in_today') required this.checkedInToday,
    @JsonKey(name: 'days_remaining') required this.daysRemaining,
  });

  factory _$CheckInStatusDetailImpl.fromJson(Map<String, dynamic> json) =>
      _$$CheckInStatusDetailImplFromJson(json);

  @override
  @JsonKey(name: 'streak_count')
  final int streakCount;
  @override
  @JsonKey(name: 'total_days_completed')
  final int totalDaysCompleted;
  @override
  @JsonKey(name: 'is_completed')
  final bool isCompleted;
  @override
  @JsonKey(name: 'last_check_in')
  final DateTime? lastCheckIn;
  @override
  @JsonKey(name: 'checked_in_today')
  final bool checkedInToday;
  @override
  @JsonKey(name: 'days_remaining')
  final int daysRemaining;

  @override
  String toString() {
    return 'CheckInStatusDetail(streakCount: $streakCount, totalDaysCompleted: $totalDaysCompleted, isCompleted: $isCompleted, lastCheckIn: $lastCheckIn, checkedInToday: $checkedInToday, daysRemaining: $daysRemaining)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$CheckInStatusDetailImpl &&
            (identical(other.streakCount, streakCount) ||
                other.streakCount == streakCount) &&
            (identical(other.totalDaysCompleted, totalDaysCompleted) ||
                other.totalDaysCompleted == totalDaysCompleted) &&
            (identical(other.isCompleted, isCompleted) ||
                other.isCompleted == isCompleted) &&
            (identical(other.lastCheckIn, lastCheckIn) ||
                other.lastCheckIn == lastCheckIn) &&
            (identical(other.checkedInToday, checkedInToday) ||
                other.checkedInToday == checkedInToday) &&
            (identical(other.daysRemaining, daysRemaining) ||
                other.daysRemaining == daysRemaining));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    streakCount,
    totalDaysCompleted,
    isCompleted,
    lastCheckIn,
    checkedInToday,
    daysRemaining,
  );

  /// Create a copy of CheckInStatusDetail
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$CheckInStatusDetailImplCopyWith<_$CheckInStatusDetailImpl> get copyWith =>
      __$$CheckInStatusDetailImplCopyWithImpl<_$CheckInStatusDetailImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$CheckInStatusDetailImplToJson(this);
  }
}

abstract class _CheckInStatusDetail implements CheckInStatusDetail {
  const factory _CheckInStatusDetail({
    @JsonKey(name: 'streak_count') required final int streakCount,
    @JsonKey(name: 'total_days_completed')
    required final int totalDaysCompleted,
    @JsonKey(name: 'is_completed') required final bool isCompleted,
    @JsonKey(name: 'last_check_in') final DateTime? lastCheckIn,
    @JsonKey(name: 'checked_in_today') required final bool checkedInToday,
    @JsonKey(name: 'days_remaining') required final int daysRemaining,
  }) = _$CheckInStatusDetailImpl;

  factory _CheckInStatusDetail.fromJson(Map<String, dynamic> json) =
      _$CheckInStatusDetailImpl.fromJson;

  @override
  @JsonKey(name: 'streak_count')
  int get streakCount;
  @override
  @JsonKey(name: 'total_days_completed')
  int get totalDaysCompleted;
  @override
  @JsonKey(name: 'is_completed')
  bool get isCompleted;
  @override
  @JsonKey(name: 'last_check_in')
  DateTime? get lastCheckIn;
  @override
  @JsonKey(name: 'checked_in_today')
  bool get checkedInToday;
  @override
  @JsonKey(name: 'days_remaining')
  int get daysRemaining;

  /// Create a copy of CheckInStatusDetail
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$CheckInStatusDetailImplCopyWith<_$CheckInStatusDetailImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
