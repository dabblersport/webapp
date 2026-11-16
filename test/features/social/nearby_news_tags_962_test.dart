// KAN-962: the Nearby and News tags reach the server. Nearby: the City (as
// today), the country (every City of `areas.country_code`) or anywhere (no
// City filter, newest first, capped); the widest pick wins. News: "Following"
// is `sport_id in (interests)` on published_news, "All news" is unfiltered.
import 'package:dabbler/core/data/supabase_error_mapper.dart';
import 'package:dabbler/core/data/supabase_remote_data_source.dart';
import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/data/models/feed/feed_item.dart';
import 'package:dabbler/data/models/profile/user_profile.dart';
import 'package:dabbler/data/models/social/post.dart';
import 'package:dabbler/features/home/presentation/models/feed_tab.dart';
import 'package:dabbler/features/home/presentation/providers/home_feed_scopes.dart';
import 'package:dabbler/features/home/presentation/widgets/home_tab_tags.dart';
import 'package:dabbler/features/news/data/news_repository.dart';
import 'package:dabbler/features/news/data/news_repository_impl.dart';
import 'package:dabbler/features/news/providers/news_providers.dart';
import 'package:dabbler/features/profile/presentation/providers/profile_providers.dart';
import 'package:dabbler/features/social/data/nearby_candidate_source.dart';
import 'package:dabbler/features/social/domain/nearby_feed_loader.dart';
import 'package:dabbler/features/social/domain/nearby_ranking.dart';
import 'package:dabbler/features/social/providers/tab_feed_notifier.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import '../../helpers/supabase_test_client.dart';

const padel = '33333333-3333-3333-3333-333333333333';
const tennis = '22222222-2222-2222-2222-222222222222';

/// A client that records every request and answers `areas` with [areas] and
/// everything else with no rows.
({List<Uri> requests, NearbyCandidateSource source, SupabaseService svc})
_server({List<Map<String, dynamic>> areas = const []}) {
  final requests = <Uri>[];
  final client = buildTestSupabaseClient((http.Request r) async {
    requests.add(r.url);
    final rows = r.url.path.endsWith('/areas')
        ? areas
        : const <Map<String, dynamic>>[];
    return jsonListResponse(rows, request: r);
  });
  return (
    requests: requests,
    source: NearbyCandidateSource(client),
    svc: SupabaseService(client, SupabaseErrorMapper()),
  );
}

Uri _posts(List<Uri> requests) =>
    requests.singleWhere((u) => u.path.endsWith('/posts'));

UserProfile _profile(List<String>? interests) => UserProfile(
  id: 'me',
  userId: 'u',
  displayName: 'Me',
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
  interests: interests,
);

