import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dabbler/data/models/rewards/achievement.dart';
import 'package:dabbler/data/models/rewards/badge.dart';
import 'package:dabbler/data/models/rewards/leaderboard_entry.dart';
import 'package:dabbler/data/models/rewards/user_progress.dart';
import 'package:dabbler/data/models/rewards/tier.dart';
import 'package:dabbler/data/models/rewards/points_transaction.dart';
import '../../domain/repositories/rewards_repository.dart';
import '../../data/repositories/rewards_repository_impl.dart';
import '../controllers/rewards_controller.dart';
import '../controllers/achievements_controller.dart';
import '../controllers/tier_controller.dart';
import '../controllers/badge_controller.dart';
import '../controllers/leaderboard_controller.dart';
import '../controllers/progress_tracking_controller.dart';

// Type aliases for backward compatibility
typedef PointTransaction = PointsTransaction;
typedef TransactionType = PointsTransactionType;

// =============================================================================
// REPOSITORY PROVIDERS
// =============================================================================

/// Mock user ID provider - replace with actual auth service integration
final currentUserIdProvider = Provider<String>((ref) {
  // NOTE: Keep this in sync with mock data in RewardsRepositoryImpl until real auth wired.
  return 'current_user_id'; // Replace with actual user ID from auth
});

/// Mock repository provider - replace with actual implementation
final rewardsRepositoryProvider = Provider<RewardsRepository>((ref) {
  // Temporary in-memory implementation so UI can function without backend.
  // Replace with a proper data-source backed implementation (Supabase) later.
  return RewardsRepositoryImpl();
});

// =============================================================================
// CONTROLLER PROVIDERS
// =============================================================================

/// Provides the rewards controller with current user context
final rewardsControllerProvider =
    StateNotifierProvider<RewardsController, RewardsState>((ref) {
      final repository = ref.watch(rewardsRepositoryProvider);
      final userId = ref.watch(currentUserIdProvider);
      return RewardsController(repository: repository, userId: userId);
    });

/// Provides the achievements controller with current user context
final achievementsControllerProvider =
    StateNotifierProvider<AchievementsController, AchievementsState>((ref) {
      final repository = ref.watch(rewardsRepositoryProvider);
      final userId = ref.watch(currentUserIdProvider);
      return AchievementsController(repository: repository, userId: userId);
    });

/// Provides the tier controller with current user context
final tierControllerProvider = StateNotifierProvider<TierController, TierState>(
  (ref) {
    final repository = ref.watch(rewardsRepositoryProvider);
    final userId = ref.watch(currentUserIdProvider);
    return TierController(repository: repository, userId: userId);
  },
);

/// Provides the badge controller with current user context
final badgeControllerProvider =
    StateNotifierProvider<BadgeController, BadgeState>((ref) {
      final repository = ref.watch(rewardsRepositoryProvider);
      final userId = ref.watch(currentUserIdProvider);
      return BadgeController(repository, userId);
    });

/// Provides the leaderboard controller with current user context
final leaderboardControllerProvider =
    StateNotifierProvider<LeaderboardController, LeaderboardState>((ref) {
      final repository = ref.watch(rewardsRepositoryProvider);
      final userId = ref.watch(currentUserIdProvider);
      return LeaderboardController(repository, userId);
    });

/// Provides the progress tracking controller with current user context
final progressTrackingControllerProvider =
    StateNotifierProvider<ProgressTrackingController, ProgressTrackingState>((
      ref,
    ) {
      final repository = ref.watch(rewardsRepositoryProvider);
      final userId = ref.watch(currentUserIdProvider);
      return ProgressTrackingController(repository, userId);
    });

// =============================================================================
// COMPUTED STATE PROVIDERS
// =============================================================================

/// Provides the current user's total points
final userTotalPointsProvider = Provider<int>((ref) {
  final rewardsState = ref.watch(rewardsControllerProvider);
  return rewardsState.totalPoints.round();
});

/// Provides the current user's tier information
final userCurrentTierProvider = Provider<UserTier?>((ref) {
  final tierState = ref.watch(tierControllerProvider);
  return tierState.currentTier;
});

