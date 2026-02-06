import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dabbler/data/models/rewards/user_progress.dart';
import '../../domain/repositories/rewards_repository.dart';

/// Progress milestone types
enum MilestoneType {
  quarterway, // 25%
  halfway, // 50%
  threeQuarter, // 75%
  nearCompletion, // 90%
  completed, // 100%
}

/// Progress tracking period for analytics
enum ProgressPeriod { daily, weekly, monthly, allTime }

/// Progress milestone information
class ProgressMilestone {
  final String achievementId;
  final String achievementName;
  final MilestoneType type;
  final double percentage;
  final DateTime reachedAt;
  final Map<String, dynamic> metadata;

  const ProgressMilestone({
    required this.achievementId,
    required this.achievementName,
    required this.type,
    required this.percentage,
    required this.reachedAt,
    this.metadata = const {},
  });

  String get displayMessage {
    switch (type) {
      case MilestoneType.quarterway:
        return 'You\'re 25% complete with "$achievementName"';
      case MilestoneType.halfway:
        return 'You\'re halfway through "$achievementName"!';
      case MilestoneType.threeQuarter:
        return 'You\'re 75% done with "$achievementName"!';
      case MilestoneType.nearCompletion:
        return 'Almost there! "$achievementName" is 90% complete!';
      case MilestoneType.completed:
        return '🎉 Achievement completed: "$achievementName"!';
    }
  }
}

/// State class for progress tracking management
class ProgressTrackingState {
  final List<UserProgress> allProgress;
  final List<UserProgress> activeProgress;
  final List<UserProgress> completedProgress;
  final List<ProgressMilestone> recentMilestones;
  final Map<String, List<UserProgress>> progressByCategory;
  final ProgressPeriod selectedPeriod;
  final String? categoryFilter;
  final String searchQuery;
  final bool isLoading;
  final String? error;
  final Map<String, dynamic> analytics;
  final DateTime? lastUpdated;
  final Map<String, double> progressStreaks;

  const ProgressTrackingState({
    this.allProgress = const [],
    this.activeProgress = const [],
    this.completedProgress = const [],
    this.recentMilestones = const [],
    this.progressByCategory = const {},
    this.selectedPeriod = ProgressPeriod.weekly,
    this.categoryFilter,
    this.searchQuery = '',
    this.isLoading = false,
    this.error,
    this.analytics = const {},
    this.lastUpdated,
    this.progressStreaks = const {},
  });

  ProgressTrackingState copyWith({
    List<UserProgress>? allProgress,
    List<UserProgress>? activeProgress,
    List<UserProgress>? completedProgress,
    List<ProgressMilestone>? recentMilestones,
    Map<String, List<UserProgress>>? progressByCategory,
    ProgressPeriod? selectedPeriod,
    String? categoryFilter,
    String? searchQuery,
    bool? isLoading,
    String? error,
    Map<String, dynamic>? analytics,
    DateTime? lastUpdated,
    Map<String, double>? progressStreaks,
  }) {
    return ProgressTrackingState(
      allProgress: allProgress ?? this.allProgress,
      activeProgress: activeProgress ?? this.activeProgress,
      completedProgress: completedProgress ?? this.completedProgress,
      recentMilestones: recentMilestones ?? this.recentMilestones,
      progressByCategory: progressByCategory ?? this.progressByCategory,
      selectedPeriod: selectedPeriod ?? this.selectedPeriod,
      categoryFilter: categoryFilter ?? this.categoryFilter,
      searchQuery: searchQuery ?? this.searchQuery,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      analytics: analytics ?? this.analytics,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      progressStreaks: progressStreaks ?? this.progressStreaks,
    );
  }

  /// Get filtered progress based on search and category
  List<UserProgress> get filteredProgress {
    var filtered = allProgress.where((progress) {
      // Category filter
      if (categoryFilter != null && categoryFilter!.isNotEmpty) {
        // This would need achievement data to filter by category
        // For now, we'll skip category filtering
      }

      // Search filter - would need achievement names for this
      if (searchQuery.isNotEmpty) {
        // For now, we'll filter by achievement ID containing search query
        if (!progress.achievementId.toLowerCase().contains(
          searchQuery.toLowerCase(),
        )) {
          return false;
        }
      }

      return true;
    }).toList();

    return filtered;
  }

  /// Get progress that's close to completion (>= 80%)
  List<UserProgress> get nearCompletionProgress {
    return activeProgress
        .where((progress) => progress.calculateProgress() >= 80.0)
        .toList();
  }

