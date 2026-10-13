import 'package:dabbler/data/models/profile/privacy_settings.dart';
import 'package:dabbler/features/profile/domain/usecases/manage_privacy_usecase.dart';
import 'package:flutter_test/flutter_test.dart';

import 'privacy_fake_settings_repository.dart';

void main() {
  group('ManagePrivacyUseCase game_invite_preference (KAN-501)', () {
    for (final entry in kMessagePreferenceInts.entries) {
      test('saves ${entry.key.name} as ${entry.value}', () async {
        final repo = FakeSettingsRepository(const PrivacySettings());
        final result = await ManagePrivacyUseCase(repo)(
          ManagePrivacyParams(userId: 'u1', gameInvitePreference: entry.key),
        );
        expect(result.isRight, isTrue);
        expect(
          result.rightOrNull()!.updatedSettings.gameInvitePreference,
          entry.key,
        );
        expect(repo.writtenGameInvitePreference, [entry.value]);
      });

      test('private profile keeps ${entry.key.name}', () async {
        final repo = FakeSettingsRepository(const PrivacySettings());
        await ManagePrivacyUseCase(repo)(
          ManagePrivacyParams(
            userId: 'u1',
            profileVisibility: false,
            gameInvitePreference: entry.key,
          ),
        );
        expect(repo.writtenGameInvitePreference, [entry.value]);
      });
    }

    test('unchanged preference writes the stored integer', () async {
      final repo = FakeSettingsRepository(
        const PrivacySettings(
          gameInvitePreference: CommunicationPreference.organizersOnly,
        ),
      );
      await ManagePrivacyUseCase(repo)(
        const ManagePrivacyParams(userId: 'u1', showEmail: true),
      );
      expect(repo.writtenGameInvitePreference, [2]);
    });

    test('legacy allowGameInvitations bool still maps to 0 / 3', () async {
      final repo = FakeSettingsRepository(const PrivacySettings());
      final uc = ManagePrivacyUseCase(repo);
      await uc(
        const ManagePrivacyParams(userId: 'u1', allowGameInvitations: false),
      );
      await uc(
        const ManagePrivacyParams(userId: 'u1', allowGameInvitations: true),
      );
      expect(repo.writtenGameInvitePreference, [3, 0]);
    });

    test('message_preference still saved alongside (KAN-500 guard)', () async {
      final repo = FakeSettingsRepository(const PrivacySettings());
      await ManagePrivacyUseCase(repo)(
        const ManagePrivacyParams(
          userId: 'u1',
          messagePreference: CommunicationPreference.friendsOnly,
          gameInvitePreference: CommunicationPreference.none,
        ),
      );
      expect(repo.writtenMessagePreference, [1]);
      expect(repo.writtenGameInvitePreference, [3]);
    });
  });
}
