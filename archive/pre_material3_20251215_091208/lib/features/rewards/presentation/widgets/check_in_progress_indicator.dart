import 'package:dabbler/core/design_system/tokens/design_tokens.dart';
import 'package:flutter/material.dart';

/// Material Design native progress indicator for check-in tracking
/// Shows Week 1 (days 1-7), then Week 2 (days 8-14) after Week 1 is complete
class CheckInProgressIndicator extends StatelessWidget {
  const CheckInProgressIndicator({
    super.key,
    required this.completedDays,
    this.totalDays = 14,
    this.segmentColor,
    this.incompleteColor,
    this.height = 40,
    this.spacing = 8,
  });

  final int completedDays;
  final int totalDays;
  final Color? segmentColor;
  final Color? incompleteColor;
  final double height;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Determine which week we're in
    final isWeek1 = completedDays < 7;
    final currentWeek = isWeek1 ? 1 : 2;
    final daysInCurrentWeek = isWeek1 ? completedDays : (completedDays - 7);
    final progressValue = daysInCurrentWeek / 7;

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
          colorScheme: colorScheme,
          theme: theme,
        ),

        // Show Week 2 only after Week 1 is complete
        if (completedDays >= 7) ...[
          const SizedBox(height: DesignTokens.spacingSm),
          _WeekProgressCard(
            weekNumber: 2,
            completedDays: daysInCurrentWeek,
            totalDays: 7,
            isActive: currentWeek == 2,
            isCompleted: completedDays >= 14,
            colorScheme: colorScheme,
            theme: theme,
          ),
        ],
      ],
    );
  }
}

/// Individual week progress card using Material Design components
class _WeekProgressCard extends StatelessWidget {
  const _WeekProgressCard({
    required this.weekNumber,
    required this.completedDays,
    required this.totalDays,
    required this.isActive,
    required this.isCompleted,
    required this.colorScheme,
    required this.theme,
  });

  final int weekNumber;
  final int completedDays;
  final int totalDays;
  final bool isActive;
  final bool isCompleted;
  final ColorScheme colorScheme;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final progressValue = completedDays / totalDays;

    return Container(
      padding: const EdgeInsets.all(DesignTokens.spacingSm),
      decoration: BoxDecoration(
        color: isActive
            ? colorScheme.primaryContainer.withOpacity(0.3)
            : colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(DesignTokens.spacingSm),
        border: Border.all(
          color: isActive
              ? colorScheme.primary.withOpacity(0.5)
              : colorScheme.outlineVariant.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  // Week indicator
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: DesignTokens.spacingXs,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: isCompleted
                          ? colorScheme.primary
                          : isActive
                          ? colorScheme.primary.withOpacity(0.2)
                          : colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Week $weekNumber',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: isCompleted
                            ? colorScheme.onPrimary
                            : isActive
                            ? colorScheme.primary
                            : colorScheme.onSurfaceVariant,
                        fontWeight: DesignTokens.fontWeightSemibold,
                      ),
                    ),
                  ),

                  // Completed checkmark
                  if (isCompleted) ...[
                    const SizedBox(width: DesignTokens.spacingXs),
                    Icon(
                      Icons.check_circle,
                      size: 16,
                      color: colorScheme.primary,
                    ),
                  ],
                ],
              ),

              // Days count
              Text(
                '$completedDays/$totalDays days',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: isActive
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                  fontWeight: DesignTokens.fontWeightMedium,
                ),
              ),
            ],
          ),

          const SizedBox(height: DesignTokens.spacingXs),

          // Material Design LinearProgressIndicator
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progressValue,
              minHeight: 6,
              backgroundColor: colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(
                isCompleted ? colorScheme.primary : colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact version with smaller segments
class CompactCheckInProgressIndicator extends StatelessWidget {
  const CompactCheckInProgressIndicator({
    super.key,
    required this.completedDays,
    this.totalDays = 14,
    this.segmentColor,
    this.incompleteColor,
  });

  final int completedDays;
  final int totalDays;
  final Color? segmentColor;
  final Color? incompleteColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveSegmentColor = segmentColor ?? theme.colorScheme.primary;
    final effectiveIncompleteColor =
        incompleteColor ?? theme.colorScheme.surfaceContainerHighest;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(totalDays, (index) {
        final isCompleted = index < completedDays;

        return Padding(
          padding: EdgeInsets.only(right: index < totalDays - 1 ? 4 : 0),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: isCompleted
                  ? effectiveSegmentColor
                  : effectiveIncompleteColor,
              shape: BoxShape.circle,
            ),
          ),
        );
      }),
    );
  }
}
