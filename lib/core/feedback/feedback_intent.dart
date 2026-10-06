import 'package:flutter/foundation.dart';

/// The semantic feedback model (Action Area plan, APP_ARCHITECTURE.md §4).
///
/// Names carry a `Feedback` prefix because `Feedback` (Flutter material) and
/// `Result` (`lib/core/fp/result.dart`) are already taken in this codebase.

enum ProcessingKind { spinner, spinnerLabel, ring, indeterminate, determinate }

/// `neutral` is an announcement.
enum InfoTone { info, warning, neutral }

enum ResultKind { success, error }

/// Which presenter an entry was routed to. Set once, when the entry is
/// presented; an entry never has two.
enum FeedbackTarget {
  /// Not presented (Processing while the shell is absent).
  none,

  /// Waiting: the shell is current but blocked (create menu open).
  hold,

  /// The shell's Action Area.
  actionArea,

  /// The app-wide standard toast.
  toast,
}

/// `shell` survives tab switches; `page` is cleared on branch change.
enum FeedbackScope { shell, page }

@immutable
class FeedbackAction {
  const FeedbackAction({required this.label, required this.onPressed});
  final String label;
  final VoidCallback onPressed;
}

sealed class FeedbackState {
  const FeedbackState();
}

final class FeedbackIdle extends FeedbackState {
  const FeedbackIdle();
}

final class FeedbackProcessing extends FeedbackState {
  const FeedbackProcessing({
    this.kind = ProcessingKind.spinner,
    this.label,
    this.progress,
    this.cancellable = false,
    this.action,
  });

  final ProcessingKind kind;
  final String? label;

  /// 0..1, determinate only.
  final double? progress;

  /// Not rendered until the DS adds a Processing action (plan G2).
  final bool cancellable;
  final FeedbackAction? action;

  FeedbackProcessing withProgress(double value) => FeedbackProcessing(
    kind: ProcessingKind.determinate,
    label: label,
    progress: value.clamp(0, 1).toDouble(),
    cancellable: cancellable,
    action: action,
  );
}

final class FeedbackInformation extends FeedbackState {
  const FeedbackInformation({
    required this.message,
    this.tone = InfoTone.info,
    this.title,
    this.action,
    this.dismissible = true,
    this.duration,
  });

  final InfoTone tone;
  final String? title;
  final String message;
  final FeedbackAction? action;
  final bool dismissible;

  /// Null = presenter default; [Duration.zero] = sticky.
  final Duration? duration;
}

final class FeedbackResult extends FeedbackState {
  const FeedbackResult({
    required this.kind,
    required this.message,
    this.title,
    this.action,
    this.duration,
  });

  const FeedbackResult.success(this.message, {this.title, this.duration})
    : kind = ResultKind.success,
      action = null;

  const FeedbackResult.error(
    this.message, {
    this.title,
    this.action,
    this.duration,
  }) : kind = ResultKind.error;

  final ResultKind kind;
  final String? title;
  final String message;

  /// Error: Retry.
  final FeedbackAction? action;

  /// Null = presenter default; [Duration.zero] = sticky.
  final Duration? duration;

  /// An error with a Retry is sticky until handled (plan §6.5).
  bool get isSticky => kind == ResultKind.error && action != null;
}

/// One operation or event. [id] ties Processing -> progress -> Result together.
@immutable
class FeedbackEntry {
  const FeedbackEntry({
    required this.id,
    required this.state,
    required this.seq,
    this.dedupKey,
    this.scope = FeedbackScope.shell,
    this.target = FeedbackTarget.none,
  });

  final String id;
  final String? dedupKey;
  final FeedbackScope scope;
  final FeedbackState state;

  /// Arrival order; the priority tie-break.
  final int seq;
  final FeedbackTarget target;

  FeedbackEntry copyWith({FeedbackState? state, FeedbackTarget? target}) =>
      FeedbackEntry(
        id: id,
        dedupKey: dedupKey,
        scope: scope,
        state: state ?? this.state,
        seq: seq,
        target: target ?? this.target,
      );

  /// Plan §6: error > processing > success > warning > info/neutral.
  /// Lower is higher priority.
  int get priority => feedbackPriority(state);

  bool get isProcessing => state is FeedbackProcessing;
}

int feedbackPriority(FeedbackState s) => switch (s) {
  FeedbackResult(kind: ResultKind.error) => 0,
  FeedbackProcessing() => 1,
  FeedbackResult(kind: ResultKind.success) => 2,
  FeedbackInformation(tone: InfoTone.warning) => 3,
  FeedbackInformation() => 4,
  FeedbackIdle() => 5,
};
