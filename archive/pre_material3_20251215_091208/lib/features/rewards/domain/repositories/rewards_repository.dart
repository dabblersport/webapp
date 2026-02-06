import 'package:fpdart/fpdart.dart';

import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/data/models/rewards/achievement.dart';
import 'package:dabbler/data/models/rewards/user_progress.dart';
import 'package:dabbler/data/models/rewards/badge.dart';
import 'package:dabbler/data/models/rewards/badge_tier.dart';
import 'package:dabbler/data/models/rewards/tier.dart';
import 'package:dabbler/data/models/rewards/leaderboard_entry.dart';
import 'package:dabbler/data/models/rewards/points_transaction.dart';

// Type aliases for backward compatibility
typedef PointTransaction = PointsTransaction;
typedef TransactionType = PointsTransactionType;

/// Event types for tracking user actions
enum EventType {
  gameStart,
  gameEnd,
  gameWin,
  gameLoss,
  socialInteraction,
  profileUpdate,
  tournamentJoin,
  tournamentWin,
  dailyLogin,
  streakMaintained,
  friendInvite,
  achievementView,
  badgeView,
  leaderboardView,
  settingsChange,
  tutorialComplete,
  levelComplete,
  scoreAchieved,
  timeSpent,
  shareAction,
}

/// Leaderboard types for different rankings
enum LeaderboardType {
  overall,
  daily,
  weekly,
  monthly,
  sport,
  friends,
  tier,
  achievements,
}

/// Time frames for leaderboard queries
enum TimeFrame { today, thisWeek, thisMonth, thisYear, allTime }

/// Reward types that can be claimed
enum RewardType { achievement, badge, points, tier, special }

/// Abstract repository interface for rewards system
abstract class RewardsRepository {
  /// Gets all achievements with optional filtering
  ///
  /// [category] - Filter by achievement category
  /// [includeHidden] - Whether to include hidden achievements
  /// [includeCompleted] - Whether to include user's completed achievements
  /// [userId] - User ID for personalized filtering
  Future<Either<Failure, List<Achievement>>> getAchievements({
    AchievementCategory? category,
    bool includeHidden = false,
    bool includeCompleted = true,
    String? userId,
  });

  /// Gets a specific achievement by ID
  Future<Either<Failure, Achievement>> getAchievementById(String achievementId);

  /// Gets user's progress across all achievements
  ///
  /// [userId] - User ID to get progress for
  /// [status] - Filter by progress status
  /// [achievementIds] - Specific achievements to get progress for
  Future<Either<Failure, List<UserProgress>>> getUserProgress(
    String userId, {
    ProgressStatus? status,
    List<String>? achievementIds,
  });

  /// Gets progress for a specific achievement
  Future<Either<Failure, UserProgress?>> getUserProgressForAchievement(
    String userId,
    String achievementId,
  );

  /// Tracks an event that may contribute to achievements
  ///
  /// [eventType] - Type of event being tracked
  /// [eventData] - Additional data about the event
  /// [userId] - User who performed the action
  /// Returns list of achievements that were updated/completed
  Future<Either<Failure, List<Achievement>>> trackEvent(
    EventType eventType,
    Map<String, dynamic> eventData,
    String userId,
  );

  /// Gets leaderboard entries
  ///
  /// [type] - Type of leaderboard
  /// [timeframe] - Time period for the leaderboard
  /// [page] - Page number for pagination
  /// [pageSize] - Number of entries per page
  /// [sportFilter] - Filter by specific sport
  Future<Either<Failure, List<LeaderboardEntry>>> getLeaderboard(
    LeaderboardType type,
    TimeFrame timeframe, {
    int page = 1,
    int pageSize = 50,
    String? sportFilter,
  });

  /// Gets user's rank in a specific leaderboard
  ///
  /// [userId] - User to get rank for
  /// [leaderboardType] - Type of leaderboard
  /// [timeframe] - Time period
  /// [sportFilter] - Filter by sport if applicable
  Future<Either<Failure, int?>> getUserRank(
    String userId,
    LeaderboardType leaderboardType,
    TimeFrame timeframe, {
    String? sportFilter,
  });

