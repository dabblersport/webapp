import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dabbler/data/models/rewards/achievement.dart';
import 'rewards_service.dart';

/// Analytics event data
class AnalyticsEvent {
  final String id;
  final String userId;
  final String eventName;
  final Map<String, dynamic> properties;
  final DateTime timestamp;
  final String? sessionId;
  final Map<String, dynamic>? context;
  final bool isCustom;

  const AnalyticsEvent({
    required this.id,
    required this.userId,
    required this.eventName,
    required this.properties,
    required this.timestamp,
    this.sessionId,
    this.context,
    this.isCustom = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'eventName': eventName,
      'properties': properties,
      'timestamp': timestamp.toIso8601String(),
      'sessionId': sessionId,
      'context': context,
      'isCustom': isCustom,
    };
  }

  factory AnalyticsEvent.fromMap(Map<String, dynamic> map) {
    return AnalyticsEvent(
      id: map['id'],
      userId: map['userId'],
      eventName: map['eventName'],
      properties: Map<String, dynamic>.from(map['properties']),
      timestamp: DateTime.parse(map['timestamp']),
      sessionId: map['sessionId'],
      context: map['context'] != null
          ? Map<String, dynamic>.from(map['context'])
          : null,
      isCustom: map['isCustom'] ?? false,
    );
  }
}

/// User behavior metrics
class UserBehaviorMetrics {
  final String userId;
  final int sessionsCount;
  final Duration totalTimeSpent;
  final Duration averageSessionDuration;
  final int totalEvents;
  final DateTime lastActiveAt;
  final Map<String, int> eventCounts;
  final Map<String, dynamic> customMetrics;

  const UserBehaviorMetrics({
    required this.userId,
    required this.sessionsCount,
    required this.totalTimeSpent,
    required this.averageSessionDuration,
    required this.totalEvents,
    required this.lastActiveAt,
    required this.eventCounts,
    this.customMetrics = const {},
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'sessionsCount': sessionsCount,
      'totalTimeSpent': totalTimeSpent.inMilliseconds,
      'averageSessionDuration': averageSessionDuration.inMilliseconds,
      'totalEvents': totalEvents,
      'lastActiveAt': lastActiveAt.toIso8601String(),
      'eventCounts': eventCounts,
      'customMetrics': customMetrics,
    };
  }

  factory UserBehaviorMetrics.fromMap(Map<String, dynamic> map) {
    return UserBehaviorMetrics(
      userId: map['userId'],
      sessionsCount: map['sessionsCount'],
      totalTimeSpent: Duration(milliseconds: map['totalTimeSpent']),
      averageSessionDuration: Duration(
        milliseconds: map['averageSessionDuration'],
      ),
      totalEvents: map['totalEvents'],
      lastActiveAt: DateTime.parse(map['lastActiveAt']),
      eventCounts: Map<String, int>.from(map['eventCounts']),
      customMetrics: Map<String, dynamic>.from(map['customMetrics'] ?? {}),
    );
  }
}

/// Engagement metrics
class EngagementMetrics {
  final String userId;
  final double engagementScore;
  final int dailyActiveStreak;
  final int weeklyActiveDays;
  final int monthlyActiveDays;
  final Map<String, double> featureUsage;
  final Map<String, int> actionCounts;
  final DateTime calculatedAt;

  const EngagementMetrics({
    required this.userId,
    required this.engagementScore,
    required this.dailyActiveStreak,
    required this.weeklyActiveDays,
    required this.monthlyActiveDays,
    required this.featureUsage,
    required this.actionCounts,
    required this.calculatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'engagementScore': engagementScore,
      'dailyActiveStreak': dailyActiveStreak,
      'weeklyActiveDays': weeklyActiveDays,
      'monthlyActiveDays': monthlyActiveDays,
      'featureUsage': featureUsage,
      'actionCounts': actionCounts,
      'calculatedAt': calculatedAt.toIso8601String(),
    };
  }

