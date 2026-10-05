import 'package:dabbler/core/config/feature_flags.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('enableMeetups is off by default', () {
    expect(FeatureFlags.enableMeetups, isFalse);
  });
}