/// Provides the current user's rank in the overall leaderboard
final userLeaderboardRankProvider = Provider<int?>((ref) {
  final leaderboardState = ref.watch(leaderboardControllerProvider);
  return leaderboardState.userRank;
});

/// Provides the count of user's badges
final userBadgesCountProvider = Provider<int>((ref) {
  final badgeState = ref.watch(badgeControllerProvider);
  return badgeState.userBadges.length;
});

/// Provides the user's overall progress percentage
final overallProgressPercentageProvider = Provider<double>((ref) {
  final progressState = ref.watch(progressTrackingControllerProvider);
  final analytics = progressState.progressAnalytics;
  return (analytics['average_progress'] as num?)?.toDouble() ?? 0.0;
});

/// Provides recent milestone achievements
final recentMilestonesProvider = Provider<List<ProgressMilestone>>((ref) {
  final progressState = ref.watch(progressTrackingControllerProvider);
  return progressState.recentMilestones;
});

/// Provides showcased badges
final showcasedBadgesProvider = Provider<List<Badge>>((ref) {
  final badgeState = ref.watch(badgeControllerProvider);
  return badgeState.showcaseBadges;
});

/// Provides recent point transactions
final recentTransactionsProvider = Provider<List<PointTransaction>>((ref) {
  final rewardsState = ref.watch(rewardsControllerProvider);
  return rewardsState.recentTransactions;
});

// =============================================================================
// FILTERED DATA PROVIDERS
// =============================================================================

/// Provides filtered achievements based on current filter settings
final filteredAchievementsProvider = Provider<List<AchievementWithProgress>>((
  ref,
) {
  final achievementsState = ref.watch(achievementsControllerProvider);
  return achievementsState.filteredAchievements;
});

/// Provides filtered badges based on current filter settings
final filteredBadgesProvider = Provider<List<Badge>>((ref) {
  final badgeState = ref.watch(badgeControllerProvider);
  return badgeState.filteredBadges;
});

/// Provides filtered leaderboard entries based on current filter settings
final filteredLeaderboardEntriesProvider = Provider<List<LeaderboardEntry>>((
  ref,
) {
  final leaderboardState = ref.watch(leaderboardControllerProvider);
  return leaderboardState.filteredEntries;
});

/// Provides filtered progress based on current filter settings
final filteredProgressProvider = Provider<List<UserProgress>>((ref) {
  final progressState = ref.watch(progressTrackingControllerProvider);
  return progressState.filteredProgress;
});

// =============================================================================
// ANALYTICS PROVIDERS
// =============================================================================

/// Provides badge collection statistics
final badgeCollectionStatsProvider = Provider<Map<String, dynamic>>((ref) {
  final badgeState = ref.watch(badgeControllerProvider);
  return badgeState.collectionStats;
});

/// Provides leaderboard statistics
final leaderboardStatsProvider = Provider<Map<String, dynamic>>((ref) {
  final leaderboardState = ref.watch(leaderboardControllerProvider);
  return leaderboardState.leaderboardStats;
});

/// Provides progress analytics
final progressAnalyticsProvider = Provider<Map<String, dynamic>>((ref) {
  final progressState = ref.watch(progressTrackingControllerProvider);
  return progressState.progressAnalytics;
});

// =============================================================================
// STATUS PROVIDERS
// =============================================================================

/// Provides loading state for any rewards-related operation
final rewardsLoadingProvider = Provider<bool>((ref) {
  final rewardsLoading = ref.watch(
    rewardsControllerProvider.select((state) => state.isLoading),
  );
  final achievementsLoading = ref.watch(
    achievementsControllerProvider.select((state) => state.isLoading),
  );
  final tierLoading = ref.watch(
    tierControllerProvider.select((state) => state.isLoading),
  );
  final badgeLoading = ref.watch(
    badgeControllerProvider.select((state) => state.isLoading),
  );
  final leaderboardLoading = ref.watch(
    leaderboardControllerProvider.select((state) => state.isLoading),
  );
  final progressLoading = ref.watch(
    progressTrackingControllerProvider.select((state) => state.isLoading),
  );

  return rewardsLoading ||
      achievementsLoading ||
      tierLoading ||
      badgeLoading ||
      leaderboardLoading ||
      progressLoading;
});

