// KAN-1000 (G-03): the organiser's approval of the majority result. States:
// waiting for submissions, majority ready ("6 of 8 said 4 – 3", the spread
// of the other values, 24h countdown), approved, rejected (final entered),
// 24h passed (auto-confirmed), tie / no majority (final entry with the
// countdown, "closes with no result" if missed), closed with no result.
// Reject and the tie open the final score screen. A player sees the same
// tally read-only, with no action.

import 'package:dabbler/core/utils/bidi_isolate.dart';
import 'package:dabbler/features/post_activity/domain/post_activity_models.dart';
import 'package:dabbler/features/post_activity/presentation/post_activity_controller.dart'
    show postActivityNowProvider;
import 'package:dabbler/features/post_activity/presentation/post_activity_screen.dart'
    show postActivityError, postActivityToast;
import 'package:dabbler/features/post_activity/presentation/post_activity_steps.dart'
    show scoreText;
import 'package:dabbler/features/post_activity/presentation/result_approval_controller.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class ResultApprovalScreen extends ConsumerWidget {
  const ResultApprovalScreen({
    super.key,
    required this.eventId,
    this.title,
    this.onBack,
    this.onEnterFinal,
  });

  final String eventId;
  final String? title;
  final VoidCallback? onBack;

  /// Opens the final score screen; defaults to pushing its route.
  final Future<void> Function()? onEnterFinal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final state = ref.watch(resultApprovalProvider(eventId));
    final ctrl = ref.read(resultApprovalProvider(eventId).notifier);
    final topBar = DabblerNavigationTopBar.titled(
      title: title != null && title!.isNotEmpty
          ? context.isolate(title)
          : l.g03_title,
      onBack: onBack ?? () => context.pop(),
    );
    final t = state.tally;
    if (t == null) {
      return DabblerPage(
        topBar: topBar,
        body: state.loadFailure == null
            ? const Center(child: DabblerSpinner())
            : DabblerEmptyState.error(
                title: state.loadFailure!.code == 'not_eligible'
                    ? l.g02_err_not_eligible
                    : l.g02_load_failed,
                retryLabel: l.feed_retry,
                onRetry: ctrl.load,
              ),
      );
    }
    if (!t.competitive) {
      return DabblerPage(
        topBar: topBar,
        body: Center(
          child: DabblerEmptyState(
            key: const ValueKey<String>('g03-non-competitive'),
            icon: 'info-circle',
            title: l.g03_non_competitive,
          ),
        ),
      );
    }
    final now = ref.watch(postActivityNowProvider)();
    final hours = t.deadlineAt == null ? 0 : hoursUntil(t.deadlineAt!, now);
    final org = t.isOrganiser;

    Future<void> enterFinal() async {
      if (state.busy) return;
      if (onEnterFinal != null) {
        await onEnterFinal!();
      } else {
        await context.push<bool>(RoutePaths.resultFinal(eventId, title: title));
      }
      await ctrl.load();
    }

    Future<void> approve() async {
      final f = await ctrl.approve();
      if (!context.mounted || f?.code == 'busy') return;
      if (f == null) {
        postActivityToast(context, l.g03_approved_toast);
      } else {
        postActivityToast(context, postActivityError(l, f), err: true);
      }
    }

    final finalText = t.finalScore == null ? '' : scoreText(t.finalScore!);
    final children = <Widget>[
      ...switch (t.state) {
        ResultState.waiting => [
          _head(
            'g03-waiting',
            l.g03_waiting,
            l.g03_waiting_body(t.submissions, t.eligible),
          ),
          if (t.eligible > 0)
            DabblerProgressBar(value: t.submissions / t.eligible),
        ],
        ResultState.majorityReady => [
          _head(
            'g03-majority',
            l.g03_majority(t.votes, t.submissions, scoreText(t.provisional!)),
            l.g03_confirms_in(hours),
          ),
          if (t.submissions > 0)
            DabblerProgressBar(value: t.votes / t.submissions),
          ..._spread(l, t, skip: t.provisional),
          if (org) ...[
            const DabblerGap.v(DabblerSpacing.space5),
            DabblerButton(
              key: const ValueKey<String>('g03-approve'),
              label: l.g03_approve,
              fullWidth: true,
              loading: state.busy,
              onPressed: approve,
            ),
            const DabblerGap.v(DabblerSpacing.space2),
            DabblerButton(
              key: const ValueKey<String>('g03-reject'),
              label: l.g03_reject,
              tone: DabblerButtonTone.secondary,
              fullWidth: true,
              disabled: state.busy,
              onPressed: enterFinal,
            ),
          ],
        ],
        ResultState.tie => [
          _head('g03-tie', l.g03_tie, l.g03_tie_body(hours)),
          ..._spread(l, t),
          if (org) ...[
            const DabblerGap.v(DabblerSpacing.space5),
            DabblerButton(
              key: const ValueKey<String>('g03-enter-final'),
              label: l.g03_enter_final,
              fullWidth: true,
              disabled: state.busy,
              onPressed: enterFinal,
            ),
          ],
        ],
        ResultState.approved => [
          _head('g03-approved', l.g03_approved, l.g03_final_body(finalText)),
        ],
        ResultState.rejected => [
          _head('g03-rejected', l.g03_rejected, l.g03_final_body(finalText)),
        ],
        ResultState.autoConfirmed => [
          _head('g03-auto', l.g03_auto, l.g03_final_body(finalText)),
        ],
        ResultState.closedNoResult => [
          _head(
            'g03-closed',
            l.g03_closed_no_result,
            l.g03_closed_no_result_body,
          ),
        ],
      },
      if (!org && !t.state.isFinal) ...[
        const DabblerGap.v(DabblerSpacing.space4),
        DabblerText(l.g03_player_note, tone: DabblerTextTone.secondary),
      ],
    ];
    return DabblerPage(
      topBar: topBar,
      body: ListView(padding: DabblerInsets.screen, children: children),
    );
  }

  Widget _head(String key, String title, String body) => Padding(
    key: ValueKey<String>(key),
    padding: const EdgeInsetsDirectional.only(bottom: DabblerSpacing.space3),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DabblerText(title, style: DabblerType.title3),
        const DabblerGap.v(DabblerSpacing.space1),
        DabblerText(body, tone: DabblerTextTone.secondary),
      ],
    ),
  );

  List<Widget> _spread(AppLocalizations l, ResultTally t, {Score? skip}) {
    final rest = [
      for (final s in t.spread)
        if (s != skip) s,
    ];
    if (rest.isEmpty) return const [];
    return [
      const DabblerGap.v(DabblerSpacing.space4),
      DabblerText(l.g03_spread, weight: DabblerTextWeight.semibold),
      const DabblerGap.v(DabblerSpacing.space2),
      for (final s in rest)
        Padding(
          padding: const EdgeInsetsDirectional.only(
            bottom: DabblerSpacing.space2,
          ),
          child: DabblerProgressBar(
            key: ValueKey<String>('g03-spread-${s.a}-${s.b}'),
            value: t.submissions == 0 ? 0 : s.votes / t.submissions,
            label: l.g03_spread_row(scoreText(s), s.votes),
          ),
        ),
    ];
  }
}
