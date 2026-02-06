/// Constants for social features and content limits
class SocialConstants {
  // Post limits
  static const int maxPostLength = 1000;
  static const int maxMediaPerPost = 10;
  static const int maxCommentLength = 500;
  static const int maxCommentDepth = 3; // Maximum reply depth
  static const int maxHashtagsPerPost = 30;
  static const int maxMentionsPerPost = 50;

  // Chat limits
  static const int maxMessageLength = 5000;
  static const int messagesPerPage = 50;
  static const int maxGroupMembers = 500;
  static const int maxConversationTitle = 100;
  static const int maxAttachmentsPerMessage = 5;

  // Friend limits
  static const int maxFriends = 5000;
  static const int suggestionsPerPage = 20;
  static const int maxFriendRequestsPerDay = 50;
  static const int maxBlockedUsers = 10000;

  // Reaction types
  static const List<String> availableReactions = [
    'like',
    'love',
    'celebrate',
    'support',
    'funny',
    'wow',
  ];

  // Content moderation
  static const int maxReportsPerUser = 10;
  static const int minAccountAgeForPosting = 24; // hours
  static const int maxLinksPerPost = 5;

  // Cache and performance
  static const int feedCacheSize = 100;
  static const int messageCacheSize = 500;
  static const int userCacheSize = 1000;
  static const Duration cacheExpiry = Duration(minutes: 15);

  // Notification limits
  static const int maxNotificationsPerBatch = 10;
  static const Duration notificationBatchDelay = Duration(seconds: 10);
  static const int maxNotificationHistory = 1000;

  // Search and discovery
  static const int maxSearchResults = 50;
  static const int maxSearchHistory = 20;
  static const int minSearchQueryLength = 2;
  static const int maxSearchQueryLength = 100;

  // Media constraints
  static const int maxImageSizeBytes = 10 * 1024 * 1024; // 10MB
  static const int maxVideoSizeBytes = 100 * 1024 * 1024; // 100MB
  static const int maxAudioSizeBytes = 20 * 1024 * 1024; // 20MB
  static const List<String> supportedImageFormats = [
    'jpg',
    'jpeg',
    'png',
    'gif',
    'webp',
  ];
  static const List<String> supportedVideoFormats = ['mp4', 'mov', 'avi'];
  static const List<String> supportedAudioFormats = ['mp3', 'wav', 'm4a'];

  // Time constants
  static const Duration typingIndicatorTimeout = Duration(seconds: 3);
  static const Duration onlineStatusTimeout = Duration(minutes: 5);
  static const Duration messageRetryInterval = Duration(seconds: 30);
  static const Duration feedRefreshInterval = Duration(minutes: 5);

  // Privacy levels
  static const String privacyPublic = 'public';
  static const String privacyFriends = 'friends';
  static const String privacyPrivate = 'private';
  static const String privacyCustom = 'custom';

  // User status
  static const String statusOnline = 'online';
  static const String statusAway = 'away';
  static const String statusBusy = 'busy';
  static const String statusOffline = 'offline';

  // Content types
  static const String contentTypeText = 'text';
  static const String contentTypeImage = 'image';
  static const String contentTypeVideo = 'video';
  static const String contentTypeAudio = 'audio';
  static const String contentTypeDocument = 'document';
  static const String contentTypeLocation = 'location';
  static const String contentTypePoll = 'poll';

  // Engagement thresholds
  static const int viralPostThreshold = 1000; // likes/shares
  static const int trendingHashtagThreshold = 100; // uses
  static const double highEngagementRate = 0.1; // 10%
  static const int influencerFollowerThreshold = 10000;

  // Rate limiting
  static const int maxPostsPerHour = 10;
  static const int maxCommentsPerMinute = 5;
  static const int maxLikesPerMinute = 30;
  static const int maxMessagesPerMinute = 60;
  static const int maxFriendRequestsPerHour = 20;

  // Regex patterns
  static const String mentionPattern = r'@(\w+)';
  static const String hashtagPattern = r'#(\w+)';
  static const String urlPattern = r'https?://[^\s]+';
  static const String emailPattern =
      r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b';
}

/// Emoji reactions mapping
class ReactionEmojis {
  static const Map<String, String> reactionEmojis = {
    'like': '👍',
    'love': '❤️',
    'celebrate': '🎉',
    'support': '💪',
    'funny': '😂',
    'wow': '😮',
  };

  static String getEmoji(String reaction) {
    return reactionEmojis[reaction] ?? '👍';
  }

  static List<String> getAllEmojis() {
    return reactionEmojis.values.toList();
  }
}

/// Color constants for social features
class SocialColors {
  static const int primaryBlue = 0xFF1DA1F2;
  static const int likeRed = 0xFFE1306C;
  static const int shareGreen = 0xFF25D366;
  static const int onlineGreen = 0xFF44D362;
  static const int awayYellow = 0xFFFFC107;
  static const int busyRed = 0xFFFF5722;
  static const int offlineGray = 0xFF9E9E9E;
}
