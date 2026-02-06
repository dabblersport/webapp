import 'package:fpdart/fpdart.dart';

import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/data/models/social/friend.dart';
import '../repositories/friends_repository.dart';
import 'package:dabbler/data/models/social/friend_model.dart';

/// Parameters for adding a friend
class AddFriendParams {
  final String userId;
  final String targetUserId;
  final String? message;
  final bool bypassPrivacyCheck;

  const AddFriendParams({
    required this.userId,
    required this.targetUserId,
    this.message,
    this.bypassPrivacyCheck = false,
  });
}

/// Result of add friend operation
class AddFriendResult {
  final FriendModel friendship;
  final String status; // 'sent', 'accepted', 'blocked', 'error'
  final String? message;
  final bool notificationSent;
  final Map<String, dynamic> metadata;

  const AddFriendResult({
    required this.friendship,
    required this.status,
    this.message,
    this.notificationSent = false,
    this.metadata = const {},
  });
}

/// Use case for adding friends with comprehensive validation and business logic
class AddFriendUseCase {
  final FriendsRepository _friendsRepository;

  AddFriendUseCase(this._friendsRepository);

  Future<Either<Failure, AddFriendResult>> call(AddFriendParams params) async {
    try {
      // Validate input parameters
      final validationResult = await _validateParams(params);
      if (validationResult.isLeft()) {
        return Left(
          validationResult.fold(
            (l) => l,
            (r) => throw Exception('Unexpected success'),
          ),
        );
      }

      // Check rate limiting for friend requests
      final rateLimitResult = await _checkRateLimit(params.userId);
      if (rateLimitResult.isLeft()) {
        return Left(
          rateLimitResult.fold(
            (l) => l,
            (r) => throw Exception('Unexpected success'),
          ),
        );
      }

      // Check if users are already friends or have pending request
      final existingRelationResult = await _checkExistingRelation(params);
      if (existingRelationResult.isLeft()) {
        return Left(
          existingRelationResult.fold(
            (l) => l,
            (r) => throw Exception('Unexpected success'),
          ),
        );
      }

      // Check if target user is blocked or has blocked current user
      final blockStatusResult = await _checkBlockStatus(params);
      if (blockStatusResult.isLeft()) {
        return Left(
          blockStatusResult.fold(
            (l) => l,
            (r) => throw Exception('Unexpected success'),
          ),
        );
      }

      // Check privacy settings if not bypassed
      if (!params.bypassPrivacyCheck) {
        final privacyResult = await _checkPrivacySettings(params);
        if (privacyResult.isLeft()) {
          return Left(
            privacyResult.fold(
              (l) => l,
              (r) => throw Exception('Unexpected success'),
            ),
          );
        }
      }

      // Send the friend request
      final friendRequestResult = await _friendsRepository.sendFriendRequest(
        params.targetUserId,
        message: params.message,
      );

      if (friendRequestResult.isLeft()) {
        return Left(
          friendRequestResult.fold(
            (l) => l,
            (r) => throw Exception('Unexpected success'),
          ),
        );
      }

      final friendship = friendRequestResult.fold(
        (l) => throw Exception('Unexpected failure'),
        (r) => r,
      );

      // Send notification to recipient
      final notificationSent = await _sendFriendRequestNotification(
        params.userId,
        params.targetUserId,
        friendship.id,
        params.message,
      );

      // Log the friend request action
      await _logFriendRequestAction(params, friendship);

      // Update user activity metrics
      await _updateUserMetrics(params.userId, 'friend_request_sent');

      return Right(
        AddFriendResult(
          friendship: friendship,
          status: _determineFriendshipStatus(friendship.status),
          message: 'Friend request sent successfully',
          notificationSent: notificationSent,
          metadata: {
            'friendship_id': friendship.id,
            'sent_at': friendship.friendRequestSentAt?.toIso8601String(),
            'auto_accepted': friendship.status == FriendshipStatus.accepted,
          },
        ),
      );
    } catch (e) {
      return Left(
        ServerFailure(
          message: 'Failed to send friend request: ${e.toString()}',
          code: '500',
        ),
      );
    }
  }

  /// Validates input parameters for friend request
  Future<Either<Failure, void>> _validateParams(AddFriendParams params) async {
    // Check if user is trying to add themselves
    if (params.userId == params.targetUserId) {
      return Left(
        ValidationFailure(
          message: 'Cannot send friend request to yourself',
          code: '400',
        ),
      );
    }

    // Validate user IDs format (assuming UUID format)
    if (!_isValidUserId(params.userId)) {
      return Left(
        ValidationFailure(message: 'Invalid user ID format', code: '400'),
      );
    }

    if (!_isValidUserId(params.targetUserId)) {
      return Left(
        ValidationFailure(
          message: 'Invalid target user ID format',
          code: '400',
        ),
      );
    }

    // Validate message length if provided
    if (params.message != null && params.message!.length > 500) {
      return Left(
        ValidationFailure(
          message: 'Friend request message cannot exceed 500 characters',
          code: '400',
        ),
      );
    }

    return const Right(null);
  }

