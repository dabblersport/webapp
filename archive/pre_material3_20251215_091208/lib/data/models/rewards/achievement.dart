import 'badge_tier.dart';

/// Achievement types for different reward mechanics
enum AchievementType {
  /// One-time achievements
  single,

  /// Achievements that accumulate over time
  cumulative,

  /// Streak-based achievements
  streak,

  /// Conditional achievements based on specific criteria
  conditional,

  /// Hidden achievements not shown until unlocked
  hidden,

  /// Standard repeatable achievements
  standard,

  /// Milestone achievements for major progress markers
  milestone,

  /// Social interaction achievements
  social,

  /// Challenge-based achievements
  challenge;

  /// Whether this achievement type can be earned multiple times
  bool get isRepeatable {
    switch (this) {
      case AchievementType.single:
      case AchievementType.milestone:
      case AchievementType.hidden:
        return false;
      case AchievementType.cumulative:
      case AchievementType.streak:
      case AchievementType.conditional:
      case AchievementType.standard:
      case AchievementType.social:
      case AchievementType.challenge:
        return true;
    }
  }
}

/// Achievement categories for organization and filtering
enum AchievementCategory {
  /// Gaming-related achievements
  gaming,

  /// Social interaction achievements
  social,

  /// Profile completion achievements
  profile,

  /// Venue/location based achievements
  venue,

  /// Engagement and participation achievements
  engagement,

  /// Special events and limited-time achievements
  special,

  /// Game participation achievements
  gameParticipation,

  /// Skill and performance achievements
  skillPerformance,

  /// Milestone achievements
  milestone,
}

/// Achievement entity representing a reward milestone
class Achievement {
  final String id;
  final String code;
  final String name;
  final String description;
  final AchievementType type;
  final AchievementCategory category;
  final BadgeTier tier;
  final Map<String, dynamic> criteria;
  final int points;
  final List<String> prerequisites;
  final DateTime? availableFrom;
  final DateTime? availableUntil;
  final bool isHidden;
  final int? maxProgress;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const Achievement({
    required this.id,
    required this.code,
    required this.name,
    required this.description,
    required this.type,
    required this.category,
    required this.tier,
    required this.criteria,
    required this.points,
    this.prerequisites = const [],
    this.availableFrom,
    this.availableUntil,
    this.isHidden = false,
    this.maxProgress,
    this.isActive = true,
    required this.createdAt,
    this.updatedAt,
  });

  /// Checks if the achievement is currently available
  bool isAvailable() {
    if (!isActive) return false;

    final now = DateTime.now();

    // Check if achievement is within availability window
    if (availableFrom != null && now.isBefore(availableFrom!)) {
      return false;
    }

    if (availableUntil != null && now.isAfter(availableUntil!)) {
      return false;
    }

    return true;
  }

  /// Checks if all prerequisites are met
  bool meetsPrerequisites(List<String> completedAchievements) {
    if (prerequisites.isEmpty) return true;

    return prerequisites.every(
      (prerequisite) => completedAchievements.contains(prerequisite),
    );
  }

  /// Gets formatted criteria description for display
  String getFormattedCriteria() {
    final buffer = StringBuffer();

    switch (type) {
      case AchievementType.single:
        buffer.write('Complete: ');
        break;
      case AchievementType.cumulative:
        buffer.write('Accumulate: ');
        break;
      case AchievementType.streak:
        buffer.write('Maintain streak: ');
        break;
      case AchievementType.conditional:
        buffer.write('Meet condition: ');
        break;
      case AchievementType.hidden:
        return 'Hidden achievement - complete to reveal criteria';
      case AchievementType.standard:
        buffer.write('Complete: ');
        break;
      case AchievementType.milestone:
        buffer.write('Reach milestone: ');
        break;
      case AchievementType.social:
        buffer.write('Social activity: ');
        break;
      case AchievementType.challenge:
        buffer.write('Challenge: ');
        break;
    }

    // Format different criteria types
    if (criteria.containsKey('count')) {
      buffer.write('${criteria['count']} times');
    }

    if (criteria.containsKey('duration')) {
      buffer.write(' over ${criteria['duration']} days');
    }

    if (criteria.containsKey('sport')) {
      buffer.write(' in ${criteria['sport']}');
    }

    if (criteria.containsKey('score_threshold')) {
      buffer.write(' with score ≥ ${criteria['score_threshold']}');
    }

    if (criteria.containsKey('ranking')) {
      buffer.write(' ranking #${criteria['ranking']} or better');
    }

    return buffer.toString();
  }

  /// Gets the tier color for UI display
  String getTierColorHex() {
    switch (tier) {
      case BadgeTier.bronze:
        return '#CD7F32';
      case BadgeTier.silver:
        return '#C0C0C0';
      case BadgeTier.gold:
        return '#FFD700';
      case BadgeTier.platinum:
        return '#E5E4E2';
      case BadgeTier.diamond:
        return '#B9F2FF';
    }
  }

  /// Gets the tier display name
  String getTierDisplayName() {
    switch (tier) {
      case BadgeTier.bronze:
        return 'Bronze';
      case BadgeTier.silver:
        return 'Silver';
      case BadgeTier.gold:
        return 'Gold';
      case BadgeTier.platinum:
        return 'Platinum';
      case BadgeTier.diamond:
        return 'Diamond';
    }
  }

  /// Gets the category display name
  String getCategoryDisplayName() {
    switch (category) {
      case AchievementCategory.gaming:
        return 'Gaming';
      case AchievementCategory.social:
        return 'Social';
      case AchievementCategory.profile:
        return 'Profile';
      case AchievementCategory.venue:
        return 'Venue';
      case AchievementCategory.engagement:
        return 'Engagement';
      case AchievementCategory.special:
        return 'Special';
      case AchievementCategory.gameParticipation:
        return 'Game Participation';
      case AchievementCategory.skillPerformance:
        return 'Skill & Performance';
      case AchievementCategory.milestone:
        return 'Milestone';
    }
  }

  /// Creates a copy with updated values
  Achievement copyWith({
    String? id,
    String? code,
    String? name,
    String? description,
    AchievementType? type,
    AchievementCategory? category,
    BadgeTier? tier,
    Map<String, dynamic>? criteria,
    int? points,
    List<String>? prerequisites,
    DateTime? availableFrom,
    DateTime? availableUntil,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Achievement(
      id: id ?? this.id,
      code: code ?? this.code,
      name: name ?? this.name,
      description: description ?? this.description,
      type: type ?? this.type,
      category: category ?? this.category,
      tier: tier ?? this.tier,
      criteria: criteria ?? this.criteria,
      points: points ?? this.points,
      prerequisites: prerequisites ?? this.prerequisites,
      availableFrom: availableFrom ?? this.availableFrom,
      availableUntil: availableUntil ?? this.availableUntil,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is Achievement &&
        other.id == id &&
        other.code == code &&
        other.name == name &&
        other.description == description &&
        other.type == type &&
        other.category == category &&
        other.tier == tier &&
        other.points == points;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        code.hashCode ^
        name.hashCode ^
        description.hashCode ^
        type.hashCode ^
        category.hashCode ^
        tier.hashCode ^
        points.hashCode;
  }

  @override
  String toString() {
    return 'Achievement(id: $id, code: $code, name: $name, tier: $tier, points: $points)';
  }
}
