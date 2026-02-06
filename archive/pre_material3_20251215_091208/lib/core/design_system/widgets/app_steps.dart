import 'package:flutter/material.dart';
import 'package:dabbler/core/design_system/widgets/app_step.dart';

/// Horizontal stepper component from Figma
/// Node: 322:3071 (steps)
///
/// Displays multiple steps with connecting lines.
/// Size: 303x18px (for 5 steps)
///
/// Example:
/// ```dart
/// AppSteps(
///   totalSteps: 5,
///   currentStep: 2, // 0-indexed
/// )
/// ```
class AppSteps extends StatelessWidget {
  const AppSteps({
    required this.totalSteps,
    required this.currentStep,
    this.stepSize = 18.0,
    this.lineThickness = 2.0,
    this.spacing = 12.0,
    this.color,
    super.key,
  }) : assert(totalSteps > 0, 'Total steps must be greater than 0'),
       assert(
         currentStep >= 0 && currentStep < totalSteps,
         'Current step must be between 0 and totalSteps-1',
       );

  /// Total number of steps
  final int totalSteps;

  /// Current active step (0-indexed)
  final int currentStep;

  /// Size of each step indicator (default: 18px)
  final double stepSize;

  /// Thickness of connecting lines (default: 2px)
  final double lineThickness;

  /// Spacing between step and line (default: 12px)
  final double spacing;

  /// Optional custom color (defaults to primary color from theme)
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final stepColor = color ?? Theme.of(context).colorScheme.primary;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        totalSteps * 2 - 1, // Steps + lines between them
        (index) {
          if (index.isEven) {
            // Step indicator
            final stepIndex = index ~/ 2;
            return AppStep(
              state: _getStepState(stepIndex),
              size: stepSize,
              color: stepColor,
            );
          } else {
            // Connecting line
            final lineIndex = index ~/ 2;
            final isCompleted = lineIndex < currentStep;
            return Padding(
              padding: EdgeInsets.symmetric(horizontal: spacing),
              child: Container(
                width: 40.0, // Line width from Figma
                height: lineThickness,
                decoration: BoxDecoration(
                  color: isCompleted ? stepColor : stepColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(lineThickness / 2),
                ),
              ),
            );
          }
        },
      ),
    );
  }

  AppStepState _getStepState(int stepIndex) {
    if (stepIndex < currentStep) {
      return AppStepState.done;
    } else if (stepIndex == currentStep) {
      return AppStepState.current;
    } else {
      return AppStepState.defaultState;
    }
  }
}
