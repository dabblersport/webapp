import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dabbler/data/models/area.dart';
import 'package:dabbler/data/models/profile_location.dart';
import 'package:dabbler/data/repositories/profile_location_repository.dart';
import 'package:dabbler/data/repositories/profile_location_repository_impl.dart';
import 'package:dabbler/features/location/domain/saved_place_rules.dart';
import 'package:dabbler/features/location/providers/active_location_provider.dart';
import 'package:dabbler/features/location/providers/location_providers.dart';
import 'package:dabbler/core/data/supabase_remote_data_source.dart';
import 'package:dabbler/features/profile/presentation/providers/profile_providers.dart';

// =============================================================================
// REPOSITORY PROVIDER
// =============================================================================

final profileLocationRepositoryProvider = Provider<ProfileLocationRepository>((
  ref,
) {
  final svc = ref.watch(supabaseServiceProvider);
  return ProfileLocationRepositoryImpl(svc);
});

// =============================================================================
// NOTIFIER
// =============================================================================

/// What saving a place did (KAN-589).
enum SavePlaceOutcome {
  saved,

  /// Another saved place is already at this location: nothing was written.
  duplicate,
  failed,
}

class ProfileLocationNotifier extends AsyncNotifier<List<ProfileLocation>> {
  ProfileLocationRepository get _repo =>
      ref.read(profileLocationRepositoryProvider);

  @override
  Future<List<ProfileLocation>> build() async {
    final result = await _repo.getLocations();
    return result.fold((_) => [], (list) => list);
  }

  // ── Save ──────────────────────────────────────────────────────────────────

  /// Returns whether the place was saved. A failure leaves the list as it was.
  Future<bool> saveLocation({
    required double lat,
    required double lng,
    required String areaId,
    required ProfileLocationLabel label,
    String? labelCustom,
    bool isPrimary = false,
  }) async =>
      await savePlace(
        lat: lat,
        lng: lng,
        areaId: areaId,
        label: label,
        labelCustom: labelCustom,
        isPrimary: isPrimary,
      ) ==
      SavePlaceOutcome.saved;

  /// Whether another saved place already sits at ([lat], [lng]) (KAN-589).
  /// [exceptId] is the place being edited.
  Future<bool> hasPlaceAt(double lat, double lng, {String? exceptId}) async {
    List<ProfileLocation> places;
    try {
      places = await future;
    } catch (_) {
      places = state.valueOrNull ?? const <ProfileLocation>[];
    }
    return savedPlaceAt(places, lat, lng, exceptId: exceptId) != null;
  }

  /// Saves a place. Two saved places never share one location, whatever their
  /// labels (KAN-589): a place within [kSamePlaceToleranceMeters] of another
  /// is refused before anything is written.
  Future<SavePlaceOutcome> savePlace({
    required double lat,
    required double lng,
    required String areaId,
    required ProfileLocationLabel label,
    String? labelCustom,
    bool isPrimary = false,
  }) async {
    if (await hasPlaceAt(lat, lng)) return SavePlaceOutcome.duplicate;

    final profileId = ref.read(profileControllerProvider).profile?.id;
    if (profileId == null) return SavePlaceOutcome.failed;

    // 1. Insert geo_location and get its id
    final geoResult = await _repo.resolveGeoLocationId(
      lat: lat,
      lng: lng,
      areaId: areaId,
    );

    final geoLocationId = geoResult.fold((_) => null, (id) => id);
    if (geoLocationId == null) return SavePlaceOutcome.failed;

    // 2. Insert profile_location
    final saveResult = await _repo.saveLocation(
      profileId: profileId,
      lat: lat,
      lng: lng,
      geoLocationId: geoLocationId,
      areaId: areaId,
      label: label,
      labelCustom: labelCustom,
      isPrimary: isPrimary,
    );

    return saveResult.fold((_) => SavePlaceOutcome.failed, (row) {
      // The server fills the point from the geo location; until a reload the
      // local row carries the point that was saved, so the same-place rule
      // sees it at once.
      final saved = row.copyWith(lat: row.lat ?? lat, lng: row.lng ?? lng);
      final current = state.valueOrNull ?? [];
      // Demote previous primary in local state if this one is primary
      final updated = isPrimary
          ? [saved, ...current.map((l) => l.copyWith(isPrimary: false))]
          : [saved, ...current];
      state = AsyncData(updated);
      return SavePlaceOutcome.saved;
    });
  }

  // ── Set primary ───────────────────────────────────────────────────────────

  Future<void> setPrimary(String locationId) async {
    final current = state.valueOrNull ?? [];
    final target = current.where((l) => l.id == locationId).firstOrNull;
    if (target == null || target.lat == null || target.lng == null) return;

    final profileId = ref.read(profileControllerProvider).profile?.id;
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

  /// Deletes a saved place and refreshes the list from the server (KAN-589).
  /// Returns whether the place is gone: a failed delete, or one the server did
  /// not apply (the place comes back on the refresh), reports false and the
  /// list shows what the server holds.
  Future<bool> deleteLocation(String locationId) async {
    final result = await _repo.deleteLocation(locationId);
    if (result.isFailure) return false;
    final current = state.valueOrNull ?? [];
    state = AsyncData(current.where((l) => l.id != locationId).toList());
    final fresh = await _repo.getLocations();
    return fresh.fold((_) => true, (list) {
      state = AsyncData(list);
      return list.every((l) => l.id != locationId);
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
final resolvedNearestAreaProvider = FutureProvider.autoDispose
    .family<Area?, ({double lat, double lng})>((ref, coords) async {
      final repo = ref.watch(areaRepositoryProvider);
      final result = await repo.getNearestArea(
        lat: coords.lat,
        lng: coords.lng,
      );
      return result.fold((_) => null, (area) => area);
    });
