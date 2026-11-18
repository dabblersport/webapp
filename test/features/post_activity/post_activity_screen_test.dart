// KAN-1000 (G-02): every state of the post-activity flow, EN and AR.

import 'dart:async';

import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/features/post_activity/domain/post_activity_models.dart';
import 'package:dabbler/features/post_activity/presentation/post_activity_screen.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'post_activity_fakes.dart';

ResultTally _open({MyScore? mine, int submissions = 1, int eligible = 2}) =>
    ResultTally(
      competitive: true,
      state: ResultState.waiting,
      submissions: submissions,
      eligible: eligible,
      mine: mine,
    );

Widget _screen() => const PostActivityScreen(eventId: 'e1', onBack: _noop);
void _noop() {}

Finder _k(String k) => find.byKey(ValueKey<String>(k));

Future<void> _tapSide(WidgetTester tester, String side) async {
  await tester.ensureVisible(_k('g02-side-$side'));
  await tester.pumpAndSettle();
  await tester.tap(_k('g02-side-$side'));
}

void main() {
  for (final locale in kLocales) {
    final l = lOf(locale);
    group('G-02 ${locale.languageCode}', () {
      testWidgets('not started: score step first, countdown, side then Next', (
        tester,
      ) async {
        final repo = FakePostRepo(
          flowValue: flowOf(RatingFlowState.notStarted),
          tally: Ok(_open()),
        );
        await pumpPost(tester, repo, _screen(), locale: locale);
        expect(_k('g02-step-score'), findsOneWidget);
        expect(find.text(l.g02_closes_in(47)), findsOneWidget);
        expect(find.byType(DabblerProgressBar), findsOneWidget);
        await _tapSide(tester, 'a');
        await tester.pumpAndSettle();
        await tester.tap(_k('g02-next'));
        await tester.pumpAndSettle();
        expect(repo.calls, ['score:0-0:a']);
        expect(_k('g02-step-players'), findsOneWidget);
        expect(find.textContaining('Omar'), findsOneWidget);
      });

      testWidgets('non-competitive: no score step', (tester) async {
        final repo = FakePostRepo(
          flowValue: flowOf(RatingFlowState.notStarted),
          tally: const Ok(ResultTally(competitive: false)),
        );
        await pumpPost(tester, repo, _screen(), locale: locale);
        expect(_k('g02-step-score'), findsNothing);
        expect(_k('g02-step-players'), findsOneWidget);
        expect(find.text(l.g02_step_of(1, 3)), findsWidgets);
      });

      testWidgets('every step skips; Submit shows waiting with the count', (
        tester,
      ) async {
        final repo = FakePostRepo(
          flowValue: flowOf(RatingFlowState.notStarted),
          tally: Ok(_open()),
        );
        repo.afterWrite = () =>
            repo.flowValue = flowOf(RatingFlowState.submitted);
        await pumpPost(tester, repo, _screen(), locale: locale);
        for (var i = 0; i < 4; i++) {
          await tester.tap(_k('g02-skip'));
          await tester.pumpAndSettle();
        }
        expect(repo.calls, ['submit']);
        expect(_k('g02-submitted'), findsOneWidget);
        expect(find.text(l.g02_submitted_count(1, 2)), findsWidgets);
      });

      testWidgets('partly saved: resumes at the first unsaved step', (
        tester,
      ) async {
        final repo = FakePostRepo(
          flowValue: flowOf(
            RatingFlowState.partlySaved,
            playerMine: {'sportsmanship': 4},
          ),
          tally: Ok(_open(mine: const MyScore(Score(4, 3), 'a'))),
        );
        await pumpPost(tester, repo, _screen(), locale: locale);
        expect(_k('g02-step-organiser'), findsOneWidget);
        await tester.tap(_k('g02-back'));
        await tester.pumpAndSettle();
        expect(_k('g02-step-players'), findsOneWidget);
        final r = tester.widget<DabblerRating>(
          _k('rating-player:p1-sportsmanship'),
        );
        expect(r.value, 4);
      });

      testWidgets('a rating is saved on Next', (tester) async {
        final repo = FakePostRepo(
          flowValue: flowOf(RatingFlowState.notStarted),
          tally: const Ok(ResultTally(competitive: false)),
        );
        await pumpPost(tester, repo, _screen(), locale: locale);
        await tester.tap(_k('rating-player:p1-sportsmanship'));
        await tester.pumpAndSettle();
        await tester.tap(_k('g02-next'));
        await tester.pumpAndSettle();
        expect(repo.calls.single, startsWith('rate:player:p1:'));
        expect(_k('g02-step-organiser'), findsOneWidget);
      });

      testWidgets('submitted: waiting for others with the count', (
        tester,
      ) async {
        final repo = FakePostRepo(
          flowValue: flowOf(RatingFlowState.submitted),
          tally: Ok(_open(submissions: 6, eligible: 8)),
        );
        await pumpPost(tester, repo, _screen(), locale: locale);
        expect(find.text(l.g02_submitted), findsOneWidget);
        expect(find.text(l.g02_submitted_count(6, 8)), findsWidgets);
      });

      testWidgets('closed after 48h: read-only', (tester) async {
        final repo = FakePostRepo(
          flowValue: flowOf(
            RatingFlowState.closed,
            playerMine: {'sportsmanship': 5},
          ),
          tally: const Ok(
            ResultTally(
              competitive: true,
              state: ResultState.approved,
              finalScore: Score(4, 3),
            ),
          ),
        );
        await pumpPost(tester, repo, _screen(), locale: locale);
        expect(_k('g02-closed'), findsOneWidget);
        expect(find.text(l.g02_closed), findsOneWidget);
        expect(_k('g02-next'), findsNothing);
        expect(_k('g02-skip'), findsNothing);
        for (final r in tester.widgetList<DabblerRating>(
          find.byType(DabblerRating),
        )) {
          expect(r.onChanged, isNull);
        }
      });

      testWidgets('not eligible (finalized attendance)', (tester) async {
        final repo = FakePostRepo(
          flowValue: const RatingFlow(state: RatingFlowState.notEligible),
          tally: const Err(Failure(code: 'not_eligible')),
        );
        await pumpPost(tester, repo, _screen(), locale: locale);
        expect(_k('g02-not-eligible'), findsOneWidget);
        expect(find.text(l.g02_not_eligible_body), findsOneWidget);
        expect(_k('g02-organiser'), findsNothing);
        expect(repo.resultReads, 0);
      });

      for (final (name, code) in [
        ('meetup', 'not_found'),
        ('training game', 'no_score_step'),
      ]) {
        testWidgets('the organiser of a $name: organiser copy, no button', (
          tester,
        ) async {
          final repo = FakePostRepo(
            flowValue: const RatingFlow(
              state: RatingFlowState.notEligible,
              isOrganiser: true,
            ),
            tally: Err(Failure(code: code)),
          );
          await pumpPost(tester, repo, _screen(), locale: locale);
          expect(_k('g02-organiser'), findsOneWidget);
          expect(find.text(l.g02_organiser_title), findsOneWidget);
          expect(find.text(l.g02_organiser_body_no_result), findsOneWidget);
          expect(find.text(l.g02_organiser_body), findsNothing);
          expect(_k('g02-organiser-result'), findsNothing);
          expect(find.text(l.g02_not_eligible_body), findsNothing);
        });
      }

      testWidgets('the organiser of a competitive game: organiser copy', (
        tester,
      ) async {
        final repo = FakePostRepo(
          flowValue: const RatingFlow(
            state: RatingFlowState.notEligible,
            isOrganiser: true,
          ),
          tally: const Ok(ResultTally(competitive: true, isOrganiser: true)),
        );
        await pumpPost(tester, repo, _screen(), locale: locale);
        expect(_k('g02-organiser'), findsOneWidget);
        expect(find.text(l.g02_organiser_title), findsOneWidget);
        expect(find.text(l.g02_organiser_body), findsOneWidget);
        expect(find.text(l.g02_organiser_result), findsOneWidget);
        expect(_k('g02-organiser-result'), findsOneWidget);
        expect(find.text(l.g02_not_eligible_body), findsNothing);
      });

      testWidgets('a refusal never shows success and reloads', (tester) async {
        final repo = FakePostRepo(
          flowValue: flowOf(RatingFlowState.notStarted),
          tally: const Ok(ResultTally(competitive: false)),
        )..failure = const Failure(code: 'window_closed');
        await pumpPost(tester, repo, _screen(), locale: locale);
        for (var i = 0; i < 3; i++) {
          await tester.tap(_k('g02-skip'));
          await tester.pumpAndSettle();
        }
        expect(repo.calls, ['submit']);
        expect(find.text(l.g02_err_window_closed), findsOneWidget);
        expect(find.text(l.g02_submitted), findsNothing);
        expect(repo.flowReads, 2);
        await tester.pump(const Duration(seconds: 10));
      });

      testWidgets('double tap = one call', (tester) async {
        final repo = FakePostRepo(
          flowValue: flowOf(RatingFlowState.notStarted),
          tally: Ok(_open()),
        )..gate = Completer<void>();
        await pumpPost(tester, repo, _screen(), locale: locale);
        await _tapSide(tester, 'b');
        await tester.pump();
        await tester.tap(_k('g02-next'));
        await tester.pump();
        await tester.tap(_k('g02-next'), warnIfMissed: false);
        await tester.pump();
        repo.gate!.complete();
        await tester.pumpAndSettle();
        expect(repo.calls, ['score:0-0:b']);
      });
    });
  }
}
