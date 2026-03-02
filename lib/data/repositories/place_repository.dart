import 'package:dabbler/core/config/environment.dart';
import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/data/models/place.dart';
import 'package:flutter/foundation.dart';
import 'package:mapbox_search/mapbox_search.dart' hide Place;

/// Repository that wraps Mapbox SearchBox API for place search.
///
/// Returns [Result<T, Failure>] to stay consistent with the app's FP layer.
class PlaceRepository {
  PlaceRepository({String? apiKey}) : _search = _buildSearchApi(apiKey);

  static SearchBoxAPI _buildSearchApi(String? apiKey) {
    final token = apiKey ?? Environment.mapboxAccessToken;
    assert(token.isNotEmpty, 'Mapbox access token is empty – check .env');
    debugPrint('[PlaceRepository] token loaded (${token.length} chars)');
    return SearchBoxAPI(
      apiKey: token,
      limit: 10,
      types: [PlaceType.poi, PlaceType.address, PlaceType.place],
    );
  }

  final SearchBoxAPI _search;

  /// Search for places matching [query].
  ///
  /// Optionally bias results toward [proximityLat]/[proximityLng].
  Future<Result<List<Place>, Failure>> searchPlaces({
    required String query,
    double? proximityLat,
    double? proximityLng,
  }) async {
    return Result.guard(
      () async {
        final proximity = proximityLat != null && proximityLng != null
            ? Proximity.LatLong(lat: proximityLat, long: proximityLng)
            : Proximity.LocationNone();

        final response = await _search.getSuggestions(
          query,
          proximity: proximity,
        );

        return response.fold((data) {
          return data.suggestions
              .map(
                (s) => Place(
                  id: s.mapboxId,
                  name: s.name,
                  fullAddress: s.fullAddress ?? s.placeFormatted,
                  category: s.poiCategory?.firstOrNull,
                ),
              )
              .toList();
        }, (failure) => throw Exception(failure.message));
      },
      (e) => Failure(
        category: FailureCode.network,
        message: 'Place search failed: $e',
        cause: e,
      ),
    );
  }

  /// Retrieve full place details (including coordinates) by [mapboxId].
  Future<Result<Place, Failure>> resolvePlace({
    required String mapboxId,
  }) async {
    return Result.guard(
      () async {
        final response = await _search.getPlace(mapboxId);

        return response.fold((data) {
          final feature = data.features.first;
          final props = feature.properties;
          final coords = props.coordinates;

          return Place(
            id: mapboxId,
            name: props.name,
            fullAddress: props.fullAddress ?? props.placeFormatted,
            category: props.poiCategory?.firstOrNull,
            latitude: coords?.location.lat,
            longitude: coords?.location.long,
          );
        }, (failure) => throw Exception(failure.message));
      },
      (e) => Failure(
        category: FailureCode.network,
        message: 'Place retrieval failed: $e',
        cause: e,
      ),
    );
  }
}
