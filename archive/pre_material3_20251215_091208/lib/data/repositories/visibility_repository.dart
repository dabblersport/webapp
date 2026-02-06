import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/core/fp/failure.dart';

/// Client-side mirror of server visibility logic.
/// Safe heuristic only—server RLS remains the source of truth.
abstract class VisibilityRepository {
  /// Is the current viewer allowed to see an entity owned by [ownerId]
  /// with the given [visibility]?
  ///
  /// Fail-closed on any ambiguity or error.
  Future<Result<bool, Failure>> canViewOwner({
    required String ownerId,
    required String visibility,
  });

  /// Alias; same semantics as [canViewOwner].
  Future<Result<bool, Failure>> canReadRow({
    required String ownerId,
    required String visibility,
  });

  /// Low-level helper: mirror of server-side social relation.
  /// True if there's an accepted or pending friendship between current user and [otherUserId].
  Future<Result<bool, Failure>> areSynced(String otherUserId);

  /// Best-effort admin check. If the check is forbidden/unavailable, returns false.
  Future<Result<bool, Failure>> isAdmin();
}
