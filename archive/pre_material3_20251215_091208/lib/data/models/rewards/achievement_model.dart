import 'package:dabbler/data/models/rewards/achievement.dart';
import 'package:dabbler/data/models/rewards/badge_tier.dart';

/// Data model for Achievement with JSON serialization
class AchievementModel extends Achievement {
  const AchievementModel({
    required super.id,
    required super.code,
    required super.name,
    required super.description,
    required super.type,
    required super.category,
    required super.tier,
    required super.criteria,
    required super.points,
    super.prerequisites = const [],
    super.availableFrom,
    super.availableUntil,
    super.isActive = true,
    required super.createdAt,
    super.updatedAt,
  });

  /// Creates an AchievementModel from JSON
  factory AchievementModel.fromJson(Map<String, dynamic> json) {
    return AchievementModel(
      id: json['id'] as String,
      code: json['code'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      type: _parseAchievementType(json['type']),
      category: _parseAchievementCategory(json['category']),
      tier: _parseBadgeTier(json['tier']),
      criteria: _parseCriteria(json['criteria']),
      points: _parsePoints(json['points']),
      prerequisites: _parsePrerequisites(json['prerequisites']),
      availableFrom: _parseDateTime(json['available_from']),
      availableUntil: _parseDateTime(json['available_until']),
      isActive: json['is_active'] as bool? ?? true,
      createdAt: _parseDateTime(json['created_at'])!,
      updatedAt: _parseDateTime(json['updated_at']),
    );
  }

  /// Converts the model to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'name': name,
      'description': description,
      'type': type.name,
      'category': category.name,
      'tier': tier.name,
      'criteria': criteria,
      'points': points,
      'prerequisites': prerequisites,
      'available_from': availableFrom?.toIso8601String(),
      'available_until': availableUntil?.toIso8601String(),
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  /// Creates a copy as AchievementModel
  @override
  AchievementModel copyWith({
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
    return AchievementModel(
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

  // Static parsing methods

  static AchievementType _parseAchievementType(dynamic value) {
    if (value == null) return AchievementType.single;

    if (value is String) {
      switch (value.toLowerCase()) {
        case 'single':
          return AchievementType.single;
        case 'cumulative':
          return AchievementType.cumulative;
        case 'streak':
          return AchievementType.streak;
        case 'conditional':
          return AchievementType.conditional;
        case 'hidden':
          return AchievementType.hidden;
        default:
          return AchievementType.single;
      }
    }

    return AchievementType.single;
  }

  static AchievementCategory _parseAchievementCategory(dynamic value) {
    if (value == null) return AchievementCategory.milestone;

    if (value is String) {
      switch (value.toLowerCase()) {
        case 'game_participation':
        case 'gameparticipation':
          return AchievementCategory.gameParticipation;
        case 'social':
          return AchievementCategory.social;
        case 'skill_performance':
        case 'skillperformance':
          return AchievementCategory.skillPerformance;
        case 'milestone':
          return AchievementCategory.milestone;
        case 'special':
          return AchievementCategory.special;
        default:
          return AchievementCategory.milestone;
      }
    }

    return AchievementCategory.milestone;
  }

  static BadgeTier _parseBadgeTier(dynamic value) {
    if (value == null) return BadgeTier.bronze;

    if (value is String) {
      switch (value.toLowerCase()) {
        case 'bronze':
          return BadgeTier.bronze;
        case 'silver':
          return BadgeTier.silver;
        case 'gold':
          return BadgeTier.gold;
        case 'platinum':
          return BadgeTier.platinum;
        case 'diamond':
          return BadgeTier.diamond;
        default:
          return BadgeTier.bronze;
      }
    }

    return BadgeTier.bronze;
  }

  static Map<String, dynamic> _parseCriteria(dynamic value) {
    if (value == null) return {};

    if (value is Map<String, dynamic>) {
      return Map<String, dynamic>.from(value);
    }

    if (value is String) {
      try {
        // Try to parse JSON string
        final Map<String, dynamic> parsed = Map<String, dynamic>.from(
          Map.from(value as dynamic),
        );
        return parsed;
      } catch (e) {
        // If parsing fails, return empty map
        return {};
      }
    }

    return {};
  }

  static int _parsePoints(dynamic value) {
    if (value == null) return 0;

    if (value is int) return value;
    if (value is double) return value.round();
    if (value is String) {
      return int.tryParse(value) ?? 0;
    }

    return 0;
  }

  static List<String> _parsePrerequisites(dynamic value) {
    if (value == null) return [];

    if (value is List) {
      return value.cast<String>();
    }

    if (value is String) {
      // Handle comma-separated string
      if (value.isEmpty) return [];
      return value.split(',').map((s) => s.trim()).toList();
    }

    return [];
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

  /// Creates an AchievementModel from a Supabase row
  factory AchievementModel.fromSupabase(Map<String, dynamic> data) {
    return AchievementModel.fromJson({
      ...data,
      // Handle potential database field naming differences
      'created_at': data['created_at'] ?? data['createdAt'],
      'updated_at': data['updated_at'] ?? data['updatedAt'],
      'available_from': data['available_from'] ?? data['availableFrom'],
      'available_until': data['available_until'] ?? data['availableUntil'],
      'is_active': data['is_active'] ?? data['isActive'],
    });
  }

  /// Converts to format suitable for Supabase insertion
  Map<String, dynamic> toSupabase() {
    final json = toJson();

    // Remove null values and convert to database format
    json.removeWhere((key, value) => value == null);

    return {
      ...json,
      // Ensure proper field naming for database
      'created_at': json['created_at'],
      'updated_at': json['updated_at'],
      'available_from': json['available_from'],
      'available_until': json['available_until'],
      'is_active': json['is_active'],
    };
  }

  /// Creates test/mock achievement
  factory AchievementModel.mock({
    String? id,
    String? code,
    AchievementType type = AchievementType.single,
    AchievementCategory category = AchievementCategory.milestone,
    BadgeTier tier = BadgeTier.bronze,
    Map<String, dynamic>? criteria,
    int points = 100,
  }) {
    return AchievementModel(
      id: id ?? 'mock_achievement',
      code: code ?? 'MOCK_ACHIEVEMENT',
      name: 'Mock Achievement',
      description: 'A mock achievement for testing',
      type: type,
      category: category,
      tier: tier,
      criteria: criteria ?? {'count': 1},
      points: points,
      prerequisites: const [],
      createdAt: DateTime.now(),
    );
  }

  /// Validates criteria structure based on achievement type
  bool validateCriteria() {
    switch (type) {
      case AchievementType.single:
        return criteria.containsKey('count') ||
            criteria.containsKey('condition');

      case AchievementType.cumulative:
        return criteria.containsKey('count') || criteria.containsKey('total');

      case AchievementType.streak:
        return criteria.containsKey('streak_length') ||
            criteria.containsKey('duration');

      case AchievementType.conditional:
        return criteria.containsKey('conditions') ||
            criteria.containsKey('requirements');

      case AchievementType.hidden:
        return criteria.isNotEmpty;

      case AchievementType.standard:
        return criteria.containsKey('count') ||
            criteria.containsKey('condition');

      case AchievementType.milestone:
        return criteria.containsKey('milestone') ||
            criteria.containsKey('target');

      case AchievementType.social:
        return criteria.containsKey('social_action') ||
            criteria.containsKey('interaction');

      case AchievementType.challenge:
        return criteria.containsKey('challenge_id') ||
            criteria.containsKey('objective');
    }
  }

  /// Gets default criteria based on achievement type
  static Map<String, dynamic> getDefaultCriteria(AchievementType type) {
    switch (type) {
      case AchievementType.single:
        return {'count': 1};

      case AchievementType.cumulative:
        return {'total': 10};

      case AchievementType.streak:
        return {'streak_length': 5};

      case AchievementType.conditional:
        return {'conditions': []};

      case AchievementType.hidden:
        return {'secret': true};

      case AchievementType.standard:
        return {'count': 1};

      case AchievementType.milestone:
        return {'milestone': 100};

      case AchievementType.social:
        return {'social_action': 'invite'};

      case AchievementType.challenge:
        return {'challenge_id': 'default'};
    }
  }
}