  /// Get recently started progress (< 25%)
  List<UserProgress> get recentlyStartedProgress {
    return activeProgress
        .where((progress) => progress.calculateProgress() < 25.0)
        .take(10)
        .toList();
  }

  /// Get progress analytics for the selected period
  Map<String, dynamic> get progressAnalytics {
    final totalActive = activeProgress.length;
    final totalCompleted = completedProgress.length;
    final averageProgress = totalActive > 0
        ? activeProgress
                  .map((p) => p.calculateProgress())
                  .reduce((a, b) => a + b) /
              totalActive
        : 0.0;

    final completionRate = (totalActive + totalCompleted) > 0
        ? (totalCompleted / (totalActive + totalCompleted)) * 100
        : 0.0;

    return {
      'total_active': totalActive,
      'total_completed': totalCompleted,
      'average_progress': averageProgress.round(),
      'completion_rate': completionRate.round(),
      'near_completion': nearCompletionProgress.length,
      'recently_started': recentlyStartedProgress.length,
      'milestones_reached': recentMilestones.length,
      'most_active_category': _getMostActiveCategory(),
      'progress_velocity': _calculateProgressVelocity(),
    };
  }

  String _getMostActiveCategory() {
    if (progressByCategory.isEmpty) return 'None';

    String mostActiveCategory = '';
    int maxProgress = 0;

    progressByCategory.forEach((category, progressList) {
      if (progressList.length > maxProgress) {
        maxProgress = progressList.length;
        mostActiveCategory = category;
      }
    });

    return mostActiveCategory.isNotEmpty ? mostActiveCategory : 'None';
  }

  double _calculateProgressVelocity() {
    // Calculate progress made per day based on recent milestones
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));

    final recentMilestoneCount = recentMilestones
        .where((milestone) => milestone.reachedAt.isAfter(weekAgo))
        .length;

    return recentMilestoneCount / 7.0; // Milestones per day
  }
}

/// Progress tracking controller for managing real-time progress
class ProgressTrackingController extends StateNotifier<ProgressTrackingState> {
  final RewardsRepository _repository;
  final String userId;

  ProgressTrackingController(this._repository, this.userId)
    : super(const ProgressTrackingState()) {
    _initialize();
  }

  Future<void> _initialize() async {
    await loadAllProgress();
  }

  /// Loads all user progress
  Future<void> loadAllProgress() async {
    state = state.copyWith(isLoading: true, error: null);

    final result = await _repository.getUserProgress(userId);

    result.fold(
      (failure) =>
          state = state.copyWith(error: failure.toString(), isLoading: false),
      (progressList) {
        final active = <UserProgress>[];
        final completed = <UserProgress>[];
        final byCategory = <String, List<UserProgress>>{};

        for (final progress in progressList) {
          // Categorize progress
          if (progress.status == ProgressStatus.completed) {
            completed.add(progress);
          } else {
            active.add(progress);
          }

          // Group by category (would need achievement data for proper categorization)
          // For now, we'll use a simple categorization
          final category = _getCategoryFromProgress(progress);
          byCategory.putIfAbsent(category, () => []).add(progress);
        }

        // Calculate streaks
        final streaks = _calculateProgressStreaks(progressList);

        // Generate recent milestones
        final milestones = _generateRecentMilestones(progressList);

        // Generate analytics
        final analytics = _generateAnalytics(progressList);

        state = state.copyWith(
          allProgress: progressList,
          activeProgress: active,
          completedProgress: completed,
          progressByCategory: byCategory,
          recentMilestones: milestones,
          analytics: analytics,
          progressStreaks: streaks,
          isLoading: false,
          lastUpdated: DateTime.now(),
        );
      },
    );
  }

  /// Loads progress for specific achievements
  Future<void> loadProgressForAchievements(List<String> achievementIds) async {
    final result = await _repository.getUserProgress(
      userId,
      achievementIds: achievementIds,
    );

    result.fold(
      (failure) => state = state.copyWith(error: failure.toString()),
      (progressList) {
        // Update existing progress with new data
        final updatedProgress = List<UserProgress>.from(state.allProgress);

        for (final newProgress in progressList) {
          final existingIndex = updatedProgress.indexWhere(
            (p) => p.achievementId == newProgress.achievementId,
          );

          if (existingIndex != -1) {
            updatedProgress[existingIndex] = newProgress;
          } else {
            updatedProgress.add(newProgress);
          }
        }

        // Recompute categorization
        _updateStateWithNewProgress(updatedProgress);
      },
    );
  }

