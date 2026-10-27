import 'dart:convert';

import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/data/models/area.dart';
import 'package:dabbler/data/models/active_location.dart';
import 'package:dabbler/data/models/social/post.dart';
import 'package:dabbler/data/repositories/post_repository.dart';
import 'package:dabbler/features/location/providers/active_location_provider.dart';
import 'package:dabbler/features/social/data/nearby_candidate_source.dart';
import 'package:dabbler/features/social/domain/nearby_ranking.dart';
import 'package:dabbler/features/social/providers/post_providers.dart';
import 'package:dabbler/features/social/providers/tab_feed_notifier.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../home/home_measure_fixtures.dart' show framePost;

/// KAN-594 return items 2 and 3 (CEO, Jira 14024): a change of City shows only
/// the new City's posts, and a private or followers-only post never appears.

/// The posts the fake server holds, by City. [hidden] are not public.
final _dubai = {'d1': 'Dubai', 'd2': 'Dubai'};
final _doha = {'q1': 'Doha', 'q2': 'Doha'};

class _Posts implements PostRepository {
  @override
  Future<Result<List<Post>, Failure>> getPostsByIds(List<String> ids) async =>
      Ok([
        for (final id in ids) framePost(id, 'Sam', 'body $id', 'football', 0),
      ]);

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _Loc extends ActiveLocationNotifier {
  _Loc(this.initial);
  final ActiveLocationState initial;

  @override
  Future<ActiveLocationState> build() async => initial;

  void set(ActiveLocationState s) => state = AsyncData(s);
}

NearbyCandidate _cand(String id, int minutesAgo, {double? lat, double? lng}) =>
    NearbyCandidate(
      id: id,
      createdAt: DateTime.now().subtract(Duration(minutes: minutesAgo)),
      lat: lat,
      lng: lng,
    );

ProviderContainer _container(
  ActiveLocationState initial,
  List<String> citiesAsked,
) {
  final c = ProviderContainer(
    overrides: [
      postRepositoryProvider.overrideWithValue(_Posts()),
      activeLocationProvider.overrideWith(() => _Loc(initial)),
      nearbyCandidateFetchProvider.overrideWithValue(({
        required city,
        required asOf,
      }) async {
        citiesAsked.add(city ?? '');
        final ids = city == 'Doha' ? _doha : _dubai;
        var m = 1;
        return [for (final id in ids.keys) _cand(id, m++ * 10)];
      }),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

/// Waits for the feed (it loads itself when its City changes).
Future<void> _settle(ProviderContainer c) async {
  c.listen(nearbyFeedProvider, (_, _) {});
  for (var i = 0; i < 50 && c.read(nearbyFeedProvider) is! TabFeedData; i++) {
    await c.read(nearbyFeedProvider.notifier).load();
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

List<String> _shown(ProviderContainer c) => [
  for (final p in (c.read(nearbyFeedProvider) as TabFeedData).posts) p.id,
];

/// A client whose server records every request and answers [rows].
({SupabaseClient client, List<Uri> requests}) _client(
  List<Map<String, dynamic>> Function(Uri) rows,
) {
  final requests = <Uri>[];
  final mock = MockClient((http.Request r) async {
    requests.add(r.url);
    return http.Response(
      jsonEncode(rows(r.url)),
      200,
      request: r,
      headers: {'content-type': 'application/json'},
    );
  });
  return (
    client: SupabaseClient(
      'http://localhost:54321',
      'anon-key',
      httpClient: mock,
    ),
    requests: requests,
  );
}

void main() {
  group('city change (TC5)', () {
    test(
      'after the City switches, the feed shows only the new City\'s posts',
      () async {
        final asked = <String>[];
        final c = _container(
          ActiveLocationCityOnly('Dubai', country: 'AE'),
          asked,
        );
        await c.read(activeLocationProvider.future);
        await _settle(c);
        expect(_shown(c), ['d1', 'd2']);

        (c.read(activeLocationProvider.notifier) as _Loc).set(
          ActiveLocationCityOnly('Doha', country: 'QA'),
        );
        await _settle(c);
        expect(asked.last, 'Doha');
        expect(_shown(c), ['q1', 'q2']);
        expect(_shown(c), isNot(contains('d1')));
        expect(_shown(c), isNot(contains('d2')));
      },
    );

    test('an Area of another City moves the feed to that City too', () async {
      final asked = <String>[];
      final c = _container(
        ActiveLocationCityOnly('Dubai', country: 'AE'),
        asked,
      );
      await c.read(activeLocationProvider.future);
      await _settle(c);

      (c.read(activeLocationProvider.notifier) as _Loc).set(
        ActiveLocationReady(
          const ActiveLocation(
            lat: 25.28,
            lng: 51.52,
            area: Area(
              id: 'a-doha',
              name: 'West Bay',
              district: 'Doha',
              city: 'Doha',
              country: 'QA',
              centerLat: 25.28,
              centerLng: 51.52,
            ),
            source: ActiveLocationSource.manual,
          ),
        ),
      );
      await _settle(c);
      expect(asked.last, 'Doha');
      expect(_shown(c).toSet(), {'q1', 'q2'});
    });
  });

  group('privacy (Nearby is public posts only)', () {
    test(
      'the candidate query asks for public, original, live posts only',
      () async {
        final s = _client((_) => []);
        await NearbyCandidateSource(
          s.client,
          personaType: null,
        ).fetch(city: 'Doha', asOf: DateTime.utc(2026, 10, 25));
        final q = s.requests.single.queryParameters;
        expect(q['visibility'], 'eq.public');
        expect(q['kind'], 'eq.original');
        expect(q['origin_type'], 'neq.system');
        expect(q['is_deleted'], 'eq.false');
        expect(q['is_hidden_admin'], 'eq.false');
        expect(q['posted_from_city'], 'ilike.Doha');
      },
    );

    test('a private or followers-only row the server returns is never '
        'requested, and only public rows reach the feed', () async {
      // The fake server honours the visibility filter the way Postgres does.
      final table = [
        {'id': 'pub', 'visibility': 'public'},
        {'id': 'priv', 'visibility': 'private'},
        {'id': 'fol', 'visibility': 'followers'},
        {'id': 'circle', 'visibility': 'circle'},
      ];
      final s = _client((uri) {
        final want = uri.queryParameters['visibility']?.replaceFirst('eq.', '');
        return [
          for (final r in table)
            if (want == null || r['visibility'] == want)
              {
                'id': r['id'],
                'created_at': '2026-10-25T10:00:00Z',
                'geo_lat': null,
                'geo_lng': null,
              },
        ];
      });
      final got = await NearbyCandidateSource(
        s.client,
        personaType: null,
      ).fetch(city: 'Dubai', asOf: DateTime.utc(2026, 10, 25, 12));
      expect([for (final g in got) g.id], ['pub']);
    });

    test('Dubai also owns legacy rows with no posting City; other Cities '
        'match exactly, with pattern characters escaped', () async {
      final s = _client((_) => []);
      final src = NearbyCandidateSource(s.client, personaType: null);
      await src.fetch(city: 'Dubai', asOf: DateTime.utc(2026, 10, 25));
      expect(
        s.requests.last.queryParameters['or'],
        contains('posted_from_city.is.null'),
      );
      await src.fetch(city: '50%_Town', asOf: DateTime.utc(2026, 10, 25));
      expect(
        s.requests.last.queryParameters['posted_from_city'],
        r'ilike.50\%\_Town',
      );
    });

    test('no City: no request at all', () async {
      final s = _client((_) => []);
      final got = await NearbyCandidateSource(
        s.client,
        personaType: null,
      ).fetch(city: null, asOf: DateTime.utc(2026, 10, 25));
      expect(got, isEmpty);
      expect(s.requests, isEmpty);
    });
  });
}
