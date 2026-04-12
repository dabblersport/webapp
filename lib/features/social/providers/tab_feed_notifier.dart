import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/data/models/social/post.dart';
import 'package:dabbler/data/repositories/post_repository.dart';
import 'post_providers.dart';

// =============================================================================
// GENERIC TAB FEED STATE
// =============================================================================

class TabFeedState {
  const TabFeedState({
    this.posts = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.error,
    this.loaded = false,
  });

  final List<Post> posts;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final String? error;

  /// True once a successful first load has completed (prevents re-fetch on
  /// tab switch).
  final bool loaded;

  TabFeedState copyWith({
    List<Post>? posts,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    Object? error = _sentinel,
    bool? loaded,
  }) {
    return TabFeedState(
      posts: posts ?? this.posts,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      error: error == _sentinel ? this.error : error as String?,
      loaded: loaded ?? this.loaded,
    );
  }

  static const Object _sentinel = Object();
}

// =============================================================================
// GENERIC TAB FEED NOTIFIER
// =============================================================================

typedef _FeedFetcher =
    Future<Result<List<Post>, Failure>> Function({
      required int limit,
      required int offset,
    });

/// A generic paginated feed notifier for tabs that return [Post] lists.
///
/// - Caches state across tab switches (does NOT refetch if [loaded] is true).
/// - Call [refresh()] to force reload.
/// - [loadMore()] appends the next page.
class TabFeedNotifier extends StateNotifier<TabFeedState> {
  TabFeedNotifier(this._fetcher, {bool autoLoad = true})
    : super(const TabFeedState()) {
    if (autoLoad) ensureLoaded();
  }

  final _FeedFetcher _fetcher;
  static const int _pageSize = 20;
  int _activePage = 0;

  /// Loads the first page only if not yet loaded (cache-friendly).
  Future<void> ensureLoaded() async {
    if (state.loaded) return;
    await load();
  }

  /// Force-reload from first page.
  Future<void> load() async {
    if (!mounted) return;
    state = state.copyWith(isLoading: true, error: null);
    _activePage = 0;

    final result = await _fetcher(limit: _pageSize, offset: 0);
    if (!mounted) return;

    result.fold(
      (err) => state = state.copyWith(isLoading: false, error: err.message),
      (posts) => state = state.copyWith(
        posts: posts,
        isLoading: false,
        hasMore: posts.length >= _pageSize,
        loaded: true,
      ),
    );
  }

  /// Appends the next page.
  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore || !mounted) return;

    state = state.copyWith(isLoadingMore: true);
    final nextPage = _activePage + 1;

    final result = await _fetcher(
      limit: _pageSize,
      offset: nextPage * _pageSize,
    );
    if (!mounted) return;

    result.fold((_) => state = state.copyWith(isLoadingMore: false), (
      newPosts,
    ) {
      if (newPosts.isEmpty) {
        state = state.copyWith(hasMore: false, isLoadingMore: false);
        return;
      }
      _activePage = nextPage;
      final existingIds = state.posts.map((p) => p.id).toSet();
      final deduped = newPosts
          .where((p) => !existingIds.contains(p.id))
          .toList();
      state = state.copyWith(
        posts: [...state.posts, ...deduped],
        isLoadingMore: false,
        hasMore: newPosts.length >= _pageSize && deduped.isNotEmpty,
      );
    });
  }
}

// =============================================================================
// FOLLOWING FEED PROVIDER
// =============================================================================

/// Feed of posts from users the caller follows.
/// NOT autoDispose — caches across tab switches.
final followingFeedProvider =
    StateNotifierProvider<TabFeedNotifier, TabFeedState>((ref) {
      final repo = ref.watch(postRepositoryProvider);
      return TabFeedNotifier(
        ({required limit, required offset}) =>
            repo.getFollowingFeed(limit: limit, offset: offset),
        autoLoad: false, // lazy: only load when user opens the tab
      );
    });

// =============================================================================
// NEARBY FEED PROVIDER
// =============================================================================

/// Feed of nearby original, non-system posts sorted by distance from the
/// user's current location. Falls back to recency when location is
/// unavailable.
/// NOT autoDispose — caches across tab switches.
final nearbyFeedProvider = StateNotifierProvider<TabFeedNotifier, TabFeedState>(
  (ref) {
    final repo = ref.watch(postRepositoryProvider);
    return _buildNearbyNotifier(repo);
  },
);

TabFeedNotifier _buildNearbyNotifier(PostRepository repo) {
  // Location is resolved lazily inside the fetcher so permission dialogs
  // don't fire on app launch.
  return TabFeedNotifier(({required limit, required offset}) async {
    double? lat;
    double? lng;

    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
        timeLimit: const Duration(seconds: 5),
      );
      lat = pos.latitude;
      lng = pos.longitude;
    } catch (_) {
      // Location unavailable — backend will fall back to recency.
    }

    return repo.getNearbyFeed(lat: lat, lng: lng, limit: limit, offset: offset);
  }, autoLoad: false);
}

// =============================================================================
// NEWS FEED PROVIDER
// =============================================================================

/// Editorial/system posts (post_type = 'allocated', origin_type = 'system').
/// NOT autoDispose — caches across tab switches.
final newsFeedProvider = StateNotifierProvider<TabFeedNotifier, TabFeedState>((
  ref,
) {
  final repo = ref.watch(postRepositoryProvider);
  return TabFeedNotifier(
    ({required limit, required offset}) =>
        repo.getNewsFeed(limit: limit, offset: offset),
    autoLoad: false,
  );
});

// =============================================================================
// LOCATION AVAILABILITY PROVIDER (used by UI to show a hint)
// =============================================================================

/// Resolves to `true` when location permission is granted.
final locationPermissionProvider = FutureProvider.autoDispose<bool>((
  ref,
) async {
  try {
    final perm = await Geolocator.checkPermission();
    return perm == LocationPermission.always ||
        perm == LocationPermission.whileInUse;
  } catch (_) {
    return false;
  }
});

// =============================================================================
// SUPABASE SERVICE PROVIDER (re-exported for convenience)
// =============================================================================

// Supabase.instance is accessed directly where needed.
// Expose for active feed (re-used)
SupabaseClient get supabaseClient => Supabase.instance.client;
