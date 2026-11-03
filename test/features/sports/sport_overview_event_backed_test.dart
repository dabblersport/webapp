import 'dart:convert';

import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/features/sports/data/sport_overview_models.dart';
import 'package:dabbler/features/sports/data/sport_overview_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../helpers/supabase_test_client.dart';

/// KAN-745 (KAN-715 R05): the Sport Overview counts after KAN-726 (B07)
/// moved `games_next7` / `meetups_next7` onto `public.events`.
///
/// B07 keeps the result shape (20261104100700_kan714_b07_sport_overview_counts
/// .sql:190-191): seven `bigint` counts from `count(DISTINCT ...)`, which are
/// never null, and `mutual_followers jsonb` coalesced to `[]` (:259-268),
/// whose items carry nullable `display_name`, `avatar_url`, `username`. The
/// RPC returns no title, end_at, sport or id column, so the nullable fields
/// exercised here are the nested ones B07 can actually return.

const String kSportId = '11111111-1111-1111-1111-111111111111';

/// A real client over a MockClient; every request is recorded.
SupabaseClient recordingClient(List<http.Request> seen, Object body) =>
    buildTestSupabaseClient((http.Request r) async {
      seen.add(r);
      return http.Response(
        jsonEncode(body),
        200,
        headers: const <String, String>{'content-type': 'application/json'},
        request: r,
      );
    });

/// The B07 row as PostgREST returns a RETURNS TABLE function: a one-row list.
List<Map<String, dynamic>> b07Row({List<Object?> mutual = const []}) =>
    <Map<String, dynamic>>[
      <String, dynamic>{
        'followers': 1204,
        'games_next7': 7,
        'meetups_next7': 5,
        'venues': 4,
        'spaces': 9,
        'posts': 17,
        'news': 2,
        'mutual_followers': mutual,
      },
    ];

void main() {
  group('B07 event-backed sport overview', () {
    test('counts parse exactly as returned, with no recount', () async {
      final List<http.Request> seen = <http.Request>[];
      final SportOverviewRepository repo = SupabaseSportOverviewRepository(
        recordingClient(seen, b07Row()),
      );

      final Result<SportOverviewCounts, Failure> r = await repo.overview(
        kSportId,
        'CAI',
      );

      final SportOverviewCounts c = r.requireValue;
      expect(c.followers, 1204);
      expect(c.gamesNext7, 7);
      expect(c.meetupsNext7, 5);
      expect(c.venues, 4);
      expect(c.spaces, 9);
      expect(c.posts, 17);
      expect(c.news, 2);
      expect(c.mutualFollowers, isEmpty);
    });

    test('legacy null fields in mutual_followers parse and render safely', () {
      final SportOverviewCounts c = SportOverviewCounts.fromJson(
        b07Row(
          mutual: <Object?>[
            <String, dynamic>{
              'display_name': null,
              'avatar_url': null,
              'username': null,
            },
            <String, dynamic>{
              'display_name': null,
              'avatar_url': null,
              'username': 'omar',
            },
            <String, dynamic>{
              'display_name': 'Aisha',
              'avatar_url': null,
              'username': null,
            },
          ],
        ).single,
      );

      // A row with no name at all is left out; nothing is invented for it.
      expect(c.mutualFollowers, hasLength(2));
      expect(c.mutualFollowers[0].displayName, isNull);
      expect(c.mutualFollowers[0].username, 'omar');
      expect(c.mutualFollowers[0].avatarUrl, isNull);
      expect(c.mutualFollowers[0].label, 'omar');
      expect(c.mutualFollowers[1].label, 'Aisha');
      expect(c.mutualFollowers[1].username, isNull);
      // The counts are untouched by the nested nulls.
      expect(c.gamesNext7, 7);
      expect(c.meetupsNext7, 5);
    });

    test('a null mutual_followers is an empty list, not an error', () {
      final Map<String, dynamic> row = b07Row().single
        ..['mutual_followers'] = null;
      final SportOverviewCounts c = SportOverviewCounts.fromJson(row);
      expect(c.mutualFollowers, isEmpty);
      expect(c.followers, 1204);
    });

    test('calls rpc_sport_overview as one rpc read with the sport id unchanged '
        'and issues no table write', () async {
      final List<http.Request> seen = <http.Request>[];
      final SportOverviewRepository repo = SupabaseSportOverviewRepository(
        recordingClient(seen, b07Row()),
      );

      await repo.overview(kSportId, 'CAI');

      expect(seen, hasLength(1));
      final http.Request req = seen.single;
      expect(req.url.path, endsWith('/rest/v1/rpc/rpc_sport_overview'));
      // PostgREST calls a function by POST to /rpc/<name>; a table write
      // would hit /rest/v1/<table> or use PATCH / PUT / DELETE.
      expect(req.method, 'POST');
      expect(req.url.path, isNot(matches(RegExp(r'/rest/v1/(?!rpc/)'))));
      expect(req.headers['Prefer'] ?? '', isNot(contains('resolution')));
      // The id sent is the sport id itself, never an event id.
      final Map<String, dynamic> params =
          jsonDecode(req.body) as Map<String, dynamic>;
      expect(params, <String, dynamic>{
        'p_sport_id': kSportId,
        'p_city_code': 'CAI',
      });
    });
  });
}
