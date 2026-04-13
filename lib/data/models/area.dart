import 'package:freezed_annotation/freezed_annotation.dart';

part 'area.freezed.dart';
part 'area.g.dart';

/// A geographic area from the `areas` table.
///
/// Areas are server-managed regions used for location grouping.
/// Every post is assigned an area via the server-side trigger.
@freezed
class Area with _$Area {
  const factory Area({
    required String id,
    required String name,
    required String district,
    required String city,
    required String country,
    @JsonKey(name: 'center_lat') required double centerLat,
    @JsonKey(name: 'center_lng') required double centerLng,
    @JsonKey(name: 'is_active') @Default(true) bool isActive,
    @JsonKey(name: 'is_verified') @Default(false) bool isVerified,

    /// Only populated in nearby-query results (from resolve_nearest_area RPC).
    @JsonKey(name: 'distance_m') double? distanceM,
  }) = _Area;

  factory Area.fromJson(Map<String, dynamic> json) => _$AreaFromJson(json);
}
