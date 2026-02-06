import 'package:dabbler/data/models/authentication/user.dart';
import 'sports_profile.dart';
import 'profile_statistics.dart';
import 'privacy_settings.dart';
import 'user_preferences.dart';
import 'user_settings.dart';

class UserProfile {
  // Core user information (from profiles table)
  final String id; // profile id
  final String userId; // foreign key to auth.users
  final String? username; // citext
  final String displayName;
  final String? avatarUrl;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Enhanced profile fields (matching actual DB schema)
  final String? bio;
  final int? age; // stored as integer in DB (not dateOfBirth)
  final String? city;
  final String? country;
  final String? phoneNumber; // from auth.users, not profiles table
  final String? email; // from auth.users, not profiles table
  final String? gender;
  final String? profileType; // organiser/player
  final String? intention; // organise/play
  final String? preferredSport;
  final String? interests;
  final String? language;
  final bool verified; // matches DB column name
  final bool isActive;
  final double? geoLat;
  final double? geoLng;

  // Related entities
  final List<SportProfile> sportsProfiles;
  final ProfileStatistics statistics;
  final PrivacySettings privacySettings;
  final UserPreferences preferences;
  final UserSettings settings;

  const UserProfile({
    required this.id,
    required this.userId,
    this.username,
    required this.displayName,
    this.avatarUrl,
    required this.createdAt,
    required this.updatedAt,
    this.bio,
    this.age,
    this.city,
    this.country,
    this.phoneNumber,
    this.email,
    this.gender,
    this.profileType,
    this.intention,
    this.preferredSport,
    this.interests,
    this.language,
    this.verified = false,
    this.isActive = true,
    this.geoLat,
    this.geoLng,
    this.sportsProfiles = const [],
    this.statistics = const ProfileStatistics(),
    this.privacySettings = const PrivacySettings(),
    this.preferences = const UserPreferences(userId: ''),
    this.settings = const UserSettings(),
  });

  /// Creates UserProfile from auth User with default values
  factory UserProfile.fromUser(User user) {
    return UserProfile(
      id: '', // will be set when profile is created in DB
      userId: user.id,
      email: user.email,
      displayName:
          user.fullName ?? user.username ?? user.email?.split('@').first ?? '',
      username: user.username,
      avatarUrl: user.avatarUrl,
      createdAt: user.createdAt,
      updatedAt: user.updatedAt,
    );
  }

  /// Checks if profile is considered complete
  bool isProfileComplete() {
    return calculateProfileCompletion() >= 80.0;
  }

  /// Returns the primary sport (if any)
  SportProfile? getPrimarySport() {
    try {
      return sportsProfiles.firstWhere((sport) => sport.isPrimarySport);
    } catch (e) {
      // If no primary sport set, return most played sport
      if (sportsProfiles.isEmpty) return null;
      return sportsProfiles.reduce(
        (a, b) => a.gamesPlayed > b.gamesPlayed ? a : b,
      );
    }
  }

  /// Returns age (stored directly in DB)
  int? getAge() {
    return age;
  }

  /// Returns full name if available
  String getFullName() {
    if (displayName.isNotEmpty) {
      return displayName;
    }
    if (username != null && username!.isNotEmpty) {
      return username!;
    }
    return email?.split('@').first ?? 'User';
  }

  /// Returns display name with privacy considerations
  String getDisplayName({String? viewerId}) {
    if (!privacySettings.canViewField('realName', viewerId)) {
      return displayName.isNotEmpty
          ? displayName
          : ''; // Return username/handle instead
    }
    final fullName = getFullName();
    return fullName.isNotEmpty ? fullName : '';
  }

  /// Calculates and returns current profile completion percentage
  double calculateProfileCompletion() {
    double completion = 0.0;

    // Basic info (40%)
    completion += 20.0; // Account exists
    if (displayName.isNotEmpty) completion += 10.0;
    if (avatarUrl != null) completion += 10.0;

    // Personal details (30%)
    if (bio != null && bio!.isNotEmpty) completion += 10.0;
    if (age != null) completion += 5.0;
    if (city != null && city!.isNotEmpty) completion += 2.5;
    if (country != null && country!.isNotEmpty) completion += 2.5;
    if (username != null && username!.isNotEmpty) completion += 10.0;

    // Sports profiles (20%)
    if (sportsProfiles.isNotEmpty) completion += 10.0;
    if (sportsProfiles.any((sport) => sport.isPrimarySport)) completion += 5.0;
    if (sportsProfiles.any(
      (sport) => sport.skillLevel != SkillLevel.beginner,
    )) {
      completion += 5.0;
    }

    // Preferences and settings (10%)
    if (preferences.preferredGameTypes.isNotEmpty) completion += 5.0;
    if (preferences.weeklyAvailability.isNotEmpty) completion += 5.0;

    return completion.clamp(0.0, 100.0);
  }

