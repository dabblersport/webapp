/// Feature flags for MVP launch
///
/// This file controls which features are gated in the app. KAN-32 removed 98
/// flags that nothing in the codebase read — a flag that gates no code is not
/// a feature, it's a promise nobody can verify. Every flag below is read by
/// at least one call site; see the file history / KAN-32 for the removed list.
class FeatureFlags {
  // ============================================================================
  // LIVE FEATURE GATES
  // ============================================================================

  /// Games & Matches
  static const bool enableGameBrowsing = true;

  /// Central MVP feature flags (UI gating only; do not delete code).
  static const bool socialFeed = true;
  // KAN-45: direct messaging / chat is not wired up — the socialChat and
  // socialMessages routes only reach a "Coming Soon" placeholder. Keep this
  // false until a real chat screen backs those routes.
  static const bool messaging = false;
  static const bool notifications = true;

  // Gates the 3-tier "Early Bird" check-in surface only (rewards tab route,
  // profile check-in widget, check-in modal). There is no broader rewards
  // system (points/badges/tiers/leaderboard) behind this flag — none exists
  // in the app, so there is nothing wider for it to toggle. The name says
  // what it gates: the check-in surface, and only that.
  static const bool enableEarlyBirdCheckIn = false;

  // KAN-52/KAN-103/P-029: PDPL data export is real legal scope, not a
  // product descope — the PO ruled it must be built, not waived. But
  // "built" means all data categories: several tables it depends on are
  // genuinely missing from the schema and are their own future sprint.
  // Until then, silently omitting categories from a PDPL export is exactly
  // the advertised-affordance-that-does-nothing pattern this flag family
  // exists to hide (same rule as `messaging` above). Keep false until the
  // export is actually complete. Gates the Settings export entry point in
  // account_management_screen.dart.
  static const bool enableDataExport = false;

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

  /// Payments & Bookings
  static const bool enablePayments = false;

  /// Community tab (RealFriendsScreen) in the compact mobile bottom-nav pill.
  /// The pill redesign (KAN-41 audit finding, 2223e77) only has room for two
  /// segmented groups + one icon slot, so Community was left reachable via
  /// the desktop side-nav only. Flip this on once the mobile nav has a slot
  /// for it again (see KAN-85).
  static const bool enableCommunityMobileNav = false;

  // ============================================================================
  // ANALYTICS-ONLY FLAGS
  // ============================================================================
  // KAN-32 judgment call: these 5 are read only by the flags_snapshot
  // analytics event in lib/main.dart:78-93. Unlike the deleted 98, that read
  // has a real consequence — AnalyticsService.trackEvent forwards to the
  // live `rpc_track_event` RPC, which writes into the `analytics_events`
  // table (verified 2026-08-29/31; it is NOT the no-op the original ticket
  // description assumed). Deleting these would silently drop real product
  // telemetry dimensions, so they are kept rather than removed.
  static const bool multiSport = true;
  static const bool organiserProfile = true;
  static const bool squads = true;
  static const bool venuesBooking = true; // venues remain read-only
  static const bool enableBookingFlow = true;

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
  // UTILITY METHODS
  // ============================================================================

  /// Get all enabled feature names (for analytics/debugging)
  static List<String> getEnabledFeatures() {
    return [
      if (enableGameBrowsing) 'game_browsing',
      if (enablePlayerGameCreation) 'player_game_creation',
      if (enableOrganiserGameCreation) 'organiser_game_creation',
      if (socialFeed) 'social_feed',
      if (messaging) 'messaging',
      if (notifications) 'notifications',
      if (enablePayments) 'payments',
      if (enableEarlyBirdCheckIn) 'rewards',
    ];
  }

  /// Get feature flag value by name (for dynamic checking)
  static bool getFeatureFlag(String featureName) {
    switch (featureName) {
      case 'game_browsing':
        return enableGameBrowsing;
      case 'player_game_creation':
        return enablePlayerGameCreation;
      case 'organiser_game_creation':
        return enableOrganiserGameCreation;
      case 'social_feed':
        return socialFeed;
      case 'messaging':
        return messaging;
      case 'notifications':
        return notifications;
      case 'payments':
        return enablePayments;
      case 'rewards':
        return enableEarlyBirdCheckIn;
      default:
        return false;
    }
  }

  /// MVP readiness check
  static bool isMvpReady() {
    return enableGameBrowsing;
  }

  /// Get MVP version identifier
  static String getMvpVersion() {
    return 'MVP-1.0.0';
  }

  /// Get feature rollout phase
  static String getPhase() {
    if (!isMvpReady()) return 'pre-mvp';
    if (!socialFeed) return 'mvp';
    if (!enablePayments) return 'post-mvp-social';
    return 'full-features';
  }
}
