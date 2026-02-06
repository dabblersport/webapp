import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dabbler/data/models/rewards/achievement.dart';
import '../domain/repositories/rewards_repository.dart';
import 'rewards_service.dart';

/// Progress event data
class ProgressEvent {
  final String id;
  final String userId;
  final ProgressEventType type;
  final Map<String, dynamic> data;
  final DateTime timestamp;
  final bool isProcessed;
  final int retryCount;
  final Map<String, dynamic>? metadata;

  const ProgressEvent({
    required this.id,
    required this.userId,
    required this.type,
    required this.data,
    required this.timestamp,
    this.isProcessed = false,
    this.retryCount = 0,
    this.metadata,
  });

  ProgressEvent copyWith({
    String? id,
    String? userId,
    ProgressEventType? type,
    Map<String, dynamic>? data,
    DateTime? timestamp,
    bool? isProcessed,
    int? retryCount,
    Map<String, dynamic>? metadata,
  }) {
    return ProgressEvent(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      data: data ?? this.data,
      timestamp: timestamp ?? this.timestamp,
      isProcessed: isProcessed ?? this.isProcessed,
      retryCount: retryCount ?? this.retryCount,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'type': type.name,
      'data': data,
      'timestamp': timestamp.toIso8601String(),
      'isProcessed': isProcessed,
      'retryCount': retryCount,
      'metadata': metadata,
    };
  }

  factory ProgressEvent.fromMap(Map<String, dynamic> map) {
    return ProgressEvent(
      id: map['id'],
      userId: map['userId'],
      type: ProgressEventType.values.firstWhere(
        (t) => t.name == map['type'],
        orElse: () => ProgressEventType.custom,
      ),
      data: Map<String, dynamic>.from(map['data']),
      timestamp: DateTime.parse(map['timestamp']),
      isProcessed: map['isProcessed'] ?? false,
      retryCount: map['retryCount'] ?? 0,
      metadata: map['metadata'] != null
          ? Map<String, dynamic>.from(map['metadata'])
          : null,
    );
  }
}

/// Types of progress events
enum ProgressEventType {
  gameCompleted,
  achievementUnlocked,
  dailyLogin,
  streakIncreased,
  challengeCompleted,
  socialInteraction,
  milestoneReached,
  levelUp,
  pointsEarned,
  badgeAwarded,
  custom,
}

/// Daily goal data
class DailyGoal {
  final String id;
  final String name;
  final String description;
  final GoalType type;
  final int targetValue;
  final int currentValue;
  final DateTime date;
  final bool isCompleted;
  final int pointsReward;
  final Map<String, dynamic> config;

  const DailyGoal({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    required this.targetValue,
    required this.currentValue,
    required this.date,
    this.isCompleted = false,
    required this.pointsReward,
    this.config = const {},
  });

  DailyGoal copyWith({
    String? id,
    String? name,
    String? description,
    GoalType? type,
    int? targetValue,
    int? currentValue,
    DateTime? date,
    bool? isCompleted,
    int? pointsReward,
    Map<String, dynamic>? config,
  }) {
    return DailyGoal(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      type: type ?? this.type,
      targetValue: targetValue ?? this.targetValue,
      currentValue: currentValue ?? this.currentValue,
      date: date ?? this.date,
      isCompleted: isCompleted ?? this.isCompleted,
      pointsReward: pointsReward ?? this.pointsReward,
      config: config ?? this.config,
    );
  }

  double get progress =>
      targetValue > 0 ? (currentValue / targetValue).clamp(0.0, 1.0) : 0.0;
  int get remainingValue => math.max(0, targetValue - currentValue);
  bool get isAchieved => currentValue >= targetValue;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'type': type.name,
      'targetValue': targetValue,
      'currentValue': currentValue,
      'date': date.toIso8601String(),
      'isCompleted': isCompleted,
      'pointsReward': pointsReward,
      'config': config,
    };
  }

  factory DailyGoal.fromMap(Map<String, dynamic> map) {
    return DailyGoal(
      id: map['id'],
      name: map['name'],
      description: map['description'],
      type: GoalType.values.firstWhere(
        (t) => t.name == map['type'],
        orElse: () => GoalType.other,
      ),
      targetValue: map['targetValue'],
      currentValue: map['currentValue'],
      date: DateTime.parse(map['date']),
      isCompleted: map['isCompleted'] ?? false,
      pointsReward: map['pointsReward'],
      config: Map<String, dynamic>.from(map['config'] ?? {}),
    );
  }
}

