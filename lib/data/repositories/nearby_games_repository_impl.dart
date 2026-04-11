import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/data/models/nearby/nearby.dart';
import 'package:dabbler/data/repositories/base_repository.dart';
import 'package:dabbler/data/repositories/nearby_games_repository.dart';

class NearbyRepositoryImpl extends BaseRepository implements NearbyRepository {
  const NearbyRepositoryImpl(super.svc);

  // ---------------------------------------------------------------------------
  // Games
  // ---------------------------------------------------------------------------

  @override
  Future<Result<List<NearbyGame>, Failure>> getNearbyGames({
    required double lat,
    required double lng,
    int radius = 5000,
  }) {
    return guard<List<NearbyGame>>(() async {
      final rows =
          await svc.client.rpc(
                'get_nearby_games',
                params: {'p_lat': lat, 'p_lng': lng, 'p_radius': radius},
              )
              as List<dynamic>;
      return rows
          .cast<Map<String, dynamic>>()
          .map(NearbyGame.fromJson)
          .toList();
    });
  }

  // ---------------------------------------------------------------------------
  // Venues
  // ---------------------------------------------------------------------------

  @override
  Future<Result<List<NearbyVenue>, Failure>> getNearbyVenues({
    required double lat,
    required double lng,
    int radius = 5000,
  }) {
    return guard<List<NearbyVenue>>(() async {
      final rows =
          await svc.client.rpc(
                'get_nearby_venues',
                params: {'p_lat': lat, 'p_lng': lng, 'p_radius': radius},
              )
              as List<dynamic>;
      return rows
          .cast<Map<String, dynamic>>()
          .map(NearbyVenue.fromJson)
          .toList();
    });
  }

  // ---------------------------------------------------------------------------
  // Posts
  // ---------------------------------------------------------------------------

  @override
  Future<Result<List<NearbyPost>, Failure>> getNearbyPosts({
    required double lat,
    required double lng,
    int radius = 5000,
  }) {
    return guard<List<NearbyPost>>(() async {
      final rows =
          await svc.client.rpc(
                'get_nearby_posts',
                params: {'p_lat': lat, 'p_lng': lng, 'p_radius': radius},
              )
              as List<dynamic>;
      return rows
          .cast<Map<String, dynamic>>()
          .map(NearbyPost.fromJson)
          .toList();
    });
  }

  // ---------------------------------------------------------------------------
  // Profiles
  // ---------------------------------------------------------------------------

  @override
  Future<Result<List<NearbyProfile>, Failure>> getNearbyProfiles({
    required double lat,
    required double lng,
    int radius = 5000,
  }) {
    return guard<List<NearbyProfile>>(() async {
      final rows =
          await svc.client.rpc(
                'get_nearby_profiles',
                params: {'p_lat': lat, 'p_lng': lng, 'p_radius': radius},
              )
              as List<dynamic>;
      return rows
          .cast<Map<String, dynamic>>()
          .map(NearbyProfile.fromJson)
          .toList();
    });
  }
}
