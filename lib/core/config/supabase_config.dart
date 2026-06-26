class SupabaseConfig {
  // Storage bucket names
  static const String avatarsBucket = 'Avatar';
  static const String venueImagesBucket = 'venue-images';
  static const String postMediaBucket = 'post-media';

  // Table names
  static const String usersTable =
      'profiles'; // Changed from 'users' to 'profiles' to match actual database schema
  static const String venuesTable = 'venues';
  static const String matchesTable = 'matches';
  static const String matchParticipantsTable = 'match_participants';
  static const String matchWaitlistTable = 'match_waitlist';

  // News
  static const String feedPostsView = 'feed_posts';
  static const String publishedNewsTable = 'published_news';

  // Social timeline
  static const String publicActivitiesTable = 'public_activities';

  // RPC function names
  static const String searchMatchesFunction = 'search_matches';
  static const String getNearbyVenuesFunction = 'get_nearby_venues';

  // Real-time channels
  static const String matchesChannel = 'matches';
  static const String participantsChannel = 'match_participants';

  // Auth settings
  static const bool enableEmailConfirmations = false;
  static const bool enablePhoneConfirmations = true;
  static const int sessionTimeout = 3600; // 1 hour in seconds

  // API settings
  static const int maxRowsPerRequest = 1000;
  static const int defaultPageSize = 20;

  // Cache settings
  static const Duration cacheTimeout = Duration(minutes: 5);
  static const int maxCacheSize = 100; // number of items

  // File upload settings
  static const int maxFileSize = 5 * 1024 * 1024; // 5MB
  static const List<String> allowedImageTypes = ['jpg', 'jpeg', 'png', 'webp'];
  static const List<String> allowedDocumentTypes = ['pdf', 'doc', 'docx'];

  // Validation rules
  static const int minPasswordLength = 8;
  static const int maxTitleLength = 100;
  static const int maxDescriptionLength = 500;
  static const int maxParticipants = 50;
  static const int minParticipants = 2;

  // Error messages
  static const String networkErrorMessage =
      'Network error. Please check your connection.';
  static const String authErrorMessage =
      'Authentication failed. Please try again.';
  static const String permissionErrorMessage =
      'You don\'t have permission to perform this action.';
  static const String validationErrorMessage =
      'Please check your input and try again.';
  static const String serverErrorMessage =
      'Server error. Please try again later.';

  // Success messages
  static const String matchCreatedMessage = 'Match created successfully!';
  static const String matchUpdatedMessage = 'Match updated successfully!';
  static const String matchJoinedMessage = 'Successfully joined the match!';
  static const String matchLeftMessage = 'Left the match successfully.';
  static const String profileUpdatedMessage = 'Profile updated successfully!';

  // Default values
  static const String defaultAvatarUrl =
      'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=150';
  static const String defaultVenueImageUrl =
      'https://images.unsplash.com/photo-1571019613454-1cb2f99b2d8b?w=800';
  static const double defaultRating = 4.5;
  static const List<String> defaultAmenities = ['Parking', 'Equipment'];

  // Sports configuration
  static const Map<String, List<String>> sportFormats = {
    'football': ['Futsal', 'Competitive', 'Substitutional', 'Association'],
    'basketball': ['3 vs 3', '5 vs 5'],
    'tennis': ['Singles', 'Doubles'],
    'padel': ['Singles', 'Doubles'],
    'squash': ['Singles', 'Doubles'],
  };

  static const Map<String, int> sportDefaultDurations = {
    'football': 90,
    'basketball': 60,
    'tennis': 120,
    'padel': 90,
    'squash': 60,
  };

  static const Map<String, int> sportMaxParticipants = {
    'football': 22,
    'basketball': 10,
    'tennis': 4,
    'padel': 4,
    'squash': 4,
  };

  // ---- P4-1: table name constants (auto-generated from call sites) ----
  static const String areasTable = 'areas';
  static const String banTermsTable = 'ban_terms';
  static const String circleMembersTable = 'circle_members';
  static const String circlesTable = 'circles';
  static const String commentsTable = 'comments';
  static const String friendEdgesTable = 'friend_edges';
  static const String friendshipsTable = 'friendships';
  static const String gameRatingAggregateTable = 'game_rating_aggregate';
  static const String gamesTable = 'games';
  static const String geoLocationsTable = 'geo_locations';
  static const String hashtagsTable = 'hashtags';
  static const String likesTable = 'likes';
  static const String moderationActionsTable = 'moderation_actions';
  static const String moderationBanTermsTable = 'moderation_ban_terms';
  static const String moderationFlagsTable = 'moderation_flags';
  static const String moderationReportsTable = 'moderation_reports';
  static const String moderationTicketsTable = 'moderation_tickets';
  static const String notificationsTable = 'notifications';
  static const String payoutsTable = 'payouts';
  static const String postCirclesTable = 'post_circles';
  static const String postHashtagsTable = 'post_hashtags';
  static const String postRepostsTable = 'post_reposts';
  static const String postSquadsTable = 'post_squads';
  static const String postThemesTable = 'post_themes';
  static const String postViewsTable = 'post_views';
  static const String postsTable = 'posts';
  static const String profileFollowsTable = 'profile_follows';
  static const String profileLocationsTable = 'profile_locations';
  static const String ratingsTable = 'ratings';
  static const String reactionsTable = 'reactions';
  static const String spaceSlotGridTable = 'space_slot_grid';
  static const String spaceSlotHoldsTable = 'space_slot_holds';
  static const String sportsTable = 'sports';
  static const String squadInvitesTable = 'squad_invites';
  static const String squadJoinRequestsTable = 'squad_join_requests';
  static const String squadLinkTokensTable = 'squad_link_tokens';
  static const String squadMembersTable = 'squad_members';
  static const String squadsTable = 'squads';
  static const String userBlocksTable = 'user_blocks';
  static const String userReputationAggregateTable = 'user_reputation_aggregate';
  static const String vCircleTable = 'v_circle';
  static const String vFeedCircleTable = 'v_feed_circle';
  static const String vSquadCardTable = 'v_squad_card';
  static const String vSquadDetailTable = 'v_squad_detail';
  static const String venueOpeningHoursTable = 'venue_opening_hours';
  static const String venuePriceRulesTable = 'venue_price_rules';
  static const String venueRatingAggregateTable = 'venue_rating_aggregate';
  static const String venueSpacesTable = 'venue_spaces';
  static const String venueSubmissionsTable = 'venue_submissions';
  static const String vibesTable = 'vibes';
  static const String walletLedgerTable = 'wallet_ledger';
  static const String walletsTable = 'wallets';

  // ---- P4-1: RPC name constants ----
  static const String isAdminFn = 'is_admin';
  static const String rpcBlockUserFn = 'rpc_block_user';
  static const String rpcCircleListFn = 'rpc_circle_list';
  static const String rpcFriendRequestsInboxFn = 'rpc_friend_requests_inbox';
  static const String rpcFriendRequestsOutboxFn = 'rpc_friend_requests_outbox';
  static const String rpcFriendUnfriendFn = 'rpc_friend_unfriend';
  static const String rpcUnblockUserFn = 'rpc_unblock_user';
}
