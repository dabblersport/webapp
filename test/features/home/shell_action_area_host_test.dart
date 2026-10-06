import 'package:dabbler/core/feedback/feedback_intent.dart';
import 'package:dabbler/core/feedback/presentation_context.dart';
import 'package:dabbler/core/feedback/shell_action_area_host.dart';
import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';

import '../../support/render_mode.dart';
import 'shell_feedback_harness.dart';

const _bar = DabblerNavigationBottomBar(
  items: [
    DabblerNavigationItem(id: 'home', icon: 'home-2', label: 'Feeds'),
    DabblerNavigationItem(id: 'games', icon: 'game', label: 'Games'),
  ],
  active: 'home',
  rotateActionOnOpen: false,
  actionOpenIcon: 'close-circle',
  mirrorInRtl: false,
);

const _working = FeedbackProcessing(
  kind: ProcessingKind.spinnerLabel,
  label: 'Working',
);

Finder get _toast => find.byType(DabblerToast);

void main() {
  setUpAll(loadRenderFonts);

  // ------------------------------------------------------------------ idle

  for (final inset in [0.0, 34.0]) {
    testWidgets('idle host is geometrically the old bar (inset $inset)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      tester.view.padding = FakeViewPadding(bottom: inset);
      addTearDown(tester.view.reset);
      const bodyKey = Key('body');
      Future<Map<String, Rect>> measure(Widget overlay) async {
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: DabblerDesignSystemTheme.withTokens(renderThemeBase()),
              home: DabblerPage(
                body: const SizedBox.expand(key: bodyKey),
                bottomOverlay: overlay,
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));
        return {
          // The overlay's box: the bar plus the bottom inset, applied once.
          'overlay': tester.getRect(
            find.byWidgetPredicate(
              (w) =>
                  w is DabblerNavigationStatus ||
                  (w is DabblerNavigationBottomBar &&
                      find.byType(DabblerNavigationStatus).evaluate().isEmpty),
            ),
          ),
          'body': tester.getRect(find.byKey(bodyKey)),
          for (final (i, e)
              in tester.elementList(find.byType(DabblerIcon)).indexed)
            'icon$i': tester.getRect(find.byElementPredicate((x) => x == e)),
        };
      }

      final old = await measure(_bar);
      final hosted = await measure(
        const ShellActionAreaHost(
          bar: _bar,
          createMenuOpen: false,
          branchIndex: 0,
          dismissSemanticLabel: 'Dismiss',
        ),
      );
      expect(hosted, old);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('idle shell: tabs switch, create menu opens, back goes home', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final h = await pumpShell(tester);
    expect(h.status.payload, isNull);
    expect(h.state.surface, ShellSurface.current);
    await tester.tap(find.bySemanticsLabel('Games'));
    await tester.pumpAndSettle();
    expect(h.location, '/games');
    expect(h.status.bar.active, 'games');
    expect(h.state.branchIndex, 3);
    // Back from a non-home branch returns Home (unchanged behaviour).
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(h.location, '/home');
    await tester.tap(find.bySemanticsLabel('Create'));
    await tester.pumpAndSettle();
    expect(find.text('Create post'), findsOneWidget);
    expect(h.state.surface, ShellSurface.blocked);
    expect(h.status.suspended, isTrue);
    semantics.dispose();
  });

  // ------------------------------------------------------------ processing

  testWidgets('processing renders on the action area', (tester) async {
    final h = await pumpShell(tester);
    h.center.begin(_working);
    await h.advance(400);
    expect(h.status.payload, isA<DabblerNavigationStatusActivity>());
    expect(find.text('Working'), findsOneWidget);
    expect(_toast, findsNothing);
  });

  testWidgets('progress updates in place on the same surface', (tester) async {
    final h = await pumpShell(tester);
    final id = h.center.begin(
      const FeedbackProcessing(
        kind: ProcessingKind.determinate,
        label: 'Upload',
        progress: 0,
      ),
    );
    await h.advance(400);
    final area = tester.state(find.byType(DabblerActionArea));
    for (final v in [0.25, 0.5, 0.75]) {
      h.center.progress(id, v);
      await h.advance(100);
      final p = h.status.payload! as DabblerNavigationStatusActivity;
      expect(p.value, v);
      expect(p.presentation, DabblerNavigationActivityPresentation.progress);
    }
    expect(tester.state(find.byType(DabblerActionArea)), same(area));
  });

  testWidgets('processing -> success on the same surface, then idle', (
    tester,
  ) async {
    final h = await pumpShell(tester);
    final id = h.center.begin(_working);
    await h.advance(400);
    final area = tester.state(find.byType(DabblerActionArea));
    h.center.succeed(id, const FeedbackResult.success('Done'));
    await h.advance(1200);
    expect(find.text('Done'), findsOneWidget);
    expect(tester.state(find.byType(DabblerActionArea)), same(area));
    expect(_toast, findsNothing);
    // Timed: the default toast duration returns the bar to idle.
    await h.advance(5000);
    expect(h.state.current, isNull);
    expect(h.status.payload, isNull);
    // Navigation is intact after returning to idle.
    await tester.tap(find.bySemanticsLabel('Games'));
    await tester.pumpAndSettle();
    expect(h.location, '/games');
  });

  testWidgets('processing -> error -> Retry -> success', (tester) async {
    final h = await pumpShell(tester);
    var calls = 0;
    h.center.run<int>(
      processing: _working,
      task: () async {
        calls++;
        await Future<void>.delayed(const Duration(milliseconds: 300));
        return calls == 1
            ? const Err<int, Failure>(Failure(message: 'x'))
            : const Ok<int, Failure>(1);
      },
      success: (_) => const FeedbackResult.success('Joined'),
      failure: (_, retry) => FeedbackResult.error(
        'Failed',
        action: FeedbackAction(label: 'Retry', onPressed: retry),
      ),
    );
    await h.advance(1600);
    expect(find.text('Failed'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    // Sticky: still there long after a toast would have gone.
    await h.advance(5000);
    expect(find.text('Failed'), findsOneWidget);
    await tester.tap(find.byKey(DabblerNavigationStatus.actionTargetKey));
    await h.advance(200);
    expect(h.state.current?.state, isA<FeedbackProcessing>());
    await h.advance(1600);
    expect(calls, 2);
    expect(find.text('Joined'), findsOneWidget);
    expect(_toast, findsNothing);
  });

  // ----------------------------------------------------------- information

  testWidgets('sticky information stays until dismissed', (tester) async {
    final h = await pumpShell(tester);
    h.center.inform(
      const FeedbackInformation(message: 'Heads up', duration: Duration.zero),
      key: 'tip',
    );
    await h.advance(1000);
    expect(find.text('Heads up'), findsOneWidget);
    await h.advance(6000);
    expect(find.text('Heads up'), findsOneWidget);
    await tester.tap(find.byKey(DabblerNavigationStatus.dismissTargetKey));
    await h.advance(1000);
    expect(h.state.current, isNull);
    expect(h.state.dismissedKeys, contains('tip'));
    expect(h.phase, DabblerActionAreaPhase.idle);
  });

  // ------------------------------------------------------------- scoping

  testWidgets('tab switch keeps a shell op and clears a page op', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final h = await pumpShell(tester);
    // Compact: the bar stays live under a collapsed surface (an expanded
    // one makes the bar inert, by DS design).
    final shellOp = h.center.begin(const FeedbackProcessing());
    h.center.inform(
      const FeedbackInformation(message: 'Page note'),
      scope: FeedbackScope.page,
    );
    await h.advance(300);
    await tester.tap(find.bySemanticsLabel('Games'));
    await h.advance(600);
    expect(h.location, '/games');
    expect(h.state.current?.id, shellOp);
    expect(h.state.queue, isEmpty);
    expect(h.status.payload, isA<DabblerNavigationStatusActivity>());
    expect(h.status.bar.active, 'games');
    semantics.dispose();
  });

  testWidgets('an internal route hides the area; the result arrives once '
      'as a standard toast', (tester) async {
    final h = await pumpShell(tester);
    final id = h.center.begin(_working);
    await h.advance(300);
    h.router.push('/internal');
    await h.advance(1000);
    expect(h.state.surface, ShellSurface.absent);
    expect(
      tester
          .widget<DabblerNavigationStatus>(
            find.byType(DabblerNavigationStatus, skipOffstage: false),
          )
          .payload,
      isNull,
    );
    h.center.succeed(id, const FeedbackResult.success('Saved'));
    await h.advance(600);
    expect(find.text('Saved'), findsOneWidget);
    expect(_toast, findsOneWidget);
    expect(find.byType(DabblerNavigationStatus), findsNothing);
    h.router.pop();
    await h.advance(5000);
    expect(h.state.surface, ShellSurface.current);
    expect(h.status.payload, isNull);
    expect(find.text('Saved'), findsNothing);
  });

  testWidgets('create menu open holds a result until it closes', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final h = await pumpShell(tester);
    await tester.tap(find.bySemanticsLabel('Create'));
    await tester.pumpAndSettle();
    h.center.announce(const FeedbackResult.success('Later'));
    await h.advance(1000);
    expect(h.state.current?.target, FeedbackTarget.hold);
    expect(h.status.suspended, isTrue);
    expect(h.phase, DabblerActionAreaPhase.idle);
    expect(_toast, findsNothing);
    await tester.tap(find.bySemanticsLabel('Close menu'));
    await h.advance(1500);
    expect(h.state.current?.target, FeedbackTarget.actionArea);
    expect(h.phase, DabblerActionAreaPhase.expanded);
    expect(find.text('Later'), findsOneWidget);
    semantics.dispose();
  });

  // ----------------------------------------------- direction, inset, motion

  testWidgets('bottom safe area; the surface pins with the bar in LTR/RTL', (
    tester,
  ) async {
    final bars = <String, Rect>{};
    for (final locale in const [Locale('en'), Locale('ar')]) {
      final h = await pumpShell(tester, locale: locale, bottomInset: 34);
      final idleBar = tester.getRect(find.byType(DabblerNavigationBottomBar));
      expect(idleBar.bottom, lessThanOrEqualTo(852 - 34));
      h.center.begin(_working);
      await h.advance(600);
      expect(h.phase, DabblerActionAreaPhase.expanded);
      final label = tester.getRect(find.text('Working'));
      expect(label.left, greaterThanOrEqualTo(idleBar.left));
      expect(label.right, lessThanOrEqualTo(idleBar.right));
      expect(label.bottom, lessThanOrEqualTo(852 - 34));
      expect(tester.getRect(find.byType(DabblerNavigationBottomBar)), idleBar);
      bars[locale.languageCode] = idleBar;
      expect(tester.takeException(), isNull);
    }
    // mirrorInRtl: false — the bar, and the surface over it, do not flip.
    expect(bars['ar'], bars['en']);
  });

  testWidgets('reduced motion: phases land without long pumps', (tester) async {
    final h = await pumpShell(tester, reduceMotion: true);
    final id = h.center.begin(_working);
    await h.advance(100);
    h.center.succeed(id, const FeedbackResult.success('Done'));
    await h.advance(600);
    expect(find.text('Done'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('payload mapping: target gates, kinds and tones', () {
    FeedbackEntry e(
      FeedbackState s, [
      FeedbackTarget t = FeedbackTarget.actionArea,
    ]) => FeedbackEntry(id: 'a', state: s, seq: 1, target: t);
    expect(
      navigationStatusPayloadFor(e(_working, FeedbackTarget.toast)),
      isNull,
    );
    expect(
      navigationStatusPayloadFor(e(_working, FeedbackTarget.none)),
      isNull,
    );
    final ring =
        navigationStatusPayloadFor(
              e(
                const FeedbackProcessing(
                  kind: ProcessingKind.ring,
                  progress: .4,
                ),
              ),
            )!
            as DabblerNavigationStatusActivity;
    expect(ring.presentation, DabblerNavigationActivityPresentation.ring);
    expect(ring.value, .4);
    final err =
        navigationStatusPayloadFor(
              e(
                FeedbackResult.error(
                  'x',
                  action: FeedbackAction(label: 'Retry', onPressed: () {}),
                ),
              ),
            )!
            as DabblerNavigationStatusFeedback;
    expect(err.data.tone, DabblerToastTone.error);
    expect(err.banner, isTrue);
    expect(err.data.duration, Duration.zero);
    final ok =
        navigationStatusPayloadFor(e(const FeedbackResult.success('y')))!
            as DabblerNavigationStatusFeedback;
    expect(ok.data.tone, DabblerToastTone.success);
    expect(ok.banner, isFalse);
  });
}
