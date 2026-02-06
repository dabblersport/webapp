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

  /// Optional helper calling `rpc_block_user`.
  Future<Result<void, Failure>> blockUser(String peerUserId);

  /// Optional helper calling `rpc_unblock_user`.
  Future<Result<void, Failure>> unblockUser(String peerUserId);
}
