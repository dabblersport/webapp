import 'package:dabbler/core/config/supabase_config.dart';
import 'package:dabbler/core/data/supabase_remote_data_source.dart';
import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';

/// What can be favourited: `toggle_favorite`'s `p_target_type`.
enum FavoriteTarget {
  game('game'),
  meetup('meetup'),
  venue('venue');

  const FavoriteTarget(this.wire);

  /// The value the RPC takes.
  final String wire;
}

/// The server's answer to a toggle: the viewer's new state and the new count.
typedef FavoriteState = ({bool favourited, int count});

/// Favourites (the heart) of a game, meetup or venue. Not likes.
abstract class FavoritesRepository {
  /// Flips the viewer's favourite on [targetId] and returns the new state.
  Future<Result<FavoriteState, Failure>> toggle(
    FavoriteTarget target,
    String targetId,
  );
}

class SupabaseFavoritesRepository implements FavoritesRepository {
  const SupabaseFavoritesRepository(this._svc);

  final SupabaseService _svc;

  @override
  Future<Result<FavoriteState, Failure>> toggle(
    FavoriteTarget target,
    String targetId,
  ) => Result.guard(() async {
    final dynamic response = await _svc.client.rpc(
      SupabaseConfig.toggleFavoriteRpc,
      params: {'p_target_type': target.wire, 'p_target_id': targetId},
    );
    final dynamic row = response is List ? response.first : response;
    final map = Map<String, dynamic>.from(row as Map);
    return (
      favourited: map['favourited'] as bool? ?? false,
      count: (map['favorite_count'] as num?)?.toInt() ?? 0,
    );
  }, (e) => Failure.from(e));
}
