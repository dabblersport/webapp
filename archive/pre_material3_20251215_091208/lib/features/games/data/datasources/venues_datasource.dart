import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:dabbler/data/models/games/venue_model.dart';
import 'package:dabbler/data/models/games/sport_config_model.dart';
import 'venues_remote_data_source.dart';

// Custom exceptions for venues
class VenueServerException implements Exception {
  final String message;
  VenueServerException(this.message);
}

class VenueNotFoundException implements Exception {
  final String message;
  VenueNotFoundException(this.message);
}

class VenueUnavailableException implements Exception {
  final String message;
  VenueUnavailableException(this.message);
}

class SupabaseVenuesDataSource implements VenuesRemoteDataSource {
  final SupabaseClient _supabaseClient;

  // In-memory cache for frequently accessed venues
  final Map<String, VenueModel> _venueCache = {};
  final Map<String, List<VenueModel>> _listCache = {};
  final Map<String, DateTime> _cacheTimestamps = {};
  static const Duration _cacheDuration = Duration(minutes: 10);

  SupabaseVenuesDataSource(this._supabaseClient);

  @override
  Future<List<VenueModel>> getVenues({
    Map<String, dynamic>? filters,
    int page = 1,
    int limit = 20,
    String? sortBy,
    bool ascending = true,
  }) async {
    try {
      final cacheKey = 'venues_${filters.hashCode}_${page}_$limit';

      // Check cache first
      if (_isCacheValid(cacheKey)) {
        return _listCache[cacheKey]!;
      }

      // Build select query with joins to related tables
      // Use left joins so venues without spaces/photos still appear
      var query = _supabaseClient.from('venues').select('''
        *,
        venue_spaces(sport, name_en, is_active),
        venue_rating_aggregate(composite_score, event_count),
        venue_photos(url, sort_order)
      ''');

      // Apply filters
      if (filters != null) {
        // Sports filtering - filter venues that have spaces with the sport
        final sports = filters['sports'] ?? filters['sport'];
        if (sports != null) {
          // For sport filtering, we'll filter client-side after fetching
          // or use a subquery approach - simplified for now
        }

        if (filters['city'] != null) {
          query = query.eq('city', filters['city']);
        }
        if (filters['amenities'] != null && filters['amenities'] is List) {
          final amenitiesList = filters['amenities'] as List;
          if (amenitiesList.isNotEmpty) {
            query = query.overlaps('amenities', amenitiesList);
          }
        }
        // Rating filtering will be done client-side after parsing
      }

      final response = await query
          .eq('is_active', true) // Only show active venues
          .order(
            sortBy ?? 'name_en',
            ascending: ascending,
          ) // Use name_en for alphabetical sorting
          .range((page - 1) * limit, page * limit - 1);

      if (response.isNotEmpty) {}

      var venues = response
          .map<VenueModel>((json) => VenueModel.fromJson(json))
          .toList();

      // Filter by sport client-side if filter was provided
      if (filters != null) {
        final sports = filters['sports'] ?? filters['sport'];
        if (sports != null) {
          final sportList = sports is List ? sports : [sports];
          venues = venues.where((venue) {
            return venue.supportedSports.any(
              (sport) => sportList.any(
                (filterSport) =>
                    sport.toLowerCase() == filterSport.toString().toLowerCase(),
              ),
            );
          }).toList();
        }

        // Filter by rating if provided
        if (filters['min_rating'] != null) {
          final minRating = filters['min_rating'] as num;
          venues = venues
              .where((venue) => venue.rating >= minRating.toDouble())
              .toList();
        }
      }

      // Update cache
      _listCache[cacheKey] = venues;
      _cacheTimestamps[cacheKey] = DateTime.now();

      return venues;
    } on PostgrestException catch (e) {
      // Handle RLS infinite recursion error gracefully (code 42P17)
      if (e.code == '42P17') {
        return [];
      }

      throw VenueServerException('Database error: ${e.message}');
    } catch (e) {
      throw VenueServerException('Failed to get venues: ${e.toString()}');
    }
  }

