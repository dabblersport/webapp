import 'package:dabbler/core/feedback/feedback_center.dart';
import 'package:dabbler/core/feedback/feedback_intent.dart';
import 'package:dabbler/core/feedback/presentation_context.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Maps the center's current entry onto the DS payload (APP_ARCHITECTURE.md
/// §3). Null for anything the Action Area does not present.
DabblerNavigationStatusPayload? navigationStatusPayloadFor(
  FeedbackEntry? entry,
) {
  if (entry == null) return null;
  if (entry.target != FeedbackTarget.actionArea &&
      entry.target != FeedbackTarget.hold) {
    return null;
  }
  return switch (entry.state) {
    FeedbackIdle() => null,
    FeedbackProcessing(
      :final kind,
      :final label,
      :final progress,
      :final action,
    ) =>
      DabblerNavigationStatusActivity(
        presentation: switch (kind) {
          ProcessingKind.spinner =>
            DabblerNavigationActivityPresentation.spinner,
          ProcessingKind.spinnerLabel =>
            DabblerNavigationActivityPresentation.spinnerLabel,
          ProcessingKind.ring => DabblerNavigationActivityPresentation.ring,
          ProcessingKind.indeterminate =>
            DabblerNavigationActivityPresentation.indeterminate,
          ProcessingKind.determinate =>
            DabblerNavigationActivityPresentation.progress,
        },
        label: label,
        value: kind == ProcessingKind.indeterminate ? null : progress,
        action: _action(action),
      ),
    FeedbackInformation(
      :final tone,
      :final title,
      :final message,
      :final action,
      :final dismissible,
      :final duration,
    ) =>
      DabblerNavigationStatusFeedback(
        DabblerNavigationFeedbackData(
          tone: switch (tone) {
            InfoTone.info => DabblerToastTone.info,
            InfoTone.warning => DabblerToastTone.warning,
            InfoTone.neutral => DabblerToastTone.neutral,
          },
          title: title,
          message: message,
          action: _action(action),
          dismissible: dismissible,
          duration: duration,
        ),
        // A sticky message needs its dismiss: the banner draws it.
        presentation: duration == Duration.zero
            ? DabblerNavigationFeedbackPresentation.banner
            : DabblerNavigationFeedbackPresentation.toast,
      ),
    final FeedbackResult r => DabblerNavigationStatusFeedback(
      DabblerNavigationFeedbackData(
        tone: r.kind == ResultKind.error
            ? DabblerToastTone.error
            : DabblerToastTone.success,
        title: r.title,
        message: r.message,
        action: _action(r.action),
        dismissible: r.isSticky,
        duration: r.isSticky ? Duration.zero : r.duration,
      ),
      // An error with Retry is sticky (plan §6.5): a banner, with dismiss.
      presentation: r.isSticky
          ? DabblerNavigationFeedbackPresentation.banner
          : DabblerNavigationFeedbackPresentation.toast,
    ),
  };
}

DabblerToastAction? _action(FeedbackAction? a) => a == null
    ? null
    : DabblerToastAction(label: a.label, onPressed: a.onPressed);

/// The shell's Action Area: the real bottom bar under one persistent
/// [DabblerNavigationStatus] surface, driven by [feedbackCenterProvider].
///
/// Publishes [ShellSurface] (current / blocked / absent) and the active
/// branch to the center; presents only entries the center routed to the
/// Action Area. With nothing to present it is the bar alone.
class ShellActionAreaHost extends ConsumerStatefulWidget {
  const ShellActionAreaHost({
    super.key,
    required this.bar,
    required this.createMenuOpen,
    required this.branchIndex,
    required this.dismissSemanticLabel,
  });

  final DabblerNavigationBottomBar bar;
  final bool createMenuOpen;
  final int branchIndex;
  final String dismissSemanticLabel;

  @override
  ConsumerState<ShellActionAreaHost> createState() =>
      _ShellActionAreaHostState();
}

class _ShellActionAreaHostState extends ConsumerState<ShellActionAreaHost> {
  late final FeedbackCenter _center;
  bool _routeCurrent = true;
  bool _publishScheduled = false;

  // The payload is cached per presented state object: a DS message is
  // identified by its data instance, so it must not be rebuilt per frame.
  FeedbackState? _forState;
  FeedbackTarget? _forTarget;
  DabblerNavigationStatusPayload? _payload;
  String? _payloadId;

  /// Mounted hosts; the shell has one, a remount briefly overlaps.
  static int _live = 0;

  @override
  void initState() {
    super.initState();
    _live++;
    _center = ref.read(feedbackCenterProvider.notifier);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _routeCurrent = ModalRoute.isCurrentOf(context) ?? true;
    _schedulePublish();
  }

  @override
  void didUpdateWidget(ShellActionAreaHost old) {
    super.didUpdateWidget(old);
    if (old.createMenuOpen != widget.createMenuOpen ||
        old.branchIndex != widget.branchIndex) {
      _schedulePublish();
    }
  }

  // Leaving the tree: absent. Deferred, because this happens while widgets
  // build or unmount and a provider cannot notify then. When the whole app
  // tree (and with it the container) is going away, the write lands on a
  // disposed center with no listeners, which is harmless.
  @override
  void dispose() {
    final center = _center;
    _live--;
    Future.microtask(() {
      // A host that mounted meanwhile owns the surface now.
      if (_live == 0) center.setSurface(ShellSurface.absent);
    });
    super.dispose();
  }

  ShellSurface get _surface => !_routeCurrent
      ? ShellSurface.absent
      : widget.createMenuOpen
      ? ShellSurface.blocked
      : ShellSurface.current;

  /// Providers cannot change while widgets build: publish after the frame.
  void _schedulePublish() {
    if (_publishScheduled) return;
    _publishScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _publishScheduled = false;
      if (!mounted) return;
      _center.setBranch(widget.branchIndex);
      _center.setSurface(_surface);
    });
  }

  void _onDone(DabblerNavigationStatusEndReason reason) {
    final id = _payloadId;
    final shown = _forState;
    if (id == null) return;
    final cur = ref.read(feedbackCenterProvider).current;
    // The entry already moved on (Retry re-began it in place, or a newer
    // state replaced it): nothing of ours ended.
    if (cur == null || cur.id != id || !identical(cur.state, shown)) return;
    switch (reason) {
      case DabblerNavigationStatusEndReason.timeout:
      case DabblerNavigationStatusEndReason.action:
        _center.consumed(id);
      case DabblerNavigationStatusEndReason.dismissed:
        _center.dismiss(id);
      case DabblerNavigationStatusEndReason.replaced:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final entry = ref.watch(feedbackCenterProvider.select((s) => s.current));
    if (entry == null ||
        !identical(entry.state, _forState) ||
        entry.target != _forTarget) {
      final next = navigationStatusPayloadFor(entry);
      // Hold -> actionArea for the same state keeps the same payload object.
      final same =
          entry != null &&
          identical(entry.state, _forState) &&
          _payload != null;
      _payload = next == null ? null : (same ? _payload : next);
      _forState = entry?.state;
      _forTarget = entry?.target;
      _payloadId = next == null ? null : entry?.id;
    }
    return DabblerNavigationStatus(
      bar: widget.bar,
      payload: _payload,
      suspended: widget.createMenuOpen,
      onDone: _onDone,
      dismissSemanticLabel: widget.dismissSemanticLabel,
    );
  }
}
