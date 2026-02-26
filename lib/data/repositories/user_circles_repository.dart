import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import '../models/user_circle.dart';

/// Abstract contract for managing named user circles.
///
/// Named circles let users curate groups of followers and share
/// posts exclusively with those groups.
///
/// DB tables expected:
///   - `circles`        (id, owner_profile_id, name, created_at)
///   - `circle_members` (circle_id, member_profile_id, added_at)
abstract class UserCirclesRepository {
  /// Returns all circles owned by the authenticated user, ordered newest-first.
  Future<Result<List<UserCircle>, Failure>> listCircles({
    required String ownerProfileId,
  });

  /// Creates a new circle with the given [name].
  Future<Result<UserCircle, Failure>> createCircle({
    required String ownerProfileId,
    required String name,
  });

  /// Renames the circle identified by [circleId].
  Future<Result<UserCircle, Failure>> updateCircle(
    String circleId, {
    required String ownerProfileId,
    required String name,
  });

  /// Permanently deletes a circle and all its members.
  Future<Result<void, Failure>> deleteCircle(
    String circleId, {
    required String ownerProfileId,
  });

  /// Returns all members of a circle, with profile details.
  Future<Result<List<CircleMember>, Failure>> getCircleMembers(String circleId);

  /// Adds [memberProfileId] to the circle.
  Future<Result<void, Failure>> addMember(
    String circleId,
    String memberProfileId, {

    /// Optional convenience for callers; ignored if the DB schema doesn't
    /// store user_id in the membership row.
    String? memberUserId,
  });

  /// Removes [memberProfileId] from the circle.
  Future<Result<void, Failure>> removeMember(
    String circleId,
    String memberProfileId,
  );

  /// Returns the current user's followers (people who follow them).
  /// Used to populate the "add followers" list, ordered by recency.
  Future<Result<List<Map<String, dynamic>>, Failure>> getFollowers({
    required String ownerProfileId,
  });
}
