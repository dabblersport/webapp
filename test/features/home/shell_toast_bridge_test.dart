import 'package:dabbler/core/feedback/feedback_intent.dart';
import 'package:dabbler/core/feedback/presentation_context.dart';
import 'package:dabbler/core/feedback/shell_toast_bridge.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/render_mode.dart';
import 'shell_feedback_harness.dart';

/// Commit 4: the existing toast API, decided by the shell surface at
/// presentation time. One presenter per event.

const _report = DabblerToastSpec(
  message: 'Report submitted. Thank you.',
  tone: DabblerToastTone.success,
);

Finder get _floating => find.byType(DabblerToast);
Finder get _reportText => find.text(_report.message);

/// A dialog over the shell whose button does what `ReportDialog` does on
/// success: take the toast queue, pop, then show.
Future<void> _openReportDialog(ShellHarness h, {required bool pop}) async {
  showDialog<void>(
    context: h.rootContext,
    builder: (ctx) => Center(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          final toast = DabblerToastProvider.of(ctx);
          if (pop) Navigator.pop(ctx);
          toast.show(_report);
        },
        child: const SizedBox(width: 100, height: 100, key: Key('submit')),
      ),
    ),
  );
  await h.advance(500);
  expect(h.state.surface, ShellSurface.absent);
  await h.tester.tap(find.byKey(const Key('submit')));
}

void main() {
  setUpAll(loadRenderFonts);

  testWidgets('a toast raised on the shell is presented by the Action Area', (
    tester,
  ) async {
    final h = await pumpShell(tester);
    DabblerToastProvider.of(tester.element(find.text('/home-b'))).show(_report);
    await h.advance(1200);
    expect(h.state.current?.state, isA<FeedbackResult>());
    expect(_reportText, findsOneWidget);
    expect(_floating, findsNothing);
  });

  testWidgets('report from Home: the dialog closes, then the Action Area '
      'shows the result — not a floating toast', (tester) async {
    final h = await pumpShell(tester);
    await _openReportDialog(h, pop: true);
    await h.advance(1500);
    expect(h.state.surface, ShellSurface.current);
    expect(_reportText, findsOneWidget);
    expect(_floating, findsNothing);
    await h.advance(5000);
    expect(h.state.current, isNull);
    expect(h.phase, DabblerActionAreaPhase.idle);
    expect(_floating, findsNothing);
  });

  testWidgets('a result raised while a dialog still covers the shell is '
      'the standard toast, once', (tester) async {
    final h = await pumpShell(tester);
    await _openReportDialog(h, pop: false);
    await h.advance(800);
    expect(_floating, findsOneWidget);
    expect(_reportText, findsOneWidget);
    expect(h.state.current, isNull);
    Navigator.of(h.rootContext).pop();
    await h.advance(800);
    expect(_reportText, findsOneWidget); // still the toast, not re-shown
    expect(h.state.current, isNull);
    await h.advance(5000);
  });

  testWidgets('the same call from an internal route is the standard toast', (
    tester,
  ) async {
    final h = await pumpShell(tester);
    h.router.push('/internal');
    await h.advance(1000);
    DabblerToastProvider.of(
      tester.element(find.text('/internal-b')),
    ).show(_report);
    await h.advance(800);
    expect(_floating, findsOneWidget);
    expect(_reportText, findsOneWidget);
    expect(h.state.current, isNull);
    await h.advance(5000);
  });

  test('toast tones map to the same intent and text', () {
    FeedbackState f(DabblerToastTone t) =>
        feedbackFromToastSpec(DabblerToastSpec(message: 'm', tone: t));
    expect(f(DabblerToastTone.success), isA<FeedbackResult>());
    expect(
      (f(DabblerToastTone.error) as FeedbackResult).kind,
      ResultKind.error,
    );
    expect(
      (f(DabblerToastTone.warning) as FeedbackInformation).tone,
      InfoTone.warning,
    );
    expect(
      (f(DabblerToastTone.info) as FeedbackInformation).tone,
      InfoTone.info,
    );
    expect(
      (f(DabblerToastTone.neutral) as FeedbackInformation).tone,
      InfoTone.neutral,
    );
  });
}
