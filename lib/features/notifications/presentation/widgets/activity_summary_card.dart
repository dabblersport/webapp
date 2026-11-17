// Extracted from notifications_screen_v2.dart by KAN-152 (pt.C of the split).
//
// KAN-420: the digest strip is DabblerStatTile cells under a caption.
//
// KAN-990: the window is today and the six local days before it
// ([activityLastSevenDays]); both labels are localized. The "day streak" tile
// is gone: no data source defines that streak (the only server streak is the
// 14-day Early Bird check-in program, a different thing), and the old figure
// was counted from whichever pages happened to be loaded.

import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';

import 'package:dabbler/features/activities/domain/activity_log_time.dart';
import 'package:dabbler/features/activities/presentation/controllers/activity_log_controller.dart';
import 'package:dabbler/l10n/app_localizations.dart';

class ActivitySummaryCard extends StatelessWidget {
  const ActivitySummaryCard({super.key, required this.state, this.now});

  final ActivityLogState state;

  /// Two tiles share one grid row.
  static const int _halfRow = DabblerStatGrid.columns ~/ 2;

  /// The clock; null is the current time (tests pin it).
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ActivityLastSevenDays week = activityLastSevenDays(
      state.activities,
      now ?? DateTime.now(),
    );

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
              DabblerStatTile(
                value: DabblerType.toWesternDigits('${week.events}'),
                label: l10n.activity_stat_events,
                span: _halfRow,
              ),
              DabblerStatTile(
                value: DabblerType.toWesternDigits('${week.rewards}'),
                label: l10n.activity_stat_rewards,
                span: _halfRow,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
