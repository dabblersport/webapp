// KAN-930: a join request goes through rpc_join_game, never a direct insert
// into game_join_requests (games has RLS with no client SELECT policy, so the
// table guard refuses a client insert with game_not_found). The RPC's refusal
// codes map to the existing exceptions and to EN/AR copy.
import 'dart:convert';

import 'package:dabbler/core/config/supabase_config.dart';
import 'package:dabbler/features/games/data/datasources/games_remote_data_source.dart';
import 'package:dabbler/features/games/data/datasources/supabase_games_datasource.dart';
import 'package:dabbler/features/games/presentation/controllers/join_action_toast.dart';
import 'package:dabbler/features/games/presentation/controllers/game_view_controller.dart'
    show JoinActionResult;
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import '../../../helpers/supabase_test_client.dart';

http.Response _json(http.Request r, Object body, [int status = 200]) =>
    http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json'},
      request: r,
    );

void main() {
  late List<http.Request> seen;

  SupabaseGamesDataSource build(http.Response Function(http.Request r) onJoin) {
    seen = [];
    return SupabaseGamesDataSource(
      buildTestSupabaseClient((r) async {
        seen.add(r);
        if (r.url.path == '/rest/v1/rpc/${SupabaseConfig.rpcJoinGameFn}') {
          return onJoin(r);
        }
        return _json(r, <dynamic>[]);
      }),
    );
  }

  Iterable<http.Request> tableWrites() => seen.where(
    (r) =>
        !r.url.path.startsWith('/rest/v1/rpc/') &&
        r.method != 'GET' &&
        r.method != 'HEAD',
  );

  test('requestToJoinGame calls rpc_join_game with the right args', () async {
    final ds = build(
      (r) => _json(r, [
        {
          'result': 'request_submitted',
          'roster_status': null,
          'waitlist_position': null,
        },
      ]),
    );
    final result = await ds.requestToJoinGame('game-1', 'user-1');
    expect(result, 'request_submitted');
    final rpc = seen.singleWhere(
      (r) => r.url.path == '/rest/v1/rpc/rpc_join_game',
    );
    expect(rpc.method, 'POST');
    expect(jsonDecode(rpc.body), {
      'p_actor_type': 'player',
      'p_game_id': 'game-1',
    });
    expect(tableWrites(), isEmpty);
    expect(
      seen.where(
        (r) => r.url.path.endsWith(SupabaseConfig.gameJoinRequestsTable),
      ),
      isEmpty,
    );
  });

  test('a pending request (cta requested) is the same outcome', () async {
    final ds = build(
      (r) => _json(r, {'code': 'P0001', 'message': 'requested'}, 400),
    );
    expect(await ds.requestToJoinGame('game-1', 'user-1'), 'request_submitted');
    expect(tableWrites(), isEmpty);
  });

  test('refusals map to the existing exceptions', () async {
    final started = build(
      (r) => _json(r, {'code': 'P0001', 'message': 'started'}, 400),
    );
    await expectLater(
      started.requestToJoinGame('game-1', 'user-1'),
      throwsA(isA<GameAlreadyStartedException>()),
    );
    final closed = build(
      (r) => _json(r, {'code': 'P0001', 'message': 'closed'}, 400),
    );
    await expectLater(
      closed.requestToJoinGame('game-1', 'user-1'),
      throwsA(
        isA<GameServerException>().having((e) => e.message, 'code', 'closed'),
      ),
    );
    expect(tableWrites(), isEmpty);
  });

  group('EN/AR copy', () {
    for (final code in const ['en', 'ar']) {
      final l = lookupAppLocalizations(Locale(code));
      test('$code: refusal codes and outcomes', () {
        expect(joinRefusalMessage(l, 'closed'), l.game_join_err_closed);
        expect(joinRefusalMessage(l, 'started'), l.game_join_err_started);
        expect(joinRefusalMessage(l, 'link_invalid'), l.game_join_err_link);
        expect(joinRefusalMessage(l, 'link_required'), l.game_join_err_link);
        expect(joinRefusalMessage(l, 'requested'), l.game_join_err_requested);
        expect(joinRefusalMessage(l, 'not_allowed'), l.feedback_join_failed);
        expect(
          joinActionMessageL10n(l, JoinActionResult.requestSubmitted),
          l.game_join_request_sent,
        );
        expect(
          joinActionMessageL10n(l, JoinActionResult.waitlisted),
          l.game_join_waitlisted,
        );
      });
    }
    test('the Arabic copy is not the English copy', () {
      final en = lookupAppLocalizations(const Locale('en'));
      final ar = lookupAppLocalizations(const Locale('ar'));
      expect(ar.game_join_request_sent, isNot(en.game_join_request_sent));
      expect(ar.game_error_stale_update, isNot(en.game_error_stale_update));
    });
  });
}