  /// Gets user's current tier information
  Future<Either<Failure, UserTier?>> getUserTier(String userId);

  /// Gets user's point transactions history
  ///
  /// [userId] - User to get transactions for
  /// [type] - Filter by transaction type
  /// [limit] - Maximum number of transactions to return
  /// [offset] - Offset for pagination
  Future<Either<Failure, List<PointTransaction>>> getPointTransactions(
    String userId, {
    TransactionType? type,
    int limit = 50,
    int offset = 0,
  });

  /// Claims a reward (achievement, badge, etc.)
  ///
  /// [rewardId] - ID of the reward to claim
  /// [rewardType] - Type of reward being claimed
  /// [userId] - User claiming the reward
  Future<Either<Failure, Map<String, dynamic>>> claimReward(
    String rewardId,
    RewardType rewardType,
    String userId,
  );

  /// Gets user's badges with collection information
  ///
  /// [userId] - User to get badges for
  /// [tier] - Filter by badge tier
  /// [showcaseOnly] - Only get showcased badges
  Future<Either<Failure, List<Badge>>> getUserBadges(
    String userId, {
    BadgeTier? tier,
    bool showcaseOnly = false,
  });

  /// Updates badge showcase settings
  ///
  /// [userId] - User updating showcase
  /// [badgeId] - Badge to update
  /// [isShowcased] - Whether to showcase the badge
  /// [showcaseOrder] - Order in showcase
  Future<Either<Failure, void>> updateBadgeShowcase(
    String userId,
    String badgeId,
    bool isShowcased, {
    int? showcaseOrder,
  });

  /// Gets achievement statistics for a user
  ///
  /// [userId] - User to get stats for
  Future<Either<Failure, Map<String, dynamic>>> getAchievementStats(
    String userId,
  );

  /// Gets leaderboard statistics
  ///
  /// [type] - Leaderboard type
  /// [timeframe] - Time period
  Future<Either<Failure, Map<String, dynamic>>> getLeaderboardStats(
    LeaderboardType type,
    TimeFrame timeframe,
  );

  /// Searches achievements by name or description
  ///
  /// [query] - Search query
  /// [userId] - User for personalized results
  /// [category] - Filter by category
  Future<Either<Failure, List<Achievement>>> searchAchievements(
    String query, {
    String? userId,
    AchievementCategory? category,
  });

  /// Gets trending/popular achievements
  ///
  /// [timeframe] - Time period to consider
  /// [limit] - Number of achievements to return
  Future<Either<Failure, List<Achievement>>> getTrendingAchievements(
    TimeFrame timeframe, {
    int limit = 10,
  });

  /// Gets recommended achievements for a user
  ///
  /// [userId] - User to get recommendations for
  /// [limit] - Number of recommendations
  Future<Either<Failure, List<Achievement>>> getRecommendedAchievements(
    String userId, {
    int limit = 5,
  });

  /// Gets achievements that are close to completion
  ///
  /// [userId] - User to check progress for
  /// [threshold] - Progress threshold (e.g., 80% complete)
  /// [limit] - Maximum number of achievements
  Future<Either<Failure, List<Achievement>>> getNearCompletionAchievements(
    String userId, {
    double threshold = 0.8,
    int limit = 5,
  });

  /// Batch updates user progress (for offline sync)
  ///
  /// [userId] - User to update progress for
  /// [progressUpdates] - Map of achievement ID to progress delta
  Future<Either<Failure, List<Achievement>>> batchUpdateProgress(
    String userId,
    Map<String, Map<String, dynamic>> progressUpdates,
  );

  /// Gets cached data status and sync information
  Future<Either<Failure, Map<String, dynamic>>> getCacheStatus();

  /// Forces a sync with remote data
  ///
  /// [userId] - User to sync data for
  Future<Either<Failure, void>> syncUserData(String userId);

  /// Gets offline queued events count
  Future<Either<Failure, int>> getQueuedEventsCount();

  /// Processes queued offline events
  Future<Either<Failure, int>> processQueuedEvents();

