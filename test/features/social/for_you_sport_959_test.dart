import 'dart:convert';
import 'dart:io';

import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/data/models/feed/feed_item.dart';
import 'package:dabbler/data/models/social/post.dart';
import 'package:dabbler/data/repositories/post_repository.dart';
import 'package:dabbler/features/social/providers/feed_notifier.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import '../../helpers/supabase_test_client.dart';
import '../home/home_measure_fixtures.dart' show framePost;

// KAN-959: the For you sport filter sends `p_sport_id` to get_home_feed when a
// sport is chosen, omits it for "All sports", and a change reloads page 1.

const padel = '33333333-3333-3333-3333-333333333333';

class _Posts implements PostRepository {
  @override
  Future<Result<List<Post>, Failure>> getPostsByIds(List<String> ids) async =>
      Ok([
        for (final id in ids)
          framePost(id, 'Name', 'Body', 'padel', 0).copyWith(sportId: padel),
      ]);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// `get_home_feed`: records every request body and answers [rows] posts
/// (fewer than a page, so the feed ends there).
class _Rpc {
  _Rpc(this.rows);

  final int rows;
  final bodies = <Map<String, dynamic>>[];

  Future<http.Response> handle(http.Request r) async {
    if (!r.url.path.endsWith('/rpc/get_home_feed')) {
      return jsonListResponse(const [], request: r);
    }
    bodies.add(Map<String, dynamic>.from(jsonDecode(r.body) as Map));
    final base = DateTime.utc(2026, 11, 16);
    return http.Response(
      jsonEncode([
        for (var i = 0; i < rows; i++)
          {
            'activity_id': 'p${bodies.length}-$i',
            'activity_type': 'post',
            'created_at': base.subtract(Duration(minutes: i)).toIso8601String(),
          },
      ]),
      200,
      headers: {'content-type': 'application/json'},
      request: r,
    );
  }
}

void main() {
  test('no sport: p_sport_id is not sent (today\'s call)', () async {
    final rpc = _Rpc(3);
    final n = FeedNotifier(_Posts(), buildTestSupabaseClient(rpc.handle));
    addTearDown(n.dispose);
    await pumpEventQueue();
    expect(rpc.bodies, isNotEmpty);
    for (final b in rpc.bodies) {
      expect(b.containsKey('p_sport_id'), isFalse);
      expect(b['p_limit'], 20);
    }
  });

  test('a sport is chosen: every page sends p_sport_id; a change reloads '
      'from page 1; All sports clears it', () async {
    final rpc = _Rpc(3);
    String? sport;
    final n = FeedNotifier(
      _Posts(),
      buildTestSupabaseClient(rpc.handle),
      sportId: () => sport,
    );
    addTearDown(n.dispose);
    await pumpEventQueue();
    final before = rpc.bodies.length;

    sport = padel;
    final reload = n.refilter();
    expect(n.state, isA<FeedLoading>(), reason: 'old rows are dropped');
    expect(await reload, isTrue);
    final filtered = rpc.bodies.sublist(before);
    expect(filtered, isNotEmpty);
    expect(filtered.first['p_cursor'], isNull, reason: 'page 1');
    for (final b in filtered) {
      expect(b['p_sport_id'], padel);
    }
    expect(n.state, isA<FeedData>());
    expect(n.state.items.whereType<FeedPostItem>(), isNotEmpty);

    final mid = rpc.bodies.length;
    sport = null;
    await n.refilter();
    final cleared = rpc.bodies.sublist(mid);
    expect(cleared, isNotEmpty);
    expect(cleared.first['p_cursor'], isNull);
    for (final b in cleared) {
      expect(b.containsKey('p_sport_id'), isFalse);
    }
  });

  test('the provider reads forYouSportProvider and refilters on change', () {
    final src = File(
      'lib/features/social/providers/feed_notifier.dart',
    ).readAsStringSync();
    final provider = src.substring(src.indexOf('final feedNotifierProvider'));
    expect(provider, contains('sportId: () => ref.read(forYouSportProvider)'));
    expect(provider, contains('ref.listen<String?>(forYouSportProvider'));
    expect(provider, contains('notifier.refilter()'));
    final filter = File(
      'lib/features/social/providers/for_you_sport_filter.dart',
    ).readAsStringSync();
    expect(
      filter,
      contains('final forYouSportProvider = StateProvider<String?>('),
    );
    expect(filter, isNot(contains('StateProvider.autoDispose')));
  });
}
