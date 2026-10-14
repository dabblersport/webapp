import 'package:dabbler/core/config/feature_flags.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FeatureFlags.messagingFlagsConsistent (KAN-507 C1)', () {
    for (final messaging in [false, true]) {
      for (final gameChat in [false, true]) {
        for (final reporting in [false, true]) {
          final expected = !((messaging || gameChat) && !reporting);
          test('messaging=$messaging gameChat=$gameChat reporting=$reporting '
              '-> $expected', () {
            expect(
              FeatureFlags.messagingFlagsConsistent(
                messaging,
                gameChat,
                reporting,
              ),
              expected,
            );
          });
        }
      }
    }

    test('fails exactly for the three chat-on/reporting-off combinations', () {
      var failing = 0;
      for (final m in [false, true]) {
        for (final g in [false, true]) {
          for (final r in [false, true]) {
            if (!FeatureFlags.messagingFlagsConsistent(m, g, r)) failing++;
          }
        }
      }
      expect(failing, 3);
    });
  });

  test('committed flag values are consistent and all false (AC2)', () {
    expect(FeatureFlags.messaging, isFalse);
    expect(FeatureFlags.enableMessagingGameChat, isFalse);
    expect(FeatureFlags.enableMessagingReporting, isFalse);
    expect(
      FeatureFlags.messagingFlagsConsistent(
        FeatureFlags.messaging,
        FeatureFlags.enableMessagingGameChat,
        FeatureFlags.enableMessagingReporting,
      ),
      isTrue,
    );
  });
}
