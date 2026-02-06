import 'package:fpdart/fpdart.dart';
import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/data/models/games/venue.dart';
import 'package:dabbler/data/models/games/sport_config.dart';

/// Time slot model for availability checking
class TimeSlot {
  final String startTime;
  final String endTime;
  final bool isAvailable;
  final String? courtNumber;
  final double? price;
  final String? notes;

  const TimeSlot({
    required this.startTime,
    required this.endTime,
    required this.isAvailable,
    this.courtNumber,
    this.price,
    this.notes,
  });
}

/// Venue filter options
class VenueFilters {
  final List<String>? sports;
  final double? minPrice;
  final double? maxPrice;
  final List<String>? amenities;
  final double? minRating;
  final bool? hasParking;
  final bool? isIndoor;
  final bool? isOutdoor;
  final String? priceRange; // 'budget', 'mid-range', 'premium'

  const VenueFilters({
    this.sports,
    this.minPrice,
    this.maxPrice,
    this.amenities,
    this.minRating,
    this.hasParking,
    this.isIndoor,
    this.isOutdoor,
    this.priceRange,
  });

  Map<String, dynamic> toJson() {
    return {
      if (sports != null) 'sports': sports,
      if (minPrice != null) 'min_price': minPrice,
      if (maxPrice != null) 'max_price': maxPrice,
      if (amenities != null) 'amenities': amenities,
      if (minRating != null) 'min_rating': minRating,
      if (hasParking != null) 'has_parking': hasParking,
      if (isIndoor != null) 'is_indoor': isIndoor,
      if (isOutdoor != null) 'is_outdoor': isOutdoor,
      if (priceRange != null) 'price_range': priceRange,
    };
  }
}

abstract class VenuesRepository {
  /// Retrieves a list of venues based on filters
  Future<Either<Failure, List<Venue>>> getVenues({
    VenueFilters? filters,
    int page = 1,
    int limit = 20,
    String? sortBy,
    bool ascending = true,
  });

  /// Retrieves a single venue by its ID
  Future<Either<Failure, Venue>> getVenue(String venueId);

  /// Searches venues based on query string and location
  Future<Either<Failure, List<Venue>>> searchVenues(
    String query, {
    double? latitude,
    double? longitude,
    double? radiusKm,
    VenueFilters? filters,
    int page = 1,
    int limit = 20,
  });

  /// Gets venues near a specific location
  Future<Either<Failure, List<Venue>>> getNearbyVenues(
    double latitude,
    double longitude,
    double radiusKm, {
    VenueFilters? filters,
    int page = 1,
    int limit = 20,
  });

  /// Gets sports available at a specific venue
  Future<Either<Failure, List<SportConfig>>> getVenueSports(String venueId);

  /// Checks availability for a venue on a specific date and time
  Future<Either<Failure, List<TimeSlot>>> checkAvailability(
    String venueId,
    DateTime date, {
    String? startTime,
    String? endTime,
    String? sport,
  });

  /// Gets featured/popular venues
  Future<Either<Failure, List<Venue>>> getFeaturedVenues({
    int page = 1,
    int limit = 10,
  });

  /// Gets venues by sport type
  Future<Either<Failure, List<Venue>>> getVenuesBySport(
    String sportType, {
    double? latitude,
    double? longitude,
    double? radiusKm,
    VenueFilters? filters,
    int page = 1,
    int limit = 20,
  });

  /// Gets venue reviews and ratings
  Future<Either<Failure, Map<String, dynamic>>> getVenueReviews(
    String venueId, {
    int page = 1,
    int limit = 20,
  });

  /// Adds a review for a venue
  Future<Either<Failure, bool>> addVenueReview(
    String venueId,
    String userId,
    double rating,
    String? comment,
  );

  /// Gets venue photos
  Future<Either<Failure, List<String>>> getVenuePhotos(String venueId);

  /// Gets venue operating hours
  Future<Either<Failure, Map<String, dynamic>>> getVenueOperatingHours(
    String venueId,
  );

  /// Gets pricing information for a venue
  Future<Either<Failure, Map<String, dynamic>>> getVenuePricing(
    String venueId, {
    String? sport,
    DateTime? date,
  });

  /// Checks if venue has specific amenities
  Future<Either<Failure, bool>> checkVenueAmenities(
    String venueId,
    List<String> requiredAmenities,
  );

  /// Gets venue contact information
  Future<Either<Failure, Map<String, dynamic>>> getVenueContactInfo(
    String venueId,
  );

  /// Gets venues owned/managed by a user
  Future<Either<Failure, List<Venue>>> getUserVenues(
    String userId, {
    int page = 1,
    int limit = 20,
  });

  /// Reports a venue for issues
  Future<Either<Failure, bool>> reportVenue(
    String venueId,
    String reason,
    String? description,
  );

  /// Marks venue as favorite for a user
  Future<Either<Failure, bool>> toggleVenueFavorite(
    String venueId,
    String userId,
  );

  /// Gets user's favorite venues
  Future<Either<Failure, List<Venue>>> getFavoriteVenues(
    String userId, {
    int page = 1,
    int limit = 20,
  });

  /// Gets venue booking history
  Future<Either<Failure, List<Map<String, dynamic>>>> getVenueBookingHistory(
    String venueId, {
    DateTime? startDate,
    DateTime? endDate,
    int page = 1,
    int limit = 20,
  });

  /// Gets venue utilization statistics
  Future<Either<Failure, Map<String, dynamic>>> getVenueUtilizationStats(
    String venueId, {
    DateTime? startDate,
    DateTime? endDate,
  });

  /// Gets recommended venues for a user
  Future<Either<Failure, List<Venue>>> getRecommendedVenues(
    String userId, {
    double? latitude,
    double? longitude,
    int page = 1,
    int limit = 20,
  });

  /// Gets venue peak and off-peak hours
  Future<Either<Failure, Map<String, dynamic>>> getVenuePeakHours(
    String venueId,
  );

  /// Checks venue capacity for a specific time
  Future<Either<Failure, Map<String, dynamic>>> checkVenueCapacity(
    String venueId,
    DateTime dateTime,
    String sport,
  );

  /// Gets venue weather suitability info
  Future<Either<Failure, Map<String, dynamic>>> getVenueWeatherSuitability(
    String venueId,
  );

  /// Gets venues with current promotions/discounts
  Future<Either<Failure, List<Venue>>> getVenuesWithPromotions({
    double? latitude,
    double? longitude,
    double? radiusKm,
    int page = 1,
    int limit = 20,
  });
}
