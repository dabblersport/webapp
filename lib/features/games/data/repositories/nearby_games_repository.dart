import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/features/location/presentation/widgets/nearby_filter_sheet.dart'
    show NearbySortOrder;
import 'package:dabbler/features/games/data/datasources/nearby_games_datasource.dart';
import 'package:dabbler/features/games/data/models/nearby_game_model.dart';

abstract class NearbyGamesRepository {
  Future<Result<List<NearbyGameModel>, Failure>> getNearbyGames({
    required double lat,
    required double lng,
    required int radiusMeters,
    String? sportId,
    NearbySortOrder sortOrder = NearbySortOrder.nearest,
  });
}

class NearbyGamesRepositoryImpl implements NearbyGamesRepository {
  const NearbyGamesRepositoryImpl(this._datasource);

  final NearbyGamesDatasource _datasource;

  @override
  Future<Result<List<NearbyGameModel>, Failure>> getNearbyGames({
    required double lat,
    required double lng,
    required int radiusMeters,
    String? sportId,
    NearbySortOrder sortOrder = NearbySortOrder.nearest,
  }) =>
      _datasource.getNearbyGames(
        lat: lat,
        lng: lng,
        radiusMeters: radiusMeters,
        sportId: sportId,
        sortOrder: sortOrder,
      );
}
