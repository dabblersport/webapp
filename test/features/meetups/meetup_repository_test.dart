import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/features/meetups/data/repositories/meetup_repository_impl.dart';
import 'package:dabbler/features/meetups/domain/models/meetup_enums.dart';
import 'package:dabbler/features/meetups/domain/models/meetup_inputs.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import 'meetup_mocks.mocks.dart';

void main() {
  late MockMeetupDataSource ds;
  late MeetupRepositoryImpl repo;
  final boom = Exception('SocketException: down');

  setUp(() {
    ds = MockMeetupDataSource();
    repo = MeetupRepositoryImpl(ds);
  });

  final create = CreateMeetupInput(
    sportId: 's',
    sportVariantId: 'v',
    title: 'Run',
    locationName: 'Park',
    startAt: DateTime.utc(2026, 11, 1),
  );

  void expectFailure(Result<dynamic, Failure> r) {
    expect(r.isFailure, isTrue);
    expect(r.requireError.category, FailureCode.network);
  }

  test('create ok + failure', () async {
    when(ds.create(any, actorType: anyNamed('actorType')))
        .thenAnswer((_) async => 'm1');
    expect((await repo.create(create)).requireValue, 'm1');
    when(ds.create(any, actorType: anyNamed('actorType'))).thenThrow(boom);
    expectFailure(await repo.create(create));
  });

  test('rsvp maps each action and result', () async {
    when(ds.rsvp('m', 'going', profileId: anyNamed('profileId')))
        .thenAnswer((_) async => 'going');
    when(ds.rsvp('m', 'request', profileId: anyNamed('profileId')))
        .thenAnswer((_) async => 'pending');
    when(ds.rsvp('m', 'cancel', profileId: anyNamed('profileId')))
        .thenAnswer((_) async => 'cancelled');
    when(ds.rsvp('m', 'interested', profileId: anyNamed('profileId')))
        .thenAnswer((_) async => 'interested');
    expect((await repo.rsvp('m', RsvpAction.going)).requireValue, RsvpStatus.going);
    expect((await repo.rsvp('m', RsvpAction.request)).requireValue, RsvpStatus.pending);
    expect((await repo.rsvp('m', RsvpAction.cancel)).requireValue, RsvpStatus.cancelled);
    expect((await repo.rsvp('m', RsvpAction.interested)).requireValue,
        RsvpStatus.interested);
    when(ds.rsvp('x', 'going', profileId: anyNamed('profileId'))).thenThrow(boom);
    expectFailure(await repo.rsvp('x', RsvpAction.going));
  });

  test('cancel ok + failure', () async {
    when(ds.cancel('m')).thenAnswer((_) async {});
    expect((await repo.cancel('m')).isSuccess, isTrue);
    when(ds.cancel('m')).thenThrow(boom);
    expectFailure(await repo.cancel('m'));
  });

  test('nearby ok + failure', () async {
    when(ds.nearby(1, 2, 500)).thenAnswer((_) async => [
          {'id': 'a', 'title': 'T', 'starts_at': '2026-11-01T10:00:00Z', 'distance_m': 12.5}
        ]);
    final r = await repo.nearbyMeetups(lat: 1, lng: 2, radiusMeters: 500);
    expect(r.requireValue.single.distanceM, 12.5);
    when(ds.nearby(1, 2, 500)).thenThrow(boom);
    expectFailure(await repo.nearbyMeetups(lat: 1, lng: 2, radiusMeters: 500));
  });

  test('card ok + failure', () async {
    when(ds.card('m', 'player')).thenAnswer((_) async => {'id': 'm', 'title': 'T'});
    expect((await repo.meetupCard('m')).requireValue.id, 'm');
    when(ds.card('m', 'player')).thenThrow(boom);
    expectFailure(await repo.meetupCard('m'));
  });

  test('attendees ok + status filter + failure', () async {
    when(ds.attendees('m', status: 'going', limit: 50, offset: 0))
        .thenAnswer((_) async => [
              {'actor_profile_id': 'p', 'display_name': 'A', 'username': 'a', 'status': 'going'}
            ]);
    final r = await repo.attendees('m', status: RsvpStatus.going);
    expect(r.requireValue.single.status, RsvpStatus.going);
    when(ds.attendees('m', status: 'going', limit: 50, offset: 0)).thenThrow(boom);
    expectFailure(await repo.attendees('m', status: RsvpStatus.going));
  });

  test('canCreate + canRsvp ok + failure', () async {
    when(ds.canCreate('p')).thenAnswer((_) async => true);
    expect((await repo.canCreate('p')).requireValue, isTrue);
    when(ds.canRsvp('m'))
        .thenAnswer((_) async => {'allowed': true, 'cta': 'request'});
    expect((await repo.canRsvp('m')).requireValue.cta, RsvpCta.request);
    when(ds.canCreate('p')).thenThrow(boom);
    when(ds.canRsvp('m')).thenThrow(boom);
    expectFailure(await repo.canCreate('p'));
    expectFailure(await repo.canRsvp('m'));
  });

  test('update ok + failure', () async {
    const u = UpdateMeetupInput(meetupId: 'm', title: 'New');
    when(ds.update(any)).thenAnswer(
      (_) async => {'id': 'm', 'title': 'New', 'is_host': true},
    );
    final card = (await repo.update(u)).requireValue;
    expect(card.title, 'New');
    expect(card.isHost, isTrue);
    when(ds.update(any)).thenThrow(boom);
    expectFailure(await repo.update(u));
  });

  test('decideRequest and removeAttendee ok + failure', () async {
    when(ds.decideRequest('m', 'u', 'approve')).thenAnswer((_) async => 'interested');
    when(ds.decideRequest('m', 'u', 'decline')).thenAnswer((_) async => 'cancelled');
    when(ds.removeAttendee('m', 'u')).thenAnswer((_) async => 'cancelled');
    expect((await repo.decideRequest('m', 'u', MeetupDecision.approve)).requireValue,
        RsvpStatus.interested);
    expect((await repo.decideRequest('m', 'u', MeetupDecision.decline)).requireValue,
        RsvpStatus.cancelled);
    expect((await repo.removeAttendee('m', 'u')).requireValue, RsvpStatus.cancelled);
    when(ds.removeAttendee('m', 'u')).thenThrow(boom);
    expectFailure(await repo.removeAttendee('m', 'u'));
  });

  test('RPC error messages map to typed failures', () async {
    const expected = {
      'organiser_required': FailureCode.forbidden,
      'visibility_not_supported': FailureCode.validation,
      'free_meetups_only': FailureCode.validation,
      'not_host': FailureCode.forbidden,
      'meetup_cancelled': FailureCode.conflict,
      'capacity_below_going_count': FailureCode.conflict,
      'invalid_capacity': FailureCode.validation,
      'title_invalid': FailureCode.validation,
      'invalid_time_range': FailureCode.validation,
      'no_pending_request': FailureCode.conflict,
      'invalid_decision': FailureCode.validation,
      'cannot_remove_host': FailureCode.forbidden,
      'attendee_not_found': FailureCode.notFound,
      'auth_required': FailureCode.unauthorized,
    };
    for (final e in expected.entries) {
      when(ds.cancel('m')).thenThrow(Exception('PostgrestException(message: ${e.key}, code: P0001)'));
      final f = (await repo.cancel('m')).requireError;
      expect(f.category, e.value, reason: e.key);
      expect(f.code, e.key);
    }
  });

  test('list, sports, variants ok + failure', () async {
    when(ds.soloSports()).thenAnswer((_) async => [
          {'id': 's', 'name_en': 'Running'}
        ]);
    expect((await repo.soloSports()).requireValue.single.nameEn, 'Running');
    when(ds.sportVariants('s')).thenAnswer((_) async => [
          {'id': 'v', 'sport_id': 's', 'name_en': '5k'}
        ]);
    expect((await repo.sportVariants('s')).requireValue.single.requiredPlayers, 1);
    when(ds.fetchMeetupList(sportId: null, limit: 20, offset: 0))
        .thenAnswer((_) async => []);
    expect((await repo.fetchMeetups()).requireValue, isEmpty);
    when(ds.soloSports()).thenThrow(boom);
    expectFailure(await repo.soloSports());
  });
}
