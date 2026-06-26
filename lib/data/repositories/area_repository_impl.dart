import 'dart:math' as math;
import 'package:dabbler/core/config/supabase_config.dart';

import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/data/models/area.dart';
import 'package:dabbler/data/repositories/area_repository.dart';
import 'package:dabbler/data/repositories/base_repository.dart';

/// Concrete [AreaRepository] backed by Supabase.
class AreaRepositoryImpl extends BaseRepository implements AreaRepository {
  AreaRepositoryImpl(super.svc);

  @override
  Future<Result<Area, Failure>> getArea(String areaId) => guard(() async {
    final row = await svc.client
        .from(SupabaseConfig.areasTable)
        .select()
        .eq('id', areaId)
        .single();
    return Area.fromJson(row);
  });

  @override
  Future<Result<List<Area>, Failure>> getActiveAreas() => guard(() async {
    final rows = await svc.client
        .from(SupabaseConfig.areasTable)
        .select()
        .eq('is_active', true)
        .order('name');
    return rows.map((r) => Area.fromJson(r)).toList();
  });

  @override
  Future<Result<Area, Failure>> getNearestArea({
    required double lat,
    required double lng,
  }) => guard(() async {
    final rows = await svc.client.from(SupabaseConfig.areasTable).select().eq('is_active', true);

    if (rows.isEmpty) {
      throw Exception('No active areas found');
    }

    final areas = rows.map((r) => Area.fromJson(r)).toList();

    // Find the closest area by Haversine-like distance.
    Area nearest = areas.first;
    double minDist = double.infinity;

    for (final area in areas) {
      final dist = _haversine(lat, lng, area.centerLat, area.centerLng);
      if (dist < minDist) {
        minDist = dist;
        nearest = area;
      }
    }

    return nearest;
  });

  /// Simple Haversine distance in meters.
  static double _haversine(double lat1, double lng1, double lat2, double lng2) {
    const r = 6371000.0; // Earth radius in meters
    final dLat = _toRad(lat2 - lat1);
    final dLng = _toRad(lng2 - lng1);
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRad(lat1)) *
            math.cos(_toRad(lat2)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  static double _toRad(double deg) => deg * math.pi / 180;
}
