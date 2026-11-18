// KAN-999 (G-06 player side): "Marked as not attended · Confirms in 47h
// unless you ask for a review", Request review (sheet with an optional note),
// and the outcomes: review requested, accepted, kept, 48h passed (confirmed),
// unanswered review accepted, and auto-finalized (not recorded). Opened from
// the no-show and review notices. The card is the inbox's card (W1-F2).

import 'package:dabbler/core/utils/bidi_isolate.dart';
import 'package:dabbler/features/attendance/domain/attendance_list_models.dart';
import 'package:dabbler/features/attendance/presentation/attendance_list_controller.dart'
    show attendanceNowProvider;
import 'package:dabbler/features/attendance/presentation/attendance_list_screen.dart'
    show attendanceToast;
import 'package:dabbler/features/attendance/presentation/no_show_controller.dart';
import 'package:dabbler/features/attendance/presentation/review_request_sheet.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class NoShowScreen extends ConsumerStatefulWidget {
  const NoShowScreen({
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
  ConsumerState<NoShowScreen> createState() => _NoShowScreenState();
}

/// Every open reads the server again (KAN-999): a state kept from an earlier
/// visit is dropped, never shown.
class _NoShowScreenState extends ConsumerState<NoShowScreen> {
  bool _invalidated = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_invalidated) return;
    _invalidated = true;
    ref.invalidate(noShowProvider(widget.eventId));
  }

  @override
  Widget build(BuildContext context) => _NoShowScreenBody(
    eventId: widget.eventId,
    title: widget.title,
    onBack: widget.onBack,
  );
}

class _NoShowScreenBody extends ConsumerWidget {
  const _NoShowScreenBody({required this.eventId, this.title, this.onBack});

  final String eventId;
  final String? title;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final state = ref.watch(noShowProvider(eventId));
    final ctrl = ref.read(noShowProvider(eventId).notifier);
    final topBar = DabblerNavigationTopBar.titled(
      title: l.g05_title,
      onBack: onBack ?? () => context.pop(),
    );
    final s = state.status;
    if (s == null) {
      return DabblerPage(
        topBar: topBar,
        body: state.loadFailure == null
            ? const Center(child: DabblerSpinner())
            : DabblerEmptyState.error(
                title: l.g05_load_failed,
                retryLabel: l.feed_retry,
                onRetry: ctrl.load,
              ),
      );
    }
    final now = ref.watch(attendanceNowProvider)();
    var phase = s.phase;
    // The 48h ran out before the sweep confirmed it: show it as confirmed.
    if (phase == NoShowPhase.pending &&
        s.noShowDeadline != null &&
        hoursLeft(s.noShowDeadline!, now) == 0) {
      phase = NoShowPhase.confirmed;
    }
    final head = title != null && title!.isNotEmpty
        ? context.isolate(title)
        : l.g05_title;
    final reason = s.reason == null || s.reason!.isEmpty
        ? null
        : l.g06_organiser_reason(context.isolate(s.reason));

    Future<void> request() async {
      final sent = await showReviewRequestSheet(
        context: context,
        onSend: ctrl.requestReview,
      );
      if (!context.mounted || sent != true) return;
      attendanceToast(context, l.g06_requested);
    }

    final Widget card = switch (phase) {
      NoShowPhase.pending => DabblerNotificationCard(
        key: const ValueKey<String>('no-show-pending'),
        leading: const DabblerNotificationIconTile(
          icon: 'calendar-remove',
          tone: DabblerNotificationTone.warn,
        ),
        actor: head,
        verb: l.g06_marked,
        unread: true,
        sub: l.g06_confirms_in(hoursLeft(s.noShowDeadline ?? now, now)),
        meta: <DabblerNotificationMeta>[
          if (reason != null) DabblerNotificationMeta('message-text', reason),
        ],
        pending: state.sending ? l.g06_sending : null,
        actions: state.sending
            ? const <DabblerNotificationCardAction>[]
            : <DabblerNotificationCardAction>[
                DabblerNotificationCardAction(
                  l.g06_request,
                  primary: true,
                  onPressed: request,
                ),
              ],
      ),
      _ => _outcome(context, l, s, phase, head, now),
    };
    return DabblerPage(
      topBar: topBar,
      body: ListView(padding: DabblerInsets.screen, children: <Widget>[card]),
    );
  }

  Widget _outcome(
    BuildContext context,
    AppLocalizations l,
    NoShowStatus s,
    NoShowPhase phase,
    String head,
    DateTime now,
  ) {
    final (
      String icon,
      DabblerNotificationTone tone,
      String text,
      String body,
    ) = switch (phase) {
      NoShowPhase.reviewRequested => (
        'clock',
        DabblerNotificationTone.info,
        l.g06_requested,
        l.g06_requested_body(hoursLeft(s.reviewDeadline ?? now, now)),
      ),
      NoShowPhase.accepted => (
        'tick-circle',
        DabblerNotificationTone.ok,
        l.g06_accepted,
        l.g06_accepted_body,
      ),
      NoShowPhase.expiredAccepted => (
        'tick-circle',
        DabblerNotificationTone.ok,
        l.g06_accepted,
        l.g06_expired_body,
      ),
      NoShowPhase.kept => (
        'close-circle',
        DabblerNotificationTone.neutral,
        l.g06_kept,
        l.g06_kept_body,
      ),
      NoShowPhase.confirmed => (
        'close-circle',
        DabblerNotificationTone.neutral,
        l.g06_confirmed,
        l.g06_confirmed_body,
      ),
      NoShowPhase.notRecorded => (
        'info-circle',
        DabblerNotificationTone.neutral,
        l.g06_not_recorded,
        l.g06_not_recorded_body,
      ),
      _ => ('info-circle', DabblerNotificationTone.neutral, l.g06_none, ''),
    };
    return DabblerNotificationCard(
      key: ValueKey<String>('no-show-${phase.name}'),
      leading: DabblerNotificationIconTile(icon: icon, tone: tone),
      actor: head,
      verb: text,
      sub: body.isEmpty ? null : body,
      result: DabblerNotificationResult(icon: icon, text: text, tone: tone),
    );
  }
}
