import 'package:dabbler/core/feedback/feedback_center.dart';
import 'package:dabbler/core/feedback/feedback_intent.dart';
import 'package:dabbler/core/feedback/shell_toast_bridge.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Maps a toast-targeted entry onto today's standard toast. Returns null for
/// anything that is not toast-presentable (Processing, Idle, or an entry
/// routed to another presenter) — the one-presenter guarantee.
DabblerToastSpec? toastSpecFor(FeedbackEntry entry) {
  if (entry.target != FeedbackTarget.toast) return null;
  return switch (entry.state) {
    FeedbackInformation(
      :final message,
      :final tone,
      :final action,
      :final duration,
    ) =>
      DabblerToastSpec(
        message: message,
        tone: switch (tone) {
          InfoTone.info => DabblerToastTone.info,
          InfoTone.warning => DabblerToastTone.warning,
          InfoTone.neutral => DabblerToastTone.neutral,
        },
        action: _action(action),
        duration: duration ?? DabblerToastSpec.defaultDuration,
      ),
    final FeedbackResult r => DabblerToastSpec(
      message: r.message,
      tone: r.kind == ResultKind.error
          ? DabblerToastTone.error
          : DabblerToastTone.success,
      action: _action(r.action),
      duration:
          r.duration ??
          (r.isSticky
              ? DabblerToastSpec.sticky
              : DabblerToastSpec.defaultDuration),
    ),
    FeedbackProcessing() || FeedbackIdle() => null,
  };
}

DabblerToastAction? _action(FeedbackAction? a) => a == null
    ? null
    : DabblerToastAction(label: a.label, onPressed: a.onPressed);

/// Hands every toast-targeted entry to the existing app-wide
/// [DabblerToastProvider], exactly as call sites do today. Mount it inside
/// the provider. Renders [child] unchanged.
class FeedbackToastPresenter extends ConsumerWidget {
  const FeedbackToastPresenter({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<FeedbackCenterState>(feedbackCenterProvider, (_, next) {
      if (next.outbox.isEmpty) return;
      final toasts = DabblerToastProvider.maybeOf(context);
      final center = ref.read(feedbackCenterProvider.notifier);
      for (final entry in [...next.outbox]) {
        final spec = toastSpecFor(entry);
        if (spec != null) {
          // Already routed to the toast: never re-route it to the shell.
          if (toasts is ShellAwareToastController) {
            toasts.showStandard(spec);
          } else {
            toasts?.show(spec);
          }
        }
        center.delivered(entry.id);
      }
    });
    return child;
  }
}