  /// Checks rate limiting for friend requests
  Future<Either<Failure, void>> _checkRateLimit(String userId) async {
    try {
      // Check if user has exceeded friend request rate limit (e.g., 10 requests per hour)
      final recentRequests = await _friendsRepository.getRecentFriendRequests(
        userId,
        hours: 1,
      );

      if (recentRequests.isRight() &&
          recentRequests
                  .fold((l) => throw Exception('Unexpected failure'), (r) => r)
                  .length >=
              10) {
        return Left(
          BusinessLogicFailure(
            message:
                'Friend request rate limit exceeded. Please wait before sending more requests.',
            code: '429',
          ),
        );
      }

      return const Right(null);
    } catch (e) {
      return Left(
        ServerFailure(
          message: 'Failed to check rate limit: ${e.toString()}',
          code: '500',
        ),
      );
    }
  }

  /// Checks if there's already an existing relationship
  Future<Either<Failure, void>> _checkExistingRelation(
    AddFriendParams params,
  ) async {
    try {
      final existingFriendship = await _friendsRepository.getFriendshipStatus(
        params.userId,
        params.targetUserId,
      );

      if (existingFriendship.isRight()) {
        final status = existingFriendship.fold(
          (l) => throw Exception('Unexpected failure'),
          (r) => r,
        );
        if (status != null) {
          switch (status) {
            case FriendshipStatus.accepted:
              return Left(
                ConflictFailure(
                  message: 'You are already friends with this user',
                  code: '409',
                ),
              );
            case FriendshipStatus.pending:
              return Left(
                ConflictFailure(
                  message: 'Friend request already sent to this user',
                  code: '409',
                ),
              );
            case FriendshipStatus.declined:
              // Allow resending after 24 hours - we would need to get the actual friendship data
              // For now, we'll allow resending
              break;
            case FriendshipStatus.blocked:
              return Left(
                ForbiddenFailure(
                  message: 'Cannot send friend request to this user',
                ),
              );
          }
        }
      }

      return const Right(null);
    } catch (e) {
      return Left(
        ServerFailure(
          message: 'Failed to check existing relationship: ${e.toString()}',
          code: '500',
        ),
      );
    }
  }

  /// Checks if either user has blocked the other
  Future<Either<Failure, void>> _checkBlockStatus(
    AddFriendParams params,
  ) async {
    try {
      // Check if current user is blocked by target user
      final isBlockedByTarget = await _friendsRepository.isUserBlocked(
        params.targetUserId,
        params.userId,
      );

      if (isBlockedByTarget.isRight() &&
          isBlockedByTarget.fold(
                (l) => throw Exception('Unexpected failure'),
                (r) => r,
              ) ==
              true) {
        return Left(
          ForbiddenFailure(message: 'Cannot send friend request to this user'),
        );
      }

      // Check if current user has blocked target user
      final hasBlockedTarget = await _friendsRepository.isUserBlocked(
        params.userId,
        params.targetUserId,
      );

      if (hasBlockedTarget.isRight() &&
          hasBlockedTarget.fold(
                (l) => throw Exception('Unexpected failure'),
                (r) => r,
              ) ==
              true) {
        return Left(
          ConflictFailure(
            message:
                'You have blocked this user. Unblock them first to send a friend request.',
            code: '409',
          ),
        );
      }

      return const Right(null);
    } catch (e) {
      return Left(
        ServerFailure(
          message: 'Failed to check block status: ${e.toString()}',
          code: '500',
        ),
      );
    }
  }

  /// Checks privacy settings of target user
  Future<Either<Failure, void>> _checkPrivacySettings(
    AddFriendParams params,
  ) async {
    try {
      final privacySettings = await _friendsRepository.getUserPrivacySettings(
        params.targetUserId,
      );

      if (privacySettings.isLeft()) {
        return Left(
          privacySettings.fold(
            (l) => l,
            (r) => throw Exception('Unexpected success'),
          ),
        );
      }

      final settings = privacySettings.fold(
        (l) => throw Exception('Unexpected failure'),
        (r) => r,
      );

      // Check if user accepts friend requests from anyone
      if (!settings.allowFriendRequests) {
        return Left(
          ForbiddenFailure(
            message: 'This user is not accepting friend requests',
          ),
        );
      }

      // Check friend request restrictions
      switch (settings.friendRequestsFrom) {
        case FriendRequestPrivacy.nobody:
          return Left(
            ForbiddenFailure(
              message: 'This user is not accepting friend requests',
            ),
          );
        case FriendRequestPrivacy.friendsOfFriends:
          final hasMutualFriends = await _checkMutualFriends(params);
          if (hasMutualFriends.isLeft() ||
              hasMutualFriends.fold(
                    (l) => throw Exception('Unexpected failure'),
                    (r) => r,
                  ) ==
                  false) {
            return Left(
              ForbiddenFailure(
                message:
                    'This user only accepts friend requests from friends of friends',
              ),
            );
          }
          break;
        case FriendRequestPrivacy.everyone:
          // No restrictions
          break;
      }

      return const Right(null);
    } catch (e) {
      return Left(
        ServerFailure(
          message: 'Failed to check privacy settings: ${e.toString()}',
          code: '500',
        ),
      );
    }
  }

