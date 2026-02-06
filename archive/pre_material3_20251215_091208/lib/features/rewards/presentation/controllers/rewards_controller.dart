import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dabbler/data/models/rewards/points_transaction.dart';
import 'package:dabbler/data/models/rewards/tier.dart';
import '../../domain/repositories/rewards_repository.dart';

// Type aliases for backward compatibility
typedef PointTransaction = PointsTransaction;
typedef TransactionType = PointsTransactionType;

/// Overall state for the rewards system
class RewardsState {
  final double totalPoints;
  final double todayPoints;
  final double weeklyPoints;
  final UserTier? currentTier;
  final double tierProgress;
  final double pointsToNextTier;
  final List<PointTransaction> recentTransactions;
  final List<RewardNotification> pendingNotifications;
  final bool isLoading;
  final String? error;
  final DateTime? lastUpdated;
  final Map<String, dynamic> cache;

  const RewardsState({
    this.totalPoints = 0.0,
    this.todayPoints = 0.0,
    this.weeklyPoints = 0.0,
    this.currentTier,
    this.tierProgress = 0.0,
    this.pointsToNextTier = 0.0,
    this.recentTransactions = const [],
    this.pendingNotifications = const [],
    this.isLoading = false,
    this.error,
    this.lastUpdated,
    this.cache = const {},
  });

  RewardsState copyWith({
    double? totalPoints,
    double? todayPoints,
    double? weeklyPoints,
    UserTier? currentTier,
    double? tierProgress,
    double? pointsToNextTier,
    List<PointTransaction>? recentTransactions,
    List<RewardNotification>? pendingNotifications,
    bool? isLoading,
    String? error,
    DateTime? lastUpdated,
    Map<String, dynamic>? cache,
  }) {
    return RewardsState(
      totalPoints: totalPoints ?? this.totalPoints,
      todayPoints: todayPoints ?? this.todayPoints,
      weeklyPoints: weeklyPoints ?? this.weeklyPoints,
      currentTier: currentTier ?? this.currentTier,
      tierProgress: tierProgress ?? this.tierProgress,
      pointsToNextTier: pointsToNextTier ?? this.pointsToNextTier,
      recentTransactions: recentTransactions ?? this.recentTransactions,
      pendingNotifications: pendingNotifications ?? this.pendingNotifications,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      cache: cache ?? this.cache,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RewardsState &&
        other.totalPoints == totalPoints &&
        other.todayPoints == todayPoints &&
        other.weeklyPoints == weeklyPoints &&
        other.currentTier == currentTier &&
        other.tierProgress == tierProgress &&
        other.pointsToNextTier == pointsToNextTier &&
        other.isLoading == isLoading &&
        other.error == error;
  }

  @override
  int get hashCode {
    return totalPoints.hashCode ^
        todayPoints.hashCode ^
        weeklyPoints.hashCode ^
        currentTier.hashCode ^
        tierProgress.hashCode ^
        pointsToNextTier.hashCode ^
        isLoading.hashCode ^
        error.hashCode;
  }

  @override
  String toString() {
    return 'RewardsState(points: $totalPoints, tier: ${currentTier?.level.displayName}, loading: $isLoading)';
  }
}

/// Controller managing overall rewards state
class RewardsController extends StateNotifier<RewardsState> {
  final RewardsRepository _repository;
  final String userId;

  // Cache configuration
  static const Duration _cacheExpiration = Duration(minutes: 5);
  static const int _maxRecentTransactions = 20;

  RewardsController({
    required RewardsRepository repository,
    required this.userId,
  }) : _repository = repository,
       super(const RewardsState());