/// Goal types
enum GoalType {
  playGames,
  earnPoints,
  completeAchievements,
  socialInteractions,
  streakDays,
  challenges,
  other,
}

/// Streak data
class StreakData {
  final String type;
  final int currentStreak;
  final int longestStreak;
  final DateTime lastActivityAt;
  final DateTime streakStartedAt;
  final Map<String, dynamic> metadata;

  const StreakData({
    required this.type,
    required this.currentStreak,
    required this.longestStreak,
    required this.lastActivityAt,
    required this.streakStartedAt,
    this.metadata = const {},
  });

  StreakData copyWith({
    String? type,
    int? currentStreak,
    int? longestStreak,
    DateTime? lastActivityAt,
    DateTime? streakStartedAt,
    Map<String, dynamic>? metadata,
  }) {
    return StreakData(
      type: type ?? this.type,
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      lastActivityAt: lastActivityAt ?? this.lastActivityAt,
      streakStartedAt: streakStartedAt ?? this.streakStartedAt,
      metadata: metadata ?? this.metadata,
    );
  }

  bool get isActive {
    final now = DateTime.now();
    final daysDiff = now.difference(lastActivityAt).inDays;
    return daysDiff <= 1; // Allow for timezone differences
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'currentStreak': currentStreak,
      'longestStreak': longestStreak,
      'lastActivityAt': lastActivityAt.toIso8601String(),
      'streakStartedAt': streakStartedAt.toIso8601String(),
      'metadata': metadata,
    };
  }

  factory StreakData.fromMap(Map<String, dynamic> map) {
    return StreakData(
      type: map['type'],
      currentStreak: map['currentStreak'],
      longestStreak: map['longestStreak'],
      lastActivityAt: DateTime.parse(map['lastActivityAt']),
      streakStartedAt: DateTime.parse(map['streakStartedAt']),
      metadata: Map<String, dynamic>.from(map['metadata'] ?? {}),
    );
  }
}

/// Progress tracking service
class ProgressTrackingService extends ChangeNotifier {
  final RewardsRepository _repository;
  final RewardsService _rewardsService;

  // Event processing
  final List<ProgressEvent> _eventQueue = [];
  final List<ProgressEvent> _offlineQueue = [];
  Timer? _processingTimer;
  Timer? _syncTimer;
  bool _isProcessingEvents = false;
  bool _isOnline = true;

  // Daily goals
  final Map<String, List<DailyGoal>> _dailyGoalsCache = {};
  DateTime? _lastDailyGoalsUpdate;

  // Streaks
  final Map<String, StreakData> _streaksCache = {};
  final Set<String> _trackedStreakTypes = {
    'daily_login',
    'games_played',
    'social_activity',
  };

  // Achievement progress
  final Map<String, Map<String, double>> _achievementProgress = {};

  // Batch processing
  static const int _batchSize = 50;
  static const Duration _batchInterval = Duration(seconds: 30);
  static const int _maxRetries = 3;

  // State
  bool _isInitialized = false;
  String? _currentUserId;
  SharedPreferences? _prefs;

  ProgressTrackingService({
    required RewardsRepository repository,
    required RewardsService rewardsService,
  }) : _repository = repository,
       _rewardsService = rewardsService;

  // Getters
  bool get isInitialized => _isInitialized;
  bool get isOnline => _isOnline;
  int get queueLength => _eventQueue.length;
  int get offlineQueueLength => _offlineQueue.length;
  String? get currentUserId => _currentUserId;

