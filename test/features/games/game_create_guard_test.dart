import 'package:dabbler/core/config/feature_flags.dart';
import 'package:dabbler/features/games/presentation/widgets/game_create_guard.dart';
import 'package:flutter_test/flutter_test.dart';

/// KAN-475: the one persona / feature-flag guard every Create game entry uses.
/// It must allow and deny exactly what the two route redirects did - copied
/// here verbatim as [_oldRedirectAllows] - for every profile type and every
/// flag combination. (The edit route had no redirect: always allowed.)
bool _oldRedirectAllows(
  String? profileType, {
  required bool playerFlag,
  required bool organiserFlag,
}) {
  // Block players from creating games if feature disabled.
  if (profileType == 'player' && !playerFlag) return false;
  // Block organisers from creating games if feature disabled.
  if (profileType == 'organiser' && !organiserFlag) return false;
  // Allow access if profile type has permission.
  return true;
}

void main() {
  const types = <String?>[
    'player',
    'organiser',
    'host',
    'socialiser',
    'unknown-type',
    '',
    null,
  ];

  for (final bool player in <bool>[true, false]) {
    for (final bool organiser in <bool>[true, false]) {
      for (final String? type in types) {
        test('type=$type playerFlag=$player organiserFlag=$organiser: '
            'same outcome as the redirects', () {
          expect(
            gameCreationAllowed(
              type,
              playerEnabled: player,
              organiserEnabled: organiser,
            ),
            _oldRedirectAllows(
              type,
              playerFlag: player,
              organiserFlag: organiser,
            ),
          );
        });
      }
    }
  }

  test('the defaults are the app feature flags', () {
    for (final type in types) {
      expect(
        gameCreationAllowed(type),
        _oldRedirectAllows(
          type,
          playerFlag: FeatureFlags.enablePlayerGameCreation,
          organiserFlag: FeatureFlags.enableOrganiserGameCreation,
        ),
      );
    }
  });
}
