import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:dabbler/core/cache/cache_providers.dart';
import 'package:dabbler/core/cache/offline_cache.dart';
import 'package:dabbler/core/errors/request_timeout.dart';
import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/data/models/active_location.dart'
    show ActiveLocationSource;
import 'package:dabbler/data/models/social/post.dart';
import 'package:dabbler/features/location/providers/active_location_provider.dart';
import 'package:dabbler/features/location/providers/listing_city.dart';
import 'package:dabbler/core/data/supabase_remote_data_source.dart'
    show supabaseServiceProvider;
import 'package:dabbler/features/social/data/nearby_candidate_source.dart';
import 'package:dabbler/features/social/domain/nearby_feed_loader.dart';
import 'package:dabbler/features/social/domain/nearby_ranking.dart';
import 'package:dabbler/features/home/presentation/providers/home_feed_scopes.dart'
    show nearbyAreaProvider, NearbyArea;

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

typedef TabFeedFetcher =
    Future<Result<List<Post>, Failure>> Function({
      required int limit,
      required int offset,
    });

/// KAN-955: one page and its raw size — the number of rows or ranked ids the
/// page asked for, before unfetchable ones dropped out. `hasMore` is judged
/// on [rawCount], never on how many posts came back.
typedef TabFeedPage = ({List<Post> posts, int rawCount});

