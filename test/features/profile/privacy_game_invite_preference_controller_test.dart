import 'package:dabbler/data/models/profile/privacy_settings.dart';
import 'package:dabbler/features/profile/domain/usecases/manage_privacy_usecase.dart';
import 'package:dabbler/features/profile/presentation/controllers/privacy_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import 'privacy_fake_settings_repository.dart';

/// Controller wired to the use case only (no direct repository).
class _SeededController extends PrivacyController {
  _SeededController(FakeSettingsRepository repo)
    : super(managePrivacyUseCase: ManagePrivacyUseCase(repo)) {
    state = PrivacyState(settings: repo.stored);
  }
}

void main() {
  group(
    'PrivacyController.saveAllChanges game_invite_preference (KAN-501)',
    () {
      for (final entry in kMessagePreferenceInts.entries.where(
        (e) => e.key != CommunicationPreference.anyone,
      )) {
        test('saves ${entry.key.name} as ${entry.value}', () async {
          final repo = FakeSettingsRepository(const PrivacySettings());
          final c = _SeededController(repo);
          c.updateSetting('gameInvitePreference', entry.key);
          final ok = await c.saveAllChanges('u1');
          expect(c.state.errorMessage, isNull);
          expect(ok, isTrue);
          expect(repo.writtenGameInvitePreference, [entry.value]);
          expect(c.state.settings!.gameInvitePreference, entry.key);
        });
      }

      test(
        'another setting saved alongside gameInvitePreference does not throw',
        () async {
          final repo = FakeSettingsRepository(const PrivacySettings());
          final c = _SeededController(repo);
          c.updateSetting('showEmail', true);
          c.updateSetting(
            'gameInvitePreference',
            CommunicationPreference.organizersOnly,
          );
          final ok = await c.saveAllChanges('u1');
          expect(c.state.errorMessage, isNull);
          expect(ok, isTrue);
          expect(repo.stored.showEmail, isTrue);
          expect(repo.writtenGameInvitePreference, [2]);
        },
      );

      test(
        'gameInvitePreference unchanged writes the stored integer',
        () async {
          final repo = FakeSettingsRepository(
            const PrivacySettings(
              gameInvitePreference: CommunicationPreference.none,
            ),
          );
          final c = _SeededController(repo);
          c.updateSetting('showEmail', true);
          final ok = await c.saveAllChanges('u1');
          expect(ok, isTrue);
          expect(repo.writtenGameInvitePreference, [3]);
        },
      );
    },
  );
}
