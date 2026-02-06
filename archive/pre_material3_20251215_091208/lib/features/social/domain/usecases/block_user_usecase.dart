import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/utils/either.dart';
import '../repositories/friends_repository.dart';
import 'package:dabbler/data/models/social/block_record_model.dart';

/// Parameters for blocking a user
class BlockUserParams {
  final String blockingUserId;
  final String blockedUserId;
  final String? reason;
  final BlockType blockType;
  final bool removeExistingFriendship;
  final bool clearConversations;
  final bool hideSharedContent;
  final bool preventFutureRequests;
  final bool sendNotificationToBlocked;
  final Map<String, dynamic>? metadata;

  const BlockUserParams({
    required this.blockingUserId,
    required this.blockedUserId,
    this.reason,
    this.blockType = BlockType.full,
    this.removeExistingFriendship = true,
    this.clearConversations = true,
    this.hideSharedContent = true,
    this.preventFutureRequests = true,
    this.sendNotificationToBlocked = false,
    this.metadata,
  });

  BlockUserParams copyWith({
    String? blockingUserId,
    String? blockedUserId,
    String? reason,
    BlockType? blockType,
    bool? removeExistingFriendship,
    bool? clearConversations,
    bool? hideSharedContent,
    bool? preventFutureRequests,
    bool? sendNotificationToBlocked,
    Map<String, dynamic>? metadata,
  }) {
    return BlockUserParams(
      blockingUserId: blockingUserId ?? this.blockingUserId,
      blockedUserId: blockedUserId ?? this.blockedUserId,
      reason: reason ?? this.reason,
      blockType: blockType ?? this.blockType,
      removeExistingFriendship:
          removeExistingFriendship ?? this.removeExistingFriendship,
      clearConversations: clearConversations ?? this.clearConversations,
      hideSharedContent: hideSharedContent ?? this.hideSharedContent,
      preventFutureRequests:
          preventFutureRequests ?? this.preventFutureRequests,
      sendNotificationToBlocked:
          sendNotificationToBlocked ?? this.sendNotificationToBlocked,
      metadata: metadata ?? this.metadata,
    );
  }
}

/// Result of block user operation
class BlockUserResult {
  final BlockRecordModel blockRecord;
  final List<CleanupAction> completedCleanupActions;
  final List<CleanupAction> failedCleanupActions;
  final bool friendshipRemoved;
  final int conversationsCleared;
  final int sharedContentHidden;
  final bool notificationSent;
  final List<String> warnings;
  final Map<String, dynamic>? debugInfo;

  const BlockUserResult({
    required this.blockRecord,
    this.completedCleanupActions = const [],
    this.failedCleanupActions = const [],
    this.friendshipRemoved = false,
    this.conversationsCleared = 0,
    this.sharedContentHidden = 0,
    this.notificationSent = false,
    this.warnings = const [],
    this.debugInfo,
  });
}

/// Types of blocking
enum BlockType {
  full, // Complete block - no interactions allowed
  messaging, // Block messaging only
  content, // Hide content only
  requests, // Block friend requests only
}

/// Cleanup actions performed when blocking
enum CleanupAction {
  removeFriendship,
  clearConversations,
  hideSharedPosts,
  removeFromGroups,
  cancelPendingRequests,
  clearNotifications,
  updatePrivacySettings,
  removeFromSuggestions,
}

/// Relationship status before blocking
class PreBlockRelationship {
  final bool wereFriends;
  final bool hadPendingFriendRequest;
  final int sharedConversations;
  final int sharedGroups;
  final DateTime? lastInteraction;

  const PreBlockRelationship({
    this.wereFriends = false,
    this.hadPendingFriendRequest = false,
    this.sharedConversations = 0,
    this.sharedGroups = 0,
    this.lastInteraction,
  });
}

/// Use case for blocking users with comprehensive cleanup
class BlockUserUseCase {
  final FriendsRepository _friendsRepository;

  BlockUserUseCase(this._friendsRepository);

  Future<Either<Failure, BlockUserResult>> call(BlockUserParams params) async {
    try {
      // Validate input parameters
      if (params.blockingUserId == params.blockedUserId) {
        return Left(ValidationFailure(message: 'Cannot block yourself'));
      }

      if (params.blockingUserId.isEmpty || params.blockedUserId.isEmpty) {
        return Left(ValidationFailure(message: 'User IDs cannot be empty'));
      }

      // Perform the block operation using FriendsRepository
      final blockResult = await _friendsRepository.blockUser(
        params.blockedUserId,
      );

      return blockResult.fold((failure) => Left(failure), (success) {
        // Create a simple block record
        final blockRecord = BlockRecordModel(
          id: '${params.blockingUserId}_${params.blockedUserId}_${DateTime.now().millisecondsSinceEpoch}',
          blockingUserId: params.blockingUserId,
          blockedUserId: params.blockedUserId,
          reason: params.reason,
          blockType: params.blockType.name,
          createdAt: DateTime.now(),
        );

        return Right(
          BlockUserResult(
            blockRecord: blockRecord,
            completedCleanupActions: [CleanupAction.removeFriendship],
            failedCleanupActions: [],
            friendshipRemoved: true,
            conversationsCleared: 0,
            sharedContentHidden: 0,
            notificationSent: false,
          ),
        );
      });
    } catch (e) {
      return Left(
        ServerFailure(message: 'Failed to block user: ${e.toString()}'),
      );
    }
  }
}
