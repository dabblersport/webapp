import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';

/// Progress indicator for the early-bird check-in challenge.
///
/// Shows Week 1 (days 1-7), then Week 2 (days 8-14) after Week 1 is complete.
/// Built from the design system: a [DabblerSurface] per week holding a
/// [DabblerBadge], the day count and a [DabblerProgressBar].
class CheckInProgressIndicator extends StatelessWidget {
  const CheckInProgressIndicator({
    super.key,
    required this.completedDays,
    this.totalDays = 14,
  });

  final int completedDays;
  final int totalDays;

  @override
  Widget build(BuildContext context) {
    // Determine which week we're in
    final isWeek1 = completedDays < 7;
    final currentWeek = isWeek1 ? 1 : 2;
    final daysInCurrentWeek = isWeek1 ? completedDays : (completedDays - 7);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Week 1
        _WeekProgressCard(
          weekNumber: 1,
          completedDays: completedDays >= 7 ? 7 : completedDays,
          totalDays: 7,
          isActive: currentWeek == 1,
          isCompleted: completedDays >= 7,
        ),

        // Show Week 2 only after Week 1 is complete
        if (completedDays >= 7) ...[
          const DabblerGap.v(DabblerSpacing.space2),
          _WeekProgressCard(
            weekNumber: 2,
            completedDays: daysInCurrentWeek,
            totalDays: 7,
            isActive: currentWeek == 2,
            isCompleted: completedDays >= 14,
          ),
        ],
      ],
    );
  }
}

/// Individual week progress card.
class _WeekProgressCard extends StatelessWidget {
  const _WeekProgressCard({
    required this.weekNumber,
    required this.completedDays,
    required this.totalDays,
    required this.isActive,
    required this.isCompleted,
  });

  final int weekNumber;
  final int completedDays;
  final int totalDays;
  final bool isActive;
  final bool isCompleted;

  @override
  Widget build(BuildContext context) {
    final colors = DabblerColors.of(context);
    final progressValue = completedDays / totalDays;

    return DabblerSurface(
      variant: isActive
          ? DabblerSurfaceVariant.brandTint
          : DabblerSurfaceVariant.grey,
      padding: DabblerInsets.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              DabblerBadge(label: 'Week $weekNumber'),
              if (isCompleted) ...[
                const DabblerGap.h(DabblerSpacing.space2),
                DabblerIcon(
                  'tick-circle',
                  size: DabblerSizing.iconInline,
                  weight: DabblerIconWeight.bold,
                  color: colors.brandPrimary,
                ),
              ],
              const Spacer(),
              DabblerText(
                '$completedDays/$totalDays days',
                style: DabblerType.caption1,
                tone: isActive
                    ? DabblerTextTone.brand
                    : DabblerTextTone.secondary,
              ),
            ],
          ),
          const DabblerGap.v(DabblerSpacing.space2),
          DabblerProgressBar(
            value: progressValue,
            size: DabblerProgressBarSize.sm,
          ),
        ],
      ),
    );
  }
}
