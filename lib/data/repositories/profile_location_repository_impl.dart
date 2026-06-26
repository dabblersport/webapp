import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/config/supabase_config.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/data/models/profile_location.dart';
import 'package:dabbler/data/repositories/base_repository.dart';
import 'package:dabbler/data/repositories/profile_location_repository.dart';

class ProfileLocationRepositoryImpl extends BaseRepository
    implements ProfileLocationRepository {
  const ProfileLocationRepositoryImpl(super.svc);

  // ── Geo-location resolution ──────────────────────────────────────────────

  @override
  Future<Result<String, Failure>> resolveGeoLocationId({
    required double lat,
    required double lng,
    required String areaId,
  }) =>
      guard(() async {
        // Insert a PostGIS geography point. Longitude comes first in WKT.
        final row = await svc.client
            .from(SupabaseConfig.geoLocationsTable)
            .insert({
              'location': 'SRID=4326;POINT($lng $lat)',
              'area_id': areaId,
              'geohash': _geohash(lat, lng),
            })
            .select('id')
            .single();
        return row['id'] as String;
      });

  // ── Profile location CRUD ────────────────────────────────────────────────

  @override
  Future<Result<List<ProfileLocation>, Failure>> getLocations() =>
      guard(() async {
        // RLS scopes this to the authenticated user's profile automatically.
        final rows = await svc.client
            .from(SupabaseConfig.profileLocationsTable)
            .select()
            .order('created_at', ascending: false);
        return rows
            .map((r) => ProfileLocation.fromJson(r))
            .toList();
      });

  @override
  Future<Result<ProfileLocation, Failure>> saveLocation({
    required double lat,
    required double lng,
    required String geoLocationId,
    required String areaId,
    required ProfileLocationLabel label,
    String? labelCustom,
    bool isPrimary = false,
  }) =>
      guard(() async {
        // If this will be primary, demote existing primary first.
        if (isPrimary) {
          await svc.client
              .from(SupabaseConfig.profileLocationsTable)
              .update({'is_primary': false})
              .eq('is_primary', true);
        }

        final row = await svc.client
            .from(SupabaseConfig.profileLocationsTable)
            .insert({
              'geo_location_id': geoLocationId,
              'label': label.toJson(),
              if (labelCustom != null) 'label_custom': labelCustom,
              'is_primary': isPrimary,
            })
            .select()
            .single();
        return ProfileLocation.fromJson(row);
      });

  @override
  Future<Result<void, Failure>> setPrimary(
    String locationId, {
    required double lat,
    required double lng,
    required String profileId,
  }) =>
      guard(() async {
        // Step 1: clear existing primary
        await svc.client
            .from(SupabaseConfig.profileLocationsTable)
            .update({'is_primary': false})
            .eq('is_primary', true);

        // Step 2: set new primary
        await svc.client
            .from(SupabaseConfig.profileLocationsTable)
            .update({'is_primary': true})
            .eq('id', locationId);

        // Step 3: sync to profiles table for post-trigger fallback
        await svc.client.from(SupabaseConfig.usersTable).update({
          'latitude': lat,
          'longitude': lng,
          'last_location_updated_at':
              DateTime.now().toUtc().toIso8601String(),
        }).eq('id', profileId);
      });

  @override
  Future<Result<void, Failure>> deleteLocation(String locationId) =>
      guard(() async {
        await svc.client
            .from(SupabaseConfig.profileLocationsTable)
            .delete()
            .eq('id', locationId);
      });

  @override
  Future<Result<void, Failure>> renameLocation(
    String locationId,
    ProfileLocationLabel label, {
    String? customName,
  }) =>
      guard(() async {
        await svc.client.from(SupabaseConfig.profileLocationsTable).update({
          'label': label.toJson(),
          'label_custom': customName,
        }).eq('id', locationId);
      });

  @override
  Future<Result<void, Failure>> updateRadius(
    String locationId,
    int meters,
  ) =>
      guard(() async {
        await svc.client
            .from(SupabaseConfig.profileLocationsTable)
            .update({'nearby_radius_meters': meters}).eq('id', locationId);
      });

  // ── Geohash helper ────────────────────────────────────────────────────────
  //
  // Simple base32 geohash encoding (precision 9, ~5 m accuracy).
  // Avoids importing a dedicated package for this single use-case.

  static const String _base32 = '0123456789bcdefghjkmnpqrstuvwxyz';

  static String _geohash(double lat, double lng, {int precision = 9}) {
    double minLat = -90, maxLat = 90;
    double minLng = -180, maxLng = 180;
    final buf = StringBuffer();
    int bits = 0;
    int bitsTotal = 0;
    int hashValue = 0;
    bool isEven = true;

    while (buf.length < precision) {
      if (isEven) {
        final mid = (minLng + maxLng) / 2;
        if (lng >= mid) {
          hashValue = (hashValue << 1) | 1;
          minLng = mid;
        } else {
          hashValue = hashValue << 1;
          maxLng = mid;
        }
      } else {
        final mid = (minLat + maxLat) / 2;
        if (lat >= mid) {
          hashValue = (hashValue << 1) | 1;
          minLat = mid;
        } else {
          hashValue = hashValue << 1;
          maxLat = mid;
        }
      }
      isEven = !isEven;
      bits++;
      bitsTotal++;

      if (bits == 5) {
        buf.write(_base32[hashValue]);
        bits = 0;
        hashValue = 0;
      }
    }
    // suppress unused-variable warning
    final _ = bitsTotal;
    return buf.toString();
  }

}
