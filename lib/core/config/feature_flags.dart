/// Feature flags for MVP launch
///
/// This file controls which features are visible in the app.
/// Features set to `false` are hidden from UI but code remains intact
/// for future enablement.
///
/// MVP Strategy: Launch with core features, progressively enable advanced ones
class FeatureFlags {
  // ============================================================================
  // MVP CORE FEATURES (Enabled)
  // ============================================================================

  /// Authentication
  static const bool enablePhoneAuth = true;
  static const bool enableEmailAuth = true;
  static const bool enableGoogleAuth = true; // Future
  static const bool enableAppleAuth = true; // Future

  /// Profile Management
  static const bool enableBasicProfile = true;
  static const bool enableProfileEdit = true;
  static const bool enableAvatarUpload = true;
  static const bool enableBioEdit = true;
  static const bool enableLocationEdit = true;

  /// Games & Matches
  static const bool enableGameBrowsing = true;
  static const bool enableGameDetails = true;
  static const bool enableJoinGames = true;
  static const bool enableLeaveGames = true;
  static const bool enableMyGames = true;

  /// Ratings
  static const bool enablePlayerRatings = true;
  static const bool enableViewRatings = true;

  /// Statistics
  static const bool enableBasicStats = true;

  /// Settings
  static const bool enableThemeSettings = true;
  static const bool enableLanguageSettings = true;
  static const bool enableLogout = true;

  // ============================================================================
  // HIDDEN FEATURES (Future Release)
  // ============================================================================

  /// Central MVP feature flags (UI gating only; do not delete code).
  static const bool multiSport = true;
  static const bool organiserProfile = true;
  static const bool socialFeed = true; // NOW ENABLED FOR MVP
  static const bool messaging = true;
  static const bool notifications = true;
  static const bool squads = true;
  static const bool venuesBooking = true; // venues remain read-only
  static const bool enableRewards =
      false; // Early Bird check-in system disabled for now

  /// Game Creation Features (Split by profile type)
  static const bool enablePlayerGameCreation =
      true; // Players CANNOT create games in MVP
  static const bool enableOrganiserGameCreation =
      true; // Organisers can create organized games in MVP

  /// Game Joining Features (Split by profile type)
  static const bool enablePlayerGameJoining =
      true; // Players CAN join games in MVP
  static const bool enableOrganiserGameJoining =
      true; // Organisers CANNOT join games in MVP (they create/organize)

  /// Game Management
  static const bool enableGameEditing = true;
  static const bool enableGameDeletion = true;
  static const bool enableRecurringGames = true;
  static const bool enablePrivateGames = true;
  static const bool enableGameInvitations = true;
  static const bool enableGameWaitlist = true;
  static const bool enableGameChat = true;

  /// Profile Types
  static const bool enableOrganiserProfile = true; // NOW ENABLED FOR MVP
  static const bool enableMultiProfile = true;
  static const bool enableVerificationBadge = true;
  static const bool enableProfileCompletionPercent = true;

  /// Social Features
  static const bool enableSocialFeed = true; // NOW ENABLED FOR MVP
  static const bool enableCreatePost = true; // NOW ENABLED FOR MVP
  static const bool enableLikePost = true; // NOW ENABLED FOR MVP
  static const bool enableCommentPost = true; // NOW ENABLED FOR MVP
  static const bool enableSharePost = true; // NOW ENABLED FOR MVP
  static const bool enableFollowUsers = true; // NOW ENABLED FOR MVP
  static const bool enableFriendRequests = true; // NOW ENABLED FOR MVP
  static const bool enableFriendsList = true; // NOW ENABLED FOR MVP
  static const bool enableBlockUsers =
      true; // NOW ENABLED - Full blocking support
  static const bool enableReportContent =
      true; // NOW ENABLED - Content moderation
  static const bool enableCircleFeed = true;
  static const bool enableActivityFeed = true;

  /// Squads & Teams
  static const bool enableSquads = true;
  static const bool enableCreateSquad = true;
  static const bool enableJoinSquad = true;
  static const bool enableSquadChat = true;
  static const bool enableSquadInvites = true;
  static const bool enableSquadStats = true;

  /// Messaging
  static const bool enableDirectMessages = true;
  static const bool enableGroupChat = true;
  static const bool enableChatHistory = true;
  static const bool enableTypingIndicators = true;
  static const bool enableReadReceipts = true;

