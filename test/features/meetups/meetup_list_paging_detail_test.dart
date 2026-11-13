// KAN-932: the meetups list reads upcoming meetups from now with paging; the
// detail shows the description; an edited location_name wins over venue_name.
import 'dart:convert';

import 'package:dabbler/features/meetups/data/datasources/supabase_meetup_datasource.dart';
import 'package:dabbler/features/meetups/domain/models/meetup_enums.dart';
import 'package:dabbler/features/meetups/domain/models/meetup_models.dart';
import 'package:dabbler/features/meetups/presentation/screens/meetup_detail_screen.dart';
import 'package:dabbler/features/meetups/presentation/screens/meetups_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import '../../helpers/supabase_test_client.dart';
import 'meetup_screens_harness.dart';

MeetupCard _card({String? description, String? location, String? venue}) =>
    MeetupCard(
      id: 'm1',
      title: 'Sunrise run',
      description: description,
      startAt: DateTime.now().add(const Duration(days: 1)),
      locationName: location,
      venueName: venue,
      capacity: 40,
      counts: const MeetupCounts(going: 2),
      host: const MeetupHost(displayName: 'Ahmed Farouk'),
    );

Future<void> _detail(WidgetTester tester, MeetupCard card) => pumpMeetups(
  tester,
  MeetupDetailScreen(meetupId: 'm1', onBack: () {}),
  FakeMeetupRepository()
    ..card = card
    ..eligibility = const RsvpEligibility(
      allowed: true,
      cta: RsvpCta.rsvpGoing,
    ),
);

void main() {
  group('list query', () {
    test('upcoming from now, soonest first, one page', () async {
      final seen = <http.Request>[];
      final now = DateTime.utc(2026, 11, 14, 9, 30);
      final ds = SupabaseMeetupDataSource(
        buildTestSupabaseClient((r) async {
          seen.add(r);
          return http.Response(
            jsonEncode(<Object>[]),
            200,
            headers: {'content-type': 'application/json'},
            request: r,
          );
        }),
        now: () => now,
      );
      await ds.fetchMeetupList(limit: 40, offset: 0);
      final q = seen.single.url.queryParameters;
      expect(seen.single.url.path, '/rest/v1/v_meetup_list');
      expect(q['is_cancelled'], 'eq.false');
      expect(q['start_at'], 'gte.${now.toIso8601String()}');
      expect(q['order'], startsWith('start_at.asc'));
      expect(q['limit'], '40');
      expect(q['offset'], '0');
    });
  });

  group('list paging', () {
    testWidgets('a full page offers Load more, which fetches two pages', (
      tester,
    ) async {
      final repo = FakeMeetupRepository()
        ..list = [
          for (var i = 0; i < 25; i++)
            meetupRow(
              'm$i',
              title: 'Run $i',
              startsIn: Duration(days: i + 1),
            ),
        ];
      await pumpMeetups(tester, const MeetupsScreen(), repo);
      expect(repo.listLimits, everyElement(20));
      final more = find.text('Load more');
      await tester.scrollUntilVisible(
        more,
        400,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(more);
      await settle(tester);
      expect(repo.listLimits.last, 40);
      // 25 rows came back for two pages of 20: nothing more to load.
      expect(find.text('Load more'), findsNothing);
    });

    testWidgets('a short page has no Load more', (tester) async {
      final repo = FakeMeetupRepository()..list = [meetupRow('a')];
      await pumpMeetups(tester, const MeetupsScreen(), repo);
      expect(find.text('Sunrise run'), findsOneWidget);
      expect(find.text('Load more', skipOffstage: false), findsNothing);
    });

    testWidgets('the card shows the edited location, not the venue', (
      tester,
    ) async {
      final repo = FakeMeetupRepository()
        ..list = [meetupRow('a').copyWith(locationName: 'Safa Park gate 3')];
      await pumpMeetups(tester, const MeetupsScreen(), repo);
      expect(find.textContaining('Safa Park gate 3'), findsWidgets);
      expect(find.textContaining('Kite Beach'), findsNothing);
    });
  });

  group('detail fields', () {
    testWidgets('shows the description under About', (tester) async {
      await _detail(
        tester,
        _card(description: 'Easy 5k along the beach.', location: 'Kite'),
      );
      expect(find.text('About', skipOffstage: false), findsOneWidget);
      expect(
        find.text('Easy 5k along the beach.', skipOffstage: false),
        findsOneWidget,
      );
    });

    testWidgets('no About section without a description', (tester) async {
      await _detail(tester, _card(description: '  ', location: 'Kite'));
      expect(find.text('About', skipOffstage: false), findsNothing);
    });

    testWidgets('the edited location_name wins over venue_name', (
      tester,
    ) async {
      await _detail(
        tester,
        _card(location: 'Safa Park gate 3', venue: 'Old Venue'),
      );
      expect(find.text('Safa Park gate 3', skipOffstage: false), findsWidgets);
      expect(find.text('Old Venue', skipOffstage: false), findsNothing);
    });

    testWidgets('falls back to venue_name with no location_name', (
      tester,
    ) async {
      await _detail(tester, _card(venue: 'Kite Beach Courts'));
      expect(find.text('Kite Beach Courts', skipOffstage: false), findsWidgets);
    });
  });
}
