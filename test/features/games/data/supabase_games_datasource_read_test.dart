// KAN-715: the ACTIVE games reads (getGames -> Explore games tab,
// getMyGames -> Home upcoming + composer "Link a game") read the event-backed
// projections v_game_card / v_my_games, never public.games (RLS on, no policy:
// an authenticated read of games returns no rows). Filters, ordering and
// paging stay server-side, ids stay games.id, and a null-heavy row parses
// without invented values.
import 'dart:convert';

import 'package:dabbler/features/games/data/datasources/supabase_games_datasource.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import '../../../helpers/supabase_test_client.dart';

const String _gameA = '11111111-1111-1111-1111-111111111111';
const String _gameB = '22222222-2222-2222-2222-222222222222';

/// A v_game_card row with every nullable shared column null.
Map<String, dynamic> _nullCard(String id) => {
  'id': id,
  'title': null,
  'game_type': 'pickup',
  'start_at': '2099-11-10T18:00:00Z',
  'end_at': null,
  'capacity': null,
  'bench_slots': 0,
  'min_skill': null,
  'max_skill': null,
  'listing_visibility': 'public',
  'join_policy': 'open',
  'allows_waitlist': null,
  'is_cancelled': false,
  'created_at': '2026-11-01T09:30:00Z',
  'updated_at': '2026-11-02T10:45:00Z',
  'sport_id': null,
  'sport_key': null,
  'creator_profile_id': null,
  'geo_location_id': null,
  'venue_id': null,
  'venue_name': null,
  'latitude': null,
  'longitude': null,
  'roster_count': 0,
};

http.Response _json(http.Request r, Object body) => http.Response(
  jsonEncode(body),
  200,
  headers: {'content-type': 'application/json'},
  request: r,
);

void main() {
  late List<http.Request> seen;

  SupabaseGamesDataSource build({
    List<Map<String, dynamic>> cards = const [],
    List<Map<String, dynamic>> hosted = const [],
    List<Map<String, dynamic>> roster = const [],
  }) {
    seen = [];
    return SupabaseGamesDataSource(
      buildTestSupabaseClient((r) async {
        seen.add(r);
        switch (r.url.path) {
          case '/rest/v1/v_game_card':
            return _json(r, cards);
          case '/rest/v1/v_my_games':
            return _json(r, hosted);
          case '/rest/v1/game_roster':
            return _json(r, roster);
        }
        return _json(r, <dynamic>[]);
      }),
    );
  }

  Iterable<http.Request> gamesTableReads() =>
      seen.where((r) => r.url.path == '/rest/v1/games');

  Iterable<http.Request> at(String path) =>
      seen.where((r) => r.url.path == path);

  test('constructing the datasource opens no read of public.games', () async {
    build();
    await Future<void>.delayed(Duration.zero);
    expect(gamesTableReads(), isEmpty);
    expect(seen, isEmpty);
  });

  group('getGames (Explore games tab)', () {
    test(
      'reads v_game_card with the filters, order and page server-side',
      () async {
        final ds = build(cards: [_nullCard(_gameA)]);
        await ds.getGames(
          filters: {
            'is_public': true,
            'status': 'upcoming',
            'start_date': '2026-11-01T00:00:00Z',
            'end_date': '2026-12-01T00:00:00Z',
            'sport': 'padel',
          },
          page: 2,
          limit: 100,
        );
        expect(gamesTableReads(), isEmpty);
        final r = at('/rest/v1/v_game_card').single;
        final q = r.url.queryParametersAll;
        expect(q['listing_visibility'], ['eq.public']);
        expect(q['is_cancelled'], ['eq.false']);
        expect(q['sport_key'], ['eq.padel']);
        expect(q['start_at'], [
          'gte.2026-11-01T00:00:00Z',
          'lte.2026-12-01T00:00:00Z',
        ]);
        expect(q['order']!.single, startsWith('start_at.asc'));
        expect(q['offset'], ['100']);
        expect(q['limit'], ['100']);
      },
    );

    test('a null-heavy card parses with no invented values', () async {
      final ds = build(cards: [_nullCard(_gameA)]);
      final games = await ds.getGames(
        filters: {'is_public': true, 'status': 'upcoming'},
        limit: 100,
      );
      final g = games.single;
      expect(g.id, _gameA);
      expect(g.title, '');
      expect(g.storedTitle, isNull);
      expect(g.sport, '');
      expect(g.storedSport, isNull);
      expect(g.endTime, '');
      expect(g.storedEndAt, isNull);
      expect(g.maxPlayers, 0);
      expect(g.venueId, isNull);
      expect(g.organizerId, '');
      expect(g.scheduledDate, DateTime.utc(2099, 11, 10, 18));
      expect(g.createdAt, DateTime.utc(2026, 11, 1, 9, 30));
      expect(g.updatedAt, DateTime.utc(2026, 11, 2, 10, 45));
    });

    test('sport_key from the card becomes the game sport', () async {
      final ds = build(
        cards: [
          _nullCard(_gameA)
            ..['sport_key'] = 'padel'
            ..['title'] = 'Friday padel'
            ..['capacity'] = 4,
        ],
      );
      final g = (await ds.getGames(filters: {'is_public': true})).single;
      expect(g.sport, 'padel');
      expect(g.storedSport, 'padel');
      expect(g.title, 'Friday padel');
      expect(g.maxPlayers, 4);
    });
  });

  group('getMyGames (Home upcoming, composer link sheet)', () {
    test('hosted ids come from v_my_games, rows from v_game_card, '
        'filters server-side', () async {
      final ds = build(
        hosted: [
          {'id': _gameA},
        ],
        roster: [
          {'game_id': _gameB},
        ],
        cards: [_nullCard(_gameA), _nullCard(_gameB)],
      );
      final games = await ds.getMyGames(
        'user-1',
        status: 'upcoming',
        sportId: 'sport-1',
        limit: 50,
      );
      expect(gamesTableReads(), isEmpty);

      final hosted = at('/rest/v1/v_my_games').single.url.queryParametersAll;
      expect(hosted['select'], ['id']);
      expect(hosted['creator_user_id'], ['eq.user-1']);

      final card = at('/rest/v1/v_game_card').single.url.queryParametersAll;
      final idFilter = card['id']!.single;
      expect(idFilter, startsWith('in.('));
      expect(idFilter, contains(_gameA));
      expect(idFilter, contains(_gameB));
      expect(card['sport_id'], ['eq.sport-1']);
      expect(card['is_cancelled'], ['eq.false']);
      expect(card['start_at']!.single, startsWith('gte.'));
      expect(card['order']!.single, startsWith('start_at.asc'));
      expect(card['offset'], ['0']);
      expect(card['limit'], ['50']);

      expect(games.map((g) => g.id).toSet(), {_gameA, _gameB});
      for (final g in games) {
        expect(g.title, '');
        expect(g.sport, '');
        expect(g.endTime, '');
        expect(g.maxPlayers, 0);
      }
    });

    test('no hosted and no joined game reads nothing more', () async {
      final ds = build();
      final games = await ds.getMyGames('user-1', status: 'upcoming');
      expect(games, isEmpty);
      expect(gamesTableReads(), isEmpty);
      expect(at('/rest/v1/v_game_card'), isEmpty);
    });
  });
}
