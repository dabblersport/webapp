import 'package:freezed_annotation/freezed_annotation.dart';

part 'organiser_profile.freezed.dart';
part 'organiser_profile.g.dart';

/// Model representing an organiser profile from the organiser_profiles table
/// This is linked to a profile via profile_id
@freezed
class OrganiserProfile with _$OrganiserProfile {
  const factory OrganiserProfile({
    required String id,
    @JsonKey(name: 'profile_id') required String profileId, // FK to profiles.id
    required String sport,
    @JsonKey(name: 'organiser_level') @Default(1) int organiserLevel,
    @JsonKey(name: 'commission_type') @Default('percent') String commissionType,
    @JsonKey(name: 'commission_value') @Default(0.0) double commissionValue,
    @JsonKey(name: 'is_verified') @Default(false) bool isVerified,
    @JsonKey(name: 'is_active') @Default(true) bool isActive,
    @JsonKey(name: 'created_at') required DateTime createdAt,
    @JsonKey(name: 'updated_at') required DateTime updatedAt,
  }) = _OrganiserProfile;

  factory OrganiserProfile.fromJson(Map<String, dynamic> json) =>
      _$OrganiserProfileFromJson(json);
}
