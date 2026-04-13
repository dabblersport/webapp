import 'package:dabbler/data/models/area.dart';

enum ActiveLocationSource { gps, saved, manual }

/// The single resolved location that drives all nearby queries app-wide.
///
/// Built by [ActiveLocationNotifier] and consumed by every nearby feed,
/// venue list, and game list. Never expose raw [lat]/[lng] in the UI —
/// always show [area.name] + [area.district].
class ActiveLocation {
  const ActiveLocation({
    required this.lat,
    required this.lng,
    required this.area,
    this.nearbyRadiusMeters = 10000,
    this.defaultRadiusMeters = 10000,
    required this.source,
    this.savedLocationId,
    this.savedLocationLabel,
  });

  final double lat;
  final double lng;
  final Area area;

  /// Default radius from the saved location row, or 10 km. Individual screens
  /// can override via [ActiveLocationNotifier.setRadiusOverride].
  final int nearbyRadiusMeters;

  /// The source's original radius, never overridden. Used to restore
  /// [nearbyRadiusMeters] when [ActiveLocationNotifier.clearRadiusOverride]
  /// is called.
  final int defaultRadiusMeters;

  final ActiveLocationSource source;

  /// Non-null when [source] == [ActiveLocationSource.saved].
  final String? savedLocationId;

  /// Human-readable label, e.g. "Home", "Work", or a custom name.
  final String? savedLocationLabel;

  ActiveLocation copyWith({
    double? lat,
    double? lng,
    Area? area,
    int? nearbyRadiusMeters,
    int? defaultRadiusMeters,
    ActiveLocationSource? source,
    String? savedLocationId,
    String? savedLocationLabel,
  }) {
    return ActiveLocation(
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      area: area ?? this.area,
      nearbyRadiusMeters: nearbyRadiusMeters ?? this.nearbyRadiusMeters,
      defaultRadiusMeters: defaultRadiusMeters ?? this.defaultRadiusMeters,
      source: source ?? this.source,
      savedLocationId: savedLocationId ?? this.savedLocationId,
      savedLocationLabel: savedLocationLabel ?? this.savedLocationLabel,
    );
  }
}