/// Provides any error state across all rewards controllers
final rewardsErrorProvider = Provider<String?>((ref) {
  final rewardsError = ref.watch(
    rewardsControllerProvider.select((state) => state.error),
  );
  final achievementsError = ref.watch(
    achievementsControllerProvider.select((state) => state.error),
  );
  final tierError = ref.watch(
    tierControllerProvider.select((state) => state.error),
  );
  final badgeError = ref.watch(
    badgeControllerProvider.select((state) => state.error),
  );
  final leaderboardError = ref.watch(
    leaderboardControllerProvider.select((state) => state.error),
  );
  final progressError = ref.watch(
    progressTrackingControllerProvider.select((state) => state.error),
  );

  return rewardsError ??
      achievementsError ??
      tierError ??
      badgeError ??
      leaderboardError ??
      progressError;
});

// =============================================================================
// UTILITY PROVIDERS
// =============================================================================

/// Provides search functionality across achievements
final achievementSearchProvider =
    Provider.family<List<AchievementWithProgress>, String>((ref, query) {
      final controller = ref.read(achievementsControllerProvider.notifier);
      controller.setSearchQuery(query);
      return ref.watch(filteredAchievementsProvider);
    });

/// Provides search functionality across badges
final badgeSearchProvider = Provider.family<List<Badge>, String>((ref, query) {
  final controller = ref.read(badgeControllerProvider.notifier);
  controller.updateSearchQuery(query);
  return ref.watch(filteredBadgesProvider);
});

/// Provides leaderboard entries for specific type and timeframe
final specificLeaderboardProvider =
    FutureProvider.family<List<LeaderboardEntry>, Map<String, dynamic>>((
      ref,
      params,
    ) async {
      final type = params['type'] as LeaderboardType;
      final timeframe = params['timeframe'] as TimeFrame;
      final controller = ref.read(leaderboardControllerProvider.notifier);

      await controller.changeLeaderboardType(type);
      await controller.changeTimeFrame(timeframe);
      return ref.read(filteredLeaderboardEntriesProvider);
    });

/// Provides achievements by category
final achievementsByCategoryProvider =
    Provider.family<List<AchievementWithProgress>, AchievementCategory>((
      ref,
      category,
    ) {
      final controller = ref.read(achievementsControllerProvider.notifier);
      controller.setCategory(category);
      return ref.watch(filteredAchievementsProvider);
    });

/// Provides progress insights and recommendations
final progressInsightsProvider = Provider<Map<String, dynamic>>((ref) {
  final controller = ref.read(progressTrackingControllerProvider.notifier);
  return controller.getProgressInsights();
});

/// Provides competitive insights for leaderboard
final competitiveInsightsProvider = Provider<Map<String, dynamic>>((ref) {
  final controller = ref.read(leaderboardControllerProvider.notifier);
  return controller.getCompetitiveInsights();
});

// =============================================================================
// STREAM PROVIDERS (for real-time updates)
// =============================================================================

/// Provides real-time updates for user's total points
final pointsStreamProvider = StreamProvider<int>((ref) {
  return Stream.periodic(const Duration(seconds: 30), (count) {
    return ref.read(userTotalPointsProvider);
  });
});

/// Provides real-time updates for user's rank
final rankStreamProvider = StreamProvider<int?>((ref) {
  return Stream.periodic(const Duration(minutes: 1), (count) {
    return ref.read(userLeaderboardRankProvider);
  });
});

// =============================================================================
// COMPOSITE PROVIDERS (combining multiple data sources)
// =============================================================================

/// Provides a comprehensive dashboard summary
final rewardsDashboardProvider = Provider<Map<String, dynamic>>((ref) {
  final totalPoints = ref.watch(userTotalPointsProvider);
  final tier = ref.watch(userCurrentTierProvider);
  final rank = ref.watch(userLeaderboardRankProvider);
  final badgeCount = ref.watch(userBadgesCountProvider);
  final overallProgress = ref.watch(overallProgressPercentageProvider);
  final recentMilestones = ref.watch(recentMilestonesProvider);

  return {
    'total_points': totalPoints,
    'tier_name': tier?.level.name ?? 'Bronze',
    'rank': rank,
    'badges_earned': badgeCount,
    'overall_progress': overallProgress,
    'recent_milestones_count': recentMilestones.length,
    'last_updated': DateTime.now(),
  };
});

