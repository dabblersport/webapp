// Extracted from notifications_screen_v2.dart by KAN-152 (pt.C of the split).
// Public rather than library-private: Dart privacy is per-file, so the classes
// must widen to be usable from the screen. No behaviour change.

import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:dabbler/core/design_system/tokens/design_tokens.dart';
import 'package:dabbler/themes/app_theme.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/features/activities/data/models/activity_feed_event.dart';
import 'sparkline_painter.dart';

class ActivitySummaryCard extends StatelessWidget {
  final dynamic state;
  const ActivitySummaryCard({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final scheme = context.getCategoryTheme('main');
    final activities = (state.activities as List<ActivityFeedEvent>);
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    final recent =
        activities.where((a) => a.happenedAt.isAfter(cutoff)).toList();
    final total = recent.length;
    final rewards = recent.where((a) => a.subjectType == 'reward').length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 12),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [cs.primaryContainer, cs.surfaceContainerHigh],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: cs.onSurface.withValues(alpha: 0.10),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.of(context).activity_last_7_days,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.4,
                      color: cs.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _statColumn(
                        context,
                        value: '$total',
                        label: 'events',
                        valueSize: 26,
                        valueColor: cs.onSurface,
                      ),
                      const SizedBox(width: 16),
                      _statColumn(
                        context,
                        value: '+$rewards',
                        label: 'rewards',
                        valueSize: 18,
                        valueColor: DesignTokens.success,
                      ),
                      const SizedBox(width: 16),
                      _statColumn(
                        context,
                        valueWidget: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Iconsax.flash_1_copy,
                              size: 14,
                              color: DesignTokens.warning,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              '${_streak(activities)}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: DesignTokens.warning,
                              ),
                            ),
                          ],
                        ),
                        label: AppLocalizations.of(context).activity_day_streak,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 84,
              height: 46,
              child: CustomPaint(
                painter: SparklinePainter(
                  color: scheme.primary,
                  data: _bucketByDay(activities, days: 8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  int _streak(List<ActivityFeedEvent> all) {
    if (all.isEmpty) return 0;
    final daysWithActivity = all
        .map((a) =>
            DateTime(a.happenedAt.year, a.happenedAt.month, a.happenedAt.day))
        .toSet();
    int streak = 0;
    var cursor = DateTime.now();
    cursor = DateTime(cursor.year, cursor.month, cursor.day);
    while (daysWithActivity.contains(cursor)) {
      streak += 1;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  List<int> _bucketByDay(List<ActivityFeedEvent> all, {required int days}) {
    final buckets = List<int>.filled(days, 0);
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day)
        .subtract(Duration(days: days - 1));
    for (final a in all) {
      final d = DateTime(
          a.happenedAt.year, a.happenedAt.month, a.happenedAt.day);
      final diff = d.difference(start).inDays;
      if (diff >= 0 && diff < days) buckets[diff] += 1;
    }
    return buckets;
  }

  Widget _statColumn(
    BuildContext context, {
    String? value,
    Widget? valueWidget,
    required String label,
    double valueSize = 18,
    Color? valueColor,
  }) {
    final cs = context.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        valueWidget ??
            Text(
              value!,
              style: TextStyle(
                fontSize: valueSize,
                fontWeight: FontWeight.w900,
                height: 1,
                letterSpacing: -0.6,
                color: valueColor ?? cs.onSurface,
              ),
            ),
        const SizedBox(height: 3),
        Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: cs.onPrimaryContainer,
          ),
        ),
      ],
    );
  }
}
