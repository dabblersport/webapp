import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:dabbler/data/models/area.dart';

/// A place the user picked, as remembered on the device.
class RecentPlace {
  const RecentPlace({required this.name, this.venueId, this.lat, this.lng});

  final String name;
  final String? venueId;
  final double? lat;
  final double? lng;

  /// Identity used for de-duplication: the venue id when there is one, else
  /// the trimmed, lower-cased name plus lat/lng rounded to 4 decimals
  /// (~11 m), so the same typed place picked twice is one entry.
  String get identity {
    if (venueId != null && venueId!.isNotEmpty) return 'v:$venueId';
    String r(double? v) => v == null ? '' : v.toStringAsFixed(4);
    return 'n:${name.trim().toLowerCase()}|${r(lat)}|${r(lng)}';
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    if (venueId != null) 'venue_id': venueId,
    if (lat != null) 'lat': lat,
    if (lng != null) 'lng': lng,
  };

  static RecentPlace? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final name = raw['name'];
    if (name is! String || name.isEmpty) return null;
    final venueId = raw['venue_id'];
    final lat = raw['lat'];
    final lng = raw['lng'];
    return RecentPlace(
      name: name,
      venueId: venueId is String ? venueId : null,
      lat: lat is num ? lat.toDouble() : null,
      lng: lng is num ? lng.toDouble() : null,
    );
  }
}

/// Device-local "Recent" places, per user and capped (KAN-469, cto ruling
/// KAN-463). Follows `ProfileCacheService`'s recents list
/// (`profile_cache_service.dart:21-22`, `:228-241`): a JSON list in
/// SharedPreferences, newest first, de-duplicated, capped at 25.
///
/// Per user (T-004): the key is `place:recent:<userId>`, so a different user
/// on the same device never reads another user's list. With no signed-in
/// user nothing is read or written. [clearAll] removes every user's list,
/// for a sign-out path to call. Device-only: no network, no database.
class RecentPlacesService {
  const RecentPlacesService();

  static const String keyPrefix = 'place:recent:';
  static const int maxRecent = 25;

  static String keyFor(String userId) => '$keyPrefix$userId';

  /// The home location picker's scope: areas, not places, so each sheet only
  /// lists recents it can hand back. Shares [keyPrefix], so [clearAll] still
  /// removes it.
  static const String homeKeyPrefix = '${keyPrefix}home:';

  static String homeKeyFor(String userId) => '$homeKeyPrefix$userId';

  Future<List<RecentPlace>> read(String? userId) async {
    if (userId == null || userId.isEmpty) return const [];
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(keyFor(userId));
      if (raw == null) return const [];
      final list = json.decode(raw);
      if (list is! List) return const [];
      return [
        for (final e in list)
          if (RecentPlace.fromJson(e) case final RecentPlace p) p,
      ];
    } catch (_) {
      return const [];
    }
  }

  /// Puts [place] first, removing any earlier entry with the same identity,
  /// and keeps at most [maxRecent].
  Future<void> add(String? userId, RecentPlace place) async {
    if (userId == null || userId.isEmpty) return;
    try {
      final list = [...await read(userId)]
        ..removeWhere((e) => e.identity == place.identity)
        ..insert(0, place);
      while (list.length > maxRecent) {
        list.removeLast();
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        keyFor(userId),
        json.encode([for (final p in list) p.toJson()]),
      );
    } catch (_) {
      // Best effort, like the pattern: a failed write loses one recent.
    }
  }

  /// The home picker's recent areas for [userId], newest first.
  Future<List<Area>> readAreas(String? userId) async {
    if (userId == null || userId.isEmpty) return const [];
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(homeKeyFor(userId));
      if (raw == null) return const [];
      final list = json.decode(raw);
      if (list is! List) return const [];
      final out = <Area>[];
      for (final e in list) {
        if (e is! Map) continue;
        try {
          out.add(Area.fromJson(Map<String, dynamic>.from(e)));
        } catch (_) {
          // Skip an entry that no longer parses.
        }
      }
      return out;
    } catch (_) {
      return const [];
    }
  }

  /// Puts [area] first in the home scope, de-duplicated by area id, keeping
  /// at most [maxRecent].
  Future<void> addArea(String? userId, Area area) async {
    if (userId == null || userId.isEmpty) return;
    try {
      final list = [...await readAreas(userId)]
        ..removeWhere((e) => e.id == area.id)
        ..insert(0, area.copyWith(distanceM: null));
      while (list.length > maxRecent) {
        list.removeLast();
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        homeKeyFor(userId),
        json.encode([for (final a in list) a.toJson()]),
      );
    } catch (_) {
      // Best effort: a failed write loses one recent.
    }
  }

  Future<void> clear(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(keyFor(userId));
    await prefs.remove(homeKeyFor(userId));
  }

  /// Removes every user's recents, both scopes, on this device (sign-out).
  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    for (final k in prefs.getKeys().where((k) => k.startsWith(keyPrefix))) {
      await prefs.remove(k);
    }
  }
}
