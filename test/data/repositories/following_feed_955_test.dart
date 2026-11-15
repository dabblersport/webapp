import 'package:dabbler/core/data/supabase_error_mapper.dart';
import 'package:dabbler/core/data/supabase_remote_data_source.dart';
import 'package:dabbler/data/models/social/post.dart';
import 'package:dabbler/data/repositories/following_sport_filter.dart';
import 'package:dabbler/data/repositories/post_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import '../../features/home/home_measure_fixtures.dart' show framePost;
import '../../helpers/supabase_test_client.dart';

// KAN-955 (CEO 2026-11-16): Following shows posts whose author is a followed
// profile OR whose sport is one of the active persona's followed sports
// (`profiles.interests`), in one server-side query.

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

/// Evaluates the `or=(col.in.(a,b),col.in.(c))` the client sends, the way
/// PostgREST does: a row is returned once if ANY clause matches.
bool _matchesOr(Map<String, dynamic> row, String? or) {
  if (or == null) return true;
  final clauses = RegExp(
    r'(\w+)\.in\.\(([^)]*)\)',
  ).allMatches(or.substring(1, or.length - 1));
  return clauses.any(
    (m) => m.group(2)!.split(',').contains(row[m.group(1)!] as String?),
  );
}

/// One user with two active personas. `player` holds [follows] and
/// [interests]; `organiser` holds [organiserFollows] and [organiserInterests].
/// Each persona's profile id is `me-<persona>`.
class _Server {
  _Server({this.follows = const [], this.interests, this.organiserInterests});

  final List<String> follows;
  final List<String>? interests;
  final List<String> organiserFollows = const ['organiser-friend'];
  final List<String>? organiserInterests;
  final postQueries = <Map<String, String>>[];
  final profileQueries = <Map<String, String>>[];

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
      return jsonListResponse([
        {'interests': persona == 'organiser' ? organiserInterests : interests},
      ], request: r);
    }
    if (path.endsWith('/posts')) {
      postQueries.add(q);
      return jsonListResponse([
        for (final row in _table)
          if (_matchesOr(row, q['or'])) row,
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
  group('followingFeedOrFilter', () {
    test('people and sports: one or= with both sets, sorted', () {
      expect(
        followingFeedOrFilter(['p2', 'p1', 'p2'], {padel, football}),
        'author_profile_id.in.(p1,p2),sport_id.in.($football,$padel)',
      );
    });

    test('only one set present: just that set', () {
      expect(followingFeedOrFilter(['p1'], null), 'author_profile_id.in.(p1)');
      expect(followingFeedOrFilter(['p1'], {}), 'author_profile_id.in.(p1)');
      expect(followingFeedOrFilter([], {padel}), 'sport_id.in.($padel)');
    });

    test('neither: null (empty state, no query)', () {
      expect(followingFeedOrFilter([], null), isNull);
      expect(followingFeedOrFilter([], {}), isNull);
    });
  });

  group('getFollowingFeed', () {
    test('sport only: posts in followed sports from anyone', () async {
      final s = _Server(interests: [padel]);
      expect(await _following(s), ['padel-by-stranger', 'padel-by-friend']);
      expect(s.postQueries.single['or'], '(sport_id.in.($padel))');
    });

    test('person only: every post by followed people', () async {
      final s = _Server(follows: ['friend']);
      expect(await _following(s), [
        'tennis-by-friend',
        'padel-by-friend',
        'untagged-by-friend',
      ]);
      expect(s.postQueries.single['or'], '(author_profile_id.in.(friend))');
    });

    test('both: union of the two, a post matching both appears once', () async {
      final s = _Server(follows: ['friend'], interests: [padel, football]);
      final ids = await _following(s);
      expect(ids, [
        'padel-by-stranger',
        'tennis-by-friend',
        'padel-by-friend',
        'untagged-by-friend',
      ]);
      expect(ids.toSet().length, ids.length, reason: 'no duplicates');
      final q = s.postQueries.single;
      expect(
        q['or'],
        '(author_profile_id.in.(friend),sport_id.in.($football,$padel))',
      );
      // The existing filters, order and server-side pagination stay.
      expect(q['origin_type'], 'in.("manual","repost")');
      expect(q['is_deleted'], 'eq.false');
      expect(q['is_hidden_admin'], 'eq.false');
      expect(q['order'], 'created_at.desc.nullslast');
      expect(q['offset'], '0');
      expect(q['limit'], '20');
    });

    test('no one and no sport followed: empty, posts never queried', () async {
      for (final interests in <List<String>?>[null, const []]) {
        final s = _Server(interests: interests);
        expect(await _following(s), isEmpty);
        expect(s.postQueries, isEmpty);
      }
    });

    test('only the ACTIVE persona\'s follows and sports count', () async {
      _Server two() =>
          _Server(follows: ['friend'], organiserInterests: [padel]);

      // Active = player: follows 'friend', no sport.
      final asPlayer = two();
      expect(await _following(asPlayer), [
        'tennis-by-friend',
        'padel-by-friend',
        'untagged-by-friend',
      ]);
      expect(asPlayer.profileQueries.single['persona_type'], 'eq.player');
      expect(asPlayer.profileQueries.single['is_active'], 'eq.true');
      expect(
        asPlayer.postQueries.single['or'],
        '(author_profile_id.in.(friend))',
      );

      // Active = organiser: follows padel and 'organiser-friend' (no posts);
      // the player's 'friend' no longer counts.
      final asOrganiser = two();
      expect(await _following(asOrganiser, persona: 'organiser'), [
        'padel-by-stranger',
        'padel-by-friend',
      ]);
      expect(asOrganiser.profileQueries.single['persona_type'], 'eq.organiser');
      expect(
        asOrganiser.postQueries.single['or'],
        '(author_profile_id.in.(organiser-friend),sport_id.in.($padel))',
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
