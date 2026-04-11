import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/data/models/nearby/nearby.dart';

abstract class NearbyRepository {
  Future<Result<List<NearbyGame>, Failure>> getNearbyGames({
    required double lat,
    required double lng,
    int radius = 5000,
  });

  Future<Result<List<NearbyVenue>, Failure>> getNearbyVenues({
    required double lat,
    required double lng,
    int radius = 5000,
  });

  Future<Result<List<NearbyPost>, Failure>> getNearbyPosts({
    required double lat,
    required double lng,
    int radius = 5000,
  });

  Future<Result<List<NearbyProfile>, Failure>> getNearbyProfiles({
    required double lat,
    required double lng,
    int radius = 5000,
  });
}