ProviderContainer _container(List<String>? interests) {
  final c = ProviderContainer(
    overrides: [
      currentUserProfileProvider.overrideWithValue(_profile(interests)),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

void _pick(ProviderContainer c, FeedTab tab, HomeTabTag tag) {
  final n = c.read(homeTabPicksProvider.notifier);
  n.state = toggleHomeTabPick(n.state, tab, tag);
}

class _News implements NewsRepository {
  final calls = <List<String>?>[];

  @override
  Future<Result<List<FeedNewsItem>, Failure>> fetchNewsTab({
    int limit = 20,
    int offset = 0,
    List<String>? sportIds,
  }) async {
    calls.add(sportIds);
    return const Ok(<FeedNewsItem>[]);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final asOf = DateTime.utc(2026, 11, 16);

  group('Nearby candidate query', () {
    test('City: posted_from_city of the City, no areas lookup', () async {
      final s = _server();
      await s.source.fetch(city: 'Doha', asOf: asOf, area: NearbyArea.city);
      final q = _posts(s.requests).queryParameters;
      expect(q['posted_from_city'], 'ilike.Doha');
      expect(q['visibility'], 'eq.public');
      expect(s.requests.where((u) => u.path.endsWith('/areas')), isEmpty);
    });

    test('country: every active City of the country, Dubai owning legacy '
        'rows', () async {
      final s = _server(
        areas: [
          {'city': 'Dubai'},
          {'city': 'Abu Dhabi'},
          {'city': 'Sharjah'},
          {'city': 'dubai'},
        ],
      );
      await s.source.fetch(
        city: 'Dubai',
        asOf: asOf,
        area: NearbyArea.country,
        countryCode: 'AE',
      );
      final areas = s.requests
          .singleWhere((u) => u.path.endsWith('/areas'))
          .queryParameters;
      expect(areas['country_code'], 'eq.AE');
      expect(areas['is_active'], 'eq.true');
      final q = _posts(s.requests).queryParameters;
      expect(q.containsKey('posted_from_city'), isFalse);
      expect(
        q['or'],
        '(posted_from_city.ilike.Abu Dhabi,posted_from_city.ilike.Dubai,'
        'posted_from_city.ilike.Sharjah,posted_from_city.is.null)',
      );
      expect(q['visibility'], 'eq.public');
    });

    test('country without a country code stays on the City', () async {
      final s = _server();
      await s.source.fetch(city: 'Doha', asOf: asOf, area: NearbyArea.country);
      expect(
        _posts(s.requests).queryParameters['posted_from_city'],
        'ilike.Doha',
      );
      expect(s.requests.where((u) => u.path.endsWith('/areas')), isEmpty);
    });

    test('anywhere: no City filter, ranking columns only, newest first, one '
        'capped page', () async {
      final s = _server();
      await s.source.fetch(
        city: 'Dubai',
        asOf: asOf,
        area: NearbyArea.anywhere,
        countryCode: 'AE',
      );
      expect(s.requests, hasLength(1));
      final u = _posts(s.requests);
      final q = u.queryParameters;
      expect(q.containsKey('posted_from_city'), isFalse);
      expect(q.containsKey('or'), isFalse);
      expect(q['select'], 'id,created_at,geo_lat,geo_lng');
      expect(q['order'], startsWith('created_at.desc'));
      expect(q['visibility'], 'eq.public');
      expect(q['kind'], 'eq.original');
      expect(q['offset'], '0');
      expect(q['limit'], '1000');
    });

    test('the loader passes the scope\'s area and country on, and refetches '
        'when the area changes', () async {
      final asked = <(NearbyArea?, String?)>[];
      final loader = NearbyFeedLoader(
        fetchCandidates:
            ({required city, required asOf, area, countryCode}) async {
              asked.add((area, countryCode));
              return const <NearbyCandidate>[];
            },
        postsByIds: (ids) async => const Ok(<Post>[]),
      );
      await loader.loadRankedPage(
        scope: const NearbyScope(city: 'Dubai', countryCode: 'AE'),
        limit: 20,
        offset: 0,
      );
      await loader.loadRankedPage(
        scope: const NearbyScope(
          city: 'Dubai',
          countryCode: 'AE',
          area: NearbyArea.anywhere,
        ),
        limit: 20,
        offset: 0,
      );
      expect(asked, [(NearbyArea.city, 'AE'), (NearbyArea.anywhere, 'AE')]);
    });
  });

  test('nearbyAreaProvider: the widest pick wins', () {
    final c = _container(null);
    expect(c.read(nearbyAreaProvider), NearbyArea.city);
    _pick(c, FeedTab.nearby, HomeTabTag.country);
    expect(c.read(nearbyAreaProvider), NearbyArea.country);
    _pick(c, FeedTab.nearby, HomeTabTag.anywhere);
    expect(c.read(nearbyAreaProvider), NearbyArea.anywhere);
    _pick(c, FeedTab.nearby, HomeTabTag.anywhere);
    expect(c.read(nearbyAreaProvider), NearbyArea.country);
    _pick(c, FeedTab.nearby, HomeTabTag.city);
    expect(c.read(nearbyAreaProvider), NearbyArea.city);
  });

  test('nearbyCacheKey keeps the City key and separates wider areas', () {
    expect(nearbyCacheKey('Dubai'), 'feed.nearby.Dubai');
    expect(nearbyCacheKey('Dubai', NearbyArea.city), 'feed.nearby.Dubai');
    expect(
      nearbyCacheKey('Dubai', NearbyArea.country),
      'feed.nearby.Dubai.country',
    );
    expect(
      nearbyCacheKey('Dubai', NearbyArea.anywhere),
      'feed.nearby.Dubai.anywhere',
    );
  });

  group('News', () {
    test(
      'Following filters sport_id on the server; All news does not',
      () async {
        final s = _server();
        final repo = NewsRepositoryImpl(s.svc);
        await repo.fetchNewsTab(sportIds: [padel, tennis]);
        await repo.fetchNewsTab();
        final news = s.requests
            .where((u) => u.path.endsWith('/published_news'))
            .toList();
        expect(news, hasLength(2));
        expect(news[0].queryParameters['sport_id'], 'in.("$padel","$tennis")');
        expect(news[1].queryParameters.containsKey('sport_id'), isFalse);
      },
    );

    test('newsSportIdsProvider: Following (the default) is the interests; '
        'All news is null', () {
      final c = _container([padel]);
      expect(c.read(newsSportIdsProvider), [padel]);
      _pick(c, FeedTab.news, HomeTabTag.newsAll);
      expect(c.read(newsSportIdsProvider), isNull);
      _pick(c, FeedTab.news, HomeTabTag.newsFollowing);
      expect(c.read(newsSportIdsProvider), [padel]);
    });

    test('the notifier sends the tag on every page and makes no call when '
        'Following has no sport', () async {
      final repo = _News();
      List<String>? sports = [padel];
      final n = NewsTabNotifier(repo, sportIds: () => sports);
      addTearDown(n.dispose);
      await n.load();
      expect(repo.calls, [
        [padel],
      ]);
      sports = null;
      await n.refilter();
      expect(repo.calls.last, isNull);
      sports = const <String>[];
      await n.refilter();
      expect(repo.calls, hasLength(2), reason: 'no call with no sport');
      expect(n.state.loaded, isTrue);
      expect(n.state.items, isEmpty);
    });

    test('the provider reloads a started tab when the tag changes', () async {
      final repo = _News();
      final c = ProviderContainer(
        overrides: [
          currentUserProfileProvider.overrideWithValue(_profile([padel])),
          newsRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(c.dispose);
      // Not loaded yet: a tag change makes no call.
      c.read(newsTabFeedProvider);
      _pick(c, FeedTab.news, HomeTabTag.newsAll);
      await pumpEventQueue();
      expect(repo.calls, isEmpty);
      await c.read(newsTabFeedProvider.notifier).ensureLoaded();
      expect(repo.calls, [null]);
      _pick(c, FeedTab.news, HomeTabTag.newsFollowing);
      await pumpEventQueue();
      expect(repo.calls, [
        null,
        [padel],
      ]);
    });
  });
}
