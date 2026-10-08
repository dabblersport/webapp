import 'package:dabbler/core/config/supabase_config.dart';
import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/features/games/data/models/nearby_game_model.dart';
import 'package:dabbler/features/games/data/repositories/games_following_repository.dart';
import 'package:dabbler/features/games/presentation/providers/games_following_provider.dart';
import 'package:dabbler/features/games/presentation/utils/games_listing_copy.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

/// A mockito mock of the repository, written out (the generated form) so the
/// test needs no build_runner pass.
class MockGamesFollowingRepository extends Mock
    implements GamesFollowingRepository {
  @override
  Future<Result<Map<String, int>, Failure>> getFollowingJoined(
    List<String>? gameIds,
  ) =>
      super.noSuchMethod(
            Invocation.method(#getFollowingJoined, [gameIds]),
            returnValue: Future<Result<Map<String, int>, Failure>>.value(
              const Ok<Map<String, int>, Failure>({}),
            ),
            returnValueForMissingStub:
                Future<Result<Map<String, int>, Failure>>.value(
                  const Ok<Map<String, int>, Failure>({}),
                ),
          )
          as Future<Result<Map<String, int>, Failure>>;
}

NearbyGameModel _game(String id) =>
    NearbyGameModel(id: id, title: id, distanceMeters: 0, isPublic: true);

void main() {
  group('repository', () {
    late List<(String, Map<String, dynamic>)> calls;
    SupabaseGamesFollowingRepository repo({
      bool signedIn = true,
      Object? answer = const <Map<String, dynamic>>[],
      Object? error,
    }) {
      calls = [];
      return SupabaseGamesFollowingRepository(
        rpc: (fn, params) async {
          calls.add((fn, params));
          if (error != null) throw error;
          return answer;
        },
        signedIn: () => signedIn,
      );
    }

    test('calls the RPC by its config name with p_game_ids', () async {
      final r = await repo(
        answer: [
          {'game_id': 'g1', 'following_count': 2},
          {'game_id': 'g2', 'following_count': 0},
        ],
      ).getFollowingJoined(['g1', 'g2']);
      expect(calls, hasLength(1));
      expect(calls.single.$1, SupabaseConfig.gamesFollowingJoinedRpc);
      expect(calls.single.$1, 'rpc_games_following_joined');
      expect(calls.single.$2, {
        'p_game_ids': ['g1', 'g2'],
      });
      expect(r, isA<Ok<Map<String, int>, Failure>>());
      expect((r as Ok<Map<String, int>, Failure>).value, {'g1': 2});
    });

    test('sends at most 200 ids', () async {
      final ids = [for (var i = 0; i < 250; i++) 'g$i'];
      await repo().getFollowingJoined(ids);
      final sent = calls.single.$2['p_game_ids'] as List<String>;
      expect(sent, hasLength(kGamesFollowingMaxIds));
      expect(sent, ids.take(200).toList());
    });

    test('no call for an empty list or a signed-out viewer', () async {
      final a = await repo().getFollowingJoined(const []);
      expect(calls, isEmpty);
      expect((a as Ok<Map<String, int>, Failure>).value, isEmpty);
      final b = await repo(signedIn: false).getFollowingJoined(['g1']);
      expect(calls, isEmpty);
      expect((b as Ok<Map<String, int>, Failure>).value, isEmpty);
    });

    test('an RPC error is an Err, not a throw', () async {
      final r = await repo(
        error: Exception('permission denied'),
      ).getFollowingJoined(['g1']);
      expect(r, isA<Err<Map<String, int>, Failure>>());
    });
  });

  group('merge', () {
    late MockGamesFollowingRepository mock;
    ProviderContainer container() {
      final c = ProviderContainer(
        overrides: [gamesFollowingRepositoryProvider.overrideWithValue(mock)],
      );
      addTearDown(c.dispose);
      return c;
    }

    setUp(() => mock = MockGamesFollowingRepository());

    test('requests only the visible ids, merged onto the cards', () async {
      when(mock.getFollowingJoined(any)).thenAnswer(
        (_) async => const Ok<Map<String, int>, Failure>({'g2': 3}),
      );
      final visible = [_game('g2'), _game('g1')];
      final c = container();
      final key = gamesFollowingKey(visible);
      final counts = await c.read(gamesFollowingJoinedProvider(key).future);
      final ids =
          verify(mock.getFollowingJoined(captureAny)).captured.single
              as List<String>;
      expect(ids, ['g1', 'g2']);
      final merged = gamesWithFollowing(visible, counts);
      expect(merged.map((g) => g.followingJoined), [3, 0]);
      expect(merged.map((g) => g.id), ['g2', 'g1']);
    });

    test('caps the key at 200 ids', () {
      final many = [for (var i = 0; i < 260; i++) _game('g$i')];
      expect(gamesFollowingKey(many).split(','), hasLength(200));
    });

    test('a failure leaves the list intact and shows no note', () async {
      when(mock.getFollowingJoined(any)).thenAnswer(
        (_) async => Err<Map<String, int>, Failure>(Failure.from('boom')),
      );
      final visible = [_game('g1')];
      final c = container();
      final counts = await c.read(
        gamesFollowingJoinedProvider(gamesFollowingKey(visible)).future,
      );
      expect(counts, isEmpty);
      final merged = gamesWithFollowing(visible, counts);
      expect(identical(merged, visible), isTrue);
      expect(merged.single.followingJoined, 0);
    });

    test('a thrown error is also no data', () async {
      when(mock.getFollowingJoined(any)).thenThrow(StateError('x'));
      final c = container();
      final counts = await c.read(gamesFollowingJoinedProvider('g1').future);
      expect(counts, isEmpty);
    });

    test('signed out: the real repository makes no call', () async {
      var called = 0;
      final c = ProviderContainer(
        overrides: [
          gamesFollowingRepositoryProvider.overrideWithValue(
            SupabaseGamesFollowingRepository(
              rpc: (fn, params) async {
                called++;
                return const [];
              },
              signedIn: () => false,
            ),
          ),
        ],
      );
      addTearDown(c.dispose);
      final counts = await c.read(gamesFollowingJoinedProvider('g1').future);
      expect(counts, isEmpty);
      expect(called, 0);
    });

    test('re-requests only when the set of ids changes', () async {
      when(mock.getFollowingJoined(any)).thenAnswer(
        (_) async => const Ok<Map<String, int>, Failure>({}),
      );
      final c = container();
      final a = gamesFollowingKey([_game('g1'), _game('g2')]);
      final sub = c.listen(gamesFollowingJoinedProvider(a), (_, _) {});
      addTearDown(sub.close);
      await c.read(gamesFollowingJoinedProvider(a).future);
      // Same set, another order or rebuild: same key, no new call.
      final again = gamesFollowingKey([_game('g2'), _game('g1')]);
      expect(again, a);
      await c.read(gamesFollowingJoinedProvider(again).future);
      verify(mock.getFollowingJoined(any)).called(1);
      // A new set: one more call.
      final b = gamesFollowingKey([_game('g1'), _game('g3')]);
      await c.read(gamesFollowingJoinedProvider(b).future);
      verify(mock.getFollowingJoined(any)).called(1);
    });

    test('withFollowing keeps the favourite and withFavourite keeps it', () {
      final g = _game('g1').withFollowing(4);
      expect(g.followingJoined, 4);
      expect(g.withFavourite(favourited: true, count: 1).followingJoined, 4);
    });
  });

  group('card note', () {
    for (final locale in const [Locale('en'), Locale('ar')]) {
      final l = lookupAppLocalizations(locale);
      final lang = locale.languageCode;

      test('$lang: spots + following, joined by a middle dot', () {
        final note = gamesCardNote(l, GamesCardStatus.open, 3, 2);
        expect(
          note,
          '${l.listing_spots_left(3)} · ${l.listing_following_joined(2)}',
        );
        expect(note, contains(' · '));
      });

      test('$lang: a full game shows only the following note', () {
        expect(
          gamesCardNote(l, GamesCardStatus.full, 0, 5),
          l.listing_following_joined(5),
        );
      });

      test('$lang: no following, the status note alone', () {
        expect(
          gamesCardNote(l, GamesCardStatus.open, 3, 0),
          l.listing_spots_left(3),
        );
        expect(gamesCardNote(l, GamesCardStatus.full, 0, 0), l.listing_full);
      });
    }

    test('EN and AR wording, Western digits', () {
      final en = lookupAppLocalizations(const Locale('en'));
      final ar = lookupAppLocalizations(const Locale('ar'));
      expect(en.listing_following_joined(2), '2 following');
      expect(en.listing_following_joined(1), '1 following');
      expect(ar.listing_following_joined(1), '1 ممّن تتابعهم');
      expect(ar.listing_following_joined(3), '3 ممّن تتابعهم');
      expect(ar.listing_following_joined(11), '11 ممّن تتابعهم');
      expect(
        gamesCardNote(en, GamesCardStatus.open, 3, 2),
        '3 spots left · 2 following',
      );
    });
  });
}
