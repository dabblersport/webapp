import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:math' as math;

import 'package:dabbler/data/models/rewards/achievement.dart';
import 'package:dabbler/data/models/rewards/badge_tier.dart';
import 'package:dabbler/data/models/rewards/user_progress.dart';

enum ProgressSize { small, medium, large }

class ProgressVisualization extends StatelessWidget {
  final Achievement achievement;
  final UserProgress userProgress;
  final ProgressSize size;
  final bool animated;

  const ProgressVisualization({
    super.key,
    required this.achievement,
    required this.userProgress,
    this.size = ProgressSize.medium,
    this.animated = true,
  });

  @override
  Widget build(BuildContext context) {
    switch (achievement.type) {
      case AchievementType.single:
        return _buildSingleProgress();
      case AchievementType.cumulative:
        return _buildCumulativeProgress();
      case AchievementType.streak:
        return _buildStreakProgress();
      case AchievementType.conditional:
        return _buildConditionalProgress();
      case AchievementType.hidden:
        return _buildHiddenProgress();
      case AchievementType.standard:
        return _buildSingleProgress();
      case AchievementType.milestone:
        return _buildCumulativeProgress();
      case AchievementType.social:
        return _buildConditionalProgress();
      case AchievementType.challenge:
        return _buildSingleProgress();
    }
  }

  Widget _buildSingleProgress() {
    final progressValue = userProgress.calculateProgress() / 100.0;
    final isCompleted = userProgress.status == ProgressStatus.completed;

    return CircularProgressVisualization(
      progress: progressValue,
      isCompleted: isCompleted,
      size: size,
      animated: animated,
      color: _getProgressColor(),
    );
  }

