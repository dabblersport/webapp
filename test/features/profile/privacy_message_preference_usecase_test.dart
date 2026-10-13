import 'package:dabbler/data/models/profile/privacy_settings.dart';
import 'package:dabbler/features/profile/domain/usecases/manage_privacy_usecase.dart';
import 'package:flutter_test/flutter_test.dart';

import 'privacy_fake_settings_repository.dart';

void main() {
  group('ManagePrivacyUseCase message_preference (KAN-500)', () {
    for (final entry in kMessagePreferenceInts.entries) {
      test('saves ${entry.key.name} as ${entry.value}', () async {
        final repo = FakeSettingsRepository(const PrivacySettings());
        final result = await ManagePrivacyUseCase(repo)(
          ManagePrivacyParams(userId: 'u1', messagePreference: entry.key),
        );
        expect(result.isRight, isTrue);
        expect(
          result.rightOrNull()!.updatedSettings.messagePreference,
          entry.key,
        );
        expect(repo.writtenMessagePreference, [entry.value]);
      });
    }

    test('unchanged preference writes the stored integer', () async {
      final repo = FakeSettingsRepository(
        const PrivacySettings(
          messagePreference: CommunicationPreference.organizersOnly,
        ),
      );
      await ManagePrivacyUseCase(repo)(
        const ManagePrivacyParams(userId: 'u1', showEmail: true),
      );
      expect(repo.writtenMessagePreference, [2]);
    });
  });
}
