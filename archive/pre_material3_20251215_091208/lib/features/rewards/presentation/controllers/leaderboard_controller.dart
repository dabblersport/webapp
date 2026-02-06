import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dabbler/data/models/rewards/leaderboard_entry.dart';
import '../../domain/repositories/rewards_repository.dart';

/// Leaderboard sorting options
enum LeaderboardSort { rank, score, name, recent }

/// State class for leaderboard management
class LeaderboardState {
  final List<LeaderboardEntry> entries;
  final LeaderboardType selectedType;
  final TimeFrame selectedTimeframe;
  final String? sportFilter;
  final LeaderboardSort sortBy;
  final bool isAscending;
  final String searchQuery;
  final int currentPage;
  final int pageSize;
  final bool hasMorePages;
  final bool isLoading;
  final String? error;
  final Map<String, dynamic> stats;
  final int? userRank;
  final LeaderboardEntry? userEntry;
  final DateTime? lastUpdated;

  const LeaderboardState({
    this.entries = const [],
    this.selectedType = LeaderboardType.overall,
    this.selectedTimeframe = TimeFrame.allTime,
    this.sportFilter,
    this.sortBy = LeaderboardSort.rank,
    this.isAscending = true,
    this.searchQuery = '',
    this.currentPage = 1,
    this.pageSize = 50,
    this.hasMorePages = false,
    this.isLoading = false,
    this.error,
    this.stats = const {},
    this.userRank,
    this.userEntry,
    this.lastUpdated,
  });

  LeaderboardState copyWith({
    List<LeaderboardEntry>? entries,
    LeaderboardType? selectedType,
    TimeFrame? selectedTimeframe,
    String? sportFilter,
    LeaderboardSort? sortBy,
    bool? isAscending,
    String? searchQuery,
    int? currentPage,
    int? pageSize,
    bool? hasMorePages,
    bool? isLoading,
    String? error,
    Map<String, dynamic>? stats,
    int? userRank,
    LeaderboardEntry? userEntry,
    DateTime? lastUpdated,
  }) {
    return LeaderboardState(
      entries: entries ?? this.entries,
      selectedType: selectedType ?? this.selectedType,
      selectedTimeframe: selectedTimeframe ?? this.selectedTimeframe,
      sportFilter: sportFilter ?? this.sportFilter,
      sortBy: sortBy ?? this.sortBy,
      isAscending: isAscending ?? this.isAscending,
      searchQuery: searchQuery ?? this.searchQuery,
      currentPage: currentPage ?? this.currentPage,
      pageSize: pageSize ?? this.pageSize,
      hasMorePages: hasMorePages ?? this.hasMorePages,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      stats: stats ?? this.stats,
      userRank: userRank ?? this.userRank,
      userEntry: userEntry ?? this.userEntry,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  /// Get filtered and sorted entries
  List<LeaderboardEntry> get filteredEntries {
    var filtered = entries.where((entry) {
      // Search filter
      if (searchQuery.isNotEmpty) {
        if (!entry.username.toLowerCase().contains(searchQuery.toLowerCase())) {
          return false;
        }
      }

      return true;
    }).toList();

    // Sort entries
    filtered.sort((a, b) {
      int comparison = 0;

      switch (sortBy) {
        case LeaderboardSort.rank:
          comparison = a.currentRank.compareTo(b.currentRank);
          break;
        case LeaderboardSort.score:
          comparison = a.totalPoints.compareTo(b.totalPoints);
          break;
        case LeaderboardSort.name:
          comparison = a.username.compareTo(b.username);
          break;
        case LeaderboardSort.recent:
          comparison = a.lastActiveAt.compareTo(b.lastActiveAt);
          break;
      }

      return isAscending ? comparison : -comparison;
    });

    return filtered;
  }

  /// Get top performers (top 10)
  List<LeaderboardEntry> get topPerformers {
    return entries.take(10).toList();
  }

  /// Get user's position context (user rank ± 5 positions)
  List<LeaderboardEntry> get userContext {
    if (userRank == null || userRank! <= 0) return [];

    final startRank = (userRank! - 5).clamp(1, entries.length);
    final endRank = (userRank! + 5).clamp(1, entries.length);

    return entries
        .where(
          (entry) =>
              entry.currentRank >= startRank && entry.currentRank <= endRank,
        )
        .toList();
  }

  /// Get leaderboard statistics
  Map<String, dynamic> get leaderboardStats {
    if (entries.isEmpty) return {'total_entries': 0};

    final scores = entries.map((e) => e.totalPoints).toList();
    final totalScore = scores.fold<double>(0, (sum, score) => sum + score);
    final averageScore = totalScore / entries.length;
    final maxScore = scores.reduce((a, b) => a > b ? a : b);
    final minScore = scores.reduce((a, b) => a < b ? a : b);

    return {
      'total_entries': entries.length,
      'average_score': averageScore.round(),
      'highest_score': maxScore.round(),
      'lowest_score': minScore.round(),
      'user_percentile': _calculateUserPercentile(),
      'active_users_today': _getActiveUsersToday(),
      'score_distribution': _getScoreDistribution(),
    };
  }

  double _calculateUserPercentile() {
    if (userRank == null || entries.isEmpty) return 0.0;
    return ((entries.length - userRank! + 1) / entries.length) * 100;
  }

  int _getActiveUsersToday() {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);

    return entries
        .where((entry) => entry.lastActiveAt.isAfter(startOfDay))
        .length;
  }

  Map<String, int> _getScoreDistribution() {
    final distribution = <String, int>{
      '0-100': 0,
      '101-500': 0,
      '501-1000': 0,
      '1001-2500': 0,
      '2500+': 0,
    };

    for (final entry in entries) {
      final score = entry.totalPoints.round();
      if (score <= 100) {
        distribution['0-100'] = distribution['0-100']! + 1;
      } else if (score <= 500) {
        distribution['101-500'] = distribution['101-500']! + 1;
      } else if (score <= 1000) {
        distribution['501-1000'] = distribution['501-1000']! + 1;
      } else if (score <= 2500) {
        distribution['1001-2500'] = distribution['1001-2500']! + 1;
      } else {
        distribution['2500+'] = distribution['2500+']! + 1;
      }
    }

    return distribution;
  }
}

/// Leaderboard controller for managing leaderboard state
class LeaderboardController extends StateNotifier<LeaderboardState> {
  final RewardsRepository _repository;
  final String userId;

