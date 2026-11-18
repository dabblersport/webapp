// KAN-999 (G-05): the organiser's attendance list. Each roster row shows
// checked in / not / corrected (and, once final, its outcome). During the
// check-in window the list is read-only; after it each row can be changed
// with a reason shown to the player; Finalize locks it. Open review requests
// (G-06) show as the inbox's review card above the roster.

import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/utils/bidi_isolate.dart';
import 'package:dabbler/features/attendance/domain/attendance_list_models.dart';
import 'package:dabbler/features/attendance/presentation/attendance_correct_sheet.dart';
import 'package:dabbler/features/attendance/presentation/attendance_list_controller.dart';
import 'package:dabbler/features/attendance/presentation/attendance_review_card.dart';
import 'package:dabbler/features/attendance/presentation/check_in_screen.dart'
    show checkInClock;
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// The attendance RPC a refusal came from: each raises its own set.
enum AttendanceCall { correct, finalize, decide, requestReview }

/// The text for a refusal [f] (its server message) from [call]. The codes are
/// exactly those each RPC raises (kan994 migrations); any other is [fallback].
String attendanceRefusalText(
  AppLocalizations l,
  AttendanceCall call,
  Failure f,
  String fallback,
) {
  final String? text = switch ((call, f.code)) {
    (AttendanceCall.correct || AttendanceCall.finalize, 'window_not_closed') =>
      l.g05_err_window_not_closed,
    (
      AttendanceCall.correct || AttendanceCall.finalize,
      'attendance_finalized',
    ) =>
      l.g05_err_finalized,
    (AttendanceCall.correct || AttendanceCall.finalize, 'event_cancelled') =>
      l.g05_err_cancelled,
    (AttendanceCall.correct, 'not_a_participant') => l.g05_err_not_participant,
    (AttendanceCall.correct, 'reason_required') => l.g05_reason_required,
    (AttendanceCall.finalize, 'event_did_not_happen') =>
      l.g05_err_did_not_happen,
    (AttendanceCall.decide, 'no_open_review') => l.g06_err_already_decided,
    (
      AttendanceCall.correct ||
          AttendanceCall.finalize ||
          AttendanceCall.decide,
      'not_organiser',
    ) =>
      l.g05_not_organiser,
    (AttendanceCall.requestReview, 'review_window_closed') => l.g06_err_closed,
    (AttendanceCall.requestReview, 'no_pending_no_show') =>
      l.g06_err_no_pending,
    // invalid_mark, invalid_decision, not_authenticated: a client bug or a
    // lost session, not something the user can act on.
    _ => null,
  };
  return text ?? fallback;
}

void attendanceToast(BuildContext context, String message, {bool err = false}) {
  DabblerToastProvider.maybeOf(context)?.show(
    DabblerToastSpec(
      message: message,
      tone: err ? DabblerToastTone.error : DabblerToastTone.success,
    ),
  );
}

class AttendanceListScreen extends ConsumerStatefulWidget {
  const AttendanceListScreen({
    super.key,
    required this.eventId,
    this.title,
    this.onBack,
  });

  final String eventId;

  /// Shown as entered.
  final String? title;
  final VoidCallback? onBack;

  @override
  ConsumerState<AttendanceListScreen> createState() => _AttendanceListScreenState();
}

/// Every open reads the server again (KAN-999): a state kept from an earlier
/// visit is dropped, never shown.
class _AttendanceListScreenState extends ConsumerState<AttendanceListScreen> {
  bool _invalidated = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_invalidated) return;
    _invalidated = true;
    ref.invalidate(attendanceListProvider(widget.eventId));
  }

  @override
  Widget build(BuildContext context) => _AttendanceListScreenBody(
    eventId: widget.eventId,
    title: widget.title,
    onBack: widget.onBack,
  );
}

class _AttendanceListScreenBody extends ConsumerWidget {
  const _AttendanceListScreenBody({required this.eventId, this.title, this.onBack});

  final String eventId;
  final String? title;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final state = ref.watch(attendanceListProvider(eventId));
    final ctrl = ref.read(attendanceListProvider(eventId).notifier);
    final topBar = DabblerNavigationTopBar.titled(
      title: l.g05_title,
      onBack: onBack ?? () => context.pop(),
    );
    final list = state.list;
    if (list == null) {
      final f = state.loadFailure;
      return DabblerPage(
        topBar: topBar,
        body: f == null
            ? const Center(child: DabblerSpinner())
            : f.code == 'not_organiser'
            ? DabblerEmptyState(
                key: const ValueKey<String>('attendance-not-organiser'),
                icon: 'lock',
                title: l.g05_not_organiser,
              )
            : DabblerEmptyState.error(
                title: l.g05_load_failed,
                retryLabel: l.feed_retry,
                onRetry: ctrl.load,
              ),
      );
    }
    final phase = list.phaseAt(ref.watch(attendanceNowProvider)());
    final editable = phase == AttendanceListPhase.afterWindow;
    final reviews = <AttendanceRow>[
      for (final r in list.rows)
        if (r.reviewOpen || state.decisions.containsKey(r.userId)) r,
    ];

