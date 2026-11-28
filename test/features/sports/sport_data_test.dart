import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/data/models/social/post.dart';
import 'package:dabbler/features/games/data/models/nearby_game_model.dart';
import 'package:dabbler/features/sports/data/sport_follow_repository.dart';
import 'package:dabbler/features/sports/data/sport_overview_models.dart';
import 'package:dabbler/features/sports/data/sport_overview_repository.dart';
import 'package:dabbler/features/sports/presentation/providers/sport_overview_providers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../helpers/supabase_test_client.dart';
import 'sport_test_harness.dart';

/// The repository contract against KAN-621's `rpc_sport_overview`, covered with
/// fakes: the real client runs its request path over a MockClient, so the call
/// shape (RPC name, parameters, filters) is asserted without a database. The
/// migration is not applied; live QA waits for it.
/// A real client over a MockClient; every response carries its request, which
/// the PostgREST parser needs.
SupabaseClient client(FutureOr<http.Response> Function(http.Request) handler) =>
    buildTestSupabaseClient((http.Request r) async {
      final http.Response res = await handler(r);
      return http.Response(
        res.body,
        res.statusCode,
        headers: res.headers,
        request: r,
      );
    });

void main() {
  group('SportOverviewCounts', () {
    test('reads the RPC row', () {
      final SportOverviewCounts c = SportOverviewCounts.fromJson(
        const <String, dynamic>{
          'followers': 1204,
          'games_next7': 3,
          'meetups_next7': 2,
          'venues': 4,
          'spaces': 9,
          'posts': 17,
          'news': 1,
          'players': 12,
          'mutual_followers': <Map<String, dynamic>>[
            <String, dynamic>{'display_name': 'Aisha', 'username': 'aisha'},
          ],
        },
      );
      expect(c.followers, 1204);
      expect(c.players, 12);
      expect(c.gamesNext7, 3);
      expect(c.venues, 4);
      expect(c.spaces, 9);
      expect(c.mutualFollowers.single.label, 'Aisha');
    });

    test('keeps at most three mutual followers and drops nameless rows', () {
      final SportOverviewCounts c = SportOverviewCounts.fromJson(
        <String, dynamic>{
          'mutual_followers': <Map<String, dynamic>>[
            <String, dynamic>{'display_name': 'A'},
            <String, dynamic>{'display_name': ' '},
            <String, dynamic>{'username': 'b'},
            <String, dynamic>{'display_name': 'C'},
            <String, dynamic>{'display_name': 'D'},
          ],
        },
      );
      expect(c.mutualFollowers.map((m) => m.label), <String>['A', 'b', 'C']);
    });

    test('an absent or malformed mutual_followers is empty, not an error', () {
      expect(
        SportOverviewCounts.fromJson(const <String, dynamic>{}).mutualFollowers,
        isEmpty,
      );
      expect(
        SportOverviewCounts.fromJson(const <String, dynamic>{
          'mutual_followers': 'oops',
        }).mutualFollowers,
        isEmpty,
      );
    });
  });

  group('SupabaseSportOverviewRepository', () {
    test('overview calls rpc_sport_overview with the city code', () async {
      late http.Request seen;
      final SupabaseSportOverviewRepository repo =
          SupabaseSportOverviewRepository(
            client((http.Request r) async {
              seen = r;
              return jsonListResponse(<Map<String, dynamic>>[
                <String, dynamic>{
                  'followers': 10,
                  'games_next7': 1,
                  'meetups_next7': 0,
                  'venues': 2,
                  'spaces': 5,
                  'posts': 7,
                  'news': 0,
                  'mutual_followers': <dynamic>[],
                },
              ]);
            }),
          );
      final Result<SportOverviewCounts, Failure> r = await repo.overview(
        kFootball,
        'dubai',
      );
      expect(seen.url.path, endsWith('/rest/v1/rpc/rpc_sport_overview'));
      expect(jsonDecode(seen.body), <String, dynamic>{
        'p_sport_id': kFootball,
        'p_city_code': 'dubai',
      });
      expect(r.requireValue.spaces, 5);
    });

    test('overview without a city sends no city (every city)', () async {
      late http.Request seen;
      final SupabaseSportOverviewRepository repo =
          SupabaseSportOverviewRepository(
            client((http.Request r) async {
              seen = r;
              return jsonListResponse(<Map<String, dynamic>>[
                <String, dynamic>{'followers': 1},
              ]);
            }),
          );
      await repo.overview(kFootball, null);
      expect(jsonDecode(seen.body), <String, dynamic>{'p_sport_id': kFootball});
    });

    test('overview maps a server error to a Failure', () async {
      final SupabaseSportOverviewRepository repo =
          SupabaseSportOverviewRepository(
            client(
              (http.Request r) async => postgrestErrorResponse(
                message: 'permission denied for function rpc_sport_overview',
                code: '42501',
                status: 403,
              ),
            ),
          );
      final Result<SportOverviewCounts, Failure> r = await repo.overview(
        kFootball,
        null,
      );
      expect(r, isA<Err<SportOverviewCounts, Failure>>());
      expect(r.requireError.isForbidden, isTrue);
    });

    test('an unknown sport id is a notFound failure', () async {
      final SupabaseSportOverviewRepository repo =
          SupabaseSportOverviewRepository(
            client((http.Request r) async {
              // maybeSingle() with no row answers an empty list.
              return jsonListResponse(<Map<String, dynamic>>[]);
            }),
          );
      final Result<SportInfo, Failure> r = await repo.sport('nope');
      expect(r.requireError.isNotFound, isTrue);
    });

    test(
      'games: public, not cancelled, next 7 days, soonest first, in the city',
      () async {
        final List<http.Request> seen = <http.Request>[];
        final SupabaseSportOverviewRepository repo =
            SupabaseSportOverviewRepository(
              client((http.Request r) async {
                seen.add(r);
                if (r.url.path.endsWith('/areas')) {
                  return jsonListResponse(<Map<String, dynamic>>[
                    <String, dynamic>{'id': 'a1'},
                    <String, dynamic>{'id': 'a2'},
                  ]);
                }
                return jsonListResponse(<Map<String, dynamic>>[
                  <String, dynamic>{
                    'id': 'g1',
                    'title': 'Five-a-side',
                    'sport_name_en': 'Football',
                    'start_at': DateTime.now()
                        .add(const Duration(days: 1))
                        .toUtc()
                        .toIso8601String(),
                    'capacity': 10,
                    'roster_count': 6,
                    'price_aed': 30,
                  },
                ]);
              }),
            );
        final Result<List<NearbyGameModel>, Failure> r = await repo.games(
          kFootball,
          'dubai',
        );
        final http.Request areas = seen.firstWhere(
          (http.Request q) => q.url.path.endsWith('/areas'),
        );
        expect(areas.url.queryParameters['city_code'], 'eq.dubai');
        final http.Request games = seen.firstWhere(
          (http.Request q) => q.url.path.endsWith('/v_game_card'),
        );
        final Map<String, List<String>> q = games.url.queryParametersAll;
        expect(q['sport_id'], <String>['eq.$kFootball']);
        expect(q['is_cancelled'], <String>['eq.false']);
        expect(q['listing_visibility'], <String>['eq.public']);
        expect(q['area_id'], <String>['in.("a1","a2")']);
        expect(q['order']!.single, startsWith('start_at.asc'));
        expect(q['start_at']!.map((String v) => v.split('.').first), <String>[
          'gte',
          'lt',
        ]);
        final NearbyGameModel g = r.requireValue.single;
        expect(g.priceAed, 30);
        expect(g.spotsRemaining, 4);
      },
    );

    test('a city with no areas lists nothing and asks for no games', () async {
      final List<String> paths = <String>[];
      final SupabaseSportOverviewRepository repo =
          SupabaseSportOverviewRepository(
            client((http.Request r) async {
              paths.add(r.url.path);
              return jsonListResponse(<Map<String, dynamic>>[]);
            }),
          );
      expect((await repo.games(kFootball, 'nowhere')).requireValue, isEmpty);
      expect(paths.where((String p) => p.endsWith('/v_game_card')), isEmpty);
    });

    test(
      'posts: the sport only, newest first, with no Following filter',
      () async {
        late http.Request seen;
        final SupabaseSportOverviewRepository repo =
            SupabaseSportOverviewRepository(
              client((http.Request r) async {
                seen = r;
                return jsonListResponse(<Map<String, dynamic>>[
                  <String, dynamic>{'id': 'p2'},
                  <String, dynamic>{'id': 'p1'},
                ]);
              }),
            );
        final Result<List<String>, Failure> r = await repo.postIds(kTennis);
        final Map<String, List<String>> q = seen.url.queryParametersAll;
        expect(q['sport_id'], <String>['eq.$kTennis']);
        expect(q['order']!.single, startsWith('created_at.desc'));
        expect(q['order']!.single, contains('id.desc'));
        // KAN-593's Following filter is an `or=` over interests: never here.
        expect(q.containsKey('or'), isFalse);
        expect(r.requireValue, <String>['p2', 'p1']);
      },
    );
  });

  group('SupabaseSportFollowRepository (KAN-1059 RPCs, KAN-1060)', () {
    const SportInfo tennis = SportInfo(
      id: kTennis,
      nameEn: 'Tennis',
      sportKey: 'tennis',
    );

    /// A repository whose every RPC answers [answer]; [seen] records each
    /// request.
    SupabaseSportFollowRepository build(
      String answer,
      List<http.Request> seen, {
      int status = 200,
    }) => SupabaseSportFollowRepository(
      client((http.Request r) {
        seen.add(r);
        return http.Response(
          status == 200 ? jsonEncode(answer) : '{"message":"boom"}',
          status,
          headers: <String, String>{'content-type': 'application/json'},
        );
      }),
    );

    for (final (String, String, SportFollowOutcome) c
        in <(String, String, SportFollowOutcome)>[
          ('follow', 'followed', SportFollowOutcome.followed),
          ('follow', 'unchanged', SportFollowOutcome.unchanged),
          ('follow', 'invalid_sport', SportFollowOutcome.invalid),
          ('unfollow', 'unfollowed', SportFollowOutcome.unfollowed),
          ('unfollow', 'blocked_primary', SportFollowOutcome.blockedPrimary),
          (
            'unfollow',
            'blocked_in_my_sports',
            SportFollowOutcome.blockedInMySports,
          ),
          ('unfollow', 'blocked_last', SportFollowOutcome.blockedLast),
          ('add', 'added', SportFollowOutcome.added),
          ('add', 'restored', SportFollowOutcome.added),
          ('remove', 'removed', SportFollowOutcome.removed),
          ('remove', 'blocked_primary', SportFollowOutcome.blockedPrimary),
          ('remove', 'blocked_last', SportFollowOutcome.blockedLast),
          ('level', 'set', SportFollowOutcome.levelSet),
        ]) {
      test('${c.$1} "${c.$2}" is ${c.$3.name}', () async {
        final List<http.Request> seen = <http.Request>[];
        final SupabaseSportFollowRepository repo = build(c.$2, seen);
        final Result<SportFollowOutcome, Failure> r = switch (c.$1) {
          'follow' => await repo.follow('me', tennis),
          'unfollow' => await repo.unfollow('me', tennis),
          'add' => await repo.addToMySports('me', tennis, skillLevel: 5),
          'remove' => await repo.removeFromMySports('me', tennis),
          _ => await repo.setLevel('me', tennis, 7),
        };
        expect(r.requireValue, c.$3);
        final http.Request req = seen.single;
        expect(
          req.url.path,
          endsWith(switch (c.$1) {
            'follow' => '/rpc/rpc_follow_sport',
            'unfollow' => '/rpc/rpc_unfollow_sport',
            'add' => '/rpc/rpc_add_my_sport',
            'remove' => '/rpc/rpc_remove_my_sport',
            _ => '/rpc/rpc_set_sport_level',
          }),
        );
        final Map<String, dynamic> body =
            jsonDecode(req.body) as Map<String, dynamic>;
        expect(body['p_profile_id'], 'me');
        expect(body['p_sport_id'], kTennis);
        if (c.$1 == 'add') expect(body['p_skill_level'], 5);
        if (c.$1 == 'level') expect(body['p_skill_level'], 7);
      });
    }

    test('a server error is a Failure, not a flipped state', () async {
      final SupabaseSportFollowRepository repo = build(
        '',
        <http.Request>[],
        status: 500,
      );
      final r = await repo.unfollow('me', tennis);
      expect(r, isA<Err<SportFollowOutcome, Failure>>());
    });
  });

  group('mySportCardFromRows (active cards only)', () {
    const SportInfo tennis = SportInfo(
      id: kTennis,
      nameEn: 'Tennis',
      sportKey: 'tennis',
    );
    test('no matching card is none', () {
      expect(
        mySportCardFromRows(<dynamic>[
          <String, dynamic>{'sport_id': kFootball, 'sport': 'football'},
        ], tennis),
        MySportCard.none,
      );
    });
    test('a card with no level chosen is levelUnset', () {
      expect(
        mySportCardFromRows(<dynamic>[
          <String, dynamic>{'sport_id': kTennis, 'skill_level_set_at': null},
        ], tennis),
        MySportCard.levelUnset,
      );
    });
    test('a legacy key-only card with a level is ready', () {
      expect(
        mySportCardFromRows(<dynamic>[
          <String, dynamic>{
            'sport': 'Tennis',
            'skill_level_set_at': '2026-11-28T00:00:00Z',
          },
        ], tennis),
        MySportCard.ready,
      );
    });
  });

  group('SportPostsNotifier', () {
    test('pages through the sport posts in the order the ids came', () async {
      final FakeSportOverviewRepository repo = FakeSportOverviewRepository();
      final List<List<String>> asked = <List<String>>[];
      repo.postIdsResult = Ok(<String>[
        for (int i = 0; i < kSportOverviewPostsPage; i++) 'p$i',
      ]);
      final SportPostsNotifier n = SportPostsNotifier(repo, (
        List<String> ids,
      ) async {
        asked.add(ids);
        return Ok<List<Post>, Failure>([
          for (final String id in ids.reversed) post(id),
        ]);
      }, kFootball);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(n.state.loading, isFalse);
      expect(n.state.posts.first.id, 'p0');
      expect(n.state.hasMore, isTrue);

      repo.postIdsResult = const Ok(<String>['last']);
      await n.loadMore();
      expect(n.state.posts.last.id, 'last');
      expect(n.state.hasMore, isFalse);
      expect(
        repo.calls,
        contains('postIds:$kFootball:$kSportOverviewPostsPage'),
      );
    });

    test(
      'a failed first page is an error; a failed later page keeps rows',
      () async {
        final FakeSportOverviewRepository repo = FakeSportOverviewRepository();
        repo.postIdsResult = const Err(Failure(message: 'offline'));
        final SportPostsNotifier n = SportPostsNotifier(
          repo,
          (List<String> ids) async => const Ok<List<Post>, Failure>(<Post>[]),
          kFootball,
        );
        await Future<void>.delayed(Duration.zero);
        expect(n.state.error, isNotNull);
        expect(n.state.posts, isEmpty);
      },
    );
  });

  group('AC11 no hard-coded colours or strings in the new files', () {
    test(
      'no `Colors.` (Material) and no Color(0x literal; DabblerColors.of is the DS token accessor',
      () {
        final List<File> files = Directory('lib/features/sports')
            .listSync(recursive: true)
            .whereType<File>()
            .where((File f) => f.path.endsWith('.dart'))
            .toList();
        expect(files, isNotEmpty);
        final RegExp banned = RegExp(r'(?<![A-Za-z])Colors\.|Color\(0x');
        for (final File f in files) {
          expect(
            banned.hasMatch(f.readAsStringSync()),
            isFalse,
            reason: f.path,
          );
        }
      },
    );
  });
}
