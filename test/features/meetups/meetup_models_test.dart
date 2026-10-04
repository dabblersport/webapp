import 'package:dabbler/features/meetups/domain/models/meetup_enums.dart';
import 'package:dabbler/features/meetups/domain/models/meetup_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'v_meetup_list row parses; creator_user_id is ignored; optionals null',
    () {
      final m = MeetupListItem.fromJson({
        'id': 'm1',
        'title': 'Sunrise run',
        'description': null,
        'start_at': '2026-11-01T05:30:00+00:00',
        'end_at': null,
        'capacity': 2,
        'members_only': false,
        'listing_visibility': 'public',
        'rsvp_policy': 'request',
        'is_cancelled': false,
        'creator_profile_id': 'p1',
        'creator_user_id': 'u1',
        'sport_id': 's1',
        'sport_name_en': 'Running',
        'location_name': 'Park',
        'joining_rule': 'free',
        'cost_cover': 'free',
        'going_count': 2,
        'interested_count': 1,
        'declined_count': 0,
        'my_rsvp_status': null,
      });
      expect(m.rsvpPolicy, RsvpPolicy.request);
      expect(m.isFull, isTrue);
      expect(m.endAt, isNull);
      expect(m.toJson().containsKey('creator_user_id'), isFalse);
      expect(m.lifecycle(DateTime.utc(2026, 10, 1)), MeetupLifecycle.upcoming);
      expect(m.lifecycle(DateTime.utc(2026, 12, 1)), MeetupLifecycle.started);
    },
  );

  test(
    'unknown/deferred rsvp_policy reads as closed; no capacity is never full',
    () {
      final m = MeetupListItem.fromJson({
        'id': 'm',
        'title': 'T',
        'start_at': '2026-11-01T05:30:00Z',
        'rsvp_policy': 'invite',
        'is_cancelled': true,
      });
      expect(m.rsvpPolicy, RsvpPolicy.closed);
      expect(m.isFull, isFalse);
      expect(m.lifecycle(DateTime.utc(2026, 1, 1)), MeetupLifecycle.cancelled);
      expect(RsvpPolicy.fromDb('link'), RsvpPolicy.closed);
    },
  );

  test('getnearbymeetups row', () {
    final n = NearbyMeetup.fromJson({
      'id': 'a',
      'title': 'T',
      'starts_at': '2026-11-01T10:00:00Z',
      'lat': 25.2,
      'lng': 55.3,
      'areaid': 'ar',
      'distance_m': 120,
    });
    expect(n.distanceM, 120.0);
    expect(n.areaId, 'ar');
  });

  test('rpc_meetup_card jsonb, nested host/counts, sparse', () {
    final c = MeetupCard.fromJson({
      'id': 'm',
      'title': 'T',
      'start_at': '2026-11-01T10:00:00Z',
      'visibility': 'public',
      'description': 'Easy pace',
      'end_at': '2026-11-01T11:00:00Z',
      'location_name': 'Park',
      'capacity': 12,
      'is_cancelled': false,
      'is_host': true,
      'owner_profile_id': 'pp',
      'host': {'actor_profile_id': 'p', 'display_name': 'H', 'username': 'h'},
      'counts': {'going': 3, 'interested': 1, 'declined': 0, 'pending': 2},
      'my_status': 'going',
    });
    expect(c.host!.displayName, 'H');
    expect(c.counts.going, 3);
    expect(c.counts.pending, 2);
    expect(c.isHost, isTrue);
    expect(c.locationName, 'Park');
    expect(c.toJson().containsKey('owner_user_id'), isFalse);
    final sparse = MeetupCard.fromJson({'id': 'm'});
    expect(sparse.counts.going, 0);
    expect(sparse.host, isNull);
    expect(sparse.counts.pending, isNull);
    expect(sparse.isHost, isFalse);
  });

  test('attendee status + eligibility + sport shapes', () {
    expect(
      MeetupAttendee.fromJson({
        'actor_profile_id': 'p',
        'status': 'declined',
      }).status,
      RsvpStatus.declined,
    );
    expect(
      MeetupAttendee.fromJson({
        'actor_profile_id': 'p',
        'status': 'zzz',
      }).status,
      RsvpStatus.unknown,
    );
    final e = RsvpEligibility.fromJson({
      'allowed': false,
      'cta': 'closed',
      'reason': 'closed',
    });
    expect(e.allowed, isFalse);
    expect(e.cta, RsvpCta.closed);
    expect(
      RsvpEligibility.fromJson({'allowed': true, 'cta': 'rsvp_going'}).cta,
      RsvpCta.rsvpGoing,
    );
    expect(RsvpEligibility.fromJson({'cta': 'weird'}).cta, RsvpCta.unknown);
    expect(MeetupSport.fromJson({'id': 's', 'name_en': 'Yoga'}).nameAr, isNull);
    expect(RsvpStatus.fromDb('pending'), RsvpStatus.pending);
    expect(RsvpStatus.fromDbOrNull(null), isNull);
  });
}
