import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dabbler/core/cache/cache_policy.dart';
import 'package:dabbler/core/cache/cache_providers.dart';
import 'package:dabbler/core/cache/offline_cache.dart';
import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/core/offline/cached_read.dart';
import 'package:dabbler/features/games/data/models/nearby_game_model.dart';
import 'package:dabbler/features/meetups/domain/models/meetup_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// KAN-748: the event cache invalidation contract — which change invalidates
/// which keys, shown copies refreshed once, and no late write after an
/// account switch.
void main() {
  // The event key families in use today (grep of lib/features).
  const gameList = 'games.list.x.x.null.null.dateAsc.Dubai|UAE|AE';
  const gameListSport = 'games.list.x.x.null.s1.dateAsc.x';
  const gameMine = 'games.mine.s1';
  const gameUpcoming = 'games.upcoming.u1';
  const meetupList = 'meetups.list.s1';
  const meetupNearby = 'meetups.nearby.25.200.55.300.10000.0';
  const meetupCard1 = 'meetups.card.m1';
  const meetupCard2 = 'meetups.card.m2';
  const unrelated = 'settings.privacy';
  const allKeys = [
    gameList,
    gameListSport,
    gameMine,
    gameUpcoming,
    meetupList,
    meetupNearby,
    meetupCard1,
    meetupCard2,
    unrelated,
  ];

  Set<String> hit(EventCacheChange c) => {
    for (final k in allKeys)
      if (isInvalidatedBy(c, k)) k,
  };

  group('contract: change -> key families', () {
    const gameLists = {gameList, gameListSport, gameMine, gameUpcoming};
    const meetupLists = {meetupList, meetupNearby};

    test('game created / edited / cancelled -> every game list', () {
      for (final c in [
        const EventCacheChange.created(CachedEventKind.game, 'g1'),
        const EventCacheChange.edited(CachedEventKind.game, 'g1'),
        const EventCacheChange.cancelled(CachedEventKind.game, 'g1'),
      ]) {
        expect(hit(c), gameLists, reason: c.type.name);
      }
    });

    test('meetup created -> meetup lists only (no detail exists yet)', () {
      expect(
        hit(const EventCacheChange.created(CachedEventKind.meetup, 'm1')),
        meetupLists,
      );
    });

    test('meetup edited / cancelled -> its card + the meetup lists', () {
      for (final c in [
        const EventCacheChange.edited(CachedEventKind.meetup, 'm1'),
        const EventCacheChange.cancelled(CachedEventKind.meetup, 'm1'),
      ]) {
        expect(hit(c), {...meetupLists, meetupCard1}, reason: c.type.name);
      }
    });

    test('the id keeps its meaning: game g1 never hits meetups.card.g1', () {
      expect(
        isInvalidatedBy(
          const EventCacheChange.cancelled(CachedEventKind.game, 'm1'),
          meetupCard1,
        ),
        isFalse,
      );
      expect(
        isInvalidatedBy(
          const EventCacheChange.edited(CachedEventKind.meetup, 'm1'),
          'meetups.card.m10',
        ),
        isFalse,
      );
    });

    test('city changed -> the location-scoped lists', () {
      expect(hit(const EventCacheChange.cityChanged()), {
        gameList,
        gameListSport,
        meetupNearby,
      });
    });

    test('sport changed -> the sport-scoped lists', () {
      expect(hit(const EventCacheChange.sportChanged()), {
        gameList,
        gameListSport,
        gameMine,
        meetupList,
      });
    });

    test('account changed -> everything of the old account', () {
      expect(hit(const EventCacheChange.accountChanged('A')), allKeys.toSet());
    });
  });

  group('invalidator', () {
    late OfflineCache cache;
    late String? account;
    late EventCacheInvalidator invalidator;
    final unregister = <void Function()>[];

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      cache = OfflineCache(prefs: await SharedPreferences.getInstance());
      account = 'A';
      invalidator = EventCacheInvalidator(
        cache: cache,
        currentAccountId: () => account,
      );
      for (final k in allKeys) {
        await cache.write('A', k, {'k': k});
      }
    });

    tearDown(() {
      for (final u in unregister) {
        u();
      }
      unregister.clear();
    });

    /// Registers a shown copy and returns its refresh counter.
    List<int> show(String acct, String key) {
      final count = [0];
      unregister.add(
        ShownCacheEntries.instance.register(acct, key, () => count[0]++),
      );
      return count;
    }

    Future<Set<String>> stored(String acct) async => {
      for (final k in allKeys)
        if (await cache.read(acct, k) != null) k,
    };

    test('edit: unshown matches removed, shown ones kept and refreshed '
        'exactly once', () async {
      final shownCard = show('A', meetupCard1);
      final shownList = show('A', meetupList);
      final shownOther = show('A', gameMine);
      final secondCopy = show('A', meetupCard1); // two providers, one key

      await invalidator.invalidate(
        const EventCacheChange.edited(CachedEventKind.meetup, 'm1'),
      );

      expect(shownCard[0], 1);
      expect(secondCopy[0], 1);
      expect(shownList[0], 1);
      expect(shownOther[0], 0);
      // meetups.nearby was not shown: removed. The shown card and list stay
      // as the offline fallback until their network-first refresh answers.
      expect(await stored('A'), allKeys.toSet()..remove(meetupNearby));
    });

    test('cancel: the event card and its lists are removed even when '
        'shown, then the shown copies refresh once', () async {
      final shownCard = show('A', meetupCard1);
      await invalidator.invalidate(
        const EventCacheChange.cancelled(CachedEventKind.meetup, 'm1'),
      );
      expect(shownCard[0], 1);
      expect(
        await stored('A'),
        allKeys.toSet()..removeAll([meetupCard1, meetupList, meetupNearby]),
      );
      // And never readable by another account.
      expect(await cache.read('B', meetupCard1), isNull);
    });

    test('game created / city / sport each remove their families', () async {
      final shownCity = show('A', gameList);
      await invalidator.invalidate(const EventCacheChange.cityChanged());
      expect(shownCity[0], 1);
      expect(await cache.read('A', meetupNearby), isNull);
      expect(await cache.read('A', gameListSport), isNull);

      await invalidator.invalidate(const EventCacheChange.sportChanged());
      expect(shownCity[0], 2);
      expect(await cache.read('A', gameMine), isNull);
      expect(await cache.read('A', meetupList), isNull);
      expect(await cache.read('A', gameUpcoming), isNotNull);

      await invalidator.invalidate(
        const EventCacheChange.created(CachedEventKind.game, 'g9'),
      );
      expect(shownCity[0], 3);
      expect(await cache.read('A', gameUpcoming), isNull);
      expect(await cache.read('A', meetupCard1), isNotNull);
      expect(await cache.read('A', unrelated), isNotNull);
    });

    test('account change: the old account is wiped and its shown copies '
        'refresh once (they re-run as the new account)', () async {
      final shown = show('A', meetupCard1);
      account = 'B';
      await invalidator.invalidate(const EventCacheChange.accountChanged('A'));
      expect(shown[0], 1);
      expect(await stored('A'), isEmpty);
    });

    test('signed out: an event change does nothing', () async {
      final shown = show('A', meetupCard1);
      account = null;
      await invalidator.invalidate(
        const EventCacheChange.edited(CachedEventKind.meetup, 'm1'),
      );
      expect(shown[0], 0);
      expect(await stored('A'), allKeys.toSet());
    });

    test('the invalidator issues no Supabase / shared-column write', () {
      // It ran above with no Supabase initialised (any client access would
      // throw). Its source holds no client call either.
      final src = File(
        'lib/core/cache/cache_providers.dart',
      ).readAsStringSync();
      final start = src.indexOf('class EventCacheInvalidator');
      expect(start, isNot(-1));
      final body = src.substring(start, src.indexOf('\n}\n', start));
      for (final banned in [
        'Supabase',
        '.from(',
        '.rpc(',
        '.insert(',
        '.update(',
        '.upsert(',
        '.delete(',
        'functions',
      ]) {
        expect(body, isNot(contains(banned)), reason: banned);
      }
    });
  });

  group('records with null fields', () {
    test('a meetup card with null title / end / sport survives the cache, '
        'id is the meetup id', () async {
      SharedPreferences.setMockInitialValues({});
      final cache = OfflineCache(prefs: await SharedPreferences.getInstance());
      const card = MeetupCard(id: 'm1');
      await cache.write('A', meetupCard1, card.toJson());
      final back = MeetupCard.fromJson(
        Map<String, dynamic>.from(
          jsonDecode(jsonEncode((await cache.read('A', meetupCard1))!.payload))
              as Map,
        ),
      );
      expect(back.id, 'm1');
      expect(back.title, isNull);
      expect(back.endAt, isNull);
      expect(back.sportKey, isNull);
      expect(back.startAt, isNull);
    });

    test('a nearby game row with null sport / end parses; id is games.id', () {
      final m = NearbyGameModel.fromJson({
        'id': 'g1',
        'title': 'Five',
        'sport_name': null,
        'end_at': null,
        'scheduled_at': '2026-11-02T18:00:00.000Z',
      });
      final back = NearbyGameModel.fromJson(
        Map<String, dynamic>.from(jsonDecode(jsonEncode(m.toJson())) as Map),
      );
      expect(back.id, 'g1');
      expect(back.sportName, isNull);
      expect(back.endAt, isNull);
      expect(back.scheduledAt!.toUtc(), DateTime.utc(2026, 11, 2, 18));
    });
  });

  group('late results after an account switch', () {
    test('swrFetch: a fetch that finishes after the switch writes to '
        'neither account', () async {
      SharedPreferences.setMockInitialValues({});
      final cache = OfflineCache(prefs: await SharedPreferences.getInstance());
      final gate = Completer<String>();
      final p = FutureProvider.autoDispose<String>(
        (ref) => swrFetch<String>(
          ref,
          key: meetupCard1,
          fetch: () => gate.future,
          encode: (v) => v,
          decode: (j) => j as String,
        ),
      );
      final container = ProviderContainer(
        overrides: [
          cacheAccountIdProvider.overrideWith(
            (ref) => CacheAccountNotifier.fixed('A'),
          ),
          offlineCacheProvider.overrideWithValue(cache),
        ],
      );
      addTearDown(container.dispose);
      final sub = container.listen(p, (_, _) {});
      final pending = container.read(p.future);
      await Future<void>.delayed(Duration.zero);

      container.read(cacheAccountIdProvider.notifier).state = 'B';
      gate.complete('private payload of A');
      await pending;
      await Future<void>.delayed(Duration.zero);

      expect(await cache.read('A', meetupCard1), isNull);
      expect(await cache.read('B', meetupCard1), isNull);
      sub.close();
    });

    test(
      'swrFetch: shown copy refreshes network-first on invalidation',
      () async {
        SharedPreferences.setMockInitialValues({});
        final cache = OfflineCache(
          prefs: await SharedPreferences.getInstance(),
        );
        await cache.write('A', meetupCard1, 'old');
        var fetches = 0;
        var answer = 'v1';
        final p = FutureProvider.autoDispose<String>(
          (ref) => swrFetch<String>(
            ref,
            key: meetupCard1,
            fetch: () async {
              fetches++;
              return answer;
            },
            encode: (v) => v,
            decode: (j) => j as String,
          ),
        );
        final container = ProviderContainer(
          overrides: [
            cacheAccountIdProvider.overrideWith(
              (ref) => CacheAccountNotifier.fixed('A'),
            ),
            offlineCacheProvider.overrideWithValue(cache),
          ],
        );
        addTearDown(container.dispose);
        final sub = container.listen(p, (_, _) {});
        expect(await container.read(p.future), 'old');
        for (var i = 0; i < 5; i++) {
          await Future<void>.delayed(Duration.zero);
        }
        expect(await container.read(p.future), 'v1');
        expect(fetches, 1); // the background refresh

        answer = 'v2-edited';
        await EventCacheInvalidator(
          cache: cache,
          currentAccountId: () => 'A',
        ).invalidate(
          const EventCacheChange.edited(CachedEventKind.meetup, 'm1'),
        );
        expect(await container.read(p.future), 'v2-edited');
        expect(fetches, 2); // exactly one request for the invalidation
        expect((await cache.read('A', meetupCard1))!.payload, 'v2-edited');
        sub.close();
      },
    );

    test('readThrough: a fetch that finishes after the switch is not '
        'written', () async {
      SharedPreferences.setMockInitialValues({});
      final cache = OfflineCache(prefs: await SharedPreferences.getInstance());
      var current = 'A';
      final gate = Completer<Result<String, Failure>>();
      final pending = readThrough<String>(
        cache: cache,
        accountId: 'A',
        currentAccountId: () => current,
        key: gameUpcoming,
        isOffline: () => false,
        fetch: () => gate.future,
        encode: (v) => v,
        decode: (j) => j as String,
      );
      current = 'B';
      gate.complete(const Ok('private payload of A'));
      await pending;
      expect(await cache.read('A', gameUpcoming), isNull);
      expect(await cache.read('B', gameUpcoming), isNull);
    });

    test('readThrough: offline serves stale, back online the next read goes '
        'to the network and replaces it', () async {
      SharedPreferences.setMockInitialValues({});
      final cache = OfflineCache(prefs: await SharedPreferences.getInstance());
      await cache.write('A', gameUpcoming, 'stale');
      var offline = true;
      var fetches = 0;
      Future<Result<CachedRead<String>, Failure>> read() => readThrough<String>(
        cache: cache,
        accountId: 'A',
        key: gameUpcoming,
        isOffline: () => offline,
        fetch: () async {
          fetches++;
          return const Ok('fresh');
        },
        encode: (v) => v,
        decode: (j) => j as String,
      );
      final r1 = (await read()).requireValue;
      expect(r1.value, 'stale');
      expect(r1.isStale, isTrue);
      expect(fetches, 0);

      offline = false;
      final r2 = (await read()).requireValue;
      expect(r2.value, 'fresh');
      expect(r2.isStale, isFalse);
      expect(fetches, 1);
      expect((await cache.read('A', gameUpcoming))!.payload, 'fresh');
    });
  });
}
