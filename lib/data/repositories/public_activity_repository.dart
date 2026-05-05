import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/data/models/social/public_activity.dart';

abstract class PublicActivityRepository {
  /// Fetches social activities from users the current user follows.
  Future<Result<List<PublicActivity>, Failure>> fetchFollowingActivities({
    int limit = 20,
    int offset = 0,
  });

  /// Fetches public activities for a specific profile (for their Activity tab).
  Future<Result<List<PublicActivity>, Failure>> fetchUserActivities({
    required String profileId,
    int limit = 20,
    int offset = 0,
  });
}