  /// Tracks a specific event that may update progress
  Future<void> trackEvent(
    EventType eventType,
    Map<String, dynamic> eventData,
  ) async {
    final result = await _repository.trackEvent(eventType, eventData, userId);

    result.fold(
      (failure) => state = state.copyWith(error: failure.toString()),
      (updatedAchievements) {
        // Reload progress for updated achievements
        final achievementIds = updatedAchievements.map((a) => a.id).toList();
        if (achievementIds.isNotEmpty) {
          loadProgressForAchievements(achievementIds);
        }
      },
    );
  }

  /// Updates search query
  void updateSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  /// Updates category filter
  void updateCategoryFilter(String? category) {
    state = state.copyWith(categoryFilter: category);
  }

  /// Updates selected period for analytics
  void updatePeriod(ProgressPeriod period) {
    state = state.copyWith(selectedPeriod: period);
  }

  /// Gets progress for a specific achievement
  UserProgress? getProgressForAchievement(String achievementId) {
    try {
      return state.allProgress.firstWhere(
        (progress) => progress.achievementId == achievementId,
      );
    } catch (e) {
      return null;
    }
  }

  /// Gets achievements that are likely to be completed soon
  List<UserProgress> getPriorityAchievements() {
    return state.activeProgress
        .where((progress) => progress.calculateProgress() >= 60.0)
        .toList()
      ..sort((a, b) => b.calculateProgress().compareTo(a.calculateProgress()));
  }

  /// Gets progress insights and recommendations
  Map<String, dynamic> getProgressInsights() {
    final insights = <String>[];
    final recommendations = <String>[];

    // Analyze near completion achievements
    final nearCompletion = state.nearCompletionProgress;
    if (nearCompletion.isNotEmpty) {
      insights.add(
        'You have ${nearCompletion.length} achievements almost complete!',
      );
      recommendations.add(
        'Focus on completing your near-finished achievements first',
      );
    }

    // Analyze recently started
    final recentlyStarted = state.recentlyStartedProgress;
    if (recentlyStarted.length > 5) {
      insights.add(
        'You\'ve started ${recentlyStarted.length} new achievements recently',
      );
      recommendations.add('Consider focusing on fewer achievements at a time');
    }

    // Analyze completion rate
    final analytics = state.progressAnalytics;
    final completionRate = analytics['completion_rate'] as int;
    if (completionRate < 30) {
      insights.add('Your completion rate is $completionRate%');
      recommendations.add('Try setting smaller, achievable goals');
    } else if (completionRate > 70) {
      insights.add('Great job! You have a $completionRate% completion rate');
      recommendations.add('You\'re doing great! Keep up the momentum');
    }

    // Analyze streaks
    final longestStreak = _getLongestProgressStreak();
    if (longestStreak > 0) {
      insights.add('Your longest progress streak is $longestStreak days');
      if (longestStreak < 7) {
        recommendations.add('Try to build a consistent daily progress habit');
      }
    }

    return {
      'insights': insights,
      'recommendations': recommendations,
      'focus_areas': _getFocusAreas(),
      'motivation_message': _getMotivationMessage(),
    };
  }

  /// Refreshes all progress data
  Future<void> refresh() async {
    await loadAllProgress();
  }

  /// Private helper methods

  String _getCategoryFromProgress(UserProgress progress) {
    // This would typically use achievement data to determine category
    // For now, we'll use a simple heuristic based on achievement ID
    final id = progress.achievementId.toLowerCase();

    if (id.contains('game') || id.contains('match') || id.contains('play')) {
      return 'Games';
    } else if (id.contains('social') ||
        id.contains('friend') ||
        id.contains('chat')) {
      return 'Social';
    } else if (id.contains('skill') ||
        id.contains('level') ||
        id.contains('rank')) {
      return 'Skills';
    } else if (id.contains('daily') ||
        id.contains('weekly') ||
        id.contains('login')) {
      return 'Daily';
    } else {
      return 'General';
    }
  }

  Map<String, double> _calculateProgressStreaks(
    List<UserProgress> progressList,
  ) {
    final streaks = <String, double>{};

    // This would calculate actual streaks based on historical data
    // For now, we'll return empty streaks
    return streaks;
  }

