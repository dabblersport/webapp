import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/activity_feed_datasource.dart';
import '../../data/models/activity_feed_event.dart';

/// State class for the activity feed.
class ActivityFeedState {
  final List<ActivityFeedEvent> activities;
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;
  final String currentPeriod; // 'all' | 'past' | 'upcoming' | 'present'
  final String?
  currentCategory; // 'all' | 'game' | 'booking' | 'social' | 'payment' | 'reward'
  final DateTime? lastCursor; // For pagination
  final bool hasMore; // Whether there are more items to load

  ActivityFeedState({
    this.activities = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
    this.currentPeriod = 'all',
    this.currentCategory,
    this.lastCursor,
    this.hasMore = true,
  });

  /// Get filtered activities based on current category
  List<ActivityFeedEvent> get filteredActivities {
    if (currentCategory == null || currentCategory == 'all') {
      return activities;
    }

    // Map UI category names to subject_type values
    final categoryMap = {
      'Games': 'game',
      'Booking': 'booking',
      'Community': 'social',
      'Payment': 'payment',
      'Rewards': 'reward',
    };

    final subjectType = categoryMap[currentCategory];
    if (subjectType == null) {
      return activities;
    }

    return activities
        .where((activity) => activity.subjectType == subjectType)
        .toList();
  }

  ActivityFeedState copyWith({
    List<ActivityFeedEvent>? activities,
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    String? currentPeriod,
    String? currentCategory,
    DateTime? lastCursor,
    bool? hasMore,
  }) {
    return ActivityFeedState(
      activities: activities ?? this.activities,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: error,
      currentPeriod: currentPeriod ?? this.currentPeriod,
      currentCategory: currentCategory ?? this.currentCategory,
      lastCursor: lastCursor ?? this.lastCursor,
      hasMore: hasMore ?? this.hasMore,
    );
  }
}

/// Controller for managing activity feed state and data fetching.
class ActivityFeedController extends StateNotifier<ActivityFeedState> {
  final ActivityFeedDatasource _datasource;
  static const int _pageSize = 50;

  ActivityFeedController(this._datasource) : super(ActivityFeedState());

  /// Loads the first page of activities for the given period.
  Future<void> loadActivities(String period) async {
    state = state.copyWith(
      isLoading: true,
      error: null,
      currentPeriod: period,
      activities: [],
      lastCursor: null,
      hasMore: true,
    );

    try {
      final activities = await _datasource.getActivityFeed(
        period: period,
        limit: _pageSize,
      );

      state = state.copyWith(
        isLoading: false,
        activities: activities,
        lastCursor: activities.isNotEmpty ? activities.last.happenedAt : null,
        hasMore: activities.length >= _pageSize,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Changes the period filter and reloads activities.
  Future<void> changePeriod(String newPeriod) async {
    if (newPeriod == state.currentPeriod) {
      return; // No change needed
    }

    await loadActivities(newPeriod);
  }

  /// Loads the next page of activities using cursor-based pagination.
  Future<void> loadMore() async {
    // Don't load if already loading, no cursor, or no more items
    if (state.isLoadingMore || state.lastCursor == null || !state.hasMore) {
      return;
    }

    state = state.copyWith(isLoadingMore: true, error: null);

    try {
      final activities = await _datasource.getActivityFeed(
        period: state.currentPeriod,
        limit: _pageSize,
        cursor: state.lastCursor,
      );

      // If we got fewer items than requested, we've reached the end
      final hasMore = activities.length >= _pageSize;

      state = state.copyWith(
        isLoadingMore: false,
        activities: [...state.activities, ...activities],
        lastCursor: activities.isNotEmpty
            ? activities.last.happenedAt
            : state.lastCursor,
        hasMore: hasMore,
      );
    } catch (e) {
      state = state.copyWith(isLoadingMore: false, error: e.toString());
    }
  }

  /// Changes the category filter (client-side filtering).
  void changeCategory(String? category) {
    state = state.copyWith(currentCategory: category);
  }

  /// Refreshes the current activity list.
  Future<void> refresh() async {
    await loadActivities(state.currentPeriod);
  }
}
