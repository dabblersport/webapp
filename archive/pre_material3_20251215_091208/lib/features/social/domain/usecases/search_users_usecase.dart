import 'package:fpdart/fpdart.dart';
import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/data/models/profile/user_profile.dart';

/// Parameters for searching users
class SearchUsersParams {
  final String query;
  final int page;
  final int limit;
  final List<String>? excludeUserIds;
  final Map<String, dynamic>? filters;

  const SearchUsersParams({
    required this.query,
    this.page = 1,
    this.limit = 20,
    this.excludeUserIds,
    this.filters,
  });
}

/// Result of user search operation
class SearchUsersResult {
  final List<UserProfile> users;
  final int totalCount;
  final int page;
  final int totalPages;
  final bool hasMore;

  const SearchUsersResult({
    required this.users,
    required this.totalCount,
    required this.page,
    required this.totalPages,
    required this.hasMore,
  });
}

/// Use case for searching users
class SearchUsersUseCase {
  const SearchUsersUseCase();

  Future<Either<Failure, SearchUsersResult>> call(
    SearchUsersParams params,
  ) async {
    try {
      // Mock implementation - in real app, this would call repository
      await Future.delayed(const Duration(milliseconds: 300));

      final mockUsers = [
        UserProfile(
          id: 'user1',
          userId: 'user1',
          email: 'john@example.com',
          displayName: 'John Doe',
          avatarUrl: null,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          bio: 'Software developer',
        ),
        UserProfile(
          id: 'user2',
          userId: 'user2',
          email: 'jane@example.com',
          displayName: 'Jane Smith',
          avatarUrl: null,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          bio: 'Designer',
        ),
      ];

      return Right(
        SearchUsersResult(
          users: mockUsers,
          totalCount: mockUsers.length,
          page: params.page,
          totalPages: 1,
          hasMore: false,
        ),
      );
    } catch (e) {
      return Left(
        ServerFailure(message: 'Failed to search users: ${e.toString()}'),
      );
    }
  }
}
