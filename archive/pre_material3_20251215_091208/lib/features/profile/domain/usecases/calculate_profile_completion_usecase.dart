import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/utils/either.dart';
import 'package:dabbler/data/models/profile/user_profile.dart';
import 'package:dabbler/data/models/profile/sports_profile.dart';
import 'package:dabbler/data/models/profile/privacy_settings.dart';
import 'package:dabbler/data/models/profile/user_settings.dart';

/// Parameters for calculating profile completion
class CalculateProfileCompletionParams {
  final UserProfile profile;
  final Map<String, double>?
  fieldWeights; // Custom weights for different fields

  const CalculateProfileCompletionParams({
    required this.profile,
    this.fieldWeights,
  });
}

/// Result of profile completion calculation
class CalculateProfileCompletionResult {
  final double completionPercentage;
  final Map<String, bool> fieldCompletionStatus;
  final Map<String, double> fieldWeights;
  final List<String> missingRequiredFields;
  final List<String> missingSuggestedFields;
  final List<String> recommendations;
  final Map<String, double> categoryScores;

  const CalculateProfileCompletionResult({
    required this.completionPercentage,
    required this.fieldCompletionStatus,
    required this.fieldWeights,
    required this.missingRequiredFields,
    required this.missingSuggestedFields,
    required this.recommendations,
    required this.categoryScores,
  });
}

/// Use case for calculating profile completion with weighted scoring and recommendations
class CalculateProfileCompletionUseCase {
  CalculateProfileCompletionUseCase();

  Either<Failure, CalculateProfileCompletionResult> call(
    CalculateProfileCompletionParams params,
  ) {
    try {
      final profile = params.profile;

      // Define default field weights if not provided
      final fieldWeights = params.fieldWeights ?? _getDefaultFieldWeights();

      // Calculate field completion status
      final fieldCompletionStatus = _calculateFieldCompletion(profile);

      // Calculate category scores
      final categoryScores = _calculateCategoryScores(profile, fieldWeights);

      // Calculate overall completion percentage
      final completionPercentage = _calculateOverallCompletion(
        fieldCompletionStatus,
        fieldWeights,
      );

      // Identify missing fields
      final missingRequiredFields = _getMissingRequiredFields(
        fieldCompletionStatus,
      );
      final missingSuggestedFields = _getMissingSuggestedFields(
        fieldCompletionStatus,
      );

      // Generate recommendations
      final recommendations = _generateRecommendations(
        profile,
        fieldCompletionStatus,
        categoryScores,
      );

      return Right(
        CalculateProfileCompletionResult(
          completionPercentage: completionPercentage,
          fieldCompletionStatus: fieldCompletionStatus,
          fieldWeights: fieldWeights,
          missingRequiredFields: missingRequiredFields,
          missingSuggestedFields: missingSuggestedFields,
          recommendations: recommendations,
          categoryScores: categoryScores,
        ),
      );
    } catch (e) {
      return Left(
        DataFailure(message: 'Profile completion calculation failed: $e'),
      );
    }
  }

  /// Define default field weights
  Map<String, double> _getDefaultFieldWeights() {
    return {
      // Basic Information (40%)
      'display_name': 8.0,
      'email': 10.0,
      'first_name': 5.0,
      'last_name': 5.0,
      'bio': 8.0,
      'avatar': 4.0,

      // Personal Details (25%)
      'date_of_birth': 8.0,
      'gender': 3.0,
      'location': 8.0,
      'phone_number': 6.0,

      // Sports & Activities (25%)
      'sports_profiles': 15.0,
      'primary_sport': 5.0,
      'skill_levels': 5.0,

      // Settings & Preferences (10%)
      'privacy_settings': 3.0,
      'user_preferences': 4.0,
      'user_settings': 3.0,
    };
  }

