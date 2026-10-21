import 'package:dabbler/core/cache/offline_cache.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// KAN-605: the on-device cache is keyed by account, stores fetchedAt, is
/// bounded with oldest-first eviction, and is wiped on sign-out / switch.
void main() {
  late SharedPreferences prefs;
  late OfflineCache cache;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    cache = OfflineCache(prefs: prefs);
  });

  test('round-trips a payload with its fetchedAt', () async {
    final at = DateTime(2026, 10, 21, 9);
    await cache.write('A', 'feed.foryou', [
      {'id': 1},
    ], fetchedAt: at);
    final hit = await cache.read('A', 'feed.foryou');
    expect(hit, isNotNull);
    expect(hit!.fetchedAt, at);
    expect(hit.payload, [
      {'id': 1},
    ]);
  });

  test('an account never reads another account\'s entries', () async {
    await cache.write('A', 'feed.foryou', ['a-post']);
    expect(await cache.read('B', 'feed.foryou'), isNull);
  });

  test('a missing or unreadable entry reads as no cache', () async {
    expect(await cache.read('A', 'nope'), isNull);
    await prefs.setString('offline_cache.v1.A.bad', '{not json');
    expect(await cache.read('A', 'bad'), isNull);
  });

  test('over the cap the oldest entries are evicted first', () async {
    final chunk = 'x' * (OfflineCache.maxBytesPerAccount ~/ 4);
    await cache.write(
      'A',
      'old',
      chunk,
      fetchedAt: DateTime(2026, 10, 1),
    );
    await cache.write(
      'A',
      'mid',
      chunk,
      fetchedAt: DateTime(2026, 10, 2),
    );
    await cache.write(
      'A',
      'new',
      chunk,
      fetchedAt: DateTime(2026, 10, 3),
    );
    expect(await cache.read('A', 'old'), isNotNull);

    await cache.write(
      'A',
      'newest',
      chunk,
      fetchedAt: DateTime(2026, 10, 4),
    );

    expect(await cache.read('A', 'old'), isNull, reason: 'oldest goes first');
    expect(await cache.read('A', 'newest'), isNotNull);
    expect(
      await cache.sizeOf('A'),
      lessThanOrEqualTo(OfflineCache.maxBytesPerAccount),
    );
  });

  test('one entry larger than the cap is not stored', () async {
    await cache.write('A', 'small', 'ok');
    await cache.write('A', 'huge', 'x' * (OfflineCache.maxBytesPerAccount + 1));
    expect(await cache.read('A', 'huge'), isNull);
    expect(await cache.read('A', 'small'), isNotNull);
  });

  test('wipe(keepAccountId) removes every other account', () async {
    await cache.write('A', 'k', 1);
    await cache.write('B', 'k', 2);
    await cache.wipe(keepAccountId: 'B');
    expect(await cache.read('A', 'k'), isNull);
    expect(await cache.read('B', 'k'), isNotNull);
  });

  test('wipe() removes everything, including the index', () async {
    await cache.write('A', 'k', 1);
    await cache.write('B', 'k', 2);
    await cache.wipe();
    expect(
      prefs.getKeys().where((k) => k.startsWith('offline_cache.')),
      isEmpty,
    );
  });

  test('a response already in flight at sign-out is not written back', () async {
    final started = DateTime.now();
    await Future<void>.delayed(const Duration(milliseconds: 5));
    await cache.wipe();
    await cache.write('A', 'k', 'late', requestStartedAt: started);
    expect(await cache.read('A', 'k'), isNull);

    // A request that began after the wipe is stored.
    await cache.write('A', 'k', 'fresh', requestStartedAt: DateTime.now());
    expect(await cache.read('A', 'k'), isNotNull);
  });

  test('only server payloads are stored: keys are namespaced, nothing else',
      () async {
    await cache.write('A', 'feed.foryou', ['p']);
    expect(
      prefs.getKeys().every((k) => k.startsWith('offline_cache.v1.A.')),
      isTrue,
    );
  });
}
