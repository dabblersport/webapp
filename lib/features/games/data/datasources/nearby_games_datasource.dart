import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/config/supabase_config.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/features/location/domain/models/nearby_sort_order.dart';
import 'package:dabbler/core/data/supabase_remote_data_source.dart';
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

  /// The viewer's own upcoming games — created by them or where they're on
  /// the active roster. Location-independent (pinned "My games" section).
  Future<Result<List<NearbyGameModel>, Failure>> getMyUpcomingGames({
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

  static const _cardColumns =
      'id, title, sport_name_en, start_at, end_at, is_cancelled, '
      'venue_name, area_name, capacity, roster_count, sport_id, '
      'is_creator, is_joined, min_skill, max_skill';

  @override
  Future<Result<List<NearbyGameModel>, Failure>> getAllGames({
    String? sportId,
  }) =>
      Result.guard(
        () async {
          var query =
              _svc.client.from(SupabaseConfig.vGameCardTable).select(_cardColumns);

          if (sportId != null) {
            query = query.eq('sport_id', sportId);
          }

          final rows =
              await query.order('start_at').limit(100) as List<dynamic>;
          return _mapCardRows(rows);
        },
        (e) => Failure.from(e),
      );

  @override
  Future<Result<List<NearbyGameModel>, Failure>> getMyUpcomingGames({
    String? sportId,
  }) =>
      Result.guard(
        () async {
          var query = _svc.client
              .from(SupabaseConfig.vGameCardTable)
              .select(_cardColumns)
              .or('is_creator.eq.true,is_joined.eq.true')
              .eq('is_cancelled', false)
              .gt('end_at', DateTime.now().toUtc().toIso8601String());

          if (sportId != null) {
            query = query.eq('sport_id', sportId);
          }

          final rows =
              await query.order('start_at').limit(50) as List<dynamic>;
          return _mapCardRows(rows);
        },
        (e) => Failure.from(e),
      );

  /// Maps v_game_card rows to [NearbyGameModel] (status computed here — the
  /// view has no status column; distance is 0, these paths are location-free).
  List<NearbyGameModel> _mapCardRows(List<dynamic> rows) {
    final now = DateTime.now();
    return rows.map((r) {
      final row = Map<String, dynamic>.from(r as Map);
      final startAt = DateTime.tryParse(row['start_at'] as String? ?? '');
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
        venueName: (row['venue_name'] ?? row['area_name']) as String?,
        distanceMeters: 0,
        playerCount: rosterCount,
        spotsRemaining: capacity > 0 ? capacity - rosterCount : null,
        isPublic: true,
        isCreated: row['is_creator'] as bool? ?? false,
        isJoined: row['is_joined'] as bool? ?? false,
        minSkill: row['min_skill'] as int?,
        maxSkill: row['max_skill'] as int?,
      );
    }).toList();
  }
}
