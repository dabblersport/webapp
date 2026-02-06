import 'package:fpdart/fpdart.dart';

import 'package:dabbler/core/fp/failure.dart';
import '../models/profile/user_profile.dart';

abstract class ProfileRepository {
  Future<Either<Failure, UserProfile>> fetchProfile(String userId);

  Future<Either<Failure, UserProfile>> upsertProfile(UserProfile profile);
}
