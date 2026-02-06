import 'dart:async';
import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dabbler/data/models/rewards/achievement.dart';
import 'package:dabbler/data/models/rewards/user_progress.dart';
import 'package:dabbler/data/models/rewards/badge_tier.dart';
import 'package:dabbler/data/models/rewards/point_transaction.dart' as data;
import '../../domain/repositories/rewards_repository.dart';
import 'package:dabbler/data/models/rewards/achievement_model.dart';
import 'package:dabbler/data/models/rewards/user_progress_model.dart';
import 'package:dabbler/data/models/rewards/badge_model.dart';
import 'package:dabbler/data/models/rewards/tier_model.dart';
import 'package:dabbler/data/models/rewards/leaderboard_model.dart';

/// Supabase data source for rewards system
/// Handles all remote operations for achievements, points, leaderboards, and progress tracking
class SupabaseRewardsDataSource {
  final SupabaseClient _client;
  final String _achievementsTable = 'achievements';
  final String _userProgressTable = 'user_progress';
  final String _pointTransactionsTable = 'point_transactions';
  final String _leaderboardTable = 'leaderboard';
  final String _userBadgesTable = 'user_badges';
  final String _userTiersTable = 'user_tiers';
  final String _eventQueueTable = 'event_queue';

  // Retry configuration
  static const int _maxRetries = 3;
  static const Duration _baseRetryDelay = Duration(seconds: 1);

  // Cache for real-time subscriptions
  final Map<String, StreamSubscription> _subscriptions = {};
  final StreamController<UserProgressModel> _progressController =
      StreamController<UserProgressModel>.broadcast();
  final StreamController<List<Map<String, dynamic>>> _leaderboardController =
      StreamController<List<Map<String, dynamic>>>.broadcast();

  SupabaseRewardsDataSource(this._client);

  /// Dispose method to clean up resources
  void dispose() {
    for (final subscription in _subscriptions.values) {
      subscription.cancel();
    }
    _subscriptions.clear();
    _progressController.close();
    _leaderboardController.close();
  }

  // =============================================================================
  // ACHIEVEMENT OPERATIONS
  // =============================================================================

  /// Get achievements with optional filters
  Future<List<AchievementModel>> getAchievements({
    AchievementCategory? category,
    bool includeHidden = false,
    bool includeCompleted = true,
    String? userId,
  }) async {
    return _withRetry(() async {
      var query = _client.from(_achievementsTable).select('*');

      // Apply filters
      if (category != null) {
        query = query.eq('category', category.name);
      }

      if (!includeHidden) {
        query = query.eq('is_hidden', false);
      }

      // Note: Complex joins with filters would be handled via Supabase RPC functions
      // For now, we'll do a simple query and handle user filtering in a separate call

      final response = await query;

      return (response as List)
          .map((json) => AchievementModel.fromSupabase(json))
          .toList();
    });
  }

  /// Get single achievement by ID
  Future<AchievementModel> getAchievementById(String achievementId) async {
    return _withRetry(() async {
      final response = await _client
          .from(_achievementsTable)
          .select('*')
          .eq('id', achievementId)
          .single();

      return AchievementModel.fromSupabase(response);
    });
  }

  /// Track achievement event and update progress
  Future<List<AchievementModel>> trackEvent(
    EventType eventType,
    Map<String, dynamic> eventData,
    String userId,
  ) async {
    return _withRetry(() async {
      try {
        // Call Supabase function for event processing
        final response = await _client.rpc(
          'process_achievement_event',
          params: {
            'event_type': eventType.name,
            'event_data': eventData,
            'user_id': userId,
            'timestamp': DateTime.now().toIso8601String(),
          },
        );

        // Return list of updated achievements
        return (response as List)
            .map((json) => AchievementModel.fromSupabase(json))
            .toList();
      } catch (e) {
        // If real-time processing fails, queue event for later
        await _queueEvent(eventType, eventData, userId);
        return <AchievementModel>[];
      }
    });
  }

