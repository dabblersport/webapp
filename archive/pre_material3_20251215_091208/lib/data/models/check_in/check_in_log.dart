import 'package:freezed_annotation/freezed_annotation.dart';

part 'check_in_log.freezed.dart';
part 'check_in_log.g.dart';

/// Model representing a single check-in log entry
/// Maps to the check_in_logs table in Supabase
@freezed
class CheckInLog with _$CheckInLog {
  const factory CheckInLog({
    required String id,
    @JsonKey(name: 'user_id') required String userId,
    @JsonKey(name: 'check_in_date') required DateTime checkInDate,
    @JsonKey(name: 'check_in_timestamp') required DateTime checkInTimestamp,
    @JsonKey(name: 'streak_at_time') required int streakAtTime,
    @JsonKey(name: 'device_info') Map<String, dynamic>? deviceInfo,
  }) = _CheckInLog;

  factory CheckInLog.fromJson(Map<String, dynamic> json) =>
      _$CheckInLogFromJson(json);
}
