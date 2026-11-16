import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dabbler/core/config/supabase_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:dabbler/data/models/feed/feed_item.dart';
import 'package:dabbler/core/data/supabase_remote_data_source.dart';
import 'package:dabbler/features/home/presentation/providers/home_feed_scopes.dart'
    show newsSportIdsProvider;
import 'package:dabbler/features/news/data/news_repository.dart';
import 'package:dabbler/features/news/data/news_repository_impl.dart';
import 'package:dabbler/features/profile/presentation/providers/profile_providers.dart';

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
  });

  final List<FeedNewsItem> items;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final bool loaded;
  final String? error;

  /// The items newest first. KAN-962: the tab's tags filter on the server, so
  /// nothing is filtered here.
  List<FeedNewsItem> get filteredItems =>
      [...items]..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  NewsTabState copyWith({
    List<FeedNewsItem>? items,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    bool? loaded,
    Object? error = _sentinel,
  }) => NewsTabState(
    items: items ?? this.items,
    isLoading: isLoading ?? this.isLoading,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    hasMore: hasMore ?? this.hasMore,
    loaded: loaded ?? this.loaded,
    error: error == _sentinel ? this.error : error as String?,
  );

  static const Object _sentinel = Object();
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

class NewsTabNotifier extends StateNotifier<NewsTabState> {
  /// [sportIds] (KAN-962): the News tag, read on every page; null is "All
  /// news", a list is "Following" (empty: follows none, no call, no rows).
  NewsTabNotifier(this._repo, {List<String>? Function()? sportIds})
    : _sportIds = sportIds ?? (() => null),
      super(const NewsTabState());

  final NewsRepository _repo;
  final List<String>? Function() _sportIds;
  static const int _pageSize = 20;

  /// Bumped by every [load]; a page from an older generation is dropped.
  int _generation = 0;

  /// Whether the tab has loaded or is loading (a tag change then reloads it).
  bool get started => state.loaded || state.isLoading;

  Future<void> ensureLoaded() async {
    if (state.loaded || state.isLoading) return;
    await load();
  }

  Future<void> load() async {
    final generation = ++_generation;
    state = state.copyWith(isLoading: true, error: null);
    final sports = _sportIds();
    if (sports != null && sports.isEmpty) {
      state = state.copyWith(
        isLoading: false,
        items: const <FeedNewsItem>[],
        hasMore: false,
        loaded: true,
        error: null,
      );
      return;
    }
    final result = await _repo.fetchNewsTab(
      limit: _pageSize,
      offset: 0,
      sportIds: sports,
    );
    if (!mounted || generation != _generation) return;
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

  /// KAN-962: the tag changed. The rows on screen belong to the old tag, so
  /// the tab goes back to loading and reloads from the first page.
  Future<void> refilter() {
    if (!mounted) return Future<void>.value();
    state = const NewsTabState(isLoading: true);
    return load();
  }

  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore) return;
    final sports = _sportIds();
    if (sports != null && sports.isEmpty) return;
    final generation = _generation;
    state = state.copyWith(isLoadingMore: true);
    final result = await _repo.fetchNewsTab(
      limit: _pageSize,
      offset: state.items.length,
      sportIds: sports,
    );
    if (!mounted || generation != _generation) return;
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
/// KAN-962: reads the News tag ([newsSportIdsProvider]) on every page and,
/// once the tab has loaded, reloads when it changes.
final newsTabFeedProvider =
    StateNotifierProvider<NewsTabNotifier, NewsTabState>((ref) {
      final repo = ref.watch(newsRepositoryProvider);
      final notifier = NewsTabNotifier(
        repo,
        sportIds: () => ref.read(newsSportIdsProvider),
      );
      ref.listen<List<String>?>(newsSportIdsProvider, (prev, next) {
        final same = prev == null
            ? next == null
            : next != null && listEquals(prev, next);
        if (!same && notifier.started) notifier.refilter();
      });
      return notifier;
    });

// ---------------------------------------------------------------------------
// News preference — optimistic local override + async DB persist
// ---------------------------------------------------------------------------

/// Local override for the news preference of the active profile.
/// null = follow profiles.news from DB; true/false = user toggled this session.
final newsPreferenceOverrideProvider = StateProvider<bool?>((ref) => null);

/// Resolved news preference: local override takes priority over DB value.
final newsEnabledProvider = Provider<bool>((ref) {
  final override = ref.watch(newsPreferenceOverrideProvider);
  if (override != null) return override;
  return ref.watch(currentUserProfileProvider)?.news ?? true;
});

/// Sets news = false for the active profile (optimistic + async DB persist).
final updateNewsPreferenceProvider = Provider<Future<void> Function()>((ref) {
  return () async {
    ref.read(newsPreferenceOverrideProvider.notifier).state = false;
    final profileId = ref.read(currentUserProfileProvider)?.id;
    if (profileId == null || profileId.isEmpty) return;
    await Supabase.instance.client
        .from(SupabaseConfig.usersTable)
        .update({'news': false})
        .eq('id', profileId);
  };
});

/// Sets news = true for the active profile (optimistic + async DB persist).
final resubscribeNewsProvider = Provider<Future<void> Function()>((ref) {
  return () async {
    ref.read(newsPreferenceOverrideProvider.notifier).state = true;
    final profileId = ref.read(currentUserProfileProvider)?.id;
    if (profileId == null || profileId.isEmpty) return;
    await Supabase.instance.client
        .from(SupabaseConfig.usersTable)
        .update({'news': true})
        .eq('id', profileId);
  };
});
