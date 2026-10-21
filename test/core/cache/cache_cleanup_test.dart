import 'dart:async';
import 'dart:convert';

import 'package:dabbler/core/cache/cache_cleanup.dart';
import 'package:dabbler/core/cache/cache_policy.dart';
import 'package:dabbler/core/cache/cache_providers.dart';
import 'package:dabbler/core/cache/offline_cache.dart';
import 'package:dabbler/core/sync/pending_settings_store.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// KAN-613: the scheduled cache cleanup removes entries older than the
/// interval, holds the size cap, refreshes (not removes) what is on screen,
/// and never touches a pending settings edit or the Home feed.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final t0 = DateTime(2026, 10, 21, 9);
  late SharedPreferences prefs;
  late OfflineCache cache;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    cache = OfflineCache(prefs: prefs);
  });

  Future<void> put(String key, DateTime at, {String account = 'A'}) =>
      cache.write(account, key, {'k': key}, fetchedAt: at);

  group('config', () {
    test('the default interval is 24 hours, in one constant', () {
      expect(kCacheCleanupInterval, const Duration(hours: 24));
    });
  });

  group('age eviction', () {
    test('removes entries older than the interval, keeps newer ones', () async {
      await put('games.list', t0.subtract(const Duration(hours: 25)));
      await put('venues.detail.1', t0.subtract(const Duration(hours: 23)));
      await put('meetups.card.9', t0);

      final r = await cache.cleanup('A', now: t0);

      expect(r.removed, ['games.list']);
      expect(await cache.read('A', 'games.list'), isNull);
      expect(await cache.read('A', 'venues.detail.1'), isNotNull);
      expect(await cache.read('A', 'meetups.card.9'), isNotNull);
    });

    test('an entry exactly at the interval is kept', () async {
      await put('games.list', t0.subtract(kCacheCleanupInterval));
      final r = await cache.cleanup('A', now: t0);
      expect(r.removed, isEmpty);
      expect(await cache.read('A', 'games.list'), isNotNull);
    });

    test('uses the given interval', () async {
      await put('games.list', t0.subtract(const Duration(hours: 2)));
      final r = await cache.cleanup(
        'A',
        now: t0,
        maxAge: const Duration(hours: 1),
      );
      expect(r.removed, ['games.list']);
    });

    test('the index forgets a removed entry', () async {
      await put('games.list', t0.subtract(const Duration(hours: 30)));
      await put('meetups.card.9', t0);
      final before = await cache.sizeOf('A');
      await cache.cleanup('A', now: t0);
      expect(await cache.sizeOf('A'), lessThan(before));
      expect(prefs.getString('offline_cache.v1.A.games.list'), isNull);
    });

    test('only the given account is cleaned', () async {
      await put('games.list', t0.subtract(const Duration(hours: 30)));
      await put(
        'games.list',
        t0.subtract(const Duration(hours: 30)),
        account: 'B',
      );
      await cache.cleanup('A', now: t0);
      expect(await cache.read('A', 'games.list'), isNull);
      expect(await cache.read('B', 'games.list'), isNotNull);
    });
  });

  group('size cap', () {
    /// Seeds [count] entries of [bytes] each straight into the store, oldest
    /// first, so the account is over the cap without a write evicting them.
    Future<void> seed(int count, int bytes, {String prefix = 'big.'}) async {
      final index = <String, List<int>>{};
      for (var i = 0; i < count; i++) {
        final at = t0.subtract(Duration(minutes: count - i)); // i=0 oldest
        index['$prefix$i'] = [at.millisecondsSinceEpoch, bytes];
        await prefs.setString(
          'offline_cache.v1.A.$prefix$i',
          jsonEncode({'t': at.millisecondsSinceEpoch, 'p': 'x'}),
        );
      }
      final old = prefs.getString('offline_cache.v1.A.__index');
      final merged = <String, dynamic>{
        if (old != null) ...jsonDecode(old) as Map<String, dynamic>,
        ...index,
      };
      await prefs.setString('offline_cache.v1.A.__index', jsonEncode(merged));
    }

    test('over the cap: the oldest entries go until it fits', () async {
      const chunk = 600 * 1024;
      await seed(4, chunk); // 2.4 MiB > 2 MiB
      final r = await cache.cleanup('A', now: t0);
      expect(r.removed, ['big.0']);
      expect(await cache.sizeOf('A'), lessThanOrEqualTo(2 * 1024 * 1024));
      expect(prefs.getString('offline_cache.v1.A.big.0'), isNull);
      expect(prefs.getString('offline_cache.v1.A.big.1'), isNotNull);
    });

    test('under the cap: nothing is evicted', () async {
      await seed(3, 100 * 1024);
      final r = await cache.cleanup('A', now: t0);
      expect(r.removed, isEmpty);
    });

    test('a feed-only cache over 2 MiB is trimmed to at most 2 MiB', () async {
      const chunk = 600 * 1024;
      await seed(4, chunk, prefix: 'feed.p'); // 2.4 MiB, all feed pages
      final r = await cache.cleanup('A', now: t0);
      expect(r.removed, ['feed.p0']); // oldest first
      expect(await cache.sizeOf('A'), lessThanOrEqualTo(2 * 1024 * 1024));
      expect(prefs.getString('offline_cache.v1.A.feed.p0'), isNull);
      expect(prefs.getString('offline_cache.v1.A.feed.p3'), isNotNull);
    });

    test(
      'the newest feed page survives the cap so the feed is not empty',
      () async {
        const chunk = 1500 * 1024;
        await seed(3, chunk, prefix: 'feed.q'); // 4.4 MiB
        await cache.cleanup('A', now: t0);
        expect(prefs.getString('offline_cache.v1.A.feed.q0'), isNull);
        expect(prefs.getString('offline_cache.v1.A.feed.q1'), isNull);
        expect(prefs.getString('offline_cache.v1.A.feed.q2'), isNotNull);
        expect(await cache.sizeOf('A'), lessThanOrEqualTo(2 * 1024 * 1024));
      },
    );

    test('feed pages stay exempt from age eviction', () async {
      await put('feed.foryou', t0.subtract(const Duration(days: 9)));
      final r = await cache.cleanup('A', now: t0);
      expect(r.removed, isEmpty);
    });

    test(
      'the cap never evicts a settings copy; the newest feed page stays',
      () async {
        const chunk = 600 * 1024;
        await seed(2, chunk, prefix: 'settings.s');
        await seed(1, chunk, prefix: 'feed.f');
        await seed(2, chunk, prefix: 'zz.');
        // 3 exempt (1.8 MiB) + 2 others (1.2 MiB): the others go, oldest first.
        await cache.cleanup('A', now: t0);
        expect(prefs.getString('offline_cache.v1.A.settings.s0'), isNotNull);
        expect(prefs.getString('offline_cache.v1.A.settings.s1'), isNotNull);
        expect(prefs.getString('offline_cache.v1.A.feed.f0'), isNotNull);
      },
    );
  });

  group('pending edits and the Home feed', () {
    test('a pending settings edit survives a cleanup 25 hours later', () async {
      const store = PendingSettingsStore();
      final edit = PendingSettingEdit(
        key: 'theme',
        value: const {'mode': 'dark'},
        editedAt: t0.toUtc(),
      );
      await store.put('A', edit);
      await put('settings.theme', t0, account: 'A');
      await put('games.list', t0);

      final later = t0.add(const Duration(hours: 25));
      final r = await cache.cleanup('A', now: later);

      expect(r.removed, ['games.list']);
      final left = await store.load('A');
      expect(left['theme']?.value, {'mode': 'dark'});
      expect(left['theme']?.editedAt, edit.editedAt);
      // The device copy of the setting is still there too.
      expect(await cache.read('A', 'settings.theme'), isNotNull);
    });

    test('the Home feed page is kept past the interval', () async {
      for (final k in [
        'feed.foryou',
        'feed.active',
        'feed.following',
        'feed.nearby',
        'feed.news',
      ]) {
        await put(k, t0);
      }
      final r = await cache.cleanup('A', now: t0.add(const Duration(days: 3)));
      expect(r.removed, isEmpty);
      for (final k in [
        'feed.foryou',
        'feed.active',
        'feed.following',
        'feed.nearby',
        'feed.news',
      ]) {
        expect(await cache.read('A', k), isNotNull, reason: k);
      }
    });

    test('a refresh that succeeds replaces the kept page', () async {
      await put('feed.foryou', t0);
      final later = t0.add(const Duration(days: 2));
      await cache.cleanup('A', now: later);
      await cache.write('A', 'feed.foryou', {'fresh': true}, fetchedAt: later);
      final hit = await cache.read('A', 'feed.foryou');
      expect(hit!.payload, {'fresh': true});
      expect(hit.fetchedAt, later);
    });
  });

  group('the entry on screen', () {
    test('a stale shown entry is kept and reported for refresh', () async {
      await put('games.list', t0.subtract(const Duration(hours: 30)));
      await put('venues.detail.1', t0.subtract(const Duration(hours: 30)));

      final r = await cache.cleanup('A', now: t0, shownKeys: {'games.list'});

      expect(r.refresh, ['games.list']);
      expect(r.removed, ['venues.detail.1']);
      expect(await cache.read('A', 'games.list'), isNotNull);
    });

    test('a live swrFetch provider is refreshed, not removed', () async {
      // swrFetch stamps its own writes with the real clock, so this test
      // moves "now" 25 hours past the real clock instead of using t0.
      final real = DateTime.now();
      await put('games.list', real.subtract(const Duration(hours: 5)));
      var fetches = 0;
      final container = ProviderContainer(
        overrides: [
          offlineCacheProvider.overrideWithValue(cache),
          cacheAccountIdProvider.overrideWith(
            (ref) => CacheAccountNotifier.fixed('A'),
          ),
        ],
      );
      addTearDown(container.dispose);
      final p = FutureProvider.autoDispose<List<String>>(
        (ref) => swrFetch<List<String>>(
          ref,
          key: 'games.list',
          fetch: () async {
            fetches++;
            return ['fresh'];
          },
          encode: (v) => v,
          decode: (j) => List<String>.from(j as List),
        ),
      );
      container.listen(p, (_, _) {}, fireImmediately: true);
      await pumpEventQueue(times: 50);
      final before = fetches;

      final scheduler = CacheCleanupScheduler(
        cache: cache,
        accountId: 'A',
        isOffline: () => false,
        now: () => real.add(const Duration(hours: 25)),
        prefs: prefs,
        observeLifecycle: false,
      );
      await pumpEventQueue(times: 50);
      addTearDown(scheduler.dispose);

      expect(await cache.read('A', 'games.list'), isNotNull);
      expect(fetches, greaterThan(before), reason: 'refreshed on screen');
    });

    test(
      'offline: the stale shown entry stays and no refresh is tried',
      () async {
        await put('games.list', t0.subtract(const Duration(hours: 30)));
        var refreshed = 0;
        final unregister = ShownCacheEntries.instance.register(
          'A',
          'games.list',
          () => refreshed++,
        );
        addTearDown(unregister);

        final scheduler = CacheCleanupScheduler(
          cache: cache,
          accountId: 'A',
          isOffline: () => true,
          now: () => t0,
          prefs: prefs,
          observeLifecycle: false,
        );
        await pumpEventQueue(times: 50);
        addTearDown(scheduler.dispose);

        expect(refreshed, 0);
        expect(await cache.read('A', 'games.list'), isNotNull);
      },
    );
  });

  group('schedule', () {
    CacheCleanupScheduler make(DateTime Function() now, {String? account}) =>
        CacheCleanupScheduler(
          cache: cache,
          accountId: account,
          isOffline: () => false,
          now: now,
          prefs: prefs,
          observeLifecycle: false,
        );

    test('runs at app start when it never ran', () async {
      await put('games.list', t0.subtract(const Duration(hours: 30)));
      final s = make(() => t0, account: 'A');
      addTearDown(s.dispose);
      await pumpEventQueue(times: 50);
      expect(await cache.read('A', 'games.list'), isNull);
      expect(prefs.getInt(CacheCleanupScheduler.lastRunKey), isNotNull);
    });

    test('does not run again before the interval has passed', () async {
      var now = t0;
      final s = make(() => now, account: 'A');
      addTearDown(s.dispose);
      await pumpEventQueue(times: 50);

      await put('games.list', now.subtract(const Duration(hours: 30)));
      now = t0.add(const Duration(hours: 23));
      expect(await s.isDue(), isFalse);
      expect(await s.runIfDue(), isNull);
      expect(await cache.read('A', 'games.list'), isNotNull);
    });

    test('runs again on resume once the interval has passed', () async {
      var now = t0;
      final s = make(() => now, account: 'A');
      addTearDown(s.dispose);
      await pumpEventQueue(times: 50);

      await put('games.list', now.subtract(const Duration(hours: 30)));
      now = t0.add(const Duration(hours: 25)); // the device clock moves
      expect(await s.isDue(), isTrue);
      s.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await pumpEventQueue(times: 50);
      expect(await cache.read('A', 'games.list'), isNull);
    });

    test('other lifecycle states do not run it', () async {
      var now = t0;
      final s = make(() => now, account: 'A');
      addTearDown(s.dispose);
      await pumpEventQueue(times: 50);
      await put('games.list', now.subtract(const Duration(hours: 30)));
      now = t0.add(const Duration(hours: 25));
      s.didChangeAppLifecycleState(AppLifecycleState.paused);
      await pumpEventQueue(times: 50);
      expect(await cache.read('A', 'games.list'), isNotNull);
    });

    test('a clock set back counts as due', () async {
      var now = t0;
      final s = make(() => now, account: 'A');
      addTearDown(s.dispose);
      await pumpEventQueue(times: 50);
      now = t0.subtract(const Duration(hours: 5));
      expect(await s.isDue(), isTrue);
    });

    test('signed out: nothing runs', () async {
      await put('games.list', t0.subtract(const Duration(hours: 30)));
      final s = make(() => t0);
      addTearDown(s.dispose);
      await pumpEventQueue(times: 50);
      expect(await cache.read('A', 'games.list'), isNotNull);
      expect(prefs.getInt(CacheCleanupScheduler.lastRunKey), isNull);
    });

    test('a pending settings edit survives the scheduled run', () async {
      const store = PendingSettingsStore();
      await store.put(
        'A',
        PendingSettingEdit(
          key: 'language',
          value: const {'code': 'ar'},
          editedAt: t0.toUtc(),
        ),
      );
      var now = t0;
      final s = make(() => now, account: 'A');
      addTearDown(s.dispose);
      await pumpEventQueue(times: 50);

      now = t0.add(const Duration(hours: 25));
      await s.runIfDue();
      expect((await store.load('A'))['language']?.value, {'code': 'ar'});
    });
  });
}
