import 'package:dabbler/features/meetups/domain/models/meetup_enums.dart';
import 'package:dabbler/features/meetups/domain/models/meetup_models.dart';
import 'package:dabbler/features/meetups/presentation/providers/meetup_filters.dart';
import 'package:dabbler/features/meetups/presentation/screens/meetup_detail_screen.dart';
import 'package:dabbler/features/meetups/presentation/screens/meetups_screen.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'meetup_screens_harness.dart';

MeetupCard _card({String? hostId = 'host1'}) => MeetupCard(
  id: 'm1',
  title: 'Sunrise run',
  startAt: DateTime.now().add(const Duration(days: 1)),
  endAt: DateTime.now().add(const Duration(days: 1, minutes: 45)),
  locationName: 'Kite Beach',
  capacity: 40,
  counts: const MeetupCounts(going: 24),
  sportNameEn: 'Running',
  sportNameAr: 'جري',
  minSkill: 1,
  maxSkill: 2,
  host: MeetupHost(
    actorProfileId: hostId,
    displayName: 'Dubai Running Club',
    avatarUrl: null,
  ),
  attendees: const <MeetupAvatar>[
    MeetupAvatar(displayName: 'Lina Haddad'),
    MeetupAvatar(displayName: 'Yousef Amer'),
  ],
);