  factory EngagementMetrics.fromMap(Map<String, dynamic> map) {
    return EngagementMetrics(
      userId: map['userId'],
      engagementScore: map['engagementScore'].toDouble(),
      dailyActiveStreak: map['dailyActiveStreak'],
      weeklyActiveDays: map['weeklyActiveDays'],
      monthlyActiveDays: map['monthlyActiveDays'],
      featureUsage: Map<String, double>.from(map['featureUsage']),
      actionCounts: Map<String, int>.from(map['actionCounts']),
      calculatedAt: DateTime.parse(map['calculatedAt']),
    );
  }
}

/// A/B test data
class ABTestData {
  final String testId;
  final String userId;
  final String variant;
  final DateTime assignedAt;
  final Map<String, dynamic> testConfig;
  final List<String> goalEvents;
  final bool hasConverted;
  final DateTime? convertedAt;
  final Map<String, dynamic>? conversionData;

  const ABTestData({
    required this.testId,
    required this.userId,
    required this.variant,
    required this.assignedAt,
    required this.testConfig,
    required this.goalEvents,
    this.hasConverted = false,
    this.convertedAt,
    this.conversionData,
  });

  Map<String, dynamic> toMap() {
    return {
      'testId': testId,
      'userId': userId,
      'variant': variant,
      'assignedAt': assignedAt.toIso8601String(),
      'testConfig': testConfig,
      'goalEvents': goalEvents,
      'hasConverted': hasConverted,
      'convertedAt': convertedAt?.toIso8601String(),
      'conversionData': conversionData,
    };
  }

  factory ABTestData.fromMap(Map<String, dynamic> map) {
    return ABTestData(
      testId: map['testId'],
      userId: map['userId'],
      variant: map['variant'],
      assignedAt: DateTime.parse(map['assignedAt']),
      testConfig: Map<String, dynamic>.from(map['testConfig']),
      goalEvents: List<String>.from(map['goalEvents']),
      hasConverted: map['hasConverted'] ?? false,
      convertedAt: map['convertedAt'] != null
          ? DateTime.parse(map['convertedAt'])
          : null,
      conversionData: map['conversionData'] != null
          ? Map<String, dynamic>.from(map['conversionData'])
          : null,
    );
  }
}

/// Conversion funnel step
class FunnelStep {
  final String stepId;
  final String stepName;
  final List<String> requiredEvents;
  final Duration? maxTimeToNext;
  final Map<String, dynamic>? conditions;

  const FunnelStep({
    required this.stepId,
    required this.stepName,
    required this.requiredEvents,
    this.maxTimeToNext,
    this.conditions,
  });

  Map<String, dynamic> toMap() {
    return {
      'stepId': stepId,
      'stepName': stepName,
      'requiredEvents': requiredEvents,
      'maxTimeToNext': maxTimeToNext?.inMilliseconds,
      'conditions': conditions,
    };
  }

  factory FunnelStep.fromMap(Map<String, dynamic> map) {
    return FunnelStep(
      stepId: map['stepId'],
      stepName: map['stepName'],
      requiredEvents: List<String>.from(map['requiredEvents']),
      maxTimeToNext: map['maxTimeToNext'] != null
          ? Duration(milliseconds: map['maxTimeToNext'])
          : null,
      conditions: map['conditions'] != null
          ? Map<String, dynamic>.from(map['conditions'])
          : null,
    );
  }
}

/// Conversion funnel data
class ConversionFunnel {
  final String funnelId;
  final String name;
  final List<FunnelStep> steps;
  final DateTime createdAt;
  final Map<String, dynamic>? config;

  const ConversionFunnel({
    required this.funnelId,
    required this.name,
    required this.steps,
    required this.createdAt,
    this.config,
  });

  Map<String, dynamic> toMap() {
    return {
      'funnelId': funnelId,
      'name': name,
      'steps': steps.map((s) => s.toMap()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'config': config,
    };
  }

  factory ConversionFunnel.fromMap(Map<String, dynamic> map) {
    return ConversionFunnel(
      funnelId: map['funnelId'],
      name: map['name'],
      steps: (map['steps'] as List).map((s) => FunnelStep.fromMap(s)).toList(),
      createdAt: DateTime.parse(map['createdAt']),
      config: map['config'] != null
          ? Map<String, dynamic>.from(map['config'])
          : null,
    );
  }
}

/// Analytics report data
class AnalyticsReport {
  final String reportId;
  final String name;
  final ReportType type;
  final Map<String, dynamic> data;
  final DateTime generatedAt;
  final DateTime periodStart;
  final DateTime periodEnd;
  final Map<String, dynamic>? filters;

