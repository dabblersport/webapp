import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/features/location/domain/models/nearby_sort_order.dart';
import 'package:dabbler/features/misc/data/datasources/supabase_remote_data_source.dart';
import 'package:dabbler/features/games/data/models/nearby_game_model.dart';

abstract class NearbyGamesDatasource {
  Future<Result<List<NearbyGameModel>, Failure>> getNearbyGames({
    required double lat,
    required double lng,
    required int radiusMeters,
    String? sportId,
    NearbySortOrder sortOrder = NearbySortOrder.nearest,
  });

  Future<Result<List<NearbyGameModel>, Failure>> getAllGames({
    String? sportId,
  });
}

class SupabaseNearbyGamesDatasource implements NearbyGamesDatasource {
  const SupabaseNearbyGamesDatasource(this._svc);

  final SupabaseService _svc;

  @override
  Future<Result<List<NearbyGameModel>, Failure>> getNearbyGames({
    required double lat,
    required double lng,
    required int radiusMeters,
    String? sportId,
    NearbySortOrder sortOrder = NearbySortOrder.nearest,
  }) =>
      Result.guard(
        () async {
          final response = await _svc.client.rpc(
            'rpc_get_nearby_games',
            params: {
              'p_lat': lat,
              'p_lng': lng,
              'p_radius_meters': radiusMeters,
              if (sportId != null) 'p_sport_id': sportId,
              'p_sort':
                  sortOrder == NearbySortOrder.nearest ? 'distance' : 'default',
            },
          );

          final rows = response as List<dynamic>;
          return rows
              .map((r) => NearbyGameModel.fromJson(
                    Map<String, dynamic>.from(r as Map),
                  ))
              .toList();
        },
        (e) => Failure.from(e),
      );

  @override
  Future<Result<List<NearbyGameModel>, Failure>> getAllGames({
    String? sportId,
  }) =>
      Result.guard(
        () async {
          var query = _svc.client.from('v_game_card').select(
                'id, title, sport_name_en, start_at, end_at, '
                'is_cancelled, venue_name, area_name, capacity, roster_count, sport_id',
              );

          if (sportId != null) {
            query = query.eq('sport_id', sportId);
          }

          final rows =
              await query.order('start_at').limit(100) as List<dynamic>;
          final now = DateTime.now();

          return rows.map((r) {
            final row = Map<String, dynamic>.from(r as Map);
            final startAt =
                DateTime.tryParse(row['start_at'] as String? ?? '');
            final endAt = DateTime.tryParse(row['end_at'] as String? ?? '');
            final isCancelled = row['is_cancelled'] as bool? ?? false;

            final String status;
            if (isCancelled) {
              status = 'cancelled';
            } else if (startAt != null && now.isBefore(startAt)) {
              status = 'upcoming';
            } else if (startAt != null &&
                endAt != null &&
                now.isAfter(startAt) &&
                now.isBefore(endAt)) {
              status = 'live';
            } else {
              status = 'ended';
            }

            final capacity = row['capacity'] as int? ?? 0;
            final rosterCount = row['roster_count'] as int? ?? 0;

            return NearbyGameModel(
              id: row['id'] as String,
              title: row['title'] as String? ?? 'Untitled Game',
              sportName: row['sport_name_en'] as String?,
              scheduledAt: startAt,
              status: status,
              venueName:
                  (row['venue_name'] ?? row['area_name']) as String?,
              distanceMeters: 0,
              playerCount: rosterCount,
              spotsRemaining:
                  capacity > 0 ? capacity - rosterCount : null,
              isPublic: true,
            );
          }).toList();
        },
        (e) => Failure.from(e),
      );
}
