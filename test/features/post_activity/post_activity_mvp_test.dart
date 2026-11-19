// KAN-968: the MVP step after Players. Shown only when rpc_mvp_get gives
// candidates; the vote is sent on Next and replaces a saved one; a refusal
// keeps the pick, and an eligibility/window refusal hides the step.

import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/features/post_activity/domain/post_activity_models.dart';
import 'package:dabbler/features/post_activity/presentation/post_activity_controller.dart';
import 'package:dabbler/features/post_activity/presentation/post_activity_screen.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'post_activity_fakes.dart';

const _none = ResultTally(competitive: false);
const _ballot = MvpBallot(
  candidates: [
    MvpCandidate(userId: 'p1', name: 'Omar'),
    MvpCandidate(userId: 'p2', name: 'Ali'),
  ],
);

Widget _screen() => const PostActivityScreen(eventId: 'e1', onBack: _noop);
void _noop() {}

Finder _k(String k) => find.byKey(ValueKey<String>(k));

PostActivityState _state(WidgetTester tester) => ProviderScope.containerOf(
  tester.element(find.byType(PostActivityScreen)),
).read(postActivityProvider('e1'));

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.ensureVisible(_k(key));
  await tester.tap(_k(key));
  await tester.pumpAndSettle();
}

FakePostRepo _repo({Result<MvpBallot, Failure> mvp = const Ok(_ballot)}) =>
    FakePostRepo(
      flowValue: flowOf(RatingFlowState.notStarted),
      tally: const Ok(_none),
    )..mvpValue = mvp;

void main() {
  for (final locale in kLocales) {
    final l = lOf(locale);
    group('KAN-968 ${locale.languageCode}', () {
      testWidgets('shown after players with candidates; vote sent', (
        tester,
      ) async {
        final repo = _repo();
        await pumpPost(tester, repo, _screen(), locale: locale);
        expect(_state(tester).steps, [
          PostStep.players,
          PostStep.mvp,
          PostStep.organiser,
          PostStep.venue,
        ]);
        await _tap(tester, 'g02-skip');
        expect(_k('g02-step-mvp'), findsOneWidget);
        expect(find.text(l.g02_step_mvp), findsOneWidget);
        expect(_k('g02-mvp-p1'), findsOneWidget);
        await _tap(tester, 'g02-mvp-p2');
        await _tap(tester, 'g02-next');
        expect(repo.calls, ['mvp:p2']);
        expect(_k('g02-step-organiser'), findsOneWidget);
      });

      testWidgets('hidden when no candidates or refused', (tester) async {
        await pumpPost(tester, _repo(mvp: const Ok(MvpBallot())), _screen());
        expect(_state(tester).steps.contains(PostStep.mvp), isFalse);
        await pumpPost(
          tester,
          _repo(mvp: const Err(Failure(code: 'not_eligible'))),
          _screen(),
          locale: locale,
        );
        expect(_state(tester).steps.contains(PostStep.mvp), isFalse);
      });

      testWidgets('saved vote preselected; a new pick replaces it', (
        tester,
      ) async {
        final repo = _repo(
          mvp: Ok(MvpBallot(candidates: _ballot.candidates, myVote: 'p1')),
        );
        await pumpPost(tester, repo, _screen(), locale: locale);
        expect(_state(tester).mvpPick, 'p1');
        await _tap(tester, 'g02-skip');
        await _tap(tester, 'g02-next');
        expect(repo.calls, isEmpty, reason: 'unchanged vote is not resent');
        await _tap(tester, 'g02-back');
        await _tap(tester, 'g02-mvp-p2');
        await _tap(tester, 'g02-next');
        expect(repo.calls, ['mvp:p2']);
      });

      testWidgets('refusal keeps the pick and shows the error', (tester) async {
        final repo = _repo()..voteFailure = const Failure(code: 'self_vote');
        await pumpPost(tester, repo, _screen(), locale: locale);
        await _tap(tester, 'g02-skip');
        await _tap(tester, 'g02-mvp-p1');
        await _tap(tester, 'g02-next');
        expect(_k('g02-step-mvp'), findsOneWidget);
        expect(_state(tester).mvpPick, 'p1');
        expect(_k('g02-save-failed'), findsOneWidget);
        expect(find.text(l.g02_err_mvp_self), findsWidgets);
      });

      testWidgets('window refusal hides the step', (tester) async {
        final repo = _repo()
          ..voteFailure = const Failure(code: 'window_closed');
        await pumpPost(tester, repo, _screen(), locale: locale);
        await _tap(tester, 'g02-skip');
        await _tap(tester, 'g02-mvp-p1');
        await _tap(tester, 'g02-next');
        expect(_state(tester).steps.contains(PostStep.mvp), isFalse);
        expect(_k('g02-step-mvp'), findsNothing);
      });
    });
  }
}