  /// Initialize the service
  Future<void> initialize(String userId) async {
    if (_isInitialized && _currentUserId == userId) return;

    try {
      _currentUserId = userId;

      // Initialize shared preferences
      _prefs = await SharedPreferences.getInstance();

      // Load offline queue
      await _loadOfflineQueue();

      // Load cached data
      await _loadCachedData();

      // Setup event listeners
      _setupEventListeners();

      // Start processing timers
      _startProcessingTimers();

      // Load daily goals
      await _loadDailyGoals();

      // Load streaks
      await _loadStreaks();

      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  /// Dispose of the service
  @override
  void dispose() {
    _processingTimer?.cancel();
    _syncTimer?.cancel();
    super.dispose();
  }

  /// Track a progress event
  Future<void> trackEvent(ProgressEvent event) async {
    try {
      if (_isOnline) {
        _eventQueue.add(event);
      } else {
        _offlineQueue.add(event);
        await _saveOfflineQueue();
      }

      // Process immediately if queue is small
      if (_eventQueue.length < 10) {
        await _processEventBatch();
      }

      notifyListeners();
    } catch (e) {
      // Fallback to offline queue
      _offlineQueue.add(event);
      await _saveOfflineQueue();
    }
  }

  /// Track multiple events at once
  Future<void> trackEvents(List<ProgressEvent> events) async {
    for (final event in events) {
      await trackEvent(event);
    }
  }

  /// Get daily goals for user
  Future<List<DailyGoal>> getDailyGoals(String userId, {DateTime? date}) async {
    final targetDate = date ?? DateTime.now();
    final dateKey = _formatDateKey(targetDate);
    final cacheKey = '${userId}_$dateKey';

    // Check cache first
    if (_dailyGoalsCache.containsKey(cacheKey) &&
        _lastDailyGoalsUpdate != null &&
        DateTime.now().difference(_lastDailyGoalsUpdate!) <
            const Duration(minutes: 5)) {
      return _dailyGoalsCache[cacheKey]!;
    }

    try {
      final goals = await _fetchDailyGoals(userId, targetDate);
      _dailyGoalsCache[cacheKey] = goals;
      _lastDailyGoalsUpdate = DateTime.now();

      return goals;
    } catch (e) {
      return _dailyGoalsCache[cacheKey] ?? [];
    }
  }

  /// Get streaks for user
  Future<Map<String, StreakData>> getStreaks(String userId) async {
    if (_streaksCache.isNotEmpty) {
      return Map.from(_streaksCache);
    }

    try {
      final streaks = await _fetchStreaks(userId);
      _streaksCache.addAll(streaks);

      return streaks;
    } catch (e) {
      return {};
    }
  }

  /// Update daily goal progress
  Future<void> updateDailyGoalProgress(
    String userId,
    String goalId,
    int progressValue, {
    bool isIncrement = true,
  }) async {
    try {
      final today = DateTime.now();
      final goals = await getDailyGoals(userId, date: today);

      final goalIndex = goals.indexWhere((g) => g.id == goalId);
      if (goalIndex == -1) return;

      final goal = goals[goalIndex];
      final newValue = isIncrement
          ? goal.currentValue + progressValue
          : progressValue;

      final updatedGoal = goal.copyWith(
        currentValue: newValue,
        isCompleted: newValue >= goal.targetValue,
      );

      goals[goalIndex] = updatedGoal;

      // Update cache
      final dateKey = _formatDateKey(today);
      final cacheKey = '${userId}_$dateKey';
      _dailyGoalsCache[cacheKey] = goals;

      // Save to repository
      await _repository.updateDailyGoalProgress(
        userId,
        goalId,
        newValue.toDouble(),
      );

      // Check if goal was just completed
      if (!goal.isCompleted && updatedGoal.isCompleted) {
        await _handleDailyGoalCompleted(userId, updatedGoal);
      }

      notifyListeners();
    } catch (e) {}
  }

  /// Update streak
  Future<void> updateStreak(String userId, String streakType) async {
    try {
      final currentStreak = _streaksCache[streakType];
      final now = DateTime.now();

      StreakData updatedStreak;

      if (currentStreak == null) {
        // New streak
        updatedStreak = StreakData(
          type: streakType,
          currentStreak: 1,
          longestStreak: 1,
          lastActivityAt: now,
          streakStartedAt: now,
        );
      } else if (currentStreak.isActive) {
        // Continue existing streak
        final daysSinceLastActivity = now
            .difference(currentStreak.lastActivityAt)
            .inDays;

        if (daysSinceLastActivity == 0) {
          // Same day, no change to streak count
          updatedStreak = currentStreak.copyWith(lastActivityAt: now);
        } else if (daysSinceLastActivity == 1) {
          // Next day, increment streak
          final newStreakCount = currentStreak.currentStreak + 1;
          updatedStreak = currentStreak.copyWith(
            currentStreak: newStreakCount,
            longestStreak: math.max(
              currentStreak.longestStreak,
              newStreakCount,
            ),
            lastActivityAt: now,
          );
        } else {
          // Streak broken, start new
          updatedStreak = StreakData(
            type: streakType,
            currentStreak: 1,
            longestStreak: currentStreak.longestStreak,
            lastActivityAt: now,
            streakStartedAt: now,
          );
        }
      } else {
        // Streak was inactive, start new
        updatedStreak = StreakData(
          type: streakType,
          currentStreak: 1,
          longestStreak: currentStreak.longestStreak,
          lastActivityAt: now,
          streakStartedAt: now,
        );
      }

      // Update cache
      _streaksCache[streakType] = updatedStreak;

      // Save to repository
      await _repository.updateStreak(userId, {
        'type': updatedStreak.type,
        'currentStreak': updatedStreak.currentStreak,
        'longestStreak': updatedStreak.longestStreak,
        'lastActivityAt': updatedStreak.lastActivityAt.toIso8601String(),
        'streakStartedAt': updatedStreak.streakStartedAt.toIso8601String(),
        'metadata': updatedStreak.metadata,
      });

      // Track streak milestone achievements
      if (updatedStreak.currentStreak > (currentStreak?.currentStreak ?? 0)) {
        await _checkStreakMilestones(userId, updatedStreak);
      }

      notifyListeners();
    } catch (e) {}
  }

  /// Check achievement progress
  Future<void> checkAchievementProgress(String userId) async {
    try {
      final achievementsResult = await _repository.getAllAchievements();

      achievementsResult.fold((failure) => null, (achievements) async {
        for (final achievement in achievements) {
          await _checkSingleAchievementProgress(userId, achievement);
        }
      });
    } catch (e) {
      // Silently handle error
    }
  }

  /// Set online/offline status
  void setOnlineStatus(bool isOnline) {
    if (_isOnline != isOnline) {
      _isOnline = isOnline;

      if (isOnline) {
        _syncOfflineQueue();
      }

      notifyListeners();
    }
  }

  /// Force sync offline queue
  Future<void> syncOfflineQueue() async {
    await _syncOfflineQueue();
  }

  /// Clear all caches
  void clearCaches() {
    _dailyGoalsCache.clear();
    _streaksCache.clear();
    _achievementProgress.clear();
    notifyListeners();
  }

  /// Get progress statistics
  Map<String, dynamic> getProgressStatistics() {
    return {
      'eventsInQueue': _eventQueue.length,
      'offlineEvents': _offlineQueue.length,
      'dailyGoalsCached': _dailyGoalsCache.length,
      'streaksTracked': _streaksCache.length,
      'achievementsTracked': _achievementProgress.length,
      'isOnline': _isOnline,
      'isProcessing': _isProcessingEvents,
    };
  }

  // Private methods

  void _setupEventListeners() {
    // Listen to rewards service events
    _rewardsService.eventStream.listen((event) {
      _handleRewardsEvent(event);
    });
  }

  void _handleRewardsEvent(RewardsEvent event) {
    final progressEvent = ProgressEvent(
      id: _generateEventId(),
      userId: event.userId,
      type: _mapRewardsEventToProgressEvent(event.type),
      data: event.data,
      timestamp: event.timestamp,
      metadata: event.metadata,
    );

    trackEvent(progressEvent);
  }

  ProgressEventType _mapRewardsEventToProgressEvent(
    RewardsEventType rewardsEventType,
  ) {
    switch (rewardsEventType) {
      case RewardsEventType.gameCompleted:
        return ProgressEventType.gameCompleted;
      case RewardsEventType.achievementUnlocked:
        return ProgressEventType.achievementUnlocked;
      case RewardsEventType.dailyLoginStreak:
        return ProgressEventType.dailyLogin;
      case RewardsEventType.challengeCompleted:
        return ProgressEventType.challengeCompleted;
      case RewardsEventType.socialInteraction:
        return ProgressEventType.socialInteraction;
      case RewardsEventType.pointsEarned:
        return ProgressEventType.pointsEarned;
      case RewardsEventType.badgeAwarded:
        return ProgressEventType.badgeAwarded;
      default:
        return ProgressEventType.custom;
    }
  }

  void _startProcessingTimers() {
    _processingTimer?.cancel();
    _processingTimer = Timer.periodic(_batchInterval, (_) {
      _processEventBatch();
    });

    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      if (_isOnline) {
        _syncOfflineQueue();
      }
    });
  }

