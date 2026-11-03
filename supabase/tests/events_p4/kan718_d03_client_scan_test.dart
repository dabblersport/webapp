// KAN-771 (KAN-718 D03, Epic KAN-708): static scan of lib/ for client reads
// of the columns phase 4 would drop from games/meetups ("slated columns").
// Matrix and verdict: supabase/tests/events_p4/KAN718_D03_OLD_CLIENT_MATRIX.md
//
// The slated set is read from the KAN-711 mapping functions (the legacy
// columns copied into events), so it cannot drift from the migration. The
// test pins every direct games/meetups table read in lib/ exactly: a new one
// fails, a removed one fails until the matrix is updated. While any read
// remains, the matrix must say deletion is BLOCKED. Nothing is changed.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const String _mirror =
    'supabase/migrations/20261102110000_kan711_events_mirror_triggers.sql';
const String _matrix =
    'supabase/tests/events_p4/KAN718_D03_OLD_CLIENT_MATRIX.md';

/// file (relative to lib/) -> the direct `games` table reads in it, as
/// `op(projection)` in source order. `*` reads every slated column.
const Map<String, List<String>> _knownGamesReads = {
  'data/repositories/post_repository_impl.dart': [
    'select(id, title, sport, game_type, start_at, end_at)',
  ],
  'features/games/data/datasources/supabase_games_datasource.dart': [
    'stream(id)',
    'select(capacity)',
    'select(*)',
    'select(*)',
    'select(*)',
    'select(*)',
    'select(id)',
    'select(*)',
    'select(*)',
    'select(*)',
    'select(*, game_favorites!inner(user_id))',
    'select(*, game_roster!inner(user_id))',
    'select(capacity)',
  ],
  'features/profile/presentation/providers/sport_profile_view_provider.dart': [
    'select(id, is_cancelled, start_at)',
  ],
  'features/profile/services/data_export_service.dart': [
    'select(*, game_roster!inner(user_id, joined_at, status, role))',
    'select()',
  ],
  'features/profile/services/data_retention_service.dart': ['delete()'],
};

/// file -> number of PostgREST embeds of games (`game:games(...)`) that read
/// slated columns through another table.
const Map<String, int> _knownGamesEmbeds = {
  'features/games/data/datasources/bookings_datasource.dart': 6,
  'features/games/data/datasources/venues_datasource.dart': 1,
};

/// Files that open a Realtime subscription on games/meetups. The payload is
/// ignored (a change only triggers a reload), so they depend on no column.
const Set<String> _knownLegacyRealtime = {
  'data/repositories/games_repository_impl.dart', // dead file (KAN-740)
  'features/explore/presentation/widgets/listing_refresh.dart',
  'features/games/presentation/controllers/game_view_controller.dart',
};

String _strip(String s) => s
    .replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '')
    .replaceAll(RegExp(r'(^|\s)//[^\n]*'), r'$1');

Iterable<(String, String)> _libFiles() sync* {
  for (final e in Directory('lib').listSync(recursive: true)) {
    if (e is File && e.path.endsWith('.dart')) {
      yield (e.path.substring('lib/'.length), _strip(e.readAsStringSync()));
    }
  }
}

/// Legacy columns copied into events by `kan711_events_map_<type>`, minus `id`
/// (retained: the subtype id is the route key).
Set<String> _slated(String type, String alias) {
  final sql = File(_mirror).readAsStringSync();
  final body = RegExp(
    'CREATE FUNCTION public\\.kan711_events_map_$type\\([\\s\\S]*?\\\$\\\$;',
  ).firstMatch(sql)!.group(0)!;
  return RegExp('\\b$alias\\.([a-z_]+)')
      .allMatches(body.replaceAll(RegExp(r'--[^\n]*'), ''))
      .map((m) => m.group(1)!)
      .where((c) => c != 'id')
      .toSet();
}

/// PostgREST embeds of [table] (`game:games(title)`, `games!inner(id)`)
/// inside string literals, where a select projection lives.
int _embeds(String src, String table) {
  final literals = RegExp(r"'''[\s\S]*?'''|'[^'\n]*'").allMatches(src);
  final embed = RegExp('(?:[\\s,:(]|\\x27)$table(?:![a-z_]+)?\\(');
  return literals.fold(0, (n, m) => n + embed.allMatches(m.group(0)!).length);
}

final RegExp _gamesFrom = RegExp(
  r"\.from\(\s*(?:SupabaseConfig\.gamesTable|'games')\s*\)",
);
final RegExp _meetupsFrom = RegExp(
  r"\.from\(\s*(?:SupabaseConfig\.meetupsTable|'meetups')\s*\)",
);

