// KAN-1000 (G-02): the post-activity flow, opened from its notices
// (activity.post_activity, activity.rating_reminder) or the "Rate and score"
// line in the game and meetup detail (PostActivityEntry). Dismiss calls
// rpc_rating_dismiss and stops the prompts. States: not started, partly saved (resumes), submitted ("waiting
// for others" with the count), closed after 48h (read-only), not eligible
// (from finalized attendance), not open yet. Non-competitive events have no
// score step. Players do not dispute: there is no dispute action.

import 'package:dabbler/core/navigation/back_or_tab.dart';
import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/utils/bidi_isolate.dart';
import 'package:dabbler/features/post_activity/domain/post_activity_models.dart';
import 'package:dabbler/features/post_activity/presentation/post_activity_controller.dart';
import 'package:dabbler/features/post_activity/presentation/post_activity_steps.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

void postActivityToast(BuildContext context, String m, {bool err = false}) {
  DabblerToastProvider.maybeOf(context)?.show(
    DabblerToastSpec(
      message: m,
      tone: err ? DabblerToastTone.error : DabblerToastTone.success,
    ),
  );
}

/// The message for a refusal of any post-activity RPC.
String postActivityError(AppLocalizations l, Failure f) => switch (f.code) {
  'window_closed' => l.g02_err_window_closed,
  'not_eligible' ||
  'not_ratable' ||
  'window_not_open' => l.g02_err_not_eligible,
  'result_final' => l.g02_err_result_final,
  'not_ended' => l.g02_err_not_ended,
  'event_cancelled' => l.g02_err_cancelled,
  'no_majority' => l.g03_err_no_majority,
  'no_submissions' => l.g03_err_no_submissions,
  'not_organiser' => l.g03_err_not_organiser,
  'invalid_score' => l.g03f_err_invalid,
  'self_vote' => l.g02_err_mvp_self,
  'invalid_player' || 'player_not_eligible' => l.g02_err_mvp_player,
  _ => l.g02_err_generic,
};