  Widget _buildCumulativeProgress() {
    final progressValue = userProgress.calculateProgress() / 100.0;
    final current = _getCurrentValue();
    final target = _getTargetValue();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SegmentedProgressBar(
          progress: progressValue,
          segments: _getSegmentCount(),
          size: size,
          animated: animated,
          color: _getProgressColor(),
        ),
        const SizedBox(height: 4),
        Text(
          '$current / $target',
          style: TextStyle(
            fontSize: _getTextSize(),
            fontWeight: FontWeight.w500,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildStreakProgress() {
    final currentStreak = _getCurrentValue();
    final targetStreak = _getTargetValue();
    final progressValue = userProgress.calculateProgress() / 100.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StreakCalendar(
          currentStreak: currentStreak,
          targetStreak: targetStreak,
          progress: progressValue,
          size: size,
          animated: animated,
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            const Icon(
              Icons.local_fire_department,
              color: Colors.orange,
              size: 16,
            ),
            const SizedBox(width: 4),
            Text(
              '$currentStreak day streak',
              style: TextStyle(
                fontSize: _getTextSize(),
                fontWeight: FontWeight.w600,
                color: Colors.orange,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildConditionalProgress() {
    final steps = _getConditionalSteps();
    final completedSteps = _getCompletedSteps();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StepIndicator(
          totalSteps: steps.length,
          currentStep: completedSteps.length,
          size: size,
          animated: animated,
          color: _getProgressColor(),
        ),
        const SizedBox(height: 4),
        Text(
          '${completedSteps.length} / ${steps.length} conditions met',
          style: TextStyle(
            fontSize: _getTextSize(),
            fontWeight: FontWeight.w500,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildHiddenProgress() {
    if (userProgress.status == ProgressStatus.completed) {
      return _buildSingleProgress();
    }

    return MysteryProgress(size: size, animated: animated);
  }

  Color _getProgressColor() {
    switch (achievement.tier) {
      case BadgeTier.bronze:
        return const Color(0xFFCD7F32);
      case BadgeTier.silver:
        return const Color(0xFFC0C0C0);
      case BadgeTier.gold:
        return const Color(0xFFFFD700);
      case BadgeTier.platinum:
        return const Color(0xFFE5E4E2);
      case BadgeTier.diamond:
        return const Color(0xFFB9F2FF);
    }
  }

  double _getTextSize() {
    switch (size) {
      case ProgressSize.small:
        return 10;
      case ProgressSize.medium:
        return 12;
      case ProgressSize.large:
        return 14;
    }
  }

  int _getCurrentValue() {
    if (userProgress.currentProgress.containsKey('count')) {
      return userProgress.currentProgress['count'] as int? ?? 0;
    }
    if (userProgress.currentProgress.containsKey('streak')) {
      return userProgress.currentProgress['streak'] as int? ?? 0;
    }
    return 0;
  }

  int _getTargetValue() {
    if (userProgress.requiredProgress.containsKey('count')) {
      return userProgress.requiredProgress['count'] as int? ?? 1;
    }
    if (userProgress.requiredProgress.containsKey('streak')) {
      return userProgress.requiredProgress['streak'] as int? ?? 1;
    }
    return 1;
  }

  int _getSegmentCount() {
    final target = _getTargetValue();
    if (target <= 5) return target;
    if (target <= 10) return 5;
    if (target <= 20) return 10;
    return 20;
  }

  List<String> _getConditionalSteps() {
    final conditions =
        userProgress.requiredProgress['conditions'] as List<dynamic>?;
    return conditions?.cast<String>() ?? [];
  }

  List<String> _getCompletedSteps() {
    final completed =
        userProgress.currentProgress['completed'] as List<dynamic>?;
    return completed?.cast<String>() ?? [];
  }
}

// Circular progress for single achievements
class CircularProgressVisualization extends StatelessWidget {
  final double progress;
  final bool isCompleted;
  final ProgressSize size;
  final bool animated;
  final Color color;

  const CircularProgressVisualization({
    super.key,
    required this.progress,
    required this.isCompleted,
    required this.size,
    required this.animated,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final dimension = _getDimension();

    return SizedBox(
      width: dimension,
      height: dimension,
      child: Stack(
        children: [
          // Background circle
          Container(
            width: dimension,
            height: dimension,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withOpacity(0.1),
            ),
          ),

          // Progress indicator
          if (animated)
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: progress),
              duration: const Duration(milliseconds: 1500),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) {
                return CircularProgressIndicator(
                  value: value,
                  backgroundColor: Colors.transparent,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                  strokeWidth: _getStrokeWidth(),
                );
              },
            )
          else
            CircularProgressIndicator(
              value: progress,
              backgroundColor: Colors.transparent,
              valueColor: AlwaysStoppedAnimation<Color>(color),
              strokeWidth: _getStrokeWidth(),
            ),

          // Center icon
          Center(
            child: isCompleted
                ? Icon(Icons.check_circle, color: color, size: dimension * 0.4)
                : Text(
                    '${(progress * 100).round()}%',
                    style: TextStyle(
                      fontSize: dimension * 0.2,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  double _getDimension() {
    switch (size) {
      case ProgressSize.small:
        return 40;
      case ProgressSize.medium:
        return 60;
      case ProgressSize.large:
        return 80;
    }
  }

  double _getStrokeWidth() {
    switch (size) {
      case ProgressSize.small:
        return 3;
      case ProgressSize.medium:
        return 4;
      case ProgressSize.large:
        return 6;
    }
  }
}

// Segmented progress bar for cumulative achievements
class SegmentedProgressBar extends StatelessWidget {
  final double progress;
  final int segments;
  final ProgressSize size;
  final bool animated;
  final Color color;

  const SegmentedProgressBar({
    super.key,
    required this.progress,
    required this.segments,
    required this.size,
    required this.animated,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final height = _getHeight();
    final segmentWidth = _getSegmentWidth();
    final completedSegments = (progress * segments).floor();
    final partialProgress = (progress * segments) - completedSegments;

    return SizedBox(
      height: height,
      child: Row(
        children: List.generate(segments, (index) {
          Widget segment;

          if (index < completedSegments) {
            // Completed segment
            segment = Container(
              width: segmentWidth,
              height: height,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(height / 2),
              ),
            );
          } else if (index == completedSegments && partialProgress > 0) {
            // Partially completed segment
            segment = Container(
              width: segmentWidth,
              height: height,
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(height / 2),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: partialProgress,
                child: Container(
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(height / 2),
                  ),
                ),
              ),
            );
          } else {
            // Empty segment
            segment = Container(
              width: segmentWidth,
              height: height,
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(height / 2),
              ),
            );
          }

          if (animated && index <= completedSegments) {
            segment = segment
                .animate()
                .fadeIn(
                  duration: 200.ms,
                  delay: Duration(milliseconds: index * 100),
                )
                .scale(
                  begin: const Offset(0.8, 0.8),
                  end: const Offset(1.0, 1.0),
                  duration: 200.ms,
                  delay: Duration(milliseconds: index * 100),
                );
          }

          return Padding(
            padding: EdgeInsets.only(right: index < segments - 1 ? 4 : 0),
            child: segment,
          );
        }),
      ),
    );
  }

  double _getHeight() {
    switch (size) {
      case ProgressSize.small:
        return 6;
      case ProgressSize.medium:
        return 8;
      case ProgressSize.large:
        return 10;
    }
  }

  double _getSegmentWidth() {
    switch (size) {
      case ProgressSize.small:
        return 15;
      case ProgressSize.medium:
        return 20;
      case ProgressSize.large:
        return 25;
    }
  }
}

// Streak calendar visualization
class StreakCalendar extends StatelessWidget {
  final int currentStreak;
  final int targetStreak;
  final double progress;
  final ProgressSize size;
  final bool animated;

  const StreakCalendar({
    super.key,
    required this.currentStreak,
    required this.targetStreak,
    required this.progress,
    required this.size,
    required this.animated,
  });

  @override
  Widget build(BuildContext context) {
    final daySize = _getDaySize();
    final daysToShow = math.min(targetStreak, 14); // Show max 14 days

    return Wrap(
      spacing: 2,
      runSpacing: 2,
      children: List.generate(daysToShow, (index) {
        final isCompleted = index < currentStreak;
        final isToday = index == currentStreak - 1;

        Widget day = Container(
          width: daySize,
          height: daySize,
          decoration: BoxDecoration(
            color: isCompleted ? Colors.orange : Colors.grey.withOpacity(0.2),
            borderRadius: BorderRadius.circular(4),
            border: isToday ? Border.all(color: Colors.orange, width: 2) : null,
          ),
          child: isCompleted
              ? const Icon(
                  Icons.local_fire_department,
                  color: Colors.white,
                  size: 10,
                )
              : null,
        );

        if (animated && isCompleted) {
          day = day
              .animate()
              .fadeIn(
                duration: 200.ms,
                delay: Duration(milliseconds: index * 50),
              )
              .scale(
                begin: const Offset(0.5, 0.5),
                end: const Offset(1.0, 1.0),
                duration: 200.ms,
                delay: Duration(milliseconds: index * 50),
              );
        }

        return day;
      }),
    );
  }

  double _getDaySize() {
    switch (size) {
      case ProgressSize.small:
        return 12;
      case ProgressSize.medium:
        return 16;
      case ProgressSize.large:
        return 20;
    }
  }
}

// Step indicator for conditional achievements
class StepIndicator extends StatelessWidget {
  final int totalSteps;
  final int currentStep;
  final ProgressSize size;
  final bool animated;
  final Color color;

  const StepIndicator({
    super.key,
    required this.totalSteps,
    required this.currentStep,
    required this.size,
    required this.animated,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final stepSize = _getStepSize();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(totalSteps, (index) {
        final isCompleted = index < currentStep;
        final isCurrent = index == currentStep;

        Widget step = Container(
          width: stepSize,
          height: stepSize,
          decoration: BoxDecoration(
            color: isCompleted ? color : color.withOpacity(0.2),
            shape: BoxShape.circle,
            border: isCurrent ? Border.all(color: color, width: 2) : null,
          ),
          child: isCompleted
              ? Icon(Icons.check, color: Colors.white, size: stepSize * 0.6)
              : Center(
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      fontSize: stepSize * 0.4,
                      fontWeight: FontWeight.bold,
                      color: isCompleted ? Colors.white : color,
                    ),
                  ),
                ),
        );

        if (animated && isCompleted) {
          step = step
              .animate()
              .fadeIn(
                duration: 300.ms,
                delay: Duration(milliseconds: index * 100),
              )
              .scale(
                begin: const Offset(0.5, 0.5),
                end: const Offset(1.0, 1.0),
                duration: 300.ms,
                delay: Duration(milliseconds: index * 100),
              );
        }

        return Padding(
          padding: EdgeInsets.only(right: index < totalSteps - 1 ? 8 : 0),
          child: step,
        );
      }),
    );
  }

  double _getStepSize() {
    switch (size) {
      case ProgressSize.small:
        return 20;
      case ProgressSize.medium:
        return 24;
      case ProgressSize.large:
        return 28;
    }
  }
}

// Mystery progress for hidden achievements
class MysteryProgress extends StatelessWidget {
  final ProgressSize size;
  final bool animated;

  const MysteryProgress({
    super.key,
    required this.size,
    required this.animated,
  });

  @override
  Widget build(BuildContext context) {
    final dimension = _getDimension();

    Widget mystery = Container(
      width: dimension,
      height: dimension,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [
            Colors.purple.withOpacity(0.3),
            Colors.indigo.withOpacity(0.3),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Icon(
        Icons.help_outline,
        color: Colors.purple,
        size: dimension * 0.4,
      ),
    );

    if (animated) {
      mystery = mystery
          .animate(onPlay: (controller) => controller.repeat())
          .shimmer(duration: 2.seconds, color: Colors.purple.withOpacity(0.2));
    }

    return mystery;
  }

  double _getDimension() {
    switch (size) {
      case ProgressSize.small:
        return 40;
      case ProgressSize.medium:
        return 60;
      case ProgressSize.large:
        return 80;
    }
  }
}
