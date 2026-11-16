import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/data/models/social/post.dart';
import 'package:dabbler/features/social/domain/nearby_feed_loader.dart';
import 'package:dabbler/features/social/domain/nearby_ranking.dart';
import 'package:dabbler/features/social/providers/tab_feed_notifier.dart';
import 'package:flutter_test/flutter_test.dart';

import '../home/home_measure_fixtures.dart' show framePost;

// KAN-955: a tab feed judges hasMore on the raw page (rows or ranked ids it
// asked for), not on the posts that came back, and fills its first page to
// about a screenful. Unfetchable Nearby ids neither end the feed nor leave it
// nearly empty.

Post _post(String id) => framePost(id, 'Name', 'Body', 'football', 0);

List<String> _ids(TabFeedNotifier n) => [for (final p in n.state.posts) p.id];

/// [total] Nearby candidates in Dubai, newest first; only every [keepEvery]th
/// id is fetchable (the rest are hidden by RLS or deleted since ranking).
({NearbyFeedLoader loader, List<int> fetchCalls}) _nearby({
  required int total,
  required int keepEvery,
}) {
  final now = DateTime.utc(2026, 11, 16, 12);
  final calls = <int>[];
  final loader = NearbyFeedLoader(
    clock: () => now,
    fetchCandidates: ({required city, required asOf, area, countryCode}) async => [
      for (var i = 0; i < total; i++)
        NearbyCandidate(
          id: 'n$i',
          createdAt: now.subtract(Duration(minutes: i)),
        ),
    ],
    postsByIds: (ids) async {
      calls.add(ids.length);
      return Ok([
        for (final id in ids)
          if (int.parse(id.substring(1)) % keepEvery == 0) _post(id),
      ]);
    },
  );
  return (loader: loader, fetchCalls: calls);
}

Future<TabFeedNotifier> _start(NearbyFeedLoader loader) async {
  final n = TabFeedNotifier.ranked(
    ({required limit, required offset}) => loader.loadRankedPage(
      scope: const NearbyScope(city: 'Dubai'),
      limit: limit,
      offset: offset,
    ),
  );
  addTearDown(n.dispose);
  await pumpEventQueue();
  return n;
}

void main() {
  group('Nearby with unfetchable ids', () {
    test('first page walks until about a screen is there', () async {
      // 1 in 5 fetchable: 4 posts per raw page of 20 -> 3 pages give 12.
      final nb = _nearby(total: 200, keepEvery: 5);
      final n = await _start(nb.loader);
      expect(nb.fetchCalls, [20, 20, 20]);
      expect(_ids(n).length, 12);
      expect(n.state.hasMore, isTrue, reason: 'raw pages were full');
    });

    test(
      'the walk is capped; hasMore stays so the next scroll resumes',
      () async {
        // 1 in 20 fetchable: 1 post per raw page.
        final nb = _nearby(total: 400, keepEvery: 20);
        final n = await _start(nb.loader);
        expect(nb.fetchCalls.length, 5, reason: 'first page + 4-page cap');
        expect(_ids(n), ['n0', 'n20', 'n40', 'n60', 'n80']);
        expect(n.state.hasMore, isTrue);

        await n.loadMore();
        expect(_ids(n).last, 'n100');
        expect(n.state.hasMore, isTrue);
      },
    );

    test('a raw page that merges to nothing does not end the feed', () async {
      // n0..n19 and n40..n59 are fetchable; n20..n39 are not.
      final now = DateTime.utc(2026, 11, 16, 12);
      final loader = NearbyFeedLoader(
        clock: () => now,
        fetchCandidates: ({required city, required asOf, area, countryCode}) async => [
          for (var i = 0; i < 60; i++)
            NearbyCandidate(
              id: 'n$i',
              createdAt: now.subtract(Duration(minutes: i)),
            ),
        ],
        postsByIds: (ids) async => Ok([
          for (final id in ids)
            if (int.parse(id.substring(1)) < 20 ||
                int.parse(id.substring(1)) >= 40)
              _post(id),
        ]),
      );
      final n = await _start(loader);
      expect(_ids(n).length, 20);
      expect(n.state.hasMore, isTrue);

      await n.loadMore(); // n20..n39 all unfetchable -> walks on to n40..
      expect(_ids(n).length, 40);
      expect(_ids(n).contains('n40'), isTrue);
      expect(n.state.hasMore, isTrue);

      await n.loadMore(); // nothing left
      expect(n.state.hasMore, isFalse);
    });

    test('the feed ends on a short raw page', () async {
      final nb = _nearby(total: 25, keepEvery: 5);
      final n = await _start(nb.loader);
      expect(nb.fetchCalls, [20, 5]);
      expect(_ids(n), ['n0', 'n5', 'n10', 'n15', 'n20']);
      expect(n.state.hasMore, isFalse);
    });
  });

  group('plain fetcher (Following): raw count is the posts returned', () {
    test('a short page ends the feed and does not walk', () async {
      var calls = 0;
      final n = TabFeedNotifier(({required limit, required offset}) async {
        calls++;
        return Ok<List<Post>, Failure>([_post('a'), _post('b')]);
      });
      addTearDown(n.dispose);
      await pumpEventQueue();
      expect(calls, 1);
      expect(_ids(n), ['a', 'b']);
      expect(n.state.hasMore, isFalse);
    });
  });
}
