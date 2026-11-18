// KAN-999 (G-06): every no-show review state, EN and AR. Player: pending with
// the countdown, Request review (sheet, optional note) -> review requested,
// accepted, kept, 48h passed (confirmed), unanswered review accepted,
// auto-finalized. Organiser: the review card with the note, Accept correction
// / Keep and their result. A refusal never shows success; a double tap sends
// one call; a non-organiser gets no review actions.

import 'dart:async';

import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/features/attendance/domain/attendance_list_models.dart';
import 'package:dabbler/features/attendance/presentation/attendance_list_screen.dart';
import 'package:dabbler/features/attendance/presentation/no_show_screen.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'attendance_review_fakes.dart';

Finder _key(String k) => find.byKey(ValueKey<String>(k));
void _noop() {}

NoShowStatus _status(NoShowPhase p) => NoShowStatus(
  phase: p,
  reason: 'Did not show up',
  noShowDeadline: kNow.add(const Duration(hours: 46, minutes: 30)),
  reviewDeadline: kNow.add(const Duration(hours: 20)),
);

const Widget _player = NoShowScreen(
  eventId: 'e1',
  title: 'Padel',
  onBack: _noop,
);
const Widget _organiser = AttendanceListScreen(
  eventId: 'e1',
  title: 'Padel',
  onBack: _noop,
);

AttendanceList _reviewList() => AttendanceList(
  closesAt: kNow.subtract(const Duration(hours: 5)),
  rows: <AttendanceRow>[
    row('a', outcome: 'attended', finalized: true),
    row(
      's',
      name: 'Sara',
      outcome: 'no_show_review',
      note: 'I was there, phone died',
      reviewDeadline: kNow.add(const Duration(hours: 30)),
      finalized: true,
    ),
  ],
);

