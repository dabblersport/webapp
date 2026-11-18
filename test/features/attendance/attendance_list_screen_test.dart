// KAN-999 (G-05): every attendance-list state, EN and AR: during the window
// (read-only), after the window (correct with a required reason), editing a
// row, finalized (no-shows pending review), auto-finalized; a refusal never
// shows success; a double tap sends one call; a non-organiser sees no list
// and no actions.

import 'dart:async';

import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/features/attendance/domain/attendance_list_models.dart';
import 'package:dabbler/features/attendance/presentation/attendance_list_entry.dart';
import 'package:dabbler/features/attendance/presentation/attendance_list_screen.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'attendance_review_fakes.dart';

AttendanceList _list(List<AttendanceRow> rows, {bool windowOpen = false}) =>
    AttendanceList(
      rows: rows,
      closesAt: windowOpen
          ? kNow.add(const Duration(minutes: 10))
          : kNow.subtract(const Duration(hours: 1)),
    );

List<AttendanceRow> _roster() => <AttendanceRow>[
  row('a', name: 'Sara', checkedInAt: kNow.subtract(const Duration(hours: 2))),
  row('b', name: 'عمر'),
  row('c', name: 'Lina', mark: 'no_show', method: 'organiser', reason: 'Left'),
];

Widget _screen() =>
    const AttendanceListScreen(eventId: 'e1', title: 'Padel', onBack: _noop);
void _noop() {}

Finder _key(String k) => find.byKey(ValueKey<String>(k));

