import 'package:supabase_flutter/supabase_flutter.dart';

/// Gamification system for onboarding
class OnboardingGamification {
  final SupabaseClient _supabase;

  OnboardingGamification({required SupabaseClient supabase})
    : _supabase = supabase;

  /// Get user's current points
  Future<int> getUserPoints(String userId) async {
    try {
      final response = await _supabase
          .from('user_points')
          .select('points')
          .eq('user_id', userId);

      return response.fold<int>(
        0,
        (sum, item) => sum + (item['points'] as int),
      );
    } catch (e) {
      return 0;
    }
  }

  /// Award points for completing actions
  Future<void> awardPoints(
    String userId,
    int points,
    String source,
    String description,
  ) async {
    try {
      await _supabase.from('user_points').insert({
        'user_id': userId,
        'points': points,
        'source': source,
        'description': description,
        'created_at': DateTime.now().toIso8601String(),
      });

      // Check for new badges
      await _checkAndAwardBadges(userId);
    } catch (e) {}
  }

  /// Get user's badges
  Future<List<Badge>> getUserBadges(String userId) async {
    try {
      final response = await _supabase
          .from('user_badges')
          .select('*, badge_definitions(*)')
          .eq('user_id', userId)
          .order('awarded_at', ascending: false);

      return response.map<Badge>((item) => Badge.fromJson(item)).toList();
    } catch (e) {
      return [];
    }
  }

  /// Check and award new badges based on progress
  Future<List<Badge>> _checkAndAwardBadges(String userId) async {
    try {
      final points = await getUserPoints(userId);
      final newBadges = <Badge>[];

      // Define badge criteria
      final badgeCriteria = <Map<String, dynamic>>[
        {
          'id': 'onboarding_starter',
          'points': 25,
          'name': 'Getting Started',
          'description': 'Started your onboarding journey',
        },
        {
          'id': 'profile_complete',
          'points': 50,
          'name': 'Profile Complete',
          'description': 'Completed basic profile information',
        },
        {
          'id': 'sports_enthusiast',
          'points': 75,
          'name': 'Sports Enthusiast',
          'description': 'Added multiple sports preferences',
        },
        {
          'id': 'onboarding_champion',
          'points': 100,
          'name': 'Onboarding Champion',
          'description': 'Completed entire onboarding flow',
        },
      ];

      // Check existing badges
      final existingBadges = await _supabase
          .from('user_badges')
          .select('badge_id')
          .eq('user_id', userId);

      final existingBadgeIds = existingBadges.map((b) => b['badge_id']).toSet();

      // Award new badges
      for (final criteria in badgeCriteria) {
        if (points >= criteria['points']! &&
            !existingBadgeIds.contains(criteria['id'])) {
          await _supabase.from('user_badges').insert({
            'user_id': userId,
            'badge_id': criteria['id'],
            'awarded_at': DateTime.now().toIso8601String(),
          });

          newBadges.add(
            Badge(
              id: criteria['id'] as String,
              name: criteria['name'] as String,
              description: criteria['description'] as String,
              iconUrl: 'assets/badges/${criteria['id']}.png',
              awardedAt: DateTime.now(),
            ),
          );
        }
      }

      return newBadges;
    } catch (e) {
      return [];
    }
  }

  /// Get achievement for step completion
  Achievement getStepAchievement(int step, String variant) {
    final achievements = {
      1: Achievement(
        title: variant == 'gamified'
            ? '🎯 Profile Created!'
            : 'Profile Created!',
        description: variant == 'gamified'
            ? 'You earned 25 points!'
            : 'Looking good!',
        points: variant == 'gamified' ? 25 : 0,
        iconUrl: 'assets/achievements/profile_created.png',
      ),
      2: Achievement(
        title: variant == 'gamified' ? '🏆 Sports Added!' : 'Sports Selected!',
        description: variant == 'gamified'
            ? 'You earned 30 points!'
            : 'Ready to play!',
        points: variant == 'gamified' ? 30 : 0,
        iconUrl: 'assets/achievements/sports_added.png',
      ),
      3: Achievement(
        title: variant == 'gamified'
            ? '📍 Preferences Set!'
            : 'Preferences Set!',
        description: variant == 'gamified'
            ? 'You earned 25 points!'
            : 'We\'ll find perfect games!',
        points: variant == 'gamified' ? 25 : 0,
        iconUrl: 'assets/achievements/preferences_set.png',
      ),
      4: Achievement(
        title: variant == 'gamified'
            ? '🔒 Privacy Secured!'
            : 'Privacy Settings Complete!',
        description: variant == 'gamified'
            ? 'You earned 20 points!'
            : 'Your data is protected!',
        points: variant == 'gamified' ? 20 : 0,
        iconUrl: 'assets/achievements/privacy_set.png',
      ),
    };

    return achievements[step] ?? Achievement.empty();
  }

  /// Get completion celebration data
  Future<CompletionCelebration> getCompletionCelebration(
    String userId,
    String variant,
  ) async {
    final totalPoints = await getUserPoints(userId);
    final badges = await getUserBadges(userId);

    return CompletionCelebration(
      title: variant == 'gamified'
          ? '🎉 Congratulations Champion!'
          : '🎉 Welcome to Dabbler!',
      subtitle: variant == 'gamified'
          ? 'You\'ve earned $totalPoints points and ${badges.length} badges!'
          : 'Your profile is complete and ready to go!',
      totalPoints: totalPoints,
      newBadges: badges,
      nextSteps: [
        'Explore games in your area',
        'Join your first game',
        'Connect with other players',
      ],
      specialOffer: _getSpecialOffer(variant),
    );
  }

