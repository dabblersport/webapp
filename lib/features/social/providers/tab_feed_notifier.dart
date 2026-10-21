import 'package:dabbler_design_system/dabbler_design_system.dart'
    show DabblerMotion;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:dabbler/core/cache/cache_providers.dart';
import 'package:dabbler/core/cache/offline_cache.dart';
import 'package:dabbler/core/errors/request_timeout.dart';
import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/services/gps_service.dart';
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

  /// KAN-606: the last next-page load failed; the list ends in a retry row.
  bool get loadMoreFailed => false;
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
    this.loadMoreFailed = false,
  });

  @override
  final List<Post> posts;
  @override
  final bool hasMore;

  final bool loadingMore;
  @override
  bool get isLoadingMore => loadingMore;

  @override
  final bool loadMoreFailed;

  TabFeedData copyWith({
    List<Post>? posts,
    bool? hasMore,
    bool? loadingMore,
    bool? loadMoreFailed,
  }) {
    return TabFeedData(
      posts: posts ?? this.posts,
      hasMore: hasMore ?? this.hasMore,
      loadingMore: loadingMore ?? this.loadingMore,
      loadMoreFailed: loadMoreFailed ?? this.loadMoreFailed,
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
  /// [cache] / [accountId] / [cacheKey] (KAN-605): when all three are given
  /// the first page is read from the on-device cache at once, and every
  /// successful first-page load is written back.
  TabFeedNotifier(
    this._fetcher, {
    bool autoLoad = true,
    OfflineCache? cache,
    String? accountId,
    String? cacheKey,
  }) : _cache = cache,
       _accountId = accountId,
       _cacheKey = cacheKey,
       super(const TabFeedLoading()) {
    _hydrated = _hydrate();
    if (autoLoad) ensureLoaded();
  }

  final _FeedFetcher _fetcher;
  final OfflineCache? _cache;
  final String? _accountId;
  final String? _cacheKey;
  late final Future<void> _hydrated;

  /// The network has answered at least once for this notifier.
  bool _networkLoaded = false;

  bool get _cacheOn =>
      _cache != null && _accountId != null && _cacheKey != null;

  /// Shows the cached first page, if there is one and nothing newer is there.
  Future<void> _hydrate() async {
    if (!_cacheOn) return;
    final hit = await _cache!.read(_accountId!, _cacheKey!);
    if (hit == null || !mounted || state is TabFeedData) return;
    try {
      final posts = [
        for (final j in (hit.payload as List))
          Post.fromJson(Map<String, dynamic>.from(j as Map)),
      ];
      if (posts.isEmpty) return;
      state = TabFeedData(posts: posts, hasMore: posts.length >= _pageSize);
    } catch (_) {
      // A cached shape that no longer parses is the same as no cache.
    }
  }

  static const int _pageSize = 20;
  int _activePage = 0;

  /// Bumped by every [load]; a next page that lands after a reload started
  /// belongs to the old list and is dropped.
  int _generation = 0;

  /// Loads the first page only if not yet loaded (cache-friendly).
  Future<void> ensureLoaded() async {
    await _hydrated;
    if (_networkLoaded) return;
    if (state is TabFeedData && !_cacheOn) return;
    await load();
  }

  /// Force-reload from first page. KAN-606: a reload over a feed that has
  /// posts keeps them on screen while it runs and when it fails; only a feed
  /// with nothing to show goes through [TabFeedLoading] and [TabFeedFailure].
  /// Returns whether the load succeeded.
  Future<bool> load() async {
    if (!mounted) return false;
    final generation = ++_generation;
    if (state.posts.isEmpty) state = const TabFeedLoading();

    final started = DateTime.now();
    final result = await _fetcher(limit: _pageSize, offset: 0).timeout(
      kRequestTimeout,
      onTimeout: () => Err<List<Post>, Failure>(const TimeoutFailure()),
    );
    if (!mounted || generation != _generation) return false;

    return result.fold(
      (err) {
        final current = state;
        if (current is TabFeedData && current.posts.isNotEmpty) {
          state = current.copyWith(loadingMore: false);
        } else {
          state = TabFeedFailure(err.message);
        }
        return false;
      },
      (posts) {
        _activePage = 0;
        _networkLoaded = true;
        state = TabFeedData(posts: posts, hasMore: posts.length >= _pageSize);
        if (_cacheOn) {
          _cache!.write(_accountId!, _cacheKey!, [
            for (final p in posts) p.toJson(),
          ], requestStartedAt: started);
        }
        return true;
      },
    );
  }

  /// Appends the next page.
  Future<void> loadMore() async {
    final data = state;
    if (data is! TabFeedData || data.loadingMore || !data.hasMore || !mounted) {
      return;
    }

    final generation = _generation;
    state = data.copyWith(loadingMore: true, loadMoreFailed: false);
    final nextPage = _activePage + 1;

    final result = await _fetcher(
      limit: _pageSize,
      offset: nextPage * _pageSize,
    );
    if (!mounted || generation != _generation) return;

    final current = state;
    if (current is! TabFeedData) return;

    // KAN-606: a failed next page keeps the posts and ends the list in a
    // retry row; [loadMore] is the retry.
    result.fold(
      (_) => state = current.copyWith(loadingMore: false, loadMoreFailed: true),
      (newPosts) {
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
      },
    );
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
      final account = ref.watch(cacheAccountIdProvider);
      return TabFeedNotifier(
        ({required limit, required offset}) =>
            repo.getFollowingFeed(limit: limit, offset: offset),
        autoLoad: false, // lazy: only load when user opens the tab
        cache: ref.watch(offlineCacheProvider),
        accountId: account,
        cacheKey: 'feed.following',
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
    return _buildNearbyNotifier(
      repo,
      coords,
      ref.watch(gpsServiceProvider),
      cache: ref.watch(offlineCacheProvider),
      accountId: ref.watch(cacheAccountIdProvider),
    );
  },
);

TabFeedNotifier _buildNearbyNotifier(
  PostRepository repo,
  ({double lat, double lng})? appLocation,
  GpsService gps, {
  OfflineCache? cache,
  String? accountId,
}) {
  return TabFeedNotifier(
    ({required limit, required offset}) async {
      // Prefer the app-level location selection (GPS / saved / manual area).
      double? lat = appLocation?.lat;
      double? lng = appLocation?.lng;

      // Fallback: raw GPS, read-only (it never raises the OS permission prompt:
      // only the location intro or an explicit user action asks for it).
      if (lat == null || lng == null) {
        try {
          final result = await gps.getCurrentLocation(
            requestPermission: false,
            cap: DabblerMotion.timeoutShort,
            accuracy: LocationAccuracy.low,
          );
          if (result is LocationSuccess) {
            lat = result.lat;
            lng = result.lng;
          }
        } catch (_) {
          // Location unavailable — backend will fall back to recency.
        }
      }

      return repo.getNearbyFeed(
        lat: lat,
        lng: lng,
        limit: limit,
        offset: offset,
      );
      // With app-level coordinates the initial fetch can't trigger a GPS
      // permission prompt, so load eagerly — this also covers notifier
      // recreation after a location change while the Nearby tab is visible.
    },
    autoLoad: appLocation != null,
    cache: cache,
    accountId: accountId,
    cacheKey: 'feed.nearby',
  );
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
    cache: ref.watch(offlineCacheProvider),
    accountId: ref.watch(cacheAccountIdProvider),
    cacheKey: 'feed.news',
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
