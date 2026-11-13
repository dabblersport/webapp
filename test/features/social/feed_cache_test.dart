import 'dart:convert';

import 'package:dabbler/core/cache/offline_cache.dart';
import 'package:dabbler/core/cache/news_item_codec.dart';
import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/data/models/feed/feed_item.dart';
import 'package:dabbler/data/models/social/post.dart';
import 'package:dabbler/data/repositories/post_repository.dart';
import 'package:dabbler/features/social/providers/active_feed_notifier.dart';
import 'package:dabbler/features/social/providers/feed_notifier.dart';
import 'package:dabbler/features/social/providers/tab_feed_notifier.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/supabase_test_client.dart';
import '../home/home_measure_fixtures.dart';
import '../home/home_test_harness.dart';

/// KAN-605: the Home feed tabs open from the on-device cache (also offline),
/// refresh in the background without duplicate cards, a failed refresh is
/// silent, an empty cache with no connection shows the failure (never an
/// endless loader), and one account never reads another's cache.

Post _post(String id) => framePost(id, 'Name $id', 'Body $id', 'football', 1);

class _Posts implements PostRepository {
  @override
  Future<Result<List<Post>, Failure>> getPostsByIds(List<String> ids) async =>
      Ok(<Post>[for (final id in ids) _post(id)]);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _HomeFeedRpc {
  List<String> nextIds = <String>[];
  bool fails = false;

  Future<http.Response> handle(http.Request request) async {
    if (!request.url.path.endsWith('/rpc/get_home_feed')) {
      return jsonListResponse(const <Map<String, dynamic>>[], request: request);
    }
    if (fails) {
      return postgrestErrorResponse(
        message: 'offline',
        code: '500',
        status: 500,
        request: request,
      );
    }
    final now = DateTime.utc(2026, 10, 20);
    return http.Response(
      jsonEncode(<Map<String, dynamic>>[
        for (var i = 0; i < nextIds.length; i++)
          <String, dynamic>{
            'activity_id': nextIds[i],
            'activity_type': 'post',
            'created_at': now.subtract(Duration(minutes: i)).toIso8601String(),
          },
      ]),
      200,
      headers: <String, String>{'content-type': 'application/json'},
      request: request,
    );
  }
}

class _TabSource {
  List<Post> next = <Post>[];
  bool fails = false;
  int calls = 0;

