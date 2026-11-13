// KAN-863 (KAN-708 F10a): every games read in SupabaseGamesDataSource goes
// through the events-backed projection public.kan718_games_compat
// (supabase/migrations/20261104110200_kan718_d05_old_client_compat_projection.sql)
// and never through the legacy public.games table. The projection has the
// same column names as games, so the mapped GameModel / PlayerModel values are
// unchanged. KAN-715 (merged KAN-861): getGames and getMyGames read the
// event-backed card projections v_game_card / v_my_games instead, and no
// realtime stream of games is opened.
import 'dart:convert';

import 'package:dabbler/features/games/data/datasources/supabase_games_datasource.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import '../../../../helpers/supabase_test_client.dart';

const _view = '/rest/v1/kan718_games_compat';
const _legacy = '/rest/v1/games';
const _card = '/rest/v1/v_game_card';
const _myGames = '/rest/v1/v_my_games';

// A projection row, column names exactly as kan718_games_compat exposes them.
Map<String, dynamic> _row(String id) => {
  'id': id,
  'game_type': 'pickup',
  'title': 'Friday Five-a-side',
  'creator_profile_id': 'prof-1',
  'creator_user_id': 'user-1',
  'venue_space_id': 'space-1',
  'start_at': '2099-11-05T18:00:00.000Z',
  'end_at': '2099-11-05T19:30:00.000Z',
  'capacity': 10,
  'listing_visibility': 'public',
  'join_policy': 'open',
  'allow_spectators': true,
  'min_skill': 1,
  'max_skill': 3,
  'rules': null,
  'is_cancelled': false,
  'cancelled_at': null,
  'cancelled_reason': null,
  'created_at': '2026-11-01T10:00:00.000Z',
  'updated_at': '2026-11-01T10:00:00.000Z',
  'squad_id': null,
  'sport_specific_data': null,
  'allows_waitlist': true,
  'sport_id': 'sport-1',
  'geo_location_id': null,
  'area_id': null,
  'venue_id': 'venue-1',
  'sport_variant_id': null,
  'bench_slots': 0,
  'joining_rule': null,
  'cost_cover': null,
  'price_aed': null,
  'request_id': null,
  'series_id': null,
  'event_id': id,
};

// KAN-715 fix 1: a v_game_card row, column names and order exactly as the
// view exposes them after 20261105140000_kan715_v_game_card_my_games_event_id
// (b01 projection + event_id appended last). id is games.id; event_id is the
// parent public.events.id and is deliberately a DIFFERENT value, so a model
// that confused the two identities cannot pass.
const _gameId = 'game-1';
const _eventId = 'event-1';

Map<String, dynamic> _cardRow(String id) => {
  'id': id,
  'title': 'Friday Five-a-side',
  'game_type': 'pickup',
  'start_at': '2099-11-05T18:00:00.000Z',
  'end_at': '2099-11-05T19:30:00.000Z',
  'capacity': 10,
  'bench_slots': 0,
  'total_slots': 10,
  'min_skill': 1,
  'max_skill': 3,
  'listing_visibility': 'public',
  'join_policy': 'open',
  'allow_spectators': true,
  'allows_waitlist': true,
  'is_cancelled': false,
  'rules': null,
  'created_at': '2026-11-01T10:00:00.000Z',
  'updated_at': '2026-11-01T10:00:00.000Z',
  'sport_id': 'sport-1',
  'sport_key': 'football',
  'sport_name_en': 'Football',
  'sport_name_ar': null,
  'sport_variant_id': null,
  'variant_key': null,
  'variant_name_en': null,
  'variant_name_ar': null,
  'required_players': null,
  'players_per_side': null,
  'creator_profile_id': 'prof-1',
  'creator_username': 'host',
  'creator_display_name': 'Host',
  'creator_avatar_url': null,
  'geo_location_id': null,
  'area_id': null,
  'area_name': null,
  'venue_space_id': 'space-1',
  'venue_id': 'venue-1',
  'venue_space_name': null,
  'venue_name': null,
  'joining_rule': null,
  'cost_cover': null,
  'roster_count': 0,
  'is_creator': true,
  'is_joined': false,
  'host_verified': false,
  'liked_by_me': false,
  'latitude': null,
  'longitude': null,
  'favorite_count': 0,
  'favourited_by_me': false,
  'price_aed': null,
  'series_id': null,
  'series_frequency': null,
  'series_ends_on': null,
  'event_id': _eventId,
};