String _op(String after) {
  final m = RegExp(
    r"^\s*\.(select|stream|delete|insert|update|upsert)\(\s*(?:primaryKey:\s*\[)?"
    r"(?:'''([\s\S]*?)'''|'([^']*)')?",
  ).firstMatch(after);
  if (m == null) return 'unknown';
  final proj = (m.group(2) ?? m.group(3) ?? '').replaceAll(RegExp(r'\s+'), ' ');
  return '${m.group(1)}(${proj.trim()})';
}

Map<String, List<String>> _scanGamesReads() {
  final found = <String, List<String>>{};
  for (final (rel, src) in _libFiles()) {
    final ops = [
      for (final m in _gamesFrom.allMatches(src)) _op(src.substring(m.end)),
    ];
    if (ops.isNotEmpty) found[rel] = ops;
  }
  return found;
}

void main() {
  final slatedGames = _slated('game', 'g');
  final slatedMeetups = _slated('meetup', 'm');

  test('slated columns come from the KAN-711 mapping and match the matrix', () {
    expect(slatedGames, {
      'creator_profile_id',
      'creator_user_id',
      'title',
      'start_at',
      'end_at',
      'capacity',
      'listing_visibility',
      'join_policy',
      'is_cancelled',
      'cancelled_at',
      'cancelled_reason',
      'sport_id',
      'area_id',
      'geo_location_id',
      'venue_id',
      'min_skill',
      'max_skill',
      'joining_rule',
      'cost_cover',
      'request_id',
      'created_at',
      'updated_at',
    });
    expect(slatedMeetups, {
      ...slatedGames.difference({
        'join_policy',
        'cancelled_at',
        'cancelled_reason',
      }),
      'rsvp_policy',
    });
    final doc = File(_matrix).readAsStringSync();
    for (final c in {...slatedGames, ...slatedMeetups}) {
      expect(doc, contains('`$c`'), reason: 'matrix omits slated column $c');
    }
  });

  test('direct games table reads in lib/ match the matrix exactly', () {
    expect(
      _scanGamesReads(),
      _knownGamesReads,
      reason:
          'A direct games read appeared or vanished. Record it in '
          'KAN718_D03_OLD_CLIENT_MATRIX.md and in this map together.',
    );
  });

  test('every pinned read touches a slated column', () {
    final selects = {
      for (final ops in _knownGamesReads.values) ...ops,
    }.where((o) => o.startsWith('select(') && !o.contains('*'));
    for (final o in selects.where(
      (o) => o != 'select()' && o != 'select(id)',
    )) {
      final cols = o.substring(7, o.length - 1).split(',').map((c) => c.trim());
      expect(cols.any(slatedGames.contains), isTrue, reason: o);
    }
    // select(id) and the stream filter on other slated columns
    // (creator_user_id; GameModel.fromJson over every column): the matrix
    // records the filters, so they are not re-derived here.
  });

  test('games embeds through other tables match the matrix', () {
    final found = <String, int>{};
    for (final (rel, src) in _libFiles()) {
      final n = _embeds(src, 'games');
      if (n > 0) found[rel] = n;
    }
    expect(found, _knownGamesEmbeds);
  });

  test('meetups: no direct table read and no embed in lib/', () {
    final hits = [
      for (final (rel, src) in _libFiles())
        if (_meetupsFrom.hasMatch(src) || _embeds(src, 'meetups') > 0) rel,
    ];
    expect(hits, isEmpty);
  });

  test('Realtime subscriptions on games/meetups are pinned and column-free', () {
    final found = <String>{};
    for (final (rel, src) in _libFiles()) {
      if (!src.contains('onPostgresChanges(')) continue;
      final legacy = RegExp(
        r"SupabaseConfig\.(games|meetups)Table|'(games|meetups)'",
      ).hasMatch(src);
      if (legacy) found.add(rel);
    }
    expect(found, _knownLegacyRealtime);
    // The only filter on a legacy table is on `id`, which is retained.
    final gv = _strip(
      File(
        'lib/features/games/presentation/controllers/game_view_controller.dart',
      ).readAsStringSync(),
    );
    expect(gv, contains("(table: SupabaseConfig.gamesTable, column: 'id')"));
  });

  test('while any client read remains, the matrix blocks deletion', () {
    final doc = File(_matrix).readAsStringSync();
    final reads = _scanGamesReads().values.fold<int>(0, (a, l) => a + l.length);
    expect(reads, greaterThan(0));
    expect(doc, contains('VERDICT: DELETION BLOCKED'));
    expect(doc, isNot(contains('VERDICT: DELETION SAFE')));
  });
}
