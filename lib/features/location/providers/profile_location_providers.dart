import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dabbler/data/models/area.dart';
import 'package:dabbler/data/models/profile_location.dart';
import 'package:dabbler/data/repositories/profile_location_repository.dart';
import 'package:dabbler/data/repositories/profile_location_repository_impl.dart';
import 'package:dabbler/features/location/providers/active_location_provider.dart';
import 'package:dabbler/features/location/providers/location_providers.dart';
import 'package:dabbler/features/misc/data/datasources/supabase_remote_data_source.dart';
import 'package:dabbler/features/profile/presentation/providers/profile_providers.dart';

// =============================================================================
// REPOSITORY PROVIDER
// =============================================================================

final profileLocationRepositoryProvider =
    Provider<ProfileLocationRepository>((ref) {
  final svc = ref.watch(supabaseServiceProvider);
  return ProfileLocationRepositoryImpl(svc);
});

// =============================================================================
// NOTIFIER
// =============================================================================

class ProfileLocationNotifier
    extends AsyncNotifier<List<ProfileLocation>> {
  ProfileLocationRepository get _repo =>
      ref.read(profileLocationRepositoryProvider);

  @override
  Future<List<ProfileLocation>> build() async {
    final result = await _repo.getLocations();
    return result.fold((_) => [], (list) => list);
  }

  // ── Save ──────────────────────────────────────────────────────────────────

  Future<void> saveLocation({
    required double lat,
    required double lng,
    required String areaId,
    required ProfileLocationLabel label,
    String? labelCustom,
    bool isPrimary = false,
  }) async {
    // 1. Insert geo_location and get its id
    final geoResult = await _repo.resolveGeoLocationId(
      lat: lat,
      lng: lng,
      areaId: areaId,
    );

    final geoLocationId = geoResult.fold((_) => null, (id) => id);
    if (geoLocationId == null) return;

    // 2. Insert profile_location
    final saveResult = await _repo.saveLocation(
      lat: lat,
      lng: lng,
      geoLocationId: geoLocationId,
      areaId: areaId,
      label: label,
      labelCustom: labelCustom,
      isPrimary: isPrimary,
    );

    saveResult.fold((_) => null, (saved) {
      final current = state.valueOrNull ?? [];
      // Demote previous primary in local state if this one is primary
      final updated = isPrimary
          ? [
              saved,
              ...current.map((l) => l.copyWith(isPrimary: false)),
            ]
          : [saved, ...current];
      state = AsyncData(updated);
    });
  }

  // ── Set primary ───────────────────────────────────────────────────────────

  Future<void> setPrimary(String locationId) async {
    final current = state.valueOrNull ?? [];
    final target = current.where((l) => l.id == locationId).firstOrNull;
    if (target == null || target.lat == null || target.lng == null) return;

    final profileId =
        ref.read(profileControllerProvider).profile?.id;
    if (profileId == null) return;

    final result = await _repo.setPrimary(
      locationId,
      lat: target.lat!,
      lng: target.lng!,
      profileId: profileId,
    );

    result.fold((_) => null, (_) {
      state = AsyncData(
        current.map((l) => l.copyWith(isPrimary: l.id == locationId)).toList(),
      );
    });
  }

  // ── Delete ────────────────────────────────────────────────────────────────

  Future<void> deleteLocation(String locationId) async {
    final result = await _repo.deleteLocation(locationId);
    result.fold((_) => null, (_) {
      final current = state.valueOrNull ?? [];
      state = AsyncData(current.where((l) => l.id != locationId).toList());
    });
  }

  // ── Rename ────────────────────────────────────────────────────────────────

  Future<void> renameLocation(
    String locationId,
    ProfileLocationLabel label, {
    String? customName,
  }) async {
    final result = await _repo.renameLocation(
      locationId,
      label,
      customName: customName,
    );
    result.fold((_) => null, (_) {
      final current = state.valueOrNull ?? [];
      state = AsyncData(
        current
            .map(
              (l) => l.id == locationId
                  ? l.copyWith(label: label, labelCustom: customName)
                  : l,
            )
            .toList(),
      );
    });
  }

  // ── Update radius ─────────────────────────────────────────────────────────

  Future<void> updateRadius(String locationId, int meters) async {
    final result = await _repo.updateRadius(locationId, meters);
    result.fold((_) => null, (_) {
      final current = state.valueOrNull ?? [];
      state = AsyncData(
        current
            .map(
              (l) => l.id == locationId
                  ? l.copyWith(nearbyRadiusMeters: meters)
                  : l,
            )
            .toList(),
      );
    });
  }

  /// Update the primary location's radius and propagate to ActiveLocation.
  Future<void> updatePrimaryRadius(int meters) async {
    final locations = state.valueOrNull ?? [];
    final primary =
        locations.where((l) => l.isPrimary).firstOrNull ??
        locations.firstOrNull;
    if (primary == null) return;
    await updateRadius(primary.id, meters);
    ref.read(activeLocationProvider.notifier).setRadiusOverride(meters);
  }
}

// =============================================================================
// PROVIDERS
// =============================================================================

final profileLocationNotifierProvider =
    AsyncNotifierProvider<ProfileLocationNotifier, List<ProfileLocation>>(
  ProfileLocationNotifier.new,
);

/// Resolves the nearest [Area] to the given coordinates using the areas table.
///
/// Used by [SaveLocationSheet] and [SavedLocationsScreen] to display/filter
/// the area name before saving.
final resolvedNearestAreaProvider =
    FutureProvider.autoDispose.family<Area?, ({double lat, double lng})>(
  (ref, coords) async {
    final repo = ref.watch(areaRepositoryProvider);
    final result = await repo.getNearestArea(
      lat: coords.lat,
      lng: coords.lng,
    );
    return result.fold((_) => null, (area) => area);
  },
);
