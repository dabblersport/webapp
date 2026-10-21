import 'dart:async';

import 'package:dabbler/core/cache/cache_providers.dart';
import 'package:dabbler/core/cache/offline_cache.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// KAN-605: listings and details show the cached copy first, refresh in the
/// background, and a failed background refresh is silent.
void main() {
  late OfflineCache cache;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    cache = OfflineCache(prefs: prefs);
  });

  ProviderContainer containerFor(String? account) => ProviderContainer(
    overrides: [
      offlineCacheProvider.overrideWithValue(cache),
      cacheAccountIdProvider.overrideWith(
        (ref) => CacheAccountNotifier.fixed(account),
      ),
    ],
  );

  AutoDisposeFutureProvider<List<String>> listing(
    Future<List<String>> Function() fetch,
  ) => FutureProvider.autoDispose<List<String>>(
    (ref) => swrFetch<List<String>>(
      ref,
      key: 'games.list',
      fetch: fetch,
      encode: (v) => v,
      decode: (j) => List<String>.from(j as List),
    ),
  );

  test('no cache: fetches, stores, and a failure is the error', () async {
    final c = containerFor('A');
    addTearDown(c.dispose);
    final ok = listing(() async => ['g1']);
    expect(await c.read(ok.future), ['g1']);
    expect((await cache.read('A', 'games.list'))!.payload, ['g1']);

    final c2 = containerFor('B');
    addTearDown(c2.dispose);
    final bad = listing(() async => throw StateError('offline'));
    await expectLater(c2.read(bad.future), throwsStateError);
  });

  test('cache hit: returns the cached copy at once, then the fresh one',
      () async {
    await cache.write('A', 'games.list', ['old']);
    final gate = Completer<List<String>>();
    final c = containerFor('A');
    addTearDown(c.dispose);
    final p = listing(() => gate.future);
    final values = <List<String>?>[];
    c.listen(p, (_, next) => values.add(next.valueOrNull), fireImmediately: true);

    // The network has not answered, yet the cached copy is there.
    await pumpEventQueue();
    expect(c.read(p).valueOrNull, ['old']);

    gate.complete(['new']);
    await pumpEventQueue(times: 50);
    expect(c.read(p).valueOrNull, ['new']);
    expect((await cache.read('A', 'games.list'))!.payload, ['new']);
  });

  test('a failed background refresh is silent and keeps the cached copy',
      () async {
    await cache.write('A', 'games.list', ['old']);
    final c = containerFor('A');
    addTearDown(c.dispose);
    final p = listing(() async => throw StateError('no internet'));
    c.listen(p, (_, __) {}, fireImmediately: true);
    await pumpEventQueue(times: 50);
    final v = c.read(p);
    expect(v.hasError, isFalse);
    expect(v.valueOrNull, ['old']);
  });

  test('an explicit refresh goes to the network, cache only covers failure',
      () async {
    await cache.write('A', 'games.list', ['old']);
    var online = true;
    final c = containerFor('A');
    addTearDown(c.dispose);
    final p = listing(() async {
      if (!online) throw StateError('no internet');
      return ['fresh'];
    });
    c.listen(p, (_, __) {}, fireImmediately: true);
    await pumpEventQueue(times: 50);
    expect(c.read(p).valueOrNull, ['fresh']);

    online = false;
    c.invalidate(p);
    await pumpEventQueue(times: 50);
    expect(c.read(p).valueOrNull, ['fresh'], reason: 'cache covers the failure');
  });

  test('another account never sees this account\'s cached copy', () async {
    await cache.write('A', 'games.list', ['a-only']);
    final c = containerFor('B');
    addTearDown(c.dispose);
    final p = listing(() async => throw StateError('no internet'));
    await expectLater(c.read(p.future), throwsStateError);
  });

  test('signed out: nothing is read or written', () async {
    final c = containerFor(null);
    addTearDown(c.dispose);
    final p = listing(() async => ['x']);
    expect(await c.read(p.future), ['x']);
    expect(await cache.sizeOf('A'), 0);
  });
}
