import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/core/fp/failure.dart';
import '../models/profile.dart';

/// `ProfilesRepository` (this file) is Result-based: every method returns
/// `Result<T, Failure>`. `Result` is CLAUDE.md's convention for new code.
///
/// A separate Either-based profile stack also exists: the domain
/// `ProfileRepository` in `lib/features/profile/domain/repositories/` and its
/// `ProfileRepositoryImpl` in `features/profile/data/repositories/`, whose
/// methods return `Either<Failure, T>`. That stack is live — it is reached
/// through `profileControllerProvider`, from the router and from the venues,
/// sports and home slices among others. For the current call sites, run:
///   grep -rn "profileControllerProvider" lib/
/// It is frozen: no new methods are added to it.

abstract class ProfilesRepository {
  /// Owner read: relies on policy `profiles_select_owner` (auth.uid() = user_id)
  Future<Result<Profile, Failure>> getMyProfile();

  /// Owner/public read by user_id (owner if same uid; otherwise requires is_active=true via public policy)
  Future<Result<Profile, Failure>> getByUserId(String userId);

  /// Public read by username (requires is_active = true)
  Future<Result<Profile?, Failure>> getPublicByUsername(String username);

  /// Owner upsert: user_id must equal auth.uid(); relies on `profiles_insert_self` or `profiles_update_owner`
  Future<Result<void, Failure>> upsert(Profile profile);

  /// Deactivate (bench) myself by setting is_active=false
  Future<Result<void, Failure>> deactivateMe();

  /// Reactivate (unbench) myself by setting is_active=true
  Future<Result<void, Failure>> reactivateMe();

  /// Soft delete profile
  Future<Result<void, Failure>> deleteSoft(String userId);

  /// Realtime stream of my profile row (owner scope)
  Stream<Result<Profile?, Failure>> watchMyProfile();
}