  /// Validates if a user can claim a specific reward
  ///
  /// [userId] - User attempting to claim
  /// [rewardId] - Reward being claimed
  /// [rewardType] - Type of reward
  Future<Either<Failure, bool>> canClaimReward(
    String userId,
    String rewardId,
    RewardType rewardType,
  );

  /// Gets reward claim history for a user
  ///
  /// [userId] - User to get history for
  /// [rewardType] - Filter by reward type
  /// [limit] - Maximum number of claims to return
  Future<Either<Failure, List<Map<String, dynamic>>>> getRewardClaimHistory(
    String userId, {
    RewardType? rewardType,
    int limit = 50,
  });

  /// Preloads commonly accessed data for better performance
  ///
  /// [userId] - User to preload data for
  Future<Either<Failure, void>> preloadUserData(String userId);

  /// Clears local cache
  Future<Either<Failure, void>> clearCache();

  /// Gets network connectivity status
  Future<Either<Failure, bool>> isOnline();

  /// Subscribes to real-time updates for user progress
  ///
  /// [userId] - User to subscribe updates for
  /// [callback] - Function to call when updates occur
  Stream<Either<Failure, UserProgress>> subscribeToProgressUpdates(
    String userId,
  );

  /// Subscribes to real-time leaderboard updates
  ///
  /// [type] - Leaderboard type to subscribe to
  /// [timeframe] - Time period
  Stream<Either<Failure, List<LeaderboardEntry>>> subscribeToLeaderboardUpdates(
    LeaderboardType type,
    TimeFrame timeframe,
  );

  // Missing methods needed by award_achievement_usecase.dart

  /// Awards points to a user and creates a transaction record
  Future<Either<Failure, PointTransaction>> awardPoints(
    String userId,
    int points,
    String reason, {
    Map<String, dynamic>? metadata,
  });

  /// Gets comprehensive user statistics
  Future<Either<Failure, Map<String, dynamic>?>> getUserStats(String userId);

  /// Gets all badges associated with a specific achievement
  Future<Either<Failure, List<Badge>>> getBadgesForAchievement(
    String achievementId,
  );

  /// Awards a specific badge to a user
  Future<Either<Failure, void>> awardBadge(String userId, String badgeId);

  /// Updates user progress for achievements
  Future<Either<Failure, void>> updateUserProgress(UserProgress progress);

  /// Increments user statistics
  Future<Either<Failure, void>> incrementUserStats(
    String userId,
    Map<String, dynamic> stats,
  );

  /// Upgrades user tier
  Future<Either<Failure, void>> upgradeTier(String userId, UserTier newTier);

  /// Queues a notification for the user
  Future<Either<Failure, void>> queueNotification({
    required String userId,
    required String type,
    String? title,
    String? message,
    Map<String, dynamic>? data,
  });

  // Missing methods for tier_calculation_service.dart

  /// Gets user points total
  Future<Either<Failure, double>> getUserPoints(String userId);

  /// Gets tier upgrade history for a user
  Future<Either<Failure, List<Map<String, dynamic>>>> getTierUpgradeHistory(
    String userId,
  );

  /// Updates user tier information
  Future<Either<Failure, void>> updateUserTier(String userId, UserTier tier);

  /// Saves tier upgrade history record
  Future<Either<Failure, void>> saveTierUpgradeHistory(
    String userId,
    Map<String, dynamic> upgradeData,
  );

  /// Gets transaction history for points
  Future<Either<Failure, List<PointTransaction>>> getTransactionHistory(
    String userId, {
    int? limit,
    DateTime? startDate,
    DateTime? endDate,
  });

  /// Updates daily goal progress
  Future<Either<Failure, void>> updateDailyGoalProgress(
    String userId,
    String goalId,
    double newValue,
  );

  /// Updates streak data
  Future<Either<Failure, void>> updateStreak(
    String userId,
    Map<String, dynamic> streakData,
  );

  /// Gets all achievements in the system
  Future<Either<Failure, List<Achievement>>> getAllAchievements();
}