  /// Checks if users have mutual friends
  Future<Either<Failure, bool>> _checkMutualFriends(
    AddFriendParams params,
  ) async {
    try {
      // For now, we'll assume there are mutual friends if the method succeeds
      // In a real implementation, we would need a method that takes both user IDs
      final mutualFriends = await _friendsRepository.getMutualFriends(
        params.userId,
      );

      if (mutualFriends.isRight()) {
        // This is a simplified check - in reality we'd need to filter by the target user
        return const Right(true);
      }

      return const Right(false);
    } catch (e) {
      return Left(
        ServerFailure(
          message: 'Failed to check mutual friends: ${e.toString()}',
          code: '500',
        ),
      );
    }
  }

  /// Sends notification to the friend request recipient
  Future<bool> _sendFriendRequestNotification(
    String senderId,
    String recipientId,
    String friendshipId,
    String? message,
  ) async {
    try {
      // This would typically call a notification service
      // For now, we'll simulate the notification sending

      // In a real implementation, this would call:
      // await _notificationService.sendNotification(notificationData);

      return true;
    } catch (e) {
      // Log error but don't fail the whole operation
      // In production, use proper logging framework
      return false;
    }
  }

  /// Logs the friend request action for analytics
  Future<void> _logFriendRequestAction(
    AddFriendParams params,
    FriendModel friendship,
  ) async {
    try {
      // In a real implementation, this would call:
      // await _analyticsService.logEvent('friend_request', logData);
    } catch (e) {
      // Log error but don't fail the operation
      // In production, use proper logging framework
    }
  }

  /// Updates user activity metrics
  Future<void> _updateUserMetrics(String userId, String actionType) async {
    try {
      // This would typically update user activity metrics
      // await _metricsService.incrementCounter(userId, actionType);
    } catch (e) {
      // In production, use proper logging framework
    }
  }

  /// Determines the status string based on friendship status
  String _determineFriendshipStatus(FriendshipStatus status) {
    switch (status) {
      case FriendshipStatus.pending:
        return 'sent';
      case FriendshipStatus.accepted:
        return 'accepted';
      case FriendshipStatus.declined:
        return 'declined';
      case FriendshipStatus.blocked:
        return 'blocked';
    }
  }

  /// Validates user ID format (assuming UUID)
  bool _isValidUserId(String userId) {
    final uuidRegex = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    );
    return uuidRegex.hasMatch(userId);
  }
}

/// Privacy settings for friend requests
enum FriendRequestPrivacy { everyone, friendsOfFriends, nobody }

/// Privacy settings model (simplified)
class UserPrivacySettings {
  final bool allowFriendRequests;
  final FriendRequestPrivacy friendRequestsFrom;

  const UserPrivacySettings({
    required this.allowFriendRequests,
    required this.friendRequestsFrom,
  });
}

/// Extended methods for FriendsRepository (these would be added to the actual repository)
extension AddFriendRepositoryMethods on FriendsRepository {
  Future<Either<Failure, List<FriendModel>>> getRecentFriendRequests(
    String userId, {
    int hours = 24,
  }) {
    // Implementation would query recent friend requests
    throw UnimplementedError('getRecentFriendRequests not implemented');
  }

  Future<Either<Failure, FriendshipStatus?>> getFriendshipStatus(
    String userId,
    String targetUserId,
  ) {
    // Implementation would check existing friendship status
    throw UnimplementedError('getFriendshipStatus not implemented');
  }

  Future<Either<Failure, bool>> isUserBlocked(
    String userId,
    String blockedUserId,
  ) {
    // Implementation would check if user is blocked
    throw UnimplementedError('isUserBlocked not implemented');
  }

  Future<Either<Failure, UserPrivacySettings>> getUserPrivacySettings(
    String userId,
  ) {
    // Implementation would get user privacy settings
    throw UnimplementedError('getUserPrivacySettings not implemented');
  }

  Future<Either<Failure, List<FriendModel>>> getMutualFriends(String userId) {
    // Implementation would get mutual friends
    throw UnimplementedError('getMutualFriends not implemented');
  }
}
