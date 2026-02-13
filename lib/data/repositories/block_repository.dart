import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';

/// Single source of truth for user-level blocking.
/// All block operations use auth.users.id (NOT profile IDs).
abstract class BlockRepository {
  /// Block another user. Also removes follow/friendship relationships server-side.
  Future<Result<void, Failure>> blockUser(String targetUserId);

  /// Unblock a user you previously blocked.
  Future<Result<void, Failure>> unblockUser(String targetUserId);

  /// Get all user IDs blocked by the current user.
  Future<Result<List<String>, Failure>> getBlockedUserIds();

  /// Bidirectional check: is there a block in either direction between
  /// the current user and [otherUserId]?
  Future<Result<bool, Failure>> isBlocked(String otherUserId);

  /// Get blocked user details (user_id, display_name, avatar_url, username).
  Future<Result<List<Map<String, dynamic>>, Failure>>
  getBlockedUsersWithProfiles();
}
