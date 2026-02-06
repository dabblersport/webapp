import 'package:freezed_annotation/freezed_annotation.dart';

part 'sport_profile.freezed.dart';
part 'sport_profile.g.dart';

/// Sport preference profile for a specific user and sport.
@freezed
class SportProfile with _$SportProfile {
  const factory SportProfile({
    /// Owning user identifier.
    @JsonKey(name: 'user_id') required String userId,

    /// Unique identifier for the sport.
    @JsonKey(name: 'sport_key') required String sportKey,

    /// Skill level reported by the user (1..10).
    @JsonKey(name: 'skill_level') required int skillLevel,
  }) = _SportProfile;

  /// Creates a [SportProfile] from a Supabase JSON payload.
  factory SportProfile.fromJson(Map<String, dynamic> json) =>
      _$SportProfileFromJson(json);
}
