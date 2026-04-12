import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/nearby_venue.dart';
import '../models/nearby_game.dart';
import '../models/nearby_post.dart';

class GeoRepository {
  final SupabaseClient _client;

  GeoRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  Future<List<NearbyVenue>> getNearbyVenues({
    required double lat,
    required double lng,
    double radiusMeters = 5000,
  }) async {
    final response = await _client.rpc(
      'get_nearby_venues',
      params: {'p_lat': lat, 'p_lng': lng, 'p_radius': radiusMeters},
    );
    return (response as List)
        .map((e) => NearbyVenue.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<NearbyGame>> getNearbyGames({
    required double lat,
    required double lng,
    double radiusMeters = 5000,
  }) async {
    final response = await _client.rpc(
      'get_nearby_games',
      params: {'p_lat': lat, 'p_lng': lng, 'p_radius': radiusMeters},
    );
    return (response as List)
        .map((e) => NearbyGame.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<NearbyPost>> getNearbyPosts({
    required double lat,
    required double lng,
    double radiusMeters = 5000,
  }) async {
    final response = await _client.rpc(
      'get_nearby_posts',
      params: {'p_lat': lat, 'p_lng': lng, 'p_radius': radiusMeters},
    );
    return (response as List)
        .map((e) => NearbyPost.fromMap(e as Map<String, dynamic>))
        .toList();
  }
}
