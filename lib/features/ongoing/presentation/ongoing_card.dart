// KAN-1008 (W3-F1): the pinned ongoing-activity card, at the top of the
// Notification Center (Home shows HomeGameCard instead). Same states as the Live
// Activity: starting soon (countdown), check-in open (Check in), checked in,
// scheduled until / started at, changed (old → new), scheduled time running,
// scheduled time ended, ended (confirmed / did not happen), cancelled. The
// organiser sees "You're organising" and never Check in. No score, ETA or
// location. Tap opens the event; Check in opens the KAN-998 screen. With
// more than one activity the first by [orderOngoing] is shown and the rest
// are in the "+N more" sheet.

import 'dart:async';

import 'package:dabbler/core/config/feature_flags.dart';
import 'package:dabbler/core/constants/timing/notification_timing.dart';
import 'package:dabbler/core/utils/bidi_isolate.dart';
import 'package:dabbler/features/attendance/presentation/check_in_screen.dart'
    show checkInClock;
import 'package:dabbler/features/lifecycle/presentation/lifecycle_controller.dart'
    show lifecycleClockProvider;
import 'package:dabbler/features/ongoing/domain/ongoing_models.dart';
import 'package:dabbler/features/ongoing/presentation/ongoing_controller.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// The slot both screens insert: the flag, the gutter and the gap below.
class OngoingCardSlot extends ConsumerWidget {
  const OngoingCardSlot({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!FeatureFlags.ongoingCard) return const SizedBox.shrink();
    final events = ref.watch(ongoingControllerProvider).events;
    if (events.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: DabblerInsets.feedScreen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          OngoingCard(events: events),
          const DabblerGap.v(DabblerSpacing.space8),
        ],
      ),
    );
  }
}

String _route(OngoingEvent e) => e.kind == OngoingKind.game
    ? RoutePaths.gameDetail(e.eventId)
    : RoutePaths.meetupDetail(e.eventId);

/// The main line of [e] at [now].
String ongoingStatusLine(BuildContext context, OngoingEvent e, DateTime now) {
  final l = AppLocalizations.of(context);
  String clock(DateTime? t) => t == null ? '' : checkInClock(context, t);
  return switch (e.statusAt(now)) {
    OngoingStatus.startingSoon => _countdown(l, e.startAt.difference(now)),
    OngoingStatus.running => l.oc_time_running,
    OngoingStatus.started => l.lc_started_at(clock(e.startedAt)),
    OngoingStatus.timeEnded || OngoingStatus.autoClosed => l.lc_time_ended,
    // No time: the RPC carries no actual end.
    OngoingStatus.confirmed => l.oc_ended,
    OngoingStatus.didNotHappen => l.lc_did_not_happen,
    OngoingStatus.cancelled => l.lc_cancelled,
  };
}

String _countdown(AppLocalizations l, Duration left) {
  final minutes = (left.inSeconds + 59) ~/ 60;
  return minutes <= 0 ? l.oc_starting_now : l.oc_starts_in(minutes);
}

/// The lines under the main one: the schedule, a change, the check-in.
List<String> _details(BuildContext context, OngoingEvent e, DateTime now) {
  final l = AppLocalizations.of(context);
  String clock(DateTime t) => checkInClock(context, t);
  final status = e.statusAt(now);
  final end = e.scheduledEnd;
  return <String>[
    if (status == OngoingStatus.startingSoon) l.g04_starts(clock(e.startAt)),
    if (end != null &&
        (status == OngoingStatus.startingSoon ||
            status == OngoingStatus.running ||
            status == OngoingStatus.started))
      l.lc_scheduled_until(clock(end)),
    if (status == OngoingStatus.timeEnded)
      e.isOrganiser ? l.lc_awaiting_body_host : l.lc_awaiting_body_guest,
    if (e.isStartChanged)
      _changed(context, e.previousStartAt!, e.startAt)
    else if (e.isEndOnlyChanged)
      _changed(context, e.previousEndAt!, e.scheduledEnd!),
    if (e.isCheckedIn) l.g04_checked_in,
  ];
}

/// "Changed: {old} → {now}". The date is added when the two fall on
/// different days; in RTL each side is bidi-isolated.
String _changed(BuildContext context, DateTime old, DateTime now) {
  final locale = Localizations.localeOf(context).toLanguageTag();
  final sameDay =
      old.year == now.year && old.month == now.month && old.day == now.day;
  String fmt(DateTime t) {
    final time = checkInClock(context, t);
    if (sameDay) return context.isolate(time);
    final date = DabblerType.toWesternDigits(DateFormat.MMMd(locale).format(t));
    return context.isolate('$date $time');
  }

  return AppLocalizations.of(context).oc_changed(fmt(old), fmt(now));
}