  /// Initialize rewards data
  Future<void> initialize() async {
    if (state.isLoading) return;

    state = state.copyWith(isLoading: true, error: null);

    try {
      await _loadUserRewards();
      await _loadRecentTransactions();
      await _loadPendingNotifications();

      state = state.copyWith(isLoading: false, lastUpdated: DateTime.now());
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Refresh all rewards data
  Future<void> refresh({bool force = false}) async {
    // Check cache validity
    if (!force && _isCacheValid()) {
      return;
    }

    await initialize();
  }

  /// Load user's total points and tier information
  Future<void> _loadUserRewards() async {
    final tierResult = await _repository.getUserTier(userId);
    final transactionsResult = await _repository.getPointTransactions(
      userId,
      limit: 100,
    );

    // Calculate total points from transactions
    double totalPoints = 0.0;
    double todayPoints = 0.0;
    double weeklyPoints = 0.0;

    await transactionsResult.fold(
      (failure) =>
          throw Exception('Failed to load transactions: ${failure.message}'),
      (transactions) async {
        // Calculate totals from transactions
        totalPoints = transactions.fold(
          0.0,
          (sum, t) => sum + t.points.toDouble(),
        );

        final now = DateTime.now();
        final startOfDay = DateTime(now.year, now.month, now.day);
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        final startOfWeekDay = DateTime(
          startOfWeek.year,
          startOfWeek.month,
          startOfWeek.day,
        );

        todayPoints = transactions
            .where((t) => t.createdAt.isAfter(startOfDay))
            .fold(0.0, (sum, t) => sum + t.points.toDouble());

        weeklyPoints = transactions
            .where((t) => t.createdAt.isAfter(startOfWeekDay))
            .fold(0.0, (sum, t) => sum + t.points.toDouble());

        await tierResult.fold(
          (failure) =>
              throw Exception('Failed to load tier: ${failure.message}'),
          (userTier) async {
            final tierProgress = userTier?.calculateProgress() ?? 0.0;
            final pointsToNext = userTier?.getPointsToNextTier() ?? 0.0;

            state = state.copyWith(
              totalPoints: totalPoints,
              todayPoints: todayPoints,
              weeklyPoints: weeklyPoints,
              currentTier: userTier,
              tierProgress: tierProgress,
              pointsToNextTier: pointsToNext,
            );
          },
        );
      },
    );
  }

  /// Load recent point transactions
  Future<void> _loadRecentTransactions() async {
    final transactionsResult = await _repository.getPointTransactions(
      userId,
      limit: _maxRecentTransactions,
    );

    transactionsResult.fold(
      (failure) =>
          throw Exception('Failed to load transactions: ${failure.message}'),
      (transactions) {
        state = state.copyWith(recentTransactions: transactions);
      },
    );
  }

  /// Load pending reward notifications
  Future<void> _loadPendingNotifications() async {
    // For now, initialize with empty notifications
    // In a real implementation, this would fetch from a notifications service
    state = state.copyWith(pendingNotifications: []);
  }

  /// Add points and update state
  Future<void> addPoints({
    required double points,
    required TransactionType type,
    required String description,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      // For now, simulate adding points by updating local state
      // In a real implementation, this would use a use case to add points

      final transaction = PointTransaction(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: userId,
        points: points.round(),
        type: type,
        reason: description,
        sourceId: metadata?['sourceId'] as String?,
        sourceType: metadata?['sourceType'] as String?,
        createdAt: DateTime.now(),
      );

      // Update local state immediately
      final updatedTransactions = [
        transaction,
        ...state.recentTransactions,
      ].take(_maxRecentTransactions).toList();

      state = state.copyWith(
        totalPoints: state.totalPoints + points,
        recentTransactions: updatedTransactions,
      );

      // Check for tier progression
      await _checkTierProgression();

      // Refresh to get accurate data
      await refresh(force: true);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// Check and handle tier progression
  Future<void> _checkTierProgression() async {
    if (state.currentTier == null) return;

    final nextTier = state.currentTier!.getNextTier();
    if (nextTier != null && state.totalPoints >= nextTier.minPoints) {
      // Trigger tier progression
      await _handleTierProgression(nextTier);
    }
  }

  /// Handle tier progression
  Future<void> _handleTierProgression(TierLevel newTierLevel) async {
    try {
      // Create new tier progression notification
      final notification = RewardNotification(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: userId,
        type: NotificationType.tierProgression,
        title: 'Tier Up!',
        message:
            'Congratulations! You\'ve reached ${newTierLevel.displayName}!',
        data: {
          'previous_tier': state.currentTier?.level.level,
          'new_tier': newTierLevel.level,
          'tier_name': newTierLevel.displayName,
        },
        createdAt: DateTime.now(),
        isRead: false,
      );

      // Add to pending notifications
      final updatedNotifications = [
        notification,
        ...state.pendingNotifications,
      ];
      state = state.copyWith(pendingNotifications: updatedNotifications);

      // Refresh tier data
      await refresh(force: true);
    } catch (e) {
      // Tier progression notification failure shouldn't break the flow
    }
  }

  /// Mark notification as read
  void markNotificationRead(String notificationId) {
    final updatedNotifications = state.pendingNotifications
        .map(
          (notification) => notification.id == notificationId
              ? notification.copyWith(isRead: true)
              : notification,
        )
        .toList();

    state = state.copyWith(pendingNotifications: updatedNotifications);
  }

  /// Clear all notifications
  void clearAllNotifications() {
    state = state.copyWith(pendingNotifications: []);
  }

  /// Get cached value
  T? getCachedValue<T>(String key) {
    final cached = state.cache[key];
    if (cached is Map<String, dynamic>) {
      final timestamp = cached['timestamp'] as DateTime?;
      if (timestamp != null &&
          DateTime.now().difference(timestamp) < _cacheExpiration) {
        return cached['value'] as T?;
      }
    }
    return null;
  }

  /// Set cached value
  void setCachedValue<T>(String key, T value) {
    final updatedCache = Map<String, dynamic>.from(state.cache);
    updatedCache[key] = {'value': value, 'timestamp': DateTime.now()};
    state = state.copyWith(cache: updatedCache);
  }

  /// Check if cache is valid
  bool _isCacheValid() {
    if (state.lastUpdated == null) return false;
    return DateTime.now().difference(state.lastUpdated!) < _cacheExpiration;
  }

  /// Clear error state
  void clearError() {
    state = state.copyWith(error: null);
  }

  /// Get summary statistics
  RewardsSummary getSummary() {
    return RewardsSummary(
      totalPoints: state.totalPoints,
      todayPoints: state.todayPoints,
      weeklyPoints: state.weeklyPoints,
      currentTier: state.currentTier?.level,
      tierProgress: state.tierProgress,
      pointsToNextTier: state.pointsToNextTier,
      recentTransactionCount: state.recentTransactions.length,
      unreadNotifications: state.pendingNotifications
          .where((n) => !n.isRead)
          .length,
      lastUpdated: state.lastUpdated,
    );
  }

  @override
  void dispose() {
    // Clean up resources if needed
    super.dispose();
  }
}

/// Reward notification model
class RewardNotification {
  final String id;
  final String userId;
  final NotificationType type;
  final String title;
  final String message;
  final Map<String, dynamic> data;
  final DateTime createdAt;
  final bool isRead;

  const RewardNotification({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.message,
    required this.data,
    required this.createdAt,
    required this.isRead,
  });

  RewardNotification copyWith({
    String? id,
    String? userId,
    NotificationType? type,
    String? title,
    String? message,
    Map<String, dynamic>? data,
    DateTime? createdAt,
    bool? isRead,
  }) {
    return RewardNotification(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      title: title ?? this.title,
      message: message ?? this.message,
      data: data ?? this.data,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
    );
  }
}

/// Types of reward notifications
enum NotificationType {
  achievementUnlocked,
  tierProgression,
  badgeEarned,
  milestoneReached,
  streakBonus,
  dailyReward,
  weeklyReward,
  specialEvent,
}

/// Summary statistics for rewards
class RewardsSummary {
  final double totalPoints;
  final double todayPoints;
  final double weeklyPoints;
  final TierLevel? currentTier;
  final double tierProgress;
  final double pointsToNextTier;
  final int recentTransactionCount;
  final int unreadNotifications;
  final DateTime? lastUpdated;

  const RewardsSummary({
    required this.totalPoints,
    required this.todayPoints,
    required this.weeklyPoints,
    this.currentTier,
    required this.tierProgress,
    required this.pointsToNextTier,
    required this.recentTransactionCount,
    required this.unreadNotifications,
    this.lastUpdated,
  });

  @override
  String toString() {
    return 'RewardsSummary(points: $totalPoints, tier: ${currentTier?.displayName}, notifications: $unreadNotifications)';
  }
}
