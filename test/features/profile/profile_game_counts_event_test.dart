import 'dart:io';

import 'package:dabbler/features/games/presentation/controllers/game_counts.dart';
import 'package:dabbler/features/profile/presentation/providers/profile_game_counts_provider.dart';
import 'package:flutter_test/flutter_test.dart';

// KAN-744 (KAN-715 R04): the profile counts read v_game_card, whose shared
// columns come from public.events since KAN-720 (B01). Event-backed rows may
// carry null title / end_at / sport_id; the games id stays the row id.
void main() {
  const String gameId = '11111111-1111-1111-1111-111111111111';
  const String profileId = '22222222-2222-2222-2222-222222222222';

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

  test('own profile: null title/end/sport parses, id is the games id', () {
    final List<GameCountRow> rows = rowsToGameCountRows(
      <Map<String, dynamic>>[nullSharedRow()],
      isOwn: true,
      profileId: profileId,
      rostered: <String>{},
    );
    expect(rows, hasLength(1));
    final GameCountRow r = rows.single;
    expect(r.id, gameId);
    expect(r.title, isNull);
    expect(r.startAt, DateTime.utc(2026, 11, 10, 18));
    expect(r.isCancelled, isFalse);
    expect(r.isOrganiser, isTrue);
    expect(r.participation, isNull);
  });

  test('visitor: organiser from creator_profile_id, joined from roster ids', () {
    final List<GameCountRow> rows = rowsToGameCountRows(
      <Map<String, dynamic>>[
        nullSharedRow()
          ..['is_creator'] = false
          ..['creator_profile_id'] = 'someone-else',
      ],
      isOwn: false,
      profileId: profileId,
      rostered: <String>{gameId},
    );
    expect(rows.single.id, gameId);
    expect(rows.single.isOrganiser, isFalse);
    expect(rows.single.participation, GameParticipation.joined);
  });

  test('a row without a start is skipped, never invented', () {
    final List<GameCountRow> rows = rowsToGameCountRows(
      <Map<String, dynamic>>[nullSharedRow()..['start_at'] = null],
      isOwn: true,
      profileId: profileId,
      rostered: <String>{},
    );
    expect(rows, isEmpty);
  });

  test('no direct write to a shared column from either surface', () {
    final RegExp write = RegExp(
      r'\.from\(\s*(SupabaseConfig\.(games|meetups|events)\w*|'
      r"'(games|meetups|events)')\s*\)\s*\.(insert|update|upsert)\(",
    );
    for (final String path in <String>[
      'lib/features/profile/presentation/providers/profile_game_counts_provider.dart',
      'lib/features/profile/services/data_retention_service.dart',
    ]) {
      final String src = File(path).readAsStringSync();
      expect(write.hasMatch(src), isFalse, reason: path);
      expect(src.contains("'events'"), isFalse, reason: path);
    }
  });
}
