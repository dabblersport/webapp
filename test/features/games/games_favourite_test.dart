import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/features/games/data/models/nearby_game_model.dart';
import 'package:dabbler/features/games/data/repositories/favorites_repository.dart';
import 'package:dabbler/features/games/presentation/providers/nearby_games_provider.dart';
import 'package:dabbler/features/games/presentation/utils/games_listing_copy.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

/// A mockito mock of the repository, written out (the generated form) so the
/// test needs no build_runner pass.
class MockFavoritesRepository extends Mock implements FavoritesRepository {
  @override
  Future<Result<FavoriteState, Failure>> toggle(
    FavoriteTarget target,
    String targetId,
  ) =>
      super.noSuchMethod(
            Invocation.method(#toggle, [target, targetId]),
            returnValue: Future<Result<FavoriteState, Failure>>.value(
              const Ok<FavoriteState, Failure>((favourited: false, count: 0)),
            ),
            returnValueForMissingStub:
                Future<Result<FavoriteState, Failure>>.value(
                  const Ok<FavoriteState, Failure>((favourited: false, count: 0)),
                ),
          )
          as Future<Result<FavoriteState, Failure>>;
}

void main() {
  const game = NearbyGameModel(
    id: 'g1',
    title: 'Game',
    distanceMeters: 0,
    isPublic: true,
    favoriteCount: 4,
  );

  late MockFavoritesRepository repo;
  ProviderContainer container({bool signedIn = true}) {
    final c = ProviderContainer(
      overrides: [
        favoritesRepositoryProvider.overrideWithValue(repo),
        favouriteSignedInProvider.overrideWithValue(signedIn),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  NearbyGameModel shown(ProviderContainer c) =>
      gameWithFavourite(c.read(gameFavouriteOverridesProvider), game);

  setUp(() => repo = MockFavoritesRepository());

  test('optimistic, then the server answer', () async {
    when(repo.toggle(FavoriteTarget.game, 'g1')).thenAnswer(
      (_) async => const Ok<FavoriteState, Failure>((favourited: true, count: 9)),
    );
    final c = container();
    final pending = toggleGameFavourite(c, game);
    expect(shown(c).favouritedByMe, isTrue);
    expect(shown(c).favoriteCount, 5);
    expect(await pending, isTrue);
    expect(shown(c).favoriteCount, 9);
    verify(repo.toggle(FavoriteTarget.game, 'g1')).called(1);
  });

  test('rolls back on error', () async {
    when(repo.toggle(FavoriteTarget.game, 'g1')).thenAnswer(
      (_) async => Err<FavoriteState, Failure>(Failure.from('boom')),
    );
    final c = container();
    expect(await toggleGameFavourite(c, game), isFalse);
    expect(shown(c).favouritedByMe, isFalse);
    expect(shown(c).favoriteCount, 4);
  });

  test('signed out: nothing is sent, nothing changes', () async {
    final c = container(signedIn: false);
    expect(await toggleGameFavourite(c, game), isFalse);
    expect(shown(c).favoriteCount, 4);
    verifyNever(repo.toggle(FavoriteTarget.game, 'g1'));
  });

  test('model reads the new card fields', () {
    final m = NearbyGameModel.fromJson({
      'id': 'g',
      'title': 'T',
      'scheduled_at': '2026-10-10T18:00:00Z',
      'end_at': '2026-10-10T19:30:00Z',
      'variant_name_en': 'Futsal 5s',
      'variant_name_ar': 'خماسي صالات',
      'host_verified': true,
      'favorite_count': 3,
      'favourited_by_me': true,
      'distance_meters': 1200,
    });
    expect(m.durationMinutes, 90);
    expect(m.formatName('en'), 'Futsal 5s');
    expect(m.formatName('ar'), 'خماسي صالات');
    expect(m.hostVerified, isTrue);
    expect(m.favoriteCount, 3);
    expect(m.favouritedByMe, isTrue);
    expect(m.distanceLabel, '1.2 km');
  });

  test('default sort is starting soonest (no chip)', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    expect(c.read(nearbyGameSortProvider), isNull);
  });

  for (final loc in const [Locale('en'), Locale('ar')]) {
    test('every game is Free, no charge - ${loc.languageCode}', () {
      final l = lookupAppLocalizations(loc);
      final p = gamesPrice(l);
      expect(p.label, l.listing_free);
      expect(p.note, l.listing_no_charge);
      expect(p.free, isTrue);
    });
  }
}
