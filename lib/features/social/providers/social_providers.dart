import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../presentation/controllers/chat_controller.dart';
import '../presentation/controllers/posts_controller.dart';
import '../presentation/controllers/social_feed_controller.dart';
import 'package:dabbler/data/models/social/chat_message_model.dart';
import 'package:dabbler/data/models/social/conversation_model.dart';
import '../../../../utils/enums/social_enums.dart'; // Import MessageType
import '../services/social_service.dart';
import 'package:dabbler/features/auth_onboarding/presentation/providers/auth_providers.dart';

// =============================================================================
// POSTS CONTROLLER PROVIDER
// =============================================================================

/// Provider for PostsController
final postsControllerProvider =
    StateNotifierProvider<PostsController, PostsState>((ref) {
      // Stub implementation — real creation goes through SocialService directly.
      return PostsController(null);
    });

// =============================================================================
// SOCIAL FEED CONTROLLER PROVIDER
// =============================================================================

/// Provider for SocialFeedController
final socialFeedControllerProvider =
    StateNotifierProvider<SocialFeedController, SocialFeedState>((ref) {
      return SocialFeedController();
    });

// =============================================================================
// CHAT CONTROLLER PROVIDER
// =============================================================================

/// Provider for ChatController
final chatControllerProvider = StateNotifierProvider<ChatController, ChatState>(
  (ref) {
    return ChatController();
  },
);

// =============================================================================
// COMPUTED PROVIDERS (DERIVED STATE)
// =============================================================================

/// Total unread messages count across all conversations
final totalUnreadMessagesProvider = Provider<int>((ref) {
  final chatState = ref.watch(chatControllerProvider);
  return chatState.totalUnreadCount;
});

/// Current active conversation
final activeConversationProvider = Provider<ConversationModel?>((ref) {
  final chatState = ref.watch(chatControllerProvider);
  return chatState.activeConversation;
});

/// Is currently typing in active conversation
final isTypingProvider = Provider<bool>((ref) {
  final chatState = ref.watch(chatControllerProvider);
  return chatState.isTypingSomeone;
});

// =============================================================================
// STREAM PROVIDERS (REAL-TIME DATA)
// =============================================================================

/// Stream of new messages
final newMessagesStreamProvider = StreamProvider<List<ChatMessageModel>>((ref) {
  // Mock stream - replace with actual real-time implementation
  return Stream.periodic(
    const Duration(minutes: 2),
    (index) => [
      ChatMessageModel(
        id: 'stream_message_$index',
        conversationId: 'stream_conversation_$index',
        senderId: 'stream_sender_$index',
        content: 'Stream message $index',
        sentAt: DateTime.now(),
        messageType: MessageType.text,
      ),
    ],
  );
});

// =============================================================================
// NOTIFICATION PROVIDERS
// =============================================================================

/// Provider for notification badges
final notificationBadgesProvider = Provider<Map<String, int>>((ref) {
  final unreadMessages = ref.watch(totalUnreadMessagesProvider);

  return {'messages': unreadMessages};
});

/// Provider for checking if there are any notifications
final hasNotificationsProvider = Provider<bool>((ref) {
  final badges = ref.watch(notificationBadgesProvider);
  return badges.values.any((count) => count > 0);
});

// =============================================================================
// CHAT-RELATED PROVIDERS
// =============================================================================

/// Provider for conversation participants
final conversationParticipantsProvider =
    FutureProvider.family<List<dynamic>, String>((ref, conversationId) async {
      // Mock implementation - in real app, this would fetch from repository
      await Future.delayed(const Duration(milliseconds: 300));
      return [
        {'id': 'user1', 'name': 'John Doe', 'avatarUrl': null, 'isAdmin': true},
        {
          'id': 'user2',
          'name': 'Jane Smith',
          'avatarUrl': null,
          'isAdmin': false,
        },
      ];
    });

/// Provider for conversation media
final conversationMediaProvider = FutureProvider.family<List<dynamic>, String>((
  ref,
  conversationId,
) async {
  // Mock implementation - in real app, this would fetch from repository
  await Future.delayed(const Duration(milliseconds: 300));
  return [
    {
      'id': 'media1',
      'type': 'image',
      'url': 'https://example.com/image1.jpg',
      'thumbnail': 'https://example.com/thumb1.jpg',
      'size': 1024000,
      'name': 'image1.jpg',
    },
    {
      'id': 'media2',
      'type': 'video',
      'url': 'https://example.com/video1.mp4',
      'thumbnail': 'https://example.com/thumb2.jpg',
      'size': 5120000,
      'name': 'video1.mp4',
    },
  ];
});

/// Provider for archived chats count
final archivedChatsCountProvider = Provider<int>((ref) {
  // In a real implementation, this would count archived conversations
  // For now, return 0
  return 0;
});