  /// Get special completion offer based on variant
  SpecialOffer? _getSpecialOffer(String variant) {
    if (variant == 'gamified') {
      return SpecialOffer(
        title: 'Limited Time Bonus!',
        description:
            'Complete your first game booking within 24 hours and get 50 bonus points!',
        expiresAt: DateTime.now().add(const Duration(hours: 24)),
        ctaText: 'Find Games Now',
      );
    }
    return null;
  }

  /// Generate completion celebration (alias for getCompletionCelebration)
  Future<CompletionCelebration> generateCompletionCelebration(
    String userId,
  ) async {
    return getCompletionCelebration(userId, 'gamified');
  }

  /// Get unlocked badges for user
  Future<List<Badge>> getUnlockedBadges(String userId) async {
    return getUserBadges(userId);
  }

  /// Calculate profile strength for user
  Future<double> calculateProfileStrength(String userId) async {
    try {
      final response = await _supabase
          .from('user_profiles')
          .select('*')
          .eq('user_id', userId)
          .single();

      return ProfileStrengthCalculator.calculate(response).toDouble();
    } catch (e) {
      return 0.0;
    }
  }

  /// Get next suggested action for user
  Future<String> getNextSuggestedAction(String userId) async {
    try {
      final response = await _supabase
          .from('user_profiles')
          .select('*')
          .eq('user_id', userId)
          .single();

      final strength = ProfileStrengthCalculator.calculate(response);
      final suggestions = ProfileStrengthCalculator.getSuggestions(
        response,
        strength,
      );
      return suggestions.isNotEmpty
          ? suggestions.first
          : 'Complete your profile to get started!';
    } catch (e) {
      return 'Complete your profile to get started!';
    }
  }
}

/// Badge model
class Badge {
  final String id;
  final String name;
  final String description;
  final String iconUrl;
  final DateTime awardedAt;

  Badge({
    required this.id,
    required this.name,
    required this.description,
    required this.iconUrl,
    required this.awardedAt,
  });

  factory Badge.fromJson(Map<String, dynamic> json) {
    return Badge(
      id: json['badge_id'] ?? json['id'],
      name: json['badge_definitions']?['name'] ?? json['name'],
      description:
          json['badge_definitions']?['description'] ?? json['description'],
      iconUrl: json['badge_definitions']?['icon_url'] ?? json['icon_url'],
      awardedAt: DateTime.parse(json['awarded_at']),
    );
  }
}

/// Achievement model
class Achievement {
  final String title;
  final String description;
  final int points;
  final String iconUrl;

  Achievement({
    required this.title,
    required this.description,
    required this.points,
    required this.iconUrl,
  });

  factory Achievement.empty() {
    return Achievement(title: '', description: '', points: 0, iconUrl: '');
  }
}

/// Completion celebration model
class CompletionCelebration {
  final String title;
  final String subtitle;
  final int totalPoints;
  final List<Badge> newBadges;
  final List<String> nextSteps;
  final SpecialOffer? specialOffer;

  CompletionCelebration({
    required this.title,
    required this.subtitle,
    required this.totalPoints,
    required this.newBadges,
    required this.nextSteps,
    this.specialOffer,
  });
}

/// Special offer model
class SpecialOffer {
  final String title;
  final String description;
  final DateTime expiresAt;
  final String ctaText;

  SpecialOffer({
    required this.title,
    required this.description,
    required this.expiresAt,
    required this.ctaText,
  });
}

/// Profile strength calculator
class ProfileStrengthCalculator {
  static int calculate(Map<String, dynamic> profileData) {
    int strength = 0;

    // Basic information (30 points)
    if (profileData['display_name']?.isNotEmpty == true) strength += 10;
    if (profileData['photo'] != null) strength += 15;
    if (profileData['bio']?.isNotEmpty == true) strength += 5;

    // Sports and skills (40 points)
    final sports = profileData['sports'] as List?;
    if (sports != null && sports.isNotEmpty) {
      strength += (sports.length * 5).clamp(0, 25); // Max 25 for sports
      if (profileData['skill_levels'] != null) strength += 15; // Skill levels
    }

    // Preferences and availability (25 points)
    if (profileData['location_preferences'] != null) strength += 10;
    if (profileData['availability'] != null) strength += 10;
    if (profileData['game_preferences'] != null) strength += 5;

    // Social and verification (5 points)
    if (profileData['social_links'] != null) strength += 3;
    if (profileData['verified'] == true) strength += 2;

    return strength.clamp(0, 100);
  }

  static String getStrengthDescription(int strength) {
    if (strength >= 90) return 'Outstanding Profile! 🌟';
    if (strength >= 75) return 'Great Profile! 🎯';
    if (strength >= 50) return 'Good Profile! 👍';
    if (strength >= 25) return 'Getting Started! 🌱';
    return 'Let\'s Build Your Profile! 🚀';
  }

  static List<String> getSuggestions(
    Map<String, dynamic> profileData,
    int currentStrength,
  ) {
    final suggestions = <String>[];

    if (profileData['photo'] == null && currentStrength < 90) {
      suggestions.add('Add a profile photo (+15 points)');
    }

    if (profileData['bio']?.isEmpty == true && currentStrength < 95) {
      suggestions.add('Write a short bio (+5 points)');
    }

    final sports = profileData['sports'] as List?;
    if (sports == null || sports.isEmpty) {
      suggestions.add('Add your favorite sports (+25 points)');
    } else if (profileData['skill_levels'] == null) {
      suggestions.add('Rate your skill levels (+15 points)');
    }

    if (profileData['availability'] == null && currentStrength < 85) {
      suggestions.add('Set your availability (+10 points)');
    }

    if (profileData['location_preferences'] == null && currentStrength < 85) {
      suggestions.add('Add location preferences (+10 points)');
    }

    return suggestions.take(3).toList(); // Show max 3 suggestions
  }
}