  @override
  Future<VenueModel> getVenue(String venueId) async {
    try {
      // Check cache first
      if (_isCacheValid(venueId)) {
        return _venueCache[venueId]!;
      }

      // Fetch venue with all related data
      final response = await _supabaseClient
          .from('venues')
          .select('''
        *,
        venue_spaces(sport, name_en, surface_key, indoor, lighting, capacity, min_players, max_players, is_active),
        venue_rating_aggregate(composite_score, event_count, dim_sums, dim_counts, last_event_at),
        venue_photos(url, sort_order),
        venue_opening_hours(weekday, open_time, close_time, is_open),
        venue_amenities(amenity_key, value)
      ''')
          .eq('id', venueId)
          .single();

      final venue = VenueModel.fromJson(response);

      // Update cache
      _venueCache[venueId] = venue;
      _cacheTimestamps[venueId] = DateTime.now();

      return venue;
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST116') {
        throw VenueNotFoundException('Venue not found');
      }
      throw VenueServerException('Database error: ${e.message}');
    } catch (e) {
      throw VenueServerException('Failed to get venue: ${e.toString()}');
    }
  }

  @override
  Future<List<VenueModel>> searchVenues(
    String query, {
    double? latitude,
    double? longitude,
    double? radiusKm,
    Map<String, dynamic>? filters,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      var searchQuery = _supabaseClient
          .from('venues')
          .select('*')
          .or(
            'name_en.ilike.%$query%,description_en.ilike.%$query%,district.ilike.%$query%',
          );

      // Location-based filtering if coordinates provided
      if (latitude != null && longitude != null && radiusKm != null) {
        final nearbyVenues = await getNearbyVenues(
          latitude,
          longitude,
          radiusKm,
          filters: filters,
          page: page,
          limit: limit,
        );

        // Filter by search query - using only name and description for now
        return nearbyVenues
            .where(
              (venue) =>
                  venue.name.toLowerCase().contains(query.toLowerCase()) ||
                  venue.description.toLowerCase().contains(query.toLowerCase()),
            )
            .toList();
      }

      // Apply additional filters
      if (filters != null) {
        if (filters['sport'] != null) {
          searchQuery = searchQuery.contains('supported_sports', [
            filters['sport'],
          ]);
        }
      }

      final response = await searchQuery
          .order('name_en')
          .range((page - 1) * limit, page * limit - 1);

      return response
          .map<VenueModel>((json) => VenueModel.fromJson(json))
          .toList();
    } on PostgrestException catch (e) {
      throw VenueServerException('Database error: ${e.message}');
    } catch (e) {
      throw VenueServerException('Failed to search venues: ${e.toString()}');
    }
  }

  @override
  Future<List<VenueModel>> getNearbyVenues(
    double latitude,
    double longitude,
    double radiusKm, {
    Map<String, dynamic>? filters,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      // Use PostGIS function for location-based queries
      final response = await _supabaseClient.rpc(
        'get_nearby_venues',
        params: {
          'lat': latitude,
          'lng': longitude,
          'radius_km': radiusKm,
          'sport_filter': filters?['sport'],
          'page_offset': (page - 1) * limit,
          'page_limit': limit,
        },
      );

      return response
          .map<VenueModel>((json) => VenueModel.fromJson(json))
          .toList();
    } on PostgrestException catch (e) {
      throw VenueServerException('Database error: ${e.message}');
    } catch (e) {
      throw VenueServerException(
        'Failed to get nearby venues: ${e.toString()}',
      );
    }
  }

  @override
  Future<List<SportConfigModel>> getVenueSports(String venueId) async {
    try {
      // Query venue_spaces to get sports supported at this venue
      final response = await _supabaseClient
          .from('venue_spaces')
          .select('sport')
          .eq('venue_id', venueId)
          .eq('is_active', true);

      if (response.isEmpty) {
        return [];
      }

      // Extract unique sports from venue spaces
      final sports = <String>{};
      for (final space in response) {
        final sport = space['sport'] as String?;
        if (sport != null && sport.isNotEmpty) {
          sports.add(sport);
        }
      }

      // Map to SportConfigModel using available sports
      return SportConfigModel.availableSports
          .where(
            (config) => sports.any(
              (sport) =>
                  sport.toLowerCase() == config.name.toLowerCase() ||
                  sport.toLowerCase() ==
                      config.type.toString().split('.').last.toLowerCase(),
            ),
          )
          .toList();
    } on PostgrestException catch (e) {
      throw VenueServerException('Database error: ${e.message}');
    } catch (e) {
      throw VenueServerException('Failed to get venue sports: ${e.toString()}');
    }
  }

  @override
  Future<List<TimeSlotModel>> checkAvailability(
    String venueId,
    String date, {
    String? startTime,
    String? endTime,
    String? sport,
  }) async {
    try {
      final response = await _supabaseClient.rpc(
        'check_venue_availability',
        params: {
          'venue_id': venueId,
          'check_date': date,
          'start_time': startTime,
          'end_time': endTime,
          'sport_type': sport,
        },
      );

      return response
          .map<TimeSlotModel>((json) => TimeSlotModel.fromJson(json))
          .toList();
    } on PostgrestException catch (e) {
      throw VenueServerException('Database error: ${e.message}');
    } catch (e) {
      throw VenueServerException(
        'Failed to check availability: ${e.toString()}',
      );
    }
  }

  @override
  Future<List<VenueModel>> getFeaturedVenues({
    int page = 1,
    int limit = 10,
  }) async {
    try {
      final response = await _supabaseClient
          .from('venues')
          .select('*')
          .eq('is_featured', true)
          .eq('is_available', true)
          .order('featured_priority', ascending: false)
          .range((page - 1) * limit, page * limit - 1);

      return response
          .map<VenueModel>((json) => VenueModel.fromJson(json))
          .toList();
    } on PostgrestException catch (e) {
      throw VenueServerException('Database error: ${e.message}');
    } catch (e) {
      throw VenueServerException(
        'Failed to get featured venues: ${e.toString()}',
      );
    }
  }

  @override
  Future<List<VenueModel>> getVenuesBySport(
    String sportType, {
    double? latitude,
    double? longitude,
    double? radiusKm,
    Map<String, dynamic>? filters,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      var query = _supabaseClient
          .from('venues')
          .select('*')
          .contains('supported_sports', [sportType])
          .eq('is_available', true);

      // Location filtering if provided
      if (latitude != null && longitude != null && radiusKm != null) {
        return await getNearbyVenues(
          latitude,
          longitude,
          radiusKm,
          filters: {'sport': sportType, ...?filters},
          page: page,
          limit: limit,
        );
      }

      final response = await query
          .order('average_rating', ascending: false)
          .range((page - 1) * limit, page * limit - 1);

      return response
          .map<VenueModel>((json) => VenueModel.fromJson(json))
          .toList();
    } on PostgrestException catch (e) {
      throw VenueServerException('Database error: ${e.message}');
    } catch (e) {
      throw VenueServerException(
        'Failed to get venues by sport: ${e.toString()}',
      );
    }
  }

  @override
  Future<Map<String, dynamic>> getVenueReviews(
    String venueId, {
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final response = await _supabaseClient
          .from('venue_reviews')
          .select('''
            *,
            user:profiles(full_name, avatar_url)
          ''')
          .eq('venue_id', venueId)
          .order('created_at', ascending: false)
          .range((page - 1) * limit, page * limit - 1);

      // Get total count
      final countResponse = await _supabaseClient
          .from('venue_reviews')
          .select('id')
          .eq('venue_id', venueId);

      return {
        'reviews': response,
        'total_count': countResponse.length,
        'page': page,
        'limit': limit,
      };
    } on PostgrestException catch (e) {
      throw VenueServerException('Database error: ${e.message}');
    } catch (e) {
      throw VenueServerException(
        'Failed to get venue reviews: ${e.toString()}',
      );
    }
  }

  @override
  Future<bool> addVenueReview(
    String venueId,
    String userId,
    double rating,
    String? comment,
  ) async {
    try {
      await _supabaseClient.from('venue_reviews').insert({
        'venue_id': venueId,
        'user_id': userId,
        'rating': rating,
        'comment': comment,
        'created_at': DateTime.now().toIso8601String(),
      });

      // Update venue average rating
      await _updateVenueAverageRating(venueId);

      // Clear cache
      _clearVenueCache(venueId);

      return true;
    } on PostgrestException catch (e) {
      throw VenueServerException('Database error: ${e.message}');
    } catch (e) {
      throw VenueServerException('Failed to add venue review: ${e.toString()}');
    }
  }

  Future<void> _updateVenueAverageRating(String venueId) async {
    try {
      await _supabaseClient.rpc(
        'update_venue_average_rating',
        params: {'venue_id': venueId},
      );
    } catch (e) {}
  }

  @override
  Future<List<String>> getVenuePhotos(String venueId) async {
    try {
      final response = await _supabaseClient
          .from('venue_photos')
          .select('url')
          .eq('venue_id', venueId)
          .order('sort_order')
          .order('created_at');

      return response.map((photo) => photo['url'] as String).toList();
    } on PostgrestException catch (e) {
      throw VenueServerException('Database error: ${e.message}');
    } catch (e) {
      throw VenueServerException('Failed to get venue photos: ${e.toString()}');
    }
  }

  @override
  Future<Map<String, dynamic>> getVenueOperatingHours(String venueId) async {
    try {
      final response = await _supabaseClient
          .from('venue_opening_hours')
          .select('weekday, open_time, close_time, is_open')
          .eq('venue_id', venueId)
          .order('weekday');

      // Convert to map format: {"0": {"open": "09:00", "close": "18:00", "is_open": true}, ...}
      final hoursMap = <String, Map<String, dynamic>>{};
      for (final row in response) {
        hoursMap[row['weekday'].toString()] = {
          'open': row['open_time'] as String,
          'close': row['close_time'] as String,
          'is_open': row['is_open'] as bool,
        };
      }

      return hoursMap;
    } on PostgrestException catch (e) {
      throw VenueServerException('Database error: ${e.message}');
    } catch (e) {
      throw VenueServerException(
        'Failed to get venue operating hours: ${e.toString()}',
      );
    }
  }

  @override
  Future<Map<String, dynamic>> getVenuePricing(
    String venueId, {
    String? sport,
    String? date,
  }) async {
    try {
      final response = await _supabaseClient.rpc(
        'get_venue_pricing',
        params: {
          'venue_id': venueId,
          'sport_type': sport,
          'pricing_date': date,
        },
      );

      return response as Map<String, dynamic>;
    } on PostgrestException catch (e) {
      throw VenueServerException('Database error: ${e.message}');
    } catch (e) {
      throw VenueServerException(
        'Failed to get venue pricing: ${e.toString()}',
      );
    }
  }

  @override
  Future<bool> checkVenueAmenities(
    String venueId,
    List<String> requiredAmenities,
  ) async {
    try {
      final response = await _supabaseClient
          .from('venues')
          .select('amenities')
          .eq('id', venueId)
          .single();

      final venueAmenities = List<String>.from(response['amenities'] ?? []);
      return requiredAmenities.every(
        (amenity) => venueAmenities.contains(amenity),
      );
    } on PostgrestException catch (e) {
      throw VenueServerException('Database error: ${e.message}');
    } catch (e) {
      throw VenueServerException(
        'Failed to check venue amenities: ${e.toString()}',
      );
    }
  }

  @override
  Future<Map<String, dynamic>> getVenueContactInfo(String venueId) async {
    try {
      final response = await _supabaseClient
          .from('venues')
          .select('phone, email, website, contact_person')
          .eq('id', venueId)
          .single();

      return response;
    } on PostgrestException catch (e) {
      throw VenueServerException('Database error: ${e.message}');
    } catch (e) {
      throw VenueServerException(
        'Failed to get venue contact info: ${e.toString()}',
      );
    }
  }

  @override
  Future<List<VenueModel>> getUserVenues(
    String userId, {
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final response = await _supabaseClient
          .from('venues')
          .select('*')
          .eq('owner_id', userId)
          .order('created_at', ascending: false)
          .range((page - 1) * limit, page * limit - 1);

      return response
          .map<VenueModel>((json) => VenueModel.fromJson(json))
          .toList();
    } on PostgrestException catch (e) {
      throw VenueServerException('Database error: ${e.message}');
    } catch (e) {
      throw VenueServerException('Failed to get user venues: ${e.toString()}');
    }
  }

  @override
  Future<bool> reportVenue(
    String venueId,
    String reason,
    String? description,
  ) async {
    try {
      await _supabaseClient.from('venue_reports').insert({
        'venue_id': venueId,
        'reason': reason,
        'description': description,
        'reported_at': DateTime.now().toIso8601String(),
      });

      return true;
    } on PostgrestException catch (e) {
      throw VenueServerException('Database error: ${e.message}');
    } catch (e) {
      throw VenueServerException('Failed to report venue: ${e.toString()}');
    }
  }

  @override
  Future<bool> toggleVenueFavorite(String venueId, String userId) async {
    try {
      await _supabaseClient.rpc(
        'toggle_venue_favorite',
        params: {'venue_id': venueId, 'user_id': userId},
      );

      return true;
    } on PostgrestException catch (e) {
      throw VenueServerException('Database error: ${e.message}');
    } catch (e) {
      throw VenueServerException(
        'Failed to toggle venue favorite: ${e.toString()}',
      );
    }
  }

  @override
  Future<List<VenueModel>> getFavoriteVenues(
    String userId, {
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final response = await _supabaseClient
          .from('venues')
          .select('*, venue_favorites!inner(user_id)')
          .eq('venue_favorites.user_id', userId)
          .order('name_en')
          .range((page - 1) * limit, page * limit - 1);

      return response
          .map<VenueModel>((json) => VenueModel.fromJson(json))
          .toList();
    } on PostgrestException catch (e) {
      throw VenueServerException('Database error: ${e.message}');
    } catch (e) {
      throw VenueServerException(
        'Failed to get favorite venues: ${e.toString()}',
      );
    }
  }

  // Additional convenience methods
  @override
  Future<List<Map<String, dynamic>>> getVenueBookingHistory(
    String venueId, {
    String? startDate,
    String? endDate,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      var query = _supabaseClient
          .from('bookings')
          .select('*, game:games(title, sport)')
          .eq('venue_id', venueId);

      if (startDate != null) {
        query = query.gte('booking_date', startDate);
      }
      if (endDate != null) {
        query = query.lte('booking_date', endDate);
      }

      final response = await query
          .order('booking_date', ascending: false)
          .range((page - 1) * limit, page * limit - 1);

      return response;
    } on PostgrestException catch (e) {
      throw VenueServerException('Database error: ${e.message}');
    } catch (e) {
      throw VenueServerException(
        'Failed to get venue booking history: ${e.toString()}',
      );
    }
  }

  @override
  Future<Map<String, dynamic>> getVenueUtilizationStats(
    String venueId, {
    String? startDate,
    String? endDate,
  }) async {
    try {
      final response = await _supabaseClient.rpc(
        'get_venue_utilization_stats',
        params: {
          'venue_id': venueId,
          'start_date': startDate,
          'end_date': endDate,
        },
      );

      return response as Map<String, dynamic>;
    } on PostgrestException catch (e) {
      throw VenueServerException('Database error: ${e.message}');
    } catch (e) {
      throw VenueServerException(
        'Failed to get venue utilization stats: ${e.toString()}',
      );
    }
  }

  @override
  Future<List<VenueModel>> getRecommendedVenues(
    String userId, {
    double? latitude,
    double? longitude,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final response = await _supabaseClient.rpc(
        'get_recommended_venues',
        params: {
          'user_id': userId,
          'user_lat': latitude,
          'user_lng': longitude,
          'page_offset': (page - 1) * limit,
          'page_limit': limit,
        },
      );

      return response
          .map<VenueModel>((json) => VenueModel.fromJson(json))
          .toList();
    } on PostgrestException catch (e) {
      throw VenueServerException('Database error: ${e.message}');
    } catch (e) {
      throw VenueServerException(
        'Failed to get recommended venues: ${e.toString()}',
      );
    }
  }

  @override
  Future<Map<String, dynamic>> getVenuePeakHours(String venueId) async {
    try {
      final response = await _supabaseClient.rpc(
        'get_venue_peak_hours',
        params: {'venue_id': venueId},
      );

      return response as Map<String, dynamic>;
    } on PostgrestException catch (e) {
      throw VenueServerException('Database error: ${e.message}');
    } catch (e) {
      throw VenueServerException(
        'Failed to get venue peak hours: ${e.toString()}',
      );
    }
  }

  @override
  Future<Map<String, dynamic>> checkVenueCapacity(
    String venueId,
    String dateTime,
    String sport,
  ) async {
    try {
      final response = await _supabaseClient.rpc(
        'check_venue_capacity',
        params: {
          'venue_id': venueId,
          'check_datetime': dateTime,
          'sport_type': sport,
        },
      );

      return response as Map<String, dynamic>;
    } on PostgrestException catch (e) {
      throw VenueServerException('Database error: ${e.message}');
    } catch (e) {
      throw VenueServerException(
        'Failed to check venue capacity: ${e.toString()}',
      );
    }
  }

  @override
  Future<Map<String, dynamic>> getVenueWeatherSuitability(
    String venueId,
  ) async {
    try {
      final response = await _supabaseClient
          .from('venues')
          .select('is_indoor, weather_protected, covered_areas')
          .eq('id', venueId)
          .single();

      return response;
    } on PostgrestException catch (e) {
      throw VenueServerException('Database error: ${e.message}');
    } catch (e) {
      throw VenueServerException(
        'Failed to get venue weather suitability: ${e.toString()}',
      );
    }
  }

  @override
  Future<List<VenueModel>> getVenuesWithPromotions({
    double? latitude,
    double? longitude,
    double? radiusKm,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      var query = _supabaseClient
          .from('venues')
          .select('*, venue_promotions!inner(*)')
          .gte(
            'venue_promotions.valid_until',
            DateTime.now().toIso8601String(),
          );

      // Location filtering if provided
      if (latitude != null && longitude != null && radiusKm != null) {
        final nearbyVenues = await getNearbyVenues(
          latitude,
          longitude,
          radiusKm,
          page: page,
          limit: limit,
        );

        // Filter for venues with active promotions - simplified for now
        return nearbyVenues;
      }

      final response = await query
          .order('venue_promotions.discount_percentage', ascending: false)
          .range((page - 1) * limit, page * limit - 1);

      return response
          .map<VenueModel>((json) => VenueModel.fromJson(json))
          .toList();
    } on PostgrestException catch (e) {
      throw VenueServerException('Database error: ${e.message}');
    } catch (e) {
      throw VenueServerException(
        'Failed to get venues with promotions: ${e.toString()}',
      );
    }
  }

  // Cache management methods
  bool _isCacheValid(String key) {
    final timestamp = _cacheTimestamps[key];
    if (timestamp == null) return false;
    return DateTime.now().difference(timestamp) < _cacheDuration;
  }

  void _clearVenueCache(String venueId) {
    _venueCache.remove(venueId);
    _cacheTimestamps.remove(venueId);

    // Clear related list caches
    final keysToRemove = _listCache.keys
        .where((key) => key.contains(venueId))
        .toList();
    for (final key in keysToRemove) {
      _listCache.remove(key);
      _cacheTimestamps.remove(key);
    }
  }

  void clearAllCache() {
    _venueCache.clear();
    _listCache.clear();
    _cacheTimestamps.clear();
  }
}
