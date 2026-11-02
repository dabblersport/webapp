// KAN-737: cancelGame / updateGameStatus go through rpc_cancel_game and never
// issue a direct write to the games table.
import 'dart:convert';

import 'package:dabbler/features/games/data/datasources/games_remote_data_source.dart';
import 'package:dabbler/features/games/data/datasources/supabase_games_datasource.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import '../../../helpers/supabase_test_client.dart';

http.Response _json(http.Request r, Object body, {int status = 200}) =>
    http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json'},
      request: r,
    );

void main() {
  late List<http.Request> seen;

  SupabaseGamesDataSource build({bool fail = false}) {
    seen = [];
    return SupabaseGamesDataSource(
      buildTestSupabaseClient((r) async {
        seen.add(r);
        if (r.url.path.startsWith('/rest/v1/rpc/')) {
          if (fail) {
            return _json(r, {
              'code': 'P0001',
              'message': 'not_host_or_not_found',
            }, status: 400);
          }
          return _json(r, 'cancelled');
        }
        return _json(r, <dynamic>[]);
      }),
    );
  }

  Iterable<http.Request> tableWrites() => seen.where(
    (r) =>
        r.url.path.startsWith('/rest/v1/') &&
        !r.url.path.startsWith('/rest/v1/rpc/') &&
        r.method != 'GET' &&
        r.method != 'HEAD',
  );

  Iterable<http.Request> rpcCancels() =>
      seen.where((r) => r.url.path == '/rest/v1/rpc/rpc_cancel_game');

  test('cancelGame calls rpc_cancel_game with p_game_id only', () async {
    final ds = build();
    expect(await ds.cancelGame('game-1'), isTrue);
    expect(jsonDecode(rpcCancels().single.body), {'p_game_id': 'game-1'});
    // No client-invented cancel date, no direct write.
    expect(tableWrites(), isEmpty);
  });

  test('cancelGame surfaces an RPC refusal as GameServerException', () async {
    final ds = build(fail: true);
    await expectLater(
      ds.cancelGame('game-1'),
      throwsA(isA<GameServerException>()),
    );
    expect(tableWrites(), isEmpty);
  });

  test('updateGameStatus(cancelled) uses rpc_cancel_game', () async {
    final ds = build();
    expect(await ds.updateGameStatus('game-2', 'cancelled'), isTrue);
    expect(jsonDecode(rpcCancels().single.body), {'p_game_id': 'game-2'});
    expect(tableWrites(), isEmpty);
  });

  test('updateGameStatus(other) writes nothing and returns false', () async {
    final ds = build();
    expect(await ds.updateGameStatus('game-3', 'completed'), isFalse);
    expect(rpcCancels(), isEmpty);
    expect(tableWrites(), isEmpty);
  });
}
