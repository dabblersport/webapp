// CEO 2026-11-19: Home's games go back into the design-system stack
// ([DabblerUpcomingReminder]). Each item carries the title, one time line
// ("14:45 until 16:15", in the user's 12/24-hour format) and at most one
// short label: Checked in / Check in / Live / Ended / Check in closed. A
// running game's ring holds its sport's emoji. Tap opens the check-in sheet
// while check-in is open for the viewer, else the event.

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
import 'package:flutter/services.dart';
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

  /// Check-in is open to this viewer (never the organiser).
  bool get canCheckIn {
    final e = live;
    return e != null && !e.isOrganiser && !e.isCancelled && e.canCheckIn;
  }

  String get route =>
      isMeetup ? RoutePaths.meetupDetail(id) : RoutePaths.gameDetail(id);

  HomeGameEntry withSport(String? s) => HomeGameEntry(
    id: id,
    title: title,
    start: start,
    venue: venue,
    end: end,
    sport: s,
    live: live,
    isMeetup: isMeetup,
  );
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

/// The one short label for [g] at [now], or null when nothing applies.
String? homeGameLabel(AppLocalizations l, HomeGameEntry g, DateTime now) {
  final e = g.live;
  if (e == null) {
    if (!g.isRunningAt(now)) return null;
    final end = g.end;
    return end != null && !now.isBefore(end)
        ? l.oc_ended
        : l.activity_pill_live;
  }
  final viewer = !e.isOrganiser && !e.isCancelled;
  if (viewer && e.isCheckedIn) return l.hc_checked_in;
  if (g.canCheckIn) return l.g04_cta;
  switch (e.statusAt(now)) {
    case OngoingStatus.running:
    case OngoingStatus.started:
      return l.activity_pill_live;
    case OngoingStatus.timeEnded:
    case OngoingStatus.autoClosed:
    case OngoingStatus.confirmed:
      return l.oc_ended;
    case OngoingStatus.didNotHappen:
    case OngoingStatus.cancelled:
    case OngoingStatus.startingSoon:
      break;
  }
  if (viewer && e.checkIn == CheckInPhase.closed) return l.hc_check_in_closed;
  return null;
}

/// The countdown window the ring fills over — three days.
const int _windowSeconds = 3 * 24 * 60 * 60;

/// [g] as a [DabblerUpcomingItem]: countdown ring before the start, the
/// sport's emoji in an elapsed-time ring while running.
DabblerUpcomingItem homeUpcomingItem(
  BuildContext context,
  HomeGameEntry g,
  DateTime now,
) {
  final l = AppLocalizations.of(context);
  final e = g.live;
  final start = e?.startAt ?? g.start;
  final end = e?.scheduledEnd ?? g.end;
  final time = end == null
      ? checkInClock(context, start)
      : l.hc_time_range(
          checkInClock(context, start),
          checkInClock(context, end),
        );
  final label = homeGameLabel(l, g, now);
  final detail = label == null ? time : '$time · $label';

  final double fraction;
  final String big;
  final String small;
  final String short;
  if (g.isRunningAt(now)) {
    final from = e?.startedAt ?? start;
    fraction = end != null && end.isAfter(from)
        ? (now.difference(from).inSeconds / end.difference(from).inSeconds)
              .clamp(0.0, 1.0)
        : 0.0;
    final emoji = e?.sportEmoji?.trim();
    final sport = (g.sport ?? e?.sportKey)?.trim();
    big = emoji != null && emoji.isNotEmpty
        ? emoji
        : sport == null || sport.isEmpty
        ? ''
        : homeSportEmoji(sport);
    small = '';
    short = label ?? time;
  } else {
    final left = start.difference(now);
    final safe = left.isNegative ? Duration.zero : left;
    final days = safe.inDays;
    final hours = safe.inHours % 24;
    // Rounded up, as the ongoing card counts ("Starts in 7 min").
    final minutes = days == 0 && hours == 0
        ? (safe.inSeconds + 59) ~/ 60
        : safe.inMinutes % 60;
    fraction = 1 - (safe.inSeconds / _windowSeconds).clamp(0.0, 1.0);
    (big, small) = days > 0
        ? ('$days', days == 1 ? l.home_upcoming_day : l.home_upcoming_days)
        : hours > 0
        ? ('$hours', hours == 1 ? l.home_upcoming_hour : l.home_upcoming_hours)
        : ('$minutes', l.home_upcoming_min);
    short =
        label ??
        (days > 0
            ? l.home_upcoming_in_days(days)
            : hours > 0
            ? l.home_upcoming_in_hours(hours, minutes)
            : l.home_upcoming_in_minutes(minutes));
  }
  return DabblerUpcomingItem(
    month: DateFormat('MMM', 'en').format(start).toUpperCase(),
    day: '${start.day}',
    title: g.title,
    detail: detail,
    ringFraction: fraction,
    ringBig: big,
    ringSmall: small,
    short: short,
    onTap: () {
      HapticFeedback.selectionClick();
      g.canCheckIn
          ? showCheckInSheet(context, g.live!.eventId)
          : context.push(g.route);
    },
  );
}
