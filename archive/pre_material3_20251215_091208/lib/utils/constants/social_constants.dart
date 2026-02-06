/// Social feature constants for the Dabbler app
/// Defines limits, constraints, and configuration values for all social features
library;

/// Social constants class
class SocialConstants {
  // Post constants
  static const int maxPostLength = 1000;
  static const int maxPostMediaCount = 10;
  static const int maxPostMediaSizeMB = 50;
  static const int maxUrlsPerPost = 3;
  static const int maxMentionsPerPost = 10;
  static const int maxHashtagsPerPost = 10;
  static const int maxEmojisPerPost = 50;

  static const List<String> allowedMediaTypes = [
    'image/jpeg',
    'image/png',
    'image/webp',
    'video/mp4',
  ];

  // Comment constants
  static const int maxCommentLength = 500;
  static const int maxCommentDepth = 3; // For nested replies
  static const int commentsPerPage = 20;

  // Friend constants
  static const int maxFriends = 5000;
  static const int maxPendingRequests = 100;
  static const int friendSuggestionsPerPage = 20;
  static const Duration friendRequestTimeout = Duration(days: 30);

  // Chat constants
  static const int maxMessageLength = 5000;
  static const int maxGroupMembers = 50;
  static const int messagesPerPage = 50;
  static const int maxMediaPerMessage = 10;

  // Notification constants
  static const int maxNotifications = 1000;
  static const Duration notificationRetention = Duration(days: 90);
  static const int notificationsPerPage = 25;

  // Real-time constants
  static const Duration typingIndicatorTimeout = Duration(seconds: 3);
  static const Duration onlineStatusTimeout = Duration(minutes: 5);
  static const int reconnectMaxAttempts = 5;

  // Engagement constants
  static const List<String> reactionTypes = [
    'like',
    'love',
    'celebrate',
    'support',
    'funny',
    'wow',
  ];

  // Search and pagination constants
  static const int defaultPageSize = 20;
  static const int maxSearchResults = 100;
  static const Duration searchDebounceDelay = Duration(milliseconds: 500);
  static const Duration cacheExpiry = Duration(minutes: 10);

  // Media upload constants
  static const int maxImageWidth = 2048;
  static const int maxImageHeight = 2048;
  static const int imageQuality = 85; // JPEG quality (0-100)
  static const Duration maxVideoLength = Duration(minutes: 5);

  // Rate limiting constants
  static const int maxPostsPerHour = 20;
  static const int maxCommentsPerMinute = 10;
  static const int maxFriendRequestsPerDay = 50;
  static const int maxMessagesPerMinute = 30;

  // UI constants
  static const Duration animationDuration = Duration(milliseconds: 300);
  static const Duration longAnimationDuration = Duration(milliseconds: 500);
  static const double defaultBorderRadius = 12.0;
  static const double cardElevation = 2.0;

  // Feed constants
  static const int feedRefreshThreshold =
      10; // Load more when 10 items from bottom
  static const Duration feedRefreshCooldown = Duration(minutes: 1);
  static const int maxFeedItems = 500; // Maximum items to keep in memory

  // Privacy constants
  static const Duration blockDuration = Duration(days: 30); // Temporary blocks
  static const int maxBlockedUsers = 1000;
  static const int maxReportsPerUser = 10;

  // Game integration constants
  static const int maxGameSessionsPerDay = 20;
  static const Duration gameInviteTimeout = Duration(hours: 24);
  static const int maxParticipantsPerGame = 20;

  // Location constants
  static const double nearbyRadius = 10.0; // km
  static const double maxLocationRadius = 100.0; // km
  static const Duration locationUpdateInterval = Duration(minutes: 5);

  // Achievement constants
  static const int maxAchievementsPerUser = 100;
  static const List<String> achievementCategories = [
    'social',
    'gaming',
    'milestone',
    'special',
  ];

  // Content moderation constants
  static const int maxReportsBeforeReview = 5;
  static const Duration contentReviewTimeout = Duration(days: 7);
  static const List<String> bannedWords = [
    // Add content moderation keywords as needed
  ];
}

// Performance constants
const int maxCachedItems = 1000;
const Duration backgroundSyncInterval = Duration(minutes: 15);
const int maxRetryAttempts = 3;
const Duration retryDelay = Duration(seconds: 2);
