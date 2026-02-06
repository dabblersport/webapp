/// Route paths used throughout the app
class RoutePaths {
  // Deep Link Configuration
  static const String deepLinkPrefix = 'dabbler://app';

  // Landing & Authentication
  static const String landing = '/landing';
  static const String phoneInput = '/phone_input';
  static const String emailInput = '/email_input';
  static const String otpVerification = '/otp_verification';
  static const String enterPassword = '/enter-password';
  static const String forgotPassword = '/forgot-password';
  static const String resetPassword = '/reset-password';
  static const String register = '/register';
  static const String createUserInfo = '/create-user-info';
  static const String sportsSelection = '/sports-selection';
  static const String intentSelection = '/intent-selection';
  static const String setPassword = '/set-password';
  static const String setUsername = '/set-username';
  static const String welcome = '/welcome';
  static const String emailVerification = '/email-verification';

  // Onboarding Routes
  static const String onboardingWelcome = '/onboarding-welcome';
  static const String onboardingBasicInfo = '/onboarding-basic-info';
  static const String onboardingSports = '/onboarding-sports';
  static const String onboardingPreferences = '/onboarding-preferences';
  static const String onboardingPrivacy = '/onboarding-privacy';
  static const String onboardingCompletion = '/onboarding-completion';

  // Main App
  static const String home = '/home';
  static const String profile = '/profile';
  static const String games = '/games';
  static const String social = '/social';
  static const String sports = '/sports';
  static const String bookings = '/bookings';
  static const String activities = '/activities';
  static const String notifications = '/notifications';
  static const String support = '/support';
  static const String loyalty = '/loyalty';
  static const String designSystemDemo = '/design-system-demo';

  // Rewards & Leaderboard
  static const String rewards = '/rewards';
  static const String leaderboard = '/rewards/leaderboard';

  // Game Creation Routes
  static const String createGame = '/create-game';
  static const String createGameBasicInfo = '/create-game-basic-info';
  static const String createGameVenueSelection = '/create-game-venue-selection';
  static const String createGameDateTime = '/create-game-date-time';
  static const String createGamePlayerSettings = '/create-game-player-settings';
  static const String createGamePricing = '/create-game-pricing';
  static const String createGameAdditionalDetails =
      '/create-game-additional-details';
  static const String createGameReview = '/create-game-review';

  // Social Routes
  static const String socialFeed = '/social-feed';
  static const String socialPost = '/social-post';
  static const String addPost = '/add-post';
  static const String socialPostDetail = '/social-post-detail';
  static const String userProfile = '/user-profile';
  static const String socialProfileDetail = '/social-profile-detail';
  static const String socialChat = '/social-chat';
  static const String socialChatDetail = '/social-chat-detail';
  static const String socialChatList = '/social-chat-list';
  static const String socialMessages = '/social-messages';
  static const String socialFriends = '/social-friends';
  static const String socialNotifications = '/social-notifications';
  static const String socialSearch = '/social-search';
  static const String socialCreatePost = '/social-create-post';
  static const String socialEditPost = '/social-edit-post';
  static const String socialAnalytics = '/social-analytics';

  // Social Onboarding Routes
  static const String socialOnboardingWelcome = '/social-onboarding-welcome';
  static const String socialOnboardingFriends = '/social-onboarding-friends';
  static const String socialOnboardingPrivacy = '/social-onboarding-privacy';
  static const String socialOnboardingNotifications =
      '/social-onboarding-notifications';
  static const String socialOnboardingComplete = '/social-onboarding-complete';

  // Admin Routes
  static const String adminModerationQueue = '/admin/moderation-queue';
  static const String adminSafetyOverview = '/admin/safety-overview';

  // Error Routes
  static const String error = '/error';
}

/// Route names for semantic navigation
class RouteNames {
  // Core Routes
  static const String home = 'home';
  static const String error = 'error';

  // Auth Routes
  static const String login = 'login';
  static const String register = 'register';
  static const String forgotPassword = 'forgot_password';
  static const String enterPassword = 'enter_password';
  static const String createUserInfo = 'create_user_information';
  static const String setPassword = 'set_password';
  static const String welcome = 'welcome';
  static const String resetPassword = 'reset_password';

