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
          const SizedBox(height: DabblerSpacing.space2),
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
      padding: const EdgeInsets.all(DabblerSpacing.space3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            children: [
              DabblerBadge(label: 'Week $weekNumber'),

              // Completed checkmark
              if (isCompleted) ...[
                const SizedBox(width: DabblerSpacing.space2),
                DabblerIcon(
                  'tick-circle',
                  size: 16,
                  weight: DabblerIconWeight.bold,
                  color: colors.brandPrimary,
                ),
              ],

              const Spacer(),

              // Days count
              Text(
                '$completedDays/$totalDays days',
                style: DabblerType.caption1
                    .resolveForDirection(Directionality.of(context))
                    .copyWith(
                      color: isActive
                          ? colors.brandPrimary
                          : colors.textSecondary,
                    ),
              ),
            ],
          ),

          const SizedBox(height: DabblerSpacing.space2),

          DabblerProgressBar(
            value: progressValue,
            size: DabblerProgressBarSize.sm,
          ),
        ],
      ),
    );
  }
}

/// Compact version: one dot per day.
class CompactCheckInProgressIndicator extends StatelessWidget {
  const CompactCheckInProgressIndicator({
    super.key,
    required this.completedDays,
    this.totalDays = 14,
  });

  final int completedDays;
  final int totalDays;

  @override
  Widget build(BuildContext context) {
    final colors = DabblerColors.of(context);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(totalDays, (index) {
          final isCompleted = index < completedDays;

          return Padding(
            padding: EdgeInsetsDirectional.only(
              end: index < totalDays - 1 ? DabblerSpacing.space1 : 0,
            ),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: isCompleted ? colors.brandPrimary : colors.surfaceSunken,
                shape: BoxShape.circle,
              ),
            ),
          );
        }),
      ),
    );
  }
}
