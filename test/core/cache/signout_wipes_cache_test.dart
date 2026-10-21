import 'dart:io';

import 'package:dabbler/core/cache/offline_cache.dart';
import 'package:dabbler/core/services/auth_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/home/home_test_harness.dart';

/// Every request fails as if the device had no connection.
class _Offline extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      throw const SocketException('Network is unreachable');
}

/// KAN-605: signing out wipes the on-device cache, also when the sign-out
/// happens offline.
void main() {
  setUpAll(initHomeTestSupabase);

  test('an offline sign-out still wipes every account\'s cache', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await OfflineCache.instance.write('A', 'feed.foryou', ['a-post']);
    await OfflineCache.instance.write('B', 'feed.foryou', ['b-post']);
    expect(await OfflineCache.instance.read('A', 'feed.foryou'), isNotNull);

    await HttpOverrides.runWithHttpOverrides(
      () => AuthService().signOut(),
      _Offline(),
    );

    expect(await OfflineCache.instance.read('A', 'feed.foryou'), isNull);
    expect(await OfflineCache.instance.read('B', 'feed.foryou'), isNull);
    expect(
      prefs.getKeys().where((k) => k.startsWith('offline_cache.')),
      isEmpty,
    );
  });
}
