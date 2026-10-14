import 'package:dabbler_design_system/dabbler_design_system.dart'
    show DabblerMotion;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart' show LocationAccuracy;

import 'package:dabbler/core/services/gps_service.dart';
import 'package:dabbler/data/models/feed/feed_post.dart';
import 'package:dabbler/data/repositories/feed_repository.dart';
import 'package:dabbler/data/repositories/feed_repository_impl.dart';
import 'package:dabbler/core/data/supabase_remote_data_source.dart';
import 'package:dabbler/features/location/providers/active_location_provider.dart';

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

/// Reads the app's active location point (e.g. the persisted manual point),
/// or null when none is ready. Must never ask for permission.
typedef ActivePointReader = ({double lat, double lng})? Function();

class NearbyFeedNotifier extends StateNotifier<NearbyFeedState> {
  NearbyFeedNotifier(
    this._repo, [
    GpsService? gps,
    ActivePointReader? activePoint,
  ]) : _gps = gps ?? GpsService(),
       _activePoint = activePoint,
       super(const NearbyFeedState());

  final FeedRepository _repo;
  final GpsService _gps;
  final ActivePointReader? _activePoint;

  /// Loads only if not previously loaded (cache-friendly across tab switches).
  Future<void> ensureLoaded() async {
    if (state.loaded) return;
    await load();
  }

  /// Reloads only when a previous load completed (used when the active
  /// location moves, e.g. a manual point is picked).
  Future<void> reloadIfLoaded() async {
    if (!mounted || !state.loaded) return;
    await load();
  }

  /// Force-load / refresh. Resolves device location, then calls the RPC.
  Future<void> load() async {
    if (!mounted) return;
    state = state.copyWith(isLoading: true, error: null);

    double? lat;
    double? lng;

    // 1. The active location (a manual point when permission is denied).
    try {
      final point = _activePoint?.call();
      if (point != null) {
        lat = point.lat;
        lng = point.lng;
      }
    } catch (_) {
      // No active location — fall through to the read-only GPS attempt.
    }

    // 2. Read-only GPS, only when no active location point is available.
    if (lat == null || lng == null) {
      try {
        // Read-only: the OS permission prompt is never raised from here (only
        // the location intro or an explicit user action asks for it).
        final result = await _gps.getCurrentLocation(
          requestPermission: false,
          cap: DabblerMotion.timeoutShort,
          accuracy: LocationAccuracy.low,
        );
        if (result is LocationSuccess) {
          lat = result.lat;
          lng = result.lng;
        }
      } catch (_) {
        // Location unavailable — use fallback.
      }
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
      ({double lat, double lng})? readPoint() {
        final loc = ref.read(activeLocationProvider).valueOrNull;
        if (loc is ActiveLocationReady) {
          return (lat: loc.location.lat, lng: loc.location.lng);
        }
        return null;
      }

      final notifier = NearbyFeedNotifier(
        repo,
        ref.watch(gpsServiceProvider),
        readPoint,
      );
      // Reload once when the active point actually moves (e.g. the user picks
      // a manual point). load() never writes the active location: no loop.
      ref.listen<AsyncValue<ActiveLocationState>>(activeLocationProvider, (
        prev,
        next,
      ) {
        final a = prev?.valueOrNull;
        final b = next.valueOrNull;
        if (b is! ActiveLocationReady) return;
        if (a is ActiveLocationReady &&
            a.location.lat == b.location.lat &&
            a.location.lng == b.location.lng) {
          return;
        }
        notifier.reloadIfLoaded();
      });
      return notifier;
    });
