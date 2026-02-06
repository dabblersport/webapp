import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';

import 'package:dabbler/core/fp/result.dart' as core;
import 'package:dabbler/core/fp/failure.dart';
import '../../../../data/repositories/geo_repository.dart' as geo;
import 'package:dabbler/data/models/games/venue.dart' as domain;
import '../../domain/repositories/venues_repository.dart' as repo;

typedef Result<T> = core.Result<T, Failure>;

enum VenueSortBy { distance, rating, price, name }

class VenueFilters {
  final List<String> sports;
  final List<String> amenities;
  final double? maxDistance; // in kilometers
  final double? minRating;
  final double? maxPricePerHour;
  final double? minPricePerHour;
  final bool openNow;
  final DateTime? availableAt;

  const VenueFilters({
    this.sports = const [],
    this.amenities = const [],
    this.maxDistance,
    this.minRating,
    this.maxPricePerHour,
    this.minPricePerHour,
    this.openNow = false,
    this.availableAt,
  });

  VenueFilters copyWith({
    List<String>? sports,
    List<String>? amenities,
    double? maxDistance,
    double? minRating,
    double? maxPricePerHour,
    double? minPricePerHour,
    bool? openNow,
    DateTime? availableAt,
  }) {
    return VenueFilters(
      sports: sports ?? this.sports,
      amenities: amenities ?? this.amenities,
      maxDistance: maxDistance ?? this.maxDistance,
      minRating: minRating ?? this.minRating,
      maxPricePerHour: maxPricePerHour ?? this.maxPricePerHour,
      minPricePerHour: minPricePerHour ?? this.minPricePerHour,
      openNow: openNow ?? this.openNow,
      availableAt: availableAt ?? this.availableAt,
    );
  }

  bool get hasActiveFilters {
    return sports.isNotEmpty ||
        amenities.isNotEmpty ||
        maxDistance != null ||
        minRating != null ||
        maxPricePerHour != null ||
        minPricePerHour != null ||
        openNow ||
        availableAt != null;
  }
}

class VenueWithDistance {
  final domain.Venue venue;
  final double distanceKm;
  final bool isAvailable;
  final bool isFavorite;

  const VenueWithDistance({
    required this.venue,
    required this.distanceKm,
    required this.isAvailable,
    this.isFavorite = false,
  });

  VenueWithDistance copyWith({
    domain.Venue? venue,
    double? distanceKm,
    bool? isAvailable,
    bool? isFavorite,
  }) {
    return VenueWithDistance(
      venue: venue ?? this.venue,
      distanceKm: distanceKm ?? this.distanceKm,
      isAvailable: isAvailable ?? this.isAvailable,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }

  String get formattedDistance {
    if (distanceKm < 1) {
      return '${(distanceKm * 1000).round()}m away';
    } else if (distanceKm < 10) {
      return '${distanceKm.toStringAsFixed(1)}km away';
    } else {
      return '${distanceKm.round()}km away';
    }
  }

  bool get isNearby => distanceKm < 5.0;
  bool get isVeryClose => distanceKm < 1.0;
}

class VenuesState {
  final List<VenueWithDistance> venues;
  final List<domain.Venue> favoriteVenues;
  final bool isLoading;
  final bool isLoadingFavorites;
  final String? error;
  final VenueFilters filters;
  final VenueSortBy sortBy;
  final bool ascending;
  final double? userLatitude;
  final double? userLongitude;
  final DateTime? lastUpdated;

  const VenuesState({
    this.venues = const [],
    this.favoriteVenues = const [],
    this.isLoading = false,
    this.isLoadingFavorites = false,
    this.error,
    this.filters = const VenueFilters(),
    this.sortBy = VenueSortBy.distance,
    this.ascending = true,
    this.userLatitude,
    this.userLongitude,
    this.lastUpdated,
  });

  bool get hasVenues => venues.isNotEmpty;
  bool get hasFavorites => favoriteVenues.isNotEmpty;
  bool get hasLocation => userLatitude != null && userLongitude != null;
  bool get hasError => error != null;

  List<VenueWithDistance> get nearbyVenues =>
      venues.where((v) => v.isNearby).toList();

  List<VenueWithDistance> get availableVenues =>
      venues.where((v) => v.isAvailable).toList();

  List<VenueWithDistance> get favoriteVenuesWithDistance =>
      venues.where((v) => v.isFavorite).toList();

