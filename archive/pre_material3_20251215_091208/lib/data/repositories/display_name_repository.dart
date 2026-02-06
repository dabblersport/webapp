import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/core/fp/failure.dart';
import '../models/profile.dart';

/// Display-name operations on `profiles`.
///
/// RLS expectations:
/// - Read: owner rows via `profiles_select_owner`; public rows via `profiles_select_public (is_active=true)`.
/// - Update: owner-only via `profiles_update_owner` (auth.uid() == user_id).
/// Server constraints enforced:
/// - CHECK length (2..50)
/// - CHECK not conflicting with username: `display_name_conflicts_username(display_name, username)`
/// - UNIQUE on `display_name_norm` (nullable unique)
abstract class DisplayNameRepository {
  /// True if no visible row has the same `display_name_norm`.
  Future<Result<bool, Failure>> isAvailable(String displayName);

  /// Get profiles with display name (ilike on `display_name`), public-first.
  Future<Result<List<Profile>, Failure>> search({
    required String query,
    int limit = 20,
    int offset = 0,
  });

  /// Update a specific profile id (must be owned by current user).
  Future<Result<Profile, Failure>> setDisplayNameForProfile({
    required String profileId,
    required String displayName,
  });

  /// Update my profile for a given type ('player'|'organiser').
  Future<Result<Profile, Failure>> setMyDisplayNameForType({
    required String profileType,
    required String displayName,
  });

  /// Stream my profile (by type) so UI can react to changes.
  Stream<Result<Profile, Failure>> myProfileTypeStream(String profileType);
}
