import 'package:dabbler/core/fp/failure.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/repositories/friends_repository.dart';
import '../../../data/repositories/friends_repository_impl.dart';
import '../../../data/repositories/feed_repository.dart';
import '../../../data/repositories/feed_repository_impl.dart';
import '../../../features/misc/data/datasources/supabase_remote_data_source.dart';
import 'package:dabbler/core/fp/result.dart';
import '../services/social_service.dart';

// =============================================================================
// REPOSITORY PROVIDERS - Core Data Layer
// =============================================================================

/// Friends repository provider - manages friend relationships
final friendsRepositoryProvider = Provider<FriendsRepository>((ref) {
  final supabaseService = ref.watch(supabaseServiceProvider);
  return FriendsRepositoryImpl(supabaseService);
});

/// Feed repository provider - manages social feed and posts
final feedRepositoryProvider = Provider<FeedRepository>((ref) {
  final supabaseService = ref.watch(supabaseServiceProvider);
  return FeedRepositoryImpl(supabaseService);
});

// =============================================================================
// FRIENDS & SOCIAL CONNECTIONS
// =============================================================================

/// Get all friendships for the current user
final friendshipsProvider = FutureProvider.autoDispose((ref) async {
  final repo = ref.watch(friendsRepositoryProvider);
  final result = await repo.listFriendships();

  return result.fold(
    (failure) => throw Exception(failure.message),
    (friendships) => friendships,
  );
});

/// Get friend edges (bidirectional friend view)
final friendEdgesProvider = FutureProvider.autoDispose((ref) async {
  final repo = ref.watch(friendsRepositoryProvider);
  final result = await repo.listFriendEdges();

  return result.fold(
    (failure) => throw Exception(failure.message),
    (edges) => edges,
  );
});

/// Get incoming friend requests (inbox)
final incomingFriendRequestsProvider = FutureProvider.autoDispose((ref) async {
  final repo = ref.watch(friendsRepositoryProvider);
  final result = await repo.inbox();

  return result.fold(
    (failure) => throw Exception(failure.message),
    (requests) => requests,
  );
});

/// Get outgoing friend requests (outbox)
final outgoingFriendRequestsProvider = FutureProvider.autoDispose((ref) async {
  final repo = ref.watch(friendsRepositoryProvider);
  final result = await repo.outbox();

  return result.fold(
    (failure) => throw Exception(failure.message),
    (requests) => requests,
  );
});

/// Get total friends count
final friendsCountProvider = Provider.autoDispose<int>((ref) {
  final friendshipsAsync = ref.watch(friendshipsProvider);

  return friendshipsAsync.when(
    data: (friendships) => friendships.length,
    loading: () => 0,
    error: (_, __) => 0,
  );
});

/// Check if user has pending friend requests
final hasPendingRequestsProvider = Provider.autoDispose<bool>((ref) {
  final inboxAsync = ref.watch(incomingFriendRequestsProvider);

  return inboxAsync.when(
    data: (requests) => requests.isNotEmpty,
    loading: () => false,
    error: (_, __) => false,
  );
});

// =============================================================================
// FRIEND REQUEST ACTIONS
// =============================================================================

/// Send a friend request to a user
final sendFriendRequestProvider =
    FutureProvider.family<Result<void, Failure>, String>((
      ref,
      peerUserId,
    ) async {
      final repo = ref.watch(friendsRepositoryProvider);
      return await repo.sendFriendRequest(peerUserId);
    });

/// Accept a friend request
final acceptFriendRequestProvider =
    FutureProvider.family<Result<void, Failure>, String>((
      ref,
      peerUserId,
    ) async {
      final repo = ref.watch(friendsRepositoryProvider);
      final result = await repo.acceptFriendRequest(peerUserId);

      // Refresh friends list after accepting
      if (result.isRight) {
        ref.invalidate(friendshipsProvider);
        ref.invalidate(incomingFriendRequestsProvider);
      }

      return result;
    });

/// Reject a friend request
final rejectFriendRequestProvider =
    FutureProvider.family<Result<void, Failure>, String>((
      ref,
      peerUserId,
    ) async {
      final repo = ref.watch(friendsRepositoryProvider);
      final result = await repo.rejectFriendRequest(peerUserId);

      // Refresh inbox after rejecting
      if (result.isRight) {
        ref.invalidate(incomingFriendRequestsProvider);
      }

      return result;
    });

