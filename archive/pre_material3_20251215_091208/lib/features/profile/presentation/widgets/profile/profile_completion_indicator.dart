import 'package:flutter/material.dart';
import 'dart:math' as math;

class ProfileCompletionIndicator extends StatefulWidget {
  final double completionPercentage;
  final List<CompletionStep> steps;
  final bool showSteps;
  final VoidCallback? onTapImprove;
  final Color? primaryColor;
  final double size;

  const ProfileCompletionIndicator({
    super.key,
    required this.completionPercentage,
    required this.steps,
    this.showSteps = true,
    this.onTapImprove,
    this.primaryColor,
    this.size = 120,
  }) : assert(completionPercentage >= 0 && completionPercentage <= 100);

  @override
  State<ProfileCompletionIndicator> createState() =>
      _ProfileCompletionIndicatorState();
}

class _ProfileCompletionIndicatorState extends State<ProfileCompletionIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _progressAnimation =
        Tween<double>(
          begin: 0.0,
          end: widget.completionPercentage / 100,
        ).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeInOut,
          ),
        );

    // Start animation after a brief delay
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _animationController.forward();
    });
  }

  @override
  void didUpdateWidget(ProfileCompletionIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.completionPercentage != widget.completionPercentage) {
      _progressAnimation =
          Tween<double>(
            begin: _progressAnimation.value,
            end: widget.completionPercentage / 100,
          ).animate(
            CurvedAnimation(
              parent: _animationController,
              curve: Curves.easeInOut,
            ),
          );
      _animationController.forward();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = widget.primaryColor ?? theme.primaryColor;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Circular progress indicator
          AnimatedBuilder(
            animation: _progressAnimation,
            builder: (context, child) {
              return CustomPaint(
                size: Size(widget.size, widget.size),
                painter: CircularProgressPainter(
                  progress: _progressAnimation.value,
                  color: color,
                  backgroundColor: color.withOpacity(0.1),
                  strokeWidth: 8,
                ),
                child: SizedBox(
                  width: widget.size,
                  height: widget.size,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedBuilder(
                          animation: _progressAnimation,
                          builder: (context, child) {
                            final displayPercentage =
                                (_progressAnimation.value * 100).round();
                            return Text(
                              '$displayPercentage%',
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: color,
                              ),
                            );
                          },
                        ),
                        Text(
                          'Complete',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.textTheme.bodySmall?.color
                                ?.withOpacity(0.6),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 16),

          // Completion message
          Text(
            _getCompletionMessage(widget.completionPercentage),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 8),

          Text(
            _getCompletionSubtitle(widget.completionPercentage),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),

          // Improvement button
          if (widget.completionPercentage < 100) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: widget.onTapImprove,
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Improve Profile'),
              ),
            ),
          ],

          // Completion steps
          if (widget.showSteps) ...[
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 16),
            _buildCompletionSteps(context, color),
          ],
        ],
      ),
    );
  }

  Widget _buildCompletionSteps(BuildContext context, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Profile Steps',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ...widget.steps.map((step) => _buildStepItem(context, step, color)),
      ],
    );
  }

  Widget _buildStepItem(
    BuildContext context,
    CompletionStep step,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: step.isCompleted ? color : Colors.transparent,
              shape: BoxShape.circle,
              border: Border.all(
                color: step.isCompleted ? color : color.withOpacity(0.3),
                width: 2,
              ),
            ),
            child: step.isCompleted
                ? const Icon(Icons.check, color: Colors.white, size: 14)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: step.isCompleted
                        ? FontWeight.w600
                        : FontWeight.normal,
                    color: step.isCompleted
                        ? null
                        : Theme.of(
                            context,
                          ).textTheme.bodyMedium?.color?.withOpacity(0.7),
                  ),
                ),
                if (step.description?.isNotEmpty == true)
                  Text(
                    step.description!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(
                        context,
                      ).textTheme.bodySmall?.color?.withOpacity(0.6),
                    ),
                  ),
              ],
            ),
          ),
          if (!step.isCompleted && step.onTap != null)
            IconButton(
              onPressed: step.onTap,
              icon: Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: color.withOpacity(0.7),
              ),
            ),
        ],
      ),
    );
  }

  String _getCompletionMessage(double percentage) {
    if (percentage >= 100) return 'Profile Complete!';
    if (percentage >= 80) return 'Almost There!';
    if (percentage >= 60) return 'Great Progress';
    if (percentage >= 40) return 'Getting Started';
    return 'Let\'s Build Your Profile';
  }

  String _getCompletionSubtitle(double percentage) {
    if (percentage >= 100) return 'Your profile is fully optimized';
    if (percentage >= 80) return 'Just a few more steps to go';
    if (percentage >= 60) return 'You\'re making good progress';
    if (percentage >= 40) return 'Add more info to stand out';
    return 'Complete your profile to get noticed';
  }
}

class CircularProgressPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color backgroundColor;
  final double strokeWidth;

  CircularProgressPainter({
    required this.progress,
    required this.color,
    required this.backgroundColor,
    this.strokeWidth = 8,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Background circle
    final backgroundPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, backgroundPaint);

    // Progress arc
    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    const startAngle = -math.pi / 2; // Start from top
    final sweepAngle = 2 * math.pi * progress;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(CircularProgressPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.backgroundColor != backgroundColor;
  }
}

class CompletionStep {
  final String title;
  final String? description;
  final bool isCompleted;
  final VoidCallback? onTap;

  const CompletionStep({
    required this.title,
    this.description,
    required this.isCompleted,
    this.onTap,
  });
}

// Compact version for smaller spaces
class CompactProfileCompletionIndicator extends StatelessWidget {
  final double completionPercentage;
  final VoidCallback? onTap;
  final Color? color;

  const CompactProfileCompletionIndicator({
    super.key,
    required this.completionPercentage,
    this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = color ?? theme.primaryColor;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: primaryColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: primaryColor.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 40,
              height: 40,
              child: CustomPaint(
                painter: CircularProgressPainter(
                  progress: completionPercentage / 100,
                  color: primaryColor,
                  backgroundColor: primaryColor.withOpacity(0.2),
                  strokeWidth: 4,
                ),
                child: Center(
                  child: Text(
                    '${completionPercentage.round()}%',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                      fontSize: 10,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Profile Completion',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    completionPercentage < 100
                        ? 'Complete your profile'
                        : 'Profile complete!',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
            if (completionPercentage < 100)
              Icon(Icons.arrow_forward_ios, color: primaryColor, size: 16),
          ],
        ),
      ),
    );
  }
}
