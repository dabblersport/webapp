// KAN-742 (KAN-715 R02): meetups become a subtype of the shared public.events
// parent. The meetup models carry the parent id as eventId, separately from
// id, which keeps meaning the meetups id (the route key). A payload without
// event_id still parses (eventId null), and a null-title record parses
// without an invented name.
import 'package:dabbler/data/models/search/meetup_search_result.dart';
import 'package:dabbler/features/meetups/data/mappers/meetup_mappers.dart';
import 'package:dabbler/features/meetups/data/repositories/meetup_repository_impl.dart';
import 'package:dabbler/features/meetups/domain/models/meetup_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import 'meetup_mocks.mocks.dart';

void main() {
  const String meetupId = '11111111-1111-1111-1111-111111111111';
  const String eventId = '99999999-9999-9999-9999-999999999999';

  // A v_meetup_list row that carries the parent id.
  Map<String, dynamic> withEvent() => <String, dynamic>{
    'id': meetupId,
    'event_id': eventId,
    'title': 'Morning run',
    'start_at': '2026-11-10T06:00:00Z',
    'end_at': '2026-11-10T07:00:00Z',
    'sport_id': 'sport-1',
  };

  // An old payload: no event_id key at all, null title / end / sport.
  Map<String, dynamic> legacyNulls() => <String, dynamic>{
    'id': meetupId,
    'title': null,
    'start_at': '2026-11-10T06:00:00Z',
    'end_at': null,
    'sport_id': null,
  };

  group('MeetupListItem', () {
    test('event_id present: eventId carried, id stays the meetups id', () {
      final MeetupListItem m = MeetupMappers.listItem(withEvent());
      expect(m.id, meetupId);
      expect(m.eventId, eventId);
      expect(m.title, 'Morning run');
    });

    test('no event_id, null title/end/sport: parses, nothing invented', () {
      final MeetupListItem m = MeetupMappers.listItem(legacyNulls());
      expect(m.id, meetupId);
      expect(m.eventId, isNull);
      expect(m.title, isNull);
      expect(m.endAt, isNull);
      expect(m.sportId, isNull);
      expect(m.startAt, DateTime.utc(2026, 11, 10, 6).toLocal()); // KAN-927
    });

    test('toJson round-trips event_id', () {
      final MeetupListItem m = MeetupMappers.listItem(withEvent());
      expect(m.toJson()['event_id'], eventId);
      expect(MeetupListItem.fromJson(m.toJson()).eventId, eventId);
    });
  });

  group('NearbyMeetup', () {
    test('event_id present and absent', () {
      final NearbyMeetup a = MeetupMappers.nearby(<String, dynamic>{
        'id': meetupId,
        'event_id': eventId,
        'title': 'Run',
      });
      expect(a.id, meetupId);
      expect(a.eventId, eventId);

      final NearbyMeetup b = MeetupMappers.nearby(<String, dynamic>{
        'id': meetupId,
        'title': 'Run',
        'starts_at': null,
      });
      expect(b.id, meetupId);
      expect(b.eventId, isNull);
      expect(b.startsAt, isNull);
    });
  });

  group('MeetupCard', () {
    test('event_id present and absent; null title/end parse', () {
      final MeetupCard a = MeetupMappers.card(<String, dynamic>{
        'id': meetupId,
        'event_id': eventId,
      });
      expect(a.id, meetupId);
      expect(a.eventId, eventId);

      final MeetupCard b = MeetupMappers.card(<String, dynamic>{
        'id': meetupId,
        'title': null,
        'end_at': null,
        'sport_key': null,
      });
      expect(b.id, meetupId);
      expect(b.eventId, isNull);
      expect(b.title, isNull);
      expect(b.endAt, isNull);
      expect(b.sportKey, isNull);
    });
  });

  group('MeetupSearchResult', () {
    test('event_id present and absent; id keeps the meetups id', () {
      final MeetupSearchResult a = MeetupSearchResult.fromJson(
        <String, dynamic>{
          'entity_id': meetupId,
          'event_id': eventId,
          'title': 'Run',
        },
      );
      expect(a.id, meetupId);
      expect(a.eventId, eventId);

      final MeetupSearchResult b = MeetupSearchResult.fromJson(
        <String, dynamic>{'entity_id': meetupId, 'title': 'Run'},
      );
      expect(b.id, meetupId);
      expect(b.eventId, isNull);
    });
  });

  group('repository passes event_id through the mappers', () {
    late MockMeetupDataSource ds;
    late MeetupRepositoryImpl repo;

    setUp(() {
      ds = MockMeetupDataSource();
      repo = MeetupRepositoryImpl(ds);
    });

    test('fetchMeetups: one row with event_id, one legacy row', () async {
      when(ds.fetchMeetupList(sportId: null, limit: 20, offset: 0)).thenAnswer(
        (_) async => <Map<String, dynamic>>[
          withEvent(),
          legacyNulls()..['id'] = 'other-meetup',
        ],
      );
      final List<MeetupListItem> items =
          (await repo.fetchMeetups()).requireValue;
      expect(items.map((MeetupListItem m) => m.id), <String>[
        meetupId,
        'other-meetup',
      ]);
      expect(items.first.eventId, eventId);
      expect(items.last.eventId, isNull);
      expect(items.last.title, isNull);
    });

    test('meetupCard: event_id carried, id unchanged', () async {
      when(ds.card(meetupId, 'player')).thenAnswer(
        (_) async => <String, dynamic>{'id': meetupId, 'event_id': eventId},
      );
      final MeetupCard card = (await repo.meetupCard(meetupId)).requireValue;
      expect(card.id, meetupId);
      expect(card.eventId, eventId);
    });
  });
}
