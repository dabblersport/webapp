import 'package:dabbler/features/rewards/presentation/widgets/check_in_progress_indicator.dart';
import 'package:dabbler/core/design_system/tokens/design_tokens.dart';
import 'package:flutter/material.dart';

/// Modal dialog that welcomes early bird testers and prompts for check-in
/// Follows Material 3 design guidelines with custom theming
class EarlyBirdCheckInModal extends StatelessWidget {
  const EarlyBirdCheckInModal({
    super.key,
    required this.currentDay,
    required this.streakCount,
    required this.daysRemaining,
    required this.onCheckIn,
    this.isCompleted = false,
  });

  final int currentDay;
  final int streakCount;
  final int daysRemaining;
  final VoidCallback onCheckIn;
  final bool isCompleted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Dialog(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DesignTokens.spacingLg),
      ),
      clipBehavior: Clip.antiAlias,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(DesignTokens.spacingLg),
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(DesignTokens.spacingLg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header section with icon
                Center(
                  child: Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          colorScheme.primaryContainer,
                          colorScheme.primaryContainer.withOpacity(0.7),
                        ],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: colorScheme.primary.withOpacity(0.15),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        isCompleted ? '🏆' : '🐦',
                        style: const TextStyle(fontSize: 48),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: DesignTokens.spacingLg),

                // Title
                Text(
                  isCompleted
                      ? 'Early Bird Badge Earned!'
                      : 'Welcome Back, Early Bird!',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: DesignTokens.fontWeightBold,
                    color: colorScheme.onSurface,
                    letterSpacing: -0.5,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: DesignTokens.spacingXs),

                // Subtitle
                Text(
                  isCompleted
                      ? 'You\'ve completed the 14-day challenge! 🎉'
                      : currentDay == 0
                      ? 'Start your journey today!'
                      : 'Day $currentDay of 14',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: DesignTokens.spacingLg),

                // Progress card
                Container(
                  padding: const EdgeInsets.all(DesignTokens.spacingMd),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(DesignTokens.spacingSm),
                    border: Border.all(
                      color: colorScheme.outlineVariant.withOpacity(0.5),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      // Progress label
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Progress',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              fontWeight: DesignTokens.fontWeightMedium,
                            ),
                          ),
                          Text(
                            '$currentDay/14 days',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: colorScheme.primary,
                              fontWeight: DesignTokens.fontWeightSemibold,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: DesignTokens.spacingSm),

                      // Progress indicator
                      CheckInProgressIndicator(
                        completedDays: currentDay,
                        totalDays: 14,
                      ),
                    ],
                  ),
                ),

                // Streak badge
                if (streakCount > 1) ...[
                  const SizedBox(height: DesignTokens.spacingMd),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: DesignTokens.spacingMd,
                      vertical: DesignTokens.spacingSm,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.orange.shade400,
                          Colors.deepOrange.shade500,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(
                        DesignTokens.spacingSm,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.orange.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('🔥', style: TextStyle(fontSize: 24)),
                        const SizedBox(width: DesignTokens.spacingXs),
                        Text(
                          '$streakCount Day Streak!',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: DesignTokens.fontWeightBold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: DesignTokens.spacingLg),

                // Days remaining info
                if (!isCompleted && daysRemaining > 0)
                  Container(
                    padding: const EdgeInsets.all(DesignTokens.spacingSm),
                    decoration: BoxDecoration(
                      color: colorScheme.secondaryContainer.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(
                        DesignTokens.spacingXs,
                      ),
                    ),
                    child: Text(
                      '$daysRemaining ${daysRemaining == 1 ? 'day' : 'days'} left to unlock your badge',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSecondaryContainer,
                        fontWeight: DesignTokens.fontWeightMedium,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                const SizedBox(height: DesignTokens.spacingLg),

                // Action buttons
                if (!isCompleted)
                  FilledButton(
                    onPressed: onCheckIn,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        vertical: DesignTokens.spacingMd,
                      ),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          DesignTokens.spacingSm,
                        ),
                      ),
                    ),
                    child: Text(
                      'Check In Now',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: colorScheme.onPrimary,
                        fontWeight: DesignTokens.fontWeightSemibold,
                      ),
                    ),
                  )
                else
                  FilledButton.tonal(
                    onPressed: () => Navigator.of(context).pop(),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        vertical: DesignTokens.spacingMd,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          DesignTokens.spacingSm,
                        ),
                      ),
                    ),
                    child: Text(
                      'Awesome!',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: DesignTokens.fontWeightSemibold,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Show the modal dialog
  static Future<bool?> show(
    BuildContext context, {
    required int currentDay,
    required int streakCount,
    required int daysRemaining,
    required VoidCallback onCheckIn,
    bool isCompleted = false,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false, // Must check in or tap Awesome to close
      builder: (context) => EarlyBirdCheckInModal(
        currentDay: currentDay,
        streakCount: streakCount,
        daysRemaining: daysRemaining,
        onCheckIn: onCheckIn,
        isCompleted: isCompleted,
      ),
    );
  }
}
