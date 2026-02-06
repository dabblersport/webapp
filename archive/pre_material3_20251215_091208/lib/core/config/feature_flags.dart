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
  static const bool enableGoogleAuth = false; // Future
  static const bool enableAppleAuth = false; // Future

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
  static const bool multiSport = false;
  static const bool organiserProfile = false;
  static const bool socialFeed = true; // NOW ENABLED FOR MVP
  static const bool messaging = false;
  static const bool notifications = true;
  static const bool squads = false;
  static const bool venuesBooking = false; // venues remain read-only
  static const bool enableRewards = true; // Early Bird check-in system enabled

  /// Game Creation Features (Split by profile type)
  static const bool enablePlayerGameCreation =
      false; // Players CANNOT create games in MVP
  static const bool enableOrganiserGameCreation =
      true; // Organisers can create organized games in MVP

  /// Game Joining Features (Split by profile type)
  static const bool enablePlayerGameJoining =
      true; // Players CAN join games in MVP
  static const bool enableOrganiserGameJoining =
      false; // Organisers CANNOT join games in MVP (they create/organize)

  /// Game Management
  static const bool enableGameEditing = false;
  static const bool enableGameDeletion = false;
  static const bool enableRecurringGames = false;
  static const bool enablePrivateGames = false;
  static const bool enableGameInvitations = false;
  static const bool enableGameWaitlist = false;
  static const bool enableGameChat = false;

  /// Profile Types
  static const bool enableOrganiserProfile = true; // NOW ENABLED FOR MVP
  static const bool enableMultiProfile = false;
  static const bool enableVerificationBadge = false;
  static const bool enableProfileCompletionPercent = false;

  /// Social Features
  static const bool enableSocialFeed = true; // NOW ENABLED FOR MVP
  static const bool enableCreatePost = true; // NOW ENABLED FOR MVP
  static const bool enableLikePost = true; // NOW ENABLED FOR MVP
  static const bool enableCommentPost = true; // NOW ENABLED FOR MVP
  static const bool enableSharePost = true; // NOW ENABLED FOR MVP
  static const bool enableFollowUsers = true; // NOW ENABLED FOR MVP
  static const bool enableFriendRequests = true; // NOW ENABLED FOR MVP
  static const bool enableFriendsList = true; // NOW ENABLED FOR MVP
  static const bool enableBlockUsers = false;
  static const bool enableReportContent = false;
  static const bool enableCircleFeed = false;
  static const bool enableActivityFeed = false;

  /// Squads & Teams
  static const bool enableSquads = false;
  static const bool enableCreateSquad = false;
  static const bool enableJoinSquad = false;
  static const bool enableSquadChat = false;
  static const bool enableSquadInvites = false;
  static const bool enableSquadStats = false;

  /// Messaging
  static const bool enableDirectMessages = false;
  static const bool enableGroupChat = false;
  static const bool enableChatHistory = false;
  static const bool enableTypingIndicators = false;
  static const bool enableReadReceipts = false;

  /// Notifications
  static const bool enablePushNotifications = true;
  static const bool enableInAppNotifications = true;
  static const bool enableNotificationCenter = true;
  static const bool enableNotificationPreferences = true;

  /// Venues
  static const bool enableVenueSearch = false;
  static const bool enableNearbyVenues = false;
  static const bool enableVenueBooking = false;
  static const bool enableVenueRatings = false;
  static const bool enableVenuePhotos = false;

  /// Payments & Bookings
  static const bool enablePayments = false;
  static const bool enableWallet = false;
  static const bool enableTransactionHistory = false;
  static const bool enableBookingFlow = false;
  static const bool enableBookingHistory = false;

  /// Advanced Statistics
  static const bool enableDetailedStats = false;
  static const bool enableLeaderboards = false;
  static const bool enableAchievementBadges = false;
  static const bool enablePerformanceTrends = false;

  /// Bench Mode
  static const bool enableBenchMode = false; // Unique feature, post-MVP

  /// Discovery
  static const bool enableAdvancedSearch = false;
  static const bool enableFilters = true; // Basic filters only
  static const bool enableMapView = false;
  static const bool enableRecommendations = false;
  static const bool enableTrendingGames = false;

  /// Ratings Extended
  static const bool enableVenueRating = false;
  static const bool enableGameRating = false;
  static const bool enableRatingComments = false; // Stars only for MVP

  /// Moderation (Backend only, no UI)
  static const bool enableModerationUI = false; // Admin panel only
  static const bool enableUserReports = false;
  static const bool enableContentModeration = false;

  /// Advanced Features
  static const bool enableRealtimeSync = false; // Use polling for MVP
  static const bool enableOfflineMode = false;
  static const bool enableAnalytics = false;
  static const bool enableABTesting = false;

  // ============================================================================
  // SPORT CONFIGURATION
  // ============================================================================

  /// Sports available in MVP
  /// Three main sports: football, cricket, paddle
  static const List<String> enabledSports = ['football', 'cricket', 'paddle'];

  /// All sports (for future enablement)
  static const List<String> allSports = [
    'football',
    'cricket',
    'paddle',
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
  static const bool showSquadsTab = false;
  static const bool showProfileTab = true;
  static const bool showSettingsTab = true; // Or within profile

  /// Top bar features
  static const bool showNotificationBell = true;
  static const bool showMessagesIcon = false;
  static const bool showSearchIcon = false;

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
  static const List<String> enabledGameTypes = ['pickup', 'organized'];

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
  static const List<String> enabledPrivacyLevels = ['public'];

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
  static const bool enableDebugMode = false;
  static const bool enableFeatureFlagOverride = false; // Allow runtime toggle
  static const bool showFeatureFlagIndicators = false; // Show "BETA" badges

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