  /// Checks if user is active based on is_active flag
  bool isActiveUser() {
    return isActive;
  }

  /// Returns user's activity status
  String getActivityStatus() {
    return isActive ? 'Active' : 'Inactive';
  }

  /// Checks compatibility with another user for games
  double getCompatibilityScore(UserProfile otherUser) {
    double score = 0.0;

    // Sport compatibility (30%)
    final myPrimarySport = getPrimarySport();
    final otherPrimarySport = otherUser.getPrimarySport();

    if (myPrimarySport != null && otherPrimarySport != null) {
      if (myPrimarySport.sportId == otherPrimarySport.sportId) {
        score += 30.0;

        // Skill level compatibility bonus
        final skillDiff =
            (myPrimarySport.skillLevel.index -
                    otherPrimarySport.skillLevel.index)
                .abs();
        if (skillDiff <= 1) score += 10.0;
      }
    }

    // Location compatibility (20%) - using city and country
    if (city != null &&
        otherUser.city != null &&
        country != null &&
        otherUser.country != null) {
      if (city == otherUser.city && country == otherUser.country) {
        score += 20.0;
      } else if (country == otherUser.country) {
        score += 10.0; // Same country, different city
      }
    }

    // Age compatibility (15%)
    final myAge = getAge();
    final otherAge = otherUser.getAge();
    if (myAge != null && otherAge != null) {
      final ageDiff = (myAge - otherAge).abs();
      if (ageDiff <= 5) {
        score += 15.0;
      } else if (ageDiff <= 10) {
        score += 10.0;
      } else if (ageDiff <= 15) {
        score += 5.0;
      }
    }

    // Activity compatibility (10%)
    if (isActiveUser() && otherUser.isActiveUser()) {
      score += 10.0;
    }

    // Experience compatibility (15%)
    if (statistics.isExperiencedPlayer() ==
        otherUser.statistics.isExperiencedPlayer()) {
      score += 15.0;
    }

    // Reliability compatibility (10%)
    final myReliability = statistics.getReliabilityScore();
    final otherReliability = otherUser.statistics.getReliabilityScore();
    final reliabilityDiff = (myReliability - otherReliability).abs();

    if (reliabilityDiff <= 10) {
      score += 10.0;
    } else if (reliabilityDiff <= 20) {
      score += 5.0;
    }

    return score.clamp(0.0, 100.0);
  }

  /// Creates a copy with updated fields
  UserProfile copyWith({
    String? id,
    String? userId,
    String? email,
    String? username,
    String? displayName,
    String? avatarUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? bio,
    int? age,
    String? city,
    String? country,
    String? phoneNumber,
    String? gender,
    String? profileType,
    String? intention,
    String? preferredSport,
    String? interests,
    String? language,
    bool? verified,
    bool? isActive,
    double? geoLat,
    double? geoLng,
    List<SportProfile>? sportsProfiles,
    ProfileStatistics? statistics,
    PrivacySettings? privacySettings,
    UserPreferences? preferences,
    UserSettings? settings,
  }) {
    return UserProfile(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      email: email ?? this.email,
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      bio: bio ?? this.bio,
      age: age ?? this.age,
      city: city ?? this.city,
      country: country ?? this.country,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      gender: gender ?? this.gender,
      profileType: profileType ?? this.profileType,
      intention: intention ?? this.intention,
      preferredSport: preferredSport ?? this.preferredSport,
      interests: interests ?? this.interests,
      language: language ?? this.language,
      verified: verified ?? this.verified,
      isActive: isActive ?? this.isActive,
      geoLat: geoLat ?? this.geoLat,
      geoLng: geoLng ?? this.geoLng,
      sportsProfiles: sportsProfiles ?? this.sportsProfiles,
      statistics: statistics ?? this.statistics,
      privacySettings: privacySettings ?? this.privacySettings,
      preferences: preferences ?? this.preferences,
      settings: settings ?? this.settings,
    );
  }

