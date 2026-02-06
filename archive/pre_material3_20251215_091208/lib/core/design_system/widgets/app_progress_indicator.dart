import 'package:flutter/material.dart';
import 'package:dabbler/core/design_system/design_system.dart';

/// Complete progress indicator widget from Figma
/// Node: 322:3364 (progress)
///
/// Displays progress steps with optional title and description.
/// Size: 327x64px
///
/// Example:
/// ```dart
/// AppProgressIndicator(
///   totalSteps: 5,
///   currentStep: 2,
///   title: 'Personal info',
///   description: 'Enter your details to get started',
/// )
/// ```
class AppProgressIndicator extends StatelessWidget {
  const AppProgressIndicator({
    required this.totalSteps,
    required this.currentStep,
    this.title,
    this.description,
    this.color,
    super.key,
  });

  /// Total number of steps
  final int totalSteps;

  /// Current active step (0-indexed)
  final int currentStep;

  /// Optional title text
  final String? title;

  /// Optional description text
  final String? description;

  /// Optional custom color (defaults to primary color from theme)
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(
          color: colorScheme.outline.withOpacity(0.2),
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Title and description
          if (title != null || description != null) ...[
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null)
                  Text(
                    title!,
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                if (title != null && description != null)
                  SizedBox(height: AppSpacing.xs),
                if (description != null)
                  Text(
                    description!,
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
            SizedBox(height: AppSpacing.md),
          ],

          // Steps indicator
          Center(
            child: AppSteps(
              totalSteps: totalSteps,
              currentStep: currentStep,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
