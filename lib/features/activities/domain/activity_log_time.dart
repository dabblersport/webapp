import 'package:intl/intl.dart';

import 'package:dabbler/features/activities/data/models/activity_feed_event.dart';
import 'package:dabbler/features/activities/domain/activity_log_merge.dart';

/// KAN-990: calendar arithmetic for the Activity log, in the device's local
/// time. Every function takes `now`, so tests pin the clock and cross a day
/// boundary on purpose.

/// The local calendar day [t] falls on (midnight, local).
DateTime activityLocalDay(DateTime t) {
  final DateTime l = t.toLocal();
  return DateTime(l.year, l.month, l.day);
}

/// Whole local calendar days from [t]'s day to [now]'s day: 0 is today, 1 is
/// yesterday, negative is a later day. Rounded so a DST day (23 or 25 hours)
/// still counts as one day.
int activityDaysAgo(DateTime t, DateTime now) =>
    (activityLocalDay(now).difference(activityLocalDay(t)).inHours / 24)
        .round();

/// The "Last 7 days" figures: today and the six local days before it.
class ActivityLastSevenDays {
  const ActivityLastSevenDays({required this.events, required this.rewards});

  /// Every log row in the window.
  final int events;

  /// The rows under the Rewards chip.
  final int rewards;
}

/// Counts [all] rows whose local day is today or one of the six days before.
/// Later days (an upcoming row) are not "the last 7 days".
ActivityLastSevenDays activityLastSevenDays(
  Iterable<ActivityFeedEvent> all,
  DateTime now,
) {
  int events = 0;
  int rewards = 0;
  for (final ActivityFeedEvent e in all) {
    final int ago = activityDaysAgo(e.happenedAt, now);
    if (ago < 0 || ago > 6) continue;
    events++;
    if (activityLogCategoryOf(e) == 'reward') rewards++;
  }
  return ActivityLastSevenDays(events: events, rewards: rewards);
}

/// The clock time of [t] in local time, in the device's 12/24-hour setting
/// (design decision I-7): `17:05` or `5:05 PM`, in [locale]'s own form.
String formatActivityClock(
  DateTime t, {
  required bool use24h,
  required String locale,
}) {
  final DateFormat f = use24h ? DateFormat.Hm(locale) : DateFormat.jm(locale);
  return f.format(t.toLocal());
}