void main() {
  test('server answers map to the G-06 phases', () {
    NoShowPhase p(String? o, [String? d]) =>
        NoShowStatus.fromJson({'outcome': o, 'review_decision': d}).phase;
    expect(p('no_show_pending'), NoShowPhase.pending);
    expect(p('no_show_review'), NoShowPhase.reviewRequested);
    expect(p('attended', 'accepted'), NoShowPhase.accepted);
    expect(p('attended', 'expired_accepted'), NoShowPhase.expiredAccepted);
    expect(p('no_show_confirmed', 'kept'), NoShowPhase.kept);
    expect(p('no_show_confirmed'), NoShowPhase.confirmed);
    expect(p('unknown'), NoShowPhase.notRecorded);
    expect(p(null), NoShowPhase.none);
    expect(
      hoursLeft(kNow.add(const Duration(hours: 46, minutes: 1)), kNow),
      47,
    );
    expect(hoursLeft(kNow.subtract(const Duration(minutes: 1)), kNow), 0);
  });

  for (final locale in kLocales) {
    final l = lookupAppLocalizations(locale);
    final tag = locale.languageCode;

    testWidgets('[$tag] pending: countdown, Request review -> requested', (
      tester,
    ) async {
      final repo = FakeReviewRepo(noShow: _status(NoShowPhase.pending));
      await pumpAttendance(tester, repo, _player, locale: locale);
      expect(_key('no-show-pending'), findsOneWidget);
      expect(
        find.textContaining(l.g06_marked, findRichText: true),
        findsOneWidget,
      );
      expect(find.text(l.g06_confirms_in(47)), findsOneWidget);
      expect(find.textContaining('Did not show up'), findsOneWidget);

      await tester.tap(find.text(l.g06_request));
      await tester.pumpAndSettle();
      expect(find.text(l.g06_sheet_title), findsWidgets);
      expect(find.text(l.g06_note_optional), findsOneWidget);
      await tester.enterText(
        find.descendant(
          of: _key('review-note'),
          matching: find.byType(EditableText),
        ),
        'I was there',
      );
      await tester.tap(_key('review-send'));
      await tester.pumpAndSettle();
      expect(repo.calls, <String>['request:I was there']);
      expect(_key('review-send'), findsNothing);
      expect(_key('no-show-reviewRequested'), findsOneWidget);
      expect(find.text(l.g06_requested_body(48)), findsOneWidget);
      await tester.pump(const Duration(seconds: 10));
    });

    testWidgets('[$tag] the note is optional; a double tap sends one call', (
      tester,
    ) async {
      final repo = FakeReviewRepo(noShow: _status(NoShowPhase.pending))
        ..gate = Completer<void>();
      await pumpAttendance(tester, repo, _player, locale: locale);
      await tester.tap(find.text(l.g06_request));
      await tester.pumpAndSettle();
      await tester.tap(_key('review-send'));
      await tester.pump();
      await tester.tap(_key('review-send'), warnIfMissed: false);
      await tester.pump();
      expect(repo.calls, <String>['request:']);
      repo.gate!.complete();
      await tester.pumpAndSettle();
      expect(_key('no-show-reviewRequested'), findsOneWidget);
      await tester.pump(const Duration(seconds: 10));
    });

    testWidgets('[$tag] a refused request never shows success', (tester) async {
      final repo = FakeReviewRepo(noShow: _status(NoShowPhase.pending))
        ..requestFailure = const Failure(code: 'network');
      await pumpAttendance(tester, repo, _player, locale: locale);
      await tester.tap(find.text(l.g06_request));
      await tester.pumpAndSettle();
      await tester.tap(_key('review-send'));
      await tester.pumpAndSettle();
      expect(find.text(l.g06_failed), findsOneWidget);
      expect(find.text(l.g06_requested), findsNothing);
      expect(_key('review-send'), findsOneWidget);
    });

    testWidgets('[$tag] 48h passed before the sweep: shown confirmed', (
      tester,
    ) async {
      final repo = FakeReviewRepo(
        noShow: NoShowStatus(
          phase: NoShowPhase.pending,
          noShowDeadline: kNow.subtract(const Duration(minutes: 5)),
        ),
      );
      await pumpAttendance(tester, repo, _player, locale: locale);
      expect(_key('no-show-confirmed'), findsOneWidget);
      expect(find.text(l.g06_request), findsNothing);
    });

    final outcomes = <NoShowPhase, String>{
      NoShowPhase.reviewRequested: l.g06_requested_body(20),
      NoShowPhase.accepted: l.g06_accepted_body,
      NoShowPhase.expiredAccepted: l.g06_expired_body,
      NoShowPhase.kept: l.g06_kept_body,
      NoShowPhase.confirmed: l.g06_confirmed_body,
      NoShowPhase.notRecorded: l.g06_not_recorded_body,
    };
    for (final e in outcomes.entries) {
      testWidgets('[$tag] ${e.key.name}: the outcome, no action', (
        tester,
      ) async {
        final repo = FakeReviewRepo(noShow: _status(e.key));
        await pumpAttendance(tester, repo, _player, locale: locale);
        expect(_key('no-show-${e.key.name}'), findsOneWidget);
        expect(find.text(e.value), findsOneWidget);
        expect(find.text(l.g06_request), findsNothing);
      });
    }

    testWidgets('[$tag] organiser: the review card, Accept correction', (
      tester,
    ) async {
      final repo = FakeReviewRepo(listResult: Ok(_reviewList()));
      await pumpAttendance(tester, repo, _organiser, locale: locale);
      expect(_key('attendance-review-s'), findsOneWidget);
      expect(
        find.textContaining(l.g06_review_verb, findRichText: true),
        findsWidgets,
      );
      expect(find.textContaining('phone died'), findsOneWidget);
      expect(find.text(l.g06_review_due(30)), findsOneWidget);
      expect(_key('attendance-chip-s-reviewRequested'), findsOneWidget);

      repo.listResult = Ok(
        AttendanceList(
          closesAt: kNow.subtract(const Duration(hours: 5)),
          rows: <AttendanceRow>[
            row('s', name: 'Sara', outcome: 'attended', finalized: true),
          ],
        ),
      );
      await tester.tap(find.text(l.g06_accept));
      await tester.pumpAndSettle();
      expect(repo.calls, <String>['decide:s:accept']);
      final head = l.g06_accepted_result('|').split('|').first.trim();
      expect(find.textContaining(head), findsOneWidget);
      expect(find.text(l.g06_accept), findsNothing);
      expect(_key('attendance-chip-s-attended'), findsOneWidget);
    });

    testWidgets('[$tag] organiser: Keep; a double tap sends one call', (
      tester,
    ) async {
      final repo = FakeReviewRepo(listResult: Ok(_reviewList()))
        ..gate = Completer<void>();
      await pumpAttendance(tester, repo, _organiser, locale: locale);
      await tester.tap(find.text(l.g06_keep));
      await tester.pump();
      expect(find.text(l.g06_sending), findsOneWidget);
      expect(find.text(l.g06_keep), findsNothing);
      repo.gate!.complete();
      await tester.pumpAndSettle();
      expect(repo.calls, <String>['decide:s:keep']);
      expect(find.text(l.g06_accept), findsNothing);
    });

    testWidgets('[$tag] organiser: a refused decision shows no result', (
      tester,
    ) async {
      final repo = FakeReviewRepo(listResult: Ok(_reviewList()))
        ..decideFailure = const Failure(code: 'no_open_review');
      await pumpAttendance(tester, repo, _organiser, locale: locale);
      await tester.tap(find.text(l.g06_accept));
      await tester.pumpAndSettle();
      expect(repo.calls, hasLength(1));
      // Already decided elsewhere: said so, and the list is read again.
      expect(find.text(l.g06_err_already_decided), findsOneWidget);
      expect(repo.listCalls, 2);
      expect(find.text(l.g06_accept), findsOneWidget);
      await tester.pump(const Duration(seconds: 10));
    });

    testWidgets('[$tag] a non-organiser gets no review card or actions', (
      tester,
    ) async {
      final repo = FakeReviewRepo(
        listResult: const Err(Failure(code: 'not_organiser')),
      );
      await pumpAttendance(tester, repo, _organiser, locale: locale);
      expect(_key('attendance-review-s'), findsNothing);
      expect(find.text(l.g06_accept), findsNothing);
      expect(find.text(l.g06_keep), findsNothing);
    });
  }
}
