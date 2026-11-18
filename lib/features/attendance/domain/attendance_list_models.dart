// KAN-999 (G-05, G-06): the organiser's attendance list, read from
// rpc_attendance_list, and the player's no-show state, read from
// rpc_attendance_my.

import 'package:dabbler/core/utils/instant.dart';
import 'package:flutter/foundation.dart';

/// What one roster row shows in its status chip.
enum AttendanceRowStatus {
  /// Checked in by the player and not changed since.
  checkedIn,

  /// No check-in and no correction.
  notCheckedIn,

  /// The organiser marked attended (with a reason).
  correctedAttended,

  /// The organiser marked no-show (with a reason).
  correctedNoShow,

  // After finalize: the row's outcome.
  attended,
  pendingReview,
  reviewRequested,
  noShowConfirmed,

  /// Auto-finalized with no check-in: not counted either way.
  notRecorded,
}

/// One row of `rpc_attendance_list`.
@immutable
class AttendanceRow {
  const AttendanceRow({
    required this.userId,
    this.displayName,
    this.checkedInAt,
    this.mark,
    this.markMethod,
    this.correctionReason,
    this.outcome,
    this.reviewRequestedAt,
    this.reviewNote,
    this.reviewDeadline,
    this.noShowDeadline,
    this.finalized = false,
  });

  final String userId;
  final String? displayName;
  final DateTime? checkedInAt;

  /// `attended` | `no_show` | null.
  final String? mark;

  /// `self` | `organiser` | null.
  final String? markMethod;
  final String? correctionReason;

  /// Null until finalized; then `attended`, `no_show_pending`,
  /// `no_show_review`, `no_show_confirmed` or `unknown`.
  final String? outcome;
  final DateTime? reviewRequestedAt;
  final String? reviewNote;
  final DateTime? reviewDeadline;
  final DateTime? noShowDeadline;
  final bool finalized;

  bool get corrected => markMethod == 'organiser';

  /// The player asked for a review the organiser has not decided.
  bool get reviewOpen => outcome == 'no_show_review';

  AttendanceRowStatus get status {
    switch (outcome) {
      case 'attended':
        return AttendanceRowStatus.attended;
      case 'no_show_pending':
        return AttendanceRowStatus.pendingReview;
      case 'no_show_review':
        return AttendanceRowStatus.reviewRequested;
      case 'no_show_confirmed':
        return AttendanceRowStatus.noShowConfirmed;
      case 'unknown':
        return AttendanceRowStatus.notRecorded;
    }
    if (corrected) {
      return mark == 'attended'
          ? AttendanceRowStatus.correctedAttended
          : AttendanceRowStatus.correctedNoShow;
    }
    return checkedInAt != null || mark == 'attended'
        ? AttendanceRowStatus.checkedIn
        : AttendanceRowStatus.notCheckedIn;
  }

  factory AttendanceRow.fromJson(Map<String, dynamic> j) => AttendanceRow(
    userId: j['user_id'] as String,
    displayName: j['display_name'] as String?,
    checkedInAt: parseInstantLocal(j['checked_in_at']),
    mark: j['mark'] as String?,
    markMethod: j['mark_method'] as String?,
    correctionReason: j['correction_reason'] as String?,
    outcome: j['outcome'] as String?,
    reviewRequestedAt: parseInstantLocal(j['review_requested_at']),
    reviewNote: j['review_note'] as String?,
    reviewDeadline: parseInstantLocal(j['review_deadline']),
    noShowDeadline: parseInstantLocal(j['no_show_deadline']),
    finalized: j['finalized'] == true,
  );
}

/// The G-05 states of the list as a whole.
enum AttendanceListPhase {
  /// Before or during the check-in window: read-only.
  duringWindow,

  /// The window closed, not finalized: each row can be corrected.
  afterWindow,

  /// Locked.
  finalized,
}

/// The list and the window it depends on.
@immutable
class AttendanceList {
  const AttendanceList({required this.rows, required this.closesAt});

  final List<AttendanceRow> rows;

  /// The check-in window's close (15 minutes after the start).
  final DateTime closesAt;

  bool get finalized => rows.any((r) => r.finalized);

  /// Finalized with no organiser decision: every row without a check-in is
  /// `unknown` (the 24h auto-finalize).
  bool get autoFinalized =>
      finalized &&
      rows.any((r) => r.outcome == 'unknown') &&
      !rows.any((r) => (r.outcome ?? '').startsWith('no_show'));

  AttendanceListPhase phaseAt(DateTime now) {
    if (finalized) return AttendanceListPhase.finalized;
    return now.isAfter(closesAt)
        ? AttendanceListPhase.afterWindow
        : AttendanceListPhase.duringWindow;
  }
}

/// The G-06 states of the player's no-show.
enum NoShowPhase {
  /// Marked no-show; the 48h to ask for a review is running.
  pending,

  /// The player asked; the organiser decides.
  reviewRequested,

  /// The organiser accepted: counted as attended.
  accepted,

  /// No answer in 48h: accepted in the player's favour.
  expiredAccepted,

  /// The organiser kept the no-show.
  kept,

  /// 48h passed without a request: confirmed.
  confirmed,

  /// Auto-finalized: not counted either way.
  notRecorded,

  /// Attended, or nothing to review.
  none,
}

/// The no-show part of one `rpc_attendance_my` answer.
@immutable
class NoShowStatus {
  const NoShowStatus({
    required this.phase,
    this.reason,
    this.noShowDeadline,
    this.reviewDeadline,
  });

  final NoShowPhase phase;

  /// The organiser's reason, shown to the player.
  final String? reason;
  final DateTime? noShowDeadline;
  final DateTime? reviewDeadline;

  factory NoShowStatus.fromJson(Map<String, dynamic> j) {
    final outcome = j['outcome'] as String?;
    final decision = j['review_decision'] as String?;
    final phase = switch (outcome) {
      'no_show_pending' => NoShowPhase.pending,
      'no_show_review' => NoShowPhase.reviewRequested,
      'no_show_confirmed' =>
        decision == 'kept' ? NoShowPhase.kept : NoShowPhase.confirmed,
      'attended' => switch (decision) {
        'accepted' => NoShowPhase.accepted,
        'expired_accepted' => NoShowPhase.expiredAccepted,
        _ => NoShowPhase.none,
      },
      'unknown' => NoShowPhase.notRecorded,
      _ => NoShowPhase.none,
    };
    return NoShowStatus(
      phase: phase,
      reason: j['correction_reason'] as String?,
      noShowDeadline: parseInstantLocal(j['no_show_deadline']),
      reviewDeadline: parseInstantLocal(j['review_deadline']),
    );
  }

  NoShowStatus copyWith({NoShowPhase? phase, DateTime? reviewDeadline}) =>
      NoShowStatus(
        phase: phase ?? this.phase,
        reason: reason,
        noShowDeadline: noShowDeadline,
        reviewDeadline: reviewDeadline ?? this.reviewDeadline,
      );
}

/// Whole hours left until [deadline], at least 1 while it has not passed.
int hoursLeft(DateTime deadline, DateTime now) {
  final m = deadline.difference(now).inMinutes;
  if (m <= 0) return 0;
  return (m + 59) ~/ 60;
}
