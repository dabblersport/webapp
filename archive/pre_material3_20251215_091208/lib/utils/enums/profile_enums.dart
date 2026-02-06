/// Profile-related enum definitions for status, completion levels, and sport categories
library;

import 'package:flutter/material.dart';

/// Enum representing the current status of a user profile
enum ProfileStatus {
  active('active'),
  inactive('inactive'),
  suspended('suspended'),
  deleted('deleted');

  final String value;
  const ProfileStatus(this.value);

  /// Create ProfileStatus from string value
  static ProfileStatus fromString(String value) =>
      ProfileStatus.values.firstWhere((e) => e.value == value);

  /// Get display name for the profile status
  String get displayName {
    switch (this) {
      case ProfileStatus.active:
        return 'Active';
      case ProfileStatus.inactive:
        return 'Inactive';
      case ProfileStatus.suspended:
        return 'Suspended';
      case ProfileStatus.deleted:
        return 'Deleted';
    }
  }

  /// Check if profile is accessible for viewing
  bool get isAccessible {
    return this == ProfileStatus.active;
  }

  /// Get color representation for the status
  Color get color {
    switch (this) {
      case ProfileStatus.active:
        return Colors.green;
      case ProfileStatus.inactive:
        return Colors.orange;
      case ProfileStatus.suspended:
        return Colors.red;
      case ProfileStatus.deleted:
        return Colors.grey;
    }
  }
}

/// Enum representing different levels of profile completion
enum ProfileCompletionLevel {
  incomplete(0, 30, 'Complete your profile'),
  basic(30, 60, 'Add more details'),
  intermediate(60, 85, 'Almost there'),
  complete(85, 100, 'Profile complete');

  final int minPercentage;
  final int maxPercentage;
  final String message;
  const ProfileCompletionLevel(
    this.minPercentage,
    this.maxPercentage,
    this.message,
  );

  /// Get completion level from percentage value
  static ProfileCompletionLevel fromPercentage(int percentage) {
    return ProfileCompletionLevel.values.firstWhere(
      (level) =>
          percentage >= level.minPercentage && percentage < level.maxPercentage,
      orElse: () => ProfileCompletionLevel.complete,
    );
  }

  /// Get color representation for the completion level
  Color get color {
    switch (this) {
      case ProfileCompletionLevel.incomplete:
        return Colors.red;
      case ProfileCompletionLevel.basic:
        return Colors.orange;
      case ProfileCompletionLevel.intermediate:
        return Colors.blue;
      case ProfileCompletionLevel.complete:
        return Colors.green;
    }
  }

  /// Get icon representation for the completion level
  IconData get icon {
    switch (this) {
      case ProfileCompletionLevel.incomplete:
        return Icons.error_outline;
      case ProfileCompletionLevel.basic:
        return Icons.warning_outlined;
      case ProfileCompletionLevel.intermediate:
        return Icons.info_outline;
      case ProfileCompletionLevel.complete:
        return Icons.check_circle_outline;
    }
  }

  /// Check if profile completion level allows certain features
  bool get allowsGameCreation => minPercentage >= 30;
  bool get allowsMessaging => minPercentage >= 60;
  bool get allowsAdvancedFeatures => minPercentage >= 85;
}

/// Enum representing different sport categories
enum SportCategory {
  team('team', 'Team Sports', Icons.groups),
  individual('individual', 'Individual Sports', Icons.person),
  racquet('racquet', 'Racquet Sports', Icons.sports_tennis),
  water('water', 'Water Sports', Icons.pool),
  winter('winter', 'Winter Sports', Icons.ac_unit),
  other('other', 'Other Sports', Icons.sports);

  final String value;
  final String displayName;
  final IconData icon;
  const SportCategory(this.value, this.displayName, this.icon);

  /// Create SportCategory from string value
  static SportCategory fromString(String value) => SportCategory.values
      .firstWhere((e) => e.value == value, orElse: () => SportCategory.other);

  /// Get color representation for the sport category
  Color get color {
    switch (this) {
      case SportCategory.team:
        return Colors.blue;
      case SportCategory.individual:
        return Colors.green;
      case SportCategory.racquet:
        return Colors.orange;
      case SportCategory.water:
        return Colors.cyan;
      case SportCategory.winter:
        return Colors.lightBlue;
      case SportCategory.other:
        return Colors.grey;
    }
  }

  /// Get example sports for this category
  List<String> get exampleSports {
    switch (this) {
      case SportCategory.team:
        return ['Football', 'Basketball', 'Soccer', 'Volleyball', 'Baseball'];
      case SportCategory.individual:
        return ['Running', 'Swimming', 'Cycling', 'Golf', 'Tennis'];
      case SportCategory.racquet:
        return ['Tennis', 'Badminton', 'Squash', 'Table Tennis', 'Racquetball'];
      case SportCategory.water:
        return ['Swimming', 'Surfing', 'Kayaking', 'Water Polo', 'Sailing'];
      case SportCategory.winter:
        return [
          'Skiing',
          'Snowboarding',
          'Ice Hockey',
          'Figure Skating',
          'Curling',
        ];
      case SportCategory.other:
        return ['Mixed Martial Arts', 'Rock Climbing', 'Gymnastics', 'Dancing'];
    }
  }
}

/// Enum representing different age groups for profile categorization
enum AgeGroup {
  teen(13, 17, 'Teen'),
  youngAdult(18, 25, 'Young Adult'),
  adult(26, 40, 'Adult'),
  middleAged(41, 60, 'Middle Aged'),
  senior(61, 120, 'Senior');

  final int minAge;
  final int maxAge;
  final String displayName;
  const AgeGroup(this.minAge, this.maxAge, this.displayName);

  /// Get age group from age value
  static AgeGroup fromAge(int age) {
    return AgeGroup.values.firstWhere(
      (group) => age >= group.minAge && age <= group.maxAge,
      orElse: () => AgeGroup.adult,
    );
  }

  /// Get all age groups as a list of display names
  static List<String> get allDisplayNames =>
      AgeGroup.values.map((e) => e.displayName).toList();
}

/// Enum representing different profile verification statuses
enum VerificationStatus {
  unverified('unverified', 'Unverified', Icons.help_outline, Colors.grey),
  pending('pending', 'Pending', Icons.schedule, Colors.orange),
  verified('verified', 'Verified', Icons.verified, Colors.blue),
  rejected('rejected', 'Rejected', Icons.cancel, Colors.red);

  final String value;
  final String displayName;
  final IconData icon;
  final Color color;
  const VerificationStatus(this.value, this.displayName, this.icon, this.color);

  /// Create VerificationStatus from string value
  static VerificationStatus fromString(String value) =>
      VerificationStatus.values.firstWhere(
        (e) => e.value == value,
        orElse: () => VerificationStatus.unverified,
      );

  /// Check if verification allows certain features
  bool get allowsVerifiedBadge => this == VerificationStatus.verified;
  bool get canRequestVerification => this == VerificationStatus.unverified;
}
