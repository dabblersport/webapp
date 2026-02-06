// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'check_in_log.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$CheckInLogImpl _$$CheckInLogImplFromJson(Map<String, dynamic> json) =>
    _$CheckInLogImpl(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      checkInDate: DateTime.parse(json['check_in_date'] as String),
      checkInTimestamp: DateTime.parse(json['check_in_timestamp'] as String),
      streakAtTime: (json['streak_at_time'] as num).toInt(),
      deviceInfo: json['device_info'] as Map<String, dynamic>?,
    );

Map<String, dynamic> _$$CheckInLogImplToJson(_$CheckInLogImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'user_id': instance.userId,
      'check_in_date': instance.checkInDate.toIso8601String(),
      'check_in_timestamp': instance.checkInTimestamp.toIso8601String(),
      'streak_at_time': instance.streakAtTime,
      'device_info': instance.deviceInfo,
    };
