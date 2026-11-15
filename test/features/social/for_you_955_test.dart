import 'dart:convert';

import 'package:dabbler/core/data/supabase_error_mapper.dart';
import 'package:dabbler/core/data/supabase_remote_data_source.dart';
import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/data/models/feed/feed_item.dart';
import 'package:dabbler/data/models/social/post.dart';
import 'package:dabbler/data/repositories/post_repository.dart';
import 'package:dabbler/data/repositories/post_repository_impl.dart';
import 'package:dabbler/features/social/data/nearby_candidate_source.dart';
import 'package:dabbler/features/social/providers/feed_notifier.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import '../../helpers/supabase_test_client.dart';
import '../home/home_measure_fixtures.dart' show framePost;

// KAN-955 (CEO 2026-11-16): For you, Nearby, Active and News show all recent
// posts; no followed-sports filter. The For you first page fills a screen.

const padel = '33333333-3333-3333-3333-333333333333';
const tennis = '22222222-2222-2222-2222-222222222222';

/// Posts by id; each carries a different sport (or none).
class _Posts implements PostRepository {
  @override
  Future<Result<List<Post>, Failure>> getPostsByIds(List<String> ids) async =>
      Ok([
        for (final (i, id) in ids.indexed)
          framePost(
            id,
            'Name',
            'Body',
            'football',
            0,
          ).copyWith(sportId: [padel, tennis, null][i % 3]),
      ]);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// The `get_home_feed` RPC. Each call answers the next of [pages]; a page is
/// a list of `(id, activity_type)`. Records every request.
class _Rpc {
  _Rpc(this.pages);

  final List<List<(String, String)>> pages;
  final requests = <Uri>[];
  int calls = 0;

  Future<http.Response> handle(http.Request r) async {
    requests.add(r.url);
    if (!r.url.path.endsWith('/rpc/get_home_feed')) {
      return jsonListResponse(const [], request: r);
    }
    final page = calls < pages.length
        ? pages[calls]
        : const <(String, String)>[];
    calls++;
    final base = DateTime.utc(2026, 11, 16);
    return http.Response(
      jsonEncode([
        for (final (i, (id, type)) in page.indexed)
          {
            'activity_id': id,
            'activity_type': type,
            'created_at': base
                .subtract(Duration(minutes: calls * 100 + i))
                .toIso8601String(),
          },
      ]),
      200,
      headers: {'content-type': 'application/json'},
      request: r,
    );
  }
}

/// A full raw page of 20 rows whose only post is [postId]; the other 19 are
/// an activity type the feed does not show.
List<(String, String)> _sparse(String postId) => [
  (postId, 'post'),
  for (var i = 0; i < 19; i++) ('$postId-g$i', 'game'),
];

Future<FeedNotifier> _start(_Rpc rpc) async {
  final n = FeedNotifier(_Posts(), buildTestSupabaseClient(rpc.handle));
  addTearDown(n.dispose);
  await pumpEventQueue();
  return n;
}

List<String> _ids(FeedNotifier n) => [
  for (final i in n.state.items)
    if (i is FeedPostItem) i.post.id,
];

bool _askedInterests(List<Uri> requests) =>
    requests.any((u) => u.queryParameters['select'] == 'interests');

void main() {
  group('For you is unfiltered', () {
    test('every post shows, whatever its sport, and followed sports are '
        'never read', () async {
      final rpc = _Rpc([
        [for (var i = 0; i < 6; i++) ('p$i', 'post')],
      ]);
      final n = await _start(rpc);
      expect(_ids(n), ['p0', 'p1', 'p2', 'p3', 'p4', 'p5']);
      expect(_askedInterests(rpc.requests), isFalse);
    });
  });

  group('discovery queries carry no sport filter', () {
    late List<Uri> requests;
    late PostRepositoryImpl repo;

    setUp(() async {
      requests = [];
      final client = buildTestSupabaseClient((r) async {
        requests.add(r.url);
        return jsonListResponse(const [], request: r);
      });
      await client.auth.setInitialSession(fakeSessionJson(userId: 'u1'));
      repo = PostRepositoryImpl(
        SupabaseService(client, SupabaseErrorMapper()),
        activePersonaType: 'player',
      );
    });

    test('getHomeFeed and getNearbyFeed (City) send no or= on sport', () async {
      await repo.getHomeFeed();
      await repo.getNearbyFeed(city: 'Doha');
      await repo.getNearbyFeed(lat: 25.2, lng: 55.3);
      await repo.getNearbyFeed();
      expect(_askedInterests(requests), isFalse);
      for (final u in requests.where((u) => u.path.endsWith('/posts'))) {
        expect(u.queryParameters['or'] ?? '', isNot(contains('sport_id')));
      }
    });

    test('Nearby candidates send no or= on sport', () async {
      final client = buildTestSupabaseClient((r) async {
        requests.add(r.url);
        return jsonListResponse(const [], request: r);
      });
      await client.auth.setInitialSession(fakeSessionJson(userId: 'u1'));
      await NearbyCandidateSource(
        client,
      ).fetch(city: 'Doha', asOf: DateTime.utc(2026, 11, 16));
      expect(_askedInterests(requests), isFalse);
      expect(requests.single.queryParameters['or'], isNull);
    });
  });

  group('short first page keeps walking the cursor', () {
    test('full raw pages that merge to 1 item each: walks until ~a screen '
        'is there, capped at 4 extra pages', () async {
      final rpc = _Rpc([for (var i = 0; i < 10; i++) _sparse('p$i')]);
      final n = await _start(rpc);
      expect(rpc.calls, 5, reason: 'first page + the 4-page cap');
      expect(_ids(n), ['p0', 'p1', 'p2', 'p3', 'p4']);
      expect(n.state.hasMore, isTrue, reason: 'the next scroll resumes');
      expect(n.state.isLoading, isFalse);
    });

    test('stops as soon as about a screen of items is there', () async {
      final rpc = _Rpc([
        [for (var i = 0; i < 8; i++) ('a$i', 'post'), ..._sparse('x').skip(8)],
        [for (var i = 0; i < 20; i++) ('b$i', 'post')],
        [for (var i = 0; i < 20; i++) ('c$i', 'post')],
      ]);
      final n = await _start(rpc);
      expect(rpc.calls, 2);
      expect(_ids(n).length, 28);
    });

    test('stops when the feed is exhausted (a short raw page)', () async {
      final rpc = _Rpc([
        _sparse('p0'),
        [('p1', 'post'), ('p2', 'post')],
      ]);
      final n = await _start(rpc);
      expect(rpc.calls, 2);
      expect(_ids(n), ['p0', 'p1', 'p2']);
      expect(n.state.hasMore, isFalse);
    });

    test('a full first page does not walk', () async {
      final rpc = _Rpc([
        [for (var i = 0; i < 20; i++) ('a$i', 'post')],
      ]);
      final n = await _start(rpc);
      expect(rpc.calls, 1);
      expect(_ids(n).length, 20);
    });
  });
}