  LeaderboardController(this._repository, this.userId)
    : super(const LeaderboardState()) {
    _initialize();
  }

  Future<void> _initialize() async {
    await loadLeaderboard();
  }

  /// Loads leaderboard data
  Future<void> loadLeaderboard({bool append = false}) async {
    if (!append) {
      state = state.copyWith(isLoading: true, error: null);
    }

    final result = await _repository.getLeaderboard(
      state.selectedType,
      state.selectedTimeframe,
      page: append ? state.currentPage + 1 : 1,
      pageSize: state.pageSize,
      sportFilter: state.sportFilter,
    );

    await result.fold(
      (failure) async {
        state = state.copyWith(error: failure.toString(), isLoading: false);
      },
      (entries) async {
        // Load user rank separately
        final userRankResult = await _repository.getUserRank(
          userId,
          state.selectedType,
          state.selectedTimeframe,
          sportFilter: state.sportFilter,
        );

        final userRank = userRankResult.fold((failure) => null, (rank) => rank);

        // Load leaderboard stats
        final statsResult = await _repository.getLeaderboardStats(
          state.selectedType,
          state.selectedTimeframe,
        );

        final stats = statsResult.fold(
          (failure) => <String, dynamic>{},
          (statsData) => statsData,
        );

        // Find user entry in the loaded entries
        LeaderboardEntry? userEntry;
        try {
          userEntry = entries.firstWhere((entry) => entry.userId == userId);
        } catch (e) {
          userEntry = null;
        }

        final updatedEntries = append
            ? [...state.entries, ...entries]
            : entries;

        state = state.copyWith(
          entries: updatedEntries,
          currentPage: append ? state.currentPage + 1 : 1,
          hasMorePages: entries.length == state.pageSize,
          isLoading: false,
          userRank: userRank,
          userEntry: userEntry,
          stats: stats,
          lastUpdated: DateTime.now(),
        );
      },
    );
  }

  /// Changes leaderboard type and reloads data
  Future<void> changeLeaderboardType(LeaderboardType type) async {
    if (state.selectedType != type) {
      state = state.copyWith(selectedType: type, currentPage: 1, entries: []);
      await loadLeaderboard();
    }
  }

  /// Changes time frame and reloads data
  Future<void> changeTimeFrame(TimeFrame timeframe) async {
    if (state.selectedTimeframe != timeframe) {
      state = state.copyWith(
        selectedTimeframe: timeframe,
        currentPage: 1,
        entries: [],
      );
      await loadLeaderboard();
    }
  }

  /// Changes sport filter and reloads data
  Future<void> changeSportFilter(String? sportFilter) async {
    if (state.sportFilter != sportFilter) {
      state = state.copyWith(
        sportFilter: sportFilter,
        currentPage: 1,
        entries: [],
      );
      await loadLeaderboard();
    }
  }

  /// Updates search query
  void updateSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  /// Updates sort criteria
  void updateSort(LeaderboardSort sortBy, {bool? ascending}) {
    state = state.copyWith(
      sortBy: sortBy,
      isAscending: ascending ?? state.isAscending,
    );
  }

  /// Toggles sort direction
  void toggleSortDirection() {
    state = state.copyWith(isAscending: !state.isAscending);
  }

  /// Loads next page of entries
  Future<void> loadMoreEntries() async {
    if (!state.hasMorePages || state.isLoading) return;
    await loadLeaderboard(append: true);
  }

