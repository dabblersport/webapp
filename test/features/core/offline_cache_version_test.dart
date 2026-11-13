import 'dart:convert';
import 'dart:io';

import 'package:dabbler/core/cache/offline_cache.dart';
import 'package:dabbler/core/offline/game_codec.dart';
import 'package:dabbler/data/models/games/game.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// KAN-747: after the codec/cache version bump an older cached record is
/// discarded, never merged over event data and never read across accounts.
void main() {
  Game game({String id = 'g1'}) => Game(
    id: id,
    title: 'Five-a-side',
    description: 'd',
    sport: 'football',
    scheduledDate: DateTime.utc(2026, 11, 2),
    startTime: '18:00',
    endTime: '19:00',
    minPlayers: 6,
    maxPlayers: 10,
    currentPlayers: 4,
    organizerId: 'u1',
    skillLevel: 'mixed',
    pricePerPlayer: 12.5,
    status: GameStatus.upcoming,
    isPublic: true,
    allowsWaitlist: false,
    checkInEnabled: false,
    createdAt: DateTime.utc(2026, 10, 1, 8, 30),
    updatedAt: DateTime.utc(2026, 10, 2, 9, 45),
  );

  /// A game record exactly as the pre-KAN-747 codec wrote it: no version.
  Map<String, Object?> unversioned(Game g) =>
      Map<String, Object?>.from(encodeGame(g))..remove('v');

  group('cache', () {
    test('1. an entry written by the v1 cache is not returned', () async {
      final at = DateTime.utc(2026, 11, 1).millisecondsSinceEpoch;
      SharedPreferences.setMockInitialValues({
        'offline_cache.v1.A.games.upcoming.u1': jsonEncode({
          't': at,
          'p': [unversioned(game())],
        }),
        'offline_cache.v1.A.__index': jsonEncode({
          'games.upcoming.u1': [at, 100],
        }),
      });
      final cache = OfflineCache(prefs: await SharedPreferences.getInstance());
      expect(await cache.read('A', 'games.upcoming.u1'), isNull);
    });

    test('5. account A\'s entry is never read for account B', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final cache = OfflineCache(prefs: prefs);
      await cache.write('A', 'games.upcoming.u1', encodeGames([game()]));
      expect(await cache.read('A', 'games.upcoming.u1'), isNotNull);
      expect(await cache.read('B', 'games.upcoming.u1'), isNull);

      // Even A's stored entry copied under B's key is refused.
      final aKey = prefs.getKeys().singleWhere(
        (k) => k.endsWith('.A.games.upcoming.u1'),
      );
      final bKey = aKey.replaceFirst('.A.', '.B.');
      await prefs.setString(bKey, prefs.getString(aKey)!);
      expect(await cache.read('B', 'games.upcoming.u1'), isNull);
    });

    test('6. the cache is local only: no Supabase or network code', () async {
      for (final path in [
        'lib/core/cache/offline_cache.dart',
        'lib/core/offline/game_codec.dart',
      ]) {
        final src = File(path).readAsStringSync();
        expect(src, isNot(contains('supabase')), reason: path);
        expect(src, isNot(contains('package:http')), reason: path);
        expect(src, isNot(contains('dart:io')), reason: path);
      }
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await OfflineCache(prefs: prefs).write('A', 'k', ['p']);
      expect(
        prefs.getKeys().every((k) => k.startsWith('offline_cache.')),
        isTrue,
      );
    });
  });

  group('codec', () {
    test('2. an unversioned (old) game record is discarded, not merged', () {
      final current = game(id: 'g-new');
      final list = jsonDecode(
        jsonEncode([unversioned(game(id: 'g-old')), encodeGame(current)]),
      );
      expect(decodeGame(unversioned(game(id: 'g-old'))), isNull);
      final back = decodeGames(list);
      expect(back.map((g) => g.id), ['g-new']);
    });

    test('2b. a record from an older codec version is discarded', () {
      final older = Map<String, Object?>.from(encodeGame(game()))..['v'] = 1;
      expect(decodeGame(jsonDecode(jsonEncode(older))), isNull);
    });

    test('3. a current-version record round-trips with ids unchanged', () {
      final g = game();
      final m = encodeGame(g);
      expect(m['v'], kGameCodecVersion);
      final b = decodeGames(jsonDecode(jsonEncode([m]))).single;
      expect(b.id, 'g1');
      expect(b.organizerId, 'u1');
      expect(b.createdAt.toUtc(), DateTime.utc(2026, 10, 1, 8, 30));
      expect(b.updatedAt.toUtc(), DateTime.utc(2026, 10, 2, 9, 45));
      expect(b.scheduledDate.toUtc(), DateTime.utc(2026, 11, 2));
    });

    // In Game, title, sport and endTime are non-null; the nullable fields are
    // venueId, venueName and cancellationDeadline.
    test('4. null optional fields stay null; nothing is invented', () {
      final b = decodeGame(jsonDecode(jsonEncode(encodeGame(game()))))!;
      expect(b.venueId, isNull);
      expect(b.venueName, isNull);
      expect(b.cancellationDeadline, isNull);
    });

    test('4b. a record missing a required field is rejected, not filled', () {
      for (final field in ['title', 'sport', 'endTime']) {
        final m = Map<String, Object?>.from(encodeGame(game()))..[field] = null;
        expect(decodeGame(jsonDecode(jsonEncode(m))), isNull, reason: field);
      }
    });
  });
}