  VenuesState copyWith({
    List<VenueWithDistance>? venues,
    List<domain.Venue>? favoriteVenues,
    bool? isLoading,
    bool? isLoadingFavorites,
    String? error,
    VenueFilters? filters,
    VenueSortBy? sortBy,
    bool? ascending,
    double? userLatitude,
    double? userLongitude,
    DateTime? lastUpdated,
  }) {
    return VenuesState(
      venues: venues ?? this.venues,
      favoriteVenues: favoriteVenues ?? this.favoriteVenues,
      isLoading: isLoading ?? this.isLoading,
      isLoadingFavorites: isLoadingFavorites ?? this.isLoadingFavorites,
      error: error,
      filters: filters ?? this.filters,
      sortBy: sortBy ?? this.sortBy,
      ascending: ascending ?? this.ascending,
      userLatitude: userLatitude ?? this.userLatitude,
      userLongitude: userLongitude ?? this.userLongitude,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}

class VenuesController extends StateNotifier<VenuesState> {
  final repo.VenuesRepository _venuesRepository;
  final geo.GeoRepository _geoRepository;

  static const Duration _cacheValidity = Duration(minutes: 10);

  VenuesController(
    this._venuesRepository, {
    required geo.GeoRepository geoRepository,
  }) : _geoRepository = geoRepository,
       super(const VenuesState());

  /// Set user location and load nearby venues
  Future<void> setUserLocation(double latitude, double longitude) async {
    state = state.copyWith(userLatitude: latitude, userLongitude: longitude);

    await loadVenues();
  }

  /// Load venues based on current filters and location
  Future<void> loadVenues() async {
    if (!_shouldRefresh()) {
      return;
    }

    state = state.copyWith(isLoading: true, error: null);

    try {
      final repoFilters = repo.VenueFilters(
        sports: state.filters.sports.isEmpty ? null : state.filters.sports,
        amenities: state.filters.amenities.isEmpty
            ? null
            : state.filters.amenities,
        minPrice: state.filters.minPricePerHour,
        maxPrice: state.filters.maxPricePerHour,
        minRating: state.filters.minRating,
      );

      // Don't pass 'distance' to database - it's not a column, we calculate it client-side
      // Map 'name' enum to 'name_en' column in database
      final dbSortBy = state.sortBy == VenueSortBy.distance
          ? 'name_en'
          : (state.sortBy == VenueSortBy.name ? 'name_en' : state.sortBy.name);

      final venuesResult = await _venuesRepository.getVenues(
        filters: repoFilters,
        sortBy: dbSortBy,
        ascending: state.ascending,
      );

      final filteredResult = await _applyGeoFiltering(venuesResult);

      filteredResult.fold(
        (failure) {
          state = state.copyWith(
            isLoading: false,
            error: 'Failed to load venues: ${failure.message}',
          );
        },
        (venues) {
          final venuesWithDistance = venues.map((venue) {
            final distance = state.hasLocation
                ? _calculateDistance(
                    state.userLatitude!,
                    state.userLongitude!,
                    venue.latitude,
                    venue.longitude,
                  )
                : 0.0;

            return VenueWithDistance(
              venue: venue,
              distanceKm: distance,
              isAvailable: true,
              isFavorite: false, // Will be updated by _updateFavoriteStatus
            );
          }).toList();

          state = state.copyWith(
            venues: venuesWithDistance,
            isLoading: false,
            lastUpdated: DateTime.now(),
          );

          _sortVenues();
        },
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load venues: $e',
      );
    }
  }

  Future<Either<Failure, List<domain.Venue>>> _applyGeoFiltering(
    Either<Failure, List<domain.Venue>> baseResult,
  ) {
    if (!state.hasLocation) {
      return Future.value(baseResult);
    }

    return baseResult.fold((failure) async => left(failure), (venues) async {
      final radiusMeters = (state.filters.maxDistance ?? 10.0) * 1000;
      final geoLimit = venues.isEmpty
          ? 20
          : (venues.length > 50 ? 50 : venues.length);
      final geoResult = await _geoRepository.nearbyVenues(
        lat: state.userLatitude!,
        lng: state.userLongitude!,
        radiusMeters: radiusMeters,
        limit: geoLimit,
      );

      // Convert core.Result to Either for consistency
      return geoResult.fold((geoFailure) => right(venues), (geoVenues) {
        if (geoVenues.isEmpty) {
          return right(<domain.Venue>[]);
        }

        final order = <String, int>{};
        for (var i = 0; i < geoVenues.length; i++) {
          order[geoVenues[i].id] = i;
        }

        final filtered = venues
            .where((venue) => order.containsKey(venue.id))
            .toList();

        filtered.sort((a, b) => order[a.id]!.compareTo(order[b.id]!));

        return right(filtered);
      });
    });
  }

  /// Update filters and reload venues
  Future<void> updateFilters(VenueFilters newFilters) async {
    state = state.copyWith(filters: newFilters);
    await loadVenues();
  }

  /// Clear all filters
  void clearFilters() {
    state = state.copyWith(filters: const VenueFilters());
    loadVenues();
  }

  /// Update sorting
  void updateSorting(VenueSortBy sortBy, {bool? ascending}) {
    state = state.copyWith(
      sortBy: sortBy,
      ascending: ascending ?? state.ascending,
    );
    _sortVenues();
  }

  /// Search venues by text
  Future<void> searchVenues(String query) async {
    if (query.isEmpty) {
      await loadVenues();
      return;
    }

    state = state.copyWith(isLoading: true, error: null);

    try {
      await Future.delayed(const Duration(milliseconds: 500));

      final filteredVenues = state.venues.where((venueWithDistance) {
        final venue = venueWithDistance.venue;
        return venue.name.toLowerCase().contains(query.toLowerCase()) ||
            venue.description.toLowerCase().contains(query.toLowerCase()) ||
            venue.city.toLowerCase().contains(query.toLowerCase()) ||
            venue.supportedSports.any(
              (sport) => sport.toLowerCase().contains(query.toLowerCase()),
            );
      }).toList();

      state = state.copyWith(venues: filteredVenues, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Search failed: $e');
    }
  }

  /// Check venue availability
  Future<bool> checkVenueAvailability({
    required String venueId,
    required DateTime date,
    required String startTime,
    required String endTime,
  }) async {
    try {
      await Future.delayed(const Duration(milliseconds: 300));

      // Mock implementation - randomly return availability
      return DateTime.now().millisecond % 3 != 0;
    } catch (e) {
      return false;
    }
  }

  /// Load favorite venues
  Future<void> loadFavoriteVenues() async {
    state = state.copyWith(isLoadingFavorites: true);

    try {
      // For now, favorites feature is disabled

      state = state.copyWith(
        favoriteVenues: [], // Favorites feature disabled
        isLoadingFavorites: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoadingFavorites: false,
        error: 'Failed to load favorites: $e',
      );
    }
  }

  /// Add venue to favorites
  Future<void> addToFavorites(String venueId) async {
    try {
      await Future.delayed(const Duration(milliseconds: 200));

      final venue = state.venues
          .firstWhere((vwd) => vwd.venue.id == venueId)
          .venue;

      final updatedFavorites = [...state.favoriteVenues, venue];

      state = state.copyWith(favoriteVenues: updatedFavorites);
      _updateFavoriteStatus();
    } catch (e) {
      state = state.copyWith(error: 'Failed to add favorite: $e');
    }
  }

  /// Remove venue from favorites
  Future<void> removeFromFavorites(String venueId) async {
    try {
      await Future.delayed(const Duration(milliseconds: 200));

      final updatedFavorites = state.favoriteVenues
          .where((venue) => venue.id != venueId)
          .toList();

      state = state.copyWith(favoriteVenues: updatedFavorites);
      _updateFavoriteStatus();
    } catch (e) {
      state = state.copyWith(error: 'Failed to remove favorite: $e');
    }
  }

  /// Refresh all data
  Future<void> refresh() async {
    state = state.copyWith(lastUpdated: null); // Force refresh
    await Future.wait([loadVenues(), loadFavoriteVenues()]);
  }

  /// Private helper methods

  bool _shouldRefresh() {
    if (state.lastUpdated == null) return true;
    return DateTime.now().difference(state.lastUpdated!) > _cacheValidity;
  }

  void _sortVenues() {
    final sortedVenues = [...state.venues];

    switch (state.sortBy) {
      case VenueSortBy.distance:
        sortedVenues.sort(
          (a, b) => state.ascending
              ? a.distanceKm.compareTo(b.distanceKm)
              : b.distanceKm.compareTo(a.distanceKm),
        );
        break;

      case VenueSortBy.rating:
        sortedVenues.sort(
          (a, b) => state.ascending
              ? a.venue.rating.compareTo(b.venue.rating)
              : b.venue.rating.compareTo(a.venue.rating),
        );
        break;

      case VenueSortBy.price:
        sortedVenues.sort(
          (a, b) => state.ascending
              ? a.venue.pricePerHour.compareTo(b.venue.pricePerHour)
              : b.venue.pricePerHour.compareTo(a.venue.pricePerHour),
        );
        break;

      case VenueSortBy.name:
        sortedVenues.sort(
          (a, b) => state.ascending
              ? a.venue.name.compareTo(b.venue.name)
              : b.venue.name.compareTo(a.venue.name),
        );
        break;
    }

    state = state.copyWith(venues: sortedVenues);
  }

  void _updateFavoriteStatus() {
    final favoriteIds = state.favoriteVenues.map((v) => v.id).toSet();

    final updatedVenues = state.venues
        .map(
          (vwd) => vwd.copyWith(isFavorite: favoriteIds.contains(vwd.venue.id)),
        )
        .toList();

    state = state.copyWith(venues: updatedVenues);
  }

  /// Calculate distance between two points using Haversine formula
  double _calculateDistance(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const double earthRadius = 6371; // Earth's radius in kilometers

    final double dLat = _degreesToRadians(lat2 - lat1);
    final double dLng = _degreesToRadians(lng2 - lng1);

    final double a =
        (dLat / 2).abs() * (dLat / 2).abs() +
        (lat1 * 3.14159 / 180).abs() *
            (lat2 * 3.14159 / 180).abs() *
            (dLng / 2).abs() *
            (dLng / 2).abs();

    final double c = 2 * (a.abs() + (1 - a).abs());

    return earthRadius * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * (3.14159 / 180);
  }
}
