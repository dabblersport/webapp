import '../../../../utils/enums/social_enums.dart';

/// Domain entity for social posts.
///
/// This is the UI/domain representation built on top of the canonical
/// `public.posts` schema and joined profile data.
class Post {
  final String id;
  final String authorId;
  final String authorName;
  final String authorAvatar;
  final String? authorProfileId; // author_profile_id from posts table
  // Core content
  final String content;
  final List<String> mediaUrls;
  final DateTime createdAt;
  final DateTime updatedAt;
  // Aggregated stats
  final int likesCount;
  final int commentsCount;
  final int sharesCount;
  // Visibility & routing
  final PostVisibility visibility;
  // Game / location context (optional)
  final String? gameId;
  final String? cityName;
  final String? venueId; // venue_id from posts table
  final String? locationTagId; // location_tag_id from posts table
  // Per-user state
  final bool isLiked;
  final bool isBookmarked;
  // Author profile details
  final String? authorBio;
  final bool authorVerified;
  // Content metadata
  final List<String> tags;
  final List<String> mentionedUsers;
  // Editing state
  final bool isEdited;
  final DateTime? editedAt;
  // Conversation / sharing
  final String? replyToPostId;
  final String? shareOriginalId;
  // Activity-specific fields for unified activity feed
  final String? activityType;
  final Map<String, dynamic>? activityData;

  /// Post kind maps directly to `public.posts.kind` (e.g. 'moment', 'dab', 'kickin').
  final String kind;

  /// Primary vibe ID maps to `public.posts.primary_vibe_id` (nullable).
  final String? primaryVibeId;

  /// Primary vibe full data (joined from vibes table via primary_vibe_id)
  final Map<String, dynamic>? primaryVibe;

  /// Vibe emoji for display (joined from vibes table)
  final String? vibeEmoji;

  /// Vibe label for display (joined from vibes table)
  final String? vibeLabel;

  /// All assigned vibes from post_vibes table (joined)
  final List<Map<String, dynamic>> postVibes;

  /// Reactions from post_reactions table (who reacted with which vibe)
  final List<Map<String, dynamic>> reactions;

  /// Mentions from post_mentions table (who was mentioned)
  final List<Map<String, dynamic>> mentions;

  /// Location tag data from location_tags table (joined)
  final Map<String, dynamic>? locationTag;

  /// Media metadata from posts.media jsonb
  final List<Map<String, dynamic>> mediaMetadata;

  const Post({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.authorAvatar,
    this.authorProfileId,
    required this.content,
    required this.mediaUrls,
    required this.createdAt,
    required this.updatedAt,
    required this.likesCount,
    required this.commentsCount,
    required this.sharesCount,
    required this.visibility,
    this.gameId,
    this.cityName,
    this.venueId,
    this.locationTagId,
    this.isLiked = false,
    this.isBookmarked = false,
    this.authorBio,
    this.authorVerified = false,
    this.tags = const [],
    this.mentionedUsers = const [],
    this.isEdited = false,
    this.editedAt,
    this.replyToPostId,
    this.shareOriginalId,
    this.activityType,
    this.activityData,
    this.kind = 'moment',
    this.primaryVibeId,
    this.primaryVibe,
    this.vibeEmoji,
    this.vibeLabel,
    this.postVibes = const [],
    this.reactions = const [],
    this.mentions = const [],
    this.locationTag,
    this.mediaMetadata = const [],
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Post && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Enum for conversation types
enum ConversationType { direct, group, game, support }
