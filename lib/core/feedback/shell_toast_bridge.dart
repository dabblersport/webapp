import 'package:dabbler/core/feedback/feedback_center.dart';
import 'package:dabbler/core/feedback/feedback_intent.dart';
import 'package:dabbler/core/feedback/presentation_context.dart';
import 'package:dabbler/core/feedback/toast_presenter.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Maps a standard toast onto a feedback intent with the same text and tone.
FeedbackState feedbackFromToastSpec(DabblerToastSpec spec) {
  final action = spec.action?.onPressed == null
      ? null
      : FeedbackAction(
          label: spec.action!.label,
          onPressed: spec.action!.onPressed!,
        );
  final duration = spec.duration == DabblerToastSpec.defaultDuration
      ? null
      : spec.duration;
  return switch (spec.tone) {
    DabblerToastTone.success => FeedbackResult(
      kind: ResultKind.success,
      message: spec.message,
      action: action,
      duration: duration,
    ),
    DabblerToastTone.error => FeedbackResult(
      kind: ResultKind.error,
      message: spec.message,
      action: action,
      duration: duration,
    ),
    DabblerToastTone.warning => FeedbackInformation(
      message: spec.message,
      tone: InfoTone.warning,
      action: action,
      duration: duration,
    ),
    DabblerToastTone.info => FeedbackInformation(
      message: spec.message,
      action: action,
      duration: duration,
    ),
    _ => FeedbackInformation(
      message: spec.message,
      tone: InfoTone.neutral,
      action: action,
      duration: duration,
    ),
  };
}

/// The app's one toast queue, made shell-aware: every existing
/// `DabblerToastProvider.of(context).show(...)` call is decided by the shell
/// surface **at presentation time** (Action Area plan, commit 4).
///
/// * Shell current (or held behind the create menu): the toast becomes an
///   Information/Result on the [FeedbackCenter] and the Action Area presents
///   it. It is not also shown as a toast.
/// * Shell absent (internal route, sheet or dialog over it): the standard
///   toast, exactly as before.
///
/// A call made while the shell is still covered — typically right after a
/// dialog or sheet pops — is decided after that frame, once the shell host
/// has published its surface, so a result raised as the dialog closes lands
/// in the Action Area.
class ShellAwareToastController extends DabblerToastController {
  ShellAwareToastController({required this.readState, required this.center});

  final FeedbackCenterState Function() readState;
  final FeedbackCenter Function() center;
  int _ids = 0;
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  bool get _shellUp => readState().surface != ShellSurface.absent;

  @override
  String show(DabblerToastSpec spec) {
    if (_shellUp) return _toCenter(spec);
    final id = spec.id ?? 'shell-toast-${++_ids}';
    final keyed = DabblerToastSpec(
      message: spec.message,
      id: id,
      tone: spec.tone,
      action: spec.action,
      duration: spec.duration,
      icon: spec.icon,
    );
    final binding = SchedulerBinding.instance;
    // After the frame's post-frame callbacks (where the host publishes).
    binding.addPostFrameCallback((_) {
      Future.microtask(() {
        if (_disposed) return;
        if (_shellUp) {
          _toCenter(keyed);
        } else {
          super.show(keyed);
        }
      });
    });
    binding.scheduleFrame();
    return id;
  }

  /// The standard toast, never re-routed: for entries the center already
  /// routed to the toast presenter.
  String showStandard(DabblerToastSpec spec) => super.show(spec);

  String _toCenter(DabblerToastSpec spec) {
    final c = center();
    return switch (feedbackFromToastSpec(spec)) {
      final FeedbackResult r => c.announce(r),
      final FeedbackInformation i => c.inform(i),
      _ => '',
    };
  }
}

/// [DabblerToastProvider] over a [ShellAwareToastController], with the
/// center's toast presenter inside it. Mount once, above the router.
class ShellAwareToastProvider extends ConsumerStatefulWidget {
  const ShellAwareToastProvider({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<ShellAwareToastProvider> createState() =>
      _ShellAwareToastProviderState();
}

class _ShellAwareToastProviderState
    extends ConsumerState<ShellAwareToastProvider> {
  late final ShellAwareToastController _controller = ShellAwareToastController(
    readState: () => ref.read(feedbackCenterProvider),
    center: () => ref.read(feedbackCenterProvider.notifier),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => DabblerToastProvider(
    controller: _controller,
    child: FeedbackToastPresenter(child: widget.child),
  );
}
