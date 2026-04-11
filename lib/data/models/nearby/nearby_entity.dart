/// Base class for all nearby entity projections returned by PostGIS RPCs.
///
/// Every `get_nearby_*` RPC returns at least (id, lat, lng, distance_meters).
/// Concrete subtypes add entity-specific fields.
abstract class NearbyEntity {
  const NearbyEntity({
    required this.id,
    required this.lat,
    required this.lng,
    required this.distanceMeters,
  });

  final String id;
  final double lat;
  final double lng;
  final double distanceMeters;

  @override
  String toString() =>
      '${runtimeType}(id: $id, distanceMeters: $distanceMeters)';
}
