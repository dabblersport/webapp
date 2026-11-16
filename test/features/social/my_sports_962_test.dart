import 'dart:convert';
import 'dart:io';

import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/data/models/feed/feed_item.dart';
import 'package:dabbler/data/models/profile/user_profile.dart';
import 'package:dabbler/data/models/social/post.dart';
import 'package:dabbler/data/repositories/post_repository.dart';
import 'package:dabbler/features/home/presentation/models/feed_tab.dart';
import 'package:dabbler/features/home/presentation/providers/home_feed_scopes.dart';
import 'package:dabbler/features/home/presentation/widgets/home_tab_tags.dart';
import 'package:dabbler/features/profile/presentation/providers/profile_providers.dart';
import 'package:dabbler/features/social/providers/feed_notifier.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import '../../helpers/supabase_test_client.dart';
import '../home/home_measure_fixtures.dart' show framePost;

// KAN-962: For you "My sports" sends the active persona's followed sports to
// get_home_feed as `p_sport_ids`, omits it for "All sports", makes no call
// when the persona follows none, and a change reloads page 1.

const padel = '33333333-3333-3333-3333-333333333333';
const tennis = '22222222-2222-2222-2222-222222222222';

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

UserProfile _profile(List<String>? interests) => UserProfile(
  id: 'me',
  userId: 'u',
  displayName: 'Me',
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
  interests: interests,
);

void main() {
  test('All sports: neither p_sport_ids nor p_sport_id is sent', () async {
    final rpc = _Rpc(3);
    final n = FeedNotifier(_Posts(), buildTestSupabaseClient(rpc.handle));
    addTearDown(n.dispose);
    await pumpEventQueue();
    expect(rpc.bodies, isNotEmpty);
    for (final b in rpc.bodies) {
      expect(b.containsKey('p_sport_ids'), isFalse);
      expect(b.containsKey('p_sport_id'), isFalse);
      expect(b['p_limit'], 20);
    }
  });

  test('My sports: every page sends p_sport_ids; a change reloads from page '
      '1; All sports drops it', () async {
    final rpc = _Rpc(3);
    List<String>? sports;
    final n = FeedNotifier(
      _Posts(),
      buildTestSupabaseClient(rpc.handle),
      sportIds: () => sports,
    );
    addTearDown(n.dispose);
    await pumpEventQueue();
    final before = rpc.bodies.length;

    sports = [padel, tennis];
    final reload = n.refilter();
    expect(n.state, isA<FeedLoading>(), reason: 'old rows are dropped');
    expect(await reload, isTrue);
    final filtered = rpc.bodies.sublist(before);
    expect(filtered, isNotEmpty);
    expect(filtered.first['p_cursor'], isNull, reason: 'page 1');
    for (final b in filtered) {
      expect(b['p_sport_ids'], [padel, tennis]);
      expect(b.containsKey('p_sport_id'), isFalse);
    }
    expect(n.state.items.whereType<FeedPostItem>(), isNotEmpty);

    final mid = rpc.bodies.length;
    sports = null;
    await n.refilter();
    final cleared = rpc.bodies.sublist(mid);
    expect(cleared, isNotEmpty);
    expect(cleared.first['p_cursor'], isNull);
    for (final b in cleared) {
      expect(b.containsKey('p_sport_ids'), isFalse);
    }
  });

  test('My sports with no followed sport: no call, no rows', () async {
    final rpc = _Rpc(3);
    final n = FeedNotifier(
      _Posts(),
      buildTestSupabaseClient(rpc.handle),
      sportIds: () => const <String>[],
    );
    addTearDown(n.dispose);
    await pumpEventQueue();
    expect(rpc.bodies, isEmpty);
    expect(n.state, isA<FeedData>());
    expect(n.state.items, isEmpty);
  });

  group('forYouSportIdsProvider', () {
    ProviderContainer container(List<String>? interests) {
      final c = ProviderContainer(
        overrides: [
          currentUserProfileProvider.overrideWithValue(_profile(interests)),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    void pick(ProviderContainer c, HomeTabTag tag) {
      final n = c.read(homeTabPicksProvider.notifier);
      n.state = toggleHomeTabPick(n.state, FeedTab.forYou, tag);
    }

    test('null until My sports is picked, then the active persona\'s '
        'interests (deduplicated); All sports clears', () {
      final c = container([padel, tennis, padel, ' ']);
      expect(c.read(forYouSportIdsProvider), isNull);
      pick(c, HomeTabTag.mySports);
      expect(c.read(forYouSportIdsProvider), [padel, tennis]);
      pick(c, HomeTabTag.allSports);
      expect(c.read(forYouSportIdsProvider), isNull);
    });

    test('no interests: an empty list (the empty state, no call)', () {
      final c = container(null);
      pick(c, HomeTabTag.mySports);
      expect(c.read(forYouSportIdsProvider), isEmpty);
    });
  });

  test('the provider sends forYouSportIdsProvider and refilters on change; '
      'only the unfiltered feed is cached', () {
    final src = File(
      'lib/features/social/providers/feed_notifier.dart',
    ).readAsStringSync();
    final provider = src.substring(src.indexOf('final feedNotifierProvider'));
    expect(
      provider,
      contains('sportIds: () => ref.read(forYouSportIdsProvider)'),
    );
    expect(
      provider,
      contains('ref.listen<List<String>?>(forYouSportIdsProvider'),
    );
    expect(provider, contains('notifier.refilter()'));
    expect(
      src,
      contains('_cache != null && _accountId != null && _sportIds() == null'),
    );
    expect(src, isNot(contains('p_sport_id\'')));
    expect(
      File(
        'lib/features/social/providers/for_you_sport_filter.dart',
      ).existsSync(),
      isFalse,
    );
  });
}
