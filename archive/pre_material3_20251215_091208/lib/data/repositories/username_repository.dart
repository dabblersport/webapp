import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/core/fp/failure.dart';
import '../models/profile.dart';

/// Username operations over the `profiles` table (citext unique).
///
/// RLS expectations:
/// - Read: owner rows via `profiles_select_owner`, public rows via `profiles_select_public (is_active=true)`.
/// - Update username: `profiles_update_owner` (auth.uid() == user_id).
/// Notes:
/// - Availability checks may be conservative due to RLS visibility; the UNIQUE index on `username` is the source of truth.
abstract class UsernameRepository {
  /// Returns true if no visible row uses this username (case-insensitive).
  Future<Result<bool, Failure>> isAvailable(String username);

  /// Get a profile by exact username (case-insensitive).
  Future<Result<Profile, Failure>> getByUsername(String username);

  /// Case-insensitive search on username (ilike); best-effort public listing.
  Future<Result<List<Profile>, Failure>> search({
    required String query,
    int limit = 20,
    int offset = 0,
  });

  /// Set username for the given profile (owned by current user).
  Future<Result<Profile, Failure>> setUsernameForProfile({
    required String profileId,
    required String username,
  });

  /// Set username for my profile by type ('player'|'organiser').
  Future<Result<Profile, Failure>> setMyUsernameForType({
    required String profileType,
    required String username,
  });

  /// Stream my profile by type to observe username changes.
  Stream<Result<Profile, Failure>> myProfileTypeStream(String profileType);
}