  // Profile Onboarding Routes
  static const String onboardingWelcome = 'onboarding-welcome';
  static const String onboardingBasicInfo = 'onboarding-basic-info';
  static const String onboardingSports = 'onboarding-sports';
  static const String onboardingPreferences = 'onboarding-preferences';
  static const String onboardingPrivacy = 'onboarding-privacy';
  static const String onboardingCompletion = 'onboarding-completion';

  // Feature Routes
  static const String profile = 'profile';
  static const String profileUser = 'profile-user';
  static const String profileEdit = 'profile-edit';
  static const String profileAvatar = 'profile-avatar';
  static const String profileStats = 'profile-stats';
  static const String profileEditPhoto = 'profile-edit-photo';
  static const String profileEditSports = 'profile-edit-sports';
  static const String settings = 'settings';
  static const String settingsPrivacy = 'settings-privacy';
  static const String settingsNotifications = 'settings-notifications';
  static const String settingsAccount = 'settings-account';
  static const String notifications = 'notifications';

  // Games Routes
  static const String games = 'games';
  static const String availableGames = 'available-games';
  static const String myGames = 'my-games';
  static const String gameHistory = 'game-history';
  static const String gameDetail = 'game-detail';
  static const String joinGame = 'join-game';
  static const String gameCheckin = 'game-checkin';
  static const String gameLobby = 'game-lobby';
  static const String liveGame = 'live-game';
  static const String postGame = 'post-game';

  // Game Creation Routes
  static const String createGame = 'create-game';
  static const String createGameBasicInfo = 'create-game-basic-info';
  static const String createGameVenueSelection = 'create-game-venue-selection';
  static const String createGameDateTime = 'create-game-date-time';
  static const String createGamePlayerSettings = 'create-game-player-settings';
  static const String createGamePricing = 'create-game-pricing';
  static const String createGameAdditionalDetails =
      'create-game-additional-details';
  static const String createGameReview = 'create-game-review';

  // Venue Routes
  static const String venuesList = 'venues-list';
  static const String venueDetail = 'venue-detail';

  // Social Routes
  static const String social = 'social';
  static const String socialFeed = 'social-feed';
  static const String socialPost = 'social-post';
  static const String socialPostDetail = 'social-post-detail';
  static const String userProfile = 'user-profile';
  static const String socialProfileDetail = 'social-profile-detail';
  static const String socialChat = 'social-chat';
  static const String socialChatDetail = 'social-chat-detail';
  static const String socialChatList = 'social-chat-list';
  static const String socialMessages = 'social-messages';
  static const String socialFriends = 'social-friends';
  static const String socialNotifications = 'social-notifications';
  static const String socialSearch = 'social-search';
  static const String socialCreatePost = 'social-create-post';
  static const String socialEditPost = 'social-edit-post';
  static const String socialAnalytics = 'social-analytics';

  // Main Navigation Routes
  static const String sports = 'sports';
  static const String activities = 'activities';

  // Rewards & Leaderboard
  static const String rewards = 'rewards';
  static const String leaderboard = 'leaderboard';

  // Main App Navigation
  static const String mainApp = 'main-app';

  // Social Onboarding Routes
  static const String socialOnboardingWelcome = 'social-onboarding-welcome';
  static const String socialOnboardingFriends = 'social-onboarding-friends';
  static const String socialOnboardingPrivacy = 'social-onboarding-privacy';
  static const String socialOnboardingNotifications =
      'social-onboarding-notifications';
  static const String socialOnboardingComplete = 'social-onboarding-complete';
}

/// Route parameters used in dynamic routes
class RouteParams {
  static const String errorMessage = 'errorMessage';
  static const String gameId = 'gameId';
  static const String venueId = 'venueId';
  static const String playerId = 'playerId';
  static const String inviteToken = 'inviteToken';
  static const String userId = 'userId';
  static const String itemId = 'itemId';
  static const String postId = 'postId';
  static const String conversationId = 'conversationId';
  static const String searchQuery = 'q';
  static const String searchType = 'type';
  static const String notificationId = 'notificationId';
}
