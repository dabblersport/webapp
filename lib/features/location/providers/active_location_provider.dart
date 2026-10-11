import 'package:dabbler_design_system/dabbler_design_system.dart'
    show DabblerMotion;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart' show LocationAccuracy;

import 'package:dabbler/core/services/gps_service.dart';
import 'package:dabbler/data/models/active_location.dart';
import 'package:dabbler/data/models/area.dart';
import 'package:dabbler/data/models/profile_location.dart';
import 'package:dabbler/data/repositories/area_repository_v2.dart';
import 'package:dabbler/features/location/providers/profile_location_providers.dart';

// =============================================================================
// STATE
// =============================================================================

sealed class ActiveLocationState {}

class ActiveLocationLoading extends ActiveLocationState {}

class ActiveLocationReady extends ActiveLocationState {
  ActiveLocationReady(this.location);
  final ActiveLocation location;
}

/// GPS denied and no saved location to fall back to.
class ActiveLocationDenied extends ActiveLocationState {}

class ActiveLocationError extends ActiveLocationState {
  ActiveLocationError(this.message);
  final String message;
}

// =============================================================================
// NOTIFIER
// =============================================================================

class ActiveLocationNotifier extends AsyncNotifier<ActiveLocationState> {
  /// Per-screen radius override. Set by screens that need a different radius;
  /// cleared in their dispose() via [clearRadiusOverride].
  int? _radiusOverride;

  GpsService get _gps => ref.read(gpsServiceProvider);
  AreaRepository get _areas => ref.read(areaRepositoryV2Provider);

  @override
  Future<ActiveLocationState> build() async {
    // Keep alive so nearby feeds don't re-initialise on navigation.
    ref.keepAlive();

    return _initialise();
  }

  // ── Initialisation ────────────────────────────────────────────────────────

  /// Degradation order (nothing here waits for GPS: first paint never does):
  /// 1. Saved primary location (instant, no GPS wait)
  /// 2. Silent GPS attempt in the background (upgrades the state if it wins)
  /// 3. No saved location: [ActiveLocationLoading] now, and the background
  ///    attempt settles it (a position, or denied / error).
  Future<ActiveLocationState> _initialise() async {
    // 1. Try saved primary location first.
    final savedState = await _trySavedPrimary();
    if (savedState != null) {
      // Kick off a background GPS attempt that may upgrade the state.
      _backgroundGpsRefresh(currentSaved: savedState.location);
      return savedState;
    }

    // 2. No saved primary: look in the background, never on the UI path.
    // Background start-up never asks the user for permission (the location
    // intro screen is where the system prompt is asked for).
    _backgroundGpsRefresh(settleWhenUnsaved: true);
    return ActiveLocationLoading();
  }

  Future<ActiveLocationReady?> _trySavedPrimary() async {
    try {
      final locations = await ref.read(profileLocationNotifierProvider.future);
      final primary =
          locations.where((l) => l.isPrimary).firstOrNull ??
          locations.firstOrNull;
      if (primary == null) return null;
      if (primary.lat == null || primary.lng == null) return null;

      final area = await _resolveArea(
        primary.lat!,
        primary.lng!,
        hintAreaId: primary.areaId,
      );
      if (area == null) return null;

      return ActiveLocationReady(
        ActiveLocation(
          lat: primary.lat!,
          lng: primary.lng!,
          area: area,
          nearbyRadiusMeters: primary.nearbyRadiusMeters,
          defaultRadiusMeters: primary.nearbyRadiusMeters,
          source: ActiveLocationSource.saved,
          savedLocationId: primary.id,
          savedLocationLabel: primary.effectiveLabel,
        ),
      );
    } catch (_) {
      return null;
    }
  }

