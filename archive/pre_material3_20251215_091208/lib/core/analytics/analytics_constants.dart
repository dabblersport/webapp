/// Analytics configuration and constants
class AnalyticsConfig {
  // Enable/disable analytics in debug mode
  static const bool enableInDebug = true;

  // Sample rate for performance metrics (0.0 to 1.0)
  static const double performanceSampleRate = 0.1;

  // Batch size for event uploads
  static const int eventBatchSize = 50;

  // Maximum events to store locally
  static const int maxLocalEvents = 1000;

  // Event upload interval in seconds
  static const int uploadIntervalSeconds = 60;

  // Session timeout in minutes
  static const int sessionTimeoutMinutes = 30;
}

/// Dimension names for custom dimensions
class AnalyticsDimensions {
  static const String sportType = 'sport_type';
  static const String userSkillLevel = 'user_skill_level';
  static const String gameType = 'game_type';
  static const String venueType = 'venue_type';
  static const String paymentMethod = 'payment_method';
  static const String platform = 'platform';
  static const String appVersion = 'app_version';
  static const String deviceType = 'device_type';
  static const String connectionType = 'connection_type';
  static const String userTier = 'user_tier';
}

/// Metrics names for custom metrics
class AnalyticsMetrics {
  static const String gameCreationTime = 'game_creation_time';
  static const String searchResponseTime = 'search_response_time';
  static const String checkInTime = 'checkin_time';
  static const String gameJoinTime = 'game_join_time';
  static const String pageLoadTime = 'page_load_time';
  static const String apiCallDuration = 'api_call_duration';
  static const String imageLoadTime = 'image_load_time';
  static const String memoryUsage = 'memory_usage';
  static const String batteryLevel = 'battery_level';
  static const String networkLatency = 'network_latency';
}

/// Funnel step definitions
class AnalyticsFunnels {
  // Game creation funnel
  static const List<String> gameCreationFunnel = [
    'funnel_game_creation_start',
    'funnel_sport_selected',
    'funnel_venue_selected',
    'funnel_time_selected',
    'funnel_players_configured',
    'funnel_price_set',
    'funnel_game_created',
  ];

  // Game joining funnel
  static const List<String> gameJoinFunnel = [
    'funnel_game_viewed',
    'funnel_join_clicked',
    'funnel_payment_started',
    'funnel_payment_completed',
    'funnel_game_joined',
  ];

  // Search funnel
  static const List<String> searchFunnel = [
    'funnel_search_initiated',
    'funnel_filters_applied',
    'funnel_results_viewed',
    'funnel_result_clicked',
    'funnel_game_viewed_from_search',
  ];

  // Check-in funnel
  static const List<String> checkInFunnel = [
    'funnel_checkin_started',
    'funnel_location_verified',
    'funnel_qr_scanned',
    'funnel_checkin_completed',
  ];
}

/// Cohort definitions
class AnalyticsCohorts {
  static const String newUsers = 'new_users';
  static const String returningUsers = 'returning_users';
  static const String activeGameCreators = 'active_game_creators';
  static const String frequentJoiners = 'frequent_joiners';
  static const String premiumUsers = 'premium_users';
  static const String locationBasedUsers = 'location_based_users';
  static const String sportSpecificUsers = 'sport_specific_users';
  static const String highEngagementUsers = 'high_engagement_users';
}

/// A/B Test definitions
class AnalyticsExperiments {
  static const String gameCreationFlow = 'game_creation_flow_v2';
  static const String searchInterface = 'search_interface_redesign';
  static const String checkInMethods = 'checkin_methods_comparison';
  static const String pricingDisplay = 'pricing_display_format';
  static const String recommendationAlgorithm = 'recommendation_algorithm_v3';
  static const String onboardingFlow = 'onboarding_flow_simplified';
  static const String notificationTiming = 'notification_timing_optimization';
}

/// Goals and conversions
class AnalyticsGoals {
  // Primary goals
  static const String gameCreated = 'goal_game_created';
  static const String gameJoined = 'goal_game_joined';
  static const String gameCompleted = 'goal_game_completed';
  static const String userRetained = 'goal_user_retained';

  // Secondary goals
  static const String profileCompleted = 'goal_profile_completed';
  static const String friendAdded = 'goal_friend_added';
  static const String venueReviewed = 'goal_venue_reviewed';
  static const String gameShared = 'goal_game_shared';
  static const String premiumUpgrade = 'goal_premium_upgrade';

  // Engagement goals
  static const String dailyActiveUser = 'goal_daily_active_user';
  static const String weeklyActiveUser = 'goal_weekly_active_user';
  static const String monthlyActiveUser = 'goal_monthly_active_user';
}

/// Event parameters
class AnalyticsParameters {
  // Common parameters
  static const String timestamp = 'timestamp';
  static const String sessionId = 'session_id';
  static const String userId = 'user_id';
  static const String deviceId = 'device_id';