  /// Notifications
  static const bool enablePushNotifications = true;
  static const bool enableInAppNotifications = true;
  static const bool enableNotificationCenter = true;
  static const bool enableNotificationPreferences = true;

  /// Venues
  static const bool enableVenueSearch = true;
  static const bool enableNearbyVenues = true;
  static const bool enableVenueBooking = true;
  static const bool enableVenueRatings = true;
  static const bool enableVenuePhotos = true;

  /// Payments & Bookings
  static const bool enablePayments = true;
  static const bool enableWallet = true;
  static const bool enableTransactionHistory = true;
  static const bool enableBookingFlow = true;
  static const bool enableBookingHistory = true;

  /// Advanced Statistics
  static const bool enableDetailedStats = true;
  static const bool enableLeaderboards = true;
  static const bool enableAchievementBadges = true;
  static const bool enablePerformanceTrends = true;

  /// Bench Mode
  static const bool enableBenchMode = true; // Unique feature, post-MVP

  /// Discovery
  static const bool enableAdvancedSearch = true;
  static const bool enableFilters = true; // Basic filters only
  static const bool enableMapView = true;
  static const bool enableRecommendations = true;
  static const bool enableTrendingGames = true;

  /// Ratings Extended
  static const bool enableVenueRating = true;
  static const bool enableGameRating = true;
  static const bool enableRatingComments = true; // Stars only for MVP

  /// Moderation (Backend only, no UI)
  static const bool enableModerationUI = true; // Admin panel only
  static const bool enableUserReports = true;
  static const bool enableContentModeration = true;

  /// Advanced Features
  static const bool enableRealtimeSync = true; // Use polling for MVP
  static const bool enableOfflineMode = true;
  static const bool enableAnalytics = true;
  static const bool enableABTesting = true;

  // ============================================================================
  // SPORT CONFIGURATION
  // ============================================================================

  /// Sports available in MVP
  /// Three main sports: football, cricket, padel
  static const List<String> enabledSports = [
    'football',
    'cricket',
    'padel',
    'basketball',
    'tennis',
    'volleyball',
    'handball',
    'badminton',
    'table_tennis',
    'squash',
    'baseball',
    'rugby',
    'hockey',
  ];

  /// All sports (for future enablement)
  static const List<String> allSports = [
    'football',
    'cricket',
    'padel',
    'basketball',
    'tennis',
    'volleyball',
    'badminton',
    'table_tennis',
    'squash',
    'baseball',
    'rugby',
    'hockey',
  ];

  /// Check if a sport is enabled
  static bool isSportEnabled(String sport) {
    return enabledSports.contains(sport.toLowerCase());
  }

  /// Check if all sports should be available in interests
  /// For MVP, all sports are available as interests even if not main sports
  static bool isAllSportsInInterests = true;

  /// Get sports available for interests selection
  static List<String> getSportsForInterests() {
    return isAllSportsInInterests ? allSports : enabledSports;
  }

  // ============================================================================
  // LANGUAGE CONFIGURATION
  // ============================================================================

  /// Languages available in MVP
  /// Only English and Arabic for initial launch
  static const List<String> enabledLanguages = ['en', 'ar'];

  /// All supported languages (for future)
  static const List<String> allLanguages = [
    'en',
    'ar',
    'es',
    'fr',
    'de',
    'it',
    'pt',
    'ru',
    'zh',
    'ja',
    'ko',
    'hi',
    'bn',
    'pa',
    'te',
    'mr',
    'ta',
    'ur',
    'gu',
    'kn',
    'ml',
    'or',
    'as',
    'ne',
    'si',
    'my',
    'km',
    'lo',
    'th',
    'vi',
    'id',
  ];

  /// Check if a language is enabled
  static bool isLanguageEnabled(String languageCode) {
    return enabledLanguages.contains(languageCode.toLowerCase());
  }

  // ============================================================================
  // NAVIGATION CONFIGURATION
  // ============================================================================

  /// Bottom navigation tabs visibility
  static const bool showHomeTab = true;
  static const bool showSportsTab =
      true; // NOW ENABLED FOR MVP - Sports/Games Browsing
  static const bool showMyGamesTab = true;
  static const bool showSocialTab = true; // NOW ENABLED FOR MVP
  static const bool showSquadsTab = true;
  static const bool showProfileTab = true;
  static const bool showSettingsTab = true; // Or within profile

  /// Top bar features
  static const bool showNotificationBell = true;
  static const bool showMessagesIcon = true;
  static const bool showSearchIcon = true;

