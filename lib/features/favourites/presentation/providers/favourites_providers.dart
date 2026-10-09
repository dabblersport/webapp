import 'package:dabbler/core/data/supabase_client.dart';
import 'package:dabbler/features/favourites/data/favourite_item.dart';
import 'package:dabbler/features/favourites/data/favourites_repository.dart';
import 'package:dabbler/features/games/presentation/utils/favourite_toast.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final favouritesRepositoryProvider = Provider<FavouritesRepository>(
  (ref) => FavouritesRepository(ref.watch(supabaseClientProvider)),
);

/// The viewer's favourites of one type, newest first.
final favouritesProvider = FutureProvider.autoDispose
    .family<List<FavouriteItem>, FavouriteKind>(
      (ref, kind) => ref.watch(favouritesRepositoryProvider).load(kind),
    );

/// Ids removed from the screen this session, applied at once (optimistic) and
/// put back if the toggle fails.
final favouriteRemovalsProvider = StateProvider.autoDispose<Set<String>>(
  (ref) => const <String>{},
);