  /// Calculate completion status for each field
  Map<String, bool> _calculateFieldCompletion(UserProfile profile) {
    return {
      // Basic Information
      'display_name': profile.displayName.isNotEmpty,
      'email': profile.email?.isNotEmpty ?? false,
      'first_name': profile.username?.isNotEmpty ?? false,
      'last_name': profile.displayName.isNotEmpty ?? false,
      'bio': profile.bio?.isNotEmpty ?? false,
      'avatar': profile.avatarUrl?.isNotEmpty ?? false,

      // Personal Details
      'date_of_birth': profile.age != null,
      'gender': profile.gender?.isNotEmpty ?? false,
      'location': profile.city?.isNotEmpty ?? false,
      'phone_number': profile.phoneNumber?.isNotEmpty ?? false,

      // Sports & Activities
      'sports_profiles': profile.sportsProfiles.isNotEmpty,
      'primary_sport': profile.sportsProfiles.any(
        (sport) => sport.isPrimarySport,
      ),
      'skill_levels': profile.sportsProfiles.any(
        (sport) => sport.skillLevel != SkillLevel.beginner,
      ),

      // Settings & Preferences
      'privacy_settings': _hasCompletedPrivacySettings(profile),
      'user_preferences': _hasCompletedPreferences(profile),
      'user_settings': _hasCompletedSettings(profile),
    };
  }

  /// Calculate category-based scores
  Map<String, double> _calculateCategoryScores(
    UserProfile profile,
    Map<String, double> fieldWeights,
  ) {
    final fieldCompletion = _calculateFieldCompletion(profile);
    final categories = <String, double>{};

    // Basic Information Category
    final basicFields = [
      'display_name',
      'email',
      'first_name',
      'last_name',
      'bio',
      'avatar',
    ];
    categories['basic_information'] = _calculateCategoryScore(
      basicFields,
      fieldCompletion,
      fieldWeights,
    );

    // Personal Details Category
    final personalFields = [
      'date_of_birth',
      'gender',
      'location',
      'phone_number',
    ];
    categories['personal_details'] = _calculateCategoryScore(
      personalFields,
      fieldCompletion,
      fieldWeights,
    );

    // Sports & Activities Category
    final sportsFields = ['sports_profiles', 'primary_sport', 'skill_levels'];
    categories['sports_activities'] = _calculateCategoryScore(
      sportsFields,
      fieldCompletion,
      fieldWeights,
    );

    // Settings & Preferences Category
    final settingsFields = [
      'privacy_settings',
      'user_preferences',
      'user_settings',
    ];
    categories['settings_preferences'] = _calculateCategoryScore(
      settingsFields,
      fieldCompletion,
      fieldWeights,
    );

    return categories;
  }

  /// Calculate score for a specific category
  double _calculateCategoryScore(
    List<String> fields,
    Map<String, bool> fieldCompletion,
    Map<String, double> fieldWeights,
  ) {
    double totalWeight = 0.0;
    double completedWeight = 0.0;

    for (final field in fields) {
      final weight = fieldWeights[field] ?? 0.0;
      totalWeight += weight;

      if (fieldCompletion[field] == true) {
        completedWeight += weight;
      }
    }

    return totalWeight > 0 ? (completedWeight / totalWeight * 100) : 0.0;
  }

  /// Calculate overall completion percentage
  double _calculateOverallCompletion(
    Map<String, bool> fieldCompletion,
    Map<String, double> fieldWeights,
  ) {
    double totalWeight = 0.0;
    double completedWeight = 0.0;

    for (final entry in fieldWeights.entries) {
      final field = entry.key;
      final weight = entry.value;

      totalWeight += weight;

      if (fieldCompletion[field] == true) {
        completedWeight += weight;
      }
    }

    return totalWeight > 0
        ? (completedWeight / totalWeight * 100).clamp(0.0, 100.0)
        : 0.0;
  }

  /// Get missing required fields
  List<String> _getMissingRequiredFields(Map<String, bool> fieldCompletion) {
    const requiredFields = [
      'display_name',
      'email',
      'bio',
      'date_of_birth',
      'location',
    ];

    return requiredFields
        .where((field) => fieldCompletion[field] != true)
        .toList();
  }

  /// Get missing suggested fields
  List<String> _getMissingSuggestedFields(Map<String, bool> fieldCompletion) {
    const suggestedFields = [
      'first_name',
      'last_name',
      'avatar',
      'phone_number',
      'sports_profiles',
      'gender',
    ];

    return suggestedFields
        .where((field) => fieldCompletion[field] != true)
        .toList();
  }

