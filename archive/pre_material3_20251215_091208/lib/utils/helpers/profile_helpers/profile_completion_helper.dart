/// Helper class for calculating and managing profile completion
library;

import 'dart:math';
import '../../enums/profile_enums.dart';
import '../../constants/profile_constants.dart';

/// Temporary model classes for profile helpers
class UserProfile {
  final String? fullName;
  final String? avatarUrl;
  final String? bio;
  final String? phoneNumber;
  final String? email;
  final DateTime? dateOfBirth;
  final String? gender;
  final String? username;
  final List<SportProfile> sportsProfiles;
  final bool hasPreferences;

  const UserProfile({
    this.fullName,
    this.avatarUrl,
    this.bio,
    this.phoneNumber,
    this.email,
    this.dateOfBirth,
    this.gender,
    this.username,
    this.sportsProfiles = const [],
    this.hasPreferences = false,
  });

  /// Derived age in years from dateOfBirth if present.
  int? get age {
    if (dateOfBirth == null) return null;
    final now = DateTime.now();
    int years = now.year - dateOfBirth!.year;
    if (now.month < dateOfBirth!.month ||
        (now.month == dateOfBirth!.month && now.day < dateOfBirth!.day)) {
      years -= 1;
    }
    return years;
  }
}

class SportProfile {
  final String sport;
  final int skillLevel;
  final int yearsPlaying;
  final bool isPrimarySport;
  final SportCategory category;

  const SportProfile({
    required this.sport,
    required this.skillLevel,
    required this.yearsPlaying,
    this.isPrimarySport = false,
    required this.category,
  });
}

/// Helper class for calculating profile completion and providing guidance
class ProfileCompletionHelper {
  /// Calculate the overall completion percentage of a user profile
  static int calculateCompletion(UserProfile profile) {
    int completion = 0;

    // Basic info section (40% total weight)
    if (profile.fullName?.isNotEmpty ?? false) {
      completion += ProfileCompletionWeights.basicInfoWeight ~/ 4; // 10%
    }
    if (profile.avatarUrl?.isNotEmpty ?? false) {
      completion += ProfileCompletionWeights.basicInfoWeight ~/ 4; // 10%
    }
    if (profile.bio?.isNotEmpty ?? false) {
      completion += ProfileCompletionWeights.basicInfoWeight ~/ 4; // 10%
    }
    if (profile.phoneNumber?.isNotEmpty ?? false) {
      completion += ProfileCompletionWeights.basicInfoWeight ~/ 4; // 10%
    }

    // Sports profiles section (30% total weight)
    if (profile.sportsProfiles.isNotEmpty) {
      // Award points based on number of sports, max 30%
      final sportsPoints = min(
        profile.sportsProfiles.length * 10,
        ProfileCompletionWeights.sportsProfileWeight,
      );
      completion += sportsPoints;
    }

    // Preferences section (30% total weight)
    if (profile.hasPreferences) {
      completion += ProfileCompletionWeights.preferencesWeight;
    }

    return min(completion, 100); // Cap at 100%
  }

  /// Calculate completion for individual profile sections
  static Map<String, int> calculateSectionCompletion(UserProfile profile) {
    final sections = <String, int>{};

    // Basic info completion
    int basicCompletion = 0;
    final basicFields = [
      profile.fullName?.isNotEmpty ?? false,
      profile.avatarUrl?.isNotEmpty ?? false,
      profile.bio?.isNotEmpty ?? false,
      profile.phoneNumber?.isNotEmpty ?? false,
      profile.age != null,
      profile.gender?.isNotEmpty ?? false,
    ];
    basicCompletion =
        (basicFields.where((field) => field).length / basicFields.length * 100)
            .round();
    sections['basic_info'] = basicCompletion;

    // Sports profile completion
    int sportsCompletion = 0;
    if (profile.sportsProfiles.isNotEmpty) {
      final completedSports = profile.sportsProfiles
          .where(
            (sport) =>
                sport.sport.isNotEmpty &&
                sport.skillLevel > 0 &&
                sport.yearsPlaying >= 0,
          )
          .length;
      sportsCompletion = min(
        (completedSports / max(profile.sportsProfiles.length, 1) * 100).round(),
        100,
      );
    }
    sections['sports'] = sportsCompletion;

    // Preferences completion
    sections['preferences'] = profile.hasPreferences ? 100 : 0;

    // Contact info completion
    int contactCompletion = 0;
    final contactFields = [
      profile.email?.isNotEmpty ?? false,
      profile.phoneNumber?.isNotEmpty ?? false,
    ];
    contactCompletion =
        (contactFields.where((field) => field).length /
                contactFields.length *
                100)
            .round();
    sections['contact'] = contactCompletion;

    return sections;
  }

  /// Get a list of missing or incomplete profile fields
  static List<String> getMissingFields(UserProfile profile) {
    final missing = <String>[];

    // Check basic required fields
    if (profile.fullName?.isEmpty ?? true) missing.add('Full name');
    if (profile.avatarUrl?.isEmpty ?? true) missing.add('Profile photo');
    if (profile.bio?.isEmpty ?? true) missing.add('Bio');
    if (profile.phoneNumber?.isEmpty ?? true) missing.add('Phone number');
    if (profile.age == null) missing.add('Date of birth');

    // Check sports profiles
    if (profile.sportsProfiles.isEmpty) {
      missing.add('Sports interests');
    } else {
      final incompleteSports = profile.sportsProfiles
          .where((sport) => sport.sport.isEmpty || sport.skillLevel == 0)
          .length;
      if (incompleteSports > 0) {
        missing.add('Complete sports profiles');
      }
    }

    // Check preferences
    if (!profile.hasPreferences) {
      missing.add('Game preferences');
    }

    return missing;
  }

