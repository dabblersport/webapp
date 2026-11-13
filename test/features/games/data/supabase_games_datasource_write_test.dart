// KAN-736: createGame / updateGame go through rpc_create_game / rpc_update_game
// and never issue a direct write (INSERT/PATCH) to the games table.
import 'dart:convert';

import 'package:dabbler/features/games/data/datasources/supabase_games_datasource.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import '../../../helpers/supabase_test_client.dart';

// Null title / end / sport: the row must still parse and keep its ids.
Map<String, dynamic> _row(String id) => {
  'id': id,
  'title': null,
  'description': null,
  'sport_id': null,
  'sport': null,
  'game_date': '2026-11-05',
  'start_time': '18:00:00',
  'end_time': null,
  'end_at': null,
  'creator_user_id': 'creator-1',
  'host_user_id': 'creator-1',
  'status': 'upcoming',
  'created_at': '2026-11-01T10:00:00Z',
  'updated_at': '2026-11-01T10:00:00Z',
};

http.Response _json(http.Request r, Object body) => http.Response(
  jsonEncode(body),
  200,
  headers: {'content-type': 'application/json'},
  request: r,
);

void main() {
  late List<http.Request> seen;
  late SupabaseGamesDataSource ds;

  SupabaseGamesDataSource build(String gameId) {
    seen = [];
    return SupabaseGamesDataSource(
      buildTestSupabaseClient((r) async {
        seen.add(r);
        final path = r.url.path;
        if (path.startsWith('/rest/v1/rpc/')) return _json(r, gameId);
        if (path == '/rest/v1/kan718_games_compat') return _json(r, [_row(gameId)]);
        return _json(r, <dynamic>[]);
      }),
    );
  }

  Iterable<http.Request> writes() => seen.where(
    (r) =>
        r.url.path.startsWith('/rest/v1/') &&
        !r.url.path.startsWith('/rest/v1/rpc/') &&
        r.method != 'GET' &&
        r.method != 'HEAD',
  );

  test('createGame calls rpc_create_game, no direct write, ids kept', () async {
    ds = build('game-1');
    final game = await ds.createGame({
      'p_actor_type': 'player',
      'p_sport_id': 'sport-1',
      'host_user_id': 'legacy-host',
      'status': 'upcoming',
    });
    final rpc = seen.firstWhere(
      (r) => r.url.path == '/rest/v1/rpc/rpc_create_game',
    );
    final body = jsonDecode(rpc.body) as Map<String, dynamic>;
    expect(body, {'p_actor_type': 'player', 'p_sport_id': 'sport-1'});
    expect(writes(), isEmpty);
    expect(game.id, 'game-1');
  });

  test('updateGame calls rpc_update_game with p_game_id, no PATCH', () async {
    ds = build('game-2');
    final game = await ds.updateGame('game-2', {
      'p_title': 'New',
      'title': 'legacy',
    });
    final rpc = seen.firstWhere(
      (r) => r.url.path == '/rest/v1/rpc/rpc_update_game',
    );
    expect(jsonDecode(rpc.body), {'p_title': 'New', 'p_game_id': 'game-2'});
    expect(seen.where((r) => r.method == 'PATCH'), isEmpty);
    expect(writes(), isEmpty);
    expect(game.id, 'game-2');
  });
}
