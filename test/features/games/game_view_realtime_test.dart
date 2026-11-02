import 'dart:async';
import 'dart:convert';

import 'package:dabbler/core/config/supabase_config.dart';
import 'package:dabbler/features/games/presentation/controllers/game_view_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// KAN-749: the game view listens to its events/games row as well as the
/// roster, waitlist and join requests — on one channel, debounced, and inert
/// after dispose. Realtime is replaced by a recorder; HTTP by a MockClient.

class _Opened {
  _Opened(this.name, this.listeners, this.value, this.onChange);
  final String name;
  final List<GameViewListener> listeners;
  final String value;
  final void Function() onChange;
}

class _FakeRealtime implements GameViewRealtime {
  final opened = <_Opened>[];
  final closed = <Object>[];
  final log = <String>[];

  Set<Object> get live => opened.toSet().difference(closed.toSet());

  @override
  Object open(
    String channelName,
    List<GameViewListener> listeners,
    String value,
    void Function() onChange,
  ) {
    final o = _Opened(channelName, listeners, value, onChange);
    opened.add(o);
    log.add('open');
    return o;
  }

  @override
  Future<void> close(Object channel) async {
    closed.add(channel);
    log.add('close');
  }
}

const _gameId = 'game-1';
const _debounce = Duration(milliseconds: 500); // > DabblerMotion.debounceSearch

void main() {
  late List<http.BaseRequest> requests;
  late _FakeRealtime realtime;
  Duration responseDelay = Duration.zero;

  int gameCardReads() => requests
      .where((r) => r.url.path.endsWith('/${SupabaseConfig.vGameCardTable}'))
      .length;

  GameViewController build() {
    final client = SupabaseClient(
      'http://localhost',
      'anon-key',
      httpClient: MockClient((request) async {
        requests.add(request);
        if (responseDelay > Duration.zero) {
          await Future<void>.delayed(responseDelay);
        }
        final isCard = request.url.path.endsWith(
          '/${SupabaseConfig.vGameCardTable}',
        );
        final body = isCard
            ? {'id': _gameId, 'start_at': '2026-11-03T18:00:00Z'}
            : <Object>[];
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
      gameId: _gameId,
      currentUserId: 'user-1',
      realtime: realtime,
    );
  }

  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 50));

  setUp(() {
    requests = [];
    realtime = _FakeRealtime();
    responseDelay = Duration.zero;
  });

  tearDown(() {
    // No write of any kind ever reaches events or games.
    final writes = requests.where((r) {
      final path = r.url.path;
      final shared =
          path.endsWith('/${SupabaseConfig.eventsTable}') ||
          path.endsWith('/${SupabaseConfig.gamesTable}');
      return shared && r.method != 'GET' && r.method != 'HEAD';
    });
    expect(writes, isEmpty, reason: 'controller wrote to events/games');
  });

  test('one game_view channel carries events + games beside the three '
      'existing listeners, each filtered by the game id', () async {
    final c = build();
    addTearDown(c.dispose);
    await settle();

    expect(realtime.opened, hasLength(1));
    final ch = realtime.opened.single;
    expect(ch.name, 'game_view_$_gameId');
    expect(ch.value, _gameId);
    expect(ch.listeners, [
      (table: SupabaseConfig.gameRosterTable, column: 'game_id'),
      (table: SupabaseConfig.gameWaitlistTable, column: 'game_id'),
      (table: SupabaseConfig.gameJoinRequestsTable, column: 'game_id'),
      (table: 'events', column: 'id'),
      (table: 'games', column: 'id'),
    ]);
  });

  test('a burst of change callbacks yields exactly one reload', () async {
    final c = build();
    addTearDown(c.dispose);
    await settle();
    final before = gameCardReads();
    expect(before, 1, reason: 'constructor load');

    final fire = realtime.opened.single.onChange;
    for (var i = 0; i < 5; i++) {
      fire();
    }
    await Future<void>.delayed(_debounce);
    await settle();

    expect(gameCardReads(), before + 1);
    expect(c.state.game?.id, _gameId);
  });

  test('resync removes the old channel, then opens exactly one new one '
      'and reloads', () async {
    final c = build();
    addTearDown(c.dispose);
    await settle();
    final first = realtime.opened.single;
    final before = gameCardReads();

    await c.resync();

    expect(realtime.log, ['open', 'close', 'open']);
    expect(realtime.closed, [first]);
    expect(realtime.opened, hasLength(2));
    expect(realtime.live, hasLength(1));
    expect(realtime.opened.last.name, 'game_view_$_gameId');
    expect(gameCardReads(), before + 1);
  });

  test('after dispose a change callback schedules nothing and writes no '
      'state', () async {
    final c = build();
    await settle();
    final fire = realtime.opened.single.onChange;
    final before = requests.length;

    c.dispose();
    expect(realtime.live, isEmpty, reason: 'dispose removes the channel');

    fire();
    await Future<void>.delayed(_debounce);
    await settle();

    expect(requests.length, before);
  });

  test('a pending debounce is cancelled by dispose (account switch)', () async {
    final c = build();
    await settle();
    final before = requests.length;

    realtime.opened.single.onChange();
    c.dispose();
    await Future<void>.delayed(_debounce);
    await settle();

    expect(requests.length, before);
  });

  test('a load still in flight at dispose completes without touching '
      'state', () async {
    responseDelay = const Duration(milliseconds: 100);
    final errors = <Object>[];
    await runZonedGuarded(() async {
      final c = build(); // constructor load is now in flight
      await Future<void>.delayed(const Duration(milliseconds: 10));
      c.dispose();
      await Future<void>.delayed(const Duration(milliseconds: 300));
    }, (e, _) => errors.add(e));
    expect(errors, isEmpty);
  });

  test('resync after dispose does not resubscribe', () async {
    final c = build();
    await settle();
    c.dispose();
    await c.resync();
    expect(realtime.opened, hasLength(1));
    expect(realtime.live, isEmpty);
  });

  test('a row with null title, end and sport parses and keeps its id', () {
    final view = GameView.fromJson({
      'id': _gameId,
      'event_id': _gameId,
      'title': null,
      'start_at': '2026-11-03T18:00:00Z',
      'end_at': null,
      'sport_id': null,
      'sport_key': null,
    });
    expect(view.id, _gameId);
    expect(view.title, 'Untitled Game');
    expect(view.endAt, view.startAt);
    expect(view.sportId, isNull);
    expect(view.sportKey, isNull);
  });
}