  Future<Result<List<Post>, Failure>> fetch({
    required int limit,
    required int offset,
  }) async {
    calls++;
    return fails
        ? const Err(Failure(message: 'no internet'))
        : Ok(List<Post>.of(next));
  }
}

List<String> _feedIds(FeedState s) => <String>[
  for (final item in s.items)
    if (item is FeedPostItem) item.post.id,
];

void main() {
  late OfflineCache cache;

  setUpAll(initHomeTestSupabase);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    cache = OfflineCache(prefs: prefs);
  });

  group('For you (FeedNotifier)', () {
    Future<void> seed(String account, List<String> ids) => cache.write(
      account,
      'feed.foryou',
      {
        'items': [
          for (final id in ids) {'k': 'p', 'v': _post(id).toJson()},
        ],
        'hasMore': false,
        'cursor': null,
      },
    );

    test('cold start offline: the cached posts show, no endless loader',
        () async {
      await seed('A', ['c1', 'c2']);
      final rpc = _HomeFeedRpc()..fails = true;
      final n = FeedNotifier(
        _Posts(),
        buildTestSupabaseClient(rpc.handle),
        cache: cache,
        accountId: 'A',
      );
      addTearDown(n.dispose);
      await pumpEventQueue(times: 50);

      expect(n.state, isA<FeedData>());
      expect(_feedIds(n.state), ['c1', 'c2']);
      expect(n.state.error, isNull);
    });

    test('empty cache and no connection: the failure state, not a loader',
        () async {
      final rpc = _HomeFeedRpc()..fails = true;
      final n = FeedNotifier(
        _Posts(),
        buildTestSupabaseClient(rpc.handle),
        cache: cache,
        accountId: 'A',
      );
      addTearDown(n.dispose);
      await pumpEventQueue(times: 50);
      expect(n.state, isA<FeedFailure>());
      expect(n.state.isLoading, isFalse);
    });

    test('background refresh replaces the cache with no duplicate cards',
        () async {
      await seed('A', ['c1', 'c2']);
      final rpc = _HomeFeedRpc()..nextIds = ['c1', 'n1', 'c2'];
      final n = FeedNotifier(
        _Posts(),
        buildTestSupabaseClient(rpc.handle),
        cache: cache,
        accountId: 'A',
      );
      addTearDown(n.dispose);
      await pumpEventQueue(times: 50);

      final ids = _feedIds(n.state);
      expect(ids, ['c1', 'n1', 'c2']);
      expect(ids.toSet().length, ids.length);
      final stored = (await cache.read('A', 'feed.foryou'))!.payload as Map;
      expect((stored['items'] as List).length, 3);
    });

    test('account B never sees account A\'s cached posts', () async {
      await seed('A', ['a-secret']);
      final rpc = _HomeFeedRpc()..fails = true;
      final n = FeedNotifier(
        _Posts(),
        buildTestSupabaseClient(rpc.handle),
        cache: cache,
        accountId: 'B',
      );
      addTearDown(n.dispose);
      await pumpEventQueue(times: 50);
      expect(_feedIds(n.state), isEmpty);
      expect(n.state, isA<FeedFailure>());
    });

    test('news items survive the cache round trip', () async {
      final news = FeedNewsItem.fromJson({
        'news_id': 'n1',
        'id': 'row1',
        'news_title': {'en': 'Title', 'ar': 'عنوان'},
        'news_body': {'en': 'Body'},
        'created_at': '2026-10-20T10:00:00.000Z',
        'like_count': 2,
        'tags': ['a'],
      });
      final back = FeedNewsItem.fromJson(news.toCacheJson());
      expect(back.newsId, 'n1');
      expect(back.title, {'en': 'Title', 'ar': 'عنوان'});
      expect(back.likeCount, 2);
      expect(back.tags, ['a']);
      expect(back.createdAt, news.createdAt);
    });
  });

  group('Following / Nearby / News (TabFeedNotifier)', () {
    Future<void> seed(String account, List<String> ids) => cache.write(
      account,
      'feed.following',
      [for (final id in ids) _post(id).toJson()],
    );

    TabFeedNotifier build(_TabSource src, {String account = 'A'}) =>
        TabFeedNotifier(
          src.fetch,
          autoLoad: false,
          cache: cache,
          accountId: account,
          cacheKey: 'feed.following',
        );

    test('the cached tab renders at once, before any network answer',
        () async {
      await seed('A', ['c1', 'c2']);
      final src = _TabSource()..fails = true;
      final n = build(src);
      addTearDown(n.dispose);
      await pumpEventQueue(times: 20);
      expect(n.state, isA<TabFeedData>());
      expect(n.state.posts.map((p) => p.id), ['c1', 'c2']);
      expect(src.calls, 0, reason: 'lazy tab: nothing fetched until opened');
    });

    test('opening it offline keeps the cached posts and shows no error',
        () async {
      await seed('A', ['c1']);
      final src = _TabSource()..fails = true;
      final n = build(src);
      addTearDown(n.dispose);
      await n.ensureLoaded();
      expect(n.state, isA<TabFeedData>());
      expect(n.state.posts.map((p) => p.id), ['c1']);
      expect(n.state.error, isNull);
    });

    test('opening it online refreshes the cached tab, no duplicates',
        () async {
      await seed('A', ['c1', 'c2']);
      final src = _TabSource()..next = [_post('n1'), _post('c1'), _post('c2')];
      final n = build(src);
      addTearDown(n.dispose);
      await n.ensureLoaded();
      final ids = n.state.posts.map((p) => p.id).toList();
      expect(ids, ['n1', 'c1', 'c2']);
      expect(ids.toSet().length, ids.length);
      await n.ensureLoaded();
      expect(src.calls, 1, reason: 'once per notifier, not per visit');
      final stored = (await cache.read('A', 'feed.following'))!.payload as List;
      expect(stored.length, 3);
    });

    test('an unvisited tab with no cache and no connection is the failure '
        'state, not an endless loader', () async {
      final src = _TabSource()..fails = true;
      final n = build(src);
      addTearDown(n.dispose);
      await n.ensureLoaded();
      expect(n.state, isA<TabFeedFailure>());
      expect(n.state.isLoading, isFalse);
    });

    test('account B never sees account A\'s cached tab', () async {
      await seed('A', ['a-secret']);
      final src = _TabSource()..fails = true;
      final n = build(src, account: 'B');
      addTearDown(n.dispose);
      await n.ensureLoaded();
      expect(n.state.posts, isEmpty);
    });
  });

  group('Active (ActiveFeedNotifier)', () {
    test('the cached events render and a failed refresh keeps them', () async {
      await cache.write('A', 'feed.active', [
        {
          'id': 'g1',
          'created_at': '2026-10-20T10:00:00.000Z',
          'title': 'Five-a-side',
          'sport_name_en': 'Football',
          'venue_name': 'Pitch 1',
        },
      ]);
      final n = ActiveFeedNotifier(
        buildTestSupabaseClient(
          (r) async => postgrestErrorResponse(
            message: 'offline',
            code: '500',
            status: 500,
            request: r,
          ),
        ),
        cache: cache,
        accountId: 'A',
      );
      addTearDown(n.dispose);
      await n.ensureLoaded();
      final s = n.state;
      expect(s, isA<ActiveFeedData>());
      expect((s as ActiveFeedData).events.single.id, 'g1');
    });
  });
}