/// Provider for recent chat contacts
final recentChatContactsProvider = Provider<List<Map<String, dynamic>>>((ref) {
  // Mock implementation - in real app, this would fetch recent contacts
  return [
    {
      'id': 'user1',
      'name': 'John Doe',
      'avatarUrl': null,
      'lastMessage': 'Hey, how are you?',
      'lastMessageTime': DateTime.now().subtract(const Duration(minutes: 5)),
    },
    {
      'id': 'user2',
      'name': 'Jane Smith',
      'avatarUrl': null,
      'lastMessage': 'See you tomorrow!',
      'lastMessageTime': DateTime.now().subtract(const Duration(hours: 2)),
    },
  ];
});

// =============================================================================
// POST DETAILS PROVIDERS
// =============================================================================

/// Provider for post details
final postDetailsProvider = FutureProvider.family<dynamic, String>((
  ref,
  postId,
) async {
  try {
    final socialService = SocialService();
    return await socialService.getPostById(postId);
  } catch (e) {
    throw Exception('Failed to load post: $e');
  }
});

/// Provider for available vibes (catalog)
final vibesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final socialService = SocialService();
  return socialService.getVibes();
});

/// Provider for vibes assigned to a specific post
final postVibesProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((
      ref,
      postId,
    ) async {
      final socialService = SocialService();
      return socialService.getPostVibes(postId);
    });

/// Helper function to transform a comment with nested replies
_CommentData _transformComment(Map<String, dynamic> comment) {
  final profile = comment['profiles'];
  final replies = comment['replies'] as List<dynamic>? ?? [];

  return _CommentData(
    id: comment['id'],
    authorId: comment['author_user_id'],
    content: comment['body'] ?? '',
    createdAt: DateTime.parse(comment['created_at']),
    author: _UserViewModel(
      id: comment['author_user_id'],
      name: profile?['display_name'] ?? 'Unknown',
      username: profile?['display_name'] ?? 'unknown',
      avatar: profile?['avatar_url'],
      isVerified: profile?['verified'] ?? false,
    ),
    likesCount: comment['likes_count'] ?? comment['like_count'] ?? 0,
    isLiked: comment['is_liked'] == true || comment['user_has_liked'] == true,
    replies: replies
        .map((reply) => _transformComment(reply as Map<String, dynamic>))
        .toList(),
  );
}

/// Provider for post comments with nested replies
final postCommentsProvider = FutureProvider.family<List<dynamic>, String>((
  ref,
  postId,
) async {
  try {
    final socialService = SocialService();
    final rawComments = await socialService.getComments(postId);

    // Transform database comments to UI-expected format with nested replies
    return rawComments.map((comment) => _transformComment(comment)).toList();
  } catch (e) {
    throw Exception('Failed to load comments: $e');
  }
});

/// Helper function to count all comments including replies recursively
int _countAllComments(List<_CommentData> comments) {
  int count = comments.length;
  for (final comment in comments) {
    count += _countAllComments(comment.replies);
  }
  return count;
}

/// Provider for post comments count (including nested replies)
final postCommentsCountProvider = Provider.family<int, String>((ref, postId) {
  final commentsAsync = ref.watch(postCommentsProvider(postId));
  return commentsAsync.when(
    data: (comments) => _countAllComments(comments.cast<_CommentData>()),
    loading: () => 0,
    error: (_, __) => 0,
  );
});

/// Provider for post likes - fetches from database
final postLikesProvider = FutureProvider.family<List<dynamic>, String>((
  ref,
  postId,
) async {
  try {
    final socialService = SocialService();
    final likes = await socialService.getPostLikes(postId);
    return likes;
  } catch (e) {
    return [];
  }
});

/// Provider for current user ID - connected to auth service
final currentUserIdProvider = Provider<String>((ref) {
  final authService = ref.watch(authServiceProvider);
  final currentUser = authService.getCurrentUser();
  return currentUser?.id ?? '';
});

// =============================================================================
// VIEW MODEL CLASSES (for UI data transformation)
// =============================================================================

/// User view model for displaying user info in comments/posts
class _UserViewModel {
  final String id;
  final String name;
  final String username;
  final String? avatar;
  final bool isVerified;

  const _UserViewModel({
    required this.id,
    required this.name,
    required this.username,
    this.avatar,
    this.isVerified = false,
  });
}

/// Comment view model with author data from database
class _CommentData {
  final String id;
  final String authorId;
  final String content;
  final _UserViewModel author;
  final DateTime createdAt;
  final int likesCount;
  final bool isLiked;
  final List<_CommentData> replies;

  const _CommentData({
    required this.id,
    required this.authorId,
    required this.content,
    required this.author,
    required this.createdAt,
    this.likesCount = 0,
    this.isLiked = false,
    this.replies = const [],
  });
}

// =============================================================================
// EXTENSION METHODS
// =============================================================================

/// Extension for easy provider access in widgets
extension SocialProvidersExtension on WidgetRef {
  // Controllers
  ChatController get chatController => read(chatControllerProvider.notifier);

  // States
  ChatState get chatState => watch(chatControllerProvider);

  // Computed values
  int get totalUnreadMessages => watch(totalUnreadMessagesProvider);
  bool get hasNotifications => watch(hasNotificationsProvider);
  Map<String, int> get notificationBadges => watch(notificationBadgesProvider);
}
