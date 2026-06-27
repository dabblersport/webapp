// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notification_settings.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$NotificationSettingsImpl _$$NotificationSettingsImplFromJson(
  Map<String, dynamic> json,
) => _$NotificationSettingsImpl(
  userId: json['user_id'] as String,
  tz: json['tz'] as String? ?? 'Asia/Dubai',
  quietStartMin: (json['quiet_start_min'] as num?)?.toInt(),
  quietEndMin: (json['quiet_end_min'] as num?)?.toInt(),
  pushEnabled: json['push_enabled'] as bool? ?? true,
  emailEnabled: json['email_enabled'] as bool? ?? false,
  smsEnabled: json['sms_enabled'] as bool? ?? false,
  mutedKinds:
      (json['muted_kinds'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const <String>[],
  allowHighPriorityOverride:
      json['allow_high_priority_override'] as bool? ?? false,
  allowAllOverride: json['allow_all_override'] as bool? ?? false,
);

Map<String, dynamic> _$$NotificationSettingsImplToJson(
  _$NotificationSettingsImpl instance,
) => <String, dynamic>{
  'user_id': instance.userId,
  'tz': instance.tz,
  'quiet_start_min': instance.quietStartMin,
  'quiet_end_min': instance.quietEndMin,
  'push_enabled': instance.pushEnabled,
  'email_enabled': instance.emailEnabled,
  'sms_enabled': instance.smsEnabled,
  'muted_kinds': instance.mutedKinds,
  'allow_high_priority_override': instance.allowHighPriorityOverride,
  'allow_all_override': instance.allowAllOverride,
};
