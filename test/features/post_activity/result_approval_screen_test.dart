// KAN-1000 (G-03): every state of the organiser's result approval and the
// final score screen, EN and AR.

import 'dart:async';

import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/features/post_activity/domain/post_activity_models.dart';
import 'package:dabbler/features/post_activity/presentation/final_score_screen.dart';
import 'package:dabbler/features/post_activity/presentation/post_activity_steps.dart';
import 'package:dabbler/features/post_activity/presentation/result_approval_screen.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'post_activity_fakes.dart';

ResultTally _t(
  ResultState state, {
  Score? provisional,
  Score? finalScore,
  bool organiser = true,
}) => ResultTally(
  competitive: true,
  state: state,
  deadlineAt: kNow.add(const Duration(hours: 23)),
  provisional: provisional,
  votes: provisional == null ? 1 : 6,
  submissions: provisional == null ? 2 : 8,
  eligible: 8,
  spread: [
    if (provisional != null) const Score(4, 3, votes: 6),
    const Score(3, 3, votes: 1),
    const Score(5, 3, votes: 1),
  ],
  finalScore: finalScore,
  isOrganiser: organiser,
);

Finder _k(String k) => find.byKey(ValueKey<String>(k));

FakePostRepo _repo(ResultTally t) =>
    FakePostRepo(flowValue: flowOf(RatingFlowState.notStarted), tally: Ok(t));

