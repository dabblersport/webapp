import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/data/models/social/post.dart';
import 'package:dabbler/data/repositories/post_repository.dart';
import 'package:dabbler/features/location/providers/active_location_provider.dart';
import 'post_providers.dart';

// =============================================================================
// GENERIC TAB FEED STATE
// =============================================================================

/// Generic tab feed state as a sealed union — illegal flag combinations are
/// unrepresentable. [TabFeedData] is the loaded steady state (its presence is
/// what `loaded` used to mean); [TabFeedLoading]/[TabFeedFailure] are the
/// no-data states. Base getters keep widget read sites unchanged.
sealed class TabFeedState {
  const TabFeedState();

  List<Post> get posts => const [];
  bool get isLoading => false;
  bool get isLoadingMore => false;
  bool get hasMore => false;
  String? get error => null;
}

final class TabFeedLoading extends TabFeedState {
  const TabFeedLoading();

  @override
  bool get isLoading => true;
  @override
  bool get hasMore => true;
}

final class TabFeedFailure extends TabFeedState {
  const TabFeedFailure(this.message);

  final String message;

  @override
  String? get error => message;
}

final class TabFeedData extends TabFeedState {
  const TabFeedData({
    required this.posts,
    this.hasMore = true,
    this.loadingMore = false,
  });

  @override
  final List<Post> posts;
  @override
  final bool hasMore;

  final bool loadingMore;
  @override
  bool get isLoadingMore => loadingMore;

  TabFeedData copyWith({
    List<Post>? posts,
    bool? hasMore,
    bool? loadingMore,
  }) {
    return TabFeedData(
      posts: posts ?? this.posts,
      hasMore: hasMore ?? this.hasMore,
      loadingMore: loadingMore ?? this.loadingMore,
    );
  }
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
    : super(const TabFeedLoading()) {
    if (autoLoad) ensureLoaded();
  }

  final _FeedFetcher _fetcher;
  static const int _pageSize = 20;
  int _activePage = 0;

  /// Loads the first page only if not yet loaded (cache-friendly).
  Future<void> ensureLoaded() async {
    if (state is TabFeedData) return;
    await load();
  }

  /// Force-reload from first page.
  Future<void> load() async {
    if (!mounted) return;
    state = const TabFeedLoading();
    _activePage = 0;

    final result = await _fetcher(limit: _pageSize, offset: 0);
    if (!mounted) return;

    result.fold(
      (err) => state = TabFeedFailure(err.message),
      (posts) => state = TabFeedData(
        posts: posts,
        hasMore: posts.length >= _pageSize,
      ),
    );
  }

  /// Appends the next page.
  Future<void> loadMore() async {
    final data = state;
    if (data is! TabFeedData || data.loadingMore || !data.hasMore || !mounted) {
      return;
    }

    state = data.copyWith(loadingMore: true);
    final nextPage = _activePage + 1;

    final result = await _fetcher(
      limit: _pageSize,
      offset: nextPage * _pageSize,
    );
    if (!mounted) return;

    final current = state;
    if (current is! TabFeedData) return;

    result.fold((_) => state = current.copyWith(loadingMore: false), (
      newPosts,
    ) {
      if (newPosts.isEmpty) {
        state = current.copyWith(hasMore: false, loadingMore: false);
        return;
      }
      _activePage = nextPage;
      final existingIds = current.posts.map((p) => p.id).toSet();
      final deduped = newPosts
          .where((p) => !existingIds.contains(p.id))
          .toList();
      state = current.copyWith(
        posts: [...current.posts, ...deduped],
        loadingMore: false,
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
    // Rebuild (and thus refetch on next view) when the app-level location
    // selection changes. select() on the coordinates avoids rebuilds for
    // loading-state churn.
    final coords = ref.watch(
      activeLocationProvider.select((async) {
        final s = async.valueOrNull;
        return s is ActiveLocationReady
            ? (lat: s.location.lat, lng: s.location.lng)
            : null;
      }),
    );
    return _buildNearbyNotifier(repo, coords);
  },
);

TabFeedNotifier _buildNearbyNotifier(
  PostRepository repo,
  ({double lat, double lng})? appLocation,
) {
  return TabFeedNotifier(({required limit, required offset}) async {
    // Prefer the app-level location selection (GPS / saved / manual area).
    double? lat = appLocation?.lat;
    double? lng = appLocation?.lng;

    // Fallback: raw GPS, resolved lazily inside the fetcher so permission
    // dialogs don't fire on app launch.
    if (lat == null || lng == null) {
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
    }

    return repo.getNearbyFeed(lat: lat, lng: lng, limit: limit, offset: offset);
    // With app-level coordinates the initial fetch can't trigger a GPS
    // permission prompt, so load eagerly — this also covers notifier
    // recreation after a location change while the Nearby tab is visible.
  }, autoLoad: appLocation != null);
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
