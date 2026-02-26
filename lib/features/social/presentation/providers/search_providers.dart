import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dabbler/core/utils/search_query_parser.dart';
import 'package:dabbler/data/models/search/search_result_bundle.dart';
import 'package:dabbler/data/repositories/search_repository.dart';
import 'package:dabbler/data/repositories/search_repository_impl.dart';
import 'package:dabbler/features/misc/data/datasources/supabase_remote_data_source.dart';

// ---------------------------------------------------------------------------
// Repository provider
// ---------------------------------------------------------------------------

final searchRepositoryProvider = Provider<SearchRepository>((ref) {
  final svc = ref.watch(supabaseServiceProvider);
  return SearchRepositoryImpl(svc);
});

// ---------------------------------------------------------------------------
// Search state
// ---------------------------------------------------------------------------

class SearchState {
  final String query;
  final SearchMode mode;
  final bool isLoading;
  final String? error;
  final SearchResultBundle bundle;

  /// Tab index to auto-switch to when mode is specific (not all).
  /// -1 means no forced switch.
  final int forcedTabIndex;

  const SearchState({
    this.query = '',
    this.mode = SearchMode.all,
    this.isLoading = false,
    this.error,
    this.bundle = SearchResultBundle.empty,
    this.forcedTabIndex = -1,
  });

  SearchState copyWith({
    String? query,
    SearchMode? mode,
    bool? isLoading,
    String? error,
    SearchResultBundle? bundle,
    int? forcedTabIndex,
  }) {
    return SearchState(
      query: query ?? this.query,
      mode: mode ?? this.mode,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      bundle: bundle ?? this.bundle,
      forcedTabIndex: forcedTabIndex ?? this.forcedTabIndex,
    );
  }

  bool get hasResults => bundle.hasResults;
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

class SearchNotifier extends StateNotifier<SearchState> {
  SearchNotifier(this._repo) : super(const SearchState());

  final SearchRepository _repo;

  /// Parses [rawQuery] using [SearchQueryParser], then fires the unified RPC.
  Future<void> search(String rawQuery) async {
    final parsed = SearchQueryParser.parse(rawQuery.trim());

    if (parsed.cleanQuery.isEmpty) {
      state = const SearchState();
      return;
    }

    // Map SearchMode to the tab index for auto-switching.
    final forcedTab = _tabIndexForMode(parsed.mode);

    state = state.copyWith(
      query: rawQuery.trim(),
      mode: parsed.mode,
      isLoading: true,
      error: null,
      bundle: SearchResultBundle.empty,
      forcedTabIndex: forcedTab,
    );

    final result = await _repo.unifiedSearch(
      query: parsed.cleanQuery,
      mode: parsed.mode,
    );

    result.fold(
      (failure) =>
          state = state.copyWith(isLoading: false, error: failure.message),
      (bundle) => state = state.copyWith(isLoading: false, bundle: bundle),
    );
  }

  void clear() => state = const SearchState();

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Maps a [SearchMode] to the index of the corresponding tab in
  /// [SocialSearchScreen]'s tab list.
  ///
  /// Tab order (must stay in sync with [SocialSearchScreen._searchTabs]):
  ///   0 → all
  ///   1 → people
  ///   2 → posts
  ///   3 → games
  ///   4 → venues
  ///   5 → comments
  ///   6 → hashtags
  ///   7 → meetups
  int _tabIndexForMode(SearchMode mode) {
    switch (mode) {
      case SearchMode.all:
        return -1;
      case SearchMode.profiles:
        return 1;
      case SearchMode.posts:
        return 2;
      case SearchMode.games:
        return 3;
      case SearchMode.venues:
        return 4;
      case SearchMode.comments:
        return 5;
      case SearchMode.hashtags:
        return 6;
      case SearchMode.meetups:
        return 7;
    }
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final searchProvider = StateNotifierProvider<SearchNotifier, SearchState>((
  ref,
) {
  final repo = ref.watch(searchRepositoryProvider);
  return SearchNotifier(repo);
});