  Future<void> _processEventBatch() async {
    if (_isProcessingEvents || _eventQueue.isEmpty) return;

    _isProcessingEvents = true;

    try {
      final batch = _eventQueue.take(_batchSize).toList();
      _eventQueue.removeRange(0, math.min(_batchSize, _eventQueue.length));

      await _processBatch(batch);
    } finally {
      _isProcessingEvents = false;
    }
  }

  Future<void> _processBatch(List<ProgressEvent> batch) async {
    for (final event in batch) {
      try {
        await _processEvent(event);
      } catch (e) {
        // Retry logic
        if (event.retryCount < _maxRetries) {
          final retryEvent = event.copyWith(retryCount: event.retryCount + 1);
          _eventQueue.add(retryEvent);
        } else {
          // Move to offline queue for later retry
          _offlineQueue.add(event);
          await _saveOfflineQueue();
        }
      }
    }
  }

  Future<void> _processEvent(ProgressEvent event) async {
    switch (event.type) {
      case ProgressEventType.gameCompleted:
        await _handleGameCompleted(event);
        break;
      case ProgressEventType.dailyLogin:
        await _handleDailyLogin(event);
        break;
      case ProgressEventType.streakIncreased:
        await _handleStreakIncreased(event);
        break;
      case ProgressEventType.socialInteraction:
        await _handleSocialInteraction(event);
        break;
      default:
        await _handleCustomEvent(event);
    }

    // Update daily goals based on event
    await _updateDailyGoalsFromEvent(event);

    // Update streaks based on event
    await _updateStreaksFromEvent(event);

    // Check achievement progress
    await _updateAchievementProgressFromEvent(event);
  }

