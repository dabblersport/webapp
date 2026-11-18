// KAN-1000 PEER follow-up: the final screen refuses a non-organiser, a failed
// load retries, the waiting copy, a failed tally keeps the score step, the
// Dismiss action, the minutes countdown and the detail entry line.

import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/features/notifications/domain/notification_kinds.dart';
import 'package:dabbler/features/post_activity/domain/post_activity_models.dart';
import 'package:dabbler/features/post_activity/presentation/final_score_screen.dart';
import 'package:dabbler/features/post_activity/presentation/post_activity_entry.dart';
import 'package:dabbler/features/post_activity/presentation/post_activity_screen.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'post_activity_fakes.dart';

Finder _k(String k) => find.byKey(ValueKey<String>(k));

const ResultTally _waiting = ResultTally(
  competitive: true,
  submissions: 1,
  eligible: 4,
  isOrganiser: true,
);

void _noop() {}

void main() {
  for (final locale in kLocales) {
    final l = lOf(locale);
    group('follow-up ${locale.languageCode}', () {
      testWidgets('final screen: a player gets organiser-only, no steppers', (
        tester,
      ) async {
        final repo = FakePostRepo(
          flowValue: flowOf(RatingFlowState.notStarted),
          tally: const Ok(
            ResultTally(
              competitive: true,
              state: ResultState.majorityReady,
              provisional: Score(4, 3),
            ),
          ),
        );
        await pumpPost(
          tester,
          repo,
          const FinalScoreScreen(eventId: 'e1'),
          locale: locale,
        );
        expect(_k('g03f-organiser-only'), findsOneWidget);
        expect(find.text(l.g03f_organiser_only), findsOneWidget);
        expect(_k('g03f-a'), findsNothing);
        expect(_k('g03f-confirm'), findsNothing);
      });

      testWidgets('final screen: load failure retries', (tester) async {
        final repo = FakePostRepo(
          flowValue: flowOf(RatingFlowState.notStarted),
          tally: const Err(Failure(code: 'network')),
        );
        await pumpPost(
          tester,
          repo,
          const FinalScoreScreen(eventId: 'e1'),
          locale: locale,
        );
        expect(_k('g03f-load-failed'), findsOneWidget);
        repo.tally = const Ok(
          ResultTally(
            competitive: true,
            state: ResultState.majorityReady,
            isOrganiser: true,
          ),
        );
        await tester.tap(find.text(l.feed_retry));
        await tester.pumpAndSettle();
        expect(repo.resultReads, 2);
        expect(_k('g03f-confirm'), findsOneWidget);
      });

      testWidgets('final screen: waiting shows the waiting copy', (
        tester,
      ) async {
        final repo = FakePostRepo(
          flowValue: flowOf(RatingFlowState.notStarted),
          tally: const Ok(_waiting),
        );
        await pumpPost(
          tester,
          repo,
          const FinalScoreScreen(eventId: 'e1'),
          locale: locale,
        );
        expect(_k('g03f-waiting'), findsOneWidget);
        expect(find.text(l.g03f_waiting), findsOneWidget);
        expect(find.text(l.g02_err_result_final), findsNothing);
        expect(_k('g03f-confirm'), findsNothing);
      });

      testWidgets('a timed-out tally keeps the score step with a retry', (
        tester,
      ) async {
        final repo = FakePostRepo(
          flowValue: flowOf(RatingFlowState.notStarted),
          tally: const Err(TimeoutFailure(message: 'timeout')),
        );
        await pumpPost(
          tester,
          repo,
          const PostActivityScreen(eventId: 'e1', onBack: _noop),
          locale: locale,
        );
        expect(_k('g02-step-score'), findsOneWidget);
        expect(_k('g02-score-failed'), findsOneWidget);
        repo.tally = const Ok(_waiting);
        await tester.tap(find.text(l.feed_retry));
        await tester.pumpAndSettle();
        expect(_k('g02-score-failed'), findsNothing);
        expect(_k('g02-side-a'), findsOneWidget);
      });

      testWidgets('no_score_step drops the score step', (tester) async {
        final repo = FakePostRepo(
          flowValue: flowOf(RatingFlowState.notStarted),
          tally: const Err(Failure(code: 'no_score_step')),
        );
        await pumpPost(
          tester,
          repo,
          const PostActivityScreen(eventId: 'e1', onBack: _noop),
          locale: locale,
        );
        expect(_k('g02-step-score'), findsNothing);
        expect(_k('g02-step-players'), findsOneWidget);
      });

      testWidgets('Dismiss calls rpc_rating_dismiss and confirms', (
        tester,
      ) async {
        final repo = FakePostRepo(
          flowValue: flowOf(RatingFlowState.notStarted),
          tally: const Ok(ResultTally(competitive: false)),
        );
        await pumpPost(
          tester,
          repo,
          const PostActivityScreen(eventId: 'e1', onBack: _noop),
          locale: locale,
        );
        await tester.ensureVisible(_k('g02-dismiss'));
        await tester.tap(_k('g02-dismiss'));
        await tester.pumpAndSettle();
        expect(repo.calls, ['dismiss']);
        expect(_k('g02-dismissed'), findsOneWidget);
      });

      testWidgets('under an hour the countdown is in minutes', (tester) async {
        final f = flowOf(RatingFlowState.notStarted);
        final repo = FakePostRepo(
          flowValue: RatingFlow(
            state: f.state,
            closesAt: kNow.add(const Duration(minutes: 5)),
            players: f.players,
          ),
          tally: const Ok(ResultTally(competitive: false)),
        );
        await pumpPost(
          tester,
          repo,
          const PostActivityScreen(eventId: 'e1', onBack: _noop),
          locale: locale,
        );
        expect(find.text(l.g02_closes_in_min(5)), findsOneWidget);
      });

      Future<void> entry(WidgetTester tester, FakePostRepo repo) => pumpPost(
        tester,
        repo,
        PostActivityEntry(
          eventId: 'e1',
          endAt: kNow.subtract(const Duration(hours: 1)),
        ),
        locale: locale,
      );

      testWidgets('entry: an eligible participant gets Rate and score', (
        tester,
      ) async {
        await entry(
          tester,
          FakePostRepo(
            flowValue: flowOf(RatingFlowState.partlySaved),
            tally: const Ok(ResultTally(competitive: false)),
          ),
        );
        expect(_k('post-activity-entry-rate'), findsOneWidget);
        expect(find.text(l.pa_entry_rate), findsOneWidget);
        expect(_k('post-activity-entry-review'), findsNothing);
      });

      testWidgets('entry: the organiser with an open result gets Review', (
        tester,
      ) async {
        await entry(
          tester,
          FakePostRepo(
            flowValue: flowOf(RatingFlowState.notEligible),
            tally: const Ok(_waiting),
          ),
        );
        expect(_k('post-activity-entry-rate'), findsNothing);
        expect(_k('post-activity-entry-review'), findsOneWidget);
      });

      testWidgets('entry: hidden when closed, submitted or final', (
        tester,
      ) async {
        for (final s in [
          RatingFlowState.closed,
          RatingFlowState.submitted,
          RatingFlowState.notOpen,
        ]) {
          await entry(
            tester,
            FakePostRepo(
              flowValue: flowOf(s),
              tally: const Ok(
                ResultTally(
                  competitive: true,
                  state: ResultState.approved,
                  isOrganiser: true,
                ),
              ),
            ),
          );
          expect(_k('post-activity-entry-rate'), findsNothing);
          expect(_k('post-activity-entry-review'), findsNothing);
        }
      });

      testWidgets('entry: no server read before the activity ends', (
        tester,
      ) async {
        final repo = FakePostRepo(
          flowValue: flowOf(RatingFlowState.notStarted),
          tally: const Ok(_waiting),
        );
        await pumpPost(
          tester,
          repo,
          PostActivityEntry(
            eventId: 'e1',
            endAt: kNow.add(const Duration(hours: 1)),
          ),
          locale: locale,
        );
        expect(repo.flowReads, 0);
        expect(_k('post-activity-entry-rate'), findsNothing);
      });
    });
  }

  test('minutesUntil and hoursUntil', () {
    expect(minutesUntil(kNow.add(const Duration(minutes: 5)), kNow), 5);
    expect(minutesUntil(kNow.subtract(const Duration(minutes: 1)), kNow), 0);
    expect(hoursUntil(kNow.add(const Duration(minutes: 61)), kNow), 2);
  });

  test('post-activity notices carry a Dismiss action', () {
    for (final k in ['activity.post_activity', 'activity.rating_reminder']) {
      expect(
        NotificationKinds.of(k)!.ctas
            .map((c) => c.action)
            .contains(NotificationActionId.dismissRating),
        isTrue,
        reason: k,
      );
    }
  });
}
