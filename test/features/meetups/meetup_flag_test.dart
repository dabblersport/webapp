import 'package:dabbler/core/config/feature_flags.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // ON for the Alpha test build (CEO decision 2026-10-05). The live DB
  // migrations are pending; turn this off again, and flip this expectation
  // back, before any merge to Canary/main.
  test('enableMeetups is on for the Alpha test build', () {
    expect(FeatureFlags.enableMeetups, isTrue);
  });
}