  Future<void> _handleGameCompleted(ProgressEvent event) async {
    // Update game-related daily goals
    await updateDailyGoalProgress(event.userId, 'play_games', 1);
  }

  Future<void> _handleDailyLogin(ProgressEvent event) async {
    // Update login streak
    await updateStreak(event.userId, 'daily_login');
  }

  Future<void> _handleStreakIncreased(ProgressEvent event) async {
    // Already handled by updateStreak
  }

  Future<void> _handleSocialInteraction(ProgressEvent event) async {
    // Update social activity goals
    await updateDailyGoalProgress(event.userId, 'social_interactions', 1);
  }

  Future<void> _handleCustomEvent(ProgressEvent event) async {
    // Handle custom events based on metadata
  }

  Future<void> _updateDailyGoalsFromEvent(ProgressEvent event) async {
    final today = DateTime.now();
    final goals = await getDailyGoals(event.userId, date: today);

    for (final goal in goals) {
      if (_shouldUpdateGoalFromEvent(goal, event)) {
        final increment = _calculateGoalIncrement(goal, event);
        await updateDailyGoalProgress(event.userId, goal.id, increment);
      }
    }
  }

  bool _shouldUpdateGoalFromEvent(DailyGoal goal, ProgressEvent event) {
    switch (goal.type) {
      case GoalType.playGames:
        return event.type == ProgressEventType.gameCompleted;
      case GoalType.earnPoints:
        return event.type == ProgressEventType.pointsEarned;
      case GoalType.completeAchievements:
        return event.type == ProgressEventType.achievementUnlocked;
      case GoalType.socialInteractions:
        return event.type == ProgressEventType.socialInteraction;
      case GoalType.streakDays:
        return event.type == ProgressEventType.streakIncreased;
      case GoalType.challenges:
        return event.type == ProgressEventType.challengeCompleted;
      default:
        return false;
    }
  }

  int _calculateGoalIncrement(DailyGoal goal, ProgressEvent event) {
    switch (goal.type) {
      case GoalType.earnPoints:
        return event.data['points'] ?? 1;
      default:
        return 1;
    }
  }

  Future<void> _updateStreaksFromEvent(ProgressEvent event) async {
    for (final streakType in _trackedStreakTypes) {
      if (_shouldUpdateStreakFromEvent(streakType, event)) {
        await updateStreak(event.userId, streakType);
      }
    }
  }