void main() {
  for (final locale in kLocales) {
    final l = lOf(locale);
    group('G-03 ${locale.languageCode}', () {
      testWidgets('waiting for submissions', (tester) async {
        final repo = _repo(
          const ResultTally(
            competitive: true,
            submissions: 0,
            eligible: 8,
            isOrganiser: true,
          ),
        );
        await pumpPost(
          tester,
          repo,
          const ResultApprovalScreen(eventId: 'e1'),
          locale: locale,
        );
        expect(_k('g03-waiting'), findsOneWidget);
        expect(find.text(l.g03_waiting_body(0, 8)), findsOneWidget);
        expect(_k('g03-approve'), findsNothing);
      });

      testWidgets('majority ready: N of M said, the spread, Approve', (
        tester,
      ) async {
        final repo = _repo(
          _t(ResultState.majorityReady, provisional: const Score(4, 3)),
        );
        repo.afterWrite = () => repo.tally = Ok(
          _t(ResultState.approved, finalScore: const Score(4, 3)),
        );
        await pumpPost(
          tester,
          repo,
          const ResultApprovalScreen(eventId: 'e1'),
          locale: locale,
        );
        expect(
          find.text(l.g03_majority(6, 8, scoreText(const Score(4, 3)))),
          findsOneWidget,
        );
        expect(find.text(l.g03_confirms_in(23)), findsOneWidget);
        expect(_k('g03-spread-3-3'), findsOneWidget);
        expect(_k('g03-spread-5-3'), findsOneWidget);
        expect(_k('g03-spread-4-3'), findsNothing);
        await tester.tap(_k('g03-approve'));
        await tester.pumpAndSettle();
        expect(repo.calls, ['approve']);
        expect(_k('g03-approved'), findsOneWidget);
        await tester.pump(const Duration(seconds: 10));
      });

      testWidgets('double tap Approve = one call', (tester) async {
        final repo = _repo(
          _t(ResultState.majorityReady, provisional: const Score(4, 3)),
        )..gate = Completer<void>();
        await pumpPost(
          tester,
          repo,
          const ResultApprovalScreen(eventId: 'e1'),
          locale: locale,
        );
        await tester.tap(_k('g03-approve'));
        await tester.pump();
        await tester.tap(_k('g03-approve'), warnIfMissed: false);
        await tester.pump();
        repo.gate!.complete();
        await tester.pumpAndSettle();
        expect(repo.calls, ['approve']);
        await tester.pump(const Duration(seconds: 10));
      });

      testWidgets('a refused Approve never shows success and reloads', (
        tester,
      ) async {
        final repo = _repo(
          _t(ResultState.majorityReady, provisional: const Score(4, 3)),
        )..failure = const Failure(code: 'result_final');
        await pumpPost(
          tester,
          repo,
          const ResultApprovalScreen(eventId: 'e1'),
          locale: locale,
        );
        await tester.tap(_k('g03-approve'));
        await tester.pumpAndSettle();
        expect(find.text(l.g02_err_result_final), findsOneWidget);
        expect(find.text(l.g03_approved_toast), findsNothing);
        expect(repo.resultReads, 2);
        await tester.pump(const Duration(seconds: 10));
      });

      testWidgets('Reject opens final score entry', (tester) async {
        var opened = 0;
        final repo = _repo(
          _t(ResultState.majorityReady, provisional: const Score(4, 3)),
        );
        await pumpPost(
          tester,
          repo,
          ResultApprovalScreen(
            eventId: 'e1',
            onEnterFinal: () async => opened++,
          ),
          locale: locale,
        );
        await tester.tap(_k('g03-reject'));
        await tester.pumpAndSettle();
        expect(opened, 1);
        expect(repo.calls, isEmpty);
      });

      testWidgets('tie: final entry with the countdown', (tester) async {
        var opened = 0;
        final repo = _repo(_t(ResultState.tie));
        await pumpPost(
          tester,
          repo,
          ResultApprovalScreen(
            eventId: 'e1',
            onEnterFinal: () async => opened++,
          ),
          locale: locale,
        );
        expect(find.text(l.g03_tie_body(23)), findsOneWidget);
        expect(_k('g03-approve'), findsNothing);
        await tester.tap(_k('g03-enter-final'));
        await tester.pumpAndSettle();
        expect(opened, 1);
      });

      final finals = <ResultState, String>{
        ResultState.approved: 'g03-approved',
        ResultState.rejected: 'g03-rejected',
        ResultState.autoConfirmed: 'g03-auto',
      };
      for (final e in finals.entries) {
        testWidgets('${e.key.name}: the final score, no action', (
          tester,
        ) async {
          final repo = _repo(_t(e.key, finalScore: const Score(2, 1)));
          await pumpPost(
            tester,
            repo,
            const ResultApprovalScreen(eventId: 'e1'),
            locale: locale,
          );
          expect(_k(e.value), findsOneWidget);
          expect(
            find.text(l.g03_final_body(scoreText(const Score(2, 1)))),
            findsOneWidget,
          );
          expect(_k('g03-approve'), findsNothing);
          expect(_k('g03-enter-final'), findsNothing);
        });
      }

      testWidgets('closed with no result', (tester) async {
        final repo = _repo(_t(ResultState.closedNoResult));
        await pumpPost(
          tester,
          repo,
          const ResultApprovalScreen(eventId: 'e1'),
          locale: locale,
        );
        expect(find.text(l.g03_closed_no_result), findsOneWidget);
      });

      testWidgets('a player sees the tally with no action', (tester) async {
        final repo = _repo(
          _t(
            ResultState.majorityReady,
            provisional: const Score(4, 3),
            organiser: false,
          ),
        );
        await pumpPost(
          tester,
          repo,
          const ResultApprovalScreen(eventId: 'e1'),
          locale: locale,
        );
        expect(_k('g03-majority'), findsOneWidget);
        expect(_k('g03-approve'), findsNothing);
        expect(_k('g03-reject'), findsNothing);
        expect(find.text(l.g03_player_note), findsOneWidget);
      });

      testWidgets('final score: deadline in 24h clock, Confirm once', (
        tester,
      ) async {
        var done = 0;
        final repo = _repo(_t(ResultState.tie))..gate = Completer<void>();
        await pumpPost(
          tester,
          repo,
          FinalScoreScreen(eventId: 'e1', onDone: () => done++),
          locale: locale,
          use24h: true,
        );
        expect(_k('g03-final-screen'), findsOneWidget);
        expect(find.text(l.g03f_deadline('20:00')), findsOneWidget);
        await tester.tap(_k('g03f-confirm'));
        await tester.pump();
        await tester.tap(_k('g03f-confirm'), warnIfMissed: false);
        await tester.pump();
        repo.gate!.complete();
        await tester.pumpAndSettle();
        expect(repo.calls, ['final:0-0']);
        expect(done, 1);
        await tester.pump(const Duration(seconds: 10));
      });

      testWidgets('final score: 12h clock; a refusal stays', (tester) async {
        var done = 0;
        final repo = _repo(_t(ResultState.tie))
          ..failure = const Failure(code: 'result_final');
        await pumpPost(
          tester,
          repo,
          FinalScoreScreen(eventId: 'e1', onDone: () => done++),
          locale: locale,
        );
        expect(find.textContaining('8:00'), findsOneWidget);
        await tester.tap(_k('g03f-confirm'));
        await tester.pumpAndSettle();
        expect(done, 0);
        expect(find.text(l.g02_err_result_final), findsWidgets);
        expect(find.text(l.g03f_saved), findsNothing);
        await tester.pump(const Duration(seconds: 10));
      });
    });
  }
}
