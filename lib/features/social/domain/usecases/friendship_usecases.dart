import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/data/repositories/friends_repository.dart';
import 'package:uuid/uuid.dart';

/// Simplified use case for sending friend requests with validation
class SendFriendRequestUseCase {
  final FriendsRepository _repository;

  SendFriendRequestUseCase(this._repository);

  Future<Result<void, Failure>> call(String targetUserId) async {
    // Validate UUID format
    try {
      Uuid.parse(targetUserId);
    } catch (e) {
      return Err(const ValidationFailure(message: 'Invalid user ID format'));
    }

    // Cannot send request to self
    // Note: This check is also done in RLS policy

    return await _repository.sendFriendRequest(targetUserId);
  }
}

/// Use case for accepting friend requests
class AcceptFriendRequestUseCase {
  final FriendsRepository _repository;

  AcceptFriendRequestUseCase(this._repository);

  Future<Result<void, Failure>> call(String peerUserId) async {
    return await _repository.acceptFriendRequest(peerUserId);
  }
}

/// Use case for rejecting friend requests
class RejectFriendRequestUseCase {
  final FriendsRepository _repository;

  RejectFriendRequestUseCase(this._repository);

  Future<Result<void, Failure>> call(String peerUserId) async {
    return await _repository.rejectFriendRequest(peerUserId);
  }
}

/// Use case for removing friends
class RemoveFriendUseCase {
  final FriendsRepository _repository;

  RemoveFriendUseCase(this._repository);

  Future<Result<void, Failure>> call(String peerUserId) async {
    return await _repository.removeFriend(peerUserId);
  }
}

// NOTE: BlockUserUseCase/UnblockUserUseCase removed — use BlockRepository from block_providers.dart

/// Use case for getting friendship status
class GetFriendshipStatusUseCase {
  final FriendsRepository _repository;

  GetFriendshipStatusUseCase(this._repository);

  Future<Result<String, Failure>> call(String peerUserId) async {
    return await _repository.getFriendshipStatus(peerUserId);
  }

  Stream<Result<String, Failure>> stream(String peerUserId) {
    return _repository.getFriendshipStatusStream(peerUserId);
  }
}
