import 'package:dabbler/core/config/feature_flags.dart';
import 'package:flutter_test/flutter_test.dart';

/// KAN-544: the Realtime flag is only valid with the two flags it hangs on.
/// KAN-554: all four launch flags are on in the committed code.
void main() {
  test('committed (KAN-554 launch): the realtime flag and the three chat flags are all true', () {
    expect(FeatureFlags.messagingRealtime, isTrue);
    expect(FeatureFlags.messaging, isTrue);
    expect(FeatureFlags.enableMessagingGameChat, isTrue);
    expect(FeatureFlags.enableMessagingReporting, isTrue);
  });

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

  test('the flag is nameable and enabled at launch (KAN-554)', () {
    expect(FeatureFlags.getFeatureFlag('messaging_realtime'), isTrue);
    expect(FeatureFlags.getEnabledFeatures(), contains('messaging_realtime'));
  });
}
