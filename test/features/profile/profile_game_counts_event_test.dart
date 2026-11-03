import 'dart:io';

import 'package:dabbler/features/games/presentation/controllers/game_counts.dart';
import 'package:dabbler/features/profile/presentation/models/contributor_profile_data.dart';
import 'package:dabbler/features/profile/presentation/providers/contributor_profile_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// KAN-744 (KAN-715 R04): the profile counts read v_game_card, whose shared
// columns come from public.events since KAN-720 (B01). Event-backed rows may
// carry null title / end_at / sport_id; the games id stays the row id.
//
// This pins the live path the profile screens draw: _readGames selects
// v_game_card -> gameRowsToEntities -> contributorProfileProvider ->
// profileGameCountsProvider.
void main() {
  const String gameId = '11111111-1111-1111-1111-111111111111';
  const String profileId = '22222222-2222-2222-2222-222222222222';
  const String userId = '33333333-3333-3333-3333-333333333333';

  Map<String, dynamic> nullSharedRow() => <String, dynamic>{
    'id': gameId,
    'title': null,
    'start_at': '2026-11-10T18:00:00Z',
    'end_at': null,
    'sport_id': null,
    'is_cancelled': null,
    'is_creator': true,
    'is_joined': false,
    'creator_profile_id': profileId,
  };

  Future<GameCounts> countsThroughProvider(
    List<ContributorEntity> games, {
    required bool isOwn,
  }) async {
    final ContributorProfileArgs args = (userId: userId, profileId: profileId);
    final ProviderContainer container = ProviderContainer(
      overrides: [
        contributorProfileProvider(args).overrideWith(
          (ref) async => ContributorProfileData(
            profileId: profileId,
            isOwner: isOwn,
            games: SourceData<List<ContributorEntity>>(games),
            meetups: const SourceData<List<ContributorEntity>>(
              <ContributorEntity>[],
            ),
            sports: const SourceData<List<ContributorSport>>(
              <ContributorSport>[],
            ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container.read(profileGameCountsProvider(args).future);
  }

  test(
    'own profile: null title/end/sport parses, id is the games id',
    () async {
      final List<ContributorEntity> games = gameRowsToEntities(
        <Map<String, dynamic>>[nullSharedRow()],
        isOwn: true,
        profileId: profileId,
        rostered: <String>{},
      );
      expect(games, hasLength(1));
      final ContributorEntity g = games.single;
      expect(g.kind, ContributorEntityKind.game);
      expect(g.id, gameId);
      expect(g.title, isNull);
      expect(g.sportId, isNull);
      expect(g.startAt, DateTime.utc(2026, 11, 10, 18));
      expect(g.isCancelled, isFalse);
      expect(g.isOrganiser, isTrue);
      expect(g.takesPart, isFalse);

      final GameCounts counts = await countsThroughProvider(games, isOwn: true);
      expect(counts.organised, 1);
      expect(counts.played, 0);
      expect(counts.organisedGames.single.id, gameId);
      expect(counts.organisedGames.single.title, isNull);
    },
  );

  test(
    'visitor: organiser from creator_profile_id, joined from roster ids',
    () async {
      final List<ContributorEntity> games = gameRowsToEntities(
        <Map<String, dynamic>>[
          nullSharedRow()
            ..['is_creator'] = true
            ..['creator_profile_id'] = 'someone-else'
            ..['start_at'] = '2026-01-10T18:00:00Z',
        ],
        isOwn: false,
        profileId: profileId,
        rostered: <String>{gameId},
      );
      expect(games.single.id, gameId);
      // A visitor never trusts the viewer-relative is_creator flag.
      expect(games.single.isOrganiser, isFalse);
      expect(games.single.takesPart, isTrue);

      final GameCounts counts = await countsThroughProvider(
        games,
        isOwn: false,
      );
      expect(counts.played, 1);
      expect(counts.organised, 0);
      expect(counts.upcoming, 0);
    },
  );

  test('a row without a start is skipped, never invented', () async {
    final List<ContributorEntity> games = gameRowsToEntities(
      <Map<String, dynamic>>[nullSharedRow()..['start_at'] = null],
      isOwn: true,
      profileId: profileId,
      rostered: <String>{},
    );
    expect(games, isEmpty);

    final GameCounts counts = await countsThroughProvider(games, isOwn: true);
    expect(counts.played, 0);
    expect(counts.organised, 0);
    expect(counts.upcoming, 0);
  });

  test('the live counts read selects v_game_card and maps it here', () {
    final String src = File(
      'lib/features/profile/presentation/providers/contributor_profile_provider.dart',
    ).readAsStringSync();
    expect(src.contains('.from(SupabaseConfig.vGameCardTable)'), isTrue);
    expect(src.contains('return gameRowsToEntities('), isTrue);
    expect(src.contains('return data.scope()!.counts;'), isTrue);
  });

  test('no direct write to a shared column from either surface', () {
    final RegExp write = RegExp(
      r'\.from\(\s*(SupabaseConfig\.(games|meetups|events)\w*|'
      r"'(games|meetups|events)')\s*\)\s*\.(insert|update|upsert)\(",
    );
    for (final String path in <String>[
      'lib/features/profile/presentation/providers/contributor_profile_provider.dart',
      'lib/features/profile/presentation/providers/profile_game_counts_provider.dart',
      'lib/features/profile/services/data_retention_service.dart',
    ]) {
      final String src = File(path).readAsStringSync();
      expect(write.hasMatch(src), isFalse, reason: path);
      expect(src.contains("'events'"), isFalse, reason: path);
    }
  });
}
