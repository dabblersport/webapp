import 'package:dabbler/core/config/feature_flags.dart';
import 'package:flutter_test/flutter_test.dart';

/// KAN-544: the Realtime flag is off, and only valid with the two flags it
/// hangs on.
void main() {
  test(
    'committed: the realtime flag and the three chat flags are all false',
    () {
      expect(FeatureFlags.messagingRealtime, isFalse);
      expect(FeatureFlags.messaging, isFalse);
      expect(FeatureFlags.enableMessagingGameChat, isFalse);
      expect(FeatureFlags.enableMessagingReporting, isFalse);
    },
  );

  group('messagingRealtimeConsistent', () {
    for (final messaging in [false, true]) {
      for (final gameChat in [false, true]) {
        for (final realtime in [false, true]) {
          final expected = !realtime || (messaging && gameChat);
          test(
            'messaging=$messaging gameChat=$gameChat realtime=$realtime -> $expected',
            () {
              expect(
                FeatureFlags.messagingRealtimeConsistent(
                  messaging,
                  gameChat,
                  realtime,
                ),
                expected,
              );
            },
          );
        }
      }
    }

    test('realtime is consistent only with both flags on, or itself off', () {
      var consistentWithRealtimeOn = 0;
      for (final m in [false, true]) {
        for (final g in [false, true]) {
          if (FeatureFlags.messagingRealtimeConsistent(m, g, true))
            consistentWithRealtimeOn++;
        }
      }
      expect(consistentWithRealtimeOn, 1);
    });

    test('the committed values are consistent', () {
      expect(
        FeatureFlags.messagingRealtimeConsistent(
          FeatureFlags.messaging,
          FeatureFlags.enableMessagingGameChat,
          FeatureFlags.messagingRealtime,
        ),
        isTrue,
      );
    });
  });

  test('the flag is nameable but not enabled', () {
    expect(FeatureFlags.getFeatureFlag('messaging_realtime'), isFalse);
    expect(
      FeatureFlags.getEnabledFeatures(),
      isNot(contains('messaging_realtime')),
    );
  });
}
