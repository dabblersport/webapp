import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';

import 'package:dabbler/data/models/rewards/badge_tier.dart';
import 'package:dabbler/data/models/rewards/tier.dart';
import '../domain/repositories/rewards_repository.dart';

/// Tier benefit data
class TierBenefit {
  final String id;
  final String name;
  final String description;
  final TierBenefitType type;
  final Map<String, dynamic> config;
  final bool isActive;
  final DateTime? activatedAt;
  final DateTime? expiresAt;

  const TierBenefit({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    required this.config,
    this.isActive = true,
    this.activatedAt,
    this.expiresAt,
  });

  bool get isExpired => expiresAt != null && DateTime.now().isAfter(expiresAt!);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'type': type.name,
      'config': config,
      'isActive': isActive,
      'activatedAt': activatedAt?.toIso8601String(),
      'expiresAt': expiresAt?.toIso8601String(),
    };
  }

  factory TierBenefit.fromMap(Map<String, dynamic> map) {
    return TierBenefit(
      id: map['id'],
      name: map['name'],
      description: map['description'],
      type: TierBenefitType.values.firstWhere(
        (t) => t.name == map['type'],
        orElse: () => TierBenefitType.other,
      ),
      config: Map<String, dynamic>.from(map['config']),
      isActive: map['isActive'] ?? true,
      activatedAt: map['activatedAt'] != null
          ? DateTime.parse(map['activatedAt'])
          : null,
      expiresAt: map['expiresAt'] != null
          ? DateTime.parse(map['expiresAt'])
          : null,
    );
  }
}

/// Types of tier benefits
enum TierBenefitType {
  pointsMultiplier,
  exclusiveContent,
  prioritySupport,
  customization,
  earlyAccess,
  freeFeatures,
  socialPerks,
  gamingBoosts,
  other,
}

/// Tier upgrade history entry
class TierUpgradeHistory {
  final String id;
  final String userId;
  final BadgeTier fromTier;
  final BadgeTier toTier;
  final DateTime upgradedAt;
  final int pointsAtUpgrade;
  final String reason;
  final List<TierBenefit> benefitsUnlocked;
  final Map<String, dynamic>? metadata;

  const TierUpgradeHistory({
    required this.id,
    required this.userId,
    required this.fromTier,
    required this.toTier,
    required this.upgradedAt,
    required this.pointsAtUpgrade,
    required this.reason,
    required this.benefitsUnlocked,
    this.metadata,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'fromTier': fromTier.name,
      'toTier': toTier.name,
      'upgradedAt': upgradedAt.toIso8601String(),
      'pointsAtUpgrade': pointsAtUpgrade,
      'reason': reason,
      'benefitsUnlocked': benefitsUnlocked.map((b) => b.toMap()).toList(),
      'metadata': metadata,
    };
  }

  factory TierUpgradeHistory.fromMap(Map<String, dynamic> map) {
    return TierUpgradeHistory(
      id: map['id'],
      userId: map['userId'],
      fromTier: BadgeTier.values.firstWhere(
        (t) => t.name == map['fromTier'],
        orElse: () => BadgeTier.bronze,
      ),
      toTier: BadgeTier.values.firstWhere(
        (t) => t.name == map['toTier'],
        orElse: () => BadgeTier.bronze,
      ),
      upgradedAt: DateTime.parse(map['upgradedAt']),
      pointsAtUpgrade: map['pointsAtUpgrade'],
      reason: map['reason'],
      benefitsUnlocked: (map['benefitsUnlocked'] as List)
          .map((b) => TierBenefit.fromMap(b))
          .toList(),
      metadata: map['metadata'],
    );
  }
}

/// Tier projection data
class TierProjection {
  final BadgeTier currentTier;
  final BadgeTier? nextTier;
  final int currentPoints;
  final int pointsToNextTier;
  final int totalPointsForNextTier;
  final double progressToNext;
  final Duration? estimatedTimeToNext;
  final List<TierBenefit> nextTierBenefits;
  final Map<BadgeTier, int> allTierRequirements;

