import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dabbler/data/models/feed/feed_item.dart';
import 'package:dabbler/features/misc/data/datasources/supabase_remote_data_source.dart';
import 'package:dabbler/features/news/data/news_repository.dart';
import 'package:dabbler/features/news/data/news_repository_impl.dart';

// ---------------------------------------------------------------------------
// Repository provider
// ---------------------------------------------------------------------------

final newsRepositoryProvider = Provider<NewsRepository>((ref) {
  final svc = ref.watch(supabaseServiceProvider);
  return NewsRepositoryImpl(svc);
});

// ---------------------------------------------------------------------------
// News tab feed state
// ---------------------------------------------------------------------------

class NewsTabState {
  const NewsTabState({
    this.items = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.loaded = false,
    this.error,
    this.selectedSportId,
    this.selectedRegion,
  });

  final List<FeedNewsItem> items;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final bool loaded;
  final String? error;
  final String? selectedSportId;
  final String? selectedRegion;

  List<FeedNewsItem> get filteredItems {
    final result = items.where((item) {
      final sportMatch =
          selectedSportId == null || item.sportId == selectedSportId;
      final regionMatch =
          selectedRegion == null || item.regions.contains(selectedRegion);
      return sportMatch && regionMatch;
    }).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return result;
  }

  NewsTabState copyWith({
    List<FeedNewsItem>? items,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    bool? loaded,
    Object? error = _sentinel,
    Object? selectedSportId = _sentinel,
    Object? selectedRegion = _sentinel,
  }) =>
      NewsTabState(
        items: items ?? this.items,
        isLoading: isLoading ?? this.isLoading,
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
        hasMore: hasMore ?? this.hasMore,
        loaded: loaded ?? this.loaded,
        error: error == _sentinel ? this.error : error as String?,
        selectedSportId: selectedSportId == _sentinel
            ? this.selectedSportId
            : selectedSportId as String?,
        selectedRegion: selectedRegion == _sentinel
            ? this.selectedRegion
            : selectedRegion as String?,
      );

  static const Object _sentinel = Object();
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

class NewsTabNotifier extends StateNotifier<NewsTabState> {
  NewsTabNotifier(this._repo) : super(const NewsTabState());

  final NewsRepository _repo;
  static const int _pageSize = 20;

  Future<void> ensureLoaded() async {
    if (state.loaded || state.isLoading) return;
    await load();
  }

  Future<void> load() async {
    state = state.copyWith(isLoading: true, error: null);
    final result = await _repo.fetchNewsTab(limit: _pageSize, offset: 0);
    result.fold(
      (err) => state = state.copyWith(isLoading: false, error: err.message),
      (items) => state = state.copyWith(
        isLoading: false,
        items: items,
        hasMore: items.length == _pageSize,
        loaded: true,
        error: null,
      ),
    );
  }

  void setFilterSport(String? sportId) {
    state = state.copyWith(selectedSportId: sportId);
  }

  void setFilterRegion(String? region) {
    state = state.copyWith(selectedRegion: region);
  }

  void clearFilters() {
    state = state.copyWith(
      selectedSportId: null,
      selectedRegion: null,
    );
  }

  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore) return;
    state = state.copyWith(isLoadingMore: true);
    final result = await _repo.fetchNewsTab(
      limit: _pageSize,
      offset: state.items.length,
    );
    result.fold(
      (err) => state = state.copyWith(isLoadingMore: false, error: err.message),
      (newItems) => state = state.copyWith(
        isLoadingMore: false,
        items: [...state.items, ...newItems],
        hasMore: newItems.length == _pageSize,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

/// Paginated news tab feed. Not autoDispose — caches across tab switches.
final newsTabFeedProvider =
    StateNotifierProvider<NewsTabNotifier, NewsTabState>((ref) {
  final repo = ref.watch(newsRepositoryProvider);
  return NewsTabNotifier(repo);
});
