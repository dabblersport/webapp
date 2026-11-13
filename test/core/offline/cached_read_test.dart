import 'package:dabbler/core/cache/offline_cache.dart';
import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/core/offline/cached_read.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// KAN-655: reads go through the on-device cache; offline serves it stale.
void main() {
  late OfflineCache cache;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    cache = OfflineCache(prefs: prefs);
  });

  Future<Result<CachedRead<List<String>>, Failure>> read({
    required Future<Result<List<String>, Failure>> Function() fetch,
    bool offline = false,
    String? account = 'A',
  }) => readThrough<List<String>>(
    cache: cache,
    accountId: account,
    key: 'games.upcoming.u1',
    isOffline: () => offline,
    fetch: fetch,
    encode: (v) => v,
    decode: (j) => List<String>.from(j as List),
    cap: (v) => v.take(2).toList(),
  );

  Future<Result<List<String>, Failure>> ok(List<String> v) async => Ok(v);

  test('online fetch returns fresh and writes the cache (first page only)',
      () async {
    final r = await read(fetch: () => ok(['a', 'b', 'c']));
    final got = r.requireValue;
    expect(got.value, ['a', 'b', 'c']);
    expect(got.isStale, isFalse);
    expect(got.cachedAt, isNull);
    expect((await cache.read('A', 'games.upcoming.u1'))!.payload, ['a', 'b']);
  });

  test('a network failure returns the cached copy, stale, with cachedAt',
      () async {
    final at = DateTime.utc(2026, 10, 1);
    await cache.write('A', 'games.upcoming.u1', ['old'], fetchedAt: at);
    final r = await read(
      fetch: () async =>
          const Err(Failure(category: FailureCode.noInternet)),
    );
    final got = r.requireValue;
    expect(got.value, ['old']);
    expect(got.isStale, isTrue);
    expect(got.cachedAt!.toUtc(), at);
  });

  test('a timeout also serves the cached copy', () async {
    await cache.write('A', 'games.upcoming.u1', ['old']);
    final r = await read(
      fetch: () async => const Err(Failure(category: FailureCode.timeout)),
    );
    expect(r.requireValue.isStale, isTrue);
  });

  test('offline never calls the network and serves the cache', () async {
    await cache.write('A', 'games.upcoming.u1', ['old']);
    var called = false;
    final r = await read(
      offline: true,
      fetch: () {
        called = true;
        return ok(['new']);
      },
    );
    expect(called, isFalse);
    expect(r.requireValue.value, ['old']);
    expect(r.requireValue.isStale, isTrue);
  });

  test('offline with no cached copy is a typed offline Err, not a throw',
      () async {
    final r = await read(offline: true, fetch: () => ok(['x']));
    final f = r.requireError;
    expect(f.code, kOfflineCacheMiss);
    expect(f.isNoInternet, isTrue);
  });

  test('a network failure with no cached copy is the same typed Err',
      () async {
    final r = await read(
      fetch: () async =>
          const Err(Failure(category: FailureCode.noInternet)),
    );
    expect(r.requireError.code, kOfflineCacheMiss);
  });

  test('a non-network failure passes through and does not use the cache',
      () async {
    await cache.write('A', 'games.upcoming.u1', ['old']);
    final r = await read(
      fetch: () async => const Err(Failure(category: FailureCode.server)),
    );
    expect(r.requireError.category, FailureCode.server);
  });

  test('signed out just fetches and caches nothing', () async {
    final r = await read(account: null, fetch: () => ok(['a']));
    expect(r.requireValue.value, ['a']);
    expect(await cache.read('A', 'games.upcoming.u1'), isNull);
  });

  test('sign-out wipe clears the entries', () async {
    await read(fetch: () => ok(['a']));
    expect(await cache.read('A', 'games.upcoming.u1'), isNotNull);
    await OfflineCache.wipeAll();
    await cache.wipe();
    expect(await cache.read('A', 'games.upcoming.u1'), isNull);
    final r = await read(offline: true, fetch: () => ok(['a']));
    expect(r.requireError.code, kOfflineCacheMiss);
  });
}
