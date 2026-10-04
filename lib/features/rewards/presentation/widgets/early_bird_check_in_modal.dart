import 'package:dabbler/features/rewards/presentation/widgets/check_in_progress_indicator.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';

/// Modal dialog that welcomes early bird testers and prompts for check-in.
///
/// Built from the design system: a [DabblerDialog] holding a hero icon, the
/// two-week [CheckInProgressIndicator], the streak badge and the days-left
/// banner. No design frame exists for it; design-system defaults throughout.
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
    final colors = DabblerColors.of(context);

    return DabblerDialog(
      dismissible: false,
      title: isCompleted
          ? 'Early Bird Badge Earned!'
          : 'Welcome Back, Early Bird!',
      description: isCompleted
          ? 'You\'ve completed the 14-day challenge!'
          : currentDay == 0
          ? 'Start your journey today!'
          : 'Day $currentDay of 14',
      primaryAction: isCompleted
          ? DabblerDialogAction(
              label: 'Awesome!',
              onPressed: () => Navigator.of(context).pop(),
            )
          : DabblerDialogAction(label: 'Check In Now', onPressed: onCheckIn),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const DabblerGap.v(DabblerSpacing.space4),
          Center(
            child: DabblerHeroIcon(
              isCompleted ? 'medal-star' : 'sun-1',
              tone: isCompleted
                  ? DabblerHeroIconTone.success
                  : DabblerHeroIconTone.brand,
            ),
          ),
          const DabblerGap.v(DabblerSpacing.space4),

          // Progress card
          DabblerCard(
            header: DabblerKeyValueRow(
              label: 'Progress',
              value: '$currentDay/14 days',
              valueTone: DabblerTextTone.brand,
            ),
            child: CheckInProgressIndicator(
              completedDays: currentDay,
              totalDays: 14,
            ),
          ),

          // Streak badge
          if (streakCount > 1) ...[
            const DabblerGap.v(DabblerSpacing.space4),
            Center(
              child: DabblerBadge(
                label: '$streakCount Day Streak!',
                status: colors.warning,
                icon: const DabblerIcon(
                  'flash-1',
                  size: DabblerSizing.iconInline,
                ),
              ),
            ),
          ],

          // Days remaining info
          if (!isCompleted && daysRemaining > 0) ...[
            const DabblerGap.v(DabblerSpacing.space4),
            DabblerBanner(
              tone: DabblerBannerTone.neutral,
              message:
                  '$daysRemaining ${daysRemaining == 1 ? 'day' : 'days'} left to unlock your badge',
            ),
          ],
        ],
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
    // Not dismissible: the user must check in or tap Awesome to close.
    return showDabblerDialog<bool>(
      context: context,
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
