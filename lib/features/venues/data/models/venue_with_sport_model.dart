import 'package:freezed_annotation/freezed_annotation.dart';

part 'venue_with_sport_model.freezed.dart';
part 'venue_with_sport_model.g.dart';

/// Model representing a row from v_venues_with_sports view
/// Each row contains venue data + one supported sport
@freezed
class VenueWithSportModel with _$VenueWithSportModel {
  // ignore_for_file: invalid_annotation_target
  const factory VenueWithSportModel({
    required String id,
    @JsonKey(name: 'sport_id') required String sportId,
    @JsonKey(name: 'name_en') required String nameEn,
    @JsonKey(name: 'name_ar') String? nameAr,
    required String city,
    String? area,
    @JsonKey(name: 'is_active') @Default(true) bool isActive,
    @JsonKey(name: 'is_indoor') bool? isIndoor,
    @JsonKey(name: 'price_per_hour') double? pricePerHour,
    double? latitude,
    double? longitude,
    String? address,
    @JsonKey(name: 'phone_number') String? phoneNumber,
    String? description,
    @Default([]) List<String> amenities,
    @JsonKey(name: 'composite_score') double? compositeScore,
    @JsonKey(name: 'created_at') DateTime? createdAt,
  }) = _VenueWithSportModel;

  factory VenueWithSportModel.fromJson(Map<String, dynamic> json) =>
      _$VenueWithSportModelFromJson(json);
}
