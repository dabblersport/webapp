import 'dart:async';

import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/features/meetups/domain/models/meetup_enums.dart';
import 'package:dabbler/features/meetups/domain/models/meetup_models.dart';
import 'package:dabbler/features/meetups/presentation/screens/meetup_detail_screen.dart';
import 'package:dabbler/features/meetups/presentation/screens/meetups_screen.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'meetup_screens_harness.dart';

const _locales = <Locale>[Locale('en'), Locale('ar')];

MeetupCard _card({
  int? capacity = 40,
  int going = 24,
  String? my,
  bool cancelled = false,
}) => MeetupCard(
  id: 'm1',
  title: 'Sunrise run',
  startAt: DateTime.now().add(const Duration(days: 1)),
  endAt: DateTime.now().add(const Duration(days: 1, minutes: 45)),
  locationName: 'Kite Beach',
  capacity: capacity,
  isCancelled: cancelled,
  counts: MeetupCounts(going: going),
  myStatus: my,
  host: const MeetupHost(displayName: 'Ahmed Farouk'),
);

Future<FakeMeetupRepository> _detail(
  WidgetTester tester, {
  required RsvpCta cta,
  String? my,
  int? capacity = 40,
  int going = 24,
  bool cancelled = false,
  Locale locale = const Locale('en'),
  VoidCallback? onSwitch,
}) async {
  final repo = FakeMeetupRepository()
    ..card = _card(
      capacity: capacity,
      going: going,
      my: my,
      cancelled: cancelled,
    )
    ..eligibility = RsvpEligibility(allowed: true, cta: cta);
  await pumpMeetups(
    tester,
    MeetupDetailScreen(
      meetupId: 'm1',
      onBack: () {},
      onSwitchProfile: onSwitch,
    ),
    repo,
    locale: locale,
  );
  return repo;
}

DabblerRsvpCta _cta(WidgetTester t) =>
    t.widget<DabblerRsvpCta>(find.byType(DabblerRsvpCta));

