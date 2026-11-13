// KAN-743 (Events P3, KAN-715 R03): the nearby and following game paths read
// the event-backed projections KAN-723 (B04) and KAN-720 (B01) converted.
//
// B04 (supabase/migrations/20261104100400_kan714_b04_rpc_nearby_following.sql)
// keeps rpc_get_nearby_games' and rpc_games_following_joined's names and result
// columns; `id` / `game_id` are still games.id and no event_id is returned.
// These tests pin that contract on the Dart side: event-backed nulls parse, the
// game id stays the identity, and these files only read.
import 'dart:io';

import 'package:dabbler/core/config/supabase_config.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/features/games/data/models/nearby_game_model.dart';
import 'package:dabbler/features/games/data/repositories/games_following_repository.dart';
import 'package:flutter_test/flutter_test.dart';

const _gameId = '11111111-1111-1111-1111-111111111111';
const _eventId = '22222222-2222-2222-2222-222222222222';

const _datasourcePath =
    'lib/features/games/data/datasources/nearby_games_datasource.dart';
const _followingRepoPath =
    'lib/features/games/data/repositories/games_following_repository.dart';

/// A row as an event-backed read may return it: shared facts null.
Map<String, dynamic> _eventBackedRow() => {
  'id': _gameId,
  // Not returned by B04; present here to prove it can never become the id.
  'event_id': _eventId,
  'title': null,
  'sport_name': null,
  'scheduled_at': '2026-11-10T18:00:00Z',
  'end_at': null,
  'status': 'upcoming',
  'venue_name': null,
  'latitude': null,
  'longitude': null,
  'distance_meters': 1200.5,
  'player_count': 3,
  'spots_remaining': 7,
  'is_public': true,
  'min_skill': null,
  'max_skill': null,
  'variant_name_en': null,
  'variant_name_ar': null,
  'cost_cover': null,
  'joining_rule': null,
  'host_verified': false,
  'favorite_count': 0,
  'favourited_by_me': false,
  'price_aed': null,
};

/// A table or view read off the Supabase client (not `Map.from`).
final _clientFrom = RegExp(r'client\s*\.from\(');

/// Every write a Supabase query builder can issue.
final _writeCall = RegExp(r'\.(insert|update|upsert|delete)\s*\(');

void main() {
  group('NearbyGameModel parses an event-backed row', () {
    test('null title, end_at and sport parse; nothing else is invented', () {
      final m = NearbyGameModel.fromJson(_eventBackedRow());

      expect(m.sportName, isNull);
      expect(m.endAt, isNull);
      expect(m.durationMinutes, isNull, reason: 'no end, no length');
      expect(m.venueName, isNull);
      expect(m.minSkill, isNull);
      expect(m.maxSkill, isNull);
      expect(m.priceAed, isNull, reason: 'null price stays "Ask", not 0');
      expect(m.formatName('en'), isNull);
      // The RPC itself coalesces a null title to this label
      // (B04:142 coalesce(e.title, 'Untitled Game')); the model mirrors it
      // for the view path and the cache, and adds no other value.
      expect(m.title, 'Untitled Game');
      expect(
        m.scheduledAt,
        DateTime.parse('2026-11-10T18:00:00Z').toLocal(),
      ); // KAN-927
    });

    test('game id stays the id; an event id is never taken for it', () {
      final m = NearbyGameModel.fromJson(_eventBackedRow());

      expect(m.id, _gameId);
      expect(m.id, isNot(_eventId));
      // Round trip through the on-device cache keeps the game id and does
      // not carry an event id B04 does not return.
      final cached = m.toJson();
      expect(cached['id'], _gameId);
      expect(cached.containsKey('event_id'), isFalse);
      expect(cached['end_at'], isNull);
      expect(cached['sport_name'], isNull);
      expect(NearbyGameModel.fromJson(cached).id, _gameId);
    });

    test('favourite and following merges keep the game id', () {
      final m = NearbyGameModel.fromJson(_eventBackedRow());

      expect(m.withFavourite(favourited: true, count: 1).id, _gameId);
      expect(m.withFollowing(2).id, _gameId);
      expect(m.withFollowing(2).endAt, isNull);
    });
  });

  group('following repository reads the converted RPC by game id', () {
    test(
      'calls rpc_games_following_joined with game ids; keys by game id',
      () async {
        final calls = <(String, Map<String, dynamic>)>[];
        final repo = SupabaseGamesFollowingRepository(
          rpc: (fn, params) async {
            calls.add((fn, params));
            return [
              {'game_id': _gameId, 'following_count': 2},
            ];
          },
          signedIn: () => true,
        );

        final result = await repo.getFollowingJoined([_gameId]);

        expect(calls, hasLength(1));
        expect(calls.single.$1, 'rpc_games_following_joined');
        expect(calls.single.$2, {
          'p_game_ids': [_gameId],
        });
        expect((result as Ok<Map<String, int>, dynamic>).value, {_gameId: 2});
      },
    );
  });

  group('names are the ones B01/B04 converted', () {
    test('config constants', () {
      expect(SupabaseConfig.vGameCardTable, 'v_game_card');
      expect(
        SupabaseConfig.gamesFollowingJoinedRpc,
        'rpc_games_following_joined',
      );
    });
  });

  group('source: reads only, through the converted names', () {
    final datasource = File(_datasourcePath).readAsStringSync();
    final followingRepo = File(_followingRepoPath).readAsStringSync();

    test('nearby datasource calls rpc_get_nearby_games by rpc', () {
      expect(
        RegExp(r"\.rpc\(\s*'rpc_get_nearby_games'").hasMatch(datasource),
        isTrue,
      );
    });

    test('nearby datasource reads v_game_card only through select', () {
      final fromCalls = RegExp(
        r'\.from\(\s*SupabaseConfig\.vGameCardTable\s*\)\s*\.select\(',
      ).allMatches(datasource);
      expect(fromCalls.length, 2, reason: 'getAllGames + getMyUpcomingGames');
      expect(
        _clientFrom.allMatches(datasource).length,
        2,
        reason: 'no other table or view is touched',
      );
    });

    test('no insert, update, upsert or delete in either file', () {
      expect(_writeCall.hasMatch(datasource), isFalse);
      expect(_writeCall.hasMatch(followingRepo), isFalse);
    });

    test('following repository calls only the configured RPC', () {
      expect(followingRepo, contains('SupabaseConfig.gamesFollowingJoinedRpc'));
      expect(_clientFrom.hasMatch(followingRepo), isFalse);
    });

    test('neither file reads event_id as an identity', () {
      expect(datasource.contains('event_id'), isFalse);
      expect(followingRepo.contains('event_id'), isFalse);
    });
  });
}
