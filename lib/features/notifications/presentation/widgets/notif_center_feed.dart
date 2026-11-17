// KAN-989 (W1-F3): the Notifications tab's list as display rows.
//
// The list is the notifications under the chosen chip (the kind registry's
// chips) and, under All only, activity highlights from the Activity log (F-19,
// NC-08): a row type notification | activity with a stable key. Highlights are
// always read, never counted by Unread and never touched by Mark all read.
// Rows are grouped by local day: Today, Yesterday, Earlier this week, then by
// date.

import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import 'package:dabbler/features/activities/data/models/activity_feed_event.dart';
import 'package:dabbler/features/activities/domain/activity_log_time.dart';
import 'package:dabbler/features/notifications/data/models/notification_model.dart';
import 'package:dabbler/features/notifications/domain/notification_kinds.dart';
import 'package:dabbler/l10n/app_localizations.dart';

/// One row of the Notifications tab.
sealed class CenterRow {
  const CenterRow();

  /// Stable across rebuilds and pages.
  String get key;
  DateTime get at;
}

final class NotificationCenterRow extends CenterRow {
  const NotificationCenterRow(this.notification);
  final AppNotification notification;
  @override
  String get key => 'notification:${notification.id}';
  @override
  DateTime get at => notification.createdAt;
}

final class ActivityHighlightRow extends CenterRow {
  const ActivityHighlightRow(this.event);
  final ActivityFeedEvent event;
  @override
  String get key => 'activity:${event.id}';
  @override
  DateTime get at => event.happenedAt;
}

/// The highlight activity kinds (NC-08): a confirmed attendance, a result and
/// a badge. A booking status qualifies too but bookings are hidden (F-12);
/// "You posted" and "You joined" never do.
bool isActivityHighlight(ActivityFeedEvent e) {
  final verb = e.verb;
  switch (e.subjectType) {
    case 'reward':
      return verb == 'earned';
    case 'game':
    case 'meetup':
      return const {
            'attended',
            'checked_in',
            'attendance_confirmed',
            'result_confirmed',
            'won',
            'lost',
            'drew',
          }.contains(verb) ||
          e.status == 'attended';
    case 'result':
      return true;
    default:
      return false;
  }
}

/// The rows for [chip]: its notifications, plus the highlights under All,
/// newest first. A highlight about the same object as a notification on the
/// list is dropped (the notification is shown).
List<CenterRow> buildCenterRows({
  required List<AppNotification> notifications,
  required List<ActivityFeedEvent> activities,
  required NotificationChip chip,
}) {
  final rows = <CenterRow>[
    for (final n in notifications)
      if (NotificationKinds.inChip(chip, n)) NotificationCenterRow(n),
  ];
  if (chip == NotificationChip.all) {
    final notified = <String>{
      for (final n in notifications)
        for (final k in const ['entity_id', 'game_id', 'meetup_id', 'badge_id'])
          if ((n.args[k] ?? n.payload?[k]) case final Object id) '$id',
    };
    final seen = <String>{};
    for (final e in activities) {
      if (!isActivityHighlight(e)) continue;
      if (notified.contains(e.subjectId) || !seen.add(e.id)) continue;
      rows.add(ActivityHighlightRow(e));
    }
  }
  rows.sort((a, b) => b.at.compareTo(a.at));
  return rows;
}

/// A day group: [key] is `today`, `yesterday`, `week` or the local date.
typedef CenterGroup = ({String key, DateTime day, List<CenterRow> rows});

/// Groups [rows] (newest first) by local day against [now].
List<CenterGroup> groupCenterRows(List<CenterRow> rows, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final groups = <CenterGroup>[];
  for (final r in rows) {
    final t = r.at.toLocal();
    final day = DateTime(t.year, t.month, t.day);
    final days = today.difference(day).inDays;
    final key = days <= 0
        ? 'today'
        : days == 1
        ? 'yesterday'
        : days < 7
        ? 'week'
        : DateFormat('yyyy-MM-dd').format(day);
    if (groups.isEmpty || groups.last.key != key) {
      groups.add((key: key, day: day, rows: <CenterRow>[]));
    }
    groups.last.rows.add(r);
  }
  return groups;
}

/// The group's header label, in the app's language.
String centerGroupLabel(BuildContext context, CenterGroup g, DateTime now) {
  final l = AppLocalizations.of(context);
  return switch (g.key) {
    'today' => l.notif_section_today,
    'yesterday' => l.notif_section_yesterday,
    'week' => l.notif_section_this_week,
    _ =>
      g.day.year == now.year
          ? DateFormat.MMMEd(l.localeName).format(g.day)
          : DateFormat.yMMMEd(l.localeName).format(g.day),
  };
}

/// An activity highlight in the Notifications list: an icon tile and the
/// "Activity" marker, never an unread dot (NC-08).
class NotifHighlightRow extends StatelessWidget {
  const NotifHighlightRow({
    super.key,
    required this.event,
    required this.onTap,
  });

  final ActivityFeedEvent event;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final p = event.payload ?? const <String, dynamic>{};
    final title = p['title'] is String
        ? p['title'] as String
        : '${event.verb.replaceAll('_', ' ')} ${event.subjectType}';
    final sub = <String>[
      for (final k in const ['description', 'game_name', 'venue_name'])
        if (p[k] is String && (p[k] as String).trim().isNotEmpty)
          (p[k] as String).trim(),
    ].firstOrNull;
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: DabblerSpacing.space6,
      ),
      child: DabblerNotificationRow(
        leading: DabblerIconTile.named(
          event.subjectType == 'reward' ? 'cup' : 'activity',
          tone: event.subjectType == 'reward'
              ? DabblerIconTileTone.amber
              : DabblerIconTileTone.info,
          size: DabblerSizing.touchTargetMin,
        ),
        actor: title,
        subject: sub,
        pillLabel: l.notif_highlight_label,
        time: formatActivityClock(
          event.happenedAt,
          use24h: MediaQuery.alwaysUse24HourFormatOf(context),
          locale: l.localeName,
        ),
        unread: false,
        onTap: onTap,
      ),
    );
  }
}
