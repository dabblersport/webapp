import 'dart:convert';

import 'package:dabbler/core/services/analytics/analytics_service.dart';
import 'package:dabbler/features/games/presentation/controllers/game_view_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// KAN-765: drives the real [GameViewController.joinGame] and proves which
/// rpc_join_game results emit `game_joined`. Only the HTTP layer is faked.
void main() {
  late List<String> events;
  late List<http.Request> rpcCalls;

  // Answers rpc_join_game with [joinRows]; every load query gets an empty list.
  GameViewController build(Object joinRows) {
    final client = SupabaseClient(
      'http://localhost',
      'anon-key',
      httpClient: MockClient((request) async {
        final isJoin = request.url.path.endsWith('/rpc/rpc_join_game');
        if (isJoin) rpcCalls.add(request);
        final body = isJoin ? joinRows : <Object>[];
        return http.Response(
          jsonEncode(body),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    return GameViewController(
      supabase: client,
      gameId: 'game-1',
      currentUserId: 'user-1',
    );
  }

  setUp(() {
    events = [];
    rpcCalls = [];
    AnalyticsService.sinkOverride = (name, props) async {
      events.add(name);
    };
  });

  tearDown(AnalyticsService.resetForTest);

  Future<GameViewController> join(Object joinRows) async {
    final controller = build(joinRows);
    // Let the constructor's _load settle so it cannot race the join.
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await controller.joinGame();
    await Future<void>.delayed(Duration.zero);
    addTearDown(controller.dispose);
    return controller;
  }

  test('result joined sends exactly one game_joined', () async {
    final controller = await join([
      {'result': 'joined'},
    ]);

    expect(rpcCalls, hasLength(1));
    expect(events.where((e) => e == 'game_joined'), hasLength(1));
    expect(controller.state.lastAction, JoinActionResult.joined);
  });

  test('result waitlisted sends no game_joined', () async {
    final controller = await join([
      {'result': 'waitlisted'},
    ]);

    expect(rpcCalls, hasLength(1));
    expect(events.where((e) => e == 'game_joined'), isEmpty);
    expect(controller.state.lastAction, JoinActionResult.waitlisted);
  });

  test('result request_submitted sends no game_joined', () async {
    final controller = await join([
      {'result': 'request_submitted'},
    ]);

    expect(rpcCalls, hasLength(1));
    expect(events.where((e) => e == 'game_joined'), isEmpty);
    expect(controller.state.lastAction, JoinActionResult.requestSubmitted);
  });

  test('empty rows send no game_joined and set an error', () async {
    final controller = await join(<Object>[]);

    expect(rpcCalls, hasLength(1));
    expect(events.where((e) => e == 'game_joined'), isEmpty);
    expect(controller.state.error, isNotNull);
    expect(controller.state.lastAction, isNull);
  });
}