  /// Silently attempt GPS without blocking the UI. If it succeeds and is
  /// closer/more accurate, upgrade to GPS source. With [settleWhenUnsaved]
  /// (no saved location) a miss settles the state to denied / error instead of
  /// leaving it loading.
  void _backgroundGpsRefresh({
    ActiveLocation? currentSaved,
    bool settleWhenUnsaved = false,
  }) {
    // On the event queue, after the build that started it has completed.
    Future<void>(() async {
      try {
        // Silent: only upgrades when permission was already granted.
        final result = await _gps.getCurrentLocation(
          requestPermission: false,
          cap: GpsService.fixCap,
        );
        if (result is! LocationSuccess) {
          if (settleWhenUnsaved && state.valueOrNull is ActiveLocationLoading) {
            state = AsyncData(await _stateFromGpsResult(result));
          }
          return;
        }

        final area = await _resolveArea(result.lat, result.lng);
        if (area == null) {
          if (settleWhenUnsaved && state.valueOrNull is ActiveLocationLoading) {
            state = AsyncData(
              ActiveLocationError('Could not resolve your area'),
            );
          }
          return;
        }

        // Only upgrade if more accurate or saved location is missing.
        final gpsLoc = ActiveLocation(
          lat: result.lat,
          lng: result.lng,
          area: area,
          nearbyRadiusMeters:
              _radiusOverride ?? currentSaved?.nearbyRadiusMeters ?? 10000,
          defaultRadiusMeters: currentSaved?.nearbyRadiusMeters ?? 10000,
          source: ActiveLocationSource.gps,
        );

        // Prefer GPS when accuracy ≤ 100 m or no saved location exists.
        if (currentSaved == null || result.accuracyMeters <= 100) {
          state = AsyncData(ActiveLocationReady(gpsLoc));
        }
      } catch (_) {
        // Best effort: a lookup must never surface an error.
      }
    });
  }

  /// After the user allowed location on the introduction (and only then):
  /// reads the device location in the BACKGROUND, never on a UI path and never
  /// asking for permission. The last known position goes first (fast), then a
  /// fresh fix capped at [GpsService.fixCap]; each one that works updates the
  /// active location. A miss changes nothing: the chip stays "Set location" and
  /// manual selection stays available.
  Future<void> adoptDeviceLocation() async {
    try {
      // Let the initial build settle so its result cannot overwrite ours.
      try {
        await future.timeout(DabblerMotion.timeoutNetwork);
      } catch (_) {}

      final last = await _gps.getLastKnownLocation();
      if (last != null) await _applyDeviceFix(last);

      final fresh = await _gps.getCurrentLocation(
        requestPermission: false,
        cap: GpsService.fixCap,
        accuracy: LocationAccuracy.medium,
      );
      if (fresh is LocationSuccess) await _applyDeviceFix(fresh);
    } catch (_) {
      // Decoration of the experience only: nothing visible on failure.
    }
  }

  Future<void> _applyDeviceFix(LocationSuccess fix) async {
    final area = await _resolveArea(fix.lat, fix.lng);
    if (area == null) return;
    final current = state.valueOrNull;
    final defaultRadius = current is ActiveLocationReady
        ? current.location.defaultRadiusMeters
        : 10000;
    state = AsyncData(
      ActiveLocationReady(
        ActiveLocation(
          lat: fix.lat,
          lng: fix.lng,
          area: area,
          nearbyRadiusMeters: _radiusOverride ?? 10000,
          defaultRadiusMeters: defaultRadius,
          source: ActiveLocationSource.gps,
        ),
      ),
    );
  }

  Future<ActiveLocationState> _stateFromGpsResult(LocationResult result) async {
    switch (result) {
      case LocationSuccess(:final lat, :final lng):
        final area = await _resolveArea(lat, lng);
        if (area == null) {
          return ActiveLocationError('Could not resolve your area');
        }
        return ActiveLocationReady(
          ActiveLocation(
            lat: lat,
            lng: lng,
            area: area,
            nearbyRadiusMeters: _radiusOverride ?? 10000,
            defaultRadiusMeters: 10000,
            source: ActiveLocationSource.gps,
          ),
        );
      case LocationDenied():
      case LocationDeniedForever():
        return ActiveLocationDenied();
      case LocationServiceOff():
        return ActiveLocationDenied();
      case LocationTimeout():
        return ActiveLocationError('Location timed out — try again');
      case LocationError(:final message):
        return ActiveLocationError(message);
    }
  }

  // ── Public API ────────────────────────────────────────────────────────────