  // ============================================================================
  // PROFILE TYPE CONFIGURATION
  // ============================================================================

  /// Available profile types in MVP
  static const List<String> enabledProfileTypes = ['player', 'organiser'];

  /// All profile types
  static const List<String> allProfileTypes = ['player', 'organiser'];

  /// Check if profile type is enabled
  static bool isProfileTypeEnabled(String profileType) {
    return enabledProfileTypes.contains(profileType.toLowerCase());
  }

  // ============================================================================
  // GAME TYPE CONFIGURATION
  // ============================================================================

  /// Game types visible in MVP
  static const List<String> enabledGameTypes = [
    'pickup',
    'organized',
    'tournament',
  ];

  /// All game types
  static const List<String> allGameTypes = [
    'pickup',
    'organized',
    'tournament',
  ];

  /// Check if game type is enabled
  static bool isGameTypeEnabled(String gameType) {
    return enabledGameTypes.contains(gameType.toLowerCase());
  }

  // ============================================================================
  // PRIVACY CONFIGURATION
  // ============================================================================

  /// Privacy levels available in MVP
  /// Only public games for simplicity
  static const List<String> enabledPrivacyLevels = [
    'public',
    'private',
    'invite_only',
  ];

  /// All privacy levels
  static const List<String> allPrivacyLevels = [
    'public',
    'private',
    'invite_only',
  ];

  // ============================================================================
  // DEVELOPMENT & DEBUGGING
  // ============================================================================

  /// Enable debug features
  static const bool enableDebugMode = true;
  static const bool enableFeatureFlagOverride = true; // Allow runtime toggle
  static const bool showFeatureFlagIndicators = true; // Show "BETA" badges

  // ============================================================================
  // UTILITY METHODS
  // ============================================================================

  /// Get all enabled feature names (for analytics/debugging)
  static List<String> getEnabledFeatures() {
    return [
      if (enablePhoneAuth) 'phone_auth',
      if (enableEmailAuth) 'email_auth',
      if (enableGameBrowsing) 'game_browsing',
      if (enablePlayerGameCreation) 'player_game_creation',
      if (enableOrganiserGameCreation) 'organiser_game_creation',
      if (enableJoinGames) 'join_games',
      if (enablePlayerRatings) 'player_ratings',
      if (enableBasicStats) 'basic_stats',
      if (enableSocialFeed) 'social_feed',
      if (enableSquads) 'squads',
      if (enableDirectMessages) 'messaging',
      if (enablePushNotifications) 'notifications',
      if (enablePayments) 'payments',
      if (enableRewards) 'rewards',
      if (enableVenueBooking) 'venue_booking',
      if (enableBenchMode) 'bench_mode',
    ];
  }

  /// Get feature flag value by name (for dynamic checking)
  static bool getFeatureFlag(String featureName) {
    switch (featureName) {
      case 'phone_auth':
        return enablePhoneAuth;
      case 'email_auth':
        return enableEmailAuth;
      case 'game_browsing':
        return enableGameBrowsing;
      case 'player_game_creation':
        return enablePlayerGameCreation;
      case 'organiser_game_creation':
        return enableOrganiserGameCreation;
      case 'join_games':
        return enableJoinGames;
      case 'player_ratings':
        return enablePlayerRatings;
      case 'social_feed':
        return enableSocialFeed;
      case 'squads':
        return enableSquads;
      case 'messaging':
        return enableDirectMessages;
      case 'notifications':
        return enablePushNotifications;
      case 'payments':
        return enablePayments;
      case 'venue_booking':
        return enableVenueBooking;
      case 'rewards':
        return enableRewards;
      case 'bench_mode':
        return enableBenchMode;
      default:
        return false;
    }
  }

  /// MVP readiness check
  static bool isMvpReady() {
    return enablePhoneAuth &&
        enableEmailAuth &&
        enableGameBrowsing &&
        enableJoinGames &&
        enableMyGames &&
        enableBasicProfile;
  }

  /// Get MVP version identifier
  static String getMvpVersion() {
    return 'MVP-1.0.0';
  }

  /// Get feature rollout phase
  static String getPhase() {
    if (!isMvpReady()) return 'pre-mvp';
    if (!enableSocialFeed) return 'mvp';
    if (!enableSquads) return 'post-mvp-social';
    if (!enablePayments) return 'post-mvp-teams';
    return 'full-features';
  }
}
