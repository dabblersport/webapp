// KAN-740 (F05, Epic KAN-708 / KAN-715): guard for direct writes to the shared
// games/meetups columns from lib/. Manifest:
// supabase/tests/events_p2/KAN715_ACTIVE_CALL_SITES.md
//
// Once events is authoritative (KAN-712) the only authorised write path is the
// RPC contract. This test pins the *known* direct-table write sites and fails
// when a new one appears, or when a known one disappears and the manifest is
// stale. It does not delete or change any of them (cleanup is out of scope).
import 'dart:io';

import 'package:dabbler/data/models/games/game_model.dart';
import 'package:flutter_test/flutter_test.dart';

/// file (relative to lib/) -> number of direct write sites on games/meetups.
const Map<String, int> _knownDirectWrites = {
  // Legacy repository: no importers anywhere in lib/ or test/ (dead code).
  'data/repositories/games_repository_impl.dart': 3,
  // Retention purge filters on a column games does not have (inventory D4).
  'features/profile/services/data_retention_service.dart': 1,
};

const String _legacyRepo = 'data/repositories/games_repository_impl.dart';

final RegExp _write = RegExp(
  r'\.from\(\s*(SupabaseConfig\.(?:games|meetups)Table|' "'games'|'meetups'|table"
  r')\s*\)\s*\.(insert|update|upsert|delete)\(',
  multiLine: true,
);

String _stripComments(String s) =>
    s.replaceAll(RegExp(r'//[^\n]*'), '').replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '');

Map<String, int> _scan() {
  final found = <String, int>{};
  final lib = Directory('lib');
  for (final e in lib.listSync(recursive: true)) {
    if (e is! File || !e.path.endsWith('.dart')) continue;
    final rel = e.path.substring('lib/'.length);
    final src = _stripComments(e.readAsStringSync());
    var n = 0;
    for (final m in _write.allMatches(src)) {
      // A bare `table` only means games in the legacy repository.
      if (m.group(1) == 'table' && rel != _legacyRepo) continue;
      n++;
    }
    if (n > 0) found[rel] = n;
  }
  return found;
}

void main() {
  test('direct games/meetups writes in lib/ match the manifest exactly', () {
    expect(
      _scan(),
      _knownDirectWrites,
      reason:
          'A direct write to games/meetups appeared or vanished. New writes must '
          'go through the authorised RPC contract (KAN-712); if a known site was '
          'removed, update this map and KAN715_ACTIVE_CALL_SITES.md.',
    );
  });

  test('meetups have no direct table writes in lib/', () {
    final meetupWrites = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .where(
          (f) => RegExp(
            r"\.from\(\s*(SupabaseConfig\.meetupsTable|'meetups')\s*\)\s*\.(insert|update|upsert|delete)\(",
          ).hasMatch(_stripComments(f.readAsStringSync())),
        )
        .map((f) => f.path)
        .toList();
    expect(meetupWrites, isEmpty);
  });

  test('legacy lib/data/repositories/games_repository_impl.dart has no importers', () {
    final importers = <String>[];
    for (final root in ['lib', 'test']) {
      for (final e in Directory(root).listSync(recursive: true)) {
        if (e is! File || !e.path.endsWith('.dart')) continue;
        if (e.path.endsWith('data/repositories/games_repository_impl.dart') &&
            e.path.startsWith('lib/data/')) {
          continue;
        }
        final src = e.readAsStringSync();
        // `package:dabbler/data/repositories/games_repository_impl.dart`, or a
        // relative import that lands in lib/data/repositories/.
        final imports = RegExp(r'''import\s+['"]([^'"]*games_repository_impl\.dart)['"]''')
            .allMatches(src)
            .map((m) => m.group(1)!);
        for (final i in imports) {
          final inLegacyDir = e.path.startsWith('lib/data/repositories/');
          if (i == 'package:dabbler/data/repositories/games_repository_impl.dart' ||
              (inLegacyDir && i == 'games_repository_impl.dart')) {
            importers.add(e.path);
          }
        }
      }
    }
    expect(importers, isEmpty);
  });

  test('a record with null title/end/sport parses; id fields keep their meaning', () {
    final game = GameModel.fromJson({
      'id': 'g-1',
      'title': null,
      'sport': null,
      'start_at': '2026-11-05T10:00:00Z',
      'end_at': null,
      'capacity': null,
      'creator_profile_id': 'p-1',
      'listing_visibility': 'public',
      'is_cancelled': false,
    });
    expect(game.id, 'g-1'); // games.id stays the game id, never an events id
    expect(game.organizerId, 'p-1'); // creator_profile_id
  });
}