void main() {
  group('detail: every RSVP state from the RPC cta', () {
    final cases = <(String, RsvpCta, String?, int?, DabblerRsvpCtaState)>[
      ('join', RsvpCta.rsvpGoing, null, 40, DabblerRsvpCtaState.join),
      ('request', RsvpCta.request, null, 40, DabblerRsvpCtaState.request),
      ('going', RsvpCta.already, 'going', 40, DabblerRsvpCtaState.going),
      (
        'interested',
        RsvpCta.already,
        'interested',
        40,
        DabblerRsvpCtaState.interested,
      ),
      ('pending', RsvpCta.already, 'pending', 40, DabblerRsvpCtaState.pending),
      ('closed', RsvpCta.closed, null, 40, DabblerRsvpCtaState.closed),
      ('cancelled', RsvpCta.cancelled, null, 40, DabblerRsvpCtaState.cancelled),
      ('started', RsvpCta.started, null, 40, DabblerRsvpCtaState.started),
      (
        'not_visible',
        RsvpCta.notVisible,
        null,
        40,
        DabblerRsvpCtaState.notVisible,
      ),
      (
        'not_allowed',
        RsvpCta.notAllowed,
        null,
        40,
        DabblerRsvpCtaState.notAllowed,
      ),
      ('full', RsvpCta.rsvpGoing, null, 24, DabblerRsvpCtaState.full),
    ];
    for (final locale in _locales) {
      for (final c in cases) {
        testWidgets('${c.$1} (${locale.languageCode})', (tester) async {
          await _detail(
            tester,
            cta: c.$2,
            my: c.$3,
            capacity: c.$4,
            going: 24,
            locale: locale,
          );
          expect(_cta(tester).state, c.$5);
          expect(find.text('Sunrise run'), findsOneWidget);
        });
      }
    }

    testWidgets('full says Full - you\'re interested', (tester) async {
      await _detail(tester, cta: RsvpCta.rsvpGoing, capacity: 24);
      expect(find.text("Full - you're interested"), findsOneWidget);
    });

    testWidgets('a cancelled meetup overrides the cta', (tester) async {
      await _detail(tester, cta: RsvpCta.rsvpGoing, cancelled: true);
      expect(_cta(tester).state, DabblerRsvpCtaState.cancelled);
    });
  });

  group('detail: RSVP flow', () {
    testWidgets('Join meetup calls going', (tester) async {
      final repo = await _detail(tester, cta: RsvpCta.rsvpGoing);
      await tester.tap(find.text('Join meetup'));
      await settle(tester);
      expect(repo.rsvpCalls, [('m1', RsvpAction.going)]);
    });

    testWidgets('Request to join calls request', (tester) async {
      final repo = await _detail(tester, cta: RsvpCta.request);
      await tester.tap(find.text('Request to join'));
      await settle(tester);
      expect(repo.rsvpCalls, [('m1', RsvpAction.request)]);
    });

    testWidgets('full calls interested', (tester) async {
      final repo = await _detail(tester, cta: RsvpCta.rsvpGoing, capacity: 24);
      await tester.tap(find.text("Full - you're interested"));
      await settle(tester);
      expect(repo.rsvpCalls, [('m1', RsvpAction.interested)]);
    });

    testWidgets('going opens the sheet; No then Confirm cancels', (
      tester,
    ) async {
      final repo = await _detail(tester, cta: RsvpCta.already, my: 'going');
      await tester.tap(find.byType(DabblerRsvpCta));
      await settle(tester);
      expect(find.text('Are you going to this meetup?'), findsOneWidget);
      await tester.tap(find.text('No, not this time'));
      await tester.pump();
      await tester.tap(find.text('Confirm'));
      await settle(tester);
      expect(repo.rsvpCalls, [('m1', RsvpAction.cancel)]);
    });

    testWidgets('sheet Maybe sends interested', (tester) async {
      final repo = await _detail(tester, cta: RsvpCta.already, my: 'going');
      await tester.tap(find.byType(DabblerRsvpCta));
      await settle(tester);
      await tester.tap(find.text('Maybe'));
      await tester.pump();
      await tester.tap(find.text('Confirm'));
      await settle(tester);
      expect(repo.rsvpCalls, [('m1', RsvpAction.interested)]);
    });

    testWidgets('inert states do not call the repository', (tester) async {
      final repo = await _detail(tester, cta: RsvpCta.closed);
      await tester.tap(find.byType(DabblerRsvpCta));
      await settle(tester);
      expect(repo.rsvpCalls, isEmpty);
    });

    testWidgets('not allowed opens the profile switch', (tester) async {
      var n = 0;
      final repo = await _detail(
        tester,
        cta: RsvpCta.notAllowed,
        onSwitch: () => n++,
      );
      await tester.tap(find.byType(DabblerRsvpCta));
      await settle(tester);
      expect(n, 1);
      expect(repo.rsvpCalls, isEmpty);
    });

    testWidgets('a failed RSVP shows an error toast', (tester) async {
      final repo = await _detail(tester, cta: RsvpCta.rsvpGoing);
      repo.rsvpFailure = const Failure(code: 'meetup_cancelled');
      await tester.tap(find.text('Join meetup'));
      await settle(tester);
      expect(find.text('This meetup was cancelled.'), findsOneWidget);
    });
  });

  group('listing', () {
    for (final locale in _locales) {
      final tag = locale.languageCode;
      testWidgets('cards ($tag)', (tester) async {
        final repo = FakeMeetupRepository()
          ..list = [
            meetupRow('a', title: 'Sunrise run'),
            meetupRow(
              'b',
              title: 'Hatta trail hike',
              policy: RsvpPolicy.request,
            ),
          ];
        await pumpMeetups(tester, const MeetupsScreen(), repo, locale: locale);
        expect(find.text('Sunrise run'), findsOneWidget);
        expect(find.byType(DabblerCardGame), findsWidgets);
        expect(find.byType(DabblerRsvpCta), findsWidgets);
      });

      testWidgets('empty ($tag)', (tester) async {
        await pumpMeetups(
          tester,
          const MeetupsScreen(),
          FakeMeetupRepository(),
          locale: locale,
        );
        // The test font (Ahem) is wider than the real one, so the long
        // button label overflows here; the assertion is on the content.
        tester.takeException();
        expect(find.text('No meetups available.'), findsOneWidget);
        expect(find.text('Explore another activity'), findsOneWidget);
      });

      testWidgets('one upcoming is a CardUpcoming ($tag)', (tester) async {
        final repo = FakeMeetupRepository()
          ..list = [meetupRow('a', my: 'going', title: 'Mine')];
        await pumpMeetups(tester, const MeetupsScreen(), repo, locale: locale);
        expect(find.byType(DabblerCardUpcoming), findsOneWidget);
        expect(find.byType(DabblerCardUpcomingRail), findsNothing);
      });

      testWidgets('several upcoming are a rail ($tag)', (tester) async {
        final repo = FakeMeetupRepository()
          ..list = [
            meetupRow('a', my: 'going', title: 'Mine one'),
            meetupRow('b', my: 'interested', title: 'Mine two'),
          ];
        await pumpMeetups(tester, const MeetupsScreen(), repo, locale: locale);
        expect(find.byType(DabblerCardUpcomingRail), findsNWidgets(2));
        expect(find.byType(DabblerCardUpcoming), findsNothing);
      });
    }

    testWidgets('tabs come from the sports provider', (tester) async {
      await pumpMeetups(
        tester,
        const MeetupsScreen(),
        FakeMeetupRepository()..list = [meetupRow('a')],
      );
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Running'), findsWidgets);
      expect(find.text('Yoga'), findsOneWidget);
    });

    testWidgets('loading shows skeletons', (tester) async {
      final repo = FakeMeetupRepository()
        ..list = [meetupRow('a')]
        ..listGate = Completer<void>();
      await pumpMeetups(tester, const MeetupsScreen(), repo);
      expect(find.byType(DabblerSkeleton), findsWidgets);
      repo.listGate!.complete();
      await settle(tester);
    });

    testWidgets('error shows retry', (tester) async {
      final repo = FakeMeetupRepository()..listError = 'boom';
      await pumpMeetups(tester, const MeetupsScreen(), repo);
      expect(find.text("Couldn't load meetups"), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('Join meetup on a card calls going', (tester) async {
      final repo = FakeMeetupRepository()..list = [meetupRow('a')];
      await pumpMeetups(tester, const MeetupsScreen(), repo);
      await tester.tap(find.text('Join meetup'));
      await settle(tester);
      expect(repo.rsvpCalls, [('a', RsvpAction.going)]);
    });

    testWidgets('a full card shows Full and a tap marks interested', (
      tester,
    ) async {
      final repo = FakeMeetupRepository()
        ..list = [meetupRow('a', capacity: 24, going: 24)];
      await pumpMeetups(tester, const MeetupsScreen(), repo);
      expect(find.text('Full'), findsWidgets);
      await tester.tap(find.text("Full - you're interested"));
      await settle(tester);
      expect(repo.rsvpCalls, [('a', RsvpAction.interested)]);
    });
  });
}