class OngoingCard extends ConsumerStatefulWidget {
  const OngoingCard({super.key, required this.events});

  /// Ordered by [orderOngoing]; never empty.
  final List<OngoingEvent> events;

  @override
  ConsumerState<OngoingCard> createState() => _OngoingCardState();
}

class _OngoingCardState extends ConsumerState<OngoingCard> {
  /// Redraws the countdown at the next minute. One-shot, display only: the
  /// server is read by the controller's boundary timer, not here.
  Timer? _tick;

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  void _armTick(OngoingEvent e, DateTime now) {
    _tick?.cancel();
    _tick = null;
    if (e.statusAt(now) != OngoingStatus.startingSoon) return;
    final left = e.startAt.difference(now);
    const tick = NotificationTiming.ongoingCountdownTick;
    final toMinute = left - tick * left.inMinutes;
    _tick = Timer(toMinute <= Duration.zero ? tick : toMinute, () {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final now = ref.watch(lifecycleClockProvider)();
    final e = widget.events.first;
    final others = widget.events.length - 1;
    _armTick(e, now);
    final overline = <String>[
      e.kind == OngoingKind.game ? l.oc_game : l.oc_meetup,
      if (e.isOrganiser) l.oc_organiser,
    ].join(' · ');
    final details = _details(context, e, now);
    return DabblerCard(
      key: ValueKey<String>('ongoing-card-${e.eventId}'),
      semanticLabel: e.title,
      onTap: () => context.push(_route(e)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          DabblerText(
            overline,
            style: DabblerType.caption1,
            tone: DabblerTextTone.secondary,
          ),
          const DabblerGap.v(DabblerSpacing.space2),
          DabblerText(
            context.isolate(e.title),
            style: DabblerType.headline,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const DabblerGap.v(DabblerSpacing.space2),
          DabblerText(
            ongoingStatusLine(context, e, now),
            key: const ValueKey<String>('ongoing-status'),
            style: DabblerType.subheadline,
            weight: DabblerTextWeight.medium,
          ),
          for (final d in details)
            DabblerText(
              d,
              style: DabblerType.footnote,
              tone: DabblerTextTone.secondary,
            ),
          if (e.canCheckIn) ...<Widget>[
            const DabblerGap.v(DabblerSpacing.space8),
            DabblerButton(
              key: const ValueKey<String>('ongoing-check-in'),
              label: l.g04_cta,
              icon: 'tick-circle',
              size: DabblerButtonSize.full,
              fullWidth: true,
              onPressed: () => context.push(RoutePaths.checkIn(e.eventId)),
            ),
          ],
          if (others > 0) ...<Widget>[
            const DabblerGap.v(DabblerSpacing.space8),
            DabblerButton(
              key: const ValueKey<String>('ongoing-more'),
              label: l.oc_more(others),
              tone: DabblerButtonTone.neutral,
              size: DabblerButtonSize.small,
              onPressed: () => _showOthers(context, widget.events.skip(1)),
            ),
          ],
        ],
      ),
    );
  }
}

Future<void> _showOthers(BuildContext context, Iterable<OngoingEvent> others) {
  final l = AppLocalizations.of(context);
  final list = others.toList();
  return showDabblerSheet<void>(
    context: context,
    title: l.oc_sheet_title,
    detent: DabblerSheetDetent.content,
    builder: (sheet) => Consumer(
      builder: (sheet, ref, _) {
        final now = ref.watch(lifecycleClockProvider)();
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            for (final e in list)
              DabblerListRow(
                key: ValueKey<String>('ongoing-row-${e.eventId}'),
                title: sheet.isolate(e.title),
                subtitle: ongoingStatusLine(sheet, e, now),
                showChevron: !e.canCheckIn,
                trailing: e.canCheckIn
                    ? DabblerButton(
                        key: ValueKey<String>(
                          'ongoing-row-check-in-${e.eventId}',
                        ),
                        label: l.g04_cta,
                        size: DabblerButtonSize.small,
                        onPressed: () {
                          Navigator.of(sheet).pop();
                          context.push(RoutePaths.checkIn(e.eventId));
                        },
                      )
                    : null,
                onTap: () {
                  Navigator.of(sheet).pop();
                  context.push(_route(e));
                },
              ),
          ],
        );
      },
    ),
  );
}
