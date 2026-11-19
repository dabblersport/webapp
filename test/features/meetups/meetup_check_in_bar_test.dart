// The meetup detail's bottom bar follows the player's check-in (EN and AR):
// before the window the RSVP button; open: "Check in" with "Can't make it" as
// a text action opening the RSVP sheet; checked in or closed: no way out.
// The host's bar is unchanged.

import 'package:dabbler/features/attendance/domain/check_in_models.dart';
import 'package:dabbler/features/meetups/domain/models/meetup_enums.dart';
import 'package:dabbler/features/meetups/domain/models/meetup_models.dart';
import 'package:dabbler/features/meetups/presentation/screens/meetup_detail_screen.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../attendance/attendance_fakes.dart';
import 'meetup_screens_harness.dart';

const _going = MeetupCard(id: 'm1', title: 'Run', myStatus: 'going');

Future<void> _pump(
  WidgetTester t,
  Locale locale,
  CheckInPhase phase, {
  MeetupCard card = _going,
  DateTime? checkedInAt,
}) async {
  await pumpMeetups(
    t,
    MeetupDetailScreen(meetupId: 'm1', onBack: () {}),
    FakeMeetupRepository()
      ..card = card
      ..eligibility = const RsvpEligibility(
        allowed: true,
        cta: RsvpCta.already,
      ),
    locale: locale,
    overrides: [checkInPhaseOverride(phase, checkedInAt: checkedInAt)],
    // Wide: the test font draws every glyph a full em, so a bar label that
    // fits a phone in the real face overflows one here.
    size: const Size(1200, 900),
  );
}

Finder _inBar(Finder f) =>
    find.descendant(of: find.byType(DabblerActionBar), matching: f);

const _cta = ValueKey<String>('check-in-cta');
const _leave = ValueKey<String>('check-in-leave');

void main() {
  for (final locale in const [Locale('en'), Locale('ar')]) {
    final l = lookupAppLocalizations(locale);
    final tag = locale.languageCode;

    for (final phase in const [
      CheckInPhase.beforeWindow,
      CheckInPhase.notEligible,
    ]) {
      testWidgets('[$tag] ${phase.name}: the RSVP button, as today', (t) async {
        await _pump(t, locale, phase);
        expect(_inBar(find.byType(DabblerRsvpCta)), findsOneWidget);
        expect(find.byKey(_cta), findsNothing);
        await t.pumpWidget(const SizedBox());
      });
    }

    testWidgets('[$tag] open: Check in, Can\'t make it as text', (t) async {
      await _pump(t, locale, CheckInPhase.open);
      expect(
        find.descendant(of: find.byKey(_cta), matching: find.text(l.g04_cta)),
        findsOneWidget,
      );
      expect(_inBar(find.byType(DabblerRsvpCta)), findsNothing);
      final leave = find.byKey(_leave);
      expect(
        find.descendant(of: leave, matching: find.text(l.meetups_cant_make_it)),
        findsOneWidget,
      );
      await t.tap(leave);
      await t.pumpAndSettle();
      expect(find.text(l.meetups_sheet_title), findsOneWidget);
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('[$tag] submitting: the check-in button is busy', (t) async {
      await _pump(t, locale, CheckInPhase.submitting);
      expect(find.byKey(_cta), findsOneWidget);
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('[$tag] checked in: informational, no way out', (t) async {
      await _pump(
        t,
        locale,
        CheckInPhase.checkedIn,
        checkedInAt: DateTime(2026, 11, 19, 18, 5),
      );
      expect(find.byKey(_cta), findsNothing);
      expect(find.byKey(_leave), findsNothing);
      expect(_inBar(find.byType(DabblerRsvpCta)), findsNothing);
      expect(
        _inBar(find.textContaining(l.g04_checked_in_at('').trim())),
        findsOneWidget,
      );
      await t.pumpWidget(const SizedBox());
    });

    for (final phase in const [CheckInPhase.closed, CheckInPhase.cancelled]) {
      testWidgets('[$tag] ${phase.name}: no check-in, no way out', (t) async {
        await _pump(t, locale, phase);
        expect(find.byKey(_cta), findsNothing);
        expect(_inBar(find.byType(DabblerRsvpCta)), findsNothing);
        expect(
          _inBar(
            find.text(
              phase == CheckInPhase.closed ? l.g04_closed : l.g04_cancelled,
            ),
          ),
          findsOneWidget,
        );
        await t.pumpWidget(const SizedBox());
      });
    }

    testWidgets('[$tag] the host: the RSVP bar, unchanged', (t) async {
      await _pump(
        t,
        locale,
        CheckInPhase.open,
        card: const MeetupCard(
          id: 'm1',
          title: 'Run',
          myStatus: 'going',
          isHost: true,
        ),
      );
      expect(_inBar(find.byType(DabblerRsvpCta)), findsOneWidget);
      expect(find.byKey(_cta), findsNothing);
      await t.pumpWidget(const SizedBox());
    });
  }
}