void main() {
  for (final locale in kLocales) {
    final l = lookupAppLocalizations(locale);
    final tag = locale.languageCode;

    testWidgets('[$tag] during the window: chips, read-only, no Finalize', (
      tester,
    ) async {
      final repo = FakeReviewRepo(
        listResult: Ok(_list(_roster(), windowOpen: true)),
      );
      await pumpAttendance(tester, repo, _screen(), locale: locale);
      expect(_key('attendance-phase-duringWindow'), findsOneWidget);
      expect(_key('attendance-chip-a-checkedIn'), findsOneWidget);
      expect(_key('attendance-chip-b-notCheckedIn'), findsOneWidget);
      expect(_key('attendance-chip-c-correctedNoShow'), findsOneWidget);
      expect(find.text(l.g05_status_checked_in), findsOneWidget);
      expect(find.text(l.g05_status_not), findsOneWidget);
      expect(find.text(l.g05_status_corrected_no_show), findsOneWidget);
      expect(_key('attendance-finalize'), findsNothing);
      await tester.tap(_key('attendance-row-b'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(_key('attendance-reason'), findsNothing);
      expect(repo.calls, isEmpty);
    });

    testWidgets('[$tag] after the window: edit a row needs a reason', (
      tester,
    ) async {
      final repo = FakeReviewRepo(listResult: Ok(_list(_roster())));
      await pumpAttendance(tester, repo, _screen(), locale: locale);
      expect(_key('attendance-phase-afterWindow'), findsOneWidget);
      expect(find.text(l.g05_after_window), findsOneWidget);
      expect(_key('attendance-finalize'), findsOneWidget);

      await tester.tap(_key('attendance-row-b'));
      await tester.pumpAndSettle();
      // Editing a row.
      expect(find.text(l.g05_edit_title), findsOneWidget);
      expect(find.text(l.g05_mark_attended), findsOneWidget);
      expect(find.text(l.g05_mark_no_show), findsOneWidget);
      expect(find.text(l.g05_reason_hint), findsOneWidget);

      await tester.tap(_key('attendance-save'));
      await tester.pumpAndSettle();
      expect(find.text(l.g05_reason_required), findsOneWidget);
      expect(repo.calls, isEmpty);

      await tester.enterText(
        find.descendant(
          of: _key('attendance-reason'),
          matching: find.byType(EditableText),
        ),
        'Arrived late',
      );
      await tester.tap(_key('attendance-save'));
      await tester.pumpAndSettle();
      expect(repo.calls, <String>['correct:b:attended:Arrived late']);
      expect(_key('attendance-reason'), findsNothing);
      expect(find.text(l.g05_saved), findsOneWidget);
      await tester.pump(const Duration(seconds: 10));
    });

    testWidgets('[$tag] a refused correction never shows success', (
      tester,
    ) async {
      final repo = FakeReviewRepo(listResult: Ok(_list(_roster())))
        ..correctFailure = const Failure(code: 'attendance_finalized');
      await pumpAttendance(tester, repo, _screen(), locale: locale);
      await tester.tap(_key('attendance-row-b'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: _key('attendance-reason'),
          matching: find.byType(EditableText),
        ),
        'x',
      );
      await tester.tap(_key('attendance-save'));
      await tester.pumpAndSettle();
      expect(repo.calls, hasLength(1));
      expect(find.text(l.g05_err_finalized), findsOneWidget);
      expect(find.text(l.g05_saved), findsNothing);
      expect(_key('attendance-reason'), findsOneWidget);
    });

    testWidgets('[$tag] Finalize: a double tap sends one call', (tester) async {
      final repo = FakeReviewRepo(listResult: Ok(_list(_roster())))
        ..gate = Completer<void>();
      await pumpAttendance(tester, repo, _screen(), locale: locale);
      await tester.tap(_key('attendance-finalize'));
      await tester.pump();
      await tester.tap(_key('attendance-finalize'), warnIfMissed: false);
      await tester.pump();
      expect(repo.calls, <String>['finalize']);
      repo.listResult = Ok(
        _list(<AttendanceRow>[
          row('a', outcome: 'attended', finalized: true),
          row('b', outcome: 'no_show_pending', finalized: true),
        ]),
      );
      repo.gate!.complete();
      await tester.pumpAndSettle();
      expect(find.text(l.g05_finalized_toast), findsOneWidget);
      expect(_key('attendance-phase-finalized'), findsOneWidget);
      expect(_key('attendance-finalize'), findsNothing);
      await tester.pump(const Duration(seconds: 10));
    });

    testWidgets('[$tag] a refused Finalize never shows success', (
      tester,
    ) async {
      final repo = FakeReviewRepo(listResult: Ok(_list(_roster())))
        ..finalizeFailure = const Failure(code: 'window_not_closed');
      await pumpAttendance(tester, repo, _screen(), locale: locale);
      await tester.tap(_key('attendance-finalize'));
      await tester.pumpAndSettle();
      expect(find.text(l.g05_err_window_not_closed), findsOneWidget);
      expect(find.text(l.g05_finalized_toast), findsNothing);
      expect(_key('attendance-phase-afterWindow'), findsOneWidget);
      await tester.pump(const Duration(seconds: 10));
    });

    testWidgets('[$tag] finalized: no-shows pending review, locked', (
      tester,
    ) async {
      final repo = FakeReviewRepo(
        listResult: Ok(
          _list(<AttendanceRow>[
            row('a', outcome: 'attended', finalized: true),
            row('b', outcome: 'no_show_pending', finalized: true),
            row('c', outcome: 'no_show_confirmed', finalized: true),
          ]),
        ),
      );
      await pumpAttendance(tester, repo, _screen(), locale: locale);
      expect(find.text(l.g05_finalized), findsOneWidget);
      expect(_key('attendance-chip-b-pendingReview'), findsOneWidget);
      expect(find.text(l.g05_status_pending_review), findsOneWidget);
      expect(find.text(l.g05_status_no_show_confirmed), findsOneWidget);
      expect(_key('attendance-finalize'), findsNothing);
      await tester.tap(_key('attendance-row-b'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(_key('attendance-reason'), findsNothing);
    });

    testWidgets('[$tag] auto-finalized: nobody no-show, shown as such', (
      tester,
    ) async {
      final repo = FakeReviewRepo(
        listResult: Ok(
          _list(<AttendanceRow>[
            row('a', outcome: 'attended', finalized: true),
            row('b', outcome: 'unknown', finalized: true),
          ]),
        ),
      );
      await pumpAttendance(tester, repo, _screen(), locale: locale);
      expect(find.text(l.g05_auto_finalized), findsOneWidget);
      expect(find.text(l.g05_status_not_recorded), findsOneWidget);
    });

    testWidgets('[$tag] a non-organiser sees no list and no actions', (
      tester,
    ) async {
      final repo = FakeReviewRepo(
        listResult: const Err(Failure(code: 'not_organiser')),
      );
      await pumpAttendance(tester, repo, _screen(), locale: locale);
      expect(_key('attendance-not-organiser'), findsOneWidget);
      expect(find.text(l.g05_not_organiser), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('attendance-row-a')),
        findsNothing,
      );
      expect(_key('attendance-finalize'), findsNothing);
      expect(find.text(l.g06_accept), findsNothing);
    });

    testWidgets('[$tag] the entry shows only for the organiser', (
      tester,
    ) async {
      await pumpAttendance(
        tester,
        FakeReviewRepo(),
        const Column(
          children: <Widget>[AttendanceListEntry(eventId: 'e1', show: false)],
        ),
        locale: locale,
      );
      expect(_key('attendance-list-entry'), findsNothing);
      await pumpAttendance(
        tester,
        FakeReviewRepo(),
        const Column(children: <Widget>[AttendanceListEntry(eventId: 'e1')]),
        locale: locale,
      );
      expect(_key('attendance-list-entry'), findsOneWidget);
      expect(find.text(l.g05_title), findsOneWidget);
    });
  }
}
