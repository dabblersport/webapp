// KAN-1000 (G-03): the organiser's final score entry, reached by Reject or
// from the tie. Two steppers and Confirm; the deadline is shown in the
// device's 12/24h format. Success pops with true; a refusal keeps the screen
// and says why (and the tally behind it is re-read). Anyone but the
// organiser (is_organiser from rpc_result_get) gets a read-only notice with
// no steppers; a failed read offers a retry.

import 'package:dabbler/core/utils/bidi_isolate.dart';
import 'package:dabbler/features/post_activity/domain/post_activity_models.dart';
import 'package:dabbler/features/post_activity/presentation/post_activity_screen.dart'
    show postActivityError, postActivityToast;
import 'package:dabbler/features/post_activity/presentation/result_approval_controller.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

String _clock(BuildContext context, DateTime t) {
  final locale = Localizations.localeOf(context).toLanguageTag();
  final f = MediaQuery.alwaysUse24HourFormatOf(context)
      ? DateFormat.Hm(locale)
      : DateFormat.jm(locale);
  return DabblerType.toWesternDigits(f.format(t));
}

class FinalScoreScreen extends ConsumerStatefulWidget {
  const FinalScoreScreen({
    super.key,
    required this.eventId,
    this.title,
    this.onDone,
  });

  final String eventId;
  final String? title;

  /// Called on success; defaults to popping with true.
  final VoidCallback? onDone;

  @override
  ConsumerState<FinalScoreScreen> createState() => _FinalScoreScreenState();
}

class _FinalScoreScreenState extends ConsumerState<FinalScoreScreen> {
  Score? _score;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final state = ref.watch(resultApprovalProvider(widget.eventId));
    final ctrl = ref.read(resultApprovalProvider(widget.eventId).notifier);
    final t = state.tally;
    final score = _score ?? t?.provisional ?? const Score(0, 0);
    final topBar = DabblerNavigationTopBar.titled(
      title: widget.title != null && widget.title!.isNotEmpty
          ? context.isolate(widget.title)
          : l.g03f_title,
      onBack: () => context.pop(),
    );
    if (t == null) {
      return DabblerPage(
        topBar: topBar,
        body: state.loadFailure == null || state.loading
            ? const Center(child: DabblerSpinner())
            : DabblerEmptyState.error(
                key: const ValueKey<String>('g03f-load-failed'),
                title: l.g02_load_failed,
                retryLabel: l.feed_retry,
                onRetry: ctrl.load,
              ),
      );
    }
    if (!t.isOrganiser) {
      return DabblerPage(
        topBar: topBar,
        body: Center(
          child: DabblerEmptyState(
            key: const ValueKey<String>('g03f-organiser-only'),
            icon: 'lock',
            title: l.g03f_organiser_only,
            text: l.g03f_organiser_only_body,
          ),
        ),
      );
    }
    final waiting = t.competitive && t.state == ResultState.waiting;
    final open = t.competitive && !t.state.isFinal && !waiting;

    Future<void> confirm() async {
      final f = await ctrl.setFinal(score);
      if (!context.mounted || f?.code == 'busy') return;
      if (f != null) {
        postActivityToast(context, postActivityError(l, f), err: true);
        return;
      }
      postActivityToast(context, l.g03f_saved);
      if (widget.onDone != null) {
        widget.onDone!();
      } else {
        context.pop(true);
      }
    }

    return DabblerPage(
      topBar: topBar,
      body: ListView(
        key: const ValueKey<String>('g03-final-screen'),
        padding: DabblerInsets.screen,
        children: [
          DabblerText(l.g03f_title, style: DabblerType.title3),
          const DabblerGap.v(DabblerSpacing.space1),
          DabblerText(l.g03f_body, tone: DabblerTextTone.secondary),
          if (t.deadlineAt != null) ...[
            const DabblerGap.v(DabblerSpacing.space2),
            DabblerText(
              l.g03f_deadline(_clock(context, t.deadlineAt!)),
              key: const ValueKey<String>('g03f-deadline'),
              tone: DabblerTextTone.secondary,
            ),
          ],
          const DabblerGap.v(DabblerSpacing.space5),
          DabblerStepper(
            key: const ValueKey<String>('g03f-a'),
            label: l.g02_side_a,
            value: score.a,
            max: 999,
            disabled: !open || state.busy,
            onChanged: (v) => setState(() => _score = Score(v, score.b)),
          ),
          const DabblerGap.v(DabblerSpacing.space3),
          DabblerStepper(
            key: const ValueKey<String>('g03f-b'),
            label: l.g02_side_b,
            value: score.b,
            max: 999,
            disabled: !open || state.busy,
            onChanged: (v) => setState(() => _score = Score(score.a, v)),
          ),
          const DabblerGap.v(DabblerSpacing.space6),
          if (open)
            DabblerButton(
              key: const ValueKey<String>('g03f-confirm'),
              label: l.g03f_confirm,
              fullWidth: true,
              loading: state.busy,
              onPressed: confirm,
            )
          else if (waiting)
            DabblerBanner(
              key: const ValueKey<String>('g03f-waiting'),
              title: l.g03f_waiting,
              message: l.g03f_waiting_body,
            )
          else
            DabblerBanner(title: l.g02_err_result_final),
        ],
      ),
    );
  }
}