    Future<void> finalize() async {
      final f = await ctrl.finalize();
      if (!context.mounted || f?.code == 'busy') return;
      f == null
          ? attendanceToast(context, l.g05_finalized_toast)
          : attendanceToast(
              context,
              attendanceRefusalText(
                l,
                AttendanceCall.finalize,
                f,
                l.g05_failed,
              ),
              err: true,
            );
    }

    final String banner = switch (phase) {
      AttendanceListPhase.duringWindow => l.g05_during_window(
        checkInClock(context, list.closesAt),
      ),
      AttendanceListPhase.afterWindow => l.g05_after_window,
      AttendanceListPhase.finalized =>
        list.autoFinalized ? l.g05_auto_finalized : l.g05_finalized,
    };

    return DabblerPage(
      topBar: topBar,
      body: ListView(
        padding: DabblerInsets.screen,
        children: <Widget>[
          if (title != null && title!.isNotEmpty) ...<Widget>[
            DabblerText(context.isolate(title), style: DabblerType.title2),
            const DabblerGap.v(DabblerSpacing.space2),
          ],
          DabblerText(
            banner,
            key: ValueKey<String>('attendance-phase-${phase.name}'),
            style: DabblerType.footnote,
            tone: DabblerTextTone.secondary,
          ),
          const DabblerGap.v(DabblerSpacing.space6),
          for (final r in reviews) ...<Widget>[
            AttendanceReviewCard(
              row: r,
              decided: state.decisions[r.userId],
              busy: state.busy,
              onDecide: (accept) async {
                final f = await ctrl.decide(r.userId, accept: accept);
                if (!context.mounted || f == null || f.code == 'busy') return;
                attendanceToast(
                  context,
                  attendanceRefusalText(
                    l,
                    AttendanceCall.decide,
                    f,
                    l.g05_failed,
                  ),
                  err: true,
                );
              },
            ),
            const DabblerGap.v(DabblerSpacing.space4),
          ],
          if (list.rows.isEmpty)
            DabblerEmptyState(icon: 'people', title: l.g05_empty)
          else
            DabblerListGroup(
              children: <Widget>[
                for (final r in list.rows)
                  _row(
                    context,
                    l,
                    r,
                    editable ? () => _edit(context, ref, r) : null,
                  ),
              ],
            ),
          if (editable) ...<Widget>[
            const DabblerGap.v(DabblerSpacing.space8),
            DabblerButton(
              key: const ValueKey<String>('attendance-finalize'),
              label: l.g05_finalize,
              icon: 'lock',
              size: DabblerButtonSize.full,
              fullWidth: true,
              loading: state.busy,
              onPressed: state.busy ? null : finalize,
            ),
          ],
        ],
      ),
    );
  }

  Widget _row(
    BuildContext context,
    AppLocalizations l,
    AttendanceRow r,
    VoidCallback? onTap,
  ) {
    final name = r.displayName?.trim().isNotEmpty == true
        ? r.displayName!
        : l.g05_unknown_player;
    final (String label, DabblerBadgeTone tone) = switch (r.status) {
      AttendanceRowStatus.checkedIn => (
        l.g05_status_checked_in,
        DabblerBadgeTone.success,
      ),
      AttendanceRowStatus.notCheckedIn => (
        l.g05_status_not,
        DabblerBadgeTone.warning,
      ),
      AttendanceRowStatus.correctedAttended => (
        l.g05_status_corrected_attended,
        DabblerBadgeTone.primary,
      ),
      AttendanceRowStatus.correctedNoShow => (
        l.g05_status_corrected_no_show,
        DabblerBadgeTone.primary,
      ),
      AttendanceRowStatus.attended => (
        l.g05_status_attended,
        DabblerBadgeTone.success,
      ),
      AttendanceRowStatus.pendingReview => (
        l.g05_status_pending_review,
        DabblerBadgeTone.defaultTone,
      ),
      AttendanceRowStatus.reviewRequested => (
        l.g05_status_review_requested,
        DabblerBadgeTone.info,
      ),
      AttendanceRowStatus.noShowConfirmed => (
        l.g05_status_no_show_confirmed,
        DabblerBadgeTone.error,
      ),
      AttendanceRowStatus.notRecorded => (
        l.g05_status_not_recorded,
        DabblerBadgeTone.warning,
      ),
    };
    final reason = r.correctionReason;
    return DabblerListRow(
      key: ValueKey<String>('attendance-row-${r.userId}'),
      leading: DabblerAvatar(seed: name, size: DabblerAvatarSize.sm),
      title: context.isolate(name),
      subtitle: reason == null || reason.isEmpty
          ? (r.checkedInAt == null
                ? null
                : l.g04_checked_in_at(checkInClock(context, r.checkedInAt!)))
          : l.g05_reason_line(context.isolate(reason)),
      trailing: DabblerBadge(
        key: ValueKey<String>('attendance-chip-${r.userId}-${r.status.name}'),
        label: label,
        tone: tone,
      ),
      showChevron: onTap != null,
      onTap: onTap,
    );
  }

  Future<void> _edit(BuildContext context, WidgetRef ref, AttendanceRow r) =>
      showAttendanceCorrectSheet(
        context: context,
        row: r,
        onSave: (mark, reason) => ref
            .read(attendanceListProvider(eventId).notifier)
            .correct(r.userId, mark, reason),
      );
}
