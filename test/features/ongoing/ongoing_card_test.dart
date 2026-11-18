// KAN-1008 (W3-F1): the pinned ongoing card in EN and AR. Every state comes
// from a faked rpc_my_ongoing_events reply; the card leaves when the server
// stops returning the event (closed, cancelled, left, removed); overlapping
// activities follow orderOngoing and the rest are in the "+N more" sheet;
// tap opens the event and Check in opens the check-in screen; the list is
// read again at the next boundary, on resume and on an activity notice.

import 'package:dabbler/features/ongoing/domain/ongoing_models.dart';
import 'package:dabbler/features/ongoing/presentation/ongoing_card.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'ongoing_fakes.dart';

void main() {
  setUp(() => ocClock = DateTime(2026, 11, 18, 20, 5));

  for (final lang in ['en', 'ar']) {
    final l = lookupAppLocalizations(Locale(lang));
    String c(DateTime t) => ocClk(lang, t);

    group(lang, () {
      testWidgets('starting soon: countdown, start and scheduled until', (
        t,
      ) async {
        await ocPump(t, [ocRow()], locale: lang);
        expect(ocHas('Padel Night'), findsOneWidget);
        expect(ocHas(l.oc_starts_in(25)), findsOneWidget);
        expect(ocHas(l.g04_starts(c(ocStart))), findsOneWidget);
        expect(ocHas(l.lc_scheduled_until(c(ocEnd))), findsOneWidget);
        expect(ocKey('ongoing-check-in'), findsNothing);
        // The countdown redraws at the next minute without a server read.
        ocClock = ocClock.add(const Duration(minutes: 1));
        await t.pump(const Duration(minutes: 1));
        expect(ocHas(l.oc_starts_in(24)), findsOneWidget);
      });

      testWidgets('times follow the 24-hour setting', (t) async {
        await ocPump(t, [ocRow()], locale: lang, h24: true);
        expect(
          ocHas(l.lc_scheduled_until(ocClk(lang, ocEnd, h24: true))),
          findsOneWidget,
        );
      });

      testWidgets('check-in open: Check in opens the check-in screen', (
        t,
      ) async {
        await ocPump(t, [ocRow(checkIn: 'open')], locale: lang);
        expect(ocKey('ongoing-check-in'), findsOneWidget);
        expect(ocHas(l.g04_cta), findsOneWidget);
        await t.tap(ocKey('ongoing-check-in'));
        await t.pumpAndSettle();
        expect(find.text('route:check-in:e1'), findsOneWidget);
      });

      testWidgets('checked in', (t) async {
        await ocPump(t, [ocRow(checkIn: 'checked_in')], locale: lang);
        expect(ocHas(l.g04_checked_in), findsOneWidget);
        expect(ocKey('ongoing-check-in'), findsNothing);
      });

      testWidgets('scheduled time running', (t) async {
        ocClock = DateTime(2026, 11, 18, 20, 40);
        await ocPump(t, [ocRow()], locale: lang);
        expect(ocHas(l.oc_time_running), findsOneWidget);
        expect(ocHas(l.lc_scheduled_until(c(ocEnd))), findsOneWidget);
      });

      testWidgets('started at', (t) async {
        ocClock = DateTime(2026, 11, 18, 20, 40);
        final at = DateTime(2026, 11, 18, 20, 32);
        await ocPump(t, [ocRow(state: 'started', startedAt: at)], locale: lang);
        expect(ocHas(l.lc_started_at(c(at))), findsOneWidget);
      });

      testWidgets('changed: old → new', (t) async {
        final old = DateTime(2026, 11, 18, 20);
        await ocPump(t, [ocRow(previousStart: old)], locale: lang);
        String iso(String x) => lang == 'ar' ? '\u2068$x\u2069' : x;
        expect(
          ocHas(l.oc_changed(iso(c(old)), iso(c(ocStart)))),
          findsOneWidget,
        );
      });

      testWidgets('changed: end only', (t) async {
        final oldEnd = DateTime(2026, 11, 18, 21);
        await ocPump(t, [ocRow(previousEnd: oldEnd)], locale: lang);
        String iso(String x) => lang == 'ar' ? '\u2068$x\u2069' : x;
        expect(
          ocHas(l.oc_changed(iso(c(oldEnd)), iso(c(ocEnd)))),
          findsOneWidget,
        );
      });

      testWidgets('changed across midnight shows the date', (t) async {
        final start = DateTime(2026, 11, 19, 0, 30);
        final old = DateTime(2026, 11, 18, 23, 30);
        await ocPump(t, [
          ocRow(
            start: start,
            end: DateTime(2026, 11, 19, 1, 30),
            previousStart: old,
          ),
        ], locale: lang);
        String d(DateTime x) =>
            '${DabblerType.toWesternDigits(DateFormat.MMMd(lang).format(x))} ${c(x)}';
        final iso = lang == 'ar'
            ? (String x) => '\u2068$x\u2069'
            : (String x) => x;
        expect(ocHas(l.oc_changed(iso(d(old)), iso(d(start)))), findsOneWidget);
      });

      testWidgets('scheduled time ended, waiting for the organiser', (t) async {
        ocClock = DateTime(2026, 11, 18, 21, 40);
        await ocPump(t, [ocRow(state: 'awaiting_confirmation')], locale: lang);
        expect(ocHas(l.lc_time_ended), findsOneWidget);
        expect(ocHas(l.lc_awaiting_body_guest), findsOneWidget);
      });

      for (final (state, text) in [
        // No time: the RPC has no actual end.
        ('confirmed', () => l.oc_ended),
        ('did_not_happen', () => l.lc_did_not_happen),
        ('auto_closed', () => l.lc_time_ended),
      ]) {
        testWidgets('ended: $state, then gone when the server drops it', (
          t,
        ) async {
          ocClock = DateTime(2026, 11, 18, 22);
          final (repo, _) = await ocPump(t, [
            ocRow(state: state),
          ], locale: lang);
          expect(ocHas(text()), findsOneWidget);
          repo.rows = [];
          t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
          t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
          await t.pump();
          await t.pump();
          expect(ocKey('ongoing-card-e1'), findsNothing);
        });
      }

      testWidgets('cancelled, then gone when the server drops it', (t) async {
        final (repo, _) = await ocPump(t, [
          ocRow(cancelled: true, checkIn: 'cancelled'),
        ], locale: lang);
        expect(ocHas(l.lc_cancelled), findsOneWidget);
        expect(ocKey('ongoing-check-in'), findsNothing);
        repo.rows = [];
        t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        await t.pump();
        await t.pump();
        expect(ocKey('ongoing-card-e1'), findsNothing);
      });

      testWidgets('left or removed: the server returns nothing', (t) async {
        await ocPump(t, [], locale: lang);
        expect(find.byType(OngoingCard), findsNothing);
      });

      testWidgets('organiser: own variant, no Check in', (t) async {
        await ocPump(t, [
          ocRow(organiser: true, checkIn: 'open'),
        ], locale: lang);
        expect(ocHas(l.oc_organiser), findsOneWidget);
        expect(ocKey('ongoing-check-in'), findsNothing);
      });

      testWidgets('tap opens the game, and a meetup opens the meetup', (
        t,
      ) async {
        await ocPump(t, [ocRow()], locale: lang);
        await t.tap(ocKey('ongoing-card-e1'));
        await t.pumpAndSettle();
        expect(find.text('route:sports:e1'), findsOneWidget);

        await ocPump(t, [ocRow(id: 'm1', kind: 'meetup')], locale: lang);
        expect(ocHas(l.oc_meetup), findsOneWidget);
        await t.tap(ocKey('ongoing-card-m1'));
        await t.pumpAndSettle();
        expect(find.text('route:meetups:m1'), findsOneWidget);
      });

      testWidgets('overlap: earliest start shown, the other in "+1 more"', (
        t,
      ) async {
        await ocPump(t, [
          ocRow(id: 'late', title: 'Late Game', start: ocEnd),
          ocRow(id: 'early', title: 'Early Game'),
        ], locale: lang);
        expect(ocKey('ongoing-card-early'), findsOneWidget);
        expect(ocHas(l.oc_more(1)), findsOneWidget);
        await t.tap(ocKey('ongoing-more'));
        await t.pumpAndSettle();
        expect(ocHas(l.oc_sheet_title), findsOneWidget);
        expect(ocKey('ongoing-row-late'), findsOneWidget);
        await t.tap(ocKey('ongoing-row-late'));
        await t.pumpAndSettle();
        expect(find.text('route:sports:late'), findsOneWidget);
      });
    });
  }

  test('ordering: active, then awaiting confirmation, then closed', () {
    OngoingEvent e(
      String id,
      DateTime s, {
      bool cancelled = false,
      String state = 'scheduled',
      String checkIn = 'before_window',
    }) => OngoingEvent.tryParse(
      ocRow(
        id: id,
        start: s,
        cancelled: cancelled,
        state: state,
        checkIn: checkIn,
      ),
    )!;
    final early = DateTime(2026, 11, 18, 19);
    final ordered = orderOngoing([
      e('b', ocStart),
      e('x', early, cancelled: true),
      e('over', early, state: 'awaiting_confirmation'),
      e('done', early, state: 'confirmed'),
      e('a', ocStart),
      e('open', DateTime(2026, 11, 18, 20, 10), checkIn: 'open'),
    ], ocClock);
    expect(ordered.map((o) => o.eventId), [
      'open',
      'a',
      'b',
      'over',
      'done',
      'x',
    ]);
  });

  testWidgets('AR: the changed times are bidi-isolated', (t) async {
    final old = DateTime(2026, 11, 18, 20);
    await ocPump(t, [ocRow(previousStart: old)], locale: 'ar');
    final l = lookupAppLocalizations(const Locale('ar'));
    expect(
      ocHas(
        l.oc_changed(
          '\u2068${ocClk('ar', old)}\u2069',
          '\u2068${ocClk('ar', ocStart)}\u2069',
        ),
      ),
      findsOneWidget,
    );
  });

  testWidgets('"+N more": a check-in-open row has Check in', (t) async {
    ocClock = DateTime(2026, 11, 18, 20, 20);
    await ocPump(t, [
      ocRow(
        id: 'first',
        start: DateTime(2026, 11, 18, 20, 10),
        checkIn: 'open',
      ),
      ocRow(id: 'second', checkIn: 'open'),
    ]);
    await t.tap(ocKey('ongoing-more'));
    await t.pumpAndSettle();
    await t.tap(ocKey('ongoing-row-check-in-second'));
    await t.pumpAndSettle();
    expect(find.text('route:check-in:second'), findsOneWidget);
  });
}