  bool _shouldUpdateStreakFromEvent(String streakType, ProgressEvent event) {
    switch (streakType) {
      case 'daily_login':
        return event.type == ProgressEventType.dailyLogin;
      case 'games_played':
        return event.type == ProgressEventType.gameCompleted;
      case 'social_activity':
        return event.type == ProgressEventType.socialInteraction;
      default:
        return false;
    }
  }

  Future<void> _updateAchievementProgressFromEvent(ProgressEvent event) async {
    // This would typically involve complex achievement progress tracking
    // For now, we'll just trigger a general check
    await checkAchievementProgress(event.userId);
  }

  Future<void> _checkSingleAchievementProgress(
    String userId,
    Achievement achievement,
  ) async {
    try {
      // Get current progress for this achievement
      final progressKey = '${userId}_${achievement.id}';
      // Calculate new progress based on achievement criteria
      final newProgress = await _calculateAchievementProgress(
        userId,
        achievement,
      );

      // Check if achievement should be unlocked
      bool shouldUnlock =
          true; // Assume it should unlock unless a criteria fails
      for (final criteriaEntry in achievement.criteria.entries) {
        final criteriaKey = criteriaEntry.key;
        final criteriaValue = criteriaEntry.value;

        // Extract target value from criteria - adapt based on your actual criteria structure
        final targetValue = criteriaValue is Map
            ? (criteriaValue['target'] ?? criteriaValue['count'] ?? 1.0)
            : criteriaValue;
        final progressValue = newProgress[criteriaKey] ?? 0.0;

        if (progressValue <
            (targetValue is num ? targetValue.toDouble() : 1.0)) {
          shouldUnlock = false;
          break;
        }
      }

      if (shouldUnlock) {
        // Unlock achievement via rewards service
        await _rewardsService.unlockAchievement(
          userId: userId,
          achievementId: achievement.id,
        );
      } else {
        // Update progress cache
        _achievementProgress[progressKey] = newProgress;
      }
    } catch (e) {}
  }

  Future<Map<String, double>> _calculateAchievementProgress(
    String userId,
    Achievement achievement,
  ) async {
    final progress = <String, double>{};

    // This would involve complex calculations based on user data
    // For now, returning mock progress based on criteria keys
    for (final criteriaEntry in achievement.criteria.entries) {
      final criteriaKey = criteriaEntry.key;
      final criteriaValue = criteriaEntry.value;

      // Extract target value and calculate mock progress
      final targetValue = criteriaValue is Map
          ? (criteriaValue['target'] ?? criteriaValue['count'] ?? 100.0)
          : 100.0;
      progress[criteriaKey] =
          math.Random().nextDouble() *
          (targetValue is num ? targetValue.toDouble() : 100.0);
    }

    return progress;
  }

  Future<void> _checkStreakMilestones(String userId, StreakData streak) async {
    final milestones = [7, 30, 100, 365]; // Common milestone days

    if (milestones.contains(streak.currentStreak)) {
      await trackEvent(
        ProgressEvent(
          id: _generateEventId(),
          userId: userId,
          type: ProgressEventType.milestoneReached,
          data: {'streakType': streak.type, 'milestone': streak.currentStreak},
          timestamp: DateTime.now(),
        ),
      );
    }
  }

  Future<void> _handleDailyGoalCompleted(String userId, DailyGoal goal) async {
    // Award points for completing daily goal
    await _rewardsService.awardPoints(
      userId: userId,
      points: goal.pointsReward,
      reason: 'Daily goal completed: ${goal.name}',
      source: 'daily_goal_${goal.id}',
    );

    // Track goal completion event
    await trackEvent(
      ProgressEvent(
        id: _generateEventId(),
        userId: userId,
        type: ProgressEventType.milestoneReached,
        data: {
          'goalId': goal.id,
          'goalName': goal.name,
          'pointsRewarded': goal.pointsReward,
        },
        timestamp: DateTime.now(),
      ),
    );
  }

  Future<void> _syncOfflineQueue() async {
    if (_offlineQueue.isEmpty) return;

    try {
      final eventsToSync = List<ProgressEvent>.from(_offlineQueue);
      _offlineQueue.clear();

      for (final event in eventsToSync) {
        _eventQueue.add(event);
      }

      await _saveOfflineQueue();
    } catch (e) {}
  }