  /// Creates UserProfile from JSON (matching actual DB schema)
  factory UserProfile.fromJson(Map<String, dynamic> json) {
    // Parse nested sport_profiles if included in the response
    // Note: Database uses simple schema: profile_id, sport_key, skill_level
    List<SportProfile> parsedSportsProfiles = [];
    if (json['sport_profiles'] != null && json['sport_profiles'] is List) {
      parsedSportsProfiles = (json['sport_profiles'] as List)
          .map((sp) => SportProfile.fromJson(sp as Map<String, dynamic>))
          .toList();
    }

    final displayName = (json['display_name'] as String?) ?? '';

    return UserProfile(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      username: json['username'] as String?,
      displayName: displayName,
      avatarUrl: json['avatar_url'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      bio: json['bio'] as String?,
      age: json['age'] as int?,
      city: json['city'] as String?,
      country: json['country'] as String?,
      phoneNumber:
          json['phone_number'] as String?, // from auth metadata if needed
      email: json['email'] as String?, // from auth.users if needed
      gender: json['gender'] as String?,
      profileType: json['profile_type'] as String?,
      intention: json['intention'] as String?,
      preferredSport: json['preferred_sport'] as String?,
      interests: json['interests'] as String?,
      language: json['language'] as String?,
      verified: json['verified'] as bool? ?? false,
      isActive: json['is_active'] as bool? ?? true,
      geoLat: (json['geo_lat'] as num?)?.toDouble(),
      geoLng: (json['geo_lng'] as num?)?.toDouble(),
      sportsProfiles: parsedSportsProfiles,
      statistics: const ProfileStatistics(),
      privacySettings: const PrivacySettings(),
      preferences: const UserPreferences(userId: ''),
      settings: const UserSettings(),
    );
  }

  /// Converts UserProfile to JSON (matching actual DB schema)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'username': username,
      'display_name': displayName,
      'avatar_url': avatarUrl,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'bio': bio,
      'age': age,
      'city': city,
      'country': country,
      'phone_number': phoneNumber,
      'email': email, // typically from auth.users
      'gender': gender,
      'profile_type': profileType,
      'intention': intention,
      'preferred_sport': preferredSport,
      'interests': interests,
      'language': language,
      'verified': verified,
      'is_active': isActive,
      'geo_lat': geoLat,
      'geo_lng': geoLng,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserProfile &&
        other.id == id &&
        other.userId == userId &&
        other.email == email &&
        other.username == username &&
        other.displayName == displayName &&
        other.avatarUrl == avatarUrl &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt &&
        other.bio == bio &&
        other.age == age &&
        other.city == city &&
        other.country == country &&
        other.phoneNumber == phoneNumber &&
        other.gender == gender &&
        other.profileType == profileType &&
        other.intention == intention &&
        other.preferredSport == preferredSport &&
        other.interests == interests &&
        other.language == language &&
        other.verified == verified &&
        other.isActive == isActive &&
        other.geoLat == geoLat &&
        other.geoLng == geoLng &&
        _listEquals(other.sportsProfiles, sportsProfiles) &&
        other.statistics == statistics &&
        other.privacySettings == privacySettings &&
        other.preferences == preferences &&
        other.settings == settings;
  }

  @override
  int get hashCode {
    return Object.hashAll([
      id,
      userId,
      email,
      username,
      displayName,
      avatarUrl,
      createdAt,
      updatedAt,
      bio,
      age,
      city,
      country,
      phoneNumber,
      gender,
      profileType,
      intention,
      preferredSport,
      interests,
      language,
      verified,
      isActive,
      geoLat,
      geoLng,
      Object.hashAll(sportsProfiles),
      statistics,
      privacySettings,
      preferences,
      settings,
    ]);
  }

  bool _listEquals<T>(List<T>? a, List<T>? b) {
    if (a == null) return b == null;
    if (b == null || a.length != b.length) return false;
    if (identical(a, b)) return true;
    for (int index = 0; index < a.length; index++) {
      if (a[index] != b[index]) return false;
    }
    return true;
  }
}