class PostActivityScreen extends ConsumerWidget {
  const PostActivityScreen({
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
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final state = ref.watch(postActivityProvider(eventId));
    final ctrl = ref.read(postActivityProvider(eventId).notifier);
    final topBar = DabblerNavigationTopBar.titled(
      title: title != null && title!.isNotEmpty
          ? context.isolate(title)
          : l.g02_title,
      onBack: onBack ?? () => backOrTab(context),
    );
    final flow = state.flow;
    if (flow == null || state.loading && state.tally == null) {
      return DabblerPage(
        topBar: topBar,
        body: state.loadFailure == null
            ? const Center(child: DabblerSpinner())
            : DabblerEmptyState.error(
                title: l.g02_load_failed,
                retryLabel: l.feed_retry,
                onRetry: ctrl.load,
              ),
      );
    }
    Widget empty(String key, String icon, String t, String body) => Center(
      child: DabblerEmptyState(
        key: ValueKey<String>(key),
        icon: icon,
        title: t,
        text: body,
      ),
    );
    if (state.dismissed) {
      return DabblerPage(
        topBar: topBar,
        body: empty(
          'g02-dismissed',
          'tick-circle',
          l.g02_dismissed_title,
          l.g02_dismissed,
        ),
      );
    }
    final Widget body = switch (flow.state) {
      RatingFlowState.notEligible when flow.isOrganiser => Center(
        child: DabblerEmptyState(
          key: const ValueKey<String>('g02-organiser'),
          icon: 'task-square',
          title: l.g02_organiser_title,
          text: state.tally?.competitive == true
              ? l.g02_organiser_body
              : l.g02_organiser_body_no_result,
          action: state.tally?.competitive != true
              ? null
              : DabblerButton(
                  key: const ValueKey<String>('g02-organiser-result'),
                  label: l.g02_organiser_result,
                  tone: DabblerButtonTone.secondary,
                  onPressed: () => context.push(
                    RoutePaths.resultApproval(eventId, title: title),
                  ),
                ),
        ),
      ),
      RatingFlowState.notEligible => empty(
        'g02-not-eligible',
        'user-remove',
        l.g02_not_eligible,
        l.g02_not_eligible_body,
      ),
      RatingFlowState.notOpen => empty(
        'g02-not-open',
        'clock',
        l.g02_not_open,
        l.g02_not_open_body,
      ),
      RatingFlowState.submitted => _submitted(l, state),
      RatingFlowState.closed => _review(context, l, state),
      _ => _steps(context, ref, l, state, ctrl),
    };
    return DabblerPage(topBar: topBar, body: body);
  }

  Future<void> _dismiss(
    BuildContext context,
    AppLocalizations l,
    PostActivityController ctrl,
  ) async {
    final f = await ctrl.dismiss();
    if (!context.mounted || f?.code == 'busy') return;
    if (f != null) {
      postActivityToast(context, postActivityError(l, f), err: true);
    } else {
      postActivityToast(context, l.g02_dismissed);
    }
  }

  Widget _submitted(AppLocalizations l, PostActivityState s) {
    final t = s.tally;
    return ListView(
      padding: DabblerInsets.screen,
      children: [
        DabblerEmptyState(
          key: const ValueKey<String>('g02-submitted'),
          icon: 'tick-circle',
          title: l.g02_submitted,
          text: t != null && t.competitive
              ? l.g02_submitted_count(t.submissions, t.eligible)
              : l.g02_submitted_body,
        ),
        if (t != null && t.competitive && t.eligible > 0)
          DabblerProgressBar(
            value: t.submissions / t.eligible,
            label: l.g02_submitted_count(t.submissions, t.eligible),
          ),
      ],
    );
  }

  /// Closed after 48h: everything the caller gave, read-only.
  Widget _review(
    BuildContext context,
    AppLocalizations l,
    PostActivityState s,
  ) {
    final flow = s.flow!;
    return ListView(
      key: const ValueKey<String>('g02-closed'),
      padding: DabblerInsets.screen,
      children: [
        DabblerBanner(title: l.g02_closed, message: l.g02_closed_body),
        const DabblerGap.v(DabblerSpacing.space4),
        if (s.tally?.competitive == true)
          ScoreStep(
            score: s.score ?? const Score(0, 0),
            side: s.side,
            finalScore: s.tally!.finalScore,
          ),
        const DabblerGap.v(DabblerSpacing.space4),
        ..._groups(l, s, flow, null),
      ],
    );
  }

  List<Widget> _groups(
    AppLocalizations l,
    PostActivityState s,
    RatingFlow flow,
    PostStep? only, [
    PostActivityController? ctrl,
  ]) {
    Widget g(String key, RatingTarget t, String fallback, RatingSubject sub) =>
        RatingGroup(
          id: key,
          name: t.name ?? fallback,
          dims: s.dimsFor(sub),
          values: s.drafts[key] ?? t.mine,
          onChanged: ctrl == null ? null : (d, v) => ctrl.setRating(key, d, v),
        );
    return [
      if (only == null || only == PostStep.players)
        for (final p in flow.players)
          g('player:${p.id}', p, l.g02_unnamed, RatingSubject.player),
      if ((only == null || only == PostStep.organiser) &&
          flow.organiser != null)
        g(
          'organiser',
          flow.organiser!,
          l.g02_step_organiser,
          RatingSubject.organiser,
        ),
      if ((only == null || only == PostStep.venue) && flow.venue != null)
        g('venue', flow.venue!, l.g02_step_venue, RatingSubject.venue),
    ];
  }

  Widget _steps(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l,
    PostActivityState s,
    PostActivityController ctrl,
  ) {
    final steps = s.steps;
    final step = s.current;
    final now = ref.watch(postActivityNowProvider)();
    final closes = s.flow!.closesAt;
    final t = s.tally;
    Future<void> go(Future<Failure?> Function() f) async {
      final last = s.isLast;
      final r = await f();
      if (!context.mounted || r?.code == 'busy') return;
      if (r != null) {
        postActivityToast(context, postActivityError(l, r), err: true);
      } else if (last) {
        postActivityToast(context, l.g02_submitted);
      }
    }

    final (String head, String hint) = switch (step) {
      PostStep.score => (l.g02_step_score, ''),
      PostStep.players => (l.g02_step_players, l.g02_players_hint),
      PostStep.mvp => (l.g02_step_mvp, l.g02_mvp_hint),
      PostStep.organiser => (l.g02_step_organiser, l.g02_organiser_hint),
      PostStep.venue => (l.g02_step_venue, l.g02_venue_hint),
      null => (l.g02_title, ''),
    };
    final scoreReady =
        step != PostStep.score ||
        t?.open != true ||
        s.scoreNotEnded ||
        (s.side != null && s.score != null);
    return Column(
      children: [
        Expanded(
          child: ListView(
            key: ValueKey<String>('g02-step-${step?.name ?? 'none'}'),
            padding: DabblerInsets.screen,
            children: [
              if (closes != null)
                DabblerText(
                  minutesUntil(closes, now) < 60
                      ? l.g02_closes_in_min(minutesUntil(closes, now))
                      : l.g02_closes_in(hoursUntil(closes, now)),
                  key: const ValueKey<String>('g02-countdown'),
                  tone: DabblerTextTone.secondary,
                ),
              const DabblerGap.v(DabblerSpacing.space2),
              if (steps.isNotEmpty)
                DabblerProgressBar(
                  value: (s.step + 1) / steps.length,
                  label: l.g02_step_of(s.step + 1, steps.length),
                ),
              const DabblerGap.v(DabblerSpacing.space4),
              DabblerText(head, style: DabblerType.title3),
              if (hint.isNotEmpty) ...[
                const DabblerGap.v(DabblerSpacing.space1),
                DabblerText(hint, tone: DabblerTextTone.secondary),
              ],
              const DabblerGap.v(DabblerSpacing.space4),
              if (s.saveFailure != null) ...[
                DabblerBanner(
                  key: const ValueKey<String>('g02-save-failed'),
                  tone: DabblerBannerTone.error,
                  message: postActivityError(l, s.saveFailure!),
                ),
                const DabblerGap.v(DabblerSpacing.space4),
              ],
              if (step == PostStep.score && s.scoreNotEnded) ...[
                DabblerBanner(
                  key: const ValueKey<String>('g02-score-not-ended'),
                  tone: DabblerBannerTone.info,
                  message: l.g02_score_not_ended,
                ),
                const DabblerGap.v(DabblerSpacing.space4),
              ],
              if (step == PostStep.score && t == null)
                DabblerEmptyState.error(
                  key: const ValueKey<String>('g02-score-failed'),
                  title: l.g02_score_load_failed,
                  retryLabel: l.feed_retry,
                  onRetry: ctrl.retryResult,
                )
              else if (step == PostStep.score)
                ScoreStep(
                  score: s.score ?? const Score(0, 0),
                  side: s.side,
                  finalScore: t!.open ? null : t.finalScore,
                  onScore: t.open && !s.busy && !s.scoreNotEnded
                      ? ctrl.setScore
                      : null,
                  onSide: t.open && !s.busy && !s.scoreNotEnded
                      ? ctrl.setSide
                      : null,
                )
              else if (step == PostStep.mvp)
                MvpStep(
                  candidates: s.mvp?.candidates ?? const [],
                  pick: s.mvpPick,
                  unnamed: l.g02_unnamed,
                  onPick: s.busy ? null : ctrl.setMvp,
                )
              else if (step != null)
                ..._groups(l, s, s.flow!, step, s.busy ? null : ctrl),
            ],
          ),
        ),
        Padding(
          padding: DabblerInsets.screen,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DabblerButton(
                key: const ValueKey<String>('g02-next'),
                label: s.isLast ? l.g02_submit : l.g02_next,
                fullWidth: true,
                loading: s.busy,
                disabled: !scoreReady,
                onPressed: () => go(ctrl.next),
              ),
              const DabblerGap.v(DabblerSpacing.space2),
              Row(
                children: [
                  if (s.step > 0)
                    Expanded(
                      child: DabblerButton(
                        key: const ValueKey<String>('g02-back'),
                        label: l.g02_back,
                        tone: DabblerButtonTone.neutral,
                        size: DabblerButtonSize.small,
                        fullWidth: true,
                        disabled: s.busy,
                        onPressed: ctrl.back,
                      ),
                    ),
                  if (s.step > 0) const DabblerGap.h(DabblerSpacing.space2),
                  Expanded(
                    child: DabblerButton(
                      key: const ValueKey<String>('g02-skip'),
                      label: l.g02_skip,
                      tone: DabblerButtonTone.secondary,
                      size: DabblerButtonSize.small,
                      fullWidth: true,
                      disabled: s.busy,
                      onPressed: () => go(ctrl.skip),
                    ),
                  ),
                ],
              ),
              const DabblerGap.v(DabblerSpacing.space2),
              DabblerButton(
                key: const ValueKey<String>('g02-dismiss'),
                label: l.g02_dismiss,
                tone: DabblerButtonTone.neutral,
                size: DabblerButtonSize.small,
                fullWidth: true,
                disabled: s.busy,
                onPressed: () => _dismiss(context, l, ctrl),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
