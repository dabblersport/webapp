// CEO 2026-11-19: one Home card per game, in the Upcoming card's design (date
// tile, title, venue · time, countdown ring). When the game starts the same
// card switches to its running state (KAN-1008 states): the ring becomes a
// running indicator holding the sport's emoji, with "Under way" or
// "Started …"; the time line reads "2:45 PM until 4:15 PM" in the user's
// 12/24-hour format; a changed schedule shows old → new; under the time, one
// check-in label (Checked in / Check in available / Check in closed) and,
// while open, the Check in button (never for the organiser). Tap opens the
// event.

import 'package:dabbler/core/utils/bidi_isolate.dart';
import 'package:dabbler/features/attendance/presentation/check_in_screen.dart'
    show checkInClock;
import 'package:dabbler/features/attendance/domain/check_in_models.dart';
import 'package:dabbler/features/attendance/presentation/check_in_sheet.dart';
import 'package:dabbler/features/home/presentation/widgets/home_post_display.dart'
    show homeSportEmoji;
import 'package:dabbler/features/ongoing/domain/ongoing_models.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// One game (or meetup) on Home: its schedule and, once the server returns it
/// from rpc_my_ongoing_events, its live state.
@immutable
class HomeGameEntry {
  const HomeGameEntry({
    required this.id,
    required this.title,
    required this.start,
    this.venue,
    this.end,
    this.sport,
    this.live,
    this.isMeetup = false,
  });

  final String id;
  final String title;
  final DateTime start;
  final String? venue;

  /// The scheduled end from the games list; the live row's end wins.
  final DateTime? end;

  /// The sport's English name, for the running ring's emoji.
  final String? sport;
  final OngoingEvent? live;
  final bool isMeetup;

  /// Running (past its start, or started) rather than upcoming.
  bool isRunningAt(DateTime now) {
    final e = live;
    if (e == null) return !now.isBefore(start);
    return e.statusAt(now) != OngoingStatus.startingSoon;
  }

  String get route =>
      isMeetup ? RoutePaths.meetupDetail(id) : RoutePaths.gameDetail(id);
}

/// Running first, then the nearest upcoming; ties by start, then id.
List<HomeGameEntry> orderHomeGames(List<HomeGameEntry> list, DateTime now) {
  int group(HomeGameEntry g) => g.isRunningAt(now) ? 0 : 1;
  return list.toList()..sort((a, b) {
    final byGroup = group(a).compareTo(group(b));
    if (byGroup != 0) return byGroup;
    final byStart = a.start.compareTo(b.start);
    return byStart != 0 ? byStart : a.id.compareTo(b.id);
  });
}

class HomeGameCard extends StatelessWidget {
  const HomeGameCard({super.key, required this.entry, required this.now});

  final HomeGameEntry entry;
  final DateTime now;

