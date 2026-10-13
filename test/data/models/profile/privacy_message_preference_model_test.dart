import 'package:dabbler/data/models/profile/privacy_settings.dart';
import 'package:dabbler/data/models/profile/privacy_settings_model.dart';
import 'package:flutter_test/flutter_test.dart';

/// KAN-500: message_preference integer column, 0 anyone / 1 friendsOnly /
/// 2 organizersOnly / 3 none (D22). These pin the model mapping.
void main() {
  const expected = {
    CommunicationPreference.anyone: 0,
    CommunicationPreference.friendsOnly: 1,
    CommunicationPreference.organizersOnly: 2,
    CommunicationPreference.none: 3,
  };

  group('PrivacySettingsModel message_preference', () {
    for (final entry in expected.entries) {
      test('toJson writes ${entry.value} for ${entry.key.name}', () {
        final model = PrivacySettingsModel.fromEntity(
          PrivacySettings(messagePreference: entry.key),
        );
        expect(model.toJson()['message_preference'], entry.value);
      });

      test('fromJson reads ${entry.value} as ${entry.key.name}', () {
        final model = PrivacySettingsModel.fromJson({
          'message_preference': entry.value,
        });
        expect(model.messagePreference, entry.key);
      });

      test('round trip keeps ${entry.key.name}', () {
        final json = PrivacySettingsModel.fromEntity(
          PrivacySettings(messagePreference: entry.key),
        ).toJson();
        expect(
          PrivacySettingsModel.fromJson(json).messagePreference,
          entry.key,
        );
      });
    }

    test('out-of-range and null read as anyone (parser unchanged)', () {
      expect(
        PrivacySettingsModel.fromJson({
          'message_preference': 7,
        }).messagePreference,
        CommunicationPreference.anyone,
      );
      expect(
        PrivacySettingsModel.fromJson({
          'message_preference': -1,
        }).messagePreference,
        CommunicationPreference.anyone,
      );
      expect(
        PrivacySettingsModel.fromJson({
          'message_preference': null,
        }).messagePreference,
        CommunicationPreference.anyone,
      );
    });

    test('default is anyone, written as 0', () {
      expect(
        PrivacySettingsModel.fromEntity(
          const PrivacySettings(),
        ).toJson()['message_preference'],
        0,
      );
    });
  });
}