  const TierProjection({
    required this.currentTier,
    this.nextTier,
    required this.currentPoints,
    required this.pointsToNextTier,
    required this.totalPointsForNextTier,
    required this.progressToNext,
    this.estimatedTimeToNext,
    required this.nextTierBenefits,
    required this.allTierRequirements,
  });

  bool get canUpgrade => nextTier != null && pointsToNextTier <= 0;
  bool get isMaxTier => nextTier == null;

  Map<String, dynamic> toMap() {
    return {
      'currentTier': currentTier.name,
      'nextTier': nextTier?.name,
      'currentPoints': currentPoints,
      'pointsToNextTier': pointsToNextTier,
      'totalPointsForNextTier': totalPointsForNextTier,
      'progressToNext': progressToNext,
      'estimatedTimeToNext': estimatedTimeToNext?.inMilliseconds,
      'nextTierBenefits': nextTierBenefits.map((b) => b.toMap()).toList(),
      'allTierRequirements': allTierRequirements.map(
        (tier, points) => MapEntry(tier.name, points),
      ),
    };
  }
}

/// Tier calculation service
class TierCalculationService extends ChangeNotifier {
  final RewardsRepository _repository;

  // Tier requirements (points needed for each tier)
  static const Map<BadgeTier, int> _tierRequirements = {
    BadgeTier.bronze: 0,
    BadgeTier.silver: 1000,
    BadgeTier.gold: 5000,
    BadgeTier.platinum: 15000,
    BadgeTier.diamond: 50000,
  };

  // Benefits for each tier
  static const Map<BadgeTier, List<Map<String, dynamic>>> _tierBenefits = {
    BadgeTier.bronze: [
      {
        'id': 'bronze_welcome',
        'name': 'Welcome Bonus',
        'description': 'Get started with basic features',
        'type': 'other',
        'config': {},
      },
    ],
    BadgeTier.silver: [
      {
        'id': 'silver_multiplier',
        'name': '1.2x Points Multiplier',
        'description': 'Earn 20% more points on all activities',
        'type': 'pointsMultiplier',
        'config': {'multiplier': 1.2},
      },
      {
        'id': 'silver_customization',
        'name': 'Profile Customization',
        'description': 'Unlock additional avatar options',
        'type': 'customization',
        'config': {'avatarOptions': 5},
      },
    ],
    BadgeTier.gold: [
      {
        'id': 'gold_multiplier',
        'name': '1.5x Points Multiplier',
        'description': 'Earn 50% more points on all activities',
        'type': 'pointsMultiplier',
        'config': {'multiplier': 1.5},
      },
      {
        'id': 'gold_exclusive',
        'name': 'Exclusive Content',
        'description': 'Access to gold-tier exclusive games',
        'type': 'exclusiveContent',
        'config': {
          'contentIds': ['gold_game_1', 'gold_game_2'],
        },
      },
      {
        'id': 'gold_priority',
        'name': 'Priority Support',
        'description': 'Get priority customer support',
        'type': 'prioritySupport',
        'config': {'responseTime': '2 hours'},
      },
    ],
    BadgeTier.platinum: [
      {
        'id': 'platinum_multiplier',
        'name': '2x Points Multiplier',
        'description': 'Double points on all activities',
        'type': 'pointsMultiplier',
        'config': {'multiplier': 2.0},
      },
      {
        'id': 'platinum_early_access',
        'name': 'Early Access',
        'description': 'Get early access to new features',
        'type': 'earlyAccess',
        'config': {'daysEarly': 7},
      },
      {
        'id': 'platinum_free_features',
        'name': 'Premium Features',
        'description': 'All premium features included',
        'type': 'freeFeatures',
        'config': {'premiumFeatures': 'all'},
      },
      {
        'id': 'platinum_social',
        'name': 'Social Perks',
        'description': 'Enhanced social features and recognition',
        'type': 'socialPerks',
        'config': {'specialBadge': true},
      },
    ],
    BadgeTier.diamond: [
      {
        'id': 'diamond_multiplier',
        'name': '3x Points Multiplier',
        'description': 'Triple points on all activities',
        'type': 'pointsMultiplier',
        'config': {'multiplier': 3.0},
      },
      {
        'id': 'diamond_vip',
        'name': 'VIP Treatment',
        'description': 'Ultimate VIP experience with all perks',
        'type': 'other',
        'config': {'vipLevel': 'ultimate'},
      },
      {
        'id': 'diamond_gaming_boosts',
        'name': 'Gaming Boosts',
        'description': 'Special boosts and power-ups in games',
        'type': 'gamingBoosts',
        'config': {'boostMultiplier': 2.5},
      },
      {
        'id': 'diamond_exclusive_events',
        'name': 'Exclusive Events',
        'description': 'Access to diamond-only events and tournaments',
        'type': 'exclusiveContent',
        'config': {
          'eventTypes': ['tournaments', 'special_challenges'],
        },
      },
    ],
  };