void main() {
  test('models parse the appended fields', () {
    final m = MeetupListItem.fromJson({
      'id': 'a',
      'title': 't',
      'start_at': '2026-10-05T10:00:00Z',
      'attendee_avatars': [
        {'avatar_url': 'u', 'display_name': 'Lina'},
      ],
    });
    expect(m.attendeeAvatars.single.displayName, 'Lina');
    expect(
      MeetupListItem.fromJson({
        'id': 'a',
        'title': 't',
        'start_at': '2026-10-05T10:00:00Z',
      }).attendeeAvatars,
      isEmpty,
    );
    final c = MeetupCard.fromJson({
      'id': 'a',
      'sport_key': 'running',
      'sport_name_en': 'Running',
      'min_skill': 1,
      'area_name': 'Marina',
      'venue_name': 'Kite',
      'host': {'avatar_url': 'h'},
      'attendees': [
        {'display_name': 'Lina'},
      ],
    });
    expect(c.sportNameEn, 'Running');
    expect(c.host!.avatarUrl, 'h');
    expect(c.attendees.single.displayName, 'Lina');
    expect(MeetupCard.fromJson({'id': 'a'}).attendees, isEmpty);
  });

  group('filters', () {
    final a = meetupRow('a', startsIn: const Duration(days: 3));
    final b = meetupRow('b', startsIn: const Duration(days: 1));
    final c = meetupRow('c', startsIn: const Duration(days: 2));
    final d = <String, double>{'a': 1000, 'b': 8000};

    test('radius drops far meetups, keeps unknown distances', () {
      final r = applyMeetupFilters(
        <MeetupListItem>[a, b, c],
        distances: d,
        radiusMeters: 5000,
      );
      expect(r.map((e) => e.id), <String>['c', 'a']);
    });

    test('soonest orders by start; nearest by distance, unknown last', () {
      final all = <MeetupListItem>[a, b, c];
      expect(applyMeetupFilters(all, distances: d).map((e) => e.id), <String>[
        'b',
        'c',
        'a',
      ]);
      expect(
        applyMeetupFilters(
          all,
          distances: d,
          sort: MeetupSort.nearest,
        ).map((e) => e.id),
        <String>['a', 'b', 'c'],
      );
    });
  });

  group('listing card', () {
    testWidgets('faces, skill and sport badges, distance, price', (
      tester,
    ) async {
      final repo = FakeMeetupRepository()
        ..list = [
          meetupRow(
            'a',
            minSkill: 1,
            maxSkill: 2,
            faces: const [
              MeetupAvatar(displayName: 'Lina'),
              MeetupAvatar(displayName: 'Yousef'),
            ],
          ),
        ]
        ..nearbyList = const [
          NearbyMeetup(id: 'a', title: 't', distanceM: 3000),
        ];
      await pumpMeetups(
        tester,
        const MeetupsScreen(),
        repo,
        locationReady: true,
      );
      expect(find.byType(DabblerAvatarGroup), findsOneWidget);
      expect(find.text('3.0 km'), findsOneWidget);
      expect(find.text('Free'), findsOneWidget);
      expect(find.text('Running'), findsWidgets);
      // Sport and skill, on the frame's listing tags (`Listings.dc.html:526`),
      // plus Popular: 24 of 40 going is over half the places.
      expect(find.byType(DabblerListingTag), findsNWidgets(3));
      expect(find.text('Popular'), findsOneWidget);
      expect(find.byType(DabblerBadge), findsNothing);
    });
  });

  group('filter sheet', () {
    testWidgets('picking Within 5 km shows the applied chip and Clear all', (
      tester,
    ) async {
      final repo = FakeMeetupRepository()..list = [meetupRow('a')];
      await pumpMeetups(
        tester,
        const MeetupsScreen(),
        repo,
        locationReady: true,
      );
      await tester.tap(find.bySemanticsLabel('Filters'));
      await settle(tester);
      await tester.tap(find.text('Within 5 km'));
      await settle(tester);
      expect(find.text('Show 1 meetups'), findsOneWidget);
      await tester.tap(find.text('Reset'));
      await settle(tester);
      expect(find.text('Clear all'), findsNothing);
    });
  });

  group('details', () {
    Future<FollowLog> pump(
      WidgetTester tester, {
      bool following = false,
      String? hostId = 'host1',
      Locale l = const Locale('en'),
    }) async {
      final log = FollowLog()..following = following;
      final repo = FakeMeetupRepository()
        ..card = _card(hostId: hostId)
        ..eligibility = const RsvpEligibility(
          allowed: true,
          cta: RsvpCta.rsvpGoing,
        )
        ..nearbyList = const [
          NearbyMeetup(id: 'm1', title: 't', distanceM: 3000),
        ];
      await pumpMeetups(
        tester,
        MeetupDetailScreen(meetupId: 'm1', onBack: () {}),
        repo,
        locale: l,
        locationReady: true,
        follow: log,
      );
      return log;
    }

    testWidgets('sport and skill chips, distance, names, host card', (
      tester,
    ) async {
      await pump(tester);
      expect(find.text('Running'), findsOneWidget);
      expect(find.text('Beginner'), findsOneWidget);
      expect(find.text('3.0 km away'), findsOneWidget);
      expect(find.textContaining('Lina, Yousef'), findsOneWidget);
      expect(find.text('Dubai Running Club'), findsOneWidget);
    });

    for (final c in <(String, List<MeetupListItem>, bool)>[
      ('with a vibe key', [meetupRow('m1', vibeKey: 'supportive')], true),
      ('without a vibe key', [meetupRow('m1')], false),
      ('with no list row (deep link)', <MeetupListItem>[], false),
    ]) {
      testWidgets('vibe tag ${c.$1}', (tester) async {
        final repo = FakeMeetupRepository()
          ..card = _card()
          ..list = c.$2
          ..eligibility = const RsvpEligibility(
            allowed: true,
            cta: RsvpCta.rsvpGoing,
          );
        await pumpMeetups(
          tester,
          MeetupDetailScreen(meetupId: 'm1', onBack: () {}),
          repo,
        );
        expect(find.text('Supportive'), c.$3 ? findsOneWidget : findsNothing);
      });
    }

    testWidgets('no favourite placeholder in the header', (tester) async {
      await pump(tester);
      expect(find.bySemanticsLabel('Favourite'), findsNothing);
    });

    testWidgets('Follow calls the profile follow action', (tester) async {
      final log = await pump(tester);
      await tester.tap(find.text('Follow'));
      await settle(tester);
      expect(log.calls, [('me', 'host1', false)]);
    });

    testWidgets('Following unfollows', (tester) async {
      final log = await pump(tester, following: true);
      await tester.tap(find.text('Following'));
      await settle(tester);
      expect(log.calls, [('me', 'host1', true)]);
    });

    testWidgets('no pill without a host profile id', (tester) async {
      await pump(tester, hostId: null);
      expect(find.text('Follow'), findsNothing);
    });

    testWidgets('Arabic uses the Arabic sport name', (tester) async {
      await pump(tester, l: const Locale('ar'));
      expect(find.text('جري'), findsOneWidget);
    });
  });
}
