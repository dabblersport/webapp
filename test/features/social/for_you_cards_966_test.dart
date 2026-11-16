import 'dart:convert';

import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/data/models/feed/feed_item.dart';
import 'package:dabbler/data/models/social/post.dart';
import 'package:dabbler/data/repositories/post_repository.dart';
import 'package:dabbler/features/social/providers/feed_impressions.dart';
import 'package:dabbler/features/social/providers/feed_notifier.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import '../../helpers/supabase_test_client.dart';
import '../home/home_measure_fixtures.dart' show framePost;

// KAN-966: get_home_feed rows with item_kind 'active' become FeedActiveItem
// cards in the server's order; the next page sends the 3-part keyset
// (feed_at, cursor_id, item_kind); cards survive the offline cache; the
// impression tracker batches, dedupes and caps at 200.

class _Posts implements PostRepository {
  @override
  Future<Result<List<Post>, Failure>> getPostsByIds(List<String> ids) async =>
      Ok([for (final id in ids) framePost(id, 'Name', 'Body', 'padel', 0)]);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final DateTime _base = DateTime.utc(2026, 11, 16, 12);

Map<String, dynamic> _post(String id, int minutes) {
  final at = _base.subtract(Duration(minutes: minutes)).toIso8601String();
  return <String, dynamic>{
    'activity_id': id,
    'activity_type': 'post',
    'created_at': at,
    'source': 'push',
    'item_kind': 'post',
    'feed_at': at,
    'cursor_id': id,
  };
}

/// A card placed after the post [anchor] posted [minutes] ago.
Map<String, dynamic> _card(String id, String anchor, int minutes) {
  final at = _base.subtract(Duration(minutes: minutes)).toIso8601String();
  return <String, dynamic>{
    'activity_id': id,
    'activity_type': 'game_created',
    'created_at': at,
    'source': 'active',
    'item_kind': 'active',
    'feed_at': at,
    'cursor_id': anchor,
    'score': 72.5,
    'event_type': 'game_created',
    'event_at': _base.subtract(const Duration(hours: 1)).toIso8601String(),
    'entity_kind': 'game',
    'entity_id': id,
    'city': 'Dubai',
    'title': 'Friday 5-a-side',
    'actor_display_name': 'Omar Hassan',
    'actor_avatar_url': null,
    'detail': 'Zayed Sports City',
    'start_at': _base.add(const Duration(hours: 5)).toIso8601String(),
    'end_at': _base.add(const Duration(hours: 6)).toIso8601String(),
    'is_live': false,
    'sport_names_en': <String>['Football'],
    'sport_names_ar': <String>['كرة القدم'],
    'participant_count': 6,
    'capacity': 10,
    'space_count': null,
  };
}

class _Rpc {
  _Rpc(this.pages);

  final List<List<Map<String, dynamic>>> pages;
  final bodies = <Map<String, dynamic>>[];