  Future<void> _loadOfflineQueue() async {
    try {
      final queueData = _prefs?.getString('offline_queue_$_currentUserId');
      if (queueData != null) {
        final List<dynamic> queueList = jsonDecode(queueData);
        _offlineQueue.addAll(
          queueList.map((data) => ProgressEvent.fromMap(data)).toList(),
        );
      }
    } catch (e) {}
  }

  Future<void> _saveOfflineQueue() async {
    try {
      final queueData = _offlineQueue.map((event) => event.toMap()).toList();
      await _prefs?.setString(
        'offline_queue_$_currentUserId',
        jsonEncode(queueData),
      );
    } catch (e) {}
  }

  Future<void> _loadCachedData() async {
    // Load cached data from shared preferences
    try {
      final dailyGoalsData = _prefs?.getString('daily_goals_$_currentUserId');
      if (dailyGoalsData != null) {
        final Map<String, dynamic> goalsMap = jsonDecode(dailyGoalsData);
        for (final entry in goalsMap.entries) {
          final List<dynamic> goalsList = entry.value;
          _dailyGoalsCache[entry.key] = goalsList
              .map((data) => DailyGoal.fromMap(data))
              .toList();
        }
      }

      final streaksData = _prefs?.getString('streaks_$_currentUserId');
      if (streaksData != null) {
        final Map<String, dynamic> streaksMap = jsonDecode(streaksData);
        for (final entry in streaksMap.entries) {
          _streaksCache[entry.key] = StreakData.fromMap(entry.value);
        }
      }
    } catch (e) {}
  }

  Future<List<DailyGoal>> _fetchDailyGoals(String userId, DateTime date) async {
    // This would typically fetch from repository
    // For now, returning mock daily goals
    return [
      DailyGoal(
        id: 'play_games',
        name: 'Play Games',
        description: 'Complete 5 games today',
        type: GoalType.playGames,
        targetValue: 5,
        currentValue: math.Random().nextInt(5),
        date: date,
        pointsReward: 50,
      ),
      DailyGoal(
        id: 'earn_points',
        name: 'Earn Points',
        description: 'Earn 100 points today',
        type: GoalType.earnPoints,
        targetValue: 100,
        currentValue: math.Random().nextInt(100),
        date: date,
        pointsReward: 25,
      ),
      DailyGoal(
        id: 'social_interactions',
        name: 'Social Activity',
        description: 'Make 3 social interactions',
        type: GoalType.socialInteractions,
        targetValue: 3,
        currentValue: math.Random().nextInt(3),
        date: date,
        pointsReward: 30,
      ),
    ];
  }

  Future<Map<String, StreakData>> _fetchStreaks(String userId) async {
    // This would typically fetch from repository
    // For now, returning mock streaks
    final now = DateTime.now();
    return {
      'daily_login': StreakData(
        type: 'daily_login',
        currentStreak: 5,
        longestStreak: 15,
        lastActivityAt: now.subtract(const Duration(hours: 2)),
        streakStartedAt: now.subtract(const Duration(days: 5)),
      ),
      'games_played': StreakData(
        type: 'games_played',
        currentStreak: 3,
        longestStreak: 10,
        lastActivityAt: now.subtract(const Duration(hours: 1)),
        streakStartedAt: now.subtract(const Duration(days: 3)),
      ),
    };
  }

  Future<void> _loadDailyGoals() async {
    if (_currentUserId != null) {
      await getDailyGoals(_currentUserId!);
    }
  }

  Future<void> _loadStreaks() async {
    if (_currentUserId != null) {
      await getStreaks(_currentUserId!);
    }
  }

  String _generateEventId() {
    return '${DateTime.now().millisecondsSinceEpoch}_${math.Random().nextInt(10000)}';
  }

  String _formatDateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// Get the count of games played for a specific sport
  Future<int> getSportGamesCount(String userId, String sport) async {
    try {
      // For now return a stub value
      return 0;
    } catch (e) {
      return 0;
    }
  }

  /// Get the current win streak for a user in a specific sport
  Future<int> getCurrentWinStreak(String userId, String sport) async {
    try {
      // For now return a stub value
      return 0;
    } catch (e) {
      return 0;
    }
  }
}
