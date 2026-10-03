// Extracted from notifications_screen_v2.dart by KAN-152 (pt.C of the split).
// Public rather than library-private: Dart privacy is per-file, so the classes
// must widen to be usable from the screen. No behaviour change.
//
// KAN-420: the digest strip is three DabblerStatTile cells under a caption. The
// 8-day sparkline has no DS equivalent and is dropped (DS gap, see the KAN-420
// report); the numbers it summarised are unchanged.

import 'package:dabbler/core/constants/timing/profile_timing.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/features/activities/data/models/activity_feed_event.dart';

class ActivitySummaryCard extends StatelessWidget {
  final dynamic state;
  const ActivitySummaryCard({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final activities = (state.activities as List<ActivityFeedEvent>);
    final cutoff = DateTime.now().subtract(ProfileTiming.week);
    final recent = activities
        .where((a) => a.happenedAt.isAfter(cutoff))
        .toList();
    final total = recent.length;
    final rewards = recent.where((a) => a.subjectType == 'reward').length;

    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        DabblerSpacing.space6,
        DabblerSpacing.space1,
        DabblerSpacing.space6,
        DabblerSpacing.space4,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DabblerText(
            l10n.activity_last_7_days,
            style: DabblerType.caption1,
            tone: DabblerTextTone.secondary,
          ),
          const SizedBox(height: DabblerSpacing.space3),
          DabblerStatGrid(
            children: [
              DabblerStatTile(value: '$total', label: 'events'),
              DabblerStatTile(value: '+$rewards', label: 'rewards'),
              DabblerStatTile(
                value: '${_streak(activities)}',
                label: l10n.activity_day_streak,
              ),
            ],
          ),
        ],
      ),
    );
  }

  int _streak(List<ActivityFeedEvent> all) {
    if (all.isEmpty) return 0;
    final daysWithActivity = all
        .map(
          (a) =>
              DateTime(a.happenedAt.year, a.happenedAt.month, a.happenedAt.day),
        )
        .toSet();
    int streak = 0;
    var cursor = DateTime.now();
    cursor = DateTime(cursor.year, cursor.month, cursor.day);
    while (daysWithActivity.contains(cursor)) {
      streak += 1;
      cursor = cursor.subtract(ProfileTiming.day);
    }
    return streak;
  }
}