  Future<http.Response> handle(http.Request r) async {
    if (!r.url.path.endsWith('/rpc/get_home_feed')) {
      return jsonListResponse(const [], request: r);
    }
    bodies.add(Map<String, dynamic>.from(jsonDecode(r.body) as Map));
    final i = bodies.length - 1;
    return http.Response(
      jsonEncode(i < pages.length ? pages[i] : const <Object>[]),
      200,
      headers: {'content-type': 'application/json'},
      request: r,
    );
  }
}

void main() {
  group('parse', () {
    test('an active row is a FeedActiveItem with the card fields', () {
      final c = FeedActiveItem.fromHomeFeedRow(_card('g1', 'p1', 0))!;
      expect(c.item.eventType, 'game_created');
      expect(c.item.entityKind, 'game');
      expect(c.item.entityId, 'g1');
      expect(c.item.title, 'Friday 5-a-side');
      expect(c.item.actorName, 'Omar Hassan');
      expect(c.item.sportsFor('ar'), <String>['كرة القدم']);
      expect(c.item.participantCount, 6);
      expect(c.item.capacity, 10);
      expect(c.cursorId, 'p1');
      expect(c.score, 72.5);
      expect(c.feedAt, _base);
    });

    test('a post row, or a card without its entity, is not a card', () {
      expect(FeedActiveItem.fromHomeFeedRow(_post('p1', 0)), isNull);
      final broken = _card('g1', 'p1', 0)..remove('entity_id');
      expect(FeedActiveItem.fromHomeFeedRow(broken), isNull);
    });

    test('the cache shape parses back to the same card', () {
      final c = FeedActiveItem.fromHomeFeedRow(_card('g1', 'p1', 0))!;
      final back = FeedActiveItem.fromHomeFeedRow(
        jsonDecode(jsonEncode(c.toCacheJson())) as Map<String, dynamic>,
      )!;
      expect(back.item.id, c.item.id);
      expect(back.cursorId, c.cursorId);
      expect(back.feedAt, c.feedAt);
      expect(back.item.title, c.item.title);
    });
  });

  group('FeedNotifier', () {
    test(
      'keeps the server order: post, card, post; drops a broken card',
      () async {
        final rpc = _Rpc([
          [
            _post('p1', 0),
            _card('g1', 'p1', 0),
            _post('p2', 5),
            _card('g2', 'p2', 5)..remove('entity_id'),
            _post('p3', 9),
          ],
        ]);
        final n = FeedNotifier(_Posts(), buildTestSupabaseClient(rpc.handle));
        addTearDown(n.dispose);
        await pumpEventQueue();
        final items = n.state.items;
        expect(items.map((i) => i.runtimeType).toList(), <Type>[
          FeedPostItem,
          FeedActiveItem,
          FeedPostItem,
          FeedPostItem,
        ]);
        expect((items[1] as FeedActiveItem).item.entityId, 'g1');
      },
    );

    test('page 1 sends no cursor; the next page sends feed_at, cursor_id and '
        'item_kind of the last row', () async {
      // 20 rows (a full page) ending on a card, then one more page.
      final page1 = <Map<String, dynamic>>[
        for (var i = 0; i < 19; i++) _post('p$i', i),
        _card('g1', 'p18', 18),
      ];
      final rpc = _Rpc([
        page1,
        [_post('p99', 40)],
      ]);
      final n = FeedNotifier(_Posts(), buildTestSupabaseClient(rpc.handle));
      addTearDown(n.dispose);
      await pumpEventQueue();
      expect(rpc.bodies.first['p_cursor'], isNull);
      expect(rpc.bodies.first.containsKey('p_cursor_id'), isFalse);
      expect(rpc.bodies.first.containsKey('p_cursor_kind'), isFalse);
      expect(rpc.bodies.length, 1, reason: '20 items need no first-page fill');
      await n.loadMore();
      expect(rpc.bodies.length, 2);
      final next = rpc.bodies[1];
      expect(
        DateTime.parse(next['p_cursor'] as String),
        _base.subtract(const Duration(minutes: 18)),
      );
      expect(next['p_cursor_id'], 'p18');
      expect(next['p_cursor_kind'], 'active');
      expect(n.state.items.whereType<FeedActiveItem>(), hasLength(1));
    });

    test('a cursor cached before KAN-966 pages the legacy way', () {
      final legacy = HomeFeedCursor.fromCache('2026-11-16T10:00:00.000Z')!;
      expect(legacy.params.keys, <String>['p_cursor']);
      final keyed = HomeFeedCursor.fromCache(
        HomeFeedCursor(_base, id: 'p1', kind: 'post').toJson(),
      )!;
      expect(keyed.params, <String, dynamic>{
        'p_cursor': _base.toIso8601String(),
        'p_cursor_id': 'p1',
        'p_cursor_kind': 'post',
      });
    });
  });

  group('FeedImpressionTracker', () {
    const delay = Duration(milliseconds: 20);
    Future<void> settle() => Future<void>.delayed(delay * 3);

    test('marks are debounced into one batch, each card once', () async {
      final sent = <List<FeedImpression>>[];
      final t = FeedImpressionTracker((b) async => sent.add(b), delay: delay);
      t.markSeen('game', 'g1', feedAt: _base);
      t.markSeen('venue', 'v1');
      t.markSeen('game', 'g1', feedAt: _base);
      expect(sent, isEmpty, reason: 'debounced');
      await settle();
      expect(sent, hasLength(1));
      expect(sent.single, <FeedImpression>[
        {
          'entity_type': 'game',
          'entity_id': 'g1',
          'feed_at': _base.toIso8601String(),
        },
        {'entity_type': 'venue', 'entity_id': 'v1'},
      ]);
      t.markSeen('game', 'g1');
      await settle();
      expect(sent, hasLength(1), reason: 'already sent this session');
    });

    test('200 is a full batch, sent at once', () async {
      final sent = <List<FeedImpression>>[];
      final t = FeedImpressionTracker((b) async => sent.add(b), delay: delay);
      for (var i = 0; i < 230; i++) {
        t.markSeen('profile', 'u$i');
      }
      await pumpEventQueue();
      expect(sent, hasLength(1));
      expect(sent.first, hasLength(200));
      await settle();
      expect(sent, hasLength(2));
      expect(sent[1], hasLength(30));
    });

    test('a failed batch is sent again the next time the card shows', () async {
      var fail = true;
      final sent = <List<FeedImpression>>[];
      final t = FeedImpressionTracker((b) async {
        if (fail) throw Exception('offline');
        sent.add(b);
      }, delay: delay);
      t.markSeen('meetup', 'm1');
      await settle();
      expect(sent, isEmpty);
      fail = false;
      t.markSeen('meetup', 'm1');
      await settle();
      expect(sent.single.single['entity_id'], 'm1');
    });
  });
}
