import 'package:fpdart/fpdart.dart';

import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/data/models/games/venue.dart';
import 'package:dabbler/data/models/games/sport_config.dart';
import '../../domain/repositories/venues_repository.dart';
import '../datasources/venues_remote_data_source.dart';
import 'package:dabbler/data/models/games/venue_model.dart';
import 'package:dabbler/data/models/games/sport_config_model.dart';

// Custom exceptions for venues
class VenueServerException implements Exception {
  final String message;
  VenueServerException(this.message);
}

class VenueCacheException implements Exception {
  final String message;
  VenueCacheException(this.message);
}

class VenueNotFoundException implements Exception {
  final String message;
  VenueNotFoundException(this.message);
}

// Failure types for venues
abstract class VenueFailure extends Failure {
  const VenueFailure(String message) : super(message: message);
}

class VenueServerFailure extends VenueFailure {
  const VenueServerFailure([String? message])
    : super(message ?? 'Venue server error');
}

class VenueCacheFailure extends VenueFailure {
  const VenueCacheFailure([String? message])
    : super(message ?? 'Venue cache error');
}

class VenueNotFoundFailure extends VenueFailure {
  const VenueNotFoundFailure([String? message])
    : super(message ?? 'Venue not found');
}

class UnknownFailure extends VenueFailure {
  const UnknownFailure([String? message])
    : super(message ?? 'Unknown venue error');
}

class VenuesRepositoryImpl implements VenuesRepository {
  final VenuesRemoteDataSource remoteDataSource;

  // In-memory caching
  final Map<String, VenueModel> _venuesCache = {};
  final Map<String, List<VenueModel>> _listCache = {};
  final Map<String, List<SportConfigModel>> _sportsCache = {};
  final Map<String, List<TimeSlotModel>> _availabilityCache = {};
  final Map<String, List<String>> _photosCache = {};
  final Map<String, dynamic> _metadataCache = {};

  // Cache TTL - 5 minutes
  final Map<String, DateTime> _cacheTimestamps = {};
  static const Duration _cacheDuration = Duration(minutes: 5);

  VenuesRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, List<Venue>>> getVenues({
    VenueFilters? filters,
    int page = 1,
    int limit = 20,
    String? sortBy,
    bool ascending = true,
  }) async {
    try {
      final cacheKey = _generateListCacheKey('venues', {
        'filters': filters?.toJson(),
        'page': page,
        'limit': limit,
        'sortBy': sortBy,
        'ascending': ascending,
      });

      // Check cache first
      if (_isListCacheValid(cacheKey)) {
        final cached = _listCache[cacheKey]!;
        return Right(
          cached,
        ); // VenueModel extends Venue, so no conversion needed
      }

      // Fetch from remote
      final venueModels = await remoteDataSource.getVenues(
        filters: filters?.toJson(),
        page: page,
        limit: limit,
        sortBy: sortBy,
        ascending: ascending,
      );

      // Update cache
      _listCache[cacheKey] = venueModels;
      _cacheTimestamps[cacheKey] = DateTime.now();

      // Update individual venue cache
      for (final model in venueModels) {
        _venuesCache[model.id] = model;
        _cacheTimestamps[model.id] = DateTime.now();
      }

      return Right(
        venueModels,
      ); // VenueModel extends Venue, so no conversion needed
    } on VenueServerException catch (e) {
      return Left(VenueServerFailure(e.message));
    } on VenueNotFoundException catch (e) {
      return Left(VenueNotFoundFailure(e.message));
    } catch (e) {
      return Left(UnknownFailure('Failed to get venues: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, Venue>> getVenue(String venueId) async {
    try {
      // Check cache first
      if (_isVenueCacheValid(venueId)) {
        final cached = _venuesCache[venueId]!;
        return Right(
          cached,
        ); // VenueModel extends Venue, so no conversion needed
      }

      // Fetch from remote
      final venueModel = await remoteDataSource.getVenue(venueId);

      // Update cache
      _venuesCache[venueId] = venueModel;
      _cacheTimestamps[venueId] = DateTime.now();

      return Right(
        venueModel,
      ); // VenueModel extends Venue, so no conversion needed
    } on VenueServerException catch (e) {
      return Left(VenueServerFailure(e.message));
    } on VenueNotFoundException catch (e) {
      return Left(VenueNotFoundFailure(e.message));
    } catch (e) {
      return Left(UnknownFailure('Failed to get venue: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, List<Venue>>> searchVenues(
    String query, {
    double? latitude,
    double? longitude,
    double? radiusKm,
    VenueFilters? filters,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final cacheKey = _generateListCacheKey('search', {
        'query': query,
        'latitude': latitude,
        'longitude': longitude,
        'radiusKm': radiusKm,
        'filters': filters?.toJson(),
        'page': page,
        'limit': limit,
      });

      // Check cache first
      if (_isListCacheValid(cacheKey)) {
        final cached = _listCache[cacheKey]!;
        return Right(
          cached,
        ); // VenueModel extends Venue, so no conversion needed
      }

      // Fetch from remote
      final venueModels = await remoteDataSource.searchVenues(
        query,
        latitude: latitude,
        longitude: longitude,
        radiusKm: radiusKm,
        filters: filters?.toJson(),
        page: page,
        limit: limit,
      );

      // Update cache
      _listCache[cacheKey] = venueModels;
      _cacheTimestamps[cacheKey] = DateTime.now();

      // Update individual venue cache
      for (final model in venueModels) {
        _venuesCache[model.id] = model;
        _cacheTimestamps[model.id] = DateTime.now();
      }

      return Right(
        venueModels,
      ); // VenueModel extends Venue, so no conversion needed
    } on VenueServerException catch (e) {
      return Left(VenueServerFailure(e.message));
    } catch (e) {
      return Left(UnknownFailure('Failed to search venues: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, List<Venue>>> getNearbyVenues(
    double latitude,
    double longitude,
    double radiusKm, {
    VenueFilters? filters,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final cacheKey = _generateListCacheKey('nearby', {
        'latitude': latitude,
        'longitude': longitude,
        'radiusKm': radiusKm,
        'filters': filters?.toJson(),
        'page': page,
        'limit': limit,
      });

      // Check cache first
      if (_isListCacheValid(cacheKey)) {
        final cached = _listCache[cacheKey]!;
        return Right(
          cached,
        ); // VenueModel extends Venue, so no conversion needed
      }

      // Fetch from remote
      final venueModels = await remoteDataSource.getNearbyVenues(
        latitude,
        longitude,
        radiusKm,
        filters: filters?.toJson(),
        page: page,
        limit: limit,
      );

      // Update cache
      _listCache[cacheKey] = venueModels;
      _cacheTimestamps[cacheKey] = DateTime.now();

      // Update individual venue cache
      for (final model in venueModels) {
        _venuesCache[model.id] = model;
        _cacheTimestamps[model.id] = DateTime.now();
      }

      return Right(
        venueModels,
      ); // VenueModel extends Venue, so no conversion needed
    } on VenueServerException catch (e) {
      return Left(VenueServerFailure(e.message));
    } catch (e) {
      return Left(
        UnknownFailure('Failed to get nearby venues: ${e.toString()}'),
      );
    }
  }

  @override
  Future<Either<Failure, List<SportConfig>>> getVenueSports(
    String venueId,
  ) async {
    try {
      final cacheKey = 'sports_$venueId';

      // Check cache first
      if (_isSportsCacheValid(cacheKey)) {
        final cached = _sportsCache[cacheKey]!;
        return Right(
          cached,
        ); // SportConfigModel extends SportConfig, so no conversion needed
      }

      // Fetch from remote
      final sportModels = await remoteDataSource.getVenueSports(venueId);

      // Update cache
      _sportsCache[cacheKey] = sportModels;
      _cacheTimestamps[cacheKey] = DateTime.now();

      return Right(
        sportModels,
      ); // SportConfigModel extends SportConfig, so no conversion needed
    } on VenueServerException catch (e) {
      return Left(VenueServerFailure(e.message));
    } on VenueNotFoundException catch (e) {
      return Left(VenueNotFoundFailure(e.message));
    } catch (e) {
      return Left(
        UnknownFailure('Failed to get venue sports: ${e.toString()}'),
      );
    }
  }

  @override
  Future<Either<Failure, List<TimeSlot>>> checkAvailability(
    String venueId,
    DateTime date, {
    String? startTime,
    String? endTime,
    String? sport,
  }) async {
    try {
      final cacheKey = _generateAvailabilityCacheKey(
        venueId,
        date.toIso8601String(),
        startTime,
        endTime,
        sport,
      );

      // Check cache first
      if (_isAvailabilityCacheValid(cacheKey)) {
        final cached = _availabilityCache[cacheKey]!;
        return Right(cached.map((model) => model.toEntity()).toList());
      }

      // Fetch from remote
      final timeSlotModels = await remoteDataSource.checkAvailability(
        venueId,
        date.toIso8601String(),
        startTime: startTime,
        endTime: endTime,
        sport: sport,
      );

      // Update cache
      _availabilityCache[cacheKey] = timeSlotModels;
      _cacheTimestamps[cacheKey] = DateTime.now();

      return Right(timeSlotModels.map((model) => model.toEntity()).toList());
    } on VenueServerException catch (e) {
      return Left(VenueServerFailure(e.message));
    } on VenueNotFoundException catch (e) {
      return Left(VenueNotFoundFailure(e.message));
    } catch (e) {
      return Left(
        UnknownFailure('Failed to check availability: ${e.toString()}'),
      );
    }
  }

  @override
  Future<Either<Failure, List<String>>> getVenuePhotos(String venueId) async {
    try {
      final cacheKey = 'photos_$venueId';

      // Check cache first
      if (_isPhotosCacheValid(cacheKey)) {
        final cached = _photosCache[cacheKey]!;
        return Right(cached);
      }

      // Fetch from remote
      final photos = await remoteDataSource.getVenuePhotos(venueId);

      // Update cache
      _photosCache[cacheKey] = photos;
      _cacheTimestamps[cacheKey] = DateTime.now();

      return Right(photos);
    } on VenueServerException catch (e) {
      return Left(VenueServerFailure(e.message));
    } on VenueNotFoundException catch (e) {
      return Left(VenueNotFoundFailure(e.message));
    } catch (e) {
      return Left(
        UnknownFailure('Failed to get venue photos: ${e.toString()}'),
      );
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> getVenueReviews(
    String venueId, {
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final cacheKey = 'reviews_${venueId}_${page}_$limit';

      // Check cache first
      if (_isMetadataCacheValid(cacheKey)) {
        final cached = _metadataCache[cacheKey]!;
        return Right(Map<String, dynamic>.from(cached));
      }

      // Fetch from remote
      final reviews = await remoteDataSource.getVenueReviews(
        venueId,
        page: page,
        limit: limit,
      );

      // Update cache
      _metadataCache[cacheKey] = reviews;
      _cacheTimestamps[cacheKey] = DateTime.now();

      return Right(reviews);
    } on VenueServerException catch (e) {
      return Left(VenueServerFailure(e.message));
    } on VenueNotFoundException catch (e) {
      return Left(VenueNotFoundFailure(e.message));
    } catch (e) {
      return Left(
        UnknownFailure('Failed to get venue reviews: ${e.toString()}'),
      );
    }
  }

  @override
  Future<Either<Failure, bool>> addVenueReview(
    String venueId,
    String userId,
    double rating,
    String? comment,
  ) async {
    try {
      final success = await remoteDataSource.addVenueReview(
        venueId,
        userId,
        rating,
        comment,
      );

      // Clear related cache entries
      _clearVenueRelatedCache(venueId);

      return Right(success);
    } on VenueServerException catch (e) {
      return Left(VenueServerFailure(e.message));
    } on VenueNotFoundException catch (e) {
      return Left(VenueNotFoundFailure(e.message));
    } catch (e) {
      return Left(
        UnknownFailure('Failed to add venue review: ${e.toString()}'),
      );
    }
  }

  @override
  Future<Either<Failure, bool>> toggleVenueFavorite(
    String venueId,
    String userId,
  ) async {
    try {
      final success = await remoteDataSource.toggleVenueFavorite(
        venueId,
        userId,
      );

      // Clear related cache entries
      _clearUserRelatedCache(userId);

      return Right(success);
    } on VenueServerException catch (e) {
      return Left(VenueServerFailure(e.message));
    } on VenueNotFoundException catch (e) {
      return Left(VenueNotFoundFailure(e.message));
    } catch (e) {
      return Left(
        UnknownFailure('Failed to toggle venue favorite: ${e.toString()}'),
      );
    }
  }

  // Add missing methods from the interface
  @override
  Future<Either<Failure, List<Venue>>> getFeaturedVenues({
    int page = 1,
    int limit = 10,
  }) async {
    try {
      final cacheKey = 'featured_${page}_$limit';

      // Check cache first
      if (_isListCacheValid(cacheKey)) {
        final cached = _listCache[cacheKey]!;
        return Right(cached);
      }

      // Fetch from remote
      final venueModels = await remoteDataSource.getFeaturedVenues(
        page: page,
        limit: limit,
      );

      // Update cache
      _listCache[cacheKey] = venueModels;
      _cacheTimestamps[cacheKey] = DateTime.now();

      return Right(venueModels);
    } on VenueServerException catch (e) {
      return Left(VenueServerFailure(e.message));
    } catch (e) {
      return Left(
        UnknownFailure('Failed to get featured venues: ${e.toString()}'),
      );
    }
  }

  @override
  Future<Either<Failure, List<Venue>>> getVenuesBySport(
    String sportType, {
    double? latitude,
    double? longitude,
    double? radiusKm,
    VenueFilters? filters,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final cacheKey = _generateListCacheKey('sport_$sportType', {
        'latitude': latitude,
        'longitude': longitude,
        'radiusKm': radiusKm,
        'filters': filters?.toJson(),
        'page': page,
        'limit': limit,
      });

      // Check cache first
      if (_isListCacheValid(cacheKey)) {
        final cached = _listCache[cacheKey]!;
        return Right(cached);
      }

      // Fetch from remote
      final venueModels = await remoteDataSource.getVenuesBySport(
        sportType,
        latitude: latitude,
        longitude: longitude,
        radiusKm: radiusKm,
        filters: filters?.toJson(),
        page: page,
        limit: limit,
      );

      // Update cache
      _listCache[cacheKey] = venueModels;
      _cacheTimestamps[cacheKey] = DateTime.now();

      return Right(venueModels);
    } on VenueServerException catch (e) {
      return Left(VenueServerFailure(e.message));
    } catch (e) {
      return Left(
        UnknownFailure('Failed to get venues by sport: ${e.toString()}'),
      );
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> getVenueOperatingHours(
    String venueId,
  ) async {
    try {
      final cacheKey = 'hours_$venueId';

      // Check cache first
      if (_isMetadataCacheValid(cacheKey)) {
        final cached = _metadataCache[cacheKey]!;
        return Right(Map<String, dynamic>.from(cached));
      }

      // Fetch from remote
      final hours = await remoteDataSource.getVenueOperatingHours(venueId);

      // Update cache
      _metadataCache[cacheKey] = hours;
      _cacheTimestamps[cacheKey] = DateTime.now();

      return Right(hours);
    } on VenueServerException catch (e) {
      return Left(VenueServerFailure(e.message));
    } on VenueNotFoundException catch (e) {
      return Left(VenueNotFoundFailure(e.message));
    } catch (e) {
      return Left(
        UnknownFailure('Failed to get venue operating hours: ${e.toString()}'),
      );
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> getVenuePricing(
    String venueId, {
    String? sport,
    DateTime? date,
  }) async {
    try {
      final cacheKey =
          'pricing_${venueId}_${sport ?? 'any'}_${date?.toIso8601String() ?? 'any'}';

      // Check cache first
      if (_isMetadataCacheValid(cacheKey)) {
        final cached = _metadataCache[cacheKey]!;
        return Right(Map<String, dynamic>.from(cached));
      }

      // Fetch from remote
      final pricing = await remoteDataSource.getVenuePricing(
        venueId,
        sport: sport,
        date: date?.toIso8601String(),
      );

      // Update cache
      _metadataCache[cacheKey] = pricing;
      _cacheTimestamps[cacheKey] = DateTime.now();

      return Right(pricing);
    } on VenueServerException catch (e) {
      return Left(VenueServerFailure(e.message));
    } on VenueNotFoundException catch (e) {
      return Left(VenueNotFoundFailure(e.message));
    } catch (e) {
      return Left(
        UnknownFailure('Failed to get venue pricing: ${e.toString()}'),
      );
    }
  }

  @override
  Future<Either<Failure, bool>> checkVenueAmenities(
    String venueId,
    List<String> requiredAmenities,
  ) async {
    try {
      final success = await remoteDataSource.checkVenueAmenities(
        venueId,
        requiredAmenities,
      );

      return Right(success);
    } on VenueServerException catch (e) {
      return Left(VenueServerFailure(e.message));
    } on VenueNotFoundException catch (e) {
      return Left(VenueNotFoundFailure(e.message));
    } catch (e) {
      return Left(
        UnknownFailure('Failed to check venue amenities: ${e.toString()}'),
      );
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> getVenueContactInfo(
    String venueId,
  ) async {
    try {
      final cacheKey = 'contact_$venueId';

      // Check cache first
      if (_isMetadataCacheValid(cacheKey)) {
        final cached = _metadataCache[cacheKey]!;
        return Right(Map<String, dynamic>.from(cached));
      }

      // Fetch from remote
      final contactInfo = await remoteDataSource.getVenueContactInfo(venueId);

      // Update cache
      _metadataCache[cacheKey] = contactInfo;
      _cacheTimestamps[cacheKey] = DateTime.now();

      return Right(contactInfo);
    } on VenueServerException catch (e) {
      return Left(VenueServerFailure(e.message));
    } on VenueNotFoundException catch (e) {
      return Left(VenueNotFoundFailure(e.message));
    } catch (e) {
      return Left(
        UnknownFailure('Failed to get venue contact info: ${e.toString()}'),
      );
    }
  }

  @override
  Future<Either<Failure, List<Venue>>> getUserVenues(
    String userId, {
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final cacheKey = 'user_venues_${userId}_${page}_$limit';

      // Check cache first
      if (_isListCacheValid(cacheKey)) {
        final cached = _listCache[cacheKey]!;
        return Right(cached);
      }

      // Fetch from remote
      final venueModels = await remoteDataSource.getUserVenues(
        userId,
        page: page,
        limit: limit,
      );

      // Update cache
      _listCache[cacheKey] = venueModels;
      _cacheTimestamps[cacheKey] = DateTime.now();

      return Right(venueModels);
    } on VenueServerException catch (e) {
      return Left(VenueServerFailure(e.message));
    } catch (e) {
      return Left(UnknownFailure('Failed to get user venues: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, bool>> reportVenue(
    String venueId,
    String reason,
    String? description,
  ) async {
    try {
      final success = await remoteDataSource.reportVenue(
        venueId,
        reason,
        description,
      );

      return Right(success);
    } on VenueServerException catch (e) {
      return Left(VenueServerFailure(e.message));
    } on VenueNotFoundException catch (e) {
      return Left(VenueNotFoundFailure(e.message));
    } catch (e) {
      return Left(UnknownFailure('Failed to report venue: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, List<Venue>>> getFavoriteVenues(
    String userId, {
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final cacheKey = 'favorites_${userId}_${page}_$limit';

      // Check cache first
      if (_isListCacheValid(cacheKey)) {
        final cached = _listCache[cacheKey]!;
        return Right(cached);
      }

      // Fetch from remote
      final venueModels = await remoteDataSource.getFavoriteVenues(
        userId,
        page: page,
        limit: limit,
      );

      // Update cache
      _listCache[cacheKey] = venueModels;
      _cacheTimestamps[cacheKey] = DateTime.now();

      return Right(venueModels);
    } on VenueServerException catch (e) {
      return Left(VenueServerFailure(e.message));
    } catch (e) {
      return Left(
        UnknownFailure('Failed to get favorite venues: ${e.toString()}'),
      );
    }
  }

  @override
  Future<Either<Failure, List<Map<String, dynamic>>>> getVenueBookingHistory(
    String venueId, {
    DateTime? startDate,
    DateTime? endDate,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final cacheKey =
          'history_${venueId}_${startDate?.toIso8601String() ?? 'any'}_${endDate?.toIso8601String() ?? 'any'}_${page}_$limit';

      // Check cache first
      if (_isMetadataCacheValid(cacheKey)) {
        final cached = _metadataCache[cacheKey]!;
        return Right(List<Map<String, dynamic>>.from(cached));
      }

      // Fetch from remote
      final history = await remoteDataSource.getVenueBookingHistory(
        venueId,
        startDate: startDate?.toIso8601String(),
        endDate: endDate?.toIso8601String(),
        page: page,
        limit: limit,
      );

      // Update cache
      _metadataCache[cacheKey] = history;
      _cacheTimestamps[cacheKey] = DateTime.now();

      return Right(history);
    } on VenueServerException catch (e) {
      return Left(VenueServerFailure(e.message));
    } on VenueNotFoundException catch (e) {
      return Left(VenueNotFoundFailure(e.message));
    } catch (e) {
      return Left(
        UnknownFailure('Failed to get venue booking history: ${e.toString()}'),
      );
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> getVenueUtilizationStats(
    String venueId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final cacheKey =
          'utilization_${venueId}_${startDate?.toIso8601String() ?? 'any'}_${endDate?.toIso8601String() ?? 'any'}';

      // Check cache first
      if (_isMetadataCacheValid(cacheKey)) {
        final cached = _metadataCache[cacheKey]!;
        return Right(Map<String, dynamic>.from(cached));
      }

      // Fetch from remote
      final stats = await remoteDataSource.getVenueUtilizationStats(
        venueId,
        startDate: startDate?.toIso8601String(),
        endDate: endDate?.toIso8601String(),
      );

      // Update cache
      _metadataCache[cacheKey] = stats;
      _cacheTimestamps[cacheKey] = DateTime.now();

      return Right(stats);
    } on VenueServerException catch (e) {
      return Left(VenueServerFailure(e.message));
    } on VenueNotFoundException catch (e) {
      return Left(VenueNotFoundFailure(e.message));
    } catch (e) {
      return Left(
        UnknownFailure(
          'Failed to get venue utilization stats: ${e.toString()}',
        ),
      );
    }
  }

  @override
  Future<Either<Failure, List<Venue>>> getRecommendedVenues(
    String userId, {
    double? latitude,
    double? longitude,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final cacheKey =
          'recommended_${userId}_${latitude ?? 'any'}_${longitude ?? 'any'}_${page}_$limit';

      // Check cache first
      if (_isListCacheValid(cacheKey)) {
        final cached = _listCache[cacheKey]!;
        return Right(cached);
      }

      // Fetch from remote
      final venueModels = await remoteDataSource.getRecommendedVenues(
        userId,
        latitude: latitude,
        longitude: longitude,
        page: page,
        limit: limit,
      );

      // Update cache
      _listCache[cacheKey] = venueModels;
      _cacheTimestamps[cacheKey] = DateTime.now();

      return Right(venueModels);
    } on VenueServerException catch (e) {
      return Left(VenueServerFailure(e.message));
    } catch (e) {
      return Left(
        UnknownFailure('Failed to get recommended venues: ${e.toString()}'),
      );
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> getVenuePeakHours(
    String venueId,
  ) async {
    try {
      final cacheKey = 'peak_hours_$venueId';

      // Check cache first
      if (_isMetadataCacheValid(cacheKey)) {
        final cached = _metadataCache[cacheKey]!;
        return Right(Map<String, dynamic>.from(cached));
      }

      // Fetch from remote
      final peakHours = await remoteDataSource.getVenuePeakHours(venueId);

      // Update cache
      _metadataCache[cacheKey] = peakHours;
      _cacheTimestamps[cacheKey] = DateTime.now();

      return Right(peakHours);
    } on VenueServerException catch (e) {
      return Left(VenueServerFailure(e.message));
    } on VenueNotFoundException catch (e) {
      return Left(VenueNotFoundFailure(e.message));
    } catch (e) {
      return Left(
        UnknownFailure('Failed to get venue peak hours: ${e.toString()}'),
      );
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> checkVenueCapacity(
    String venueId,
    DateTime dateTime,
    String sport,
  ) async {
    try {
      final cacheKey =
          'capacity_${venueId}_${dateTime.toIso8601String()}_$sport';

      // Check cache first
      if (_isMetadataCacheValid(cacheKey)) {
        final cached = _metadataCache[cacheKey]!;
        return Right(Map<String, dynamic>.from(cached));
      }

      // Fetch from remote
      final capacity = await remoteDataSource.checkVenueCapacity(
        venueId,
        dateTime.toIso8601String(),
        sport,
      );

      // Update cache
      _metadataCache[cacheKey] = capacity;
      _cacheTimestamps[cacheKey] = DateTime.now();

      return Right(capacity);
    } on VenueServerException catch (e) {
      return Left(VenueServerFailure(e.message));
    } on VenueNotFoundException catch (e) {
      return Left(VenueNotFoundFailure(e.message));
    } catch (e) {
      return Left(
        UnknownFailure('Failed to check venue capacity: ${e.toString()}'),
      );
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> getVenueWeatherSuitability(
    String venueId,
  ) async {
    try {
      final cacheKey = 'weather_$venueId';

      // Check cache first
      if (_isMetadataCacheValid(cacheKey)) {
        final cached = _metadataCache[cacheKey]!;
        return Right(Map<String, dynamic>.from(cached));
      }

      // Fetch from remote
      final weather = await remoteDataSource.getVenueWeatherSuitability(
        venueId,
      );

      // Update cache
      _metadataCache[cacheKey] = weather;
      _cacheTimestamps[cacheKey] = DateTime.now();

      return Right(weather);
    } on VenueServerException catch (e) {
      return Left(VenueServerFailure(e.message));
    } on VenueNotFoundException catch (e) {
      return Left(VenueNotFoundFailure(e.message));
    } catch (e) {
      return Left(
        UnknownFailure(
          'Failed to get venue weather suitability: ${e.toString()}',
        ),
      );
    }
  }

  @override
  Future<Either<Failure, List<Venue>>> getVenuesWithPromotions({
    double? latitude,
    double? longitude,
    double? radiusKm,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final cacheKey = _generateListCacheKey('promotions', {
        'latitude': latitude,
        'longitude': longitude,
        'radiusKm': radiusKm,
        'page': page,
        'limit': limit,
      });

      // Check cache first
      if (_isListCacheValid(cacheKey)) {
        final cached = _listCache[cacheKey]!;
        return Right(cached);
      }

      // Fetch from remote
      final venueModels = await remoteDataSource.getVenuesWithPromotions(
        latitude: latitude,
        longitude: longitude,
        radiusKm: radiusKm,
        page: page,
        limit: limit,
      );

      // Update cache
      _listCache[cacheKey] = venueModels;
      _cacheTimestamps[cacheKey] = DateTime.now();

      return Right(venueModels);
    } on VenueServerException catch (e) {
      return Left(VenueServerFailure(e.message));
    } catch (e) {
      return Left(
        UnknownFailure('Failed to get venues with promotions: ${e.toString()}'),
      );
    }
  }

  // Cache validation methods
  bool _isVenueCacheValid(String venueId) {
    final timestamp = _cacheTimestamps[venueId];
    if (timestamp == null) return false;
    return DateTime.now().difference(timestamp) < _cacheDuration &&
        _venuesCache.containsKey(venueId);
  }

  bool _isListCacheValid(String cacheKey) {
    final timestamp = _cacheTimestamps[cacheKey];
    if (timestamp == null) return false;
    return DateTime.now().difference(timestamp) < _cacheDuration &&
        _listCache.containsKey(cacheKey);
  }

  bool _isSportsCacheValid(String cacheKey) {
    final timestamp = _cacheTimestamps[cacheKey];
    if (timestamp == null) return false;
    return DateTime.now().difference(timestamp) < _cacheDuration &&
        _sportsCache.containsKey(cacheKey);
  }

  bool _isAvailabilityCacheValid(String cacheKey) {
    final timestamp = _cacheTimestamps[cacheKey];
    if (timestamp == null) return false;
    return DateTime.now().difference(timestamp) < _cacheDuration &&
        _availabilityCache.containsKey(cacheKey);
  }

  bool _isPhotosCacheValid(String cacheKey) {
    final timestamp = _cacheTimestamps[cacheKey];
    if (timestamp == null) return false;
    return DateTime.now().difference(timestamp) < _cacheDuration &&
        _photosCache.containsKey(cacheKey);
  }

  bool _isMetadataCacheValid(String cacheKey) {
    final timestamp = _cacheTimestamps[cacheKey];
    if (timestamp == null) return false;
    return DateTime.now().difference(timestamp) < _cacheDuration &&
        _metadataCache.containsKey(cacheKey);
  }

  // Cache key generation
  String _generateListCacheKey(String prefix, Map<String, dynamic> params) {
    final sortedKeys = params.keys.toList()..sort();
    final keyParts = sortedKeys.map((key) => '$key:${params[key]}').join('|');
    return '${prefix}_$keyParts';
  }

  String _generateAvailabilityCacheKey(
    String venueId,
    String date,
    String? startTime,
    String? endTime,
    String? sport,
  ) {
    return 'availability_${venueId}_${date}_${startTime ?? 'any'}_${endTime ?? 'any'}_${sport ?? 'any'}';
  }

  // Cache clearing methods
  void _clearVenueRelatedCache(String venueId) {
    // Clear venue cache
    _venuesCache.remove(venueId);
    _cacheTimestamps.remove(venueId);

    // Clear related caches
    final keysToRemove = <String>[];
    for (final key in _cacheTimestamps.keys) {
      if (key.contains(venueId)) {
        keysToRemove.add(key);
      }
    }

    for (final key in keysToRemove) {
      _cacheTimestamps.remove(key);
      _listCache.remove(key);
      _sportsCache.remove(key);
      _availabilityCache.remove(key);
      _photosCache.remove(key);
      _metadataCache.remove(key);
    }
  }

  void _clearUserRelatedCache(String userId) {
    final keysToRemove = <String>[];
    for (final key in _cacheTimestamps.keys) {
      if (key.contains(userId) || key.contains('favorites')) {
        keysToRemove.add(key);
      }
    }

    for (final key in keysToRemove) {
      _cacheTimestamps.remove(key);
      _listCache.remove(key);
      _metadataCache.remove(key);
    }
  }

  void clearAllCache() {
    _venuesCache.clear();
    _listCache.clear();
    _sportsCache.clear();
    _availabilityCache.clear();
    _photosCache.clear();
    _metadataCache.clear();
    _cacheTimestamps.clear();
  }
}

// Extension methods for TimeSlotModel
extension TimeSlotModelExt on TimeSlotModel {
  TimeSlot toEntity() {
    return TimeSlot(
      startTime: startTime,
      endTime: endTime,
      isAvailable: isAvailable,
      courtNumber: courtNumber,
      price: price,
      notes: notes,
    );
  }
}
