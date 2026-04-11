import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import 'package:dabbler/data/models/feed/feed_post.dart';
import 'package:dabbler/data/repositories/feed_repository.dart';
import 'package:dabbler/data/repositories/feed_repository_impl.dart';
import 'package:dabbler/features/misc/data/datasources/supabase_remote_data_source.dart';

// ---------------------------------------------------------------------------
// Repository DI
// ---------------------------------------------------------------------------

final feedRepositoryProvider = Provider<FeedRepository>((ref) {
  final svc = ref.watch(supabaseServiceProvider);
  return FeedRepositoryImpl(svc);
});

// ==========================================================================
// Nearby feed state
// ==========================================================================

class NearbyFeedState {
  const NearbyFeedState({
    this.posts = const [],
    this.isLoading = false,
    this.error,
    this.loaded = false,
  });

  final List<FeedPost> posts;
  final bool isLoading;
  final String? error;

  /// True once a successful first load has completed.
  final bool loaded;

  NearbyFeedState copyWith({
    List<FeedPost>? posts,
    bool? isLoading,
    Object? error = _sentinel,
    bool? loaded,
  }) {
    return NearbyFeedState(
      posts: posts ?? this.posts,
      isLoading: isLoading ?? this.isLoading,
      error: error == _sentinel ? this.error : error as String?,
      loaded: loaded ?? this.loaded,
    );
  }

  static const Object _sentinel = Object();
}

// ==========================================================================
// Nearby feed notifier
// ==========================================================================

class NearbyFeedNotifier extends StateNotifier<NearbyFeedState> {
  NearbyFeedNotifier(this._repo) : super(const NearbyFeedState());

  final FeedRepository _repo;

  /// Loads only if not previously loaded (cache-friendly across tab switches).
  Future<void> ensureLoaded() async {
    if (state.loaded) return;
    await load();
  }

  /// Force-load / refresh. Resolves device location, then calls the RPC.
  Future<void> load() async {
    if (!mounted) return;
    state = state.copyWith(isLoading: true, error: null);

    double? lat;
    double? lng;

    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
        timeLimit: const Duration(seconds: 5),
      );
      lat = pos.latitude;
      lng = pos.longitude;
    } catch (_) {
      // Location unavailable — use fallback.
    }

    final result = await _repo.getNearbyFeed(
      lat: lat ?? 25.09,
      lng: lng ?? 55.15,
    );

    if (!mounted) return;

    result.fold(
      (err) => state = state.copyWith(isLoading: false, error: err.message),
      (posts) =>
          state = state.copyWith(posts: posts, isLoading: false, loaded: true),
    );
  }
}

// ==========================================================================
// Provider
// ==========================================================================

/// NOT autoDispose — caches across tab switches within the home screen.
final nearbyRpcFeedProvider =
    StateNotifierProvider<NearbyFeedNotifier, NearbyFeedState>((ref) {
      final repo = ref.watch(feedRepositoryProvider);
      return NearbyFeedNotifier(repo);
    });
