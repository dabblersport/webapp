import 'package:dabbler/data/models/rewards/user_progress.dart';
import 'package:dabbler/data/models/rewards/achievement.dart';
import 'achievement_model.dart';

/// Data model for UserProgress with JSON serialization
class UserProgressModel extends UserProgress {
  const UserProgressModel({
    required super.id,
    required super.userId,
    required super.achievementId,
    required super.currentProgress,
    required super.requiredProgress,
    required super.status,
    super.completedAt,
    super.expiresAt,
    required super.startedAt,
    required super.updatedAt,
    super.achievement,
    super.metadata,
    super.stats,
    super.streaks,
    super.totalPoints,
  });

  /// Creates a UserProgressModel from JSON
  factory UserProgressModel.fromJson(Map<String, dynamic> json) {
    return UserProgressModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      achievementId: json['achievement_id'] as String,
      currentProgress: _parseProgressMap(json['current_progress']),
      requiredProgress: _parseProgressMap(json['required_progress']),
      status: _parseProgressStatus(json['status']),
      completedAt: _parseDateTime(json['completed_at']),
      expiresAt: _parseDateTime(json['expires_at']),
      startedAt: _parseDateTime(json['started_at'])!,
      updatedAt: _parseDateTime(json['updated_at'])!,
      achievement: json['achievement'] != null
          ? AchievementModel.fromJson(
              json['achievement'] as Map<String, dynamic>,
            )
          : null,
      metadata: _parseMetadata(json['metadata']),
      stats: json['stats'] != null
          ? Map<String, dynamic>.from(json['stats'] as Map<String, dynamic>)
          : const {},
      streaks: json['streaks'] != null
          ? Map<String, dynamic>.from(json['streaks'] as Map<String, dynamic>)
          : const {},
      totalPoints: (json['total_points'] as num?)?.toDouble() ?? 0.0,
    );
  }

  /// Converts the model to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'achievement_id': achievementId,
      'current_progress': currentProgress,
      'required_progress': requiredProgress,
      'status': status.name,
      'completed_at': completedAt?.toIso8601String(),
      'expires_at': expiresAt?.toIso8601String(),
      'started_at': startedAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'achievement': achievement != null
          ? (achievement as AchievementModel).toJson()
          : null,
      'metadata': metadata,
      'stats': stats,
      'streaks': streaks,
      'total_points': totalPoints,
    };
  }

  /// Creates a copy as UserProgressModel
  @override
  UserProgressModel copyWith({
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
    return UserProgressModel(
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
    );
  }

  // Static parsing methods

  static Map<String, dynamic> _parseProgressMap(dynamic value) {
    if (value == null) return {};

    if (value is Map<String, dynamic>) {
      return Map<String, dynamic>.from(value);
    }

    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    if (value is String) {
      try {
        // Try to parse JSON string from JSONB
        final Map<String, dynamic> parsed = Map<String, dynamic>.from(
          Map.from(value as dynamic),
        );
        return parsed;
      } catch (e) {
        return {};
      }
    }

    return {};
  }

  static ProgressStatus _parseProgressStatus(dynamic value) {
    if (value == null) return ProgressStatus.notStarted;

    if (value is String) {
      switch (value.toLowerCase()) {
        case 'not_started':
        case 'notstarted':
          return ProgressStatus.notStarted;
        case 'in_progress':
        case 'inprogress':
          return ProgressStatus.inProgress;
        case 'completed':
          return ProgressStatus.completed;
        case 'expired':
          return ProgressStatus.expired;
        default:
          return ProgressStatus.notStarted;
      }
    }

    return ProgressStatus.notStarted;
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;

    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (e) {
        return null;
      }
    }

    if (value is DateTime) return value;

    return null;
  }

  static Map<String, dynamic>? _parseMetadata(dynamic value) {
    if (value == null) return null;

    if (value is Map<String, dynamic>) {
      return Map<String, dynamic>.from(value);
    }

    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    return null;
  }

  /// Creates a UserProgressModel from Supabase row
  factory UserProgressModel.fromSupabase(Map<String, dynamic> data) {
    return UserProgressModel.fromJson({
      ...data,
      'user_id': data['user_id'] ?? data['userId'],
      'achievement_id': data['achievement_id'] ?? data['achievementId'],
      'current_progress': data['current_progress'] ?? data['currentProgress'],
      'required_progress':
          data['required_progress'] ?? data['requiredProgress'],
      'completed_at': data['completed_at'] ?? data['completedAt'],
      'expires_at': data['expires_at'] ?? data['expiresAt'],
      'started_at': data['started_at'] ?? data['startedAt'],
      'updated_at': data['updated_at'] ?? data['updatedAt'],
    });
  }

  /// Converts to format suitable for Supabase insertion
  Map<String, dynamic> toSupabase() {
    final json = toJson();

    // Remove null values and nested objects
    json.removeWhere((key, value) => value == null);
    json.remove('achievement'); // This would be handled by joins

    return {
      ...json,
      'user_id': json['user_id'],
      'achievement_id': json['achievement_id'],
      'current_progress': json['current_progress'],
      'required_progress': json['required_progress'],
      'completed_at': json['completed_at'],
      'expires_at': json['expires_at'],
      'started_at': json['started_at'],
      'updated_at': json['updated_at'],
    };
  }

  /// Creates a mock UserProgressModel for testing
  factory UserProgressModel.mock({
    String? id,
    String? userId,
    String? achievementId,
    Map<String, dynamic>? currentProgress,
    Map<String, dynamic>? requiredProgress,
    ProgressStatus status = ProgressStatus.inProgress,
  }) {
    final now = DateTime.now();
    return UserProgressModel(
      id: id ?? 'mock_progress',
      userId: userId ?? 'mock_user',
      achievementId: achievementId ?? 'mock_achievement',
      currentProgress: currentProgress ?? {'count': 5},
      requiredProgress: requiredProgress ?? {'count': 10},
      status: status,
      startedAt: now.subtract(const Duration(days: 1)),
      updatedAt: now,
    );
  }

  /// Updates progress incrementally
  UserProgressModel updateProgress({
    required Map<String, dynamic> progressDelta,
    Map<String, dynamic>? metadataUpdate,
  }) {
    final newProgress = Map<String, dynamic>.from(currentProgress);

    // Apply incremental updates
    for (final entry in progressDelta.entries) {
      final key = entry.key;
      final deltaValue = entry.value;

      if (deltaValue is num && newProgress[key] is num) {
        // Increment numerical values
        newProgress[key] = (newProgress[key] as num) + deltaValue;
      } else {
        // Replace non-numerical values
        newProgress[key] = deltaValue;
      }
    }

    // Update metadata if provided
    Map<String, dynamic>? newMetadata;
    if (metadataUpdate != null) {
      newMetadata = Map<String, dynamic>.from(metadata ?? {});
      newMetadata.addAll(metadataUpdate);
    }

    // Check if achievement is now complete
    final isNowComplete = _checkCompletion(newProgress, requiredProgress);
    final newStatus = isNowComplete ? ProgressStatus.completed : status;
    final completionTime = isNowComplete ? DateTime.now() : completedAt;

    return copyWith(
      currentProgress: newProgress,
      status: newStatus,
      completedAt: completionTime,
      updatedAt: DateTime.now(),
      metadata: newMetadata,
    );
  }

  /// Checks if progress meets completion criteria
  bool _checkCompletion(
    Map<String, dynamic> current,
    Map<String, dynamic> required,
  ) {
    for (final entry in required.entries) {
      final key = entry.key;
      final requiredValue = entry.value;
      final currentValue = current[key];

      if (requiredValue is num && currentValue is num) {
        if (currentValue < requiredValue) return false;
      } else if (requiredValue is bool && requiredValue == true) {
        if (currentValue != true) return false;
      } else if (requiredValue is String) {
        if (currentValue != requiredValue) return false;
      }
    }

    return true;
  }

  /// Gets progress summary for display
  Map<String, dynamic> getProgressSummary() {
    return {
      'id': id,
      'achievement_id': achievementId,
      'status': status.name,
      'progress_percentage': calculateProgress(),
      'is_complete': isComplete(),
      'is_expired': isExpired(),
      'description': getProgressDescription(),
      'detailed_progress': getDetailedProgress(),
      'next_milestone': getNextMilestone(),
      'time_description': getTimeDescription(),
      'completion_estimate': estimateTimeToCompletion()?.inDays,
    };
  }

  /// Creates progress from achievement requirements
  factory UserProgressModel.fromAchievement({
    required String id,
    required String userId,
    required Achievement achievement,
    Map<String, dynamic>? initialProgress,
    DateTime? expirationDate,
  }) {
    return UserProgressModel(
      id: id,
      userId: userId,
      achievementId: achievement.id,
      currentProgress:
          initialProgress ?? _getInitialProgress(achievement.criteria),
      requiredProgress: achievement.criteria,
      status: ProgressStatus.notStarted,
      expiresAt: expirationDate,
      startedAt: DateTime.now(),
      updatedAt: DateTime.now(),
      achievement: achievement,
    );
  }

  static Map<String, dynamic> _getInitialProgress(
    Map<String, dynamic> criteria,
  ) {
    final initial = <String, dynamic>{};

    for (final entry in criteria.entries) {
      final key = entry.key;
      final value = entry.value;

      if (value is num) {
        initial[key] = 0;
      } else if (value is bool) {
        initial[key] = false;
      } else if (value is String) {
        initial[key] = '';
      } else if (value is List) {
        initial[key] = <dynamic>[];
      } else {
        initial[key] = null;
      }
    }

    return initial;
  }

  /// Calculates progress velocity (progress per day)
  double getProgressVelocity() {
    final totalDays = DateTime.now().difference(startedAt).inDays;
    if (totalDays == 0) return 0.0;

    return calculateProgress() / totalDays;
  }

  /// Gets recent progress changes
  List<Map<String, dynamic>> getRecentChanges() {
    final changes = <Map<String, dynamic>>[];

    // This would typically be populated from historical data
    // For now, we'll return the current state
    for (final entry in currentProgress.entries) {
      changes.add({
        'criterion': entry.key,
        'current_value': entry.value,
        'required_value': requiredProgress[entry.key],
        'last_updated': updatedAt.toIso8601String(),
      });
    }

    return changes;
  }
}
