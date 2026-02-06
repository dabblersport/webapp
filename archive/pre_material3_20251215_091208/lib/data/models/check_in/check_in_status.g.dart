// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'check_in_status.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$CheckInStatusImpl _$$CheckInStatusImplFromJson(Map<String, dynamic> json) =>
    _$CheckInStatusImpl(
      userId: json['user_id'] as String,
      lastCheckIn: DateTime.parse(json['last_check_in'] as String),
      streakCount: (json['streak_count'] as num).toInt(),
      totalDaysCompleted: (json['total_days_completed'] as num).toInt(),
      isCompleted: json['is_completed'] as bool,
      badgeAwardedAt: json['badge_awarded_at'] == null
          ? null
          : DateTime.parse(json['badge_awarded_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );

Map<String, dynamic> _$$CheckInStatusImplToJson(_$CheckInStatusImpl instance) =>
    <String, dynamic>{
      'user_id': instance.userId,
      'last_check_in': instance.lastCheckIn.toIso8601String(),
      'streak_count': instance.streakCount,
      'total_days_completed': instance.totalDaysCompleted,
      'is_completed': instance.isCompleted,
      'badge_awarded_at': instance.badgeAwardedAt?.toIso8601String(),
      'created_at': instance.createdAt.toIso8601String(),
      'updated_at': instance.updatedAt.toIso8601String(),
    };

_$CheckInResponseImpl _$$CheckInResponseImplFromJson(
  Map<String, dynamic> json,
) => _$CheckInResponseImpl(
  success: json['success'] as bool,
  message: json['message'] as String,
  streakCount: (json['streak_count'] as num).toInt(),
  totalDaysCompleted: (json['total_days_completed'] as num).toInt(),
  isCompleted: json['is_completed'] as bool,
  isFirstCheckInToday: json['is_first_check_in_today'] as bool,
);

Map<String, dynamic> _$$CheckInResponseImplToJson(
  _$CheckInResponseImpl instance,
) => <String, dynamic>{
  'success': instance.success,
  'message': instance.message,
  'streak_count': instance.streakCount,
  'total_days_completed': instance.totalDaysCompleted,
  'is_completed': instance.isCompleted,
  'is_first_check_in_today': instance.isFirstCheckInToday,
};

_$CheckInStatusDetailImpl _$$CheckInStatusDetailImplFromJson(
  Map<String, dynamic> json,
) => _$CheckInStatusDetailImpl(
  streakCount: (json['streak_count'] as num).toInt(),
  totalDaysCompleted: (json['total_days_completed'] as num).toInt(),
  isCompleted: json['is_completed'] as bool,
  lastCheckIn: json['last_check_in'] == null
      ? null
      : DateTime.parse(json['last_check_in'] as String),
  checkedInToday: json['checked_in_today'] as bool,
  daysRemaining: (json['days_remaining'] as num).toInt(),
);

Map<String, dynamic> _$$CheckInStatusDetailImplToJson(
  _$CheckInStatusDetailImpl instance,
) => <String, dynamic>{
  'streak_count': instance.streakCount,
  'total_days_completed': instance.totalDaysCompleted,
  'is_completed': instance.isCompleted,
  'last_check_in': instance.lastCheckIn?.toIso8601String(),
  'checked_in_today': instance.checkedInToday,
  'days_remaining': instance.daysRemaining,
};