  /// Get suggested fields to complete next (prioritized)
  static List<String> getSuggestedNextSteps(UserProfile profile) {
    final suggestions = <String>[];
    final missing = getMissingFields(profile);

    if (missing.isEmpty) return ['Your profile is complete!'];

    // Prioritize based on importance and user experience
    final priorityOrder = [
      'Profile photo',
      'Full name',
      'Sports interests',
      'Bio',
      'Game preferences',
      'Phone number',
      'Date of birth',
      'Complete sports profiles',
    ];

    for (final priority in priorityOrder) {
      if (missing.contains(priority)) {
        suggestions.add(priority);
      }
    }

    // Add any remaining missing fields
    for (final field in missing) {
      if (!suggestions.contains(field)) {
        suggestions.add(field);
      }
    }

    return suggestions;
  }

  /// Get the next step message with actionable guidance
  static String getNextStepMessage(UserProfile profile) {
    final missing = getMissingFields(profile);

    if (missing.isEmpty) {
      return 'Your profile is complete! You\'re ready to start playing.';
    }

    final suggestions = getSuggestedNextSteps(profile);
    if (suggestions.isNotEmpty) {
      return 'Next: Add ${suggestions.first.toLowerCase()} to improve your profile';
    }

    return 'Complete your profile to unlock all features';
  }

  /// Get completion level enum based on percentage
  static ProfileCompletionLevel getCompletionLevel(UserProfile profile) {
    final percentage = calculateCompletion(profile);
    return ProfileCompletionLevel.fromPercentage(percentage);
  }

  /// Check if profile meets minimum requirements for specific features
  static bool canCreateGames(UserProfile profile) {
    final completion = calculateCompletion(profile);
    return completion >= 30; // 30% minimum for game creation
  }

  static bool canSendMessages(UserProfile profile) {
    final completion = calculateCompletion(profile);
    return completion >= 60; // 60% minimum for messaging
  }

  static bool canJoinCompetitiveGames(UserProfile profile) {
    final completion = calculateCompletion(profile);
    return completion >= 85 && // 85% minimum for competitive play
        profile.sportsProfiles.isNotEmpty;
  }

  /// Get feature unlock status and requirements
  static Map<String, dynamic> getFeatureUnlockStatus(UserProfile profile) {
    final completion = calculateCompletion(profile);

    return {
      'current_completion': completion,
      'features': {
        'game_creation': {
          'unlocked': canCreateGames(profile),
          'required_completion': 30,
          'description': 'Create and organize games',
        },
        'messaging': {
          'unlocked': canSendMessages(profile),
          'required_completion': 60,
          'description': 'Send messages to other players',
        },
        'competitive_games': {
          'unlocked': canJoinCompetitiveGames(profile),
          'required_completion': 85,
          'description': 'Join competitive matches',
        },
      },
    };
  }

  /// Get completion rewards and milestones
  static List<String> getCompletionRewards(int completionPercentage) {
    final rewards = <String>[];

    if (completionPercentage >= 25) {
      rewards.add('Profile searchable by other players');
    }
    if (completionPercentage >= 50) {
      rewards.add('Can join games and send friend requests');
    }
    if (completionPercentage >= 75) {
      rewards.add('Can create and organize games');
    }
    if (completionPercentage >= 90) {
      rewards.add('Access to advanced features and competitive play');
    }
    if (completionPercentage >= 100) {
      rewards.add('Profile badge and priority in search results');
    }

    return rewards;
  }

  /// Generate completion tips based on current profile state
  static List<String> getCompletionTips(UserProfile profile) {
    final tips = <String>[];
    final missing = getMissingFields(profile);

    if (missing.contains('Profile photo')) {
      tips.add(
        'A profile photo increases your chances of getting game invites by 70%',
      );
    }
    if (missing.contains('Bio')) {
      tips.add(
        'Tell others about yourself - a good bio helps you find compatible teammates',
      );
    }
    if (missing.contains('Sports interests')) {
      tips.add(
        'Add your favorite sports to get personalized game recommendations',
      );
    }
    if (profile.sportsProfiles.length == 1) {
      tips.add(
        'Add more sports to discover new activities and meet more players',
      );
    }
    if (missing.contains('Game preferences')) {
      tips.add(
        'Set your preferences to get better matched with suitable games',
      );
    }

    // General tips for low completion
    final completion = calculateCompletion(profile);
    if (completion < 50) {
      tips.add('Complete profiles get 3x more game invitations');
    }

    return tips.take(3).toList(); // Limit to 3 tips to avoid overwhelming
  }

  /// Calculate estimated time to complete profile
  static String getEstimatedCompletionTime(UserProfile profile) {
    final missing = getMissingFields(profile);

    if (missing.isEmpty) return 'Complete!';

    // Estimate time based on missing fields (rough estimates)
    final timeEstimates = {
      'Profile photo': 2,
      'Full name': 1,
      'Bio': 3,
      'Sports interests': 5,
      'Game preferences': 3,
      'Phone number': 1,
      'Date of birth': 1,
      'Complete sports profiles': 4,
    };

    int totalMinutes = 0;
    for (final field in missing) {
      totalMinutes += timeEstimates[field] ?? 2;
    }

    if (totalMinutes < 5) return 'Less than 5 minutes';
    if (totalMinutes < 15) return 'About 10 minutes';
    if (totalMinutes < 30) return 'About 20 minutes';
    return 'About 30 minutes';
  }
}
