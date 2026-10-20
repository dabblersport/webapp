import 'package:dabbler/core/data/supabase_remote_data_source.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/features/games/data/models/nearby_game_model.dart';
import 'package:dabbler/features/games/data/repositories/games_following_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The "N following" note's data, merged onto the listing after it loads.
/// Kept apart from the listing query so a failure here never touches the list.

final gamesFollowingRepositoryProvider = Provider<GamesFollowingRepository>(
  (ref) => SupabaseGamesFollowingRepository.fromService(
    ref.watch(supabaseServiceProvider),
  ),
);

/// The provider key for the [visible] games: their ids (the first
/// [kGamesFollowingMaxIds] in list order), sorted and joined, so the same set
/// in another order or on another rebuild is the same key and is not fetched
/// again.
String gamesFollowingKey(Iterable<NearbyGameModel> visible) {
  final List<String> ids =
      visible.map((g) => g.id).take(kGamesFollowingMaxIds).toSet().toList()
        ..sort();
  return ids.join(',');
}

/// Game id → people the viewer follows in it, for one set of visible ids
/// ([gamesFollowingKey]). One call per distinct set; any failure (or a signed
/// out viewer) is an empty map, so the cards simply show no note.
final gamesFollowingJoinedProvider = FutureProvider.autoDispose
    .family<Map<String, int>, String>((ref, key) async {
      if (key.isEmpty) return const {};
      try {
        final result = await ref
            .read(gamesFollowingRepositoryProvider)
            .getFollowingJoined(key.split(','));
        return switch (result) {
          Ok(:final value) => value,
          _ => const <String, int>{},
        };
      } catch (_) {
        return const {};
      }
    });

/// [games] with their following counts from [counts] (0 where absent).
List<NearbyGameModel> gamesWithFollowing(
  List<NearbyGameModel> games,
  Map<String, int> counts,
) => counts.isEmpty
    ? games
    : [for (final g in games) g.withFollowing(counts[g.id] ?? 0)];

/// The visible [games] with the viewer's following counts merged in, watched
/// from [ref]. Until the counts arrive (or when they fail) the games come back
/// unchanged.
List<NearbyGameModel> watchGamesWithFollowing(
  WidgetRef ref,
  List<NearbyGameModel> games,
) => gamesWithFollowing(
  games,
  ref.watch(gamesFollowingJoinedProvider(gamesFollowingKey(games))).valueOrNull ??
      const {},
);