/// Remove a friend
final removeFriendProvider =
    FutureProvider.family<Result<void, Failure>, String>((
      ref,
      peerUserId,
    ) async {
      final repo = ref.watch(friendsRepositoryProvider);
      final result = await repo.removeFriend(peerUserId);

      // Refresh friends list after removal
      if (result.isRight) {
        ref.invalidate(friendshipsProvider);
        ref.invalidate(friendEdgesProvider);
      }

      return result;
    });

/// Block a user
final blockUserProvider = FutureProvider.family<Result<void, Failure>, String>((
  ref,
  peerUserId,
) async {
  final repo = ref.watch(friendsRepositoryProvider);
  final result = await repo.blockUser(peerUserId);

  // Refresh data after blocking
  if (result.isRight) {
    ref.invalidate(friendshipsProvider);
    ref.invalidate(friendEdgesProvider);
  }

  return result;
});

/// Unblock a user
final unblockUserProvider =
    FutureProvider.family<Result<void, Failure>, String>((
      ref,
      peerUserId,
    ) async {
      final repo = ref.watch(friendsRepositoryProvider);
      return await repo.unblockUser(peerUserId);
    });

// =============================================================================
// SOCIAL FEED & POSTS
// =============================================================================

/// State management for feed refresh
class FeedRefreshNotifier extends StateNotifier<int> {
  FeedRefreshNotifier() : super(0);

  void refresh() => state++;
}

final feedRefreshProvider = StateNotifierProvider<FeedRefreshNotifier, int>(
  (ref) => FeedRefreshNotifier(),
);

/// Get social feed posts
final socialFeedProvider = FutureProvider.autoDispose((ref) async {
  // Watch refresh trigger
  ref.watch(feedRefreshProvider);

  final repo = ref.watch(feedRepositoryProvider);
  final result = await repo.listRecent(limit: 50);

  return result.fold(
    (failure) => throw Exception(failure.message),
    (feedItems) => feedItems,
  );
});

/// Get posts by specific user
final userPostsProvider = FutureProvider.family
    .autoDispose<List<dynamic>, String>((ref, userId) async {
      final socialService = SocialService();
      return await socialService.getUserPosts(userId: userId);
    });

// =============================================================================
// COMMUNITY STATS & ANALYTICS
// =============================================================================

/// Community engagement stats
final communityStatsProvider = FutureProvider.autoDispose((ref) async {
  final friendships = await ref.watch(friendshipsProvider.future);
  final feed = await ref.watch(socialFeedProvider.future);

  return {
    'totalFriends': friendships.length,
    'totalPosts': feed.length,
    'engagementRate': friendships.isEmpty
        ? 0.0
        : feed.length / friendships.length,
  };
});

/// Active community members count
final activeMembersProvider = Provider.autoDispose<int>((ref) {
  final friendsCount = ref.watch(friendsCountProvider);
  return friendsCount;
});

// =============================================================================
// HELPER EXTENSION FOR EASY ACCESS
// =============================================================================

extension CommunityProvidersExtension on WidgetRef {
  /// Get friends repository
  FriendsRepository get friendsRepo => read(friendsRepositoryProvider);

  /// Get feed repository
  FeedRepository get feedRepo => read(feedRepositoryProvider);

  /// Refresh social feed
  void refreshFeed() => read(feedRefreshProvider.notifier).refresh();

  /// Send friend request
  Future<void> sendFriendRequest(String userId) async {
    final result = await read(sendFriendRequestProvider(userId).future);
    result.fold(
      (failure) => throw Exception(failure.message),
      (_) => invalidate(outgoingFriendRequestsProvider),
    );
  }

  /// Accept friend request
  Future<void> acceptFriendRequest(String userId) async {
    final result = await read(acceptFriendRequestProvider(userId).future);
    result.fold((failure) => throw Exception(failure.message), (_) {
      invalidate(friendshipsProvider);
      invalidate(incomingFriendRequestsProvider);
    });
  }

  /// Remove friend
  Future<void> removeFriend(String userId) async {
    final result = await read(removeFriendProvider(userId).future);
    result.fold((failure) => throw Exception(failure.message), (_) {
      invalidate(friendshipsProvider);
      invalidate(friendEdgesProvider);
    });
  }
}

/// Extension for BuildContext-less access in widgets
extension CommunityConsumerExtension on WidgetRef {
  /// Watch friends count
  int get friendsCount => watch(friendsCountProvider);

  /// Watch if user has pending requests
  bool get hasPendingRequests => watch(hasPendingRequestsProvider);

  /// Watch active members count
  int get activeMembersCount => watch(activeMembersProvider);
}