  const AnalyticsReport({
    required this.reportId,
    required this.name,
    required this.type,
    required this.data,
    required this.generatedAt,
    required this.periodStart,
    required this.periodEnd,
    this.filters,
  });

  Map<String, dynamic> toMap() {
    return {
      'reportId': reportId,
      'name': name,
      'type': type.name,
      'data': data,
      'generatedAt': generatedAt.toIso8601String(),
      'periodStart': periodStart.toIso8601String(),
      'periodEnd': periodEnd.toIso8601String(),
      'filters': filters,
    };
  }

  factory AnalyticsReport.fromMap(Map<String, dynamic> map) {
    return AnalyticsReport(
      reportId: map['reportId'],
      name: map['name'],
      type: ReportType.values.firstWhere(
        (t) => t.name == map['type'],
        orElse: () => ReportType.custom,
      ),
      data: Map<String, dynamic>.from(map['data']),
      generatedAt: DateTime.parse(map['generatedAt']),
      periodStart: DateTime.parse(map['periodStart']),
      periodEnd: DateTime.parse(map['periodEnd']),
      filters: map['filters'] != null
          ? Map<String, dynamic>.from(map['filters'])
          : null,
    );
  }
}

/// Report types
enum ReportType {
  achievements,
  engagement,
  behavior,
  conversion,
  retention,
  custom,
}

/// Rewards analytics service
class RewardsAnalyticsService extends ChangeNotifier {
  // Event processing
  final List<AnalyticsEvent> _eventQueue = [];
  final List<AnalyticsEvent> _offlineQueue = [];
  Timer? _processingTimer;
  bool _isProcessingEvents = false;

  // Metrics cache
  final Map<String, UserBehaviorMetrics> _behaviorMetricsCache = {};
  final Map<String, EngagementMetrics> _engagementMetricsCache = {};
  DateTime? _lastMetricsUpdate;

  // A/B testing
  final Map<String, List<ABTestData>> _activeTests = {};
  final Map<String, ConversionFunnel> _conversionFunnels = {};

  // Session tracking
  String? _currentSessionId;
  DateTime? _sessionStartTime;
  final Map<String, int> _sessionEventCounts = {};

  // State
  bool _isInitialized = false;
  String? _currentUserId;
  SharedPreferences? _prefs;
  bool _isOnline = true;

  // Configuration
  static const Duration _batchInterval = Duration(seconds: 30);
  static const int _batchSize = 50;
  static const Duration _sessionTimeout = Duration(minutes: 30);

  // Getters
  bool get isInitialized => _isInitialized;
  bool get isOnline => _isOnline;
  int get queueLength => _eventQueue.length;
  int get offlineQueueLength => _offlineQueue.length;
  String? get currentUserId => _currentUserId;
  String? get currentSessionId => _currentSessionId;