/// Provides user profile summary for rewards
final userRewardsProfileProvider = Provider<Map<String, dynamic>>((ref) {
  final totalPoints = ref.watch(userTotalPointsProvider);
  final tier = ref.watch(userCurrentTierProvider);
  final rank = ref.watch(userLeaderboardRankProvider);
  final showcasedBadges = ref.watch(showcasedBadgesProvider);
  final recentTransactions = ref.watch(recentTransactionsProvider);

  return {
    'total_points': totalPoints,
    'current_tier': tier?.level.name ?? 'Bronze',
    'tier_level': tier?.level.level ?? 1,
    'leaderboard_rank': rank,
    'showcased_badges': showcasedBadges
        .map(
          (b) => {
            'id': b.id,
            'name': b.name,
            'rarity': b.getRarityLabel(),
            'tier': b.tier.name,
          },
        )
        .toList(),
    'recent_activity': recentTransactions
        .take(5)
        .map(
          (t) => {
            'type': t.type.name,
            'amount': t.points,
            'description': t.reason,
            'created_at': t.createdAt,
          },
        )
        .toList(),
  };
});

/// Provides motivation and engagement data
final motivationProvider = Provider<Map<String, dynamic>>((ref) {
  final progressInsights = ref.watch(progressInsightsProvider);
  final competitiveInsights = ref.watch(competitiveInsightsProvider);
  final recentMilestones = ref.watch(recentMilestonesProvider);

  final motivationMessages = <String>[];
  final recommendations = <String>[];

  // Add insights from progress tracking
  if (progressInsights['insights'] is List) {
    motivationMessages.addAll(
      (progressInsights['insights'] as List).cast<String>(),
    );
  }
  if (progressInsights['recommendations'] is List) {
    recommendations.addAll(
      (progressInsights['recommendations'] as List).cast<String>(),
    );
  }

  // Add insights from competitive analysis
  if (competitiveInsights['insights'] is List) {
    motivationMessages.addAll(
      (competitiveInsights['insights'] as List).cast<String>(),
    );
  }

  return {
    'motivation_messages': motivationMessages,
    'recommendations': recommendations,
    'recent_milestones_count': recentMilestones.length,
    'overall_message': motivationMessages.isNotEmpty
        ? motivationMessages.first
        : 'Keep making progress on your achievements!',
  };
});

// =============================================================================
// REFRESH PROVIDERS (for manual data refresh)
// =============================================================================

/// Provider to trigger refresh of all rewards data
final refreshAllRewardsProvider = Provider<Future<void>>((ref) async {
  await Future.wait([
    ref.read(rewardsControllerProvider.notifier).refresh(),
    ref.read(achievementsControllerProvider.notifier).refresh(),
    ref.read(tierControllerProvider.notifier).refresh(),
    ref.read(badgeControllerProvider.notifier).refresh(),
    ref.read(leaderboardControllerProvider.notifier).refresh(),
    ref.read(progressTrackingControllerProvider.notifier).refresh(),
  ]);
});

/// Provider to trigger refresh of specific controller data
final refreshSpecificProvider = Provider.family<Future<void>, String>((
  ref,
  controllerType,
) async {
  switch (controllerType.toLowerCase()) {
    case 'rewards':
      await ref.read(rewardsControllerProvider.notifier).refresh();
      break;
    case 'achievements':
      await ref.read(achievementsControllerProvider.notifier).refresh();
      break;
    case 'tier':
      await ref.read(tierControllerProvider.notifier).refresh();
      break;
    case 'badge':
      await ref.read(badgeControllerProvider.notifier).refresh();
      break;
    case 'leaderboard':
      await ref.read(leaderboardControllerProvider.notifier).refresh();
      break;
    case 'progress':
      await ref.read(progressTrackingControllerProvider.notifier).refresh();
      break;
  }
});
