import 'package:json_annotation/json_annotation.dart';

part 'profile.g.dart';

@JsonSerializable(fieldRename: FieldRename.snake)
class Profile {
  final String id;
  final String userId;
  final String profileType;
  final String username;
  final String displayName;
  final String? bio;
  final String? avatarUrl;
  final String? city;
  final String? country;
  final String? language;
  final bool? verified;
  final bool? isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? displayNameNorm;
  final double? geoLat;
  final double? geoLng;
  // New onboarding fields
  final String? intention;
  final String? gender;
  final int? age;
  final String? preferredSport;
  final String? interests; // comma-separated

  const Profile({
    required this.id,
    required this.userId,
    required this.profileType,
    required this.username,
    required this.displayName,
    this.bio,
    this.avatarUrl,
    this.city,
    this.country,
    this.language,
    this.verified,
    this.isActive,
    this.createdAt,
    this.updatedAt,
    this.displayNameNorm,
    this.geoLat,
    this.geoLng,
    this.intention,
    this.gender,
    this.age,
    this.preferredSport,
    this.interests,
  });

  factory Profile.fromJson(Map<String, dynamic> json) =>
      _$ProfileFromJson(json);

  Map<String, dynamic> toJson() => _$ProfileToJson(this);
}
