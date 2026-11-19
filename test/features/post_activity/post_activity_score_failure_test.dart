// KAN-1027: a refused score keeps what was entered. not_ended shows a note
// and lets the user move on; any other refusal shows the error.

import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/features/post_activity/domain/post_activity_models.dart';
import 'package:dabbler/features/post_activity/presentation/post_activity_controller.dart';
import 'package:dabbler/features/post_activity/presentation/post_activity_screen.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'post_activity_fakes.dart';

const _open = ResultTally(competitive: true, eligible: 2);

Widget _screen() => const PostActivityScreen(eventId: 'e1', onBack: _noop);
void _noop() {}

Finder _k(String k) => find.byKey(ValueKey<String>(k));

PostActivityState _state(WidgetTester tester) => ProviderScope.containerOf(
  tester.element(find.byType(PostActivityScreen)),
).read(postActivityProvider('e1'));

Future<void> _enter(WidgetTester tester) async {
  final c = ProviderScope.containerOf(
    tester.element(find.byType(PostActivityScreen)),
  ).read(postActivityProvider('e1').notifier);
  c.setScore(const Score(3, 2));
  c.setSide('b');
  await tester.pumpAndSettle();
}

Future<void> _next(WidgetTester tester) async {
  await tester.ensureVisible(_k('g02-next'));
  await tester.tap(_k('g02-next'));
  await tester.pumpAndSettle();
}

void main() {
  for (final locale in kLocales) {
    final l = lOf(locale);
    group('KAN-1027 ${locale.languageCode}', () {
      testWidgets('not_ended: values kept, note shown, Next moves on', (
        tester,
      ) async {
        final repo = FakePostRepo(
          flowValue: flowOf(RatingFlowState.notStarted),
          tally: const Ok(_open),
        )..failure = const Failure(code: 'not_ended');
        await pumpPost(tester, repo, _screen(), locale: locale);
        await _enter(tester);
        await _next(tester);
        expect(repo.calls, ['score:3-2:b']);
        expect(_k('g02-step-score'), findsOneWidget);
        expect(_k('g02-score-not-ended'), findsOneWidget);
        expect(find.text(l.g02_score_not_ended), findsOneWidget);
        expect(_state(tester).score, const Score(3, 2));
        expect(_state(tester).side, 'b');
        expect(repo.flowReads, 1);
        repo.failure = null;
        await _next(tester);
        expect(repo.calls, ['score:3-2:b']);
        expect(_k('g02-step-players'), findsOneWidget);
      });

      testWidgets('generic failure: values kept, error shown', (tester) async {
        final repo = FakePostRepo(
          flowValue: flowOf(RatingFlowState.notStarted),
          tally: const Ok(_open),
        )..failure = const Failure(code: 'boom');
        await pumpPost(tester, repo, _screen(), locale: locale);
        await _enter(tester);
        await _next(tester);
        expect(_k('g02-step-score'), findsOneWidget);
        expect(_k('g02-save-failed'), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(DabblerBanner),
            matching: find.text(l.g02_err_generic),
          ),
          findsOneWidget,
        );
        expect(_state(tester).score, const Score(3, 2));
        expect(_state(tester).side, 'b');
      });

      testWidgets('a reload-class refusal keeps the values too', (
        tester,
      ) async {
        final repo = FakePostRepo(
          flowValue: flowOf(RatingFlowState.notStarted),
          tally: const Ok(_open),
        )..failure = const Failure(code: 'window_not_open');
        await pumpPost(tester, repo, _screen(), locale: locale);
        await _enter(tester);
        await _next(tester);
        expect(repo.flowReads, 2);
        expect(_k('g02-step-score'), findsOneWidget);
        expect(_k('g02-save-failed'), findsOneWidget);
        expect(_state(tester).score, const Score(3, 2));
        expect(_state(tester).side, 'b');
      });
    });
  }
}
