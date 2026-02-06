import 'badge_tier.dart';

/// Badge design style for customization
enum BadgeStyle { classic, modern, minimalist, gaming, elegant }

/// Badge animation type for display
enum BadgeAnimation { none, pulse, glow, rotate, bounce }

/// Badge rarity levels
enum BadgeRarity { common, uncommon, rare, epic, legendary }

/// Badge entity representing visual rewards for achievements
class Badge {
  final String id;
  final String name;
  final BadgeTier tier;
  final String iconUrl;
  final String? animatedIconUrl;
  final int rarityScore; // 0-100 scale
  final String unlockMessage;
  final String achievementId;
  final BadgeStyle style;
  final BadgeAnimation animation;
  final Map<String, dynamic> designMetadata;
  final bool isLimitedEdition;
  final int? maxOwners;
  final int currentOwners;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const Badge({
    required this.id,
    required this.name,
    required this.tier,
    required this.iconUrl,
    this.animatedIconUrl,
    required this.rarityScore,
    required this.unlockMessage,
    required this.achievementId,
    this.style = BadgeStyle.classic,
    this.animation = BadgeAnimation.none,
    this.designMetadata = const {},
    this.isLimitedEdition = false,
    this.maxOwners,
    this.currentOwners = 0,
    required this.createdAt,
    this.updatedAt,
  });

  /// Gets the rarity label based on rarity score
  String getRarityLabel() {
    if (rarityScore >= 95) return 'Legendary';
    if (rarityScore >= 85) return 'Epic';
    if (rarityScore >= 70) return 'Rare';
    if (rarityScore >= 50) return 'Uncommon';
    return 'Common';
  }

  /// Gets the display color based on tier
  String getDisplayColor() {
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

  /// Gets the rarity color for display
  String getRarityColor() {
    if (rarityScore >= 95) return '#FF6B35'; // Legendary orange
    if (rarityScore >= 85) return '#8A2BE2'; // Epic purple
    if (rarityScore >= 70) return '#4169E1'; // Rare blue
    if (rarityScore >= 50) return '#32CD32'; // Uncommon green
    return '#808080'; // Common gray
  }

  /// Gets the glow effect configuration
  Map<String, dynamic> getGlowEffect() {
    return {
      'enabled': rarityScore >= 70 || isLimitedEdition,
      'color': getRarityColor(),
      'intensity': _getGlowIntensity(),
      'radius': rarityScore >= 95
          ? 8.0
          : rarityScore >= 85
          ? 6.0
          : 4.0,
    };
  }

  double _getGlowIntensity() {
    if (rarityScore >= 95) return 1.0;
    if (rarityScore >= 85) return 0.8;
    if (rarityScore >= 70) return 0.6;
    return 0.4;
  }

  /// Gets border configuration for the badge
  Map<String, dynamic> getBorderConfig() {
    return {
      'width': tier == BadgeTier.diamond ? 3.0 : 2.0,
      'color': getDisplayColor(),
      'style': isLimitedEdition ? 'dashed' : 'solid',
      'glow': rarityScore >= 85,
    };
  }

  /// Gets animation configuration
  Map<String, dynamic> getAnimationConfig() {
    return {
      'type': animation.name,
      'duration': _getAnimationDuration(),
      'intensity': _getAnimationIntensity(),
      'triggerOnUnlock': true,
      'triggerOnHover': rarityScore >= 70,
    };
  }

  Duration _getAnimationDuration() {
    switch (animation) {
      case BadgeAnimation.pulse:
        return const Duration(seconds: 2);
      case BadgeAnimation.glow:
        return const Duration(seconds: 3);
      case BadgeAnimation.rotate:
        return const Duration(seconds: 4);
      case BadgeAnimation.bounce:
        return const Duration(milliseconds: 800);
      case BadgeAnimation.none:
        return Duration.zero;
    }
  }

  double _getAnimationIntensity() {
    if (rarityScore >= 95) return 1.0;
    if (rarityScore >= 85) return 0.8;
    if (rarityScore >= 70) return 0.6;
    return 0.4;
  }

  /// Checks if badge is currently obtainable
  bool isObtainable() {
    if (isLimitedEdition && maxOwners != null) {
      return currentOwners < maxOwners!;
    }
    return true;
  }

  /// Gets scarcity information
  Map<String, dynamic> getScarcityInfo() {
    if (!isLimitedEdition) {
      return {'type': 'unlimited', 'message': 'Available to all players'};
    }

    if (maxOwners == null) {
      return {
        'type': 'limited_time',
        'message': 'Limited edition - no longer available',
      };
    }

    final remaining = maxOwners! - currentOwners;
    final percentage = (currentOwners / maxOwners! * 100).round();

    return {
      'type': 'limited_quantity',
      'current_owners': currentOwners,
      'max_owners': maxOwners,
      'remaining': remaining,
      'percentage_claimed': percentage,
      'message': remaining > 0
          ? '$remaining of ${maxOwners!} remaining'
          : 'All ${maxOwners!} badges claimed',
    };
  }

  /// Gets formatted display text for the badge
  String getFormattedDisplayText() {
    final buffer = StringBuffer();
    buffer.write(name);

    if (isLimitedEdition) {
      buffer.write(' (Limited)');
    }

    final rarity = getRarityLabel();
    if (rarity != 'Common') {
      buffer.write(' - $rarity');
    }

    return buffer.toString();
  }

  /// Gets the appropriate icon URL (animated if available and conditions met)
  String getIconUrl({bool preferAnimated = false}) {
    if (preferAnimated &&
        animatedIconUrl != null &&
        (rarityScore >= 70 || animation != BadgeAnimation.none)) {
      return animatedIconUrl!;
    }
    return iconUrl;
  }

  /// Gets social sharing text
  String getSharingText() {
    return 'Just unlocked the $name badge! $unlockMessage';
  }

  /// Creates a copy with updated values
  Badge copyWith({
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
  }) {
    return Badge(
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
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is Badge &&
        other.id == id &&
        other.name == name &&
        other.tier == tier &&
        other.achievementId == achievementId;
  }

  @override
  int get hashCode {
    return id.hashCode ^ name.hashCode ^ tier.hashCode ^ achievementId.hashCode;
  }

  @override
  String toString() {
    return 'Badge(id: $id, name: $name, tier: $tier, rarity: ${getRarityLabel()})';
  }
}
