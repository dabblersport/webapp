/// A nearby game row returned by the `rpc_get_nearby_games` PostGIS RPC.
///
/// Plain Dart class (no Freezed) matching the pattern in [NearbyVenueModel].
/// Distance is always present because the RPC computes it.
class NearbyGameModel {
  const NearbyGameModel({
    required this.id,
    required this.title,
    this.sportName,
    this.scheduledAt,
    this.status,
    this.venueName,
    this.latitude,
    this.longitude,
    required this.distanceMeters,
    this.playerCount,
    this.spotsRemaining,
    required this.isPublic,
  });

  final String id;
  final String title;
  final String? sportName;
  final DateTime? scheduledAt;

  /// One of: 'upcoming', 'live', 'ended'  (computed by the RPC).
  final String? status;
  final String? venueName;
  final double? latitude;
  final double? longitude;

  /// Straight-line distance in metres from the query origin.
  final double distanceMeters;
  final int? playerCount;
  final int? spotsRemaining;
  final bool isPublic;

  factory NearbyGameModel.fromJson(Map<String, dynamic> json) {
    return NearbyGameModel(
      id: json['id'] as String,
      title: json['title'] as String? ?? 'Untitled Game',
      sportName: json['sport_name'] as String?,
      scheduledAt: json['scheduled_at'] != null
          ? DateTime.tryParse(json['scheduled_at'] as String)
          : null,
      status: json['status'] as String?,
      venueName: json['venue_name'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      distanceMeters:
          (json['distance_meters'] as num?)?.toDouble() ?? 0.0,
      playerCount: json['player_count'] as int?,
      spotsRemaining: json['spots_remaining'] as int?,
      isPublic: json['is_public'] as bool? ?? true,
    );
  }

  /// Formatted distance label: "850 m" or "1.2 km".
  String get distanceLabel {
    if (distanceMeters < 1000) {
      return '${distanceMeters.round()} m';
    }
    final km = distanceMeters / 1000;
    final formatted =
        km < 10 ? km.toStringAsFixed(1) : km.round().toString();
    return '$formatted km';
  }
}