  // Cache
  final Map<String, TierProjection> _projectionCache = {};
  final Map<String, List<TierBenefit>> _benefitsCache = {};
  final Map<String, List<TierUpgradeHistory>> _historyCache = {};

  // State
  bool _isInitialized = false;
  String? _currentUserId;
  Timer? _calculationTimer;

  TierCalculationService({required RewardsRepository repository})
    : _repository = repository;

  // Getters
  bool get isInitialized => _isInitialized;
  String? get currentUserId => _currentUserId;
  Map<BadgeTier, int> get tierRequirements => Map.from(_tierRequirements);

  /// Initialize the service
  Future<void> initialize(String userId) async {
    if (_isInitialized && _currentUserId == userId) return;

    try {
      _currentUserId = userId;

      // Start periodic calculations
      _startCalculationTimer();

      // Load initial data
      await _loadInitialData();

      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  /// Dispose of the service
  @override
  void dispose() {
    _calculationTimer?.cancel();
    super.dispose();
  }

  /// Calculate current tier from points
  BadgeTier calculateTierFromPoints(int points) {
    BadgeTier currentTier = BadgeTier.bronze;

    for (final entry in _tierRequirements.entries) {
      if (points >= entry.value) {
        currentTier = entry.key;
      } else {
        break;
      }
    }

    return currentTier;
  }

  /// Get tier projection for user
  Future<TierProjection> getTierProjection(String userId) async {
    // Check cache first
    if (_projectionCache.containsKey(userId)) {
      return _projectionCache[userId]!;
    }

    try {
      final currentPointsResult = await _repository.getUserPoints(userId);
      final currentPoints = currentPointsResult.fold(
        (failure) => 0.0,
        (points) => points,
      );

      final projection = _calculateProjection(currentPoints.toInt());

      // Cache the result
      _projectionCache[userId] = projection;

      return projection;
    } catch (e) {
      rethrow;
    }
  }

  /// Get user's active benefits
  Future<List<TierBenefit>> getUserBenefits(String userId) async {
    // Check cache first
    if (_benefitsCache.containsKey(userId)) {
      return _benefitsCache[userId]!;
    }

    try {
      final userProgressResult = await _repository.getUserProgress(userId);
      final userProgress = userProgressResult.fold(
        (failure) => null,
        (progressList) => progressList.isNotEmpty ? progressList.first : null,
      );

      if (userProgress == null) {
        return [];
      }

      final benefits = await _getBenefitsForTier(
        BadgeTier.bronze,
      ); // Default tier

      // Cache the result
      _benefitsCache[userId] = benefits;

      return benefits;
    } catch (e) {
      return [];
    }
  }

  /// Apply tier benefits to user
  Future<void> applyTierBenefits(String userId, BadgeTier tier) async {
    try {
      final benefits = await _getBenefitsForTier(tier);

      for (final benefit in benefits) {
        await _applyBenefit(userId, benefit);
      }

      // Clear cache
      _benefitsCache.remove(userId);
      _projectionCache.remove(userId);

      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  /// Check if user qualifies for tier upgrade
  Future<BadgeTier?> checkTierUpgrade(String userId) async {
    try {
      final currentPointsResult = await _repository.getUserPoints(userId);
      final currentPoints = currentPointsResult.fold(
        (failure) => 0.0,
        (points) => points,
      );

      final userProgressResult = await _repository.getUserProgress(userId);
      final userProgress = userProgressResult.fold(
        (failure) => null,
        (progressList) => progressList.isNotEmpty ? progressList.first : null,
      );

      if (userProgress == null) return null;

      final newTier = calculateTierFromPoints(currentPoints.toInt());
      final currentTier = BadgeTier.bronze; // Default tier

      if (newTier != currentTier && _isHigherTier(newTier, currentTier)) {
        await _processTierUpgrade(
          userId,
          currentTier,
          newTier,
          currentPoints.toInt(),
        );
        return newTier;
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  /// Get tier upgrade history for user
  Future<List<TierUpgradeHistory>> getTierUpgradeHistory(String userId) async {
    // Check cache first
    if (_historyCache.containsKey(userId)) {
      return _historyCache[userId]!;
    }

    try {
      final historyResult = await _repository.getTierUpgradeHistory(userId);
      final historyMaps = historyResult.fold(
        (failure) => <Map<String, dynamic>>[],
        (history) => history,
      );

      final history = historyMaps
          .map((map) => TierUpgradeHistory.fromMap(map))
          .toList();

      // Cache the result
      _historyCache[userId] = history;

      return history;
    } catch (e) {
      return [];
    }
  }

  /// Get points multiplier for user's current tier
  Future<double> getPointsMultiplier(String userId) async {
    try {
      final benefits = await getUserBenefits(userId);

      for (final benefit in benefits) {
        if (benefit.type == TierBenefitType.pointsMultiplier &&
            benefit.isActive &&
            !benefit.isExpired) {
          return benefit.config['multiplier']?.toDouble() ?? 1.0;
        }
      }

      return 1.0;
    } catch (e) {
      return 1.0;
    }
  }

  /// Estimate time to reach next tier
  Future<Duration?> estimateTimeToNextTier(
    String userId, {
    int? averagePointsPerDay,
  }) async {
    try {
      final projection = await getTierProjection(userId);

      if (projection.isMaxTier || projection.pointsToNextTier <= 0) {
        return null;
      }

      // Use provided average or calculate from user history
      final dailyRate =
          averagePointsPerDay ?? await _calculateDailyPointsRate(userId);

      if (dailyRate <= 0) {
        return null;
      }

      final daysNeeded = (projection.pointsToNextTier / dailyRate).ceil();
      return Duration(days: daysNeeded);
    } catch (e) {
      return null;
    }
  }

  /// Clear cache for user
  void clearUserCache(String userId) {
    _projectionCache.remove(userId);
    _benefitsCache.remove(userId);
    _historyCache.remove(userId);
    notifyListeners();
  }

  /// Clear all cache
  void clearAllCache() {
    _projectionCache.clear();
    _benefitsCache.clear();
    _historyCache.clear();
    notifyListeners();
  }

  // Private methods

  TierProjection _calculateProjection(int currentPoints) {
    final currentTier = calculateTierFromPoints(currentPoints);
    BadgeTier? nextTier;
    int pointsToNextTier = 0;
    int totalPointsForNextTier = 0;
    double progressToNext = 1.0;

    // Find next tier
    final tierList = BadgeTier.values;
    final currentIndex = tierList.indexOf(currentTier);

    if (currentIndex < tierList.length - 1) {
      nextTier = tierList[currentIndex + 1];
      totalPointsForNextTier = _tierRequirements[nextTier]!;
      pointsToNextTier = totalPointsForNextTier - currentPoints;

      if (pointsToNextTier < 0) pointsToNextTier = 0;

      final currentTierPoints = _tierRequirements[currentTier]!;
      final tierRange = totalPointsForNextTier - currentTierPoints;
      final progressInTier = currentPoints - currentTierPoints;

      progressToNext = tierRange > 0
          ? (progressInTier / tierRange).clamp(0.0, 1.0)
          : 1.0;
    }

    return TierProjection(
      currentTier: currentTier,
      nextTier: nextTier,
      currentPoints: currentPoints,
      pointsToNextTier: math.max(0, pointsToNextTier),
      totalPointsForNextTier: totalPointsForNextTier,
      progressToNext: progressToNext,
      nextTierBenefits: nextTier != null
          ? _getBenefitsForTierSync(nextTier)
          : [],
      allTierRequirements: Map.from(_tierRequirements),
    );
  }

  Future<List<TierBenefit>> _getBenefitsForTier(BadgeTier tier) async {
    final benefitMaps = _tierBenefits[tier] ?? [];

    return benefitMaps
        .map((benefitMap) => TierBenefit.fromMap(benefitMap))
        .toList();
  }

  List<TierBenefit> _getBenefitsForTierSync(BadgeTier tier) {
    final benefitMaps = _tierBenefits[tier] ?? [];

    return benefitMaps
        .map((benefitMap) => TierBenefit.fromMap(benefitMap))
        .toList();
  }

  Future<void> _applyBenefit(String userId, TierBenefit benefit) async {
    try {
      switch (benefit.type) {
        case TierBenefitType.pointsMultiplier:
          // Points multiplier is applied during point calculations
          break;
        case TierBenefitType.exclusiveContent:
          await _unlockExclusiveContent(userId, benefit.config);
          break;
        case TierBenefitType.prioritySupport:
          await _enablePrioritySupport(userId, benefit.config);
          break;
        case TierBenefitType.customization:
          await _unlockCustomization(userId, benefit.config);
          break;
        case TierBenefitType.earlyAccess:
          await _enableEarlyAccess(userId, benefit.config);
          break;
        case TierBenefitType.freeFeatures:
          await _enableFreeFeatures(userId, benefit.config);
          break;
        case TierBenefitType.socialPerks:
          await _enableSocialPerks(userId, benefit.config);
          break;
        case TierBenefitType.gamingBoosts:
          await _enableGamingBoosts(userId, benefit.config);
          break;
        case TierBenefitType.other:
          await _applyOtherBenefit(userId, benefit);
          break;
      }
    } catch (e) {}
  }

  Future<void> _processTierUpgrade(
    String userId,
    BadgeTier fromTier,
    BadgeTier toTier,
    int currentPoints,
  ) async {
    try {
      // Convert BadgeTier to TierLevel (simple mapping for now)
      final tierLevel = _badgeTierToTierLevel(toTier);

      // Create UserTier object
      final userTier = UserTier(
        id: _generateUpgradeId(),
        userId: userId,
        level: tierLevel,
        currentPoints: currentPoints.toDouble(),
        pointsInTier: currentPoints.toDouble(),
        achievedAt: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Update user's tier
      await _repository.updateUserTier(userId, userTier);

      // Get benefits for new tier
      final newBenefits = await _getBenefitsForTier(toTier);

      // Apply tier benefits
      await applyTierBenefits(userId, toTier);

      // Create upgrade history entry
      final upgradeHistory = TierUpgradeHistory(
        id: _generateUpgradeId(),
        userId: userId,
        fromTier: fromTier,
        toTier: toTier,
        upgradedAt: DateTime.now(),
        pointsAtUpgrade: currentPoints,
        reason: 'Points threshold reached',
        benefitsUnlocked: newBenefits,
      );

      // Save upgrade history
      await _repository.saveTierUpgradeHistory(userId, upgradeHistory.toMap());

      // Clear cache
      clearUserCache(userId);
    } catch (e) {
      rethrow;
    }
  }

  bool _isHigherTier(BadgeTier tier1, BadgeTier tier2) {
    return BadgeTier.values.indexOf(tier1) > BadgeTier.values.indexOf(tier2);
  }

  Future<int> _calculateDailyPointsRate(String userId) async {
    try {
      final transactionsResult = await _repository.getTransactionHistory(
        userId,
        limit: 100,
      );

      final transactions = transactionsResult.fold(
        (failure) => <PointTransaction>[],
        (transactionList) => transactionList,
      );

      if (transactions.isEmpty) return 0;

      final now = DateTime.now();
      final recentTransactions = transactions.where((t) {
        final daysDiff = now.difference(t.createdAt).inDays;
        return daysDiff <= 30; // Last 30 days
      }).toList();

      if (recentTransactions.isEmpty) return 0;

      final totalPoints = recentTransactions
          .where((t) => t.finalPoints > 0)
          .fold<double>(0.0, (sum, t) => sum + t.finalPoints);

      final oldestTransaction = recentTransactions.last;
      final daysDiff = math.max(
        1,
        now.difference(oldestTransaction.createdAt).inDays,
      );

      return (totalPoints / daysDiff).round();
    } catch (e) {
      return 0;
    }
  }

  void _startCalculationTimer() {
    _calculationTimer?.cancel();
    _calculationTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => _performPeriodicCalculations(),
    );
  }

  Future<void> _performPeriodicCalculations() async {
    if (_currentUserId == null) return;

    try {
      // Check for tier upgrades
      await checkTierUpgrade(_currentUserId!);

      // Refresh projection cache
      _projectionCache.remove(_currentUserId!);
      await getTierProjection(_currentUserId!);
    } catch (e) {}
  }

  Future<void> _loadInitialData() async {
    if (_currentUserId == null) return;

    try {
      // Preload projection and benefits
      await Future.wait([
        getTierProjection(_currentUserId!),
        getUserBenefits(_currentUserId!),
      ]);
    } catch (e) {}
  }

  String _generateUpgradeId() {
    return '${DateTime.now().millisecondsSinceEpoch}_${_currentUserId ?? 'unknown'}';
  }

  // Benefit application methods
  Future<void> _unlockExclusiveContent(
    String userId,
    Map<String, dynamic> config,
  ) async {
    // Implementation for unlocking exclusive content
  }

  Future<void> _enablePrioritySupport(
    String userId,
    Map<String, dynamic> config,
  ) async {
    // Implementation for enabling priority support
  }

  Future<void> _unlockCustomization(
    String userId,
    Map<String, dynamic> config,
  ) async {
    // Implementation for unlocking customization options
  }

  Future<void> _enableEarlyAccess(
    String userId,
    Map<String, dynamic> config,
  ) async {
    // Implementation for enabling early access
  }

  Future<void> _enableFreeFeatures(
    String userId,
    Map<String, dynamic> config,
  ) async {
    // Implementation for enabling free features
  }

  Future<void> _enableSocialPerks(
    String userId,
    Map<String, dynamic> config,
  ) async {
    // Implementation for enabling social perks
  }

  Future<void> _enableGamingBoosts(
    String userId,
    Map<String, dynamic> config,
  ) async {
    // Implementation for enabling gaming boosts
  }

  Future<void> _applyOtherBenefit(String userId, TierBenefit benefit) async {
    // Implementation for other benefit types
  }

  /// Map BadgeTier to TierLevel
  TierLevel _badgeTierToTierLevel(BadgeTier badgeTier) {
    switch (badgeTier) {
      case BadgeTier.bronze:
        return TierLevel.rookie;
      case BadgeTier.silver:
        return TierLevel.competitor;
      case BadgeTier.gold:
        return TierLevel.expert;
      case BadgeTier.platinum:
        return TierLevel.master;
      case BadgeTier.diamond:
        return TierLevel.legend;
    }
  }
}