// A v_my_games row, column names and order exactly as the view exposes them
// after the same migration (event_id appended last).
Map<String, dynamic> _myGamesRow(String id) => {
  'id': id,
  'title': 'Friday Five-a-side',
  'game_type': 'pickup',
  'start_at': '2099-11-05T18:00:00.000Z',
  'end_at': '2099-11-05T19:30:00.000Z',
  'capacity': 10,
  'is_cancelled': false,
  'listing_visibility': 'public',
  'join_policy': 'open',
  'created_at': '2026-11-01T10:00:00.000Z',
  'sport_id': 'sport-1',
  'sport_key': 'football',
  'sport_name_en': 'Football',
  'sport_name_ar': null,
  'creator_profile_id': 'prof-1',
  'creator_user_id': 'user-1',
  'area_id': null,
  'area_name': null,
  'venue_id': 'venue-1',
  'venue_name': null,
  'my_roster_status': null,
  'event_id': _eventId,
};

bool _wantsObject(http.Request r) =>
    (r.headers['Accept'] ?? r.headers['accept'] ?? '').contains(
      'vnd.pgrst.object',
    );

http.Response _json(http.Request r, Object body) => http.Response(
  jsonEncode(body),
  200,
  headers: {'content-type': 'application/json'},
  request: r,
);

