import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/data/models/profile_location.dart';

abstract class ProfileLocationRepository {
  /// Load all saved locations for the authenticated profile, sorted newest first.
  Future<Result<List<ProfileLocation>, Failure>> getLocations();

  /// Insert a new `geo_location` row and return its id.
  ///
  /// This id is then passed as [geoLocationId] to [saveLocation].
  Future<Result<String, Failure>> resolveGeoLocationId({
    required double lat,
    required double lng,
    required String areaId,
  });

  /// Insert a new `profile_locations` row.
  Future<Result<ProfileLocation, Failure>> saveLocation({
    required double lat,
    required double lng,
    required String geoLocationId,
    required String areaId,
    required ProfileLocationLabel label,
    String? labelCustom,
    bool isPrimary = false,
  });

  /// Set one location as primary (clears any previous primary first).
  ///
  /// Also syncs lat/lng to the `profiles` table for the post-trigger fallback.
  Future<Result<void, Failure>> setPrimary(
    String locationId, {
    required double lat,
    required double lng,
    required String profileId,
  });

  /// Delete a saved location.
  Future<Result<void, Failure>> deleteLocation(String locationId);

  /// Update the label of a saved location.
  Future<Result<void, Failure>> renameLocation(
    String locationId,
    ProfileLocationLabel label, {
    String? customName,
  });
}