  List<ProgressMilestone> _generateRecentMilestones(
    List<UserProgress> progressList,
  ) {
    final milestones = <ProgressMilestone>[];
    final now = DateTime.now();

    // Generate milestones based on current progress
    for (final progress in progressList) {
      final percentage = progress.calculateProgress();

      if (percentage >= 100.0 && progress.status == ProgressStatus.completed) {
        milestones.add(
          ProgressMilestone(
            achievementId: progress.achievementId,
            achievementName:
                'Achievement ${progress.achievementId}', // Would get from achievement
            type: MilestoneType.completed,
            percentage: 100.0,
            reachedAt: progress.completedAt ?? now,
          ),
        );
      } else if (percentage >= 90.0) {
        milestones.add(
          ProgressMilestone(
            achievementId: progress.achievementId,
            achievementName: 'Achievement ${progress.achievementId}',
            type: MilestoneType.nearCompletion,
            percentage: percentage,
            reachedAt: progress.updatedAt,
          ),
        );
      } else if (percentage >= 75.0) {
        milestones.add(
          ProgressMilestone(
            achievementId: progress.achievementId,
            achievementName: 'Achievement ${progress.achievementId}',
            type: MilestoneType.threeQuarter,
            percentage: percentage,
            reachedAt: progress.updatedAt,
          ),
        );
      }
    }

    // Sort by most recent first
    milestones.sort((a, b) => b.reachedAt.compareTo(a.reachedAt));

    return milestones.take(20).toList(); // Return last 20 milestones
  }

  Map<String, dynamic> _generateAnalytics(List<UserProgress> progressList) {
    // This would generate comprehensive analytics
    // For now, return basic analytics
    return {
      'total_progress_entries': progressList.length,
      'average_completion': progressList.isNotEmpty
          ? progressList
                    .map((p) => p.calculateProgress())
                    .reduce((a, b) => a + b) /
                progressList.length
          : 0.0,
    };
  }

  void _updateStateWithNewProgress(List<UserProgress> updatedProgress) {
    final active = <UserProgress>[];
    final completed = <UserProgress>[];
    final byCategory = <String, List<UserProgress>>{};

    for (final progress in updatedProgress) {
      if (progress.status == ProgressStatus.completed) {
        completed.add(progress);
      } else {
        active.add(progress);
      }

      final category = _getCategoryFromProgress(progress);
      byCategory.putIfAbsent(category, () => []).add(progress);
    }

    final milestones = _generateRecentMilestones(updatedProgress);
    final analytics = _generateAnalytics(updatedProgress);
    final streaks = _calculateProgressStreaks(updatedProgress);

    state = state.copyWith(
      allProgress: updatedProgress,
      activeProgress: active,
      completedProgress: completed,
      progressByCategory: byCategory,
      recentMilestones: milestones,
      analytics: analytics,
      progressStreaks: streaks,
      lastUpdated: DateTime.now(),
    );
  }

  double _getLongestProgressStreak() {
    if (state.progressStreaks.isEmpty) return 0.0;
    return state.progressStreaks.values.reduce((a, b) => a > b ? a : b);
  }

  List<String> _getFocusAreas() {
    final focusAreas = <String>[];

    // Analyze progress patterns to suggest focus areas
    if (state.nearCompletionProgress.isNotEmpty) {
      focusAreas.add('Complete nearly finished achievements');
    }

    if (state.recentlyStartedProgress.length >
        state.nearCompletionProgress.length) {
      focusAreas.add('Focus on fewer achievements at once');
    }

    final mostActiveCategory =
        state.progressAnalytics['most_active_category'] as String;
    if (mostActiveCategory != 'None') {
      focusAreas.add('Continue excelling in $mostActiveCategory');
    }

    return focusAreas;
  }

  String _getMotivationMessage() {
    final analytics = state.progressAnalytics;
    final totalActive = analytics['total_active'] as int;
    final completionRate = analytics['completion_rate'] as int;

    if (completionRate >= 80) {
      return '🏆 Amazing! You\'re a completion champion!';
    } else if (completionRate >= 60) {
      return '🌟 Great progress! You\'re on fire!';
    } else if (completionRate >= 40) {
      return '💪 Good work! Keep pushing forward!';
    } else if (totalActive > 0) {
      return '🚀 Every step counts! You\'re making progress!';
    } else {
      return '🎯 Ready to start your achievement journey?';
    }
  }

  /// Clears any error state
  void clearError() {
    state = state.copyWith(error: null);
  }
}