  /// The countdown window the ring fills over — three days.
  static const int _windowSeconds = 3 * 24 * 60 * 60;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final e = entry.live;
    final status = e?.statusAt(now);
    final running = entry.isRunningAt(now);
    final start = e?.startAt ?? entry.start;
    final end = e?.scheduledEnd ?? entry.end;
    final time = end == null
        ? checkInClock(context, start)
        : l.hc_time_range(
            checkInClock(context, start),
            checkInClock(context, end),
          );
    final venue = entry.venue;
    final detail = venue == null || venue.isEmpty ? time : '$venue · $time';
    final statusLine = e == null ? null : _statusLine(context, l, e, status!);
    final changed = e == null ? null : _changedLine(context, e);
    final checkIn = e == null ? null : _checkInLabel(l, e);
    return DabblerFeedTappable(
      key: ValueKey<String>('home-game-${entry.id}'),
      onTap: () => context.push(entry.route),
      child: DabblerSurface.card(
        radius: DabblerRadius.lg,
        padding: const EdgeInsets.all(DabblerSpacing.space4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
              children: <Widget>[
                _dateTile(start),
                const DabblerGap.h(DabblerSpacing.space4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      DabblerText(
                        context.isolate(entry.title),
                        style: DabblerType.subheadline,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      DabblerText(
                        DabblerType.toWesternDigits(detail),
                        style: DabblerType.caption1,
                        tone: DabblerTextTone.secondary,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (statusLine != null)
                        DabblerText(
                          statusLine,
                          key: const ValueKey<String>('home-game-status'),
                          style: DabblerType.caption1,
                          weight: DabblerTextWeight.medium,
                          tone: running
                              ? DabblerTextTone.brand
                              : DabblerTextTone.primary,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      if (checkIn != null)
                        DabblerText(
                          checkIn.$1,
                          key: const ValueKey<String>(
                            'home-game-check-in-status',
                          ),
                          style: DabblerType.caption1,
                          weight: DabblerTextWeight.medium,
                          tone: checkIn.$2
                              ? DabblerTextTone.brand
                              : DabblerTextTone.secondary,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      if (changed != null)
                        DabblerText(
                          changed,
                          key: const ValueKey<String>('home-game-changed'),
                          style: DabblerType.caption1,
                          tone: DabblerTextTone.secondary,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                const DabblerGap.h(DabblerSpacing.space4),
                running ? _runningRing(e) : _countdownRing(l, start),
              ],
            ),
            if (e != null && e.canCheckIn) ...<Widget>[
              const DabblerGap.v(DabblerSpacing.space3),
              DabblerButton(
                key: const ValueKey<String>('home-game-check-in'),
                label: l.g04_cta,
                icon: 'tick-circle',
                size: DabblerButtonSize.small,
                fullWidth: true,
                onPressed: () => showCheckInSheet(context, e.eventId),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _dateTile(DateTime start) => SizedBox(
    width: DabblerUpcomingReminder.dateTileWidth,
    child: DabblerSurface.brandTint(
      radius: DabblerRadius.md,
      borderWidth: 0,
      padding: const EdgeInsets.symmetric(vertical: DabblerSpacing.space2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          DabblerText(
            DateFormat('MMM', 'en').format(start).toUpperCase(),
            style: DabblerType.caption2,
            tone: DabblerTextTone.brand,
          ),
          DabblerText(
            DabblerType.toWesternDigits('${start.day}'),
            style: DabblerType.headline,
            tone: DabblerTextTone.brand,
          ),
        ],
      ),
    ),
  );

  Widget _countdownRing(AppLocalizations l, DateTime start) {
    final left = start.difference(now);
    final safe = left.isNegative ? Duration.zero : left;
    final days = safe.inDays;
    final hours = safe.inHours % 24;
    // Rounded up, as the ongoing card counts ("Starts in 7 min").
    final minutes = days == 0 && hours == 0
        ? (safe.inSeconds + 59) ~/ 60
        : safe.inMinutes % 60;
    final (String big, String small) = days > 0
        ? ('$days', days == 1 ? l.home_upcoming_day : l.home_upcoming_days)
        : hours > 0
        ? ('$hours', hours == 1 ? l.home_upcoming_hour : l.home_upcoming_hours)
        : ('$minutes', l.home_upcoming_min);
    return DabblerRing.ticks(
      key: const ValueKey<String>('home-game-countdown'),
      fraction: 1 - (safe.inSeconds / _windowSeconds).clamp(0.0, 1.0),
      diameter: DabblerUpcomingReminder.ringSize,
      count: 32,
      track: DabblerRingTrack.faint,
      semanticValue: '$big $small',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          DabblerText(
            DabblerType.toWesternDigits(big),
            style: DabblerType.title3,
          ),
          DabblerText(
            small,
            style: DabblerType.caption2,
            tone: DabblerTextTone.secondary,
          ),
        ],
      ),
    );
  }

  /// The running indicator: an arc of the scheduled time that has passed.
  Widget _runningRing(OngoingEvent? e) {
    final start = e?.startedAt ?? e?.startAt ?? entry.start;
    final end = e?.scheduledEnd;
    var fraction = 0.0;
    if (end != null && end.isAfter(start)) {
      fraction =
          (now.difference(start).inSeconds / end.difference(start).inSeconds)
              .clamp(0.0, 1.0);
    }
    return DabblerRing.arc(
      key: const ValueKey<String>('home-game-running'),
      fraction: fraction,
      diameter: DabblerUpcomingReminder.ringSize,
      child: _sportMark(),
    );
  }

  /// The sport's emoji; the play icon only when no sport is known.
  Widget _sportMark() {
    final sport = entry.sport?.trim();
    if (sport == null || sport.isEmpty) {
      return const DabblerIcon('play', size: DabblerSizing.iconSm);
    }
    return DabblerText(
      homeSportEmoji(sport),
      key: const ValueKey<String>('home-game-sport'),
      style: DabblerType.title3,
    );
  }

  /// The one check-in label under the time, and whether it is the brand
  /// tone; null when check-in does not concern the viewer (the organiser,
  /// not eligible, before the window, cancelled).
  (String, bool)? _checkInLabel(AppLocalizations l, OngoingEvent e) {
    if (e.isOrganiser || e.isCancelled) return null;
    if (e.isCheckedIn) return (l.hc_checked_in, true);
    if (e.canCheckIn) return (l.hc_check_in_available, true);
    if (e.checkIn == CheckInPhase.closed) return (l.hc_check_in_closed, false);
    return null;
  }

  String? _statusLine(
    BuildContext context,
    AppLocalizations l,
    OngoingEvent e,
    OngoingStatus status,
  ) {
    String clock(DateTime t) => checkInClock(context, t);
    return switch (status) {
      // Before the start the ring counts down and the time line holds the
      // range, so there is nothing more to say.
      OngoingStatus.startingSoon => null,
      OngoingStatus.running => l.hc_under_way,
      OngoingStatus.started =>
        e.startedAt == null
            ? l.hc_under_way
            : l.lc_started_at(clock(e.startedAt!)),
      OngoingStatus.timeEnded =>
        '${l.lc_time_ended} · ${e.isOrganiser ? l.lc_awaiting_body_host : l.lc_awaiting_body_guest}',
      OngoingStatus.autoClosed => l.lc_time_ended,
      OngoingStatus.confirmed => l.oc_ended,
      OngoingStatus.didNotHappen => l.lc_did_not_happen,
      OngoingStatus.cancelled => l.lc_cancelled,
    };
  }

  /// "Changed: {old} → {now}", the date added when the days differ.
  String? _changedLine(BuildContext context, OngoingEvent e) {
    final DateTime old;
    final DateTime fresh;
    if (e.isStartChanged) {
      old = e.previousStartAt!;
      fresh = e.startAt;
    } else if (e.isEndOnlyChanged) {
      old = e.previousEndAt!;
      fresh = e.scheduledEnd!;
    } else {
      return null;
    }
    final locale = Localizations.localeOf(context).toLanguageTag();
    final sameDay =
        old.year == fresh.year &&
        old.month == fresh.month &&
        old.day == fresh.day;
    String fmt(DateTime t) {
      final time = checkInClock(context, t);
      if (sameDay) return context.isolate(time);
      final date = DabblerType.toWesternDigits(
        DateFormat.MMMd(locale).format(t),
      );
      return context.isolate('$date $time');
    }

    return AppLocalizations.of(context).oc_changed(fmt(old), fmt(fresh));
  }
}