  /// Generate personalized recommendations
  List<String> _generateRecommendations(
    UserProfile profile,
    Map<String, bool> fieldCompletion,
    Map<String, double> categoryScores,
  ) {
    final recommendations = <String>[];

    // Critical missing information
    if (fieldCompletion['display_name'] != true) {
      recommendations.add('Add a display name to help others identify you');
    }

    if (fieldCompletion['bio'] != true) {
      recommendations.add('Write a bio to introduce yourself to other players');
    }

    if (fieldCompletion['avatar'] != true) {
      recommendations.add(
        'Upload a profile picture to make your profile more personal',
      );
    }

    if (fieldCompletion['location'] != true) {
      recommendations.add('Add your location to find nearby games and players');
    }

    if (fieldCompletion['date_of_birth'] != true) {
      recommendations.add(
        'Add your date of birth to find age-appropriate games',
      );
    }

    // Sports-related recommendations
    if (fieldCompletion['sports_profiles'] != true) {
      recommendations.add('Add your sports interests to find compatible games');
    } else if (!fieldCompletion['primary_sport']!) {
      recommendations.add(
        'Set a primary sport to better showcase your main interest',
      );
    }

    // Category-specific recommendations
    if (categoryScores['basic_information']! < 70) {
      recommendations.add(
        'Complete your basic information to improve profile visibility',
      );
    }

    if (categoryScores['sports_activities']! < 50) {
      recommendations.add(
        'Add more sports details to find better game matches',
      );
    }

    if (categoryScores['personal_details']! < 60) {
      recommendations.add(
        'Complete personal details for better player connections',
      );
    }

    // Phone number for better communication
    if (fieldCompletion['phone_number'] != true &&
        profile.sportsProfiles.isNotEmpty) {
      recommendations.add('Add a phone number for easier game coordination');
    }

    // Settings completion
    if (fieldCompletion['privacy_settings'] != true) {
      recommendations.add('Review and update your privacy settings');
    }

    // Gamification recommendations
    if (profile.sportsProfiles.isEmpty) {
      recommendations.add(
        'Join your first sport community to unlock profile features',
      );
    } else if (profile.sportsProfiles.length == 1) {
      recommendations.add('Add more sports to expand your game opportunities');
    }

    // Experience-based recommendations
    final totalGamesPlayed = profile.sportsProfiles.fold<int>(
      0,
      (sum, sport) => sum + sport.gamesPlayed,
    );

    if (totalGamesPlayed == 0) {
      recommendations.add(
        'Play your first game to start building your sports profile',
      );
    } else if (totalGamesPlayed > 10 && fieldCompletion['avatar'] != true) {
      recommendations.add(
        'You\'ve played several games! Add a photo to help teammates recognize you',
      );
    }

    return recommendations;
  }

  /// Check if privacy settings are meaningfully configured
  bool _hasCompletedPrivacySettings(UserProfile profile) {
    final settings = profile.privacySettings;

    // Check if user has made deliberate privacy choices (not all defaults)
    final hasCustomSettings =
        settings.profileVisibility != ProfileVisibility.public ||
        !settings.showEmail ||
        settings.messagePreference != CommunicationPreference.anyone ||
        settings.blockedUsers.isNotEmpty;

    return hasCustomSettings;
  }

  /// Check if preferences are configured
  bool _hasCompletedPreferences(UserProfile profile) {
    final preferences = profile.preferences;

    return preferences.preferredGameTypes.isNotEmpty ||
        preferences.weeklyAvailability.isNotEmpty ||
        preferences.maxTravelRadius > 15.0; // Default is 15.0
  }

  /// Check if settings are configured
  bool _hasCompletedSettings(UserProfile profile) {
    final settings = profile.settings;

    // Check if user has modified any settings from defaults
    return settings.language != 'en' ||
        settings.themeMode != ThemeMode.system ||
        !settings.enablePushNotifications ||
        settings.reminderMinutesBefore != 60;
  }
}
