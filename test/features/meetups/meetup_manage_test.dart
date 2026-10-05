import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/features/meetups/domain/models/meetup_enums.dart';
import 'package:dabbler/features/meetups/domain/models/meetup_models.dart';
import 'package:dabbler/features/meetups/presentation/providers/meetup_user_lookup.dart';
import 'package:dabbler/features/meetups/presentation/screens/meetup_detail_screen.dart';
import 'package:dabbler/features/meetups/presentation/screens/meetup_edit_screen.dart';
import 'package:dabbler/features/meetups/presentation/screens/meetup_manage_screen.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'meetup_screens_harness.dart';

const _people = <MeetupAttendee>[
  MeetupAttendee(
    actorProfileId: 'p1',
    displayName: 'Lina Haddad',
    status: RsvpStatus.going,
  ),
  MeetupAttendee(
    actorProfileId: 'p2',
    displayName: 'Yousef Amer',
    status: RsvpStatus.interested,
  ),
  MeetupAttendee(
    actorProfileId: 'p3',
    displayName: 'Nadia Saleh',
    status: RsvpStatus.pending,
  ),
];

final _lookup = meetupUserIdLookupProvider.overrideWithValue(
  (String profileId) async => 'u-$profileId',
);

Future<FakeMeetupRepository> _manage(
  WidgetTester tester, {
  Locale locale = const Locale('en'),
  VoidCallback? onCancelled,
  Failure? failure,
}) async {
  final repo = FakeMeetupRepository()
    ..attendeeList = _people
    ..manageFailure = failure;
  await pumpMeetups(
    tester,
    MeetupManageScreen(
      meetupId: 'm1',
      onBack: () {},
      onEdit: () {},
      onCancelled: onCancelled,
    ),
    repo,
    locale: locale,
    overrides: <Override>[_lookup],
  );
  tester.takeException();
  return repo;
}

