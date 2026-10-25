import 'dart:io';

import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/data/models/social/post.dart';
import 'package:dabbler/features/social/domain/nearby_feed_loader.dart';
import 'package:dabbler/features/social/domain/nearby_ranking.dart';
import 'package:dabbler/features/social/domain/nearby_ranking_config.dart';
import 'package:flutter_test/flutter_test.dart';

import '../home/home_measure_fixtures.dart' show framePost;

/// KAN-594: the examples in docs/kan594/nearby_ranking_examples.md, with the
/// values the product approved (H = 24 h, D = 5 km, missing = 2 x D).
final _asOf = DateTime.utc(2026, 10, 22, 12);
const _origin = NearbyOrigin(25.0, 55.0);

/// A point [meters] due north of the origin.
double _northOf(double meters) => 25.0 + meters / 111195.0;

NearbyCandidate _post(
  String id, {
  required double ageHours,
  double? distanceMeters,
}) => NearbyCandidate(
  id: id,
  createdAt: _asOf.subtract(Duration(minutes: (ageHours * 60).round())),
  lat: distanceMeters == null ? null : _northOf(distanceMeters),
  lng: distanceMeters == null ? null : 55.0,
);

List<NearbyCandidate> _examples() => [
  _post('A', ageHours: 1, distanceMeters: 12000), // newer, farther
  _post('B', ageHours: 30, distanceMeters: 800), // older, closer
  _post('C', ageHours: 6, distanceMeters: 4000),
  _post('D', ageHours: 3, distanceMeters: 25000),
  _post('E', ageHours: 72, distanceMeters: 300),
];

List<String> _ids(List<ScoredNearby> r) => [for (final s in r) s.candidate.id];