  /// Batch update progress for multiple achievements
  Future<List<AchievementModel>> batchUpdateProgress(
    String userId,
    Map<String, Map<String, dynamic>> progressUpdates,
  ) async {
    return _withRetry(() async {
      final response = await _client.rpc(
        'batch_update_progress',
        params: {
          'user_id': userId,
          'progress_updates': progressUpdates,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      return (response as List)
          .map((json) => AchievementModel.fromSupabase(json))
          .toList();
    });
  }

  /// Get user progress for achievements
  Future<List<UserProgressModel>> getUserProgress(
    String userId, {
    ProgressStatus? status,
    List<String>? achievementIds,
  }) async {
    return _withRetry(() async {
      var query = _client
          .from(_userProgressTable)
          .select('*, achievements(*)')
          .eq('user_id', userId);

      if (status != null) {
        query = query.eq('status', status.name);
      }

      if (achievementIds != null && achievementIds.isNotEmpty) {
        query = query.inFilter('achievement_id', achievementIds);
      }

      final response = await query.order('updated_at', ascending: false);

      return (response as List)
          .map((json) => UserProgressModel.fromSupabase(json))
          .toList();
    });
  }

  /// Get user progress for specific achievement
  Future<UserProgressModel?> getUserProgressForAchievement(
    String userId,
    String achievementId,
  ) async {
    return _withRetry(() async {
      final response = await _client
          .from(_userProgressTable)
          .select('*, achievements(*)')
          .eq('user_id', userId)
          .eq('achievement_id', achievementId)
          .maybeSingle();

      return response != null ? UserProgressModel.fromSupabase(response) : null;
    });
  }

  // =============================================================================
  // POINTS OPERATIONS
  // =============================================================================

  /// Award points with multipliers and create transaction
  Future<Map<String, dynamic>> awardPoints(
    String userId,
    int basePoints,
    TransactionType type,
    String sourceId, {
    double multiplier = 1.0,
    Map<String, dynamic>? metadata,
  }) async {
    return _withRetry(() async {
      final response = await _client.rpc(
        'award_points',
        params: {
          'user_id': userId,
          'base_points': basePoints,
          'transaction_type': type.name,
          'source_id': sourceId,
          'multiplier': multiplier,
          'metadata': metadata ?? {},
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      return response as Map<String, dynamic>;
    });
  }

  /// Get point transaction history
  Future<List<data.PointTransaction>> getPointTransactions(
    String userId, {
    TransactionType? type,
    int limit = 50,
    int offset = 0,
  }) async {
    return _withRetry(() async {
      var query = _client
          .from(_pointTransactionsTable)
          .select('*')
          .eq('user_id', userId);

      if (type != null) {
        query = query.eq('type', type.name);
      }

      final orderedQuery = query.order('created_at', ascending: false);
      final response = await orderedQuery.range(offset, offset + limit - 1);

      return (response as List)
          .map(
            (json) => data.PointTransaction(
              id: json['id'],
              userId: json['user_id'],
              basePoints: json['base_points'] ?? json['amount'] ?? 0,
              finalPoints: json['final_points'] ?? json['amount'] ?? 0,
              runningBalance: json['running_balance'] ?? 0,
              type: data.TransactionType.values.firstWhere(
                (e) => e.name == json['type'],
                orElse: () => data.TransactionType.achievement,
              ),
              description: json['description'] ?? '',
              createdAt: DateTime.parse(json['created_at']),
              metadata: json['metadata'] ?? {},
            ),
          )
          .toList();
    });
  }

  /// Get user's current point balance
  Future<int> getUserPointBalance(String userId) async {
    return _withRetry(() async {
      final response = await _client.rpc(
        'get_user_point_balance',
        params: {'user_id': userId},
      );

      return response as int;
    });
  }

  // =============================================================================
  // LEADERBOARD OPERATIONS
  // =============================================================================

  /// Get leaderboard data with caching support
  Future<LeaderboardModel> getLeaderboard(
    LeaderboardType type,
    TimeFrame timeframe, {
    int page = 1,
    int pageSize = 50,
    String? sportFilter,
  }) async {
    return _withRetry(() async {
      final response = await _client.rpc(
        'get_leaderboard',
        params: {
          'leaderboard_type': type.name,
          'time_frame': timeframe.name,
          'page_number': page,
          'page_size': pageSize,
          'sport_filter': sportFilter,
        },
      );

      return LeaderboardModel.fromJson(response);
    });
  }

  /// Get user's rank in specific leaderboard
  Future<int?> getUserRank(
    String userId,
    LeaderboardType leaderboardType,
    TimeFrame timeframe, {
    String? sportFilter,
  }) async {
    return _withRetry(() async {
      final response = await _client.rpc(
        'get_user_rank',
        params: {
          'user_id': userId,
          'leaderboard_type': leaderboardType.name,
          'time_frame': timeframe.name,
          'sport_filter': sportFilter,
        },
      );

      return response as int?;
    });
  }

  /// Get leaderboard statistics
  Future<Map<String, dynamic>> getLeaderboardStats(
    LeaderboardType type,
    TimeFrame timeframe,
  ) async {
    return _withRetry(() async {
      final response = await _client.rpc(
        'get_leaderboard_stats',
        params: {'leaderboard_type': type.name, 'time_frame': timeframe.name},
      );

      return response as Map<String, dynamic>;
    });
  }

  // =============================================================================
  // USER BADGES AND TIERS
  // =============================================================================

  /// Get user badges
  Future<List<BadgeModel>> getUserBadges(
    String userId, {
    BadgeTier? tier,
    bool showcaseOnly = false,
  }) async {
    return _withRetry(() async {
      var query = _client
          .from(_userBadgesTable)
          .select('*, badges(*)')
          .eq('user_id', userId);

      if (tier != null) {
        query = query.eq('badges.tier', tier.name);
      }

      if (showcaseOnly) {
        query = query.eq('is_showcased', true);
      }

      final response = await query.order('earned_at', ascending: false);

      return (response as List)
          .map((json) => BadgeModel.fromSupabase(json['badges']))
          .toList();
    });
  }

  /// Update badge showcase status
  Future<void> updateBadgeShowcase(
    String userId,
    String badgeId,
    bool isShowcased, {
    int? showcaseOrder,
  }) async {
    return _withRetry(() async {
      await _client
          .from(_userBadgesTable)
          .update({
            'is_showcased': isShowcased,
            'showcase_order': showcaseOrder,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('user_id', userId)
          .eq('badge_id', badgeId);
    });
  }

  /// Get user's current tier
  Future<TierModel?> getUserTier(String userId) async {
    return _withRetry(() async {
      final response = await _client
          .from(_userTiersTable)
          .select('*, tiers(*)')
          .eq('user_id', userId)
          .maybeSingle();

      return response != null
          ? TierModel.fromSupabase(response['tiers'])
          : null;
    });
  }

  // =============================================================================
  // SEARCH AND DISCOVERY
  // =============================================================================

  /// Search achievements by text query
  Future<List<AchievementModel>> searchAchievements(
    String query, {
    String? userId,
    AchievementCategory? category,
  }) async {
    return _withRetry(() async {
      final response = await _client.rpc(
        'search_achievements',
        params: {
          'search_query': query,
          'user_id': userId,
          'category_filter': category?.name,
        },
      );

      return (response as List)
          .map((json) => AchievementModel.fromSupabase(json))
          .toList();
    });
  }

  /// Get trending achievements
  Future<List<AchievementModel>> getTrendingAchievements(
    TimeFrame timeframe, {
    int limit = 10,
  }) async {
    return _withRetry(() async {
      final response = await _client.rpc(
        'get_trending_achievements',
        params: {'time_frame': timeframe.name, 'limit_count': limit},
      );

      return (response as List)
          .map((json) => AchievementModel.fromSupabase(json))
          .toList();
    });
  }

  /// Get recommended achievements for user
  Future<List<AchievementModel>> getRecommendedAchievements(
    String userId, {
    int limit = 5,
  }) async {
    return _withRetry(() async {
      final response = await _client.rpc(
        'get_recommended_achievements',
        params: {'user_id': userId, 'limit_count': limit},
      );

      return (response as List)
          .map((json) => AchievementModel.fromSupabase(json))
          .toList();
    });
  }

  // =============================================================================
  // REAL-TIME SUBSCRIPTIONS
  // =============================================================================

  /// Subscribe to progress updates for a user
  Stream<UserProgressModel> subscribeToProgressUpdates(String userId) {
    final subscriptionKey = 'progress_$userId';

    // Cancel existing subscription if any
    _subscriptions[subscriptionKey]?.cancel();

    _subscriptions[subscriptionKey] = _client
        .from(_userProgressTable)
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .listen((data) {
          for (final item in data) {
            final progress = UserProgressModel.fromSupabase(item);
            _progressController.add(progress);
          }
        });

    return _progressController.stream.where(
      (progress) => progress.userId == userId,
    );
  }

  /// Subscribe to leaderboard updates
  Stream<List<Map<String, dynamic>>> subscribeToLeaderboardUpdates(
    LeaderboardType type,
    TimeFrame timeframe,
  ) {
    final subscriptionKey = 'leaderboard_${type.name}_${timeframe.name}';

    // Cancel existing subscription if any
    _subscriptions[subscriptionKey]?.cancel();

    _subscriptions[subscriptionKey] = _client
        .from(_leaderboardTable)
        .stream(primaryKey: ['id'])
        .listen((data) async {
          _leaderboardController.add(data);
        });

    return _leaderboardController.stream;
  }

  // =============================================================================
  // REWARD CLAIMS AND STATISTICS
  // =============================================================================

  /// Claim a reward (achievement/badge/tier reward)
  Future<Map<String, dynamic>> claimReward(
    String rewardId,
    RewardType rewardType,
    String userId,
  ) async {
    return _withRetry(() async {
      final response = await _client.rpc(
        'claim_reward',
        params: {
          'reward_id': rewardId,
          'reward_type': rewardType.name,
          'user_id': userId,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      return response as Map<String, dynamic>;
    });
  }

  /// Check if user can claim a specific reward
  Future<bool> canClaimReward(
    String userId,
    String rewardId,
    RewardType rewardType,
  ) async {
    return _withRetry(() async {
      final response = await _client.rpc(
        'can_claim_reward',
        params: {
          'user_id': userId,
          'reward_id': rewardId,
          'reward_type': rewardType.name,
        },
      );

      return response as bool;
    });
  }

  /// Get achievement statistics for user
  Future<Map<String, dynamic>> getAchievementStats(String userId) async {
    return _withRetry(() async {
      final response = await _client.rpc(
        'get_achievement_stats',
        params: {'user_id': userId},
      );

      return response as Map<String, dynamic>;
    });
  }

  /// Get reward claim history
  Future<List<Map<String, dynamic>>> getRewardClaimHistory(
    String userId, {
    RewardType? rewardType,
    int limit = 50,
  }) async {
    return _withRetry(() async {
      final response = await _client.rpc(
        'get_reward_claim_history',
        params: {
          'user_id': userId,
          'reward_type_filter': rewardType?.name,
          'limit_count': limit,
        },
      );

      return List<Map<String, dynamic>>.from(response as List);
    });
  }

  // =============================================================================
  // ERROR HANDLING AND RETRY LOGIC
  // =============================================================================

  /// Queue event for later processing when offline
  Future<void> _queueEvent(
    EventType eventType,
    Map<String, dynamic> eventData,
    String userId,
  ) async {
    try {
      await _client.from(_eventQueueTable).insert({
        'user_id': userId,
        'event_type': eventType.name,
        'event_data': eventData,
        'created_at': DateTime.now().toIso8601String(),
        'status': 'pending',
        'retry_count': 0,
      });
    } catch (e) {
      // If queuing fails, we'll lose this event
      // In production, consider local storage backup
      rethrow;
    }
  }

  /// Process queued events (called when connectivity is restored)
  Future<int> processQueuedEvents() async {
    return _withRetry(() async {
      final response = await _client.rpc('process_queued_events');
      return response as int;
    });
  }

  /// Generic retry wrapper with exponential backoff
  Future<T> _withRetry<T>(Future<T> Function() operation) async {
    int attempts = 0;

    while (attempts < _maxRetries) {
      try {
        return await operation();
      } catch (e) {
        attempts++;

        if (attempts >= _maxRetries) {
          if (e is PostgrestException) {
            throw Exception('Server error: ${e.message}');
          } else if (e is SocketException) {
            throw Exception('Network connection failed');
          } else {
            throw Exception(e.toString());
          }
        }

        // Exponential backoff
        final delay = _baseRetryDelay * (1 << (attempts - 1));
        await Future.delayed(delay);
      }
    }

    throw Exception('Max retry attempts exceeded');
  }

  /// Check if we have network connectivity
  Future<bool> isOnline() async {
    try {
      final result = await InternetAddress.lookup('supabase.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Get count of queued events waiting to be processed
  Future<int> getQueuedEventsCount() async {
    return _withRetry(() async {
      final response = await _client
          .from(_eventQueueTable)
          .select('*')
          .eq('status', 'pending');

      return response.length;
    });
  }
}