void main() {
  for (final locale in const <Locale>[Locale('en'), Locale('ar')]) {
    testWidgets('roster sections (${locale.languageCode})', (tester) async {
      await _manage(tester, locale: locale);
      expect(find.text('Lina Haddad'), findsOneWidget);
      expect(find.text('Yousef Amer'), findsOneWidget);
      expect(find.text('Nadia Saleh'), findsOneWidget);
      final ar = locale.languageCode == 'ar';
      expect(find.text(ar ? 'الطلبات' : 'Requests'), findsOneWidget);
      expect(find.text(ar ? 'قبول' : 'Approve'), findsOneWidget);
      expect(find.text(ar ? 'رفض' : 'Decline'), findsOneWidget);
      expect(find.text(ar ? 'إزالة' : 'Remove'), findsNWidgets(2));
    });
  }

  testWidgets('approve calls decide with the auth user id', (tester) async {
    final repo = await _manage(tester);
    await tester.tap(find.text('Approve'));
    await settle(tester);
    expect(repo.decideCalls, [('m1', 'u-p3', 'approve')]);
  });

  testWidgets('decline calls decide with decline', (tester) async {
    final repo = await _manage(tester);
    await tester.tap(find.text('Decline'));
    await settle(tester);
    expect(repo.decideCalls, [('m1', 'u-p3', 'decline')]);
  });

  testWidgets('remove asks first, then calls remove', (tester) async {
    final repo = await _manage(tester);
    await tester.tap(find.text('Remove').first);
    await settle(tester);
    expect(find.text('Remove Lina Haddad?'), findsOneWidget);
    expect(repo.removeCalls, isEmpty);
    await tester.tap(
      find.descendant(
        of: find.byType(DabblerDialog),
        matching: find.text('Remove'),
      ),
    );
    await settle(tester);
    expect(repo.removeCalls, [('m1', 'u-p1')]);
  });

  testWidgets('cancel asks first, then cancels and leaves', (tester) async {
    var left = 0;
    final repo = await _manage(tester, onCancelled: () => left++);
    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await tester.pump();
    await tester.tap(find.text('Cancel meetup'));
    await settle(tester);
    expect(find.text('Cancel this meet-up?'), findsOneWidget);
    expect(repo.cancelCalls, isEmpty);
    // Ahem is wide enough to push the dialog's button off screen, so the
    // action is invoked directly.
    tester
        .widget<DabblerDialog>(find.byType(DabblerDialog))
        .primaryAction!
        .onPressed
        ?.call();
    await settle(tester);
    await settle(tester);
    expect(repo.cancelCalls, ['m1']);
    expect(left, 1);
    tester.takeException();
  });

  testWidgets('keeping it does not cancel', (tester) async {
    final repo = await _manage(tester);
    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await tester.pump();
    await tester.tap(find.text('Cancel meetup'));
    await settle(tester);
    tester
        .widget<DabblerDialog>(find.byType(DabblerDialog))
        .secondaryAction!
        .onPressed
        ?.call();
    await settle(tester);
    expect(repo.cancelCalls, isEmpty);
    tester.takeException();
  });

  testWidgets('a server error is shown as a toast', (tester) async {
    await _manage(
      tester,
      failure: const Failure(code: 'not_host', message: 'not_host'),
    );
    await tester.tap(find.text('Approve'));
    await settle(tester);
    expect(find.text('Only the host can do this.'), findsOneWidget);
  });

  group('edit', () {
    MeetupCard card() => MeetupCard(
      id: 'm1',
      title: 'Sunrise run',
      description: 'Easy pace',
      startAt: DateTime(2030, 1, 15, 18),
      endAt: DateTime(2030, 1, 15, 19),
      locationName: 'Kite Beach',
      capacity: 40,
      counts: const MeetupCounts(going: 24),
      isHost: true,
    );

    Future<FakeMeetupRepository> pump(
      WidgetTester tester, {
      Failure? failure,
      VoidCallback? done,
    }) async {
      final repo = FakeMeetupRepository()
        ..card = card()
        ..manageFailure = failure;
      await pumpMeetups(
        tester,
        MeetupEditScreen(meetupId: 'm1', onDone: done),
        repo,
      );
      tester.takeException();
      return repo;
    }

    testWidgets('prefilled; an unchanged save sends nothing but the id', (
      tester,
    ) async {
      var done = 0;
      final repo = await pump(tester, done: () => done++);
      expect(find.text('Kite Beach'), findsOneWidget);
      await tester.tap(find.byType(DabblerButton).last);
      await settle(tester);
      expect(repo.updateCalls, hasLength(1));
      final u = repo.updateCalls.single;
      expect(u.meetupId, 'm1');
      expect(u.title, isNull);
      expect(u.capacity, isNull);
      expect(done, 1);
    });

    testWidgets('a changed title is the only field sent', (tester) async {
      final repo = await pump(tester, done: () {});
      await tester.enterText(find.byType(EditableText).first, 'Sunset run');
      await tester.pump();
      await tester.tap(find.byType(DabblerButton).last);
      await settle(tester);
      final u = repo.updateCalls.single;
      expect(u.title, 'Sunset run');
      expect(u.description, isNull);
      expect(u.locationName, isNull);
      tester.takeException();
    });

    testWidgets('capacity_below_going_count is shown inline', (tester) async {
      await pump(
        tester,
        failure: const Failure(
          code: 'capacity_below_going_count',
          message: 'capacity_below_going_count',
        ),
      );
      await tester.tap(find.byType(DabblerButton).last);
      await settle(tester);
      expect(
        find.text('The capacity is lower than the number already going.'),
        findsOneWidget,
      );
    });
  });

  group('details entry', () {
    for (final host in <bool>[true, false]) {
      testWidgets('Manage meetup is ${host ? '' : 'not '}shown', (
        tester,
      ) async {
        final repo = FakeMeetupRepository()
          ..card = MeetupCard(
            id: 'm1',
            title: 'Sunrise run',
            startAt: DateTime.now().add(const Duration(days: 1)),
            isHost: host,
          )
          ..eligibility = const RsvpEligibility(
            allowed: true,
            cta: RsvpCta.rsvpGoing,
          );
        await pumpMeetups(
          tester,
          MeetupDetailScreen(meetupId: 'm1', onBack: () {}),
          repo,
        );
        expect(
          find.text('Manage meetup'),
          host ? findsOneWidget : findsNothing,
        );
      });
    }
  });
}
