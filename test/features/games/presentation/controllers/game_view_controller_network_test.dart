import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:dabbler/core/config/supabase_config.dart';
import 'package:dabbler/features/games/presentation/controllers/game_view_controller.dart';

import '../../../../helpers/supabase_test_client.dart';

/// Covers the actual join/leave/roster network path — the "reads
/// v_game_card, calls rpc_join_game / rpc_leave_game" flow KAN-34 called
/// out as the highest-value target. Uses the MockClient(httpClient)
/// technique (see test/helpers/supabase_test_client.dart) so the real
/// PostgREST/RPC request building and response decoding runs for real.
///
/// The controller opens a realtime channel subscription in its constructor
/// as a side effect; against a MockClient there's no websocket server, but
/// that channel attempt fails quietly on its own and does not block or
/// throw into these tests (verified experimentally — the subscribe call
/// only logs, and `.channel()` itself performs no I/O). Analytics side
/// calls (`AnalyticsService`, only fired on a successful *join*) read the
/// global `Supabase.instance` singleton rather than the injected test
/// client, so the joined-with-analytics branch isn't covered here — the
/// waitlisted/request_submitted/error join branches are, and none of them
/// touch analytics.
void main() {
  Map<String, dynamic> gameRow() => {
        'id': 'g1',
        'title': 'Sunday Kickabout',
        'start_at': '2026-08-30T10:00:00Z',
        'end_at': '2026-08-30T11:00:00Z',
        'capacity': 10,
        'roster_count': 8,
      };

  /// Builds a controller against a router-style MockClient and waits for
  /// the constructor's initial `_load()` to settle.
  Future<GameViewController> buildAndSettle(
    Future<http.Response> Function(http.Request request) router, {
    String userId = 'u1',
  }) async {
    final client = buildTestSupabaseClient(router);
    await client.auth.setInitialSession(fakeSessionJson(userId: userId));
    final controller = GameViewController(
      supabase: client,
      gameId: 'g1',
      currentUserId: userId,
    );
    await pumpEventQueue();
    return controller;
  }

  /// A router that answers the four `_load()` reads with sane defaults and
  /// delegates everything else (RPCs, patches) to [extra].
  Future<http.Response> Function(http.Request) loadRouter({
    Future<http.Response> Function(http.Request)? extra,
    List<Map<String, dynamic>> roster = const [],
    List<Map<String, dynamic>> waitlist = const [],
    List<Map<String, dynamic>> pendingRequests = const [],
  }) {
    return (request) async {
      final path = request.url.path;
      if (request.method == 'GET' && path.contains(SupabaseConfig.vGameCardTable)) {
        return jsonObjectResponse(gameRow(), request: request);
      }
      if (request.method == 'GET' && path.contains(SupabaseConfig.gameRosterTable)) {
        return jsonListResponse(roster, request: request);
      }
      if (request.method == 'GET' && path.contains(SupabaseConfig.gameWaitlistTable)) {
        return jsonListResponse(waitlist, request: request);
      }
      if (request.method == 'GET' && path.contains(SupabaseConfig.gameJoinRequestsTable)) {
        return jsonListResponse(pendingRequests, request: request);
      }
      if (extra != null) return extra(request);
      return jsonListResponse(const [], request: request);
    };
  }

  group('_load (initial fetch)', () {
    test('populates game, roster, waitlist and pendingRequests', () async {
      final controller = await buildAndSettle(
        loadRouter(
          roster: [
            {
              'profile_id': 'p1',
              'user_id': 'u1',
              'role': 'host',
              'profiles': {'display_name': 'Me'},
            },
          ],
          waitlist: [
            {
              'profile_id': 'p2',
              'user_id': 'u2',
              'position': 1,
              'profiles': {'display_name': 'Waiter'},
            },
          ],
        ),
      );

      expect(controller.state.game?.id, 'g1');
      expect(controller.state.roster, hasLength(1));
      expect(controller.state.waitlist, hasLength(1));
      expect(controller.state.isLoading, isFalse);
      expect(controller.state.error, isNull);
      expect(controller.isHost, isTrue);
      controller.dispose();
    });

    test('a failed game fetch sets a scoped error without throwing', () async {
      final controller = await buildAndSettle((request) async {
        if (request.method == 'GET' &&
            request.url.path.contains(SupabaseConfig.vGameCardTable)) {
          return postgrestErrorResponse(
            message: 'not found',
            status: 404,
            request: request,
          );
        }
        return jsonListResponse(const [], request: request);
      });

      expect(controller.state.game, isNull);
      expect(controller.state.error, 'Failed to load game');
      controller.dispose();
    });
  });

  group('joinGame', () {
    test('waitlisted result updates lastAction without touching analytics', () async {
      final controller = await buildAndSettle(
        loadRouter(
          extra: (request) async {
            if (request.method == 'POST' &&
                request.url.path.contains('/rpc/${SupabaseConfig.rpcJoinGameFn}')) {
              return jsonListResponse([
                {'result': 'waitlisted'},
              ], request: request);
            }
            return jsonListResponse(const [], request: request);
          },
        ),
      );

      await controller.joinGame();

      expect(controller.state.lastAction, JoinActionResult.waitlisted);
      expect(controller.state.error, isNull);
      expect(controller.state.isActing, isFalse);
      controller.dispose();
    });

    test('request_submitted result updates lastAction', () async {
      final controller = await buildAndSettle(
        loadRouter(
          extra: (request) async {
            if (request.method == 'POST' &&
                request.url.path.contains('/rpc/${SupabaseConfig.rpcJoinGameFn}')) {
              return jsonListResponse([
                {'result': 'request_submitted'},
              ], request: request);
            }
            return jsonListResponse(const [], request: request);
          },
        ),
      );

      await controller.joinGame();

      expect(controller.state.lastAction, JoinActionResult.requestSubmitted);
      controller.dispose();
    });

    test('a not_host RPC error is translated to a friendly message', () async {
      final controller = await buildAndSettle(
        loadRouter(
          extra: (request) async {
            if (request.method == 'POST' &&
                request.url.path.contains('/rpc/${SupabaseConfig.rpcJoinGameFn}')) {
              return postgrestErrorResponse(
                message: 'P0001: not_host',
                status: 400,
                request: request,
              );
            }
            return jsonListResponse(const [], request: request);
          },
        ),
      );

      await controller.joinGame();

      expect(controller.state.error, 'Only the game creator can do that.');
      expect(controller.state.isActing, isFalse);
      controller.dispose();
    });
  });

  group('leaveGame', () {
    test('calls rpc_leave_game and marks lastAction as left', () async {
      late Uri capturedUri;
      final controller = await buildAndSettle(
        loadRouter(
          extra: (request) async {
            if (request.method == 'POST' &&
                request.url.path.contains('/rpc/${SupabaseConfig.rpcLeaveGameFn}')) {
              capturedUri = request.url;
              return emptyOkResponse(request: request);
            }
            return jsonListResponse(const [], request: request);
          },
        ),
      );

      await controller.leaveGame();

      expect(controller.state.lastAction, JoinActionResult.left);
      expect(capturedUri.path, contains('/rpc/${SupabaseConfig.rpcLeaveGameFn}'));
      controller.dispose();
    });

    test('a player_not_on_roster error is translated to a friendly message', () async {
      final controller = await buildAndSettle(
        loadRouter(
          extra: (request) async {
            if (request.method == 'POST' &&
                request.url.path.contains('/rpc/${SupabaseConfig.rpcLeaveGameFn}')) {
              return postgrestErrorResponse(
                message: 'P0001: player_not_on_roster',
                status: 400,
                request: request,
              );
            }
            return jsonListResponse(const [], request: request);
          },
        ),
      );

      await controller.leaveGame();

      expect(controller.state.error, 'This player is no longer on the roster.');
      controller.dispose();
    });
  });

  group('cancelJoinRequest', () {
    test('PATCHes the pending request row to cancelled', () async {
      late http.Request captured;
      final controller = await buildAndSettle(
        loadRouter(
          extra: (request) async {
            if (request.method == 'PATCH' &&
                request.url.path.contains(SupabaseConfig.gameJoinRequestsTable)) {
              captured = request;
              return emptyOkResponse(request: request);
            }
            return jsonListResponse(const [], request: request);
          },
        ),
      );

      await controller.cancelJoinRequest();

      expect(controller.state.lastAction, JoinActionResult.cancelledRequest);
      expect(captured.body, contains('"status":"cancelled"'));
      expect(captured.url.queryParameters['status'], 'eq.pending');
      controller.dispose();
    });
  });

  group('decideJoinRequest', () {
    test('approve=true sends p_approve true to the decide RPC', () async {
      late Map<String, dynamic> body;
      final controller = await buildAndSettle(
        loadRouter(
          extra: (request) async {
            if (request.method == 'POST' &&
                request.url.path.contains('/rpc/${SupabaseConfig.rpcDecideJoinRequestFn}')) {
              body = _decodeJsonBody(request.body);
              return emptyOkResponse(request: request);
            }
            return jsonListResponse(const [], request: request);
          },
        ),
      );

      await controller.decideJoinRequest('req-1', true);

      expect(body['p_request_id'], 'req-1');
      expect(body['p_approve'], isTrue);
      expect(controller.state.isActing, isFalse);
      controller.dispose();
    });
  });

  group('removePlayer', () {
    test('a cannot_remove_host error is translated to a friendly message', () async {
      final controller = await buildAndSettle(
        loadRouter(
          extra: (request) async {
            if (request.method == 'POST' &&
                request.url.path.contains('/rpc/${SupabaseConfig.rpcRemovePlayerFn}')) {
              return postgrestErrorResponse(
                message: 'P0001: cannot_remove_host',
                status: 400,
                request: request,
              );
            }
            return jsonListResponse(const [], request: request);
          },
        ),
      );

      await controller.removePlayer('p1');

      expect(controller.state.error, 'The creator cannot be removed.');
      controller.dispose();
    });
  });
}

Map<String, dynamic> _decodeJsonBody(String body) {
  return jsonDecode(body) as Map<String, dynamic>;
}
