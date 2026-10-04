import 'dart:convert';

import 'package:dabbler/features/meetups/data/datasources/meetup_datasource.dart';
import 'package:dabbler/features/meetups/data/datasources/supabase_meetup_datasource.dart';
import 'package:dabbler/features/meetups/domain/models/meetup_inputs.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import '../../helpers/supabase_test_client.dart';

http.Response _ok(http.Request r, String body) => http.Response(
  body,
  200,
  headers: {'content-type': 'application/json'},
  request: r,
);

void main() {
  late List<http.Request> seen;
  late SupabaseMeetupDataSource ds;

  SupabaseMeetupDataSource build(http.Response Function(http.Request) h) {
    seen = [];
    return SupabaseMeetupDataSource(
      buildTestSupabaseClient((r) async {
        seen.add(r);
        return h(r);
      }),
    );
  }

  Map<String, dynamic> body() =>
      jsonDecode(seen.single.body) as Map<String, dynamic>;
  String path() => seen.single.url.path;

  final input = CreateMeetupInput(
    sportId: 's',
    sportVariantId: 'v',
    title: 'Run',
    locationName: 'Park',
    startAt: DateTime.utc(2026, 11, 1, 5),
    capacity: 10,
  );

  test('create sends rpc_create_meetup, public + free fixed', () async {
    ds = build((r) => _ok(r, jsonEncode('new-id')));
    expect(await ds.create(input, actorType: 'organiser'), 'new-id');
    expect(path(), '/rest/v1/rpc/rpc_create_meetup');
    expect(body().keys.toSet(), MeetupRpcParams.create(input).keys.toSet());
    expect(body()['p_listing_visibility'], 'public');
    expect(body()['p_members_only'], false);
    expect(body()['p_actor_type'], 'organiser');
    expect(body()['p_start_at'], '2026-11-01T05:00:00.000Z');
  });

  test('rsvp uses the canonical 4-arg overload name + keys', () async {
    ds = build((r) => _ok(r, jsonEncode('going')));
    expect(await ds.rsvp('m', 'going', profileId: 'p'), 'going');
    expect(path(), '/rest/v1/rpc/rpc_meetup_rsvp');
    expect(body(), {
      'p_meetup_id': 'm',
      'p_action': 'going',
      'p_profile_id': 'p',
    });
    expect(body().containsKey('p_status'), isFalse);
    expect(body().containsKey('p_profile_type'), isFalse);
  });

  test('cancel, card, attendees, nearby, can_* names and keys', () async {
    ds = build((r) => _ok(r, jsonEncode('ok')));
    await ds.cancel('m');
    expect(path(), '/rest/v1/rpc/rpc_meetup_cancel');
    expect(body(), {'p_meetup_id': 'm'});

    ds = build((r) => _ok(r, jsonEncode({'id': 'm'})));
    await ds.card('m', 'player');
    expect(path(), '/rest/v1/rpc/rpc_meetup_card');
    expect(body(), {'p_meetup_id': 'm', 'p_profile_type': 'player'});

    ds = build((r) => _ok(r, jsonEncode([])));
    await ds.attendees('m', status: 'going', limit: 5, offset: 10);
    expect(path(), '/rest/v1/rpc/rpc_meetup_attendees');
    expect(body(), {
      'p_meetup_id': 'm',
      'p_status': 'going',
      'p_limit': 5,
      'p_offset': 10,
    });

    ds = build((r) => _ok(r, jsonEncode([])));
    await ds.nearby(1.5, 2.5, 800);
    expect(path(), '/rest/v1/rpc/getnearbymeetups');
    expect(body(), {'p_lat': 1.5, 'p_lng': 2.5, 'p_radius': 800});

    ds = build((r) => _ok(r, jsonEncode(true)));
    expect(await ds.canCreate('prof'), isTrue);
    expect(path(), '/rest/v1/rpc/can_create_meetup');
    expect(body(), {'p_actor': 'prof'});

    ds = build(
      (r) => _ok(r, jsonEncode({'allowed': true, 'cta': 'rsvp_going'})),
    );
    await ds.canRsvp('m');
    expect(path(), '/rest/v1/rpc/can_current_user_rsvp_meetup');
    expect(body(), {'p_meetup_id': 'm'});
  });

  test('update targets rpc_meetup_update with its final param names', () async {
    ds = build((r) => _ok(r, jsonEncode({'id': 'm'})));
    final card = await ds.update(
      const UpdateMeetupInput(meetupId: 'm', title: 'N', capacity: 4),
    );
    expect(card, isA<Map<String, dynamic>>());
    expect(path(), '/rest/v1/rpc/rpc_meetup_update');
    expect(body().keys.toSet(), {
      'p_meetup_id',
      'p_title',
      'p_description',
      'p_start_at',
      'p_end_at',
      'p_location_name',
      'p_capacity',
    });
    expect(body()['p_capacity'], 4);
  });

  test('decide_request and remove_attendee names and keys', () async {
    ds = build((r) => _ok(r, jsonEncode('going')));
    expect(await ds.decideRequest('m', 'u', 'approve'), 'going');
    expect(path(), '/rest/v1/rpc/rpc_meetup_decide_request');
    expect(body(), {
      'p_meetup_id': 'm',
      'p_user_id': 'u',
      'p_decision': 'approve',
    });
    ds = build((r) => _ok(r, jsonEncode('cancelled')));
    expect(await ds.removeAttendee('m', 'u'), 'cancelled');
    expect(path(), '/rest/v1/rpc/rpc_meetup_remove_attendee');
    expect(body(), {'p_meetup_id': 'm', 'p_user_id': 'u'});
  });

  test('retired overload names are never used', () {
    for (final p in [MeetupRpcParams.rsvp('m', 'going')]) {
      expect(p.keys, isNot(contains('p_status')));
    }
  });

  test('sports query filters can_solo; list reads v_meetup_list', () async {
    ds = build((r) => _ok(r, jsonEncode([])));
    await ds.soloSports();
    expect(path(), '/rest/v1/sports');
    expect(seen.single.url.queryParameters['can_solo'], 'eq.true');
    ds = build((r) => _ok(r, jsonEncode([])));
    await ds.fetchMeetupList(limit: 20, offset: 0);
    expect(path(), '/rest/v1/v_meetup_list');
    expect(seen.single.url.queryParameters['is_cancelled'], 'eq.false');
    expect(
      seen.single.url.queryParameters.containsKey('select') &&
          !seen.single.url.queryParameters['select']!.contains(
            'creator_user_id',
          ),
      isTrue,
    );
  });
}
