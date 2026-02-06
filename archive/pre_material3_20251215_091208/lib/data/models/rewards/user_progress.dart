import 'achievement.dart';

/// Status of user progress towards an achievement
enum ProgressStatus {
  /// Not started yet
  notStarted,

  /// In progress
  inProgress,

  /// Completed successfully
  completed,

  /// Expired without completion
  expired,
}

/// Entity tracking user progress towards achievements
class UserProgress {
  final String id;
  final String userId;
  final String achievementId;
  final Map<String, dynamic> currentProgress;
  final Map<String, dynamic> requiredProgress;
  final ProgressStatus status;
  final DateTime? completedAt;
  final DateTime? expiresAt;
  final DateTime startedAt;
  final DateTime updatedAt;
  final Achievement? achievement;
  final Map<String, dynamic>? metadata;

  // Additional properties needed by rewards service
  final Map<String, dynamic> stats;
  final Map<String, dynamic> streaks;
  final double totalPoints;

  const UserProgress({
    required this.id,
    required this.userId,
    required this.achievementId,
    required this.currentProgress,
    required this.requiredProgress,
    required this.status,
    this.completedAt,
    this.expiresAt,
    required this.startedAt,
    required this.updatedAt,
    this.achievement,
    this.metadata,
    this.stats = const {},
    this.streaks = const {},
    this.totalPoints = 0.0,
  });

  /// Calculates progress percentage (0-100)
  double calculateProgress() {
    if (status == ProgressStatus.completed) return 100.0;
    if (status == ProgressStatus.notStarted) return 0.0;
    if (status == ProgressStatus.expired) return 0.0;

    double totalProgress = 0.0;
    int criteriaCount = 0;

    for (final key in requiredProgress.keys) {
      final required = requiredProgress[key];
      final current = currentProgress[key] ?? 0;

      if (required is num && required > 0) {
        final progress = (current as num) / required;
        totalProgress += progress.clamp(0.0, 1.0);
        criteriaCount++;
      }
    }

    if (criteriaCount == 0) return 0.0;
    return (totalProgress / criteriaCount * 100).clamp(0.0, 100.0);
  }

  /// Checks if the achievement is complete
  bool isComplete() {
    return status == ProgressStatus.completed;
  }

  /// Checks if progress has expired
  bool isExpired() {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!) &&
        status != ProgressStatus.completed;
  }

  /// Gets a human-readable progress description
  String getProgressDescription() {
    if (status == ProgressStatus.completed) {
      return 'Completed';
    }

    if (status == ProgressStatus.expired) {
      return 'Expired';
    }

    if (status == ProgressStatus.notStarted) {
      return 'Not started';
    }

    final progress = calculateProgress();
    if (progress == 0) {
      return 'Just started';
    } else if (progress < 25) {
      return 'Getting started';
    } else if (progress < 50) {
      return 'Making progress';
    } else if (progress < 75) {
      return 'More than halfway';
    } else if (progress < 100) {
      return 'Almost there';
    } else {
      return 'Complete';
    }
  }

  /// Gets detailed progress breakdown by criteria
  Map<String, String> getDetailedProgress() {
    final details = <String, String>{};

    for (final key in requiredProgress.keys) {
      final required = requiredProgress[key];
      final current = currentProgress[key] ?? 0;

      if (required is num) {
        final percentage = required > 0
            ? (current / required * 100).clamp(0, 100)
            : 0;
        details[key] =
            '$current / $required (${percentage.toStringAsFixed(0)}%)';
      } else if (required is bool) {
        details[key] = current == true ? 'Completed' : 'Pending';
      } else {
        details[key] = '$current / $required';
      }
    }

    return details;
  }

  /// Gets the next milestone or target
  Map<String, dynamic>? getNextMilestone() {
    for (final key in requiredProgress.keys) {
      final required = requiredProgress[key];
      final current = currentProgress[key] ?? 0;

      if (required is num && current < required) {
        final remaining = required - current;
        return {
          'criterion': key,
          'current': current,
          'required': required,
          'remaining': remaining,
          'progress_percent': (current / required * 100).clamp(0, 100),
        };
      }
    }

    return null;
  }

  /// Estimates time to completion based on recent progress
  Duration? estimateTimeToCompletion() {
    if (status == ProgressStatus.completed) return Duration.zero;

    final now = DateTime.now();
    final timeSinceStart = now.difference(startedAt);
    final currentProgressPercent = calculateProgress();

    if (currentProgressPercent <= 0 || timeSinceStart.inDays < 1) {
      return null; // Not enough data
    }

    final progressRate = currentProgressPercent / timeSinceStart.inDays;
    final remainingProgress = 100 - currentProgressPercent;

    if (progressRate <= 0) return null;

    final estimatedDays = (remainingProgress / progressRate).ceil();
    return Duration(days: estimatedDays);
  }

  /// Gets a formatted string for time remaining or completed time
  String getTimeDescription() {
    if (status == ProgressStatus.completed && completedAt != null) {
      final duration = completedAt!.difference(startedAt);
      return 'Completed in ${_formatDuration(duration)}';
    }

    if (isExpired()) {
      return 'Expired';
    }

    final estimate = estimateTimeToCompletion();
    if (estimate != null) {
      return 'Estimated ${_formatDuration(estimate)} remaining';
    }

    final timeSinceStart = DateTime.now().difference(startedAt);
    return 'In progress for ${_formatDuration(timeSinceStart)}';
  }

  /// Helper method to format duration
  String _formatDuration(Duration duration) {
    if (duration.inDays > 0) {
      return '${duration.inDays} day${duration.inDays == 1 ? '' : 's'}';
    } else if (duration.inHours > 0) {
      return '${duration.inHours} hour${duration.inHours == 1 ? '' : 's'}';
    } else {
      return '${duration.inMinutes} minute${duration.inMinutes == 1 ? '' : 's'}';
    }
  }

  /// Creates a copy with updated values
  UserProgress copyWith({
    String? id,
    String? userId,
    String? achievementId,
    Map<String, dynamic>? currentProgress,
    Map<String, dynamic>? requiredProgress,
    ProgressStatus? status,
    DateTime? completedAt,
    DateTime? expiresAt,
    DateTime? startedAt,
    DateTime? updatedAt,
    Achievement? achievement,
    Map<String, dynamic>? metadata,
    Map<String, dynamic>? stats,
    Map<String, dynamic>? streaks,
    double? totalPoints,
  }) {
    return UserProgress(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      achievementId: achievementId ?? this.achievementId,
      currentProgress: currentProgress ?? this.currentProgress,
      requiredProgress: requiredProgress ?? this.requiredProgress,
      status: status ?? this.status,
      completedAt: completedAt ?? this.completedAt,
      expiresAt: expiresAt ?? this.expiresAt,
      startedAt: startedAt ?? this.startedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      achievement: achievement ?? this.achievement,
      metadata: metadata ?? this.metadata,
      stats: stats ?? this.stats,
      streaks: streaks ?? this.streaks,
      totalPoints: totalPoints ?? this.totalPoints,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is UserProgress &&
        other.id == id &&
        other.userId == userId &&
        other.achievementId == achievementId &&
        other.status == status;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        userId.hashCode ^
        achievementId.hashCode ^
        status.hashCode;
  }

  @override
  String toString() {
    return 'UserProgress(id: $id, userId: $userId, achievementId: $achievementId, '
        'status: $status, progress: ${calculateProgress().toStringAsFixed(1)}%)';
  }
}
