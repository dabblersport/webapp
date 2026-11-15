// KAN-957: the Active feed reads `active_stream` — the filters go to the
// server as p_event_types / p_city, pages are keyed on the last row, and a
// filter change reloads from the first page.
import 'dart:convert';

import 'package:dabbler/features/social/providers/active_feed_notifier.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import '../../helpers/supabase_test_client.dart';

Map<String, dynamic> _row(int i) => <String, dynamic>{
  'event_type': 'game_created',
  'event_at': DateTime.utc(
    2026,
    11,
    16,
    12,
  ).subtract(Duration(minutes: i)).toIso8601String(),
  'entity_kind': 'game',
  'entity_id': 'g$i',
  'actor_profile_id': 'p$i',
  'city': 'Dubai',
  'title': 'Game $i',
  'actor_display_name': 'Host $i',
  'actor_avatar_url': null,
  'detail': 'Pitch $i',
  'start_at': '2026-11-20T15:00:00Z',
  'end_at': '2026-11-20T17:00:00Z',
  'is_live': i == 0,
  'sport_names_en': <String>['Football'],
  'sport_names_ar': <String>['كرة القدم'],
};

class _Server {
  final List<Map<String, dynamic>> bodies = <Map<String, dynamic>>[];
  final List<String> paths = <String>[];

  /// Rows answered per call, in order; the last one repeats.
  List<int> pageSizes = <int>[20];
  int _offset = 0;

  Future<http.Response> handle(http.Request r) async {
    paths.add(r.url.path);
    bodies.add(jsonDecode(r.body) as Map<String, dynamic>);
    final n = pageSizes[(bodies.length - 1).clamp(0, pageSizes.length - 1)];
    final rows = <Map<String, dynamic>>[
      for (var i = 0; i < n; i++) _row(_offset + i),
    ];
    _offset += n;
    return jsonListResponse(rows, request: r);
  }
}

void main() {
  test('reads active_stream with the filters and parses the row', () async {
    final server = _Server()..pageSizes = <int>[3];
    var filter = const ActiveFilter(city: 'Dubai', type: ActiveType.games);
    final n = ActiveFeedNotifier(
      buildTestSupabaseClient(server.handle),
      filter: () => filter,
    );
    addTearDown(n.dispose);
    await n.load();

    expect(server.paths.single, endsWith('/rpc/active_stream'));
    expect(server.bodies.single, <String, dynamic>{
      'p_event_types': <String>['game_created', 'game_started', 'game_ended'],
      'p_city': 'Dubai',
      'p_limit': 20,
      'p_before': null,
      'p_before_type': null,
      'p_before_entity': null,
    });
    final s = n.state as ActiveFeedData;
    expect(s.events, hasLength(3));
    expect(s.hasMore, isFalse);
    final first = s.events.first;
    expect(first.id, 'game_created:g0');
    expect(first.isLive, isTrue);
    expect(first.actorName, 'Host 0');
    expect(first.detail, 'Pitch 0');
    expect(first.startAt, DateTime.utc(2026, 11, 20, 15).toLocal());
    expect(first.sportsFor('ar'), <String>['كرة القدم']);
    expect(first.sportsFor('en'), <String>['Football']);

    // "All" and every city send nulls.
    filter = const ActiveFilter();
    await n.refilter();
    expect(server.bodies.last['p_event_types'], isNull);
    expect(server.bodies.last['p_city'], isNull);
  });

  test('the next page is keyed on the last row', () async {
    final server = _Server()..pageSizes = <int>[20, 5];
    final n = ActiveFeedNotifier(buildTestSupabaseClient(server.handle));
    addTearDown(n.dispose);
    await n.load();
    final page1 = (n.state as ActiveFeedData).events;
    expect(page1, hasLength(20));
    expect(n.state.hasMore, isTrue);

    await n.loadMore();
    final last = page1.last;
    expect(
      server.bodies.last['p_before'],
      last.eventAt.toUtc().toIso8601String(),
    );
    expect(server.bodies.last['p_before_type'], last.eventType);
    expect(server.bodies.last['p_before_entity'], last.entityId);
    final s = n.state as ActiveFeedData;
    expect(s.events, hasLength(25));
    expect(s.hasMore, isFalse);
  });

  test(
    'the first page fills to a screenful when rows are unparseable',
    () async {
      // 20 rows of which only 2 parse: the notifier reads on (KAN-955 fill).
      var call = 0;
      final n = ActiveFeedNotifier(
        buildTestSupabaseClient((r) async {
          call++;
          final rows = <Map<String, dynamic>>[
            for (var i = 0; i < 20; i++)
              i < 2
                  ? _row(call * 100 + i)
                  : <String, dynamic>{'event_type': 'x'},
          ];
          return jsonListResponse(rows, request: r);
        }),
      );
      addTearDown(n.dispose);
      await n.load();
      // 2 per page; the walk stops at the cap of 4 extra pages.
      expect(call, 5);
      expect(n.state.events, hasLength(10));
    },
  );

  test('a failed first load is the error state', () async {
    final n = ActiveFeedNotifier(
      buildTestSupabaseClient(
        (r) async => postgrestErrorResponse(
          message: 'offline',
          code: '500',
          status: 500,
          request: r,
        ),
      ),
    );
    addTearDown(n.dispose);
    await n.load();
    expect(n.state, isA<ActiveFeedFailure>());
  });

  test('ActiveType maps every stream event type', () {
    for (final t in <String>[
      'player_joined',
      'venue_added',
      'game_created',
      'game_started',
      'game_ended',
      'meetup_created',
      'meetup_started',
      'meetup_completed',
    ]) {
      expect(ActiveType.ofEvent(t), isNotNull, reason: t);
    }
  });
}