void main() {
  late List<http.Request> seen;
  late SupabaseGamesDataSource ds;

  SupabaseGamesDataSource build({
    List<Map<String, dynamic>> roster = const [],
  }) {
    seen = [];
    return SupabaseGamesDataSource(
      buildTestSupabaseClient((r) async {
        seen.add(r);
        final path = r.url.path;
        if (path.startsWith('/rest/v1/rpc/')) return _json(r, 'game-1');
        if (path == _view) {
          final rows = [_row('game-1')];
          return _json(r, _wantsObject(r) ? rows.first : rows);
        }
        if (path == _card) {
          final rows = [_cardRow(_gameId)];
          return _json(r, _wantsObject(r) ? rows.first : rows);
        }
        if (path == _myGames) {
          final select = r.url.queryParameters['select'];
          final row = _myGamesRow(_gameId);
          // PostgREST returns only the selected columns.
          final rows = [
            if (select == null || select == '*')
              row
            else
              {for (final c in select.split(',')) c: row[c]},
          ];
          return _json(r, _wantsObject(r) ? rows.first : rows);
        }
        if (path == '/rest/v1/game_roster') {
          if (_wantsObject(r)) {
            return roster.isEmpty
                ? http.Response('', 200, request: r)
                : _json(r, roster.first);
          }
          return _json(r, roster);
        }
        return _json(r, <dynamic>[]);
      }),
    );
  }

  List<http.Request> readsOf(String path) =>
      seen.where((r) => r.url.path == path && r.method == 'GET').toList();
  List<http.Request> viewReads() => readsOf(_view);
  bool touchedLegacy() => seen.any((r) => r.url.path == _legacy);

  void expectModel(dynamic g) {
    expect(g.id, 'game-1');
    expect(g.title, 'Friday Five-a-side');
    expect(g.maxPlayers, 10);
    expect(g.organizerId, 'prof-1');
    expect(g.venueId, 'venue-1');
    expect(g.isPublic, isTrue);
    expect(g.allowsWaitlist, isTrue);
    expect(g.scheduledDate, DateTime.utc(2099, 11, 5, 18).toLocal()); // KAN-927
  }

  void expectBothIds(dynamic g) {
    expect(g.id, _gameId, reason: 'id must stay games.id');
    expect(g.eventId, isNotNull, reason: 'parent event_id must survive');
    expect(g.eventId, _eventId);
    expect(g.eventId, isNot(g.id));
  }

  test('getGames reads v_game_card with filters, model unchanged', () async {
    ds = build();
    final games = await ds.getGames(
      filters: {'status': 'upcoming', 'is_public': true},
    );
    expect(viewReads(), isEmpty);
    final q = readsOf(_card).single.url.queryParameters;
    expect(q['is_cancelled'], 'eq.false');
    expect(q['listing_visibility'], 'eq.public');
    expect(q['order'], startsWith('start_at'));
    expect(touchedLegacy(), isFalse);
    expectModel(games.single);
  });

  test('getGames carries games.id as id and the parent event_id', () async {
    ds = build();
    final games = await ds.getGames();
    expect(readsOf(_card), hasLength(1));
    expectBothIds(games.single);
  });

  test('getGame reads the projection by id and adds current_players', () async {
    ds = build(
      roster: [
        {'profile_id': 'p1'},
        {'profile_id': 'p2'},
      ],
    );
    final g = await ds.getGame('game-1');
    expect(viewReads().single.url.queryParameters['id'], 'eq.game-1');
    expect(touchedLegacy(), isFalse);
    expectModel(g);
    expect(g.currentPlayers, 2);
  });

  test('createGame and updateGame re-read through the projection', () async {
    ds = build();
    expectModel(await ds.createGame({'p_sport_id': 'sport-1'}));
    expectModel(await ds.updateGame('game-1', {'p_title': 'X'}));
    expect(viewReads(), hasLength(2));
    expect(touchedLegacy(), isFalse);
  });

  test(
    'getMyGames reads hosted ids from v_my_games and the games from v_game_card',
    () async {
      ds = build();
      final games = await ds.getMyGames('user-1');
      expect(viewReads(), isEmpty);
      expect(
        readsOf(_myGames).single.url.queryParameters['creator_user_id'],
        'eq.user-1',
      );
      expect(readsOf(_card).single.url.queryParameters['id'], 'in.("game-1")');
      expect(touchedLegacy(), isFalse);
      expectModel(games.single);
    },
  );

  test('getMyGames carries games.id as id and the parent event_id', () async {
    ds = build();
    final games = await ds.getMyGames('user-1');
    expect(readsOf(_myGames), hasLength(1));
    expect(readsOf(_card), hasLength(1));
    expectBothIds(games.single);
  });

  test('searchGames, getGamesBySport read the projection', () async {
    ds = build();
    expectModel((await ds.searchGames('five')).single);
    expectModel((await ds.getGamesBySport('football')).single);
    final reads = viewReads();
    expect(reads, hasLength(2));
    expect(reads[0].url.queryParameters['title'], 'fts.five');
    expect(reads[1].url.queryParameters['sport'], 'eq.football');
    expect(touchedLegacy(), isFalse);
  });

  test(
    'getFavoriteGames / getGameHistory keep their embeds on the projection',
    () async {
      ds = build();
      expectModel((await ds.getFavoriteGames('user-1')).single);
      expectModel((await ds.getGameHistory('user-1')).single);
      final reads = viewReads();
      expect(reads, hasLength(2));
      expect(
        reads[0].url.queryParameters['select'],
        contains('game_favorites!inner(user_id)'),
      );
      expect(
        reads[0].url.queryParameters['game_favorites.user_id'],
        'eq.user-1',
      );
      expect(
        reads[1].url.queryParameters['select'],
        contains('game_roster!inner(user_id)'),
      );
      expect(touchedLegacy(), isFalse);
    },
  );

  test('capacity reads (players, waitlist) come from the projection', () async {
    ds = build();
    expect(await ds.getGamePlayers('game-1'), isEmpty);
    expect(await ds.getWaitlistPosition('game-1', 'user-1'), isNull);
    final reads = viewReads();
    expect(reads, hasLength(2));
    for (final r in reads) {
      expect(r.url.queryParameters['select'], 'capacity');
      expect(r.url.queryParameters['id'], 'eq.game-1');
    }
    expect(touchedLegacy(), isFalse);
  });

  test('joinGame reads the game row from the projection', () async {
    ds = build();
    try {
      await ds.joinGame('game-1', 'user-1');
    } catch (_) {
      // The join outcome is not under test; only which object was read.
    }
    expect(viewReads().first.url.queryParameters['id'], 'eq.game-1');
    expect(touchedLegacy(), isFalse);
  });
}