void main() {
  group('approved values live in config', () {
    test('standard config is the product ruling', () {
      const c = NearbyRankingConfig.standard;
      expect(c.recencyHalfLife, const Duration(hours: 24));
      expect(c.distanceScaleMeters, 5000);
      expect(c.missingCoordinateDistanceFactor, 2);
      expect(c.lastKnownMaxAge, const Duration(hours: 24));
    });

    test('no ranking number is hardcoded outside the config file', () {
      for (final f in [
        'lib/features/social/domain/nearby_ranking.dart',
        'lib/features/social/domain/nearby_feed_loader.dart',
        'lib/features/social/data/nearby_candidate_source.dart',
        'lib/features/social/providers/tab_feed_notifier.dart',
      ]) {
        final src = File(f).readAsStringSync();
        expect(src, isNot(contains('5000')), reason: f);
        expect(src, isNot(contains('hours: 24')), reason: f);
        expect(src, isNot(contains('Duration(hours')), reason: f);
      }
    });

    test('changing the config changes the order (nothing is baked in)', () {
      // A tiny distance scale makes distance dominate: C no longer wins, B does.
      const distanceHeavy = NearbyRankingConfig(distanceScaleMeters: 50);
      final r = rankNearby(
        _examples(),
        origin: _origin,
        asOf: _asOf,
        config: distanceHeavy,
      );
      expect(r.first.candidate.id, 'B');
    });
  });

  group('newer/farther versus older/closer (AC2)', () {
    test('the documented five-post table ranks C, B, A, D, E', () {
      final r = rankNearby(_examples(), origin: _origin, asOf: _asOf);
      expect(_ids(r), ['C', 'B', 'A', 'D', 'E']);
      final score = {for (final s in r) s.candidate.id: s.score};
      expect(score['C'], closeTo(0.47, 0.01));
      expect(score['B'], closeTo(0.36, 0.01));
      expect(score['A'], closeTo(0.28, 0.01));
      expect(score['D'], closeTo(0.15, 0.01));
      expect(score['E'], closeTo(0.12, 0.01));
    });

    test('a 30 h post 0.8 km away beats a 1 h post 12 km away', () {
      final r = rankNearby(
        [
          _post('newer-farther', ageHours: 1, distanceMeters: 12000),
          _post('older-closer', ageHours: 30, distanceMeters: 800),
        ],
        origin: _origin,
        asOf: _asOf,
      );
      expect(_ids(r), ['older-closer', 'newer-farther']);
    });

    test('neither distance-only nor time-only gives this order', () {
      final byDistance = [..._examples()]
        ..sort((a, b) {
          double d(NearbyCandidate c) =>
              haversineMeters(_origin.lat, _origin.lng, c.lat!, c.lng!);
          return d(a).compareTo(d(b));
        });
      final byTime = [..._examples()]
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      final blended = _ids(
        rankNearby(_examples(), origin: _origin, asOf: _asOf),
      );
      expect([for (final c in byDistance) c.id], isNot(blended));
      expect([for (final c in byTime) c.id], isNot(blended));
      expect(byDistance.first.id, 'E');
      expect(byTime.first.id, 'A');
    });
  });

  group('City-only (no origin)', () {
    test('newest first, id breaks a tie, no distance involved', () {
      final r = rankNearby(
        [
          _post('old', ageHours: 50, distanceMeters: 100),
          _post('new', ageHours: 1, distanceMeters: 90000),
          _post('b-same', ageHours: 5),
          _post('a-same', ageHours: 5),
        ],
        origin: null,
        asOf: _asOf,
      );
      expect(_ids(r), ['new', 'a-same', 'b-same', 'old']);
    });
  });

  group('missing coordinates (TC4)', () {
    test('count as 2 x D away: factor 0.33, ranked by recency', () {
      final r = rankNearby(
        [_post('fresh-no-coords', ageHours: 10 / 60)],
        origin: _origin,
        asOf: _asOf,
      );
      expect(r.single.score, closeTo(0.33, 0.01));
    });

    test('stay visible and land between B and A, never above a nearby post '
        'of similar age', () {
      final r = rankNearby(
        [
          ..._examples(),
          _post('no-coords', ageHours: 10 / 60),
          _post('nearby-similar', ageHours: 10 / 60, distanceMeters: 500),
        ],
        origin: _origin,
        asOf: _asOf,
      );
      final ids = _ids(r);
      expect(ids, contains('no-coords'));
      expect(ids.indexOf('no-coords'), greaterThan(ids.indexOf('B')));
      expect(ids.indexOf('no-coords'), lessThan(ids.indexOf('A')));
      expect(ids.indexOf('nearby-similar'), lessThan(ids.indexOf('no-coords')));
    });

    test('with no origin they are ordinary newest-first rows', () {
      final r = rankNearby(
        [_post('x', ageHours: 9), _post('y', ageHours: 2)],
        origin: null,
        asOf: _asOf,
      );
      expect(_ids(r), ['y', 'x']);
    });
  });

  group('last-known origin (TC6)', () {
    NearbyScope last(Duration age) => NearbyScope(
      city: 'Dubai',
      lat: 25.0,
      lng: 55.0,
      lastKnown: true,
      fixedAt: _asOf.subtract(age),
    );

    test('younger than 24 h: used as the origin', () {
      expect(
        resolveNearbyOrigin(last(const Duration(hours: 23)), _asOf),
        isNotNull,
      );
    });

    test('exactly 24 h is still used', () {
      expect(
        resolveNearbyOrigin(last(const Duration(hours: 24)), _asOf),
        isNotNull,
      );
    });

    test('older than 24 h: City-only, newest first', () {
      expect(
        resolveNearbyOrigin(last(const Duration(hours: 25)), _asOf),
        isNull,
      );
      final r = rankNearby(
        [
          _post('close-old', ageHours: 20, distanceMeters: 100),
          _post('far-new', ageHours: 1, distanceMeters: 30000),
        ],
        origin: resolveNearbyOrigin(last(const Duration(hours: 25)), _asOf),
        asOf: _asOf,
      );
      expect(_ids(r), ['far-new', 'close-old']);
    });

    test('a last-known point with no timestamp is not trusted', () {
      expect(
        resolveNearbyOrigin(
          const NearbyScope(lat: 25.0, lng: 55.0, lastKnown: true),
          _asOf,
        ),
        isNull,
      );
    });

    test('a live fix never expires; no point means no origin', () {
      expect(
        resolveNearbyOrigin(const NearbyScope(lat: 25.0, lng: 55.0), _asOf),
        isNotNull,
      );
      expect(
        resolveNearbyOrigin(const NearbyScope(city: 'Dubai'), _asOf),
        isNull,
      );
    });
  });

  group('paging: fixed as_of and a (score, id) cursor', () {
    Post post(String id) => framePost(id, 'n', 'b', 'football', 0);

    NearbyFeedLoader loader(
      List<NearbyCandidate> Function() candidates,
      DateTime Function() clock,
    ) => NearbyFeedLoader(
      fetchCandidates: ({required city, required asOf}) async =>
          candidates().where((c) => !c.createdAt.isAfter(asOf)).toList(),
      postsByIds: (ids) async =>
          Ok<List<Post>, Failure>([for (final id in ids) post(id)]),
      clock: clock,
    );

    const scope = NearbyScope(city: 'Dubai', lat: 25.0, lng: 55.0);

    test('pages cover every row once, in ranking order', () async {
      final all = [
        for (var i = 0; i < 11; i++)
          _post(
            'p${i.toString().padLeft(2, '0')}',
            ageHours: 1.0 + i * 3,
            distanceMeters: 500.0 + (i % 4) * 3000,
          ),
      ];
      final l = loader(() => all, () => _asOf);
      final seen = <String>[];
      for (var offset = 0; offset < 15; offset += 4) {
        final page = (await l.loadPage(
          scope: scope,
          limit: 4,
          offset: offset,
        )).fold((e) => fail('$e'), (p) => p);
        seen.addAll([for (final p in page) p.id]);
      }
      expect(seen.toSet().length, seen.length, reason: 'no duplicates');
      expect(seen, _ids(rankNearby(all, origin: _origin, asOf: _asOf)));
    });

    test('pages past 500 candidates with no duplicates and no skips', () async {
      final all = [
        for (var i = 0; i < 1250; i++)
          _post(
            'p${i.toString().padLeft(4, '0')}',
            ageHours: 1.0 + (i % 97) * 0.7 + i * 0.01,
            distanceMeters: 300.0 + (i * 37 % 41) * 900,
          ),
      ];
      final l = loader(() => all, () => _asOf);
      final seen = <String>[];
      for (var offset = 0; ; offset += 50) {
        final page = (await l.loadPage(
          scope: scope,
          limit: 50,
          offset: offset,
        )).fold((e) => fail('$e'), (p) => p);
        if (page.isEmpty) break;
        seen.addAll([for (final p in page) p.id]);
      }
      expect(seen, hasLength(1250), reason: 'every City post is reachable');
      expect(seen.toSet(), hasLength(1250), reason: 'no duplicates');
      expect(seen, _ids(rankNearby(all, origin: _origin, asOf: _asOf)));
    });

    test('no City: nothing is queried and the page is empty', () async {
      var fetches = 0;
      final l = NearbyFeedLoader(
        fetchCandidates: ({required city, required asOf}) async {
          fetches++;
          return const [];
        },
        postsByIds: (ids) async => const Ok<List<Post>, Failure>([]),
        clock: () => _asOf,
      );
      for (final s in const [
        NearbyScope(),
        NearbyScope(lat: 25.0, lng: 55.0),
        NearbyScope(city: '  '),
      ]) {
        final page = (await l.loadPage(
          scope: s,
          limit: 10,
          offset: 0,
        )).fold((e) => fail('$e'), (p) => p);
        expect(page, isEmpty);
      }
      expect(fetches, 0);
    });

    test('equal scores page by id with no repeat or skip', () async {
      final same = [
        for (final id in ['d', 'a', 'c', 'b', 'e'])
          _post(id, ageHours: 2, distanceMeters: 1000),
      ];
      final l = loader(() => same, () => _asOf);
      final seen = <String>[];
      for (var offset = 0; offset < 6; offset += 2) {
        final page = (await l.loadPage(
          scope: scope,
          limit: 2,
          offset: offset,
        )).fold((e) => fail('$e'), (p) => p);
        seen.addAll([for (final p in page) p.id]);
      }
      expect(seen, ['a', 'b', 'c', 'd', 'e']);
    });

    test('a post that arrives mid-scroll does not shift later pages; '
        'refresh picks it up', () async {
      var now = _asOf;
      final all = [
        for (var i = 0; i < 6; i++)
          _post('p$i', ageHours: 2.0 + i, distanceMeters: 1000),
      ];
      final l = loader(() => all, () => now);
      final first = (await l.loadPage(
        scope: scope,
        limit: 3,
        offset: 0,
      )).fold((e) => fail('$e'), (p) => p);
      expect([for (final p in first) p.id], ['p0', 'p1', 'p2']);

      // A brand-new, very close post lands while the user scrolls.
      now = _asOf.add(const Duration(minutes: 3));
      all.add(
        NearbyCandidate(
          id: 'late',
          createdAt: _asOf.add(const Duration(minutes: 2)),
          lat: _northOf(10),
          lng: 55.0,
        ),
      );
      final second = (await l.loadPage(
        scope: scope,
        limit: 3,
        offset: 3,
      )).fold((e) => fail('$e'), (p) => p);
      expect([for (final p in second) p.id], ['p3', 'p4', 'p5']);

      final refreshed = (await l.loadPage(
        scope: scope,
        limit: 3,
        offset: 0,
      )).fold((e) => fail('$e'), (p) => p);
      expect(refreshed.first.id, 'late');
    });

    test('a failed page does not advance the cursor', () async {
      var fail1 = true;
      final all = [
        for (var i = 0; i < 4; i++)
          _post('p$i', ageHours: 2.0 + i, distanceMeters: 1000),
      ];
      final l = NearbyFeedLoader(
        fetchCandidates: ({required city, required asOf}) async => all,
        postsByIds: (ids) async {
          if (fail1 && ids.first == 'p2') {
            return const Err(NetworkFailure());
          }
          return Ok([for (final id in ids) post(id)]);
        },
        clock: () => _asOf,
      );
      await l.loadPage(scope: scope, limit: 2, offset: 0);
      final bad = await l.loadPage(scope: scope, limit: 2, offset: 2);
      expect(bad.isFailure, isTrue);
      fail1 = false;
      final retry = (await l.loadPage(
        scope: scope,
        limit: 2,
        offset: 2,
      )).fold((e) => fail('$e'), (p) => p);
      expect([for (final p in retry) p.id], ['p2', 'p3']);
    });

    test('City-only scope pages newest first with no origin', () async {
      final all = [
        _post('old', ageHours: 40, distanceMeters: 10),
        _post('new', ageHours: 1, distanceMeters: 50000),
      ];
      final l = loader(() => all, () => _asOf);
      final page = (await l.loadPage(
        scope: const NearbyScope(city: 'Dubai'),
        limit: 5,
        offset: 0,
      )).fold((e) => fail('$e'), (p) => p);
      expect([for (final p in page) p.id], ['new', 'old']);
    });
  });
}