  /// Refreshes leaderboard data
  Future<void> refresh() async {
    state = state.copyWith(currentPage: 1, entries: []);
    await loadLeaderboard();
  }

  /// Gets entries around a specific rank
  Future<List<LeaderboardEntry>> getEntriesAroundRank(int rank) async {
    final targetPage = (rank / state.pageSize).ceil();

    final result = await _repository.getLeaderboard(
      state.selectedType,
      state.selectedTimeframe,
      page: targetPage,
      pageSize: state.pageSize,
      sportFilter: state.sportFilter,
    );

    return result.fold((failure) => [], (entries) => entries);
  }

  /// Gets user's historical performance
  Map<String, dynamic> getUserPerformanceHistory() {
    if (state.userEntry == null || state.userRank == null) {
      return {'current_rank': null, 'trend': 'unknown'};
    }

    // This would typically come from historical data
    // For now, we'll return current data
    return {
      'current_rank': state.userRank,
      'current_score': state.userEntry!.totalPoints.round(),
      'percentile': state.leaderboardStats['user_percentile'],
      'trend': 'stable', // Would calculate from historical data
      'best_rank': state.userRank, // Would track from historical data
      'total_score_gained': state.userEntry!.totalPoints.round(),
    };
  }

  /// Gets competitive insights for the user
  Map<String, dynamic> getCompetitiveInsights() {
    if (state.userRank == null || state.entries.isEmpty) {
      return {'insights': []};
    }

    final insights = <String>[];
    final userRank = state.userRank!;
    final totalUsers = state.entries.length;

    // Rank-based insights
    if (userRank <= 10) {
      insights.add('🏆 You\'re in the top 10!');
    } else if (userRank <= totalUsers * 0.1) {
      insights.add('⭐ You\'re in the top 10% of players');
    } else if (userRank <= totalUsers * 0.25) {
      insights.add('🌟 You\'re in the top 25% of players');
    }

    // Score-based insights
    if (state.userEntry != null) {
      final userScore = state.userEntry!.totalPoints.round();
      final averageScore = state.leaderboardStats['average_score'] as int;

      if (userScore > averageScore * 1.5) {
        insights.add('💪 Your score is 50% above average');
      } else if (userScore > averageScore) {
        insights.add('📈 You\'re above the average score');
      }
    }

    // Competition insights
    if (userRank > 1) {
      LeaderboardEntry? nextRankEntry;
      try {
        nextRankEntry = state.entries.firstWhere(
          (entry) => entry.currentRank == userRank - 1,
        );
      } catch (e) {
        nextRankEntry = null;
      }

      if (nextRankEntry != null && state.userEntry != null) {
        final pointsNeeded =
            nextRankEntry.totalPoints - state.userEntry!.totalPoints;
        if (pointsNeeded <= 50) {
          insights.add('🎯 Only ${pointsNeeded.round()} points to next rank!');
        }
      }
    }

    return {
      'insights': insights,
      'motivation_message': _getMotivationMessage(),
      'next_goal': _getNextGoal(),
    };
  }

  String _getMotivationMessage() {
    if (state.userRank == null) return 'Keep playing to see your rank!';

    final rank = state.userRank!;
    final total = state.entries.length;

    if (rank == 1) {
      return '🥇 Congratulations! You\'re #1!';
    } else if (rank <= 3) {
      return '🏅 Amazing! You\'re on the podium!';
    } else if (rank <= 10) {
      return '🔥 Great job! You\'re in the top 10!';
    } else if (rank <= total * 0.1) {
      return '⚡ Excellent! You\'re a top performer!';
    } else if (rank <= total * 0.25) {
      return '💫 Good work! You\'re in the top quarter!';
    } else if (rank <= total * 0.5) {
      return '📊 You\'re above average! Keep climbing!';
    } else {
      return '🚀 Every point counts! Keep pushing forward!';
    }
  }

  String _getNextGoal() {
    if (state.userRank == null || state.userRank == 1) {
      return 'Maintain your position!';
    }

    final nextMilestone = _getNextRankMilestone(state.userRank!);
    return 'Aim for rank $nextMilestone!';
  }

  int _getNextRankMilestone(int currentRank) {
    final milestones = [1, 5, 10, 25, 50, 100, 250, 500, 1000];

    for (final milestone in milestones) {
      if (milestone < currentRank) {
        return milestone;
      }
    }

    // If no milestone is found, aim for the next round number
    if (currentRank > 100) {
      return ((currentRank - 1) ~/ 100) * 100;
    } else if (currentRank > 50) {
      return 50;
    } else if (currentRank > 25) {
      return 25;
    } else if (currentRank > 10) {
      return 10;
    } else {
      return 1;
    }
  }

  /// Clears any error state
  void clearError() {
    state = state.copyWith(error: null);
  }
}