  // Game parameters
  static const String gameId = 'game_id';
  static const String sportType = 'sport_type';
  static const String venueId = 'venue_id';
  static const String playerCount = 'player_count';
  static const String gamePrice = 'game_price';
  static const String gameDuration = 'game_duration';
  static const String gameDate = 'game_date';
  static const String gameTime = 'game_time';

  // User parameters
  static const String userAge = 'user_age';
  static const String userGender = 'user_gender';
  static const String userLocation = 'user_location';
  static const String userSkillLevel = 'user_skill_level';
  static const String userTier = 'user_tier';
  static const String accountAge = 'account_age';

  // Search parameters
  static const String searchQuery = 'search_query';
  static const String searchFilters = 'search_filters';
  static const String resultsCount = 'results_count';
  static const String searchLatency = 'search_latency';

  // Performance parameters
  static const String loadTime = 'load_time';
  static const String responseTime = 'response_time';
  static const String errorCode = 'error_code';
  static const String errorMessage = 'error_message';

  // Location parameters
  static const String latitude = 'latitude';
  static const String longitude = 'longitude';
  static const String locationAccuracy = 'location_accuracy';
  static const String distanceKm = 'distance_km';

  // Device parameters
  static const String platform = 'platform';
  static const String appVersion = 'app_version';
  static const String deviceModel = 'device_model';
  static const String osVersion = 'os_version';
  static const String screenSize = 'screen_size';
  static const String connectionType = 'connection_type';
  static const String batteryLevel = 'battery_level';
}

/// Screen names
class AnalyticsScreens {
  // Main screens
  static const String home = 'home';
  static const String explore = 'explore';
  static const String myGames = 'my_games';
  static const String profile = 'profile';

  // Game screens
  static const String gameDetails = 'game_details';
  static const String gameCreation = 'game_creation';
  static const String gameSearch = 'game_search';
  static const String gameCheckIn = 'game_checkin';

  // User screens
  static const String login = 'login';
  static const String signup = 'signup';
  static const String onboarding = 'onboarding';
  static const String settings = 'settings';

  // Venue screens
  static const String venueDetails = 'venue_details';
  static const String venueList = 'venue_list';
  static const String venueMap = 'venue_map';

  // Social screens
  static const String friends = 'friends';
  static const String messages = 'messages';
  static const String notifications = 'notifications';

  // Support screens
  static const String help = 'help';
  static const String feedback = 'feedback';
  static const String about = 'about';
}

/// Custom event categories
class AnalyticsCategories {
  static const String user = 'user';
  static const String game = 'game';
  static const String search = 'search';
  static const String venue = 'venue';
  static const String payment = 'payment';
  static const String social = 'social';
  static const String notification = 'notification';
  static const String performance = 'performance';
  static const String error = 'error';
  static const String engagement = 'engagement';
  static const String conversion = 'conversion';
}

/// Event priorities (for batching and upload optimization)
enum AnalyticsEventPriority {
  low, // Background events, can be delayed
  medium, // Standard user interactions
  high, // Important business events
  critical, // Errors and critical events that should be sent immediately
}

/// Analytics event model
class AnalyticsEvent {
  final String name;
  final Map<String, dynamic> parameters;
  final AnalyticsEventPriority priority;
  final DateTime timestamp;
  final String? sessionId;
  final String? userId;

  AnalyticsEvent({
    required this.name,
    required this.parameters,
    this.priority = AnalyticsEventPriority.medium,
    DateTime? timestamp,
    this.sessionId,
    this.userId,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'parameters': parameters,
      'priority': priority.name,
      'timestamp': timestamp.toIso8601String(),
      'session_id': sessionId,
      'user_id': userId,
    };
  }

  factory AnalyticsEvent.fromJson(Map<String, dynamic> json) {
    return AnalyticsEvent(
      name: json['name'],
      parameters: Map<String, dynamic>.from(json['parameters']),
      priority: AnalyticsEventPriority.values.byName(json['priority']),
      timestamp: DateTime.parse(json['timestamp']),
      sessionId: json['session_id'],
      userId: json['user_id'],
    );
  }
}

/// Session model
class AnalyticsSession {
  final String sessionId;
  final DateTime startTime;
  final String? userId;
  final Map<String, dynamic> properties;
  DateTime lastActivityTime;

  AnalyticsSession({
    required this.sessionId,
    required this.startTime,
    this.userId,
    Map<String, dynamic>? properties,
  }) : properties = properties ?? {},
       lastActivityTime = startTime;

  bool get isExpired {
    final now = DateTime.now();
    final difference = now.difference(lastActivityTime);
    return difference.inMinutes > AnalyticsConfig.sessionTimeoutMinutes;
  }

  void updateActivity() {
    lastActivityTime = DateTime.now();
  }

  Duration get duration {
    return lastActivityTime.difference(startTime);
  }

  Map<String, dynamic> toJson() {
    return {
      'session_id': sessionId,
      'start_time': startTime.toIso8601String(),
      'last_activity_time': lastActivityTime.toIso8601String(),
      'user_id': userId,
      'properties': properties,
      'duration_seconds': duration.inSeconds,
    };
  }
}
