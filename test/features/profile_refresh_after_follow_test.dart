// KAN-970: refreshProfile must re-read the active persona by id, so a sport
// follow written to profiles.interests shows at once (not the cached copy).
import 'package:flutter_test/flutter_test.dart';

import 'package:dabbler/data/models/profile/user_profile.dart';
import 'package:dabbler/features/profile/domain/repositories/profile_repository.dart';
import 'package:dabbler/features/profile/domain/usecases/get_profile_usecase.dart';
import 'package:dabbler/features/profile/presentation/controllers/profile_controller.dart';

class _FakeGetProfile implements GetProfileUseCase {
  _FakeGetProfile(this.answer);

  List<String> answer;
  final List<String?> profileIds = <String?>[];

  @override
  ProfileRepository get repository => throw UnimplementedError();

  @override
  Future<UserProfile?> call(
    String userId, {
    String? profileType,
    bool filterActive = true,
    String? profileId,
  }) async {
    profileIds.add(profileId);
    return UserProfile(
      id: 'p1',
      userId: userId,
      displayName: 'T',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      interests: List<String>.of(answer),
    );
  }
}

void main() {
  test(
    'refreshProfile reloads by profile id and picks up new interests',
    () async {
      final fake = _FakeGetProfile(<String>['a']);
      final c = ProfileController(getProfileUseCase: fake);
      await c.loadProfile('u1');
      expect(c.state.profile?.interests, <String>['a']);

      fake.answer = <String>['a', 'b']; // the follow write
      await c.refreshProfile();
      expect(fake.profileIds.last, 'p1');
      expect(c.state.profile?.interests, <String>['a', 'b']);

      fake.answer = <String>['a']; // the unfollow write
      await c.refreshProfile();
      expect(c.state.profile?.interests, <String>['a']);
    },
  );
}
