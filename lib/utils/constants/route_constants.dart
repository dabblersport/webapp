/// Route paths used throughout the app
class RoutePaths {
  // Deep Link Configuration
  static const String deepLinkPrefix = 'dabbler://app';

  /// Public web origin for shareable universal links (game/venue/profile).
  /// The Flutter web app is deployed here, so the same host serves the
  /// .well-known association files AND renders the link in a browser when
  /// the native app isn't installed. On devices with the app, the OS opens
  /// /game/:id natively via the same redirect as dabbler://app/game/:id.
  static const String webLinkBase = 'https://app.dabbler.pro';
  static String gameLink(String gameId) => '$webLinkBase/game/$gameId';

  /// Store listings for the "get the app" banner on mobile web.
  /// Empty until the apps are published — the banner hides install buttons
  /// when these are empty.
  static const String appStoreUrl = '';
  static const String playStoreUrl = '';

  // ── Deep Link entry paths (top-level, redirect into the shell) ──
  // dabbler://app/game/:gameId  → /sports/games/:gameId
  // dabbler://app/create-game  → /create-game (already top-level, works directly)

  // Landing & Authentication
  static const String aboutTerms = '/about/terms';
  static const String aboutPrivacy = '/about/privacy';
  static const String landing = '/landing';
  static const String emailInput = '/email_input';
  static const String otpVerification = '/otp_verification';
  static const String enterPassword = '/enter-password';
  static const String forgotPassword = '/forgot-password';
  static const String resetPassword = '/reset-password';
  static const String register = '/register';
  static const String createUserInfo = '/create-user-info';
  static const String interestsSelection = '/interests-selection';
  static const String intentSelection = '/intent-selection';
  static const String setUsername = '/set-username';
  static const String authWelcome = '/auth-welcome';
  static const String welcome = '/welcome';
  static const String emailVerification = '/email-verification';

  // Onboarding Routes
  static const String onboardingWelcome = '/onboarding-welcome';
  static const String onboardingBasicInfo = '/onboarding-basic-info';
  static const String onboardingPersonaSelection =
      '/onboarding-persona-selection';
  static const String onboardingInterestsSelection =
      '/onboarding-interests-selection';
  static const String onboardingPrimarySport = '/onboarding-primary-sport';
  static const String profileSwitcher = '/profile-switcher';

  // Add Persona Flow (from Settings)
  static const String addPersonaInterests = '/add-persona/interests';
  static const String addPersonaPrimarySport = '/add-persona/primary-sport';
  static const String addPersonaUsername = '/add-persona/username';
  static const String addPersonaWelcome = '/add-persona/welcome';

  // Main App
  static const String home = '/home';
  static const String community = '/community';
  static const String venuesTab = '/sports/venues';
  static const String gamesTab = '/sports/games';
  static const String profile = '/profile';
  static const String sportProfile = '/profile/sport';
  static const String games = '/games';
  static const String social = '/social';
  static const String sportsExplore = '/sports-explore';
  static const String activities = '/activities';
  static const String notifications = '/notifications';

  // Organiser Venue Submissions
  static const String myVenueSubmissions = '/venue-submissions';
  static const String createVenueSubmission = '/venue-submissions/create';

  static String venueSubmissionDetail(String submissionId) =>
      '/venue-submissions/$submissionId';

  // Game & Venue detail paths (root-level, no shell)
  static String gameDetail(String gameId) => '/sports/games/$gameId';
  static String venueDetail(String venueId) => '/sports/venues/$venueId';

  // News detail (root-level, no shell)
  static String newsDetail(String newsId) => '/news/$newsId';

  // Rewards & Leaderboard
  static const String rewards = '/rewards';

  // Game Creation Routes
  static const String createGame = '/create-game';
  static const String editGame = '/edit-game/:gameId';
  static const String createGameBasicInfo = '/create-game-basic-info';

  // Social Routes
  static const String socialFeed = '/social-feed';
  static const String socialPostDetail = '/social-post-detail';
  static const String userProfile = '/user-profile';
  static const String socialChat = '/social-chat';
  static const String socialChatList = '/social-chat-list';
  static const String socialMessages = '/social-messages';
  static const String socialFriends = '/social-friends';
  static const String following = '/following';
  static const String followers = '/followers';
  static const String socialNotifications = '/social-notifications';
  static const String socialSearch = '/social-search';
  static const String hashtagFeed = '/hashtag';
  static const String socialCreatePost = '/social-create-post';
  static const String socialEditPost = '/social-edit-post';
  static const String socialAnalytics = '/social-analytics';
  static const String postComposer = '/post-composer';

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

  // Profile Onboarding Routes
  static const String onboardingWelcome = 'onboarding-welcome';
  static const String onboardingPersonaSelection =
      'onboarding-persona-selection';
  static const String onboardingInterestsSelection =
      'onboarding-interests-selection';
  static const String onboardingPrimarySport = 'onboarding-primary-sport';

  // Add Persona Flow Routes
  static const String addPersonaInterests = 'add-persona-interests';
  static const String addPersonaPrimarySport = 'add-persona-primary-sport';
  static const String addPersonaUsername = 'add-persona-username';
  static const String addPersonaWelcome = 'add-persona-welcome';

  // Feature Routes
  static const String profile = 'profile';
  static const String sportProfile = 'sport-profile';

  // Games Routes
  static const String gameDetail = 'game-detail';

  // Game Creation Routes
  static const String createGame = 'create-game';
  static const String editGame = 'edit-game';
  static const String createGameBasicInfo = 'create-game-basic-info';

  // Venue Routes
  static const String venueDetail = 'venue-detail';

  // News Routes
  static const String newsDetail = 'news-detail';

  // Organiser Venue Submissions
  static const String myVenueSubmissions = 'my-venue-submissions';
  static const String createVenueSubmission = 'create-venue-submission';
  static const String venueSubmissionDetail = 'venue-submission-detail';

  // Social Routes
  static const String social = 'social';
  static const String socialFeed = 'social-feed';
  static const String socialPostDetail = 'social-post-detail';
  static const String userProfile = 'user-profile';
  static const String socialChat = 'social-chat';
  static const String socialChatList = 'social-chat-list';
  static const String socialMessages = 'social-messages';
  static const String socialFriends = 'social-friends';
  static const String following = 'following';
  static const String followers = 'followers';
  static const String socialNotifications = 'social-notifications';
  static const String socialSearch = 'social-search';
  static const String hashtagFeed = 'hashtag-feed';
  static const String socialCreatePost = 'social-create-post';
  static const String socialEditPost = 'social-edit-post';
  static const String socialAnalytics = 'social-analytics';
  static const String postComposer = 'post-composer';

  // Main Navigation Routes
  static const String sports = 'sports';
  static const String community = 'community';
  static const String venuesTab = 'venues-tab';
  static const String gamesTab = 'games-tab';
  static const String activities = 'activities';

  // Rewards & Leaderboard
  static const String rewards = 'rewards';

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
  // Organiser Venue Submissions
  static const String submissionId = 'submissionId';
}
