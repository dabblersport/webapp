import 'package:flutter/material.dart';

/// Step state enum for AppStep component
enum AppStepState {
  /// Default/incomplete state - hollow circle
  defaultState,

  /// Current/active state - filled circle
  current,

  /// Completed state - checkmark
  done,
}

/// Individual step indicator component from Figma
/// Node: 322:3118 (Step Component Set)
///
/// Displays a step indicator with three states:
/// - Default: Hollow circle (未完成)
/// - Current: Filled circle (当前)
/// - Done: Checkmark circle (已完成)
///
/// Size: 18x18px
class AppStep extends StatelessWidget {
  const AppStep({required this.state, this.size = 18.0, this.color, super.key});

  /// The current state of the step
  final AppStepState state;

  /// Size of the step indicator (default: 18px)
  final double size;

  /// Optional custom color (defaults to primary color from theme)
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final stepColor = color ?? Theme.of(context).colorScheme.primary;

    return SizedBox(
      width: size,
      height: size,
      child: _buildStepIcon(stepColor),
    );
  }

  Widget _buildStepIcon(Color stepColor) {
    switch (state) {
      case AppStepState.defaultState:
        return _buildDefaultStep(stepColor);
      case AppStepState.current:
        return _buildCurrentStep(stepColor);
      case AppStepState.done:
        return _buildDoneStep(stepColor);
    }
  }

  /// Default state: Hollow circle with border
  Widget _buildDefaultStep(Color stepColor) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: stepColor.withOpacity(0.3), width: 2.0),
      ),
    );
  }

  /// Current state: Filled circle with inner dot
  Widget _buildCurrentStep(Color stepColor) {
    return Container(
      decoration: BoxDecoration(shape: BoxShape.circle, color: stepColor),
      child: Center(
        child: Container(
          width: size * 0.4, // Inner circle is 40% of total size
          height: size * 0.4,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  /// Done state: Checkmark in circle
  Widget _buildDoneStep(Color stepColor) {
    return Container(
      decoration: BoxDecoration(shape: BoxShape.circle, color: stepColor),
      child: Icon(
        Icons.check,
        size: size * 0.6, // Icon is 60% of total size
        color: Colors.white,
      ),
    );
  }
}