  /// Initialize the service
  Future<void> initialize(String userId) async {
    if (_isInitialized && _currentUserId == userId) return;

    try {
      _currentUserId = userId;

      // Initialize shared preferences
      _prefs = await SharedPreferences.getInstance();

      // Load offline queue
      await _loadOfflineQueue();

      // Start new session
      await _startNewSession();

      // Load cached data
      await _loadCachedData();

      // Setup A/B tests
      await _setupABTests();

      // Setup conversion funnels
      await _setupConversionFunnels();

      // Start processing timers
      _startProcessingTimers();

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
    _endCurrentSession();
    super.dispose();
  }

  /// Track an analytics event
  Future<void> trackEvent(
    String eventName,
    Map<String, dynamic> properties, {
    bool isCustom = false,
  }) async {
    if (_currentUserId == null) return;

    final event = AnalyticsEvent(
      id: _generateEventId(),
      userId: _currentUserId!,
      eventName: eventName,
      properties: properties,
      timestamp: DateTime.now(),
      sessionId: _currentSessionId,
      context: _buildEventContext(),
      isCustom: isCustom,
    );

    await _queueEvent(event);

    // Update session metrics
    _updateSessionMetrics(event);

    // Check A/B test conversions
    _checkABTestConversions(event);

    // Update funnel progress
    _updateFunnelProgress(event);
  }

  /// Track rewards-specific event
  Future<void> trackRewardsEvent(RewardsEvent rewardsEvent) async {
    await trackEvent('rewards_${rewardsEvent.type.name}', {
      ...rewardsEvent.data,
      'source': rewardsEvent.sourceId,
      'rewardsMetadata': rewardsEvent.metadata,
    });
  }

  /// Track achievement unlock
  Future<void> trackAchievementUnlock(Achievement achievement) async {
    await trackEvent('achievement_unlocked', {
      'achievementId': achievement.id,
      'achievementName': achievement.name,
      'tier': achievement.tier.name,
      'pointsRewarded': achievement.criteria['pointsReward'] ?? 0,
      'category': achievement.category,
    });
  }

  /// Track error
  Future<void> trackError(
    String errorType,
    String errorMessage,
    Map<String, dynamic> context,
  ) async {
    await trackEvent('error', {
      'errorType': errorType,
      'errorMessage': errorMessage,
      'context': context,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  /// Get user behavior metrics
  Future<UserBehaviorMetrics> getUserBehaviorMetrics(String userId) async {
    // Check cache first
    if (_behaviorMetricsCache.containsKey(userId) && _isCacheValid()) {
      return _behaviorMetricsCache[userId]!;
    }

    try {
      final metrics = await _calculateBehaviorMetrics(userId);
      _behaviorMetricsCache[userId] = metrics;

      return metrics;
    } catch (e) {
      rethrow;
    }
  }

  /// Get engagement metrics
  Future<EngagementMetrics> getEngagementMetrics(String userId) async {
    // Check cache first
    if (_engagementMetricsCache.containsKey(userId) && _isCacheValid()) {
      return _engagementMetricsCache[userId]!;
    }

    try {
      final metrics = await _calculateEngagementMetrics(userId);
      _engagementMetricsCache[userId] = metrics;

      return metrics;
    } catch (e) {
      rethrow;
    }
  }

  /// Get A/B test variant for user
  String getABTestVariant(String testId, String userId) {
    final userTests = _activeTests[userId] ?? [];
    final testData = userTests.where((t) => t.testId == testId).firstOrNull;

    if (testData != null) {
      return testData.variant;
    }

    // Assign new variant
    return _assignABTestVariant(testId, userId);
  }

  /// Generate analytics report
  Future<AnalyticsReport> generateReport(
    ReportType type,
    DateTime periodStart,
    DateTime periodEnd, {
    Map<String, dynamic>? filters,
  }) async {
    try {
      final data = await _generateReportData(
        type,
        periodStart,
        periodEnd,
        filters,
      );

      final report = AnalyticsReport(
        reportId: _generateReportId(),
        name: _getReportName(type),
        type: type,
        data: data,
        generatedAt: DateTime.now(),
        periodStart: periodStart,
        periodEnd: periodEnd,
        filters: filters,
      );

      return report;
    } catch (e) {
      rethrow;
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

  /// Get analytics statistics
  Map<String, dynamic> getAnalyticsStatistics() {
    return {
      'eventsInQueue': _eventQueue.length,
      'offlineEvents': _offlineQueue.length,
      'currentSessionId': _currentSessionId,
      'sessionEventCount': _sessionEventCounts.values.fold<int>(
        0,
        (a, b) => a + b,
      ),
      'behaviorMetricsCached': _behaviorMetricsCache.length,
      'engagementMetricsCached': _engagementMetricsCache.length,
      'activeABTests': _activeTests.length,
      'conversionFunnels': _conversionFunnels.length,
      'isOnline': _isOnline,
    };
  }

  // Private methods

  Future<void> _queueEvent(AnalyticsEvent event) async {
    if (_isOnline) {
      _eventQueue.add(event);
    } else {
      _offlineQueue.add(event);
      await _saveOfflineQueue();
    }

    notifyListeners();
  }

  void _updateSessionMetrics(AnalyticsEvent event) {
    _sessionEventCounts[event.eventName] =
        (_sessionEventCounts[event.eventName] ?? 0) + 1;
  }

  void _checkABTestConversions(AnalyticsEvent event) {
    final userTests = _activeTests[event.userId] ?? [];

    for (final testData in userTests) {
      if (!testData.hasConverted &&
          testData.goalEvents.contains(event.eventName)) {
        // Mark as converted
        final convertedTest = ABTestData(
          testId: testData.testId,
          userId: testData.userId,
          variant: testData.variant,
          assignedAt: testData.assignedAt,
          testConfig: testData.testConfig,
          goalEvents: testData.goalEvents,
          hasConverted: true,
          convertedAt: DateTime.now(),
          conversionData: event.properties,
        );

        // Update test data
        final userTestsList = _activeTests[event.userId]!;
        final testIndex = userTestsList.indexWhere(
          (t) => t.testId == testData.testId,
        );
        if (testIndex >= 0) {
          userTestsList[testIndex] = convertedTest;
        }

        // Track conversion event
        trackEvent('ab_test_conversion', {
          'testId': testData.testId,
          'variant': testData.variant,
          'goalEvent': event.eventName,
        });
      }
    }
  }

  void _updateFunnelProgress(AnalyticsEvent event) {
    for (final funnel in _conversionFunnels.values) {
      for (final step in funnel.steps) {
        if (step.requiredEvents.contains(event.eventName)) {
          _trackFunnelStepCompletion(funnel.funnelId, step.stepId, event);
        }
      }
    }
  }

  void _trackFunnelStepCompletion(
    String funnelId,
    String stepId,
    AnalyticsEvent event,
  ) {
    trackEvent('funnel_step_completed', {
      'funnelId': funnelId,
      'stepId': stepId,
      'originalEvent': event.eventName,
      'eventProperties': event.properties,
    });
  }

  Future<void> _startNewSession() async {
    _currentSessionId = _generateSessionId();
    _sessionStartTime = DateTime.now();
    _sessionEventCounts.clear();

    await trackEvent('session_start', {
      'sessionId': _currentSessionId,
      'timestamp': _sessionStartTime!.toIso8601String(),
    });
  }

  void _endCurrentSession() {
    if (_currentSessionId != null && _sessionStartTime != null) {
      final sessionDuration = DateTime.now().difference(_sessionStartTime!);

      trackEvent('session_end', {
        'sessionId': _currentSessionId,
        'duration': sessionDuration.inMilliseconds,
        'eventCount': _sessionEventCounts.values.fold<int>(0, (a, b) => a + b),
      });

      _currentSessionId = null;
      _sessionStartTime = null;
    }
  }

  void _startProcessingTimers() {
    _processingTimer?.cancel();
    _processingTimer = Timer.periodic(_batchInterval, (_) {
      _processEventBatch();
    });
  }

  Future<void> _processEventBatch() async {
    if (_isProcessingEvents || _eventQueue.isEmpty || !_isOnline) return;

    _isProcessingEvents = true;

    try {
      final batch = _eventQueue.take(_batchSize).toList();
      _eventQueue.removeRange(0, math.min(_batchSize, _eventQueue.length));

      // In a real implementation, these events would be sent to an analytics service
      for (final event in batch) {
        await _processAnalyticsEvent(event);
      }
    } finally {
      _isProcessingEvents = false;
    }
  }

  Future<void> _processAnalyticsEvent(AnalyticsEvent event) async {
    // This would typically send the event to an external analytics service
    // For now, we'll just store it locally for testing
  }

  Future<UserBehaviorMetrics> _calculateBehaviorMetrics(String userId) async {
    // In a real implementation, this would query the database
    // For now, returning mock data
    final random = math.Random();

    return UserBehaviorMetrics(
      userId: userId,
      sessionsCount: random.nextInt(100) + 1,
      totalTimeSpent: Duration(hours: random.nextInt(100) + 10),
      averageSessionDuration: Duration(minutes: random.nextInt(60) + 5),
      totalEvents: random.nextInt(1000) + 100,
      lastActiveAt: DateTime.now().subtract(
        Duration(hours: random.nextInt(48)),
      ),
      eventCounts: {
        'achievement_unlocked': random.nextInt(50),
        'points_earned': random.nextInt(200),
        'game_completed': random.nextInt(100),
        'social_interaction': random.nextInt(75),
      },
    );
  }

  Future<EngagementMetrics> _calculateEngagementMetrics(String userId) async {
    // In a real implementation, this would calculate engagement based on user activity
    final random = math.Random();

    return EngagementMetrics(
      userId: userId,
      engagementScore: random.nextDouble() * 100,
      dailyActiveStreak: random.nextInt(30),
      weeklyActiveDays: random.nextInt(7),
      monthlyActiveDays: random.nextInt(30),
      featureUsage: {
        'achievements': random.nextDouble(),
        'leaderboard': random.nextDouble(),
        'social': random.nextDouble(),
        'games': random.nextDouble(),
      },
      actionCounts: {
        'app_opens': random.nextInt(100),
        'feature_uses': random.nextInt(500),
        'social_actions': random.nextInt(200),
      },
      calculatedAt: DateTime.now(),
    );
  }

  String _assignABTestVariant(String testId, String userId) {
    // Simple hash-based assignment for consistency
    final hash = userId.hashCode + testId.hashCode;
    final variants = ['A', 'B', 'C'];
    final variant = variants[hash.abs() % variants.length];

    // Store the assignment
    final testData = ABTestData(
      testId: testId,
      userId: userId,
      variant: variant,
      assignedAt: DateTime.now(),
      testConfig: {},
      goalEvents: ['achievement_unlocked', 'tier_upgrade'],
    );

    _activeTests[userId] = (_activeTests[userId] ?? [])..add(testData);

    // Track assignment
    trackEvent('ab_test_assigned', {'testId': testId, 'variant': variant});

    return variant;
  }

  Future<Map<String, dynamic>> _generateReportData(
    ReportType type,
    DateTime periodStart,
    DateTime periodEnd,
    Map<String, dynamic>? filters,
  ) async {
    // In a real implementation, this would query the database and generate comprehensive reports
    final random = math.Random();

    switch (type) {
      case ReportType.achievements:
        return {
          'totalAchievementsUnlocked': random.nextInt(1000),
          'uniqueUsersWithAchievements': random.nextInt(500),
          'averageAchievementsPerUser': random.nextDouble() * 10,
          'topAchievements': [
            {'name': 'First Game', 'count': random.nextInt(100)},
            {'name': 'Social Butterfly', 'count': random.nextInt(75)},
            {'name': 'Point Master', 'count': random.nextInt(50)},
          ],
        };
      case ReportType.engagement:
        return {
          'averageEngagementScore': random.nextDouble() * 100,
          'dailyActiveUsers': random.nextInt(1000),
          'weeklyActiveUsers': random.nextInt(5000),
          'monthlyActiveUsers': random.nextInt(20000),
          'averageSessionDuration': random.nextInt(30) + 5,
          'retentionRate': random.nextDouble() * 0.8 + 0.2,
        };
      case ReportType.behavior:
        return {
          'totalSessions': random.nextInt(10000),
          'averageSessionsPerUser': random.nextDouble() * 10,
          'topEvents': [
            {'event': 'game_completed', 'count': random.nextInt(5000)},
            {'event': 'achievement_unlocked', 'count': random.nextInt(2000)},
            {'event': 'points_earned', 'count': random.nextInt(8000)},
          ],
        };
      case ReportType.conversion:
        return {
          'conversionRate': random.nextDouble() * 0.3,
          'totalConversions': random.nextInt(500),
          'averageTimeToConversion': random.nextInt(24) + 1,
          'funnelPerformance': {
            'step1': random.nextDouble() * 100,
            'step2': random.nextDouble() * 80,
            'step3': random.nextDouble() * 60,
          },
        };
      case ReportType.retention:
        return {
          'day1Retention': random.nextDouble() * 0.8,
          'day7Retention': random.nextDouble() * 0.6,
          'day30Retention': random.nextDouble() * 0.4,
          'cohortAnalysis': {
            'week1': random.nextDouble() * 100,
            'week2': random.nextDouble() * 80,
            'week3': random.nextDouble() * 60,
            'week4': random.nextDouble() * 40,
          },
        };
      case ReportType.custom:
      default:
        return {
          'customMetric1': random.nextInt(1000),
          'customMetric2': random.nextDouble() * 100,
          'customData': 'Sample custom report data',
        };
    }
  }

  Future<void> _setupABTests() async {
    // Setup predefined A/B tests
    // In a real implementation, this would load from configuration
  }

  Future<void> _setupConversionFunnels() async {
    // Setup predefined conversion funnels
    _conversionFunnels['onboarding'] = ConversionFunnel(
      funnelId: 'onboarding',
      name: 'User Onboarding',
      steps: [
        const FunnelStep(
          stepId: 'signup',
          stepName: 'Sign Up',
          requiredEvents: ['user_signup'],
        ),
        const FunnelStep(
          stepId: 'first_game',
          stepName: 'First Game',
          requiredEvents: ['game_completed'],
          maxTimeToNext: Duration(days: 1),
        ),
        const FunnelStep(
          stepId: 'first_achievement',
          stepName: 'First Achievement',
          requiredEvents: ['achievement_unlocked'],
          maxTimeToNext: Duration(days: 7),
        ),
      ],
      createdAt: DateTime.now(),
    );
  }

  Future<void> _loadOfflineQueue() async {
    try {
      final queueData = _prefs?.getString(
        'analytics_offline_queue_$_currentUserId',
      );
      if (queueData != null) {
        final List<dynamic> queueList = jsonDecode(queueData);
        _offlineQueue.addAll(
          queueList.map((data) => AnalyticsEvent.fromMap(data)).toList(),
        );
      }
    } catch (e) {}
  }

  Future<void> _saveOfflineQueue() async {
    try {
      final queueData = _offlineQueue.map((event) => event.toMap()).toList();
      await _prefs?.setString(
        'analytics_offline_queue_$_currentUserId',
        jsonEncode(queueData),
      );
    } catch (e) {}
  }

  Future<void> _syncOfflineQueue() async {
    if (_offlineQueue.isEmpty) return;

    try {
      final eventsToSync = List<AnalyticsEvent>.from(_offlineQueue);
      _offlineQueue.clear();

      for (final event in eventsToSync) {
        _eventQueue.add(event);
      }

      await _saveOfflineQueue();
    } catch (e) {}
  }

  Future<void> _loadCachedData() async {
    // Load cached metrics if available
    _lastMetricsUpdate = DateTime.now().subtract(const Duration(hours: 1));
  }

  bool _isCacheValid() {
    return _lastMetricsUpdate != null &&
        DateTime.now().difference(_lastMetricsUpdate!) <
            const Duration(minutes: 30);
  }

  Map<String, dynamic> _buildEventContext() {
    return {
      'sessionId': _currentSessionId,
      'sessionDuration': _sessionStartTime != null
          ? DateTime.now().difference(_sessionStartTime!).inMilliseconds
          : 0,
      'platform': 'mobile',
      'appVersion': '1.0.5',
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  String _generateEventId() {
    return '${DateTime.now().millisecondsSinceEpoch}_${math.Random().nextInt(10000)}';
  }

  String _generateSessionId() {
    return 'session_${DateTime.now().millisecondsSinceEpoch}_$_currentUserId';
  }

  String _generateReportId() {
    return 'report_${DateTime.now().millisecondsSinceEpoch}_${math.Random().nextInt(1000)}';
  }

  String _getReportName(ReportType type) {
    switch (type) {
      case ReportType.achievements:
        return 'Achievement Analytics Report';
      case ReportType.engagement:
        return 'User Engagement Report';
      case ReportType.behavior:
        return 'User Behavior Report';
      case ReportType.conversion:
        return 'Conversion Analytics Report';
      case ReportType.retention:
        return 'User Retention Report';
      case ReportType.custom:
        return 'Custom Analytics Report';
    }
  }
}
