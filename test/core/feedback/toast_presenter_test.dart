import 'package:dabbler/core/feedback/feedback_center.dart';
import 'package:dabbler/core/feedback/feedback_intent.dart';
import 'package:dabbler/core/feedback/presentation_context.dart';
import 'package:dabbler/core/feedback/toast_presenter.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

FeedbackEntry _e(FeedbackState s, FeedbackTarget t) =>
    FeedbackEntry(id: 'x', state: s, seq: 1, target: t);

void main() {
  group('toastSpecFor', () {
    test('only toast-targeted Information/Result map to a toast', () {
      const ok = FeedbackResult.success('ok');
      expect(toastSpecFor(_e(ok, FeedbackTarget.actionArea)), isNull);
      expect(toastSpecFor(_e(ok, FeedbackTarget.none)), isNull);
      expect(
        toastSpecFor(_e(const FeedbackProcessing(), FeedbackTarget.toast)),
        isNull,
      );
      final spec = toastSpecFor(_e(ok, FeedbackTarget.toast))!;
      expect(spec.tone, DabblerToastTone.success);
      expect(spec.duration, DabblerToastSpec.defaultDuration);
    });
    test('error with retry is a sticky error toast carrying the action', () {
      var hit = false;
      final spec = toastSpecFor(
        _e(
          FeedbackResult.error(
            'e',
            action: FeedbackAction(label: 'Retry', onPressed: () => hit = true),
          ),
          FeedbackTarget.toast,
        ),
      )!;
      expect(spec.tone, DabblerToastTone.error);
      expect(spec.duration, DabblerToastSpec.sticky);
      spec.action!.onPressed!();
      expect(hit, isTrue);
    });
    test('information tones map 1:1', () {
      for (final (t, d) in [
        (InfoTone.info, DabblerToastTone.info),
        (InfoTone.warning, DabblerToastTone.warning),
        (InfoTone.neutral, DabblerToastTone.neutral),
      ]) {
        final spec = toastSpecFor(
          _e(FeedbackInformation(message: 'm', tone: t), FeedbackTarget.toast),
        )!;
        expect(spec.tone, d);
      }
    });
  });

  testWidgets('presenter hands each toast entry to the provider once', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final toasts = DabblerToastController();
    addTearDown(toasts.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: DabblerToastProvider(
            controller: toasts,
            child: const FeedbackToastPresenter(child: SizedBox.shrink()),
          ),
        ),
      ),
    );
    final center = container.read(feedbackCenterProvider.notifier);
    final id = center.begin(const FeedbackProcessing());
    expect(toasts.visible, isEmpty);
    center.succeed(id, const FeedbackResult.success('done'));
    center.inform(const FeedbackInformation(message: 'hi'));
    expect(toasts.visible.map((e) => e.spec.message), ['done', 'hi']);
    expect(container.read(feedbackCenterProvider).outbox, isEmpty);
    center.setSurface(ShellSurface.current);
    center.announce(const FeedbackResult.success('area'));
    expect(toasts.visible.length, 2);
  });
}
