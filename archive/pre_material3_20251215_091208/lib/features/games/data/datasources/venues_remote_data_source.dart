import 'package:dabbler/data/models/games/venue_model.dart';
import 'package:dabbler/data/models/games/sport_config_model.dart';

class TimeSlotModel {
  final String startTime;
  final String endTime;
  final bool isAvailable;
  final String? courtNumber;
  final double? price;
  final String? notes;

  const TimeSlotModel({
    required this.startTime,
    required this.endTime,
    required this.isAvailable,
    this.courtNumber,
    this.price,
    this.notes,
  });

  factory TimeSlotModel.fromJson(Map<String, dynamic> json) {
    return TimeSlotModel(
      startTime: json['start_time'] as String,
      endTime: json['end_time'] as String,
      isAvailable: json['is_available'] as bool,
      courtNumber: json['court_number'] as String?,
      price: (json['price'] as num?)?.toDouble(),
      notes: json['notes'] as String?,
    );
  }
}

abstract class VenuesRemoteDataSource {
  /// Retrieves a list of venues from the remote server
  Future<List<VenueModel>> getVenues({
    Map<String, dynamic>? filters,
    int page = 1,
    int limit = 20,
    String? sortBy,
    bool ascending = true,
  });

  /// Retrieves a single venue from the remote server
  Future<VenueModel> getVenue(String venueId);

  /// Searches venues based on query string and location
  Future<List<VenueModel>> searchVenues(
    String query, {
    double? latitude,
    double? longitude,
    double? radiusKm,
    Map<String, dynamic>? filters,
    int page = 1,
    int limit = 20,
  });

  /// Gets venues near a specific location
  Future<List<VenueModel>> getNearbyVenues(
    double latitude,
    double longitude,
    double radiusKm, {
    Map<String, dynamic>? filters,
    int page = 1,
    int limit = 20,
  });

  /// Gets sports available at a specific venue
  Future<List<SportConfigModel>> getVenueSports(String venueId);

  /// Checks availability for a venue on a specific date and time
  Future<List<TimeSlotModel>> checkAvailability(
    String venueId,
    String date, {
    String? startTime,
    String? endTime,
    String? sport,
  });

  /// Gets featured/popular venues
  Future<List<VenueModel>> getFeaturedVenues({int page = 1, int limit = 10});

  /// Gets venues by sport type
  Future<List<VenueModel>> getVenuesBySport(
    String sportType, {
    double? latitude,
    double? longitude,
    double? radiusKm,
    Map<String, dynamic>? filters,
    int page = 1,
    int limit = 20,
  });

  /// Gets venue reviews and ratings
  Future<Map<String, dynamic>> getVenueReviews(
    String venueId, {
    int page = 1,
    int limit = 20,
  });

  /// Adds a review for a venue
  Future<bool> addVenueReview(
    String venueId,
    String userId,
    double rating,
    String? comment,
  );

  /// Gets venue photos
  Future<List<String>> getVenuePhotos(String venueId);

  /// Gets venue operating hours
  Future<Map<String, dynamic>> getVenueOperatingHours(String venueId);

  /// Gets pricing information for a venue
  Future<Map<String, dynamic>> getVenuePricing(
    String venueId, {
    String? sport,
    String? date,
  });

  /// Checks if venue has specific amenities
  Future<bool> checkVenueAmenities(
    String venueId,
    List<String> requiredAmenities,
  );

  /// Gets venue contact information
  Future<Map<String, dynamic>> getVenueContactInfo(String venueId);

  /// Gets venues owned/managed by a user
  Future<List<VenueModel>> getUserVenues(
    String userId, {
    int page = 1,
    int limit = 20,
  });

  /// Reports a venue for issues
  Future<bool> reportVenue(String venueId, String reason, String? description);

  /// Toggles venue favorite status
  Future<bool> toggleVenueFavorite(String venueId, String userId);

  /// Gets user's favorite venues
  Future<List<VenueModel>> getFavoriteVenues(
    String userId, {
    int page = 1,
    int limit = 20,
  });

  /// Gets venue booking history
  Future<List<Map<String, dynamic>>> getVenueBookingHistory(
    String venueId, {
    String? startDate,
    String? endDate,
    int page = 1,
    int limit = 20,
  });

  /// Gets venue utilization statistics
  Future<Map<String, dynamic>> getVenueUtilizationStats(
    String venueId, {
    String? startDate,
    String? endDate,
  });

  /// Gets recommended venues for a user
  Future<List<VenueModel>> getRecommendedVenues(
    String userId, {
    double? latitude,
    double? longitude,
    int page = 1,
    int limit = 20,
  });

  /// Gets venue peak and off-peak hours
  Future<Map<String, dynamic>> getVenuePeakHours(String venueId);

  /// Checks venue capacity for a specific time
  Future<Map<String, dynamic>> checkVenueCapacity(
    String venueId,
    String dateTime,
    String sport,
  );

  /// Gets venue weather suitability info
  Future<Map<String, dynamic>> getVenueWeatherSuitability(String venueId);

  /// Gets venues with current promotions/discounts
  Future<List<VenueModel>> getVenuesWithPromotions({
    double? latitude,
    double? longitude,
    double? radiusKm,
    int page = 1,
    int limit = 20,
  });
}
