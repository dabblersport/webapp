import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dabbler/data/models/rewards/achievement.dart';
import 'package:dabbler/data/models/rewards/badge_tier.dart';
import 'package:dabbler/data/models/rewards/user_progress.dart';
import '../../domain/repositories/rewards_repository.dart';

/// State for achievements management
class AchievementsState {
  final List<Achievement> achievements;
  final List<UserProgress> userProgress;
  final Map<String, Achievement> achievementsMap;
  final AchievementCategory? selectedCategory;
  final AchievementFilter filter;
  final AchievementSort sortBy;
  final String searchQuery;
  final bool isLoading;
  final String? error;
  final DateTime? lastUpdated;

  const AchievementsState({
    this.achievements = const [],
    this.userProgress = const [],
    this.achievementsMap = const {},
    this.selectedCategory,
    this.filter = AchievementFilter.all,
    this.sortBy = AchievementSort.name,
    this.searchQuery = '',
    this.isLoading = false,
    this.error,
    this.lastUpdated,
  });

  AchievementsState copyWith({
    List<Achievement>? achievements,
    List<UserProgress>? userProgress,
    Map<String, Achievement>? achievementsMap,
    AchievementCategory? selectedCategory,
    AchievementFilter? filter,
    AchievementSort? sortBy,
    String? searchQuery,
    bool? isLoading,
    String? error,
    DateTime? lastUpdated,
  }) {
    return AchievementsState(
      achievements: achievements ?? this.achievements,
      userProgress: userProgress ?? this.userProgress,
      achievementsMap: achievementsMap ?? this.achievementsMap,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      filter: filter ?? this.filter,
      sortBy: sortBy ?? this.sortBy,
      searchQuery: searchQuery ?? this.searchQuery,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  /// Get filtered and sorted achievements
  List<AchievementWithProgress> get filteredAchievements {
    var filtered = achievements.where((achievement) {
      // Search filter
      if (searchQuery.isNotEmpty) {
        final query = searchQuery.toLowerCase();
        if (!achievement.name.toLowerCase().contains(query) &&
            !achievement.description.toLowerCase().contains(query)) {
          return false;
        }
      }

      // Category filter
      if (selectedCategory != null &&
          achievement.category != selectedCategory) {
        return false;
      }

      // Status filter
      final progress = userProgress.firstWhere(
        (p) => p.achievementId == achievement.id,
        orElse: () => _createEmptyProgress(achievement.id),
      );

      switch (filter) {
        case AchievementFilter.completed:
          return progress.status == ProgressStatus.completed;
        case AchievementFilter.inProgress:
          return progress.status == ProgressStatus.inProgress;
        case AchievementFilter.notStarted:
          return progress.status == ProgressStatus.notStarted;
        case AchievementFilter.available:
          return achievement.isAvailable() &&
              progress.status != ProgressStatus.completed;
        case AchievementFilter.locked:
          return !achievement.isAvailable() ||
              !achievement.meetsPrerequisites(_getCompletedAchievementIds());
        case AchievementFilter.all:
          return true;
      }
    }).toList();

    // Sort achievements
    switch (sortBy) {
      case AchievementSort.name:
        filtered.sort((a, b) => a.name.compareTo(b.name));
        break;
      case AchievementSort.points:
        filtered.sort((a, b) => b.points.compareTo(a.points));
        break;
      case AchievementSort.progress:
        filtered.sort((a, b) {
          final progressA = _getProgressForAchievement(a.id);
          final progressB = _getProgressForAchievement(b.id);
          return progressB.calculateProgress().compareTo(
            progressA.calculateProgress(),
          );
        });
        break;
      case AchievementSort.tier:
        filtered.sort((a, b) => a.tier.index.compareTo(b.tier.index));
        break;
      case AchievementSort.category:
        filtered.sort((a, b) => a.category.index.compareTo(b.category.index));
        break;
      case AchievementSort.dateCreated:
        filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
    }

    // Convert to AchievementWithProgress
    return filtered.map((achievement) {
      final progress = _getProgressForAchievement(achievement.id);
      return AchievementWithProgress(
        achievement: achievement,
        progress: progress,
        isUnlocked:
            achievement.isAvailable() &&
            achievement.meetsPrerequisites(_getCompletedAchievementIds()),
      );
    }).toList();
  }

  /// Get achievement statistics
  AchievementStats get stats {
    final totalAchievements = achievements.length;
    final completedCount = userProgress
        .where((p) => p.status == ProgressStatus.completed)
        .length;
    final inProgressCount = userProgress
        .where((p) => p.status == ProgressStatus.inProgress)
        .length;

    final totalPoints = achievements.fold(0, (sum, a) => sum + a.points);
    final earnedPoints = userProgress
        .where((p) => p.status == ProgressStatus.completed)
        .map((p) => achievementsMap[p.achievementId]?.points ?? 0)
        .fold(0, (sum, points) => sum + points);

    return AchievementStats(
      totalAchievements: totalAchievements,
      completedAchievements: completedCount,
      inProgressAchievements: inProgressCount,
      availableAchievements:
          totalAchievements - completedCount - inProgressCount,
      completionRate: totalAchievements > 0
          ? (completedCount / totalAchievements) * 100
          : 0,
      totalPoints: totalPoints,
      earnedPoints: earnedPoints,
      pointsProgress: totalPoints > 0 ? (earnedPoints / totalPoints) * 100 : 0,
    );
  }

  UserProgress _getProgressForAchievement(String achievementId) {
    return userProgress.firstWhere(
      (p) => p.achievementId == achievementId,
      orElse: () => _createEmptyProgress(achievementId),
    );
  }

  UserProgress _createEmptyProgress(String achievementId) {
    return UserProgress(
      id: '',
      userId: '',
      achievementId: achievementId,
      currentProgress: {},
      requiredProgress: {},
      status: ProgressStatus.notStarted,
      startedAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  List<String> _getCompletedAchievementIds() {
    return userProgress
        .where((p) => p.status == ProgressStatus.completed)
        .map((p) => p.achievementId)
        .toList();
  }
}

/// Controller for achievements management
class AchievementsController extends StateNotifier<AchievementsState> {
  final RewardsRepository _repository;
  final String userId;

  AchievementsController({
    required RewardsRepository repository,
    required this.userId,
  }) : _repository = repository,
       super(const AchievementsState());

  /// Initialize achievements data
  Future<void> initialize() async {
    if (state.isLoading) return;

    state = state.copyWith(isLoading: true, error: null);

    try {
      await _loadAchievements();
      await _loadUserProgress();

      state = state.copyWith(isLoading: false, lastUpdated: DateTime.now());
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Refresh achievements data
  Future<void> refresh() async {
    await initialize();
  }

  /// Load all achievements
  Future<void> _loadAchievements() async {
    final result = await _repository.getAchievements();

    result.fold(
      (failure) =>
          throw Exception('Failed to load achievements: ${failure.message}'),
      (achievements) {
        final achievementsMap = <String, Achievement>{};
        for (final achievement in achievements) {
          achievementsMap[achievement.id] = achievement;
        }

        state = state.copyWith(
          achievements: achievements,
          achievementsMap: achievementsMap,
        );
      },
    );
  }

  /// Load user progress for achievements
  Future<void> _loadUserProgress() async {
    final result = await _repository.getUserProgress(userId);

    result.fold(
      (failure) =>
          throw Exception('Failed to load user progress: ${failure.message}'),
      (progress) {
        state = state.copyWith(userProgress: progress);
      },
    );
  }

  /// Set category filter
  void setCategory(AchievementCategory? category) {
    state = state.copyWith(selectedCategory: category);
  }

  /// Set status filter
  void setFilter(AchievementFilter filter) {
    state = state.copyWith(filter: filter);
  }

  /// Set sort order
  void setSortBy(AchievementSort sortBy) {
    state = state.copyWith(sortBy: sortBy);
  }

  /// Update search query
  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  /// Clear all filters
  void clearFilters() {
    state = state.copyWith(
      selectedCategory: null,
      filter: AchievementFilter.all,
      sortBy: AchievementSort.name,
      searchQuery: '',
    );
  }

  /// Get achievement by ID
  Achievement? getAchievementById(String id) {
    return state.achievementsMap[id];
  }

  /// Get progress for specific achievement
  UserProgress? getProgressForAchievement(String achievementId) {
    try {
      return state.userProgress.firstWhere(
        (p) => p.achievementId == achievementId,
      );
    } catch (e) {
      return null;
    }
  }

  /// Check if achievement is unlocked
  bool isAchievementUnlocked(String achievementId) {
    final achievement = getAchievementById(achievementId);
    if (achievement == null) return false;

    final completedIds = state.userProgress
        .where((p) => p.status == ProgressStatus.completed)
        .map((p) => p.achievementId)
        .toList();

    return achievement.isAvailable() &&
        achievement.meetsPrerequisites(completedIds);
  }

  /// Get achievements by category
  List<AchievementWithProgress> getAchievementsByCategory(
    AchievementCategory category,
  ) {
    return state.filteredAchievements
        .where((ap) => ap.achievement.category == category)
        .toList();
  }

  /// Get trending achievements (most progress recently)
  List<AchievementWithProgress> getTrendingAchievements({int limit = 5}) {
    final recentlyUpdated =
        state.filteredAchievements
            .where((ap) => ap.progress.status == ProgressStatus.inProgress)
            .toList()
          ..sort(
            (a, b) => b.progress.updatedAt.compareTo(a.progress.updatedAt),
          );

    return recentlyUpdated.take(limit).toList();
  }

  /// Get recommended achievements
  List<AchievementWithProgress> getRecommendedAchievements({int limit = 3}) {
    final available =
        state.filteredAchievements
            .where(
              (ap) =>
                  ap.isUnlocked &&
                  ap.progress.status != ProgressStatus.completed &&
                  ap.achievement.tier == BadgeTier.bronze,
            ) // Start with easier achievements
            .toList()
          ..sort(
            (a, b) => a.achievement.points.compareTo(b.achievement.points),
          );

    return available.take(limit).toList();
  }

  /// Search achievements
  Future<List<Achievement>> searchAchievements(String query) async {
    if (query.trim().isEmpty) {
      return state.achievements;
    }

    final result = await _repository.searchAchievements(query);

    return result.fold(
      (failure) => <Achievement>[],
      (achievements) => achievements,
    );
  }

  /// Clear error state
  void clearError() {
    state = state.copyWith(error: null);
  }
}

/// Achievement combined with progress information
class AchievementWithProgress {
  final Achievement achievement;
  final UserProgress progress;
  final bool isUnlocked;

  const AchievementWithProgress({
    required this.achievement,
    required this.progress,
    required this.isUnlocked,
  });

  /// Get progress percentage
  double get progressPercentage => progress.calculateProgress();

  /// Check if completed
  bool get isCompleted => progress.status == ProgressStatus.completed;

  /// Check if in progress
  bool get isInProgress => progress.status == ProgressStatus.inProgress;

  /// Check if not started
  bool get isNotStarted => progress.status == ProgressStatus.notStarted;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AchievementWithProgress &&
        other.achievement.id == achievement.id &&
        other.progress.id == progress.id;
  }

  @override
  int get hashCode => achievement.id.hashCode ^ progress.id.hashCode;
}

/// Achievement statistics
class AchievementStats {
  final int totalAchievements;
  final int completedAchievements;
  final int inProgressAchievements;
  final int availableAchievements;
  final double completionRate;
  final int totalPoints;
  final int earnedPoints;
  final double pointsProgress;

  const AchievementStats({
    required this.totalAchievements,
    required this.completedAchievements,
    required this.inProgressAchievements,
    required this.availableAchievements,
    required this.completionRate,
    required this.totalPoints,
    required this.earnedPoints,
    required this.pointsProgress,
  });
}

/// Achievement filter options
enum AchievementFilter {
  all,
  completed,
  inProgress,
  notStarted,
  available,
  locked,
}

/// Achievement sort options
enum AchievementSort { name, points, progress, tier, category, dateCreated }
