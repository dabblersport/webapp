import 'package:dabbler/data/models/rewards/tier.dart';

/// Data model for UserTier with JSON serialization and benefits parsing
class TierModel extends UserTier {
  /// Additional properties for enhanced tier management
  final Map<String, dynamic> benefitsBreakdown;
  final Map<String, dynamic> privilegesBreakdown;
  final Map<String, dynamic> progressData;
  final Map<String, dynamic> comparisonData;

  const TierModel({
    required super.id,
    required super.userId,
    required super.level,
    required super.currentPoints,
    required super.pointsInTier,
    super.benefits = const {},
    super.privileges = const {},
    super.customization = const {},
    required super.achievedAt,
    super.previousTierAt,
    super.hasNotificationSent = false,
    required super.createdAt,
    required super.updatedAt,
    this.benefitsBreakdown = const {},
    this.privilegesBreakdown = const {},
    this.progressData = const {},
    this.comparisonData = const {},
  });

  /// Creates a TierModel from JSON
  factory TierModel.fromJson(Map<String, dynamic> json) {
    return TierModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      level: _parseTierLevel(json['level']),
      currentPoints: _parseDouble(json['current_points']),
      pointsInTier: _parseDouble(json['points_in_tier']),
      benefits: _parseMap(json['benefits']),
      privileges: _parseMap(json['privileges']),
      customization: _parseStringMap(json['customization']),
      achievedAt: _parseDateTime(json['achieved_at'])!,
      previousTierAt: _parseDateTime(json['previous_tier_at']),
      hasNotificationSent: json['has_notification_sent'] as bool? ?? false,
      createdAt: _parseDateTime(json['created_at'])!,
      updatedAt: _parseDateTime(json['updated_at'])!,
      benefitsBreakdown: _parseMap(json['benefits_breakdown']),
      privilegesBreakdown: _parseMap(json['privileges_breakdown']),
      progressData: _parseMap(json['progress_data']),
      comparisonData: _parseMap(json['comparison_data']),
    );
  }

  /// Converts the model to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'level': level.level,
      'level_name': level.displayName,
      'current_points': currentPoints,
      'points_in_tier': pointsInTier,
      'benefits': benefits,
      'privileges': privileges,
      'customization': customization,
      'achieved_at': achievedAt.toIso8601String(),
      'previous_tier_at': previousTierAt?.toIso8601String(),
      'has_notification_sent': hasNotificationSent,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'benefits_breakdown': benefitsBreakdown,
      'privileges_breakdown': privilegesBreakdown,
      'progress_data': progressData,
      'comparison_data': comparisonData,
    };
  }

  /// Creates a copy as TierModel
  @override
  TierModel copyWith({
    String? id,
    String? userId,
    TierLevel? level,
    double? currentPoints,
    double? pointsInTier,
    Map<String, dynamic>? benefits,
    Map<String, dynamic>? privileges,
    Map<String, String>? customization,
    DateTime? achievedAt,
    DateTime? previousTierAt,
    bool? hasNotificationSent,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, dynamic>? benefitsBreakdown,
    Map<String, dynamic>? privilegesBreakdown,
    Map<String, dynamic>? progressData,
    Map<String, dynamic>? comparisonData,
  }) {
    return TierModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      level: level ?? this.level,
      currentPoints: currentPoints ?? this.currentPoints,
      pointsInTier: pointsInTier ?? this.pointsInTier,
      benefits: benefits ?? this.benefits,
      privileges: privileges ?? this.privileges,
      customization: customization ?? this.customization,
      achievedAt: achievedAt ?? this.achievedAt,
      previousTierAt: previousTierAt ?? this.previousTierAt,
      hasNotificationSent: hasNotificationSent ?? this.hasNotificationSent,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      benefitsBreakdown: benefitsBreakdown ?? this.benefitsBreakdown,
      privilegesBreakdown: privilegesBreakdown ?? this.privilegesBreakdown,
      progressData: progressData ?? this.progressData,
      comparisonData: comparisonData ?? this.comparisonData,
    );
  }

  // Static parsing methods

  static TierLevel _parseTierLevel(dynamic value) {
    if (value == null) return TierLevel.freshPlayer;

    if (value is int) {
      return TierLevel.fromLevel(value) ?? TierLevel.freshPlayer;
    }

    if (value is String) {
      // Try to parse as level number
      final levelNum = int.tryParse(value);
      if (levelNum != null) {
        return TierLevel.fromLevel(levelNum) ?? TierLevel.freshPlayer;
      }

      // Try to parse as tier name
      for (final tier in TierLevel.values) {
        if (tier.name.toLowerCase() == value.toLowerCase() ||
            tier.displayName.toLowerCase() == value.toLowerCase()) {
          return tier;
        }
      }
    }

    return TierLevel.freshPlayer;
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  static Map<String, dynamic> _parseMap(dynamic value) {
    if (value == null) return {};
    if (value is Map<String, dynamic>) return Map<String, dynamic>.from(value);
    if (value is Map) return Map<String, dynamic>.from(value);
    return {};
  }

  static Map<String, String> _parseStringMap(dynamic value) {
    if (value == null) return {};
    if (value is Map<String, String>) return Map<String, String>.from(value);
    if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), v.toString()));
    }
    return {};
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (e) {
        return null;
      }
    }
    if (value is DateTime) return value;
    return null;
  }

  /// Creates a TierModel from Supabase row
  factory TierModel.fromSupabase(Map<String, dynamic> data) {
    return TierModel.fromJson({
      ...data,
      'user_id': data['user_id'] ?? data['userId'],
      'current_points': data['current_points'] ?? data['currentPoints'],
      'points_in_tier': data['points_in_tier'] ?? data['pointsInTier'],
      'achieved_at': data['achieved_at'] ?? data['achievedAt'],
      'previous_tier_at': data['previous_tier_at'] ?? data['previousTierAt'],
      'has_notification_sent':
          data['has_notification_sent'] ?? data['hasNotificationSent'],
      'created_at': data['created_at'] ?? data['createdAt'],
      'updated_at': data['updated_at'] ?? data['updatedAt'],
      'benefits_breakdown':
          data['benefits_breakdown'] ?? data['benefitsBreakdown'],
      'privileges_breakdown':
          data['privileges_breakdown'] ?? data['privilegesBreakdown'],
      'progress_data': data['progress_data'] ?? data['progressData'],
      'comparison_data': data['comparison_data'] ?? data['comparisonData'],
    });
  }

  /// Converts to format suitable for Supabase insertion
  Map<String, dynamic> toSupabase() {
    final json = toJson();
    json.removeWhere((key, value) => value == null);

    return {
      ...json,
      'user_id': json['user_id'],
      'current_points': json['current_points'],
      'points_in_tier': json['points_in_tier'],
      'achieved_at': json['achieved_at'],
      'previous_tier_at': json['previous_tier_at'],
      'has_notification_sent': json['has_notification_sent'],
      'created_at': json['created_at'],
      'updated_at': json['updated_at'],
      'benefits_breakdown': json['benefits_breakdown'],
      'privileges_breakdown': json['privileges_breakdown'],
      'progress_data': json['progress_data'],
      'comparison_data': json['comparison_data'],
    };
  }

  /// Creates a mock TierModel for testing
  factory TierModel.mock({
    String? id,
    String? userId,
    TierLevel level = TierLevel.novice,
    double? currentPoints,
    double? pointsInTier,
  }) {
    final points = currentPoints ?? (level.minPoints + 50);
    return TierModel(
      id: id ?? 'mock_tier',
      userId: userId ?? 'mock_user',
      level: level,
      currentPoints: points,
      pointsInTier: points - level.minPoints,
      achievedAt: DateTime.now().subtract(const Duration(days: 30)),
      createdAt: DateTime.now().subtract(const Duration(days: 30)),
      updatedAt: DateTime.now(),
    );
  }

  /// Creates TierModel with calculated benefits and privileges
  factory TierModel.withCalculatedData({
    required String id,
    required String userId,
    required TierLevel level,
    required double currentPoints,
    DateTime? achievedAt,
    DateTime? previousTierAt,
    bool hasNotificationSent = false,
  }) {
    final now = DateTime.now();
    final pointsInCurrentTier = currentPoints - level.minPoints;

    // Create base tier
    final baseTier = TierModel(
      id: id,
      userId: userId,
      level: level,
      currentPoints: currentPoints,
      pointsInTier: pointsInCurrentTier,
      achievedAt: achievedAt ?? now,
      previousTierAt: previousTierAt,
      hasNotificationSent: hasNotificationSent,
      createdAt: now,
      updatedAt: now,
    );

    // Calculate benefits and privileges
    final calculatedBenefits = baseTier.getDefaultBenefits();
    final calculatedPrivileges = baseTier.getDefaultPrivileges();
    final progressData = baseTier._calculateProgressData();
    final comparisonData = baseTier._calculateComparisonData();

    return baseTier.copyWith(
      benefits: calculatedBenefits,
      privileges: calculatedPrivileges,
      benefitsBreakdown: _generateBenefitsBreakdown(calculatedBenefits),
      privilegesBreakdown: _generatePrivilegesBreakdown(calculatedPrivileges),
      progressData: progressData,
      comparisonData: comparisonData,
    );
  }

  static Map<String, dynamic> _generateBenefitsBreakdown(
    Map<String, dynamic> benefits,
  ) {
    final breakdown = <String, dynamic>{};

    for (final entry in benefits.entries) {
      final key = entry.key;
      final value = entry.value;

      breakdown[key] = {
        'value': value,
        'description': _getBenefitDescription(key),
        'category': _getBenefitCategory(key),
        'is_active': value is bool ? value : true,
        'numeric_value': value is num ? value : null,
      };
    }

    return breakdown;
  }

  static Map<String, dynamic> _generatePrivilegesBreakdown(
    Map<String, dynamic> privileges,
  ) {
    final breakdown = <String, dynamic>{};

    for (final entry in privileges.entries) {
      final key = entry.key;
      final value = entry.value;

      breakdown[key] = {
        'enabled': value,
        'description': _getPrivilegeDescription(key),
        'category': _getPrivilegeCategory(key),
        'unlock_level': _getPrivilegeUnlockLevel(key),
      };
    }

    return breakdown;
  }

  static String _getBenefitDescription(String key) {
    switch (key) {
      case 'daily_point_bonus':
        return 'Extra points earned daily';
      case 'achievement_point_multiplier':
        return 'Multiplier for achievement points';
      case 'leaderboard_highlight':
        return 'Highlighted on leaderboards';
      case 'custom_profile_themes':
        return 'Access to custom profile themes';
      case 'priority_matchmaking':
        return 'Faster matchmaking priority';
      case 'exclusive_events_access':
        return 'Access to exclusive events';
      case 'early_feature_access':
        return 'Early access to new features';
      case 'monthly_exclusive_rewards':
        return 'Monthly exclusive reward items';
      default:
        return 'Tier benefit';
    }
  }

  static String _getBenefitCategory(String key) {
    if (key.contains('point')) return 'Points & Rewards';
    if (key.contains('profile') || key.contains('customization')) {
      return 'Customization';
    }
    if (key.contains('matchmaking') || key.contains('priority')) {
      return 'Gameplay';
    }
    if (key.contains('event') || key.contains('access')) return 'Access';
    return 'General';
  }

  static String _getPrivilegeDescription(String key) {
    switch (key) {
      case 'create_private_tournaments':
        return 'Create private tournaments';
      case 'invite_friends_to_events':
        return 'Invite friends to events';
      case 'access_advanced_statistics':
        return 'View advanced statistics';
      case 'custom_game_settings':
        return 'Customize game settings';
      case 'priority_customer_support':
        return 'Priority customer support';
      case 'beta_testing_participation':
        return 'Participate in beta testing';
      case 'influence_game_development':
        return 'Influence game development';
      default:
        return 'Tier privilege';
    }
  }

  static String _getPrivilegeCategory(String key) {
    if (key.contains('tournament') || key.contains('game')) return 'Gameplay';
    if (key.contains('social') || key.contains('friends')) return 'Social';
    if (key.contains('support') || key.contains('beta')) return 'Support';
    if (key.contains('statistics') || key.contains('data')) return 'Analytics';
    return 'General';
  }

  static int _getPrivilegeUnlockLevel(String key) {
    switch (key) {
      case 'invite_friends_to_events':
        return 4;
      case 'create_private_tournaments':
        return 6;
      case 'access_advanced_statistics':
        return 8;
      case 'custom_game_settings':
        return 10;
      case 'priority_customer_support':
        return 12;
      case 'beta_testing_participation':
        return 14;
      case 'influence_game_development':
        return 15;
      default:
        return 1;
    }
  }

  /// Calculates progress data
  Map<String, dynamic> _calculateProgressData() {
    final nextTier = getNextTier();
    final progress = calculateProgress();
    final pointsToNext = getPointsToNextTier();

    return {
      'current_progress_percentage': progress,
      'points_to_next_tier': pointsToNext,
      'next_tier': nextTier?.displayName,
      'next_tier_level': nextTier?.level,
      'is_max_tier': level.isMaxTier,
      'points_in_current_tier': pointsInTier,
      'tier_point_range': level.pointsRange,
      'days_in_current_tier': DateTime.now().difference(achievedAt).inDays,
      'estimated_days_to_next': pointsToNext > 0
          ? _estimateDaysToNextTier()
          : null,
    };
  }

  int? _estimateDaysToNextTier() {
    final pointsToNext = getPointsToNextTier();
    if (pointsToNext <= 0) return null;

    // Simple estimation based on current tier progress rate
    final daysInTier = DateTime.now().difference(achievedAt).inDays;
    if (daysInTier <= 0) return null;

    final pointsPerDay = pointsInTier / daysInTier;
    if (pointsPerDay <= 0) return null;

    return (pointsToNext / pointsPerDay).ceil();
  }

  /// Calculates comparison data with other tiers
  Map<String, dynamic> _calculateComparisonData() {
    final allTiers = TierLevel.values;
    final currentIndex = allTiers.indexOf(level);

    return {
      'tier_position': '${currentIndex + 1} of ${allTiers.length}',
      'tiers_above': allTiers.length - currentIndex - 1,
      'tiers_below': currentIndex,
      'percentage_of_max': (currentIndex + 1) / allTiers.length * 100,
      'previous_tier': currentIndex > 0
          ? allTiers[currentIndex - 1].displayName
          : null,
      'next_tier': currentIndex < allTiers.length - 1
          ? allTiers[currentIndex + 1].displayName
          : null,
      'is_top_tier': level.isMaxTier,
      'is_bottom_tier': currentIndex == 0,
      'tier_category': _getTierCategory(),
    };
  }

  String _getTierCategory() {
    if (level.level <= 3) return 'Beginner';
    if (level.level <= 7) return 'Intermediate';
    if (level.level <= 11) return 'Advanced';
    if (level.level <= 14) return 'Expert';
    return 'Master';
  }

  /// Gets next tier preview data
  Map<String, dynamic>? getNextTierPreview() {
    final nextTier = getNextTier();
    if (nextTier == null) return null;

    final mockNextTierModel = TierModel.withCalculatedData(
      id: 'preview',
      userId: userId,
      level: nextTier,
      currentPoints: nextTier.minPoints,
    );

    return {
      'tier_info': {
        'level': nextTier.level,
        'name': nextTier.displayName,
        'min_points': nextTier.minPoints,
        'point_range': nextTier.pointsRange,
        'color': mockNextTierModel.getTierColor(),
        'icon': mockNextTierModel.getTierIcon(),
      },
      'new_benefits': _getNewBenefits(mockNextTierModel),
      'new_privileges': _getNewPrivileges(mockNextTierModel),
      'points_required': getPointsToNextTier(),
      'estimated_time': _estimateDaysToNextTier(),
    };
  }

  Map<String, dynamic> _getNewBenefits(TierModel nextTierModel) {
    final currentBenefits = benefits;
    final nextBenefits = nextTierModel.benefits;
    final newBenefits = <String, dynamic>{};

    for (final entry in nextBenefits.entries) {
      final key = entry.key;
      final nextValue = entry.value;
      final currentValue = currentBenefits[key];

      if (currentValue != nextValue) {
        newBenefits[key] = {
          'current_value': currentValue,
          'new_value': nextValue,
          'description': _getBenefitDescription(key),
          'is_new_benefit': !currentBenefits.containsKey(key),
        };
      }
    }

    return newBenefits;
  }

  Map<String, dynamic> _getNewPrivileges(TierModel nextTierModel) {
    final currentPrivileges = privileges;
    final nextPrivileges = nextTierModel.privileges;
    final newPrivileges = <String, dynamic>{};

    for (final entry in nextPrivileges.entries) {
      final key = entry.key;
      final nextValue = entry.value;
      final currentValue = currentPrivileges[key] ?? false;

      if (nextValue == true && currentValue != true) {
        newPrivileges[key] = {
          'description': _getPrivilegeDescription(key),
          'category': _getPrivilegeCategory(key),
        };
      }
    }

    return newPrivileges;
  }

  /// Gets tier comparison with other levels
  Map<String, dynamic> compareTier(TierLevel otherLevel) {
    final otherTierModel = TierModel.withCalculatedData(
      id: 'comparison',
      userId: userId,
      level: otherLevel,
      currentPoints: otherLevel.minPoints,
    );

    return {
      'comparison_type': level.level > otherLevel.level
          ? 'upgrade'
          : 'downgrade',
      'level_difference': (level.level - otherLevel.level).abs(),
      'point_difference': (currentPoints - otherLevel.minPoints).abs(),
      'benefit_differences': _compareBenefits(otherTierModel),
      'privilege_differences': _comparePrivileges(otherTierModel),
      'summary': {
        'current_tier': level.displayName,
        'comparison_tier': otherLevel.displayName,
        'is_better': level.level > otherLevel.level,
        'significant_upgrade': (level.level - otherLevel.level) >= 3,
      },
    };
  }

  Map<String, dynamic> _compareBenefits(TierModel other) {
    final differences = <String, dynamic>{};
    final allKeys = {...benefits.keys, ...other.benefits.keys};

    for (final key in allKeys) {
      final currentValue = benefits[key];
      final otherValue = other.benefits[key];

      if (currentValue != otherValue) {
        differences[key] = {
          'current': currentValue,
          'other': otherValue,
          'is_better': _isBenefitBetter(currentValue, otherValue),
          'description': _getBenefitDescription(key),
        };
      }
    }

    return differences;
  }

  Map<String, dynamic> _comparePrivileges(TierModel other) {
    final differences = <String, dynamic>{};
    final allKeys = {...privileges.keys, ...other.privileges.keys};

    for (final key in allKeys) {
      final currentValue = privileges[key] ?? false;
      final otherValue = other.privileges[key] ?? false;

      if (currentValue != otherValue) {
        differences[key] = {
          'current': currentValue,
          'other': otherValue,
          'is_better': currentValue == true && otherValue != true,
          'description': _getPrivilegeDescription(key),
        };
      }
    }

    return differences;
  }

  bool _isBenefitBetter(dynamic current, dynamic other) {
    if (current == null && other != null) return false;
    if (current != null && other == null) return true;
    if (current is num && other is num) return current > other;
    if (current is bool && other is bool) return current && !other;
    return false;
  }

  @override
  String toString() {
    return 'TierModel(id: $id, userId: $userId, level: ${level.displayName}, '
        'points: $currentPoints, progress: ${calculateProgress().toStringAsFixed(1)}%)';
  }
}