typedef TabPageFetcher =
    Future<Result<TabFeedPage, Failure>> Function({
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
    TabFeedFetcher fetcher, {
    bool autoLoad = true,
    OfflineCache? cache,
    String? accountId,
    String? cacheKey,
  }) : this.ranked(
         ({required limit, required offset}) async => (await fetcher(
           limit: limit,
           offset: offset,
         )).map((posts) => (posts: posts, rawCount: posts.length)),
         autoLoad: autoLoad,
         cache: cache,
         accountId: accountId,
         cacheKey: cacheKey,
       );

  /// KAN-955: for a feed whose pages can lose rows client-side (Nearby).
  TabFeedNotifier.ranked(
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

  final TabPageFetcher _fetcher;
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
  // KAN-955: first page fills to about a screenful, at most 4 extra pages.
  static const int _firstPageFill = 10;
  static const int _firstPageWalkCap = 4;
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
    final result = await _page(0);
    if (!mounted || generation != _generation) return false;

    if (result case Err(error: final err)) {
      final current = state;
      if (current is TabFeedData && current.posts.isNotEmpty) {
        state = current.copyWith(loadingMore: false);
      } else {
        state = TabFeedFailure(err.message);
      }
      return false;
    }
    final first = (result as Ok<TabFeedPage, Failure>).value;

    // KAN-955: a full raw page can lose rows (unfetchable ids) and leave a
    // list too short to scroll, so [loadMore] would never fire. Keep reading
    // pages until about a screenful is there, the feed ends, or the cap.
    final posts = [...first.posts];
    var page = 0;
    var hasMore = first.rawCount >= _pageSize;
    for (
      var walk = 0;
      walk < _firstPageWalkCap && hasMore && posts.length < _firstPageFill;
      walk++
    ) {
      final next = await _page(page + 1);
      if (!mounted || generation != _generation) return false;
      if (next is! Ok<TabFeedPage, Failure>) break; // the next scroll resumes
      page++;
      final seen = posts.map((p) => p.id).toSet();
      posts.addAll(next.value.posts.where((p) => !seen.contains(p.id)));
      hasMore = next.value.rawCount >= _pageSize;
    }

    _activePage = page;
    _networkLoaded = true;
    state = TabFeedData(posts: posts, hasMore: hasMore);
    if (_cacheOn) {
      _cache!.write(_accountId!, _cacheKey!, [
        for (final p in posts) p.toJson(),
      ], requestStartedAt: started);
    }
    return true;
  }

  Future<Result<TabFeedPage, Failure>> _page(int index) =>
      _fetcher(limit: _pageSize, offset: index * _pageSize).timeout(
        kRequestTimeout,
        onTimeout: () => Err<TabFeedPage, Failure>(const TimeoutFailure()),
      );

  /// Appends the next page. A raw page can merge down to nothing new while
  /// more exist (KAN-955); keep walking until something new arrives, the
  /// feed ends, or the cap is hit.
  Future<void> loadMore() async {
    final data = state;
    if (data is! TabFeedData || data.loadingMore || !data.hasMore || !mounted) {
      return;
    }

    final generation = _generation;
    state = data.copyWith(loadingMore: true, loadMoreFailed: false);

    for (var attempt = 0; attempt < 5; attempt++) {
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
      if (result is! Ok<TabFeedPage, Failure>) {
        state = current.copyWith(loadingMore: false, loadMoreFailed: true);
        return;
      }
      _activePage = nextPage;
      final rawHasMore = result.value.rawCount >= _pageSize;
      final existingIds = current.posts.map((p) => p.id).toSet();
      final deduped = result.value.posts
          .where((p) => !existingIds.contains(p.id))
          .toList();
      if (deduped.isEmpty && rawHasMore) continue;
      state = current.copyWith(
        posts: [...current.posts, ...deduped],
        loadingMore: false,
        hasMore: rawHasMore,
      );
      return;
    }

    // Cap reached: stop the spinner, keep hasMore so a later scroll resumes.
    final current = state;
    if (current is TabFeedData) state = current.copyWith(loadingMore: false);
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

/// The Nearby candidate set (KAN-594). Overridden in tests.
final nearbyCandidateFetchProvider = Provider<NearbyCandidateFetch>((ref) {
  final source = NearbyCandidateSource(
    ref.watch(supabaseServiceProvider).client,
  );
  return source.fetch;
});

/// Feed of nearby original, non-system posts (KAN-594): the selected City is
/// the boundary; with an Area or a usable location the order blends recency
/// and distance, City-only is newest first. See [NearbyFeedLoader].
/// NOT autoDispose — caches across tab switches.
final nearbyFeedProvider = StateNotifierProvider<TabFeedNotifier, TabFeedState>(
  (ref) {
    final repo = ref.watch(postRepositoryProvider);
    // Rebuild (and thus refetch on next view) when the app-level location
    // selection changes. select() on the scope avoids rebuilds for
    // loading-state churn.
    final point = ref.watch(
      activeLocationProvider.select((async) {
        final s = async.valueOrNull;
        return s is ActiveLocationReady
            ? (
                lat: s.location.lat,
                lng: s.location.lng,
                lastKnown: s.location.source == ActiveLocationSource.lastKnown,
                fixedAt: s.fixedAt,
              )
            : null;
      }),
    );
    // KAN-588: the selected City is the boundary; none means no query.
    // KAN-962: the tab's tags widen it to the country or anywhere.
    final listing = ref.watch(listingCityProvider);
    final city = listing?.name;
    final area = ref.watch(nearbyAreaProvider);
    final scope = city == null
        ? null
        : NearbyScope(
            city: city,
            lat: point?.lat,
            lng: point?.lng,
            lastKnown: point?.lastKnown ?? false,
            fixedAt: point?.fixedAt,
            area: area,
            countryCode: listing?.countryCode,
          );
    return _buildNearbyNotifier(
      NearbyFeedLoader(
        fetchCandidates: ref.watch(nearbyCandidateFetchProvider),
        postsByIds: repo.getPostsByIds,
      ),
      scope,
      cache: ref.watch(offlineCacheProvider),
      accountId: ref.watch(cacheAccountIdProvider),
    );
  },
);

/// The on-device cache key of the Nearby first page for [city] (KAN-588),
/// and, past the City, for its [area] (KAN-962).
@visibleForTesting
String nearbyCacheKey(String? city, [NearbyArea area = NearbyArea.city]) {
  final base = city == null || city.trim().isEmpty
      ? 'feed.nearby'
      : 'feed.nearby.${city.trim()}';
  return area == NearbyArea.city ? base : '$base.${area.name}';
}

TabFeedNotifier _buildNearbyNotifier(
  NearbyFeedLoader loader,
  NearbyScope? appScope, {
  OfflineCache? cache,
  String? accountId,
}) {
  return TabFeedNotifier.ranked(
    ({required limit, required offset}) async {
      // The selected City is the boundary. With none (no app location, GPS
      // only, or denied) there is no query: the home header opens the manual
      // 'Set location' drawer, and the OS permission is never asked here.
      final scope = appScope ?? const NearbyScope();

      return loader.loadRankedPage(scope: scope, limit: limit, offset: offset);
      // With app-level coordinates the initial fetch can't trigger a GPS
      // permission prompt, so load eagerly — this also covers notifier
      // recreation after a location change while the Nearby tab is visible.
    },
    autoLoad: appScope != null,
    cache: cache,
    accountId: accountId,
    // Per city (KAN-588), so a change of city never shows the previous city's
    // cached posts while the new city loads.
    cacheKey: nearbyCacheKey(appScope?.city, appScope?.area ?? NearbyArea.city),
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
