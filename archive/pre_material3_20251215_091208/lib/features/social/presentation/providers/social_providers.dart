import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controllers/social_feed_controller.dart';
import '../controllers/chat_controller.dart';
import '../controllers/friend_requests_controller.dart';
import '../controllers/posts_controller.dart';
import 'package:dabbler/data/models/social/post_model.dart';
import 'package:dabbler/data/models/social/comment_model.dart';
import 'package:dabbler/data/models/profile/user_profile.dart';
import '../../../../../utils/enums/social_enums.dart';
import '../widgets/trending/trending_filter_bar.dart';
import '../widgets/trending/trending_hashtags_widget.dart';
import '../widgets/trending/top_contributors_widget.dart';
import '../widgets/trending/engagement_metrics_widget.dart';

/// Provider for the social feed controller
final socialFeedControllerProvider =
    StateNotifierProvider<SocialFeedController, SocialFeedState>(
      (ref) => SocialFeedController(),
    );

/// Provider for the posts controller (post creation)
final postsControllerProvider =
    StateNotifierProvider<PostsController, PostsState>((ref) {
      // For now, create a mock use case to avoid dependency issues
      final mockUseCase = _MockCreatePostUseCase();
      return PostsController(mockUseCase);
    });

// Mock implementation to avoid dependency issues
class _MockCreatePostUseCase {
  // This is a temporary mock to allow the provider to compile
  // In a real implementation, this would be injected properly
}

/// Provider for checking if user has notifications
final hasNotificationsProvider = Provider<bool>((ref) {
  return false;
});

/// Provider for checking if there are pending posts
final hasPendingPostsProvider = Provider<bool>((ref) {
  return false;
});

/// Provider for recent chat contacts
final recentChatContactsProvider = FutureProvider<List<UserProfile>>((
  ref,
) async {
  return [];
});

/// Provider for current user
final currentUserProvider = Provider<UserProfile>((ref) {
  return UserProfile(
    id: 'current_user',
    userId: 'current_user',
    email: 'user@example.com',
    displayName: 'Current User',
    avatarUrl: null,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );
});

/// Provider for current user ID
final currentUserIdProvider = Provider<String>((ref) {
  final user = ref.watch(currentUserProvider);
  return user.id;
});

/// Provider for post details by ID
final postDetailsProvider = FutureProvider.family<PostModel, String>((
  ref,
  postId,
) async {
  await Future.delayed(const Duration(milliseconds: 500));
  final allPosts = ref.read(postsProvider);
  return allPosts.firstWhere(
    (post) => post.id == postId,
    orElse: () => PostModel(
      id: postId,
      authorId: 'author_id',
      authorName: 'Author Name',
      authorAvatar: '',
      content: 'Sample post content',
      mediaUrls: [],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      likesCount: 0,
      commentsCount: 0,
      sharesCount: 0,
      visibility: PostVisibility.public,
    ),
  );
});

/// Provider for post comments by post ID
final postCommentsProvider = FutureProvider.family<List<CommentModel>, String>((
  ref,
  postId,
) async {
  await Future.delayed(const Duration(milliseconds: 300));
  return [];
});

/// Provider for post comments count by post ID
final postCommentsCountProvider = FutureProvider.family<int, String>((
  ref,
  postId,
) async {
  final comments = await ref.watch(postCommentsProvider(postId).future);
  return comments.length;
});

/// Provider for post likes by post ID
final postLikesProvider = FutureProvider.family<List<UserProfile>, String>((
  ref,
  postId,
) async {
  await Future.delayed(const Duration(milliseconds: 300));
  return [];
});

/// Provider for posts
final postsProvider = Provider<List<PostModel>>((ref) {
  final feedState = ref.watch(socialFeedControllerProvider);
  return feedState.posts;
});

/// Provider for filtered posts
final filteredPostsProvider = Provider<List<PostModel>>((ref) {
  final feedState = ref.watch(socialFeedControllerProvider);
  return feedState.filteredPosts;
});

/// Provider for feed loading state
final feedLoadingProvider = Provider<bool>((ref) {
  final feedState = ref.watch(socialFeedControllerProvider);
  return feedState.isLoading;
});

