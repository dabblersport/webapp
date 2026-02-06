import 'package:dabbler/data/models/rewards/badge.dart';
import 'package:dabbler/data/models/rewards/badge_tier.dart';

/// Data model for Badge with JSON serialization and collection tracking
class BadgeModel extends Badge {
  /// Additional properties for collection tracking
  final int timesEarned;
  final DateTime? firstEarnedAt;
  final DateTime? lastEarnedAt;
  final bool isShowcased;
  final int showcaseOrder;
  final Map<String, dynamic> collectionMetadata;

  const BadgeModel({
    required super.id,
    required super.name,
    required super.tier,
    required super.iconUrl,
    super.animatedIconUrl,
    required super.rarityScore,
    required super.unlockMessage,
    required super.achievementId,
    super.style = BadgeStyle.classic,
    super.animation = BadgeAnimation.none,
    super.designMetadata = const {},
    super.isLimitedEdition = false,
    super.maxOwners,
    super.currentOwners = 0,
    required super.createdAt,
    super.updatedAt,
    this.timesEarned = 0,
    this.firstEarnedAt,
    this.lastEarnedAt,
    this.isShowcased = false,
    this.showcaseOrder = 0,
    this.collectionMetadata = const {},
  });

  /// Creates a BadgeModel from JSON
  factory BadgeModel.fromJson(Map<String, dynamic> json) {
    return BadgeModel(
      id: json['id'] as String,
      name: json['name'] as String,
      tier: _parseBadgeTier(json['tier']),
      iconUrl: json['icon_url'] as String,
      animatedIconUrl: json['animated_icon_url'] as String?,
      rarityScore: _parseRarityScore(json['rarity_score']),
      unlockMessage: json['unlock_message'] as String,
      achievementId: json['achievement_id'] as String,
      style: _parseBadgeStyle(json['style']),
      animation: _parseBadgeAnimation(json['animation']),
      designMetadata: _parseDesignMetadata(json['design_metadata']),
      isLimitedEdition: json['is_limited_edition'] as bool? ?? false,
      maxOwners: json['max_owners'] as int?,
      currentOwners: json['current_owners'] as int? ?? 0,
      createdAt: _parseDateTime(json['created_at'])!,
      updatedAt: _parseDateTime(json['updated_at']),
      timesEarned: json['times_earned'] as int? ?? 0,
      firstEarnedAt: _parseDateTime(json['first_earned_at']),
      lastEarnedAt: _parseDateTime(json['last_earned_at']),
      isShowcased: json['is_showcased'] as bool? ?? false,
      showcaseOrder: json['showcase_order'] as int? ?? 0,
      collectionMetadata: _parseCollectionMetadata(json['collection_metadata']),
    );
  }

