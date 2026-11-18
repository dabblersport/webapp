// KAN-1002 (W2-F5): the lifecycle card in the game and meetup details.
// Everyone sees the state ("Scheduled until …", "Started 8:05 PM", awaiting
// the organiser, the confirmed end, "Scheduled time ended", "Did not happen");
// only the organiser (is_organiser from the server) gets Start (optional),
// Confirm end and Did not happen. A cancelled event shows the cancelled state;
// a hidden or missing event (event_not_found) shows nothing.

import 'package:dabbler/core/config/feature_flags.dart';
import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/features/attendance/presentation/check_in_screen.dart'
    show checkInClock;
import 'package:dabbler/features/lifecycle/domain/lifecycle_models.dart';
import 'package:dabbler/features/lifecycle/presentation/lifecycle_controller.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class EventLifecycleCard extends ConsumerWidget {
  const EventLifecycleCard({super.key, required this.eventId});

  /// games.id / meetups.id, which is the events.id.
  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!FeatureFlags.eventLifecycle) return const SizedBox.shrink();
    final s = ref.watch(lifecycleControllerProvider(eventId));
    final ctrl = ref.read(lifecycleControllerProvider(eventId).notifier);
    final v = s.view;
    final l = AppLocalizations.of(context);
    if (v == null) {
      if (!s.loadFailed) return const SizedBox.shrink();
      return DabblerBanner(
        key: const ValueKey<String>('lifecycle-load-failed'),
        tone: DabblerBannerTone.error,
        message: l.lc_load_failed,
        action: DabblerBannerAction(label: l.feed_retry, onPressed: ctrl.load),
      );
    }
    if (v.isCancelled) {
      return DabblerBanner(
        key: const ValueKey<String>('lifecycle-cancelled'),
        tone: DabblerBannerTone.neutral,
        title: l.lc_cancelled,
      );
    }
    final phase = v.phase;
    final end = v.scheduledEnd;
    if (phase == null) return const SizedBox.shrink();
    final now = ref.watch(lifecycleClockProvider)();
    final isOrganiser = v.isOrganiser;
    String clock(DateTime? t) => t == null ? '' : checkInClock(context, t);
    final autoClose = v.autoCloseAt;

    final (
      DabblerBannerTone tone,
      String title,
      String? body,
    ) = switch (phase) {
      LifecyclePhase.scheduled => (
        DabblerBannerTone.info,
        end == null ? l.lc_scheduled : l.lc_scheduled_until(clock(end)),
        null,
      ),
      LifecyclePhase.started => (
        DabblerBannerTone.success,
        l.lc_started_at(clock(v.startedAt)),
        end == null ? null : l.lc_scheduled_until(clock(end)),
      ),
      LifecyclePhase.awaitingConfirmation => (
        DabblerBannerTone.warning,
        l.lc_awaiting(clock(end)),
        [
          isOrganiser ? l.lc_awaiting_body_host : l.lc_awaiting_body_guest,
          if (autoClose != null) l.lc_auto_close_at(clock(autoClose)),
        ].join('\n'),
      ),
      LifecyclePhase.confirmed => (
        DabblerBannerTone.success,
        l.lc_confirmed(clock(v.endedAt ?? end)),
        null,
      ),
      LifecyclePhase.timeEnded => (
        DabblerBannerTone.neutral,
        l.lc_time_ended,
        null,
      ),
      LifecyclePhase.didNotHappen => (
        DabblerBannerTone.neutral,
        l.lc_did_not_happen,
        null,
      ),
    };

    final busy = s.busy;
    Widget button(
      LifecycleAction a,
      String label,
      DabblerButtonTone tone,
      String key,
    ) => DabblerButton(
      key: ValueKey<String>(key),
      label: label,
      tone: tone,
      size: DabblerButtonSize.full,
      fullWidth: true,
      loading: busy == a,
      onPressed: busy != null ? null : () => ctrl.run(a),
    );

    final controls = <Widget>[
      if (isOrganiser &&
          phase == LifecyclePhase.scheduled &&
          v.startAt != null &&
          !now.isBefore(v.startAt!))
        button(
          LifecycleAction.start,
          l.lc_start,
          DabblerButtonTone.primary,
          'lifecycle-start',
        ),
      if (isOrganiser && phase == LifecyclePhase.awaitingConfirmation) ...[
        button(
          LifecycleAction.confirm,
          l.lc_confirm_end,
          DabblerButtonTone.primary,
          'lifecycle-confirm',
        ),
        button(
          LifecycleAction.didNotHappen,
          l.lc_did_not_happen,
          DabblerButtonTone.outlined,
          'lifecycle-did-not-happen',
        ),
      ],
    ];

    final f = s.failure;
    return Column(
      key: ValueKey<String>('lifecycle-${phase.name}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        DabblerBanner(tone: tone, title: title, message: body),
        if (f != null && isOrganiser) ...[
          const DabblerGap.v(DabblerSpacing.space8),
          DabblerBanner(
            key: const ValueKey<String>('lifecycle-error'),
            tone: DabblerBannerTone.error,
            message: _refusal(l, f),
          ),
        ],
        for (final c in controls) ...[
          const DabblerGap.v(DabblerSpacing.space8),
          c,
        ],
      ],
    );
  }

  static String _refusal(AppLocalizations l, Failure f) => switch (f.code) {
    'already_closed' || 'lifecycle_closed' => l.lc_already_closed,
    'not_started_yet' => l.lc_not_started_yet,
    _ => l.lc_failed,
  };
}
