import 'package:dabbler/core/data/supabase_error_mapper.dart';
import 'package:dabbler/core/data/supabase_remote_data_source.dart';
import 'package:dabbler/data/models/social/post.dart';
import 'package:dabbler/data/repositories/post_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import '../../features/home/home_measure_fixtures.dart' show framePost;
import '../../helpers/supabase_test_client.dart';

// KAN-960 (CEO 2026-11-16, reverts the followed-sports match of KAN-955):
// Following shows posts whose author is a profile the ACTIVE persona follows,
// in every sport. A followed sport never pulls in a non-followed author.

const padel = '33333333-3333-3333-3333-333333333333';
const football = '11111111-1111-1111-1111-111111111111';
const tennis = '22222222-2222-2222-2222-222222222222';

/// A post row as `posts` returns it.
Map<String, dynamic> _row(String id, {String? author, String? sport}) => {
  ...framePost(id, 'Name', 'Body', 'football', 0).toJson(),
  'author_profile_id': author ?? 'stranger',
  'sport_id': sport,
  'origin_type': 'manual',
};

/// The `posts` table the fake server holds.
final _table = [
  _row('padel-by-stranger', sport: padel),
  _row('tennis-by-friend', author: 'friend', sport: tennis),
  _row('padel-by-friend', author: 'friend', sport: padel),
  _row('tennis-by-stranger', sport: tennis),
  _row('untagged-by-friend', author: 'friend'),
  _row('untagged-by-stranger'),
];

/// Evaluates the `author_profile_id=in.(a,b)` filter the client sends.
bool _matchesAuthor(Map<String, dynamic> row, String? filter) {
  if (filter == null) return true;
  final m = RegExp(r'^in\.\(([^)]*)\)$').firstMatch(filter)!;
  return m
      .group(1)!
      .replaceAll('"', '')
      .split(',')
      .contains(row['author_profile_id']);
}

/// One user with two active personas. `player` holds [follows] and
/// [interests]; `organiser` holds [organiserFollows] and [organiserInterests].
/// Each persona's profile id is `me-<persona>`. The interests (followed
/// sports) must never be read by the Following feed.
class _Server {
  _Server({this.follows = const [], this.interests, this.organiserInterests});

  final List<String> follows;
  final List<String>? interests;
  final List<String> organiserFollows = const ['organiser-friend'];
  final List<String>? organiserInterests;
  final postQueries = <Map<String, String>>[];
  final profileQueries = <Map<String, String>>[];
  var interestsRead = false;

  Future<http.Response> handle(http.Request r) async {
    final q = r.url.queryParameters;
    final path = r.url.path;
    final persona = q['persona_type']?.replaceFirst('eq.', '');
    if (path.endsWith('/profile_follows')) {
      final f = switch (q['follower_profile_id']) {
        'eq.me-player' => follows,
        'eq.me-organiser' => organiserFollows,
        _ => const <String>[],
      };
      return jsonListResponse([
        for (final id in f) {'following_profile_id': id},
      ], request: r);
    }
    if (path.endsWith('/profiles') && q['select'] == 'id') {
      profileQueries.add(q);
      return jsonListResponse([
        if (persona != null) {'id': 'me-$persona'},
      ], request: r);
    }
    if (path.endsWith('/profiles') && q['select'] == 'interests') {
      interestsRead = true;
      return jsonListResponse([
        {'interests': persona == 'organiser' ? organiserInterests : interests},
      ], request: r);
    }
    if (path.endsWith('/posts')) {
      postQueries.add(q);
      return jsonListResponse([
        for (final row in _table)
          if (_matchesAuthor(row, q['author_profile_id'])) row,
      ], request: r);
    }
    return jsonListResponse(const [], request: r);
  }
}

Future<List<String>> _following(_Server s, {String? persona = 'player'}) async {
  final client = buildTestSupabaseClient(s.handle);
  await client.auth.setInitialSession(fakeSessionJson(userId: 'u1'));
  final repo = PostRepositoryImpl(
    SupabaseService(client, SupabaseErrorMapper()),
    activePersonaType: persona,
  );
  final result = await repo.getFollowingFeed(limit: 20, offset: 0);
  return result.fold(
    (f) => fail('getFollowingFeed failed: ${f.message}'),
    (List<Post> posts) => [for (final p in posts) p.id],
  );
}

void main() {
  group('getFollowingFeed', () {
    test('person only: every post by followed people, any sport', () async {
      final s = _Server(follows: ['friend']);
      expect(await _following(s), [
        'tennis-by-friend',
        'padel-by-friend',
        'untagged-by-friend',
      ]);
      final q = s.postQueries.single;
      expect(q['author_profile_id'], 'in.("friend")');
      expect(q.containsKey('or'), isFalse);
      // The existing filters, order and server-side pagination stay.
      expect(q['origin_type'], 'in.("manual","repost")');
      expect(q['is_deleted'], 'eq.false');
      expect(q['is_hidden_admin'], 'eq.false');
      expect(q['order'], 'created_at.desc.nullslast');
      expect(q['offset'], '0');
      expect(q['limit'], '20');
    });

    test('a followed sport by a non-followed author does NOT appear', () async {
      final s = _Server(follows: ['friend'], interests: [padel, football]);
      final ids = await _following(s);
      expect(ids, [
        'tennis-by-friend',
        'padel-by-friend',
        'untagged-by-friend',
      ]);
      expect(ids, isNot(contains('padel-by-stranger')));
      expect(s.postQueries.single['author_profile_id'], 'in.("friend")');
      expect(s.interestsRead, isFalse, reason: 'followed sports never read');
    });

    test(
      'followed sports but no one followed: empty, posts never queried',
      () async {
        for (final interests in <List<String>?>[
          null,
          const [],
          const [padel],
        ]) {
          final s = _Server(interests: interests);
          expect(await _following(s), isEmpty);
          expect(s.postQueries, isEmpty);
          expect(s.interestsRead, isFalse);
        }
      },
    );

    test('only the ACTIVE persona\'s follows count', () async {
      _Server two() =>
          _Server(follows: ['friend'], organiserInterests: [padel]);

      // Active = player: follows 'friend'.
      final asPlayer = two();
      expect(await _following(asPlayer), [
        'tennis-by-friend',
        'padel-by-friend',
        'untagged-by-friend',
      ]);
      expect(asPlayer.profileQueries.single['persona_type'], 'eq.player');
      expect(asPlayer.profileQueries.single['is_active'], 'eq.true');
      expect(asPlayer.postQueries.single['author_profile_id'], 'in.("friend")');

      // Active = organiser: follows 'organiser-friend' (no posts) and padel
      // as a sport. The player's 'friend' no longer counts and padel posts
      // by people not followed do not appear.
      final asOrganiser = two();
      expect(await _following(asOrganiser, persona: 'organiser'), isEmpty);
      expect(asOrganiser.profileQueries.single['persona_type'], 'eq.organiser');
      expect(
        asOrganiser.postQueries.single['author_profile_id'],
        'in.("organiser-friend")',
      );
    });

    test('active persona unknown: empty, never another persona', () async {
      final s = _Server(follows: ['friend'], interests: [padel]);
      expect(await _following(s, persona: null), isEmpty);
      expect(s.profileQueries, isEmpty);
      expect(s.postQueries, isEmpty);
    });
  });
}