  /// Switch to live GPS.
  Future<void> useGpsLocation() async {
    state = AsyncData(ActiveLocationLoading());
    final result = await _gps.getCurrentLocation(cap: GpsService.fixCap);
    state = AsyncData(await _stateFromGpsResult(result));
  }

  /// Switch to a specific saved profile location.
  Future<void> useSavedLocation(ProfileLocation location) async {
    if (location.lat == null || location.lng == null) return;
    state = AsyncData(ActiveLocationLoading());

    final area = await _resolveArea(
      location.lat!,
      location.lng!,
      hintAreaId: location.areaId,
    );
    if (area == null) {
      state = AsyncData(ActiveLocationError('Could not resolve area'));
      return;
    }

    state = AsyncData(
      ActiveLocationReady(
        ActiveLocation(
          lat: location.lat!,
          lng: location.lng!,
          area: area,
          nearbyRadiusMeters: _radiusOverride ?? location.nearbyRadiusMeters,
          defaultRadiusMeters: location.nearbyRadiusMeters,
          source: ActiveLocationSource.saved,
          savedLocationId: location.id,
          savedLocationLabel: location.effectiveLabel,
        ),
      ),
    );
  }

  /// Switch to a manually selected area (user picked from the area list).
  Future<void> useManualArea(Area area) async {
    state = AsyncData(
      ActiveLocationReady(
        ActiveLocation(
          lat: area.centerLat,
          lng: area.centerLng,
          area: area,
          nearbyRadiusMeters: _radiusOverride ?? 10000,
          source: ActiveLocationSource.manual,
        ),
      ),
    );
  }

  /// Re-fetch GPS position and update state.
  Future<void> refresh() async {
    final current = state.valueOrNull;
    state = AsyncData(ActiveLocationLoading());
    final result = await _gps.getCurrentLocation(cap: GpsService.fixCap);
    final next = await _stateFromGpsResult(result);
    // If refresh fails, restore previous state rather than showing error.
    state = AsyncData(
      next is ActiveLocationError && current != null ? current : next,
    );
  }

  /// Called by individual screens that need a temporary radius.
  void setRadiusOverride(int meters) {
    _radiusOverride = meters;
    _applyRadiusToCurrentState(meters);
  }

  /// Must be called in screen dispose() to reset the override.
  void clearRadiusOverride() {
    _radiusOverride = null;
    final current = state.valueOrNull;
    if (current is ActiveLocationReady) {
      state = AsyncData(
        ActiveLocationReady(
          current.location.copyWith(
            nearbyRadiusMeters: current.location.defaultRadiusMeters,
          ),
        ),
      );
    }
  }

  void _applyRadiusToCurrentState(int meters) {
    final current = state.valueOrNull;
    if (current is ActiveLocationReady) {
      state = AsyncData(
        ActiveLocationReady(
          current.location.copyWith(nearbyRadiusMeters: meters),
        ),
      );
    }
  }

  // ── Area resolution helper ────────────────────────────────────────────────

  Future<Area?> _resolveArea(
    double lat,
    double lng, {
    String? hintAreaId,
  }) async {
    // If we have a direct area id hint, try the cache first.
    if (hintAreaId != null) {
      final all = await _areas.loadAll();
      final match = all.where((a) => a.id == hintAreaId).firstOrNull;
      if (match != null) return match;
    }
    return _areas.resolveNearest(lat, lng);
  }
}

// =============================================================================
// PROVIDER
// =============================================================================

final activeLocationProvider =
    AsyncNotifierProvider<ActiveLocationNotifier, ActiveLocationState>(
      ActiveLocationNotifier.new,
    );

// =============================================================================
// DERIVED PROVIDERS
// =============================================================================

/// Derives the active nearby radius from the current ActiveLocation.
/// Falls back to 10 000 m when location is not yet ready.
final nearbyRadiusProvider = Provider<int>((ref) {
  final locState = ref.watch(activeLocationProvider).valueOrNull;
  if (locState is ActiveLocationReady) {
    return locState.location.nearbyRadiusMeters;
  }
  return 10000;
});
