import 'package:freezed_annotation/freezed_annotation.dart';

part 'place.freezed.dart';
part 'place.g.dart';

/// A place result from Mapbox Search, used for the "Add location" feature
/// on posts (similar to Instagram/Threads).
///
/// This is a local UI model — it is NOT persisted to Supabase directly.
/// When a place is selected, [name] is stored as `location_tag_id` on the
/// post, and [latitude]/[longitude] populate `geo_lat`/`geo_lng`.
@freezed
class Place with _$Place {
  const Place._();

  const factory Place({
    /// Mapbox ID used to retrieve full details.
    required String id,

    /// Human-readable place name (e.g. "Blue Bottle Coffee").
    required String name,

    /// Full formatted address string.
    @JsonKey(name: 'full_address') String? fullAddress,

    /// POI category (e.g. "cafe", "park").
    String? category,

    /// Resolved latitude (may be null before detail retrieval).
    double? latitude,

    /// Resolved longitude (may be null before detail retrieval).
    double? longitude,
  }) = _Place;

  factory Place.fromJson(Map<String, dynamic> json) => _$PlaceFromJson(json);

  /// Short display label for chips: "📍 Blue Bottle Coffee".
  String get displayLabel => '📍 $name';
}
