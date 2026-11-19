// The notification that launched the app is handled once, also across a
// process restart that hands the same launch payload back.

import 'package:dabbler/services/notifications/launch_once.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('the same launch payload is handled once', () async {
    final first = LaunchOnce(SharedPreferences.getInstance);
    expect(await first.claim('fcm:m1'), isTrue);
    expect(await first.claim('fcm:m1'), isFalse);
    // A new process (fresh instance) reading the same payload again.
    final relaunch = LaunchOnce(SharedPreferences.getInstance);
    expect(await relaunch.claim('fcm:m1'), isFalse);
    expect(await relaunch.claim('fcm:m2'), isTrue);
  });

  test('a payload without an id is let through', () async {
    final once = LaunchOnce(SharedPreferences.getInstance);
    expect(await once.claim(null), isTrue);
    expect(await once.claim(null), isTrue);
  });

  test('only recent ids are kept', () async {
    final once = LaunchOnce(SharedPreferences.getInstance);
    for (var i = 0; i < 30; i++) {
      await once.claim('id$i');
    }
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList(LaunchOnce.prefsKey)!.length, 20);
  });
}
