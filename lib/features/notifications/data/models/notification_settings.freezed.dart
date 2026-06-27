// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'notification_settings.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

NotificationSettings _$NotificationSettingsFromJson(Map<String, dynamic> json) {
  return _NotificationSettings.fromJson(json);
}

/// @nodoc
mixin _$NotificationSettings {
  @JsonKey(name: 'user_id')
  String get userId => throw _privateConstructorUsedError;
  String get tz => throw _privateConstructorUsedError;

  /// Quiet-hours window as minutes-since-midnight (0–1439), local to [tz].
  /// Null when quiet hours are disabled.
  @JsonKey(name: 'quiet_start_min')
  int? get quietStartMin => throw _privateConstructorUsedError;
  @JsonKey(name: 'quiet_end_min')
  int? get quietEndMin => throw _privateConstructorUsedError;
  @JsonKey(name: 'push_enabled')
  bool get pushEnabled => throw _privateConstructorUsedError;
  @JsonKey(name: 'email_enabled')
  bool get emailEnabled => throw _privateConstructorUsedError;
  @JsonKey(name: 'sms_enabled')
  bool get smsEnabled => throw _privateConstructorUsedError;

  /// `notification_kinds.key`s the user has muted.
  @JsonKey(name: 'muted_kinds')
  List<String> get mutedKinds => throw _privateConstructorUsedError;
  @JsonKey(name: 'allow_high_priority_override')
  bool get allowHighPriorityOverride => throw _privateConstructorUsedError;
  @JsonKey(name: 'allow_all_override')
  bool get allowAllOverride => throw _privateConstructorUsedError;

  /// Serializes this NotificationSettings to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of NotificationSettings
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $NotificationSettingsCopyWith<NotificationSettings> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $NotificationSettingsCopyWith<$Res> {
  factory $NotificationSettingsCopyWith(
    NotificationSettings value,
    $Res Function(NotificationSettings) then,
  ) = _$NotificationSettingsCopyWithImpl<$Res, NotificationSettings>;
  @useResult
  $Res call({
    @JsonKey(name: 'user_id') String userId,
    String tz,
    @JsonKey(name: 'quiet_start_min') int? quietStartMin,
    @JsonKey(name: 'quiet_end_min') int? quietEndMin,
    @JsonKey(name: 'push_enabled') bool pushEnabled,
    @JsonKey(name: 'email_enabled') bool emailEnabled,
    @JsonKey(name: 'sms_enabled') bool smsEnabled,
    @JsonKey(name: 'muted_kinds') List<String> mutedKinds,
    @JsonKey(name: 'allow_high_priority_override')
    bool allowHighPriorityOverride,
    @JsonKey(name: 'allow_all_override') bool allowAllOverride,
  });
}

/// @nodoc
class _$NotificationSettingsCopyWithImpl<
  $Res,
  $Val extends NotificationSettings
>
    implements $NotificationSettingsCopyWith<$Res> {
  _$NotificationSettingsCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of NotificationSettings
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? userId = null,
    Object? tz = null,
    Object? quietStartMin = freezed,
    Object? quietEndMin = freezed,
    Object? pushEnabled = null,
    Object? emailEnabled = null,
    Object? smsEnabled = null,
    Object? mutedKinds = null,
    Object? allowHighPriorityOverride = null,
    Object? allowAllOverride = null,
  }) {
    return _then(
      _value.copyWith(
            userId: null == userId
                ? _value.userId
                : userId // ignore: cast_nullable_to_non_nullable
                      as String,
            tz: null == tz
                ? _value.tz
                : tz // ignore: cast_nullable_to_non_nullable
                      as String,
            quietStartMin: freezed == quietStartMin
                ? _value.quietStartMin
                : quietStartMin // ignore: cast_nullable_to_non_nullable
                      as int?,
            quietEndMin: freezed == quietEndMin
                ? _value.quietEndMin
                : quietEndMin // ignore: cast_nullable_to_non_nullable
                      as int?,
            pushEnabled: null == pushEnabled
                ? _value.pushEnabled
                : pushEnabled // ignore: cast_nullable_to_non_nullable
                      as bool,
            emailEnabled: null == emailEnabled
                ? _value.emailEnabled
                : emailEnabled // ignore: cast_nullable_to_non_nullable
                      as bool,
            smsEnabled: null == smsEnabled
                ? _value.smsEnabled
                : smsEnabled // ignore: cast_nullable_to_non_nullable
                      as bool,
            mutedKinds: null == mutedKinds
                ? _value.mutedKinds
                : mutedKinds // ignore: cast_nullable_to_non_nullable
                      as List<String>,
            allowHighPriorityOverride: null == allowHighPriorityOverride
                ? _value.allowHighPriorityOverride
                : allowHighPriorityOverride // ignore: cast_nullable_to_non_nullable
                      as bool,
            allowAllOverride: null == allowAllOverride
                ? _value.allowAllOverride
                : allowAllOverride // ignore: cast_nullable_to_non_nullable
                      as bool,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$NotificationSettingsImplCopyWith<$Res>
    implements $NotificationSettingsCopyWith<$Res> {
  factory _$$NotificationSettingsImplCopyWith(
    _$NotificationSettingsImpl value,
    $Res Function(_$NotificationSettingsImpl) then,
  ) = __$$NotificationSettingsImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    @JsonKey(name: 'user_id') String userId,
    String tz,
    @JsonKey(name: 'quiet_start_min') int? quietStartMin,
    @JsonKey(name: 'quiet_end_min') int? quietEndMin,
    @JsonKey(name: 'push_enabled') bool pushEnabled,
    @JsonKey(name: 'email_enabled') bool emailEnabled,
    @JsonKey(name: 'sms_enabled') bool smsEnabled,
    @JsonKey(name: 'muted_kinds') List<String> mutedKinds,
    @JsonKey(name: 'allow_high_priority_override')
    bool allowHighPriorityOverride,
    @JsonKey(name: 'allow_all_override') bool allowAllOverride,
  });
}

/// @nodoc
class __$$NotificationSettingsImplCopyWithImpl<$Res>
    extends _$NotificationSettingsCopyWithImpl<$Res, _$NotificationSettingsImpl>
    implements _$$NotificationSettingsImplCopyWith<$Res> {
  __$$NotificationSettingsImplCopyWithImpl(
    _$NotificationSettingsImpl _value,
    $Res Function(_$NotificationSettingsImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of NotificationSettings
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? userId = null,
    Object? tz = null,
    Object? quietStartMin = freezed,
    Object? quietEndMin = freezed,
    Object? pushEnabled = null,
    Object? emailEnabled = null,
    Object? smsEnabled = null,
    Object? mutedKinds = null,
    Object? allowHighPriorityOverride = null,
    Object? allowAllOverride = null,
  }) {
    return _then(
      _$NotificationSettingsImpl(
        userId: null == userId
            ? _value.userId
            : userId // ignore: cast_nullable_to_non_nullable
                  as String,
        tz: null == tz
            ? _value.tz
            : tz // ignore: cast_nullable_to_non_nullable
                  as String,
        quietStartMin: freezed == quietStartMin
            ? _value.quietStartMin
            : quietStartMin // ignore: cast_nullable_to_non_nullable
                  as int?,
        quietEndMin: freezed == quietEndMin
            ? _value.quietEndMin
            : quietEndMin // ignore: cast_nullable_to_non_nullable
                  as int?,
        pushEnabled: null == pushEnabled
            ? _value.pushEnabled
            : pushEnabled // ignore: cast_nullable_to_non_nullable
                  as bool,
        emailEnabled: null == emailEnabled
            ? _value.emailEnabled
            : emailEnabled // ignore: cast_nullable_to_non_nullable
                  as bool,
        smsEnabled: null == smsEnabled
            ? _value.smsEnabled
            : smsEnabled // ignore: cast_nullable_to_non_nullable
                  as bool,
        mutedKinds: null == mutedKinds
            ? _value._mutedKinds
            : mutedKinds // ignore: cast_nullable_to_non_nullable
                  as List<String>,
        allowHighPriorityOverride: null == allowHighPriorityOverride
            ? _value.allowHighPriorityOverride
            : allowHighPriorityOverride // ignore: cast_nullable_to_non_nullable
                  as bool,
        allowAllOverride: null == allowAllOverride
            ? _value.allowAllOverride
            : allowAllOverride // ignore: cast_nullable_to_non_nullable
                  as bool,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$NotificationSettingsImpl extends _NotificationSettings {
  const _$NotificationSettingsImpl({
    @JsonKey(name: 'user_id') required this.userId,
    this.tz = 'Asia/Dubai',
    @JsonKey(name: 'quiet_start_min') this.quietStartMin,
    @JsonKey(name: 'quiet_end_min') this.quietEndMin,
    @JsonKey(name: 'push_enabled') this.pushEnabled = true,
    @JsonKey(name: 'email_enabled') this.emailEnabled = false,
    @JsonKey(name: 'sms_enabled') this.smsEnabled = false,
    @JsonKey(name: 'muted_kinds')
    final List<String> mutedKinds = const <String>[],
    @JsonKey(name: 'allow_high_priority_override')
    this.allowHighPriorityOverride = false,
    @JsonKey(name: 'allow_all_override') this.allowAllOverride = false,
  }) : _mutedKinds = mutedKinds,
       super._();

  factory _$NotificationSettingsImpl.fromJson(Map<String, dynamic> json) =>
      _$$NotificationSettingsImplFromJson(json);

  @override
  @JsonKey(name: 'user_id')
  final String userId;
  @override
  @JsonKey()
  final String tz;

  /// Quiet-hours window as minutes-since-midnight (0–1439), local to [tz].
  /// Null when quiet hours are disabled.
  @override
  @JsonKey(name: 'quiet_start_min')
  final int? quietStartMin;
  @override
  @JsonKey(name: 'quiet_end_min')
  final int? quietEndMin;
  @override
  @JsonKey(name: 'push_enabled')
  final bool pushEnabled;
  @override
  @JsonKey(name: 'email_enabled')
  final bool emailEnabled;
  @override
  @JsonKey(name: 'sms_enabled')
  final bool smsEnabled;

  /// `notification_kinds.key`s the user has muted.
  final List<String> _mutedKinds;

  /// `notification_kinds.key`s the user has muted.
  @override
  @JsonKey(name: 'muted_kinds')
  List<String> get mutedKinds {
    if (_mutedKinds is EqualUnmodifiableListView) return _mutedKinds;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_mutedKinds);
  }

  @override
  @JsonKey(name: 'allow_high_priority_override')
  final bool allowHighPriorityOverride;
  @override
  @JsonKey(name: 'allow_all_override')
  final bool allowAllOverride;

  @override
  String toString() {
    return 'NotificationSettings(userId: $userId, tz: $tz, quietStartMin: $quietStartMin, quietEndMin: $quietEndMin, pushEnabled: $pushEnabled, emailEnabled: $emailEnabled, smsEnabled: $smsEnabled, mutedKinds: $mutedKinds, allowHighPriorityOverride: $allowHighPriorityOverride, allowAllOverride: $allowAllOverride)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$NotificationSettingsImpl &&
            (identical(other.userId, userId) || other.userId == userId) &&
            (identical(other.tz, tz) || other.tz == tz) &&
            (identical(other.quietStartMin, quietStartMin) ||
                other.quietStartMin == quietStartMin) &&
            (identical(other.quietEndMin, quietEndMin) ||
                other.quietEndMin == quietEndMin) &&
            (identical(other.pushEnabled, pushEnabled) ||
                other.pushEnabled == pushEnabled) &&
            (identical(other.emailEnabled, emailEnabled) ||
                other.emailEnabled == emailEnabled) &&
            (identical(other.smsEnabled, smsEnabled) ||
                other.smsEnabled == smsEnabled) &&
            const DeepCollectionEquality().equals(
              other._mutedKinds,
              _mutedKinds,
            ) &&
            (identical(
                  other.allowHighPriorityOverride,
                  allowHighPriorityOverride,
                ) ||
                other.allowHighPriorityOverride == allowHighPriorityOverride) &&
            (identical(other.allowAllOverride, allowAllOverride) ||
                other.allowAllOverride == allowAllOverride));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    userId,
    tz,
    quietStartMin,
    quietEndMin,
    pushEnabled,
    emailEnabled,
    smsEnabled,
    const DeepCollectionEquality().hash(_mutedKinds),
    allowHighPriorityOverride,
    allowAllOverride,
  );

  /// Create a copy of NotificationSettings
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$NotificationSettingsImplCopyWith<_$NotificationSettingsImpl>
  get copyWith =>
      __$$NotificationSettingsImplCopyWithImpl<_$NotificationSettingsImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$NotificationSettingsImplToJson(this);
  }
}

abstract class _NotificationSettings extends NotificationSettings {
  const factory _NotificationSettings({
    @JsonKey(name: 'user_id') required final String userId,
    final String tz,
    @JsonKey(name: 'quiet_start_min') final int? quietStartMin,
    @JsonKey(name: 'quiet_end_min') final int? quietEndMin,
    @JsonKey(name: 'push_enabled') final bool pushEnabled,
    @JsonKey(name: 'email_enabled') final bool emailEnabled,
    @JsonKey(name: 'sms_enabled') final bool smsEnabled,
    @JsonKey(name: 'muted_kinds') final List<String> mutedKinds,
    @JsonKey(name: 'allow_high_priority_override')
    final bool allowHighPriorityOverride,
    @JsonKey(name: 'allow_all_override') final bool allowAllOverride,
  }) = _$NotificationSettingsImpl;
  const _NotificationSettings._() : super._();

  factory _NotificationSettings.fromJson(Map<String, dynamic> json) =
      _$NotificationSettingsImpl.fromJson;

  @override
  @JsonKey(name: 'user_id')
  String get userId;
  @override
  String get tz;

  /// Quiet-hours window as minutes-since-midnight (0–1439), local to [tz].
  /// Null when quiet hours are disabled.
  @override
  @JsonKey(name: 'quiet_start_min')
  int? get quietStartMin;
  @override
  @JsonKey(name: 'quiet_end_min')
  int? get quietEndMin;
  @override
  @JsonKey(name: 'push_enabled')
  bool get pushEnabled;
  @override
  @JsonKey(name: 'email_enabled')
  bool get emailEnabled;
  @override
  @JsonKey(name: 'sms_enabled')
  bool get smsEnabled;

  /// `notification_kinds.key`s the user has muted.
  @override
  @JsonKey(name: 'muted_kinds')
  List<String> get mutedKinds;
  @override
  @JsonKey(name: 'allow_high_priority_override')
  bool get allowHighPriorityOverride;
  @override
  @JsonKey(name: 'allow_all_override')
  bool get allowAllOverride;

  /// Create a copy of NotificationSettings
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$NotificationSettingsImplCopyWith<_$NotificationSettingsImpl>
  get copyWith => throw _privateConstructorUsedError;
}
