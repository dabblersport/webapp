import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/core/fp/failure.dart';

import '../models/friend_edge.dart';
import '../models/friendship.dart';

/// Repository interface for managing friendships and related requests.
abstract class FriendsRepository {
  /// Uses RLS policy `friendships_insert_requester` via RPC.
  Future<Result<void, Failure>> sendFriendRequest(String peerUserId);

  /// Uses RLS policy `friendships_update_parties` via RPC.
  Future<Result<void, Failure>> acceptFriendRequest(String peerUserId);

  /// Uses RLS policy `friendships_update_parties` via RPC.
  Future<Result<void, Failure>> rejectFriendRequest(String peerUserId);

  /// Uses RLS policy `friendships_update_parties` via RPC.
  Future<Result<void, Failure>> removeFriend(String peerUserId);

  /// Uses RLS policy `friendships_select_parties`.
  Future<Result<List<Friendship>, Failure>> listFriendships();

  /// Shape defined by RPC; relies on requester visibility within stored procedure.
  Future<Result<List<Map<String, dynamic>>, Failure>> inbox();

  /// Shape defined by RPC; relies on requester visibility within stored procedure.
  Future<Result<List<Map<String, dynamic>>, Failure>> outbox();

  /// Uses RLS policy `friend_edges_read`.
  Future<Result<List<FriendEdge>, Failure>> listFriendEdges();

  // NOTE: blockUser/unblockUser removed — use BlockRepository from block_providers.dart

  /// Get friendship status with a user
  Future<Result<String, Failure>> getFriendshipStatus(String peerUserId);

  /// Get friendship status as stream with real-time updates
  Stream<Result<String, Failure>> getFriendshipStatusStream(String peerUserId);

  /// Get list of friends
  Future<Result<List<Map<String, dynamic>>, Failure>> getFriends();

  /// Get friend suggestions based on mutual friends
  Future<Result<List<Map<String, dynamic>>, Failure>> getFriendSuggestions({
    int limit = 20,
  });

  /// List available profiles for discovery (Suggestions tab).
  ///
  /// Implementations should exclude the current user when possible.
  Future<Result<List<Map<String, dynamic>>, Failure>> listProfiles({
    int limit = 200,
  });

  /// Search for users by name or username
  Future<Result<List<Map<String, dynamic>>, Failure>> searchUsers(
    String query, {
    int limit = 20,
  });
}