  /// Converts the model to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'tier': tier.name,
      'icon_url': iconUrl,
      'animated_icon_url': animatedIconUrl,
      'rarity_score': rarityScore,
      'unlock_message': unlockMessage,
      'achievement_id': achievementId,
      'style': style.name,
      'animation': animation.name,
      'design_metadata': designMetadata,
      'is_limited_edition': isLimitedEdition,
      'max_owners': maxOwners,
      'current_owners': currentOwners,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'times_earned': timesEarned,
      'first_earned_at': firstEarnedAt?.toIso8601String(),
      'last_earned_at': lastEarnedAt?.toIso8601String(),
      'is_showcased': isShowcased,
      'showcase_order': showcaseOrder,
      'collection_metadata': collectionMetadata,
    };
  }

  /// Creates a copy as BadgeModel
  @override
  BadgeModel copyWith({
    String? id,
    String? name,
    BadgeTier? tier,
    String? iconUrl,
    String? animatedIconUrl,
    int? rarityScore,
    String? unlockMessage,
    String? achievementId,
    BadgeStyle? style,
    BadgeAnimation? animation,
    Map<String, dynamic>? designMetadata,
    bool? isLimitedEdition,
    int? maxOwners,
    int? currentOwners,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? timesEarned,
    DateTime? firstEarnedAt,
    DateTime? lastEarnedAt,
    bool? isShowcased,
    int? showcaseOrder,
    Map<String, dynamic>? collectionMetadata,
  }) {
    return BadgeModel(
      id: id ?? this.id,
      name: name ?? this.name,
      tier: tier ?? this.tier,
      iconUrl: iconUrl ?? this.iconUrl,
      animatedIconUrl: animatedIconUrl ?? this.animatedIconUrl,
      rarityScore: rarityScore ?? this.rarityScore,
      unlockMessage: unlockMessage ?? this.unlockMessage,
      achievementId: achievementId ?? this.achievementId,
      style: style ?? this.style,
      animation: animation ?? this.animation,
      designMetadata: designMetadata ?? this.designMetadata,
      isLimitedEdition: isLimitedEdition ?? this.isLimitedEdition,
      maxOwners: maxOwners ?? this.maxOwners,
      currentOwners: currentOwners ?? this.currentOwners,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      timesEarned: timesEarned ?? this.timesEarned,
      firstEarnedAt: firstEarnedAt ?? this.firstEarnedAt,
      lastEarnedAt: lastEarnedAt ?? this.lastEarnedAt,
      isShowcased: isShowcased ?? this.isShowcased,
      showcaseOrder: showcaseOrder ?? this.showcaseOrder,
      collectionMetadata: collectionMetadata ?? this.collectionMetadata,
    );
  }

  // Static parsing methods

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

  static BadgeStyle _parseBadgeStyle(dynamic value) {
    if (value == null) return BadgeStyle.classic;

    if (value is String) {
      switch (value.toLowerCase()) {
        case 'classic':
          return BadgeStyle.classic;
        case 'modern':
          return BadgeStyle.modern;
        case 'minimalist':
          return BadgeStyle.minimalist;
        case 'gaming':
          return BadgeStyle.gaming;
        case 'elegant':
          return BadgeStyle.elegant;
        default:
          return BadgeStyle.classic;
      }
    }

    return BadgeStyle.classic;
  }

  static BadgeAnimation _parseBadgeAnimation(dynamic value) {
    if (value == null) return BadgeAnimation.none;

    if (value is String) {
      switch (value.toLowerCase()) {
        case 'none':
          return BadgeAnimation.none;
        case 'pulse':
          return BadgeAnimation.pulse;
        case 'glow':
          return BadgeAnimation.glow;
        case 'rotate':
          return BadgeAnimation.rotate;
        case 'bounce':
          return BadgeAnimation.bounce;
        default:
          return BadgeAnimation.none;
      }
    }

    return BadgeAnimation.none;
  }

  static int _parseRarityScore(dynamic value) {
    if (value == null) return 0;

    if (value is int) return value.clamp(0, 100);
    if (value is double) return value.round().clamp(0, 100);
    if (value is String) {
      return int.tryParse(value)?.clamp(0, 100) ?? 0;
    }

    return 0;
  }

  static Map<String, dynamic> _parseDesignMetadata(dynamic value) {
    if (value == null) return {};

    if (value is Map<String, dynamic>) {
      return Map<String, dynamic>.from(value);
    }

    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    return {};
  }

  static Map<String, dynamic> _parseCollectionMetadata(dynamic value) {
    if (value == null) return {};

    if (value is Map<String, dynamic>) {
      return Map<String, dynamic>.from(value);
    }

    if (value is Map) {
      return Map<String, dynamic>.from(value);
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

  /// Creates a BadgeModel from Supabase row
  factory BadgeModel.fromSupabase(Map<String, dynamic> data) {
    return BadgeModel.fromJson({
      ...data,
      'icon_url': data['icon_url'] ?? data['iconUrl'],
      'animated_icon_url': data['animated_icon_url'] ?? data['animatedIconUrl'],
      'rarity_score': data['rarity_score'] ?? data['rarityScore'],
      'unlock_message': data['unlock_message'] ?? data['unlockMessage'],
      'achievement_id': data['achievement_id'] ?? data['achievementId'],
      'design_metadata': data['design_metadata'] ?? data['designMetadata'],
      'is_limited_edition':
          data['is_limited_edition'] ?? data['isLimitedEdition'],
      'max_owners': data['max_owners'] ?? data['maxOwners'],
      'current_owners': data['current_owners'] ?? data['currentOwners'],
      'created_at': data['created_at'] ?? data['createdAt'],
      'updated_at': data['updated_at'] ?? data['updatedAt'],
      'times_earned': data['times_earned'] ?? data['timesEarned'],
      'first_earned_at': data['first_earned_at'] ?? data['firstEarnedAt'],
      'last_earned_at': data['last_earned_at'] ?? data['lastEarnedAt'],
      'is_showcased': data['is_showcased'] ?? data['isShowcased'],
      'showcase_order': data['showcase_order'] ?? data['showcaseOrder'],
      'collection_metadata':
          data['collection_metadata'] ?? data['collectionMetadata'],
    });
  }

  /// Converts to format suitable for Supabase insertion
  Map<String, dynamic> toSupabase() {
    final json = toJson();
    json.removeWhere((key, value) => value == null);

    return {
      ...json,
      'icon_url': json['icon_url'],
      'animated_icon_url': json['animated_icon_url'],
      'rarity_score': json['rarity_score'],
      'unlock_message': json['unlock_message'],
      'achievement_id': json['achievement_id'],
      'design_metadata': json['design_metadata'],
      'is_limited_edition': json['is_limited_edition'],
      'max_owners': json['max_owners'],
      'current_owners': json['current_owners'],
      'created_at': json['created_at'],
      'updated_at': json['updated_at'],
      'times_earned': json['times_earned'],
      'first_earned_at': json['first_earned_at'],
      'last_earned_at': json['last_earned_at'],
      'is_showcased': json['is_showcased'],
      'showcase_order': json['showcase_order'],
      'collection_metadata': json['collection_metadata'],
    };
  }

  /// Creates a mock BadgeModel for testing
  factory BadgeModel.mock({
    String? id,
    String? name,
    BadgeTier tier = BadgeTier.bronze,
    int rarityScore = 50,
    bool isLimitedEdition = false,
    int timesEarned = 1,
  }) {
    return BadgeModel(
      id: id ?? 'mock_badge',
      name: name ?? 'Mock Badge',
      tier: tier,
      iconUrl: 'https://example.com/badge.png',
      rarityScore: rarityScore,
      unlockMessage: 'Congratulations on earning this badge!',
      achievementId: 'mock_achievement',
      createdAt: DateTime.now(),
      timesEarned: timesEarned,
      isLimitedEdition: isLimitedEdition,
      firstEarnedAt: DateTime.now(),
      lastEarnedAt: DateTime.now(),
    );
  }

  /// Records a new earning of this badge
  BadgeModel recordEarning() {
    final now = DateTime.now();
    return copyWith(
      timesEarned: timesEarned + 1,
      firstEarnedAt: firstEarnedAt ?? now,
      lastEarnedAt: now,
      updatedAt: now,
      collectionMetadata: {
        ...collectionMetadata,
        'last_earned': now.toIso8601String(),
        'earning_history': [
          ...(collectionMetadata['earning_history'] as List? ?? []),
          {'earned_at': now.toIso8601String()},
        ],
      },
    );
  }

  /// Updates showcase settings
  BadgeModel updateShowcase({required bool isShowcased, int? showcaseOrder}) {
    return copyWith(
      isShowcased: isShowcased,
      showcaseOrder: showcaseOrder ?? this.showcaseOrder,
      updatedAt: DateTime.now(),
      collectionMetadata: {
        ...collectionMetadata,
        'showcase_updated_at': DateTime.now().toIso8601String(),
      },
    );
  }

  /// Gets collection statistics
  Map<String, dynamic> getCollectionStats() {
    return {
      'times_earned': timesEarned,
      'first_earned_at': firstEarnedAt?.toIso8601String(),
      'last_earned_at': lastEarnedAt?.toIso8601String(),
      'is_showcased': isShowcased,
      'showcase_order': showcaseOrder,
      'days_since_first_earned': firstEarnedAt != null
          ? DateTime.now().difference(firstEarnedAt!).inDays
          : null,
      'days_since_last_earned': lastEarnedAt != null
          ? DateTime.now().difference(lastEarnedAt!).inDays
          : null,
      'is_new_badge': firstEarnedAt != null
          ? DateTime.now().difference(firstEarnedAt!).inDays <= 7
          : false,
      'earning_frequency': _calculateEarningFrequency(),
    };
  }

  double? _calculateEarningFrequency() {
    if (timesEarned <= 1 || firstEarnedAt == null || lastEarnedAt == null) {
      return null;
    }

    final daysBetween = lastEarnedAt!.difference(firstEarnedAt!).inDays;
    if (daysBetween <= 0) return null;

    return timesEarned / daysBetween;
  }

  /// Gets showcase configuration
  Map<String, dynamic> getShowcaseConfig() {
    return {
      'is_showcased': isShowcased,
      'showcase_order': showcaseOrder,
      'preferred_icon': getIconUrl(preferAnimated: isShowcased),
      'display_effects': getGlowEffect(),
      'border_config': getBorderConfig(),
      'animation_config': isShowcased ? getAnimationConfig() : null,
    };
  }

  /// Gets earning milestones
  List<Map<String, dynamic>> getEarningMilestones() {
    final milestones = <Map<String, dynamic>>[];

    // Define milestone thresholds
    final thresholds = [1, 5, 10, 25, 50, 100];

    for (final threshold in thresholds) {
      final isReached = timesEarned >= threshold;
      milestones.add({
        'threshold': threshold,
        'is_reached': isReached,
        'description': _getMilestoneDescription(threshold),
        'reward': _getMilestoneReward(threshold),
      });
    }

    return milestones;
  }

  String _getMilestoneDescription(int threshold) {
    switch (threshold) {
      case 1:
        return 'First Badge Earned';
      case 5:
        return 'Badge Collector';
      case 10:
        return 'Badge Enthusiast';
      case 25:
        return 'Badge Expert';
      case 50:
        return 'Badge Master';
      case 100:
        return 'Badge Legend';
      default:
        return 'Milestone $threshold';
    }
  }

  String _getMilestoneReward(int threshold) {
    switch (threshold) {
      case 1:
        return 'Badge unlocked';
      case 5:
        return 'Special badge effect';
      case 10:
        return 'Showcase priority';
      case 25:
        return 'Exclusive badge border';
      case 50:
        return 'Animated badge version';
      case 100:
        return 'Legendary badge status';
      default:
        return 'Achievement points';
    }
  }

  @override
  String toString() {
    return 'BadgeModel(id: $id, name: $name, tier: $tier, '
        'timesEarned: $timesEarned, rarity: ${getRarityLabel()})';
  }
}
