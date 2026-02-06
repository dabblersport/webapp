import 'package:freezed_annotation/freezed_annotation.dart';

part 'check_in_status.freezed.dart';
part 'check_in_status.g.dart';

/// Model representing the user's current check-in status
/// Maps to the user_check_ins table in Supabase
@freezed
class CheckInStatus with _$CheckInStatus {
  const factory CheckInStatus({
    @JsonKey(name: 'user_id') required String userId,
    @JsonKey(name: 'last_check_in') required DateTime lastCheckIn,
    @JsonKey(name: 'streak_count') required int streakCount,
    @JsonKey(name: 'total_days_completed') required int totalDaysCompleted,
    @JsonKey(name: 'is_completed') required bool isCompleted,
    @JsonKey(name: 'badge_awarded_at') DateTime? badgeAwardedAt,
    @JsonKey(name: 'created_at') required DateTime createdAt,
    @JsonKey(name: 'updated_at') required DateTime updatedAt,
  }) = _CheckInStatus;

  factory CheckInStatus.fromJson(Map<String, dynamic> json) =>
      _$CheckInStatusFromJson(json);
}

/// Response from the perform_check_in function
@freezed
class CheckInResponse with _$CheckInResponse {
  const factory CheckInResponse({
    required bool success,
    required String message,
    @JsonKey(name: 'streak_count') required int streakCount,
    @JsonKey(name: 'total_days_completed') required int totalDaysCompleted,
    @JsonKey(name: 'is_completed') required bool isCompleted,
    @JsonKey(name: 'is_first_check_in_today') required bool isFirstCheckInToday,
  }) = _CheckInResponse;

  factory CheckInResponse.fromJson(Map<String, dynamic> json) =>
      _$CheckInResponseFromJson(json);
}

/// Response from the get_check_in_status function
@freezed
class CheckInStatusDetail with _$CheckInStatusDetail {
  const factory CheckInStatusDetail({
    @JsonKey(name: 'streak_count') required int streakCount,
    @JsonKey(name: 'total_days_completed') required int totalDaysCompleted,
    @JsonKey(name: 'is_completed') required bool isCompleted,
    @JsonKey(name: 'last_check_in') DateTime? lastCheckIn,
    @JsonKey(name: 'checked_in_today') required bool checkedInToday,
    @JsonKey(name: 'days_remaining') required int daysRemaining,
  }) = _CheckInStatusDetail;

  factory CheckInStatusDetail.fromJson(Map<String, dynamic> json) =>
      _$CheckInStatusDetailFromJson(json);
}
