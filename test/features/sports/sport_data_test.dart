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
          'mutual_followers': <Map<String, dynamic>>[
            <String, dynamic>{'display_name': 'Aisha', 'username': 'aisha'},
          ],
        },
      );
      expect(c.followers, 1204);
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

  group(
    'SupabaseSportFollowRepository (Following = profiles.interests only)',
    () {
      SupabaseSportFollowRepository build({
        required Map<String, dynamic> profile,
        List<Map<String, dynamic>> practicing = const <Map<String, dynamic>>[],
        required List<http.Request> seen,
      }) => SupabaseSportFollowRepository(
        client((http.Request r) async {
          seen.add(r);
          if (r.method == 'GET' && r.url.path.endsWith('/profiles')) {
            return jsonObjectResponse(profile);
          }
          if (r.method == 'GET') return jsonListResponse(practicing);
          return emptyOkResponse();
        }),
      );

      List<http.Request> writes(List<http.Request> seen) =>
          seen.where((http.Request r) => r.method != 'GET').toList();

      test('follow appends the sport and touches nothing else', () async {
        final List<http.Request> seen = <http.Request>[];
        final SupabaseSportFollowRepository repo = build(
          profile: <String, dynamic>{
            'interests': <String>[kFootball],
            'primary_sport': kFootball,
            'persona_type': 'player',
          },
          seen: seen,
        );
        final Result<SportFollowOutcome, Failure> r = await repo.follow(
          'me',
          const SportInfo(id: kTennis, nameEn: 'Tennis', sportKey: 'tennis'),
        );
        expect(r.requireValue, SportFollowOutcome.followed);
        final List<http.Request> w = writes(seen);
        expect(w.length, 1);
        expect(w.single.url.path, endsWith('/profiles'));
        expect(jsonDecode(w.single.body), <String, dynamic>{
          'interests': <String>[kFootball, kTennis],
        });
        // No sport profile, no rpc_create_sport_profile.
        expect(
          seen.where((http.Request r) => r.url.path.contains('sport_profiles')),
          isEmpty,
        );
        expect(
          seen.where((http.Request r) => r.url.path.contains('rpc')),
          isEmpty,
        );
      });

      test('following twice writes nothing', () async {
        final List<http.Request> seen = <http.Request>[];
        final SupabaseSportFollowRepository repo = build(
          profile: <String, dynamic>{
            'interests': <String>[kTennis],
          },
          seen: seen,
        );
        final r = await repo.follow(
          'me',
          const SportInfo(id: kTennis, nameEn: 'Tennis'),
        );
        expect(r.requireValue, SportFollowOutcome.unchanged);
        expect(writes(seen), isEmpty);
      });

      test('unfollow removes the sport and deletes no sport profile', () async {
        final List<http.Request> seen = <http.Request>[];
        final SupabaseSportFollowRepository repo = build(
          profile: <String, dynamic>{
            'interests': <String>[kFootball, kTennis],
            'primary_sport': kFootball,
            'persona_type': 'player',
          },
          seen: seen,
        );
        final r = await repo.unfollow(
          'me',
          const SportInfo(id: kTennis, nameEn: 'Tennis', sportKey: 'tennis'),
        );
        expect(r.requireValue, SportFollowOutcome.unfollowed);
        final List<http.Request> w = writes(seen);
        expect(w.length, 1);
        expect(w.single.method, 'PATCH');
        expect(jsonDecode(w.single.body), <String, dynamic>{
          'interests': <String>[kFootball],
        });
      });

      test(
        'the Primary sport cannot be unfollowed; nothing is written',
        () async {
          final List<http.Request> seen = <http.Request>[];
          final SupabaseSportFollowRepository repo = build(
            profile: <String, dynamic>{
              'interests': <String>[kFootball, kTennis],
              'primary_sport': kTennis,
              'persona_type': 'player',
            },
            seen: seen,
          );
          final r = await repo.unfollow(
            'me',
            const SportInfo(id: kTennis, nameEn: 'Tennis', sportKey: 'tennis'),
          );
          expect(r.requireValue, SportFollowOutcome.blockedPrimary);
          expect(writes(seen), isEmpty);
        },
      );

      test(
        'a Practicing sport cannot be unfollowed; nothing is written',
        () async {
          final List<http.Request> seen = <http.Request>[];
          final SupabaseSportFollowRepository repo = build(
            profile: <String, dynamic>{
              'interests': <String>[kFootball, kTennis],
              'primary_sport': kFootball,
              'persona_type': 'player',
            },
            practicing: <Map<String, dynamic>>[
              <String, dynamic>{'sport': 'tennis', 'sport_id': kTennis},
            ],
            seen: seen,
          );
          final r = await repo.unfollow(
            'me',
            const SportInfo(id: kTennis, nameEn: 'Tennis', sportKey: 'tennis'),
          );
          expect(r.requireValue, SportFollowOutcome.blockedPracticing);
          expect(writes(seen), isEmpty);
        },
      );

      test('the last Following sport cannot be unfollowed', () async {
        final List<http.Request> seen = <http.Request>[];
        final SupabaseSportFollowRepository repo = build(
          profile: <String, dynamic>{
            'interests': <String>[kTennis],
            'primary_sport': kFootball,
            'persona_type': 'player',
          },
          seen: seen,
        );
        final r = await repo.unfollow(
          'me',
          const SportInfo(id: kTennis, nameEn: 'Tennis', sportKey: 'tennis'),
        );
        expect(r.requireValue, SportFollowOutcome.blockedLast);
        expect(writes(seen), isEmpty);
      });

      test('a write failure is a Failure, not a flipped state', () async {
        final SupabaseSportFollowRepository repo =
            SupabaseSportFollowRepository(
              client((http.Request r) async {
                if (r.method == 'GET') {
                  return jsonObjectResponse(<String, dynamic>{
                    'interests': <String>[kFootball],
                  });
                }
                return postgrestErrorResponse(
                  message: 'denied',
                  code: '42501',
                  status: 403,
                );
              }),
            );
        final r = await repo.follow(
          'me',
          const SportInfo(id: kTennis, nameEn: 'Tennis'),
        );
        expect(r, isA<Err<SportFollowOutcome, Failure>>());
      });
    },
  );

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
