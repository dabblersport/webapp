import 'package:dabbler_design_system/dabbler_design_system.dart'
    show DabblerMotion;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart' show LocationAccuracy;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dabbler/core/services/gps_service.dart';
import 'package:dabbler/data/models/active_location.dart';
import 'package:dabbler/data/models/area.dart';
import 'package:dabbler/data/models/profile_location.dart';
import 'package:dabbler/data/repositories/area_repository_v2.dart';
import 'package:dabbler/features/auth_onboarding/presentation/providers/auth_profile_providers.dart'
    show currentUserIdProvider;
import 'package:dabbler/features/location/data/device_location_store.dart';
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

/// The user chose a city but no area yet (KAN-586): there is no point, so
/// distance controls are off and nothing is sorted or filtered by distance.
/// City content stays usable.
class ActiveLocationCityOnly extends ActiveLocationState {
  ActiveLocationCityOnly(this.city);
  final String city;
}

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

  /// The signed-in account of this build; a change rebuilds the notifier, so a
  /// previous account's selection is never shown (KAN-586).
  String? _accountId;

  Future<DeviceLocationStore?> _store() async {
    try {
      return DeviceLocationStore(
        await SharedPreferences.getInstance(),
        accountId: _accountId,
      );
    } catch (_) {
      return null;
    }
  }

  AreaRepository get _areas => ref.read(areaRepositoryV2Provider);

  @override
  Future<ActiveLocationState> build() async {
    // Keep alive so nearby feeds don't re-initialise on navigation.
    ref.keepAlive();
    try {
      _accountId = ref.watch(currentUserIdProvider);
    } catch (_) {
      _accountId = null;
    }

    return _initialise();
  }

  // ── Initialisation ────────────────────────────────────────────────────────

  /// Degradation order (nothing here waits for GPS: first paint never does):
  /// 1. Saved primary location (instant, no GPS wait)
  /// 2. Silent GPS attempt in the background (upgrades the state if it wins)
  /// 3. No saved location: [ActiveLocationLoading] now, and the background
  ///    attempt settles it (a position, or denied / error).
  Future<ActiveLocationState> _initialise() async {
    // 0. This device's own choice (KAN-586): it wins over the saved primary
    // and over any GPS upgrade, whatever its mode, and survives a restart.
    final stored = (await _store())?.read();
    if (stored != null) {
      if (stored.mode == DeviceLocationMode.manual || !stored.hasPoint) {
        return _fromDeviceLocation(stored);
      }
      // Stored Auto: show the stored fix at once, then let a silent GPS read
      // refresh it; if that fails it stays, labelled last known.
      _backgroundGpsRefresh(markLastKnownOnMiss: true);
      return _fromDeviceLocation(stored);
    }

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
    bool markLastKnownOnMiss = false,
  }) {
    // On the event queue, after the build that started it has completed.
    Future<void>(() async {
      try {
        // A Manual selection is never overwritten by an Auto fix.
        if (await _isManual()) return;
        // Silent: only upgrades when permission was already granted.
        final result = await _gps.getCurrentLocation(
          requestPermission: false,
          cap: GpsService.fixCap,
        );
        if (result is! LocationSuccess) {
          if (markLastKnownOnMiss) {
            final last = await _lastKnownReady();
            if (last != null) state = AsyncData(last);
            return;
          }
          if (settleWhenUnsaved && state.valueOrNull is ActiveLocationLoading) {
            // Auto is unavailable: the last known location, labelled, if
            // there is one; otherwise the denied / error state.
            final last = await _lastKnownReady();
            state = AsyncData(last ?? await _stateFromGpsResult(result));
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
          if (await _isManual()) return;
          await _recordAutoFix(area, result.lat, result.lng);
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
    if (await _isManual()) return;
    final area = await _resolveArea(fix.lat, fix.lng);
    if (area == null) return;
    await _recordAutoFix(area, fix.lat, fix.lng);
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
    final next = await _stateFromGpsResult(result);
    if (next is ActiveLocationReady) {
      // The user asked for Auto: it replaces a Manual selection.
      await _recordAutoFix(
        next.location.area,
        next.location.lat,
        next.location.lng,
        explicit: true,
      );
    } else if (next is ActiveLocationDenied) {
      final last = await _lastKnownReady();
      if (last != null) {
        state = AsyncData(last);
        return;
      }
    }
    state = AsyncData(next);
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
    await (await _store())?.setManual(
      city: area.city,
      area: area.name,
      lat: area.centerLat,
      lng: area.centerLng,
    );
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

  // ── Per-device current location (KAN-526, KAN-586) ───────────────────────

  /// Switch to a point the user picked in the "Set location" drawer, and
  /// persist it for this device and account so it is the active location after
  /// a restart. Never asks for permission and never reads GPS.
  Future<void> useManualPoint(
    double lat,
    double lng,
    String label, {
    String? city,
    String? area,
  }) async {
    state = AsyncData(_manualReady(lat, lng, label, city: city));
    try {
      await (await _store())?.setManual(
        city: city ?? label,
        area: area ?? label,
        lat: lat,
        lng: lng,
      );
    } catch (_) {
      // Persistence is best effort; the in-memory choice already applies.
    }
  }

  /// The user changed the city. A different city clears the previous area and
  /// coordinates: the state has no point, so distance controls are off until a
  /// new area is chosen, and city content stays usable.
  Future<void> useManualCity(String city) async {
    final DeviceLocation? next = await (await _store())?.changeCity(city);
    if (next != null && next.hasPoint) {
      state = AsyncData(_fromDeviceLocation(next));
    } else {
      state = AsyncData(ActiveLocationCityOnly(city));
    }
  }

  Future<bool> _isManual() async =>
      (await _store())?.read()?.mode == DeviceLocationMode.manual;

  Future<void> _recordAutoFix(
    Area area,
    double lat,
    double lng, {
    bool explicit = false,
  }) async {
    try {
      final store = await _store();
      if (store == null) return;
      await store.applyAutoFix(
        city: area.city,
        area: area.name,
        lat: lat,
        lng: lng,
        explicit: explicit,
      );
    } catch (_) {}
  }

  /// Auto is unavailable: the stored last known point, labelled as such.
  Future<ActiveLocationReady?> _lastKnownReady() async {
    try {
      final DeviceLocation? last = await (await _store())
          ?.markAutoUnavailable();
      if (last == null || !last.hasPoint) return null;
      final r = _fromDeviceLocation(last);
      return r is ActiveLocationReady ? r : null;
    } catch (_) {
      return null;
    }
  }

  ActiveLocationState _fromDeviceLocation(DeviceLocation l) {
    if (!l.hasPoint) return ActiveLocationCityOnly(l.city);
    final bool last = l.provenance == DeviceLocationProvenance.lastKnown;
    final ActiveLocationReady ready = _manualReady(
      l.lat!,
      l.lng!,
      l.area ?? l.city,
      city: l.city,
    );
    if (l.mode == DeviceLocationMode.manual && !last) return ready;
    return ActiveLocationReady(
      ready.location.copyWith(
        source: last
            ? ActiveLocationSource.lastKnown
            : ActiveLocationSource.gps,
      ),
    );
  }

  ActiveLocationReady _manualReady(
    double lat,
    double lng,
    String label, {
    String? city,
  }) {
    // A local area named after the picked place: no server lookup, so the
    // choice works offline and on restart.
    return ActiveLocationReady(
      ActiveLocation(
        lat: lat,
        lng: lng,
        area: Area(
          id: 'manual',
          name: label,
          district: label,
          city: city ?? label,
          country: 'AE',
          centerLat: lat,
          centerLng: lng,
        ),
        nearbyRadiusMeters: _radiusOverride ?? 10000,
        source: ActiveLocationSource.manual,
        savedLocationLabel: label,
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

/// Whether distance sort and radius filters may be used: only when the active
/// location has a point. After a city change (no area yet) and while the
/// location is unknown they are off; city content stays usable (KAN-586).
final distanceControlsEnabledProvider = Provider<bool>((ref) {
  return ref.watch(activeLocationProvider).valueOrNull is ActiveLocationReady;
});
