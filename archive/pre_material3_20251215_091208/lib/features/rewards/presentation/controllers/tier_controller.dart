import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dabbler/data/models/rewards/tier.dart';
import '../../domain/repositories/rewards_repository.dart';

/// State for tier management
class TierState {
  final UserTier? currentTier;
  final TierLevel? nextTier;
  final double progressToNext;
  final double pointsToNext;
  final List<TierBenefit> currentBenefits;
  final List<TierBenefit> nextBenefits;
  final List<TierBenefit> unlockedBenefits;
  final List<TierHistoryEntry> history;
  final DateTime? projectedNextTierDate;
  final Map<String, bool> activePrivileges;
  final bool isLoading;
  final String? error;
  final DateTime? lastUpdated;

  const TierState({
    this.currentTier,
    this.nextTier,
    this.progressToNext = 0.0,
    this.pointsToNext = 0.0,
    this.currentBenefits = const [],
    this.nextBenefits = const [],
    this.unlockedBenefits = const [],
    this.history = const [],
    this.projectedNextTierDate,
    this.activePrivileges = const {},
    this.isLoading = false,
    this.error,
    this.lastUpdated,
  });

  TierState copyWith({
    UserTier? currentTier,
    TierLevel? nextTier,
    double? progressToNext,
    double? pointsToNext,
    List<TierBenefit>? currentBenefits,
    List<TierBenefit>? nextBenefits,
    List<TierBenefit>? unlockedBenefits,
    List<TierHistoryEntry>? history,
    DateTime? projectedNextTierDate,
    Map<String, bool>? activePrivileges,
    bool? isLoading,
    String? error,
    DateTime? lastUpdated,
  }) {
    return TierState(
      currentTier: currentTier ?? this.currentTier,
      nextTier: nextTier ?? this.nextTier,
      progressToNext: progressToNext ?? this.progressToNext,
      pointsToNext: pointsToNext ?? this.pointsToNext,
      currentBenefits: currentBenefits ?? this.currentBenefits,
      nextBenefits: nextBenefits ?? this.nextBenefits,
      unlockedBenefits: unlockedBenefits ?? this.unlockedBenefits,
      history: history ?? this.history,
      projectedNextTierDate:
          projectedNextTierDate ?? this.projectedNextTierDate,
      activePrivileges: activePrivileges ?? this.activePrivileges,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  /// Get tier progression summary
  TierProgressSummary get progressSummary {
    return TierProgressSummary(
      currentTierLevel: currentTier?.level.level ?? 1,
      currentTierName: currentTier?.level.displayName ?? 'Fresh Player',
      nextTierLevel: nextTier?.level ?? (currentTier?.level.level ?? 1) + 1,
      nextTierName: nextTier?.displayName ?? 'Next Tier',
      progressPercentage: progressToNext,
      pointsNeeded: pointsToNext,
      currentPoints: currentTier?.currentPoints ?? 0.0,
      estimatedDaysToNext: _calculateEstimatedDays(),
      benefitsCount: currentBenefits.length,
      privilegesCount: activePrivileges.values.where((active) => active).length,
    );
  }

  int? _calculateEstimatedDays() {
    if (pointsToNext <= 0 || projectedNextTierDate == null) return null;
    return projectedNextTierDate!.difference(DateTime.now()).inDays;
  }

  /// Get tier comparison
  TierComparison get tierComparison {
    return TierComparison(
      currentBenefits: currentBenefits,
      nextBenefits: nextBenefits,
      benefitsToUnlock: _getBenefitsToUnlock(),
      privilegesToUnlock: _getPrivilegesToUnlock(),
    );
  }

  List<TierBenefit> _getBenefitsToUnlock() {
    if (nextTier == null) return [];

    final currentBenefitIds = currentBenefits.map((b) => b.id).toSet();
    return nextBenefits
        .where((benefit) => !currentBenefitIds.contains(benefit.id))
        .toList();
  }

  Map<String, bool> _getPrivilegesToUnlock() {
    if (nextTier == null || currentTier == null) return {};

    final nextPrivileges = _generatePrivilegesForTier(nextTier!);
    final currentPrivilegeIds = activePrivileges.keys.toSet();

    final newPrivileges = <String, bool>{};
    for (final entry in nextPrivileges.entries) {
      if (!currentPrivilegeIds.contains(entry.key)) {
        newPrivileges[entry.key] = entry.value;
      }
    }
    return newPrivileges;
  }

  Map<String, bool> _generatePrivilegesForTier(TierLevel tier) {
    // Generate privileges based on tier level
    return {
      'create_private_tournaments': tier.level >= 6,
      'invite_friends_to_events': tier.level >= 4,
      'access_advanced_statistics': tier.level >= 8,
      'custom_game_settings': tier.level >= 10,
      'priority_customer_support': tier.level >= 12,
      'beta_testing_participation': tier.level >= 14,
      'influence_game_development': tier.level >= 15,
    };
  }
}

/// Controller for tier management
class TierController extends StateNotifier<TierState> {
  final RewardsRepository _repository;
  final String userId;

  TierController({required RewardsRepository repository, required this.userId})
    : _repository = repository,
      super(const TierState());

  /// Initialize tier data
  Future<void> initialize() async {
    if (state.isLoading) return;

    state = state.copyWith(isLoading: true, error: null);

    try {
      await _loadCurrentTier();
      await _loadTierHistory();
      _calculateProjections();

      state = state.copyWith(isLoading: false, lastUpdated: DateTime.now());
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Refresh tier data
  Future<void> refresh() async {
    await initialize();
  }

  /// Load current user tier
  Future<void> _loadCurrentTier() async {
    final result = await _repository.getUserTier(userId);

    result.fold(
      (failure) =>
          throw Exception('Failed to load user tier: ${failure.message}'),
      (userTier) {
        final nextTier = userTier?.getNextTier();
        final progressToNext = userTier?.calculateProgress() ?? 0.0;
        final pointsToNext = userTier?.getPointsToNextTier() ?? 0.0;

        state = state.copyWith(
          currentTier: userTier,
          nextTier: nextTier,
          progressToNext: progressToNext,
          pointsToNext: pointsToNext,
          currentBenefits: _generateBenefitsForTier(userTier?.level),
          nextBenefits: _generateBenefitsForTier(nextTier),
          activePrivileges: _generateActivePrivileges(userTier?.level),
        );
      },
    );
  }

  /// Load tier progression history
  Future<void> _loadTierHistory() async {
    // For now, generate mock history based on current tier
    // In a real implementation, this would fetch from database
    final history = _generateMockHistory();
    state = state.copyWith(history: history);
  }

  /// Generate benefits for a tier level
  List<TierBenefit> _generateBenefitsForTier(TierLevel? tierLevel) {
    if (tierLevel == null) return [];

    final benefits = <TierBenefit>[];

    // Daily bonus benefit
    benefits.add(
      TierBenefit(
        id: 'daily_bonus',
        name: 'Daily Point Bonus',
        description:
            '+${(tierLevel.level * 5).clamp(5, 75)} daily bonus points',
        value: (tierLevel.level * 5).clamp(5, 75),
        type: BenefitType.pointsBonus,
        isActive: true,
      ),
    );

    // Achievement multiplier
    benefits.add(
      TierBenefit(
        id: 'achievement_multiplier',
        name: 'Achievement Multiplier',
        description:
            '${(1.0 + (tierLevel.level - 1) * 0.05).toStringAsFixed(2)}x achievement points',
        value: 1.0 + (tierLevel.level - 1) * 0.05,
        type: BenefitType.multiplier,
        isActive: true,
      ),
    );

    // Profile customization slots
    if (tierLevel.level >= 3) {
      benefits.add(
        TierBenefit(
          id: 'profile_slots',
          name: 'Profile Customization Slots',
          description: '${(tierLevel.level / 3).ceil()} customization slots',
          value: (tierLevel.level / 3).ceil(),
          type: BenefitType.feature,
          isActive: true,
        ),
      );
    }

    // Monthly exclusive rewards
    if (tierLevel.level >= 5) {
      benefits.add(
        TierBenefit(
          id: 'monthly_rewards',
          name: 'Monthly Exclusive Rewards',
          description: 'Access to exclusive monthly rewards',
          value: 1,
          type: BenefitType.feature,
          isActive: true,
        ),
      );
    }

    // Tournament seed bonus
    if (tierLevel.level >= 7) {
      benefits.add(
        TierBenefit(
          id: 'tournament_bonus',
          name: 'Tournament Seed Bonus',
          description: 'Better tournament seeding',
          value: 1,
          type: BenefitType.feature,
          isActive: true,
        ),
      );
    }

    // Mentor program access
    if (tierLevel.level >= 11) {
      benefits.add(
        TierBenefit(
          id: 'mentor_program',
          name: 'Mentor Program Access',
          description: 'Access to mentor program',
          value: 1,
          type: BenefitType.feature,
          isActive: true,
        ),
      );
    }

    // Legend-only competitions
    if (tierLevel.level >= 13) {
      benefits.add(
        TierBenefit(
          id: 'legend_competitions',
          name: 'Legend-Only Competitions',
          description: 'Access to exclusive legend competitions',
          value: 1,
          type: BenefitType.feature,
          isActive: true,
        ),
      );
    }

    return benefits;
  }

  /// Generate active privileges for tier
  Map<String, bool> _generateActivePrivileges(TierLevel? tierLevel) {
    if (tierLevel == null) return {};

    return {
      'create_private_tournaments': tierLevel.level >= 6,
      'invite_friends_to_events': tierLevel.level >= 4,
      'access_advanced_statistics': tierLevel.level >= 8,
      'custom_game_settings': tierLevel.level >= 10,
      'priority_customer_support': tierLevel.level >= 12,
      'beta_testing_participation': tierLevel.level >= 14,
      'influence_game_development': tierLevel.level >= 15,
    };
  }

  /// Generate mock tier history
  List<TierHistoryEntry> _generateMockHistory() {
    if (state.currentTier == null) return [];

    final history = <TierHistoryEntry>[];
    final currentLevel = state.currentTier!.level.level;
    final now = DateTime.now();

    // Generate history for each tier level achieved
    for (int i = 1; i <= currentLevel; i++) {
      final tierLevel = TierLevel.values.firstWhere(
        (t) => t.level == i,
        orElse: () => TierLevel.freshPlayer,
      );

      // Estimate when each tier was achieved (going backwards from now)
      final daysAgo = (currentLevel - i) * 30; // Assume 30 days between tiers
      final achievedAt = now.subtract(Duration(days: daysAgo));

      history.add(
        TierHistoryEntry(
          tierLevel: tierLevel,
          achievedAt: achievedAt,
          pointsAtAchievement: tierLevel.minPoints,
          benefitsUnlocked: _generateBenefitsForTier(tierLevel).length,
        ),
      );
    }

    return history.reversed.toList(); // Most recent first
  }

  /// Calculate tier projections
  void _calculateProjections() {
    if (state.currentTier == null || state.pointsToNext <= 0) return;

    // Simple projection based on recent progress
    // In a real implementation, this would analyze user's point earning velocity
    const averagePointsPerDay = 50.0; // Estimate
    final daysToNext = (state.pointsToNext / averagePointsPerDay).ceil();
    final projectedDate = DateTime.now().add(Duration(days: daysToNext));

    state = state.copyWith(projectedNextTierDate: projectedDate);
  }

  /// Check if user has specific privilege
  bool hasPrivilege(String privilege) {
    return state.activePrivileges[privilege] ?? false;
  }

  /// Get benefit by ID
  TierBenefit? getBenefit(String benefitId) {
    try {
      return state.currentBenefits.firstWhere((b) => b.id == benefitId);
    } catch (e) {
      return null;
    }
  }

  /// Get all available tiers for comparison
  List<TierLevel> getAllTiers() {
    return TierLevel.values;
  }

  /// Get tier color for UI
  String getTierColor() {
    return state.currentTier?.getTierColor() ?? '#8B4513';
  }

  /// Get tier icon for UI
  String getTierIcon() {
    return state.currentTier?.getTierIcon() ?? 'seedling';
  }

  /// Clear error state
  void clearError() {
    state = state.copyWith(error: null);
  }
}

/// Tier benefit model
class TierBenefit {
  final String id;
  final String name;
  final String description;
  final dynamic value;
  final BenefitType type;
  final bool isActive;

  const TierBenefit({
    required this.id,
    required this.name,
    required this.description,
    required this.value,
    required this.type,
    required this.isActive,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TierBenefit && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// Types of tier benefits
enum BenefitType { pointsBonus, multiplier, feature, access, cosmetic }

/// Tier history entry
class TierHistoryEntry {
  final TierLevel tierLevel;
  final DateTime achievedAt;
  final double pointsAtAchievement;
  final int benefitsUnlocked;

  const TierHistoryEntry({
    required this.tierLevel,
    required this.achievedAt,
    required this.pointsAtAchievement,
    required this.benefitsUnlocked,
  });
}

/// Tier progress summary
class TierProgressSummary {
  final int currentTierLevel;
  final String currentTierName;
  final int nextTierLevel;
  final String nextTierName;
  final double progressPercentage;
  final double pointsNeeded;
  final double currentPoints;
  final int? estimatedDaysToNext;
  final int benefitsCount;
  final int privilegesCount;

  const TierProgressSummary({
    required this.currentTierLevel,
    required this.currentTierName,
    required this.nextTierLevel,
    required this.nextTierName,
    required this.progressPercentage,
    required this.pointsNeeded,
    required this.currentPoints,
    this.estimatedDaysToNext,
    required this.benefitsCount,
    required this.privilegesCount,
  });
}

/// Tier comparison model
class TierComparison {
  final List<TierBenefit> currentBenefits;
  final List<TierBenefit> nextBenefits;
  final List<TierBenefit> benefitsToUnlock;
  final Map<String, bool> privilegesToUnlock;

  const TierComparison({
    required this.currentBenefits,
    required this.nextBenefits,
    required this.benefitsToUnlock,
    required this.privilegesToUnlock,
  });
}
