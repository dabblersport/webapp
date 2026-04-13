import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:dabbler/data/models/area.dart';
import 'package:dabbler/features/misc/data/datasources/supabase_remote_data_source.dart';

/// Stateful, session-scoped area repository.
///
/// Loads all active areas once per session and caches them in memory.
/// Individual screens never refetch — they call [loadAll()] which returns
/// the cache on subsequent calls.
class AreaRepository {
  AreaRepository(this._ref);

  final Ref _ref;
  List<Area>? _cache;

  SupabaseClient get _db => _ref.read(supabaseServiceProvider).client;

  // ── Load all ─────────────────────────────────────────────────────────────

  /// Returns all active areas, loading from Supabase on first call.
  Future<List<Area>> loadAll() async {
    if (_cache != null) return _cache!;
    try {
      final rows = await _db
          .from('areas')
          .select()
          .eq('is_active', true)
          .order('name');
      _cache = rows.map((r) => Area.fromJson(Map<String, dynamic>.from(r as Map))).toList();
      return _cache!;
    } catch (_) {
      return [];
    }
  }

  // ── Nearest via RPC ───────────────────────────────────────────────────────

  /// Resolves the nearest active area to [lat]/[lng] via the
  /// `resolve_nearest_area` Supabase RPC.
  ///
  /// Falls back to client-side Haversine against the in-memory cache when
  /// the RPC is unavailable.
  Future<Area?> resolveNearest(double lat, double lng) async {
    try {
      final result = await _db.rpc(
        'resolve_nearest_area',
        params: {'p_lat': lat, 'p_lng': lng},
      );

      if (result is List && result.isNotEmpty) {
        return Area.fromJson(Map<String, dynamic>.from(result.first as Map));
      }
      if (result is Map && result.isNotEmpty) {
        return Area.fromJson(Map<String, dynamic>.from(result));
      }
    } catch (_) {
      // RPC unavailable — fall through to client-side fallback.
    }

    // Client-side fallback using cached areas.
    final areas = await loadAll();
    if (areas.isEmpty) return null;

    Area? nearest;
    double minDist = double.infinity;
    for (final area in areas) {
      final d = _haversineM(lat, lng, area.centerLat, area.centerLng);
      if (d < minDist) {
        minDist = d;
        nearest = area;
      }
    }
    return nearest;
  }

  // ── Grouped ───────────────────────────────────────────────────────────────

  /// Returns all active areas grouped by district, sorted by district name
  /// then area name within each group.
  Future<Map<String, List<Area>>> areasByDistrict() async {
    final areas = await loadAll();

    final map = <String, List<Area>>{};
    for (final area in areas) {
      map.putIfAbsent(area.district, () => []).add(area);
    }

    // Sort each group by name.
    for (final list in map.values) {
      list.sort((a, b) => a.name.compareTo(b.name));
    }

    // Return sorted by district name.
    return Map.fromEntries(
      map.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    );
  }

  // ── Haversine helper ─────────────────────────────────────────────────────

  static double _haversineM(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const r = 6371000.0;
    final dLat = _rad(lat2 - lat1);
    final dLng = _rad(lng2 - lng1);
    final a = math.pow(math.sin(dLat / 2), 2) +
        math.cos(_rad(lat1)) *
            math.cos(_rad(lat2)) *
            math.pow(math.sin(dLng / 2), 2);
    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  static double _rad(double d) => d * math.pi / 180;
}

// =============================================================================
// PROVIDER
// =============================================================================

final areaRepositoryV2Provider = Provider<AreaRepository>((ref) {
  return AreaRepository(ref);
});