/// Provider for feed error
final feedErrorProvider = Provider<String?>((ref) {
  final feedState = ref.watch(socialFeedControllerProvider);
  return feedState.error;
});

/// Provider for the chat controller
final chatControllerProvider = StateNotifierProvider<ChatController, ChatState>(
  (ref) => ChatController(),
);

/// Provider for total unread messages count
final totalUnreadMessagesProvider = Provider<int>((ref) {
  final chatState = ref.watch(chatControllerProvider);
  return chatState.unreadCounts.values.fold(0, (sum, count) => sum + count);
});

/// Provider for archived chats count
final archivedChatsCountProvider = Provider<int>((ref) {
  final chatState = ref.watch(chatControllerProvider);
  return chatState.archivedConversationIds.length;
});

/// Provider for recent conversation media
final recentConversationMediaProvider =
    FutureProvider.family<List<String>, ({String conversationId, int limit})>((
      ref,
      params,
    ) async {
      await Future.delayed(const Duration(milliseconds: 500));
      return [];
    });

/// Provider for conversation stats
final conversationStatsProvider =
    FutureProvider.family<Map<String, dynamic>, String>((
      ref,
      conversationId,
    ) async {
      await Future.delayed(const Duration(milliseconds: 500));
      return {
        'totalMessages': 0,
        'mediaCount': 0,
        'participantCount': 0,
        'createdDate': DateTime.now().toIso8601String(),
      };
    });

// =============================================================================
// FRIEND REQUESTS PROVIDERS
// =============================================================================

/// Provider for friend requests controller
final friendRequestsControllerProvider =
    StateNotifierProvider<FriendRequestsController, FriendRequestsState>((ref) {
      throw UnimplementedError(
        'FriendRequestsController dependencies not implemented',
      );
    });

/// Provider for incoming requests count
final incomingRequestsCountProvider = Provider<int>((ref) {
  final requestsState = ref.watch(friendRequestsControllerProvider);
  return requestsState.incomingRequestsCount;
});

/// Provider for outgoing requests count
final outgoingRequestsCountProvider = Provider<int>((ref) {
  final requestsState = ref.watch(friendRequestsControllerProvider);
  return requestsState.outgoingRequestsCount;
});

/// Provider for trending hashtags
final trendingHashtagsProvider =
    FutureProvider.family<List<TrendingHashtag>, TrendingTimeRange>((
      ref,
      timeRange,
    ) async {
      await Future.delayed(const Duration(milliseconds: 500));
      return [];
    });

/// Provider for top contributors
final topContributorsProvider =
    FutureProvider.family<List<TopContributor>, TrendingTimeRange>((
      ref,
      timeRange,
    ) async {
      await Future.delayed(const Duration(milliseconds: 500));
      return [];
    });

/// Provider for engagement metrics
final engagementMetricsProvider =
    FutureProvider.family<EngagementMetrics, TrendingTimeRange>((
      ref,
      timeRange,
    ) async {
      await Future.delayed(const Duration(milliseconds: 500));
      return const EngagementMetrics(
        totalPosts: 0,
        totalEngagement: 0,
        averageEngagementRate: 0.0,
        activeUsers: 0,
        totalLikes: 0,
        totalComments: 0,
        totalShares: 0,
        postsGrowth: 0.0,
        engagementGrowth: 0.0,
        userGrowth: 0.0,
      );
    });

/// Simple media item model for recent media
class MediaItem {
  final String id;
  final String type;
  final String url;
  final String? thumbnailUrl;
  final DateTime createdAt;

  MediaItem({
    required this.id,
    required this.type,
    required this.url,
    this.thumbnailUrl,
    required this.createdAt,
  });
}

/// Provider for recent media files
final recentMediaProvider = FutureProvider<List<MediaItem>>((ref) async {
  await Future.delayed(const Duration(milliseconds: 300));
  return [];
});

/// Provider for saved drafts count
final savedDraftsCountProvider = FutureProvider<int>((ref) async {
  await Future.delayed(const Duration(milliseconds: 200));
  return 0;
});
