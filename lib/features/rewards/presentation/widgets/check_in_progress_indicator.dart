import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';

/// Progress indicator for the early-bird check-in challenge.
///
/// Shows Week 1 (days 1-7), then Week 2 (days 8-14) after Week 1 is complete,
/// each as a [DabblerProgressCard].
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
    final isWeek1 = completedDays < 7;
    final week1Days = completedDays >= 7 ? 7 : completedDays;
    final week2Days = completedDays - 7;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DabblerProgressCard(
          label: 'Week 1',
          caption: '$week1Days/7 days',
          value: week1Days / 7,
          active: isWeek1,
          completed: completedDays >= 7,
        ),
        // Week 2 only after Week 1 is complete.
        if (completedDays >= 7) ...[
          const DabblerGap.v(DabblerSpacing.space2),
          DabblerProgressCard(
            label: 'Week 2',
            caption: '$week2Days/7 days',
            value: week2Days / 7,
            active: !isWeek1,
            completed: completedDays >= 14,
          ),
        ],
      ],
    );
  }
}
