/// Label options for a saved profile location.
enum ProfileLocationLabel {
  home,
  work,
  school,
  current,
  custom;

  /// Converts from the DB snake_case string.
  static ProfileLocationLabel fromJson(String value) {
    return ProfileLocationLabel.values.firstWhere(
      (e) => e.name == value,
      orElse: () => ProfileLocationLabel.custom,
    );
  }

  String toJson() => name;

  String get displayName {
    switch (this) {
      case ProfileLocationLabel.home:
        return 'Home';
      case ProfileLocationLabel.work:
        return 'Work';
      case ProfileLocationLabel.school:
        return 'School';
      case ProfileLocationLabel.current:
        return 'Current';
      case ProfileLocationLabel.custom:
        return 'Custom';
    }
  }
}

/// A saved location belonging to a profile (`profile_locations` table).
///
/// `lat`, `lng`, and `areaId` are auto-populated server-side by the
/// `fn_sync_geo_fields` trigger when `geoLocationId` is set.
/// Flutter never writes those fields directly.
class ProfileLocation {
  const ProfileLocation({
    required this.id,
    required this.profileId,
    this.geoLocationId,
    this.areaId,
    this.lat,
    this.lng,
    required this.label,
    this.labelCustom,
    this.nearbyRadiusMeters = 10000,
    this.isPrimary = false,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String profileId;
  final String? geoLocationId;

  /// Auto-filled by trigger from `geo_locations.area_id`.
  final String? areaId;

  /// Auto-filled by trigger from the PostGIS point.
  final double? lat;
  final double? lng;

  final ProfileLocationLabel label;

  /// Only meaningful when [label] == [ProfileLocationLabel.custom].
  final String? labelCustom;

  final int nearbyRadiusMeters;
  final bool isPrimary;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory ProfileLocation.fromJson(Map<String, dynamic> json) {
    return ProfileLocation(
      id: json['id'] as String,
      profileId: json['profile_id'] as String,
      geoLocationId: json['geo_location_id'] as String?,
      areaId: json['area_id'] as String?,
      lat: (json['lat'] as num?)?.toDouble(),
      lng: (json['lng'] as num?)?.toDouble(),
      label: ProfileLocationLabel.fromJson(json['label'] as String? ?? 'custom'),
      labelCustom: json['label_custom'] as String?,
      nearbyRadiusMeters:
          (json['nearby_radius_meters'] as int?) ?? 10000,
      isPrimary: (json['is_primary'] as bool?) ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'profile_id': profileId,
        if (geoLocationId != null) 'geo_location_id': geoLocationId,
        if (areaId != null) 'area_id': areaId,
        if (lat != null) 'lat': lat,
        if (lng != null) 'lng': lng,
        'label': label.toJson(),
        if (labelCustom != null) 'label_custom': labelCustom,
        'nearby_radius_meters': nearbyRadiusMeters,
        'is_primary': isPrimary,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  ProfileLocation copyWith({
    String? id,
    String? profileId,
    String? geoLocationId,
    String? areaId,
    double? lat,
    double? lng,
    ProfileLocationLabel? label,
    String? labelCustom,
    int? nearbyRadiusMeters,
    bool? isPrimary,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ProfileLocation(
      id: id ?? this.id,
      profileId: profileId ?? this.profileId,
      geoLocationId: geoLocationId ?? this.geoLocationId,
      areaId: areaId ?? this.areaId,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      label: label ?? this.label,
      labelCustom: labelCustom ?? this.labelCustom,
      nearbyRadiusMeters: nearbyRadiusMeters ?? this.nearbyRadiusMeters,
      isPrimary: isPrimary ?? this.isPrimary,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Human-readable label, falling back to [labelCustom] when applicable.
  String get effectiveLabel =>
      label == ProfileLocationLabel.custom && labelCustom != null
          ? labelCustom!
          : label.displayName;
}
