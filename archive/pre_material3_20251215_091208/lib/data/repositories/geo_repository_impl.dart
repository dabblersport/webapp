import 'dart:math' as math;
import 'package:meta/meta.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/utils/json.dart';
import '../models/venue.dart';
import 'base_repository.dart';
import 'geo_repository.dart';

@immutable
class GeoRepositoryImpl extends BaseRepository implements GeoRepository {
  const GeoRepositoryImpl(super.svc);

  SupabaseClient get _db => svc.client;

  // --- public API ------------------------------------------------------------

  @override
  Future<Result<List<Venue>, Failure>> nearbyVenues({
    required double lat,
    required double lng,
    double radiusMeters = 5000,
    int limit = 20,
    int offset = 0,
  }) async {
    return guard<List<Venue>>(() async {
      // Attempt RPC first if you've created `geo_nearby_venues(lat, lng, radius_m, lim, off)`
      try {
        final rpcRows =
            await _db.rpc(
                  'geo_nearby_venues',
                  params: {
                    'in_lat': lat,
                    'in_lng': lng,
                    'in_radius_m': radiusMeters,
                    'in_limit': limit,
                    'in_offset': offset,
                  },
                )
                as List<dynamic>;

        // If RPC returned something structured, map to Venue and return.
        if (rpcRows.isNotEmpty) {
          final venues = rpcRows
              .cast<Map<String, dynamic>>()
              .map((m) => Venue.fromJson(asMap(m)))
              .toList();
          return venues;
        }
        // If empty, fall through to fallback for consistency.
      } on PostgrestException catch (e) {
        // If RPC is missing/404 or not exposed, fall back to client-side path.
        // We silently swallow and use fallback; guard() will still catch other errors.
        final _ = e;
      } catch (_) {
        // Non-PostgREST errors also fall back.
      }

      // --- Fallback: bounding box scan + client-side haversine sort -----------
      final bbox = _bboxForRadius(lat, lng, radiusMeters);
      // Adjust column names if your schema differs (e.g., 'latitude'/'longitude').
      final rows = await _db
          .from('venues')
          .select()
          .gte('lat', bbox.minLat)
          .lte('lat', bbox.maxLat)
          .gte('lng', bbox.minLng)
          .lte('lng', bbox.maxLng)
          .limit(limit * 5) // oversample a bit before client-side sort
          .range(offset, offset + (limit * 5) - 1);

      final withDistance = rows
          .map((m) {
            final v = Venue.fromJson(asMap(m));
            final d = _haversineMeters(lat, lng, _readLat(v), _readLng(v));
            return (venue: v, dist: d);
          })
          .where((e) => e.dist <= radiusMeters)
          .toList();

      withDistance.sort((a, b) => a.dist.compareTo(b.dist));

      // Apply final pagination locally (stable and predictable).
      final start = math.min(offset, withDistance.length);
      final end = math.min(start + limit, withDistance.length);
      return withDistance.sublist(start, end).map((e) => e.venue).toList();
    });
  }

  // --- helpers ---------------------------------------------------------------

  // Extract lat/lng from Venue. Adjust if your Venue fields differ.
  double _readLat(Venue v) {
    // ignore: avoid_dynamic_calls
    final val = (v as dynamic).lat;
    return (val is num) ? val.toDouble() : double.nan;
  }

  double _readLng(Venue v) {
    // ignore: avoid_dynamic_calls
    final val = (v as dynamic).lng;
    return (val is num) ? val.toDouble() : double.nan;
  }

  /// Haversine distance in meters between two WGS84 points.
  double _haversineMeters(double lat1, double lng1, double lat2, double lng2) {
    const r = 6371000.0; // mean Earth radius (m)
    final dLat = _deg2rad(lat2 - lat1);
    final dLng = _deg2rad(lng2 - lng1);
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_deg2rad(lat1)) *
            math.cos(_deg2rad(lat2)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }

  double _deg2rad(double d) => d * math.pi / 180.0;

  _BBox _bboxForRadius(double lat, double lng, double radiusMeters) {
    // Approx degrees per meter
    // 1 deg lat ~ 111_320m; 1 deg lng ~ 111_320m * cos(lat)
    const mPerDeg = 111320.0;
    final dLat = radiusMeters / mPerDeg;
    final dLng =
        radiusMeters / (mPerDeg * math.cos(_deg2rad(lat)).clamp(0.1, 1.0));
    return _BBox(
      minLat: lat - dLat,
      maxLat: lat + dLat,
      minLng: lng - dLng,
      maxLng: lng + dLng,
    );
  }
}

@immutable
class _BBox {
  final double minLat, maxLat, minLng, maxLng;
  const _BBox({
    required this.minLat,
    required this.maxLat,
    required this.minLng,
    required this.maxLng,
  });
}
