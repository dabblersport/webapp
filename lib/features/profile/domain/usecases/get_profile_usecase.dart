import 'package:dabbler/data/models/profile/user_profile.dart';
import '../repositories/profile_repository.dart';

class GetProfileUseCase {
  final ProfileRepository repository;

  GetProfileUseCase(this.repository);

  Future<UserProfile?> call(
    String userId, {
    String? profileType,
    bool filterActive = true,
    String? profileId,
  }) async {
    final result = await repository.getProfile(
      userId,
      profileType: profileType,
      filterActive: filterActive,
      profileId: profileId,
    );
    return result.fold((_) => null, (profile) => profile);
  }
}
