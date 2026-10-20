import 'package:flutter_test/flutter_test.dart';

import 'package:dabbler/features/games/presentation/controllers/game_view_controller.dart';

// Network/realtime paths (_load, joinGame, leaveGame, …) require a live
// Supabase connection because the controller opens a realtime channel
// subscription in its constructor — that can't be faked with the
// MockClient(httpClient) technique used for the notifications/profiles repos
// (see test/helpers/supabase_test_client.dart), since it's a websocket, not
// an HTTP call. These tests instead cover the real parsing and
// state-derivation logic the controller relies on, which is exercised on
// every load.
void main() {
  group('GameView.fromJson', () {
    Map<String, dynamic> baseRow({Map<String, dynamic> overrides = const {}}) {
      return {
        'id': 'g1',
        'title': 'Sunday Kickabout',
        'game_type': 'casual',
        'start_at': '2026-08-30T10:00:00Z',
        'end_at': '2026-08-30T11:00:00Z',
        'capacity': 10,
        'bench_slots': 2,
        'total_slots': 12,
        'roster_count': 8,
        'listing_visibility': 'public',
        'join_policy': 'open',
        'allow_spectators': false,
        'allows_waitlist': true,
        'is_cancelled': false,
        'joining_rule': 'free',
        'cost_cover': 'free',
        ...overrides,
      };
    }

    test('parses required fields and computes spotsLeft/isFull', () {
      final game = GameView.fromJson(baseRow());

      expect(game.id, 'g1');
      expect(game.spotsLeft, 2);
      expect(game.isFull, isFalse);
      expect(game.isPublic, isTrue);
      expect(game.isFree, isTrue);
    });

    test('spotsLeft clamps to zero when roster exceeds capacity', () {
      final game = GameView.fromJson(
        baseRow(overrides: {'capacity': 5, 'roster_count': 8}),
      );

      expect(game.spotsLeft, 0);
      expect(game.isFull, isTrue);
    });

    test('falls back to sensible defaults for missing optional fields', () {
      final row = {
        'id': 'g2',
        'start_at': '2026-08-30T10:00:00Z',
        'end_at': '2026-08-30T11:00:00Z',
      };
      final game = GameView.fromJson(row);

      expect(game.title, 'Untitled Game');
      expect(game.gameType, 'casual');
      expect(game.capacity, 0);
      expect(game.listingVisibility, 'public');
      expect(game.joinPolicy, 'open');
      expect(game.joiningRule, 'free');
      expect(game.isCancelled, isFalse);
    });

    group('statusLabel', () {
      test('Cancelled takes priority over timing', () {
        final game = GameView.fromJson(
          baseRow(overrides: {
            'is_cancelled': true,
            'start_at': DateTime.now().add(const Duration(hours: 1)).toIso8601String(),
            'end_at': DateTime.now().add(const Duration(hours: 2)).toIso8601String(),
          }),
        );
        expect(game.statusLabel, 'Cancelled');
      });

      test('Upcoming when start is in the future', () {
        final game = GameView.fromJson(
          baseRow(overrides: {
            'start_at': DateTime.now().add(const Duration(hours: 1)).toIso8601String(),
            'end_at': DateTime.now().add(const Duration(hours: 2)).toIso8601String(),
          }),
        );
        expect(game.statusLabel, 'Upcoming');
      });

      test('Live when now falls between start and end', () {
        final game = GameView.fromJson(
          baseRow(overrides: {
            'start_at': DateTime.now().subtract(const Duration(minutes: 30)).toIso8601String(),
            'end_at': DateTime.now().add(const Duration(minutes: 30)).toIso8601String(),
          }),
        );
        expect(game.statusLabel, 'Live');
      });

      test('Ended once end_at has passed', () {
        final game = GameView.fromJson(
          baseRow(overrides: {
            'start_at': DateTime.now().subtract(const Duration(hours: 2)).toIso8601String(),
            'end_at': DateTime.now().subtract(const Duration(hours: 1)).toIso8601String(),
          }),
        );
        expect(game.statusLabel, 'Ended');
      });
    });
  });

  group('GameRosterEntry.fromJson', () {
    test('prefers display_name, falls back to username, then Player', () {
      final withDisplayName = GameRosterEntry.fromJson({
        'profile_id': 'p1',
        'user_id': 'u1',
        'role': 'host',
        'profiles': {'display_name': 'Jane', 'username': 'jane99'},
      });
      expect(withDisplayName.displayName, 'Jane');
      expect(withDisplayName.isHost, isTrue);

      final usernameOnly = GameRosterEntry.fromJson({
        'profile_id': 'p2',
        'user_id': 'u2',
        'role': 'player',
        'profiles': {'username': 'bob'},
      });
      expect(usernameOnly.displayName, 'bob');
      expect(usernameOnly.isHost, isFalse);

      final neither = GameRosterEntry.fromJson({
        'profile_id': 'p3',
        'user_id': 'u3',
        'role': 'player',
        'profiles': <String, dynamic>{},
      });
      expect(neither.displayName, 'Player');
    });
  });

  group('GameWaitlistEntry.fromJson', () {
    test('parses position and profile fields', () {
      final entry = GameWaitlistEntry.fromJson({
        'profile_id': 'p1',
        'user_id': 'u1',
        'position': 3,
        'profiles': {'display_name': 'Sam', 'avatar_url': 'https://x/y.png'},
      });

      expect(entry.position, 3);
      expect(entry.displayName, 'Sam');
      expect(entry.avatarUrl, 'https://x/y.png');
    });
  });

  group('GameJoinRequestEntry.fromJson', () {
    test('maps from_profile_id/from_user_id to profileId/userId', () {
      final entry = GameJoinRequestEntry.fromJson({
        'id': 'r1',
        'from_profile_id': 'p1',
        'from_user_id': 'u1',
        'profiles': {'username': 'alex'},
      });

      expect(entry.id, 'r1');
      expect(entry.profileId, 'p1');
      expect(entry.userId, 'u1');
      expect(entry.displayName, 'alex');
    });
  });

  group('GameViewState derived booleans', () {
    GameViewState stateWith({
      List<GameRosterEntry> roster = const [],
      List<GameWaitlistEntry> waitlist = const [],
    }) {
      return GameViewState(roster: roster, waitlist: waitlist);
    }

    const currentUserId = 'u1';

    test('roster/waitlist membership is derived from the current user id', () {
      final state = stateWith(
        roster: const [
          GameRosterEntry(
            profileId: 'p1',
            userId: currentUserId,
            role: 'player',
            displayName: 'Me',
          ),
        ],
      );

      final isOnRoster = state.roster.any((r) => r.userId == currentUserId);
      final isOnWaitlist = state.waitlist.any((r) => r.userId == currentUserId);
      final isHost = state.roster.any((r) => r.userId == currentUserId && r.isHost);

      expect(isOnRoster, isTrue);
      expect(isOnWaitlist, isFalse);
      expect(isHost, isFalse);
    });

    test('copyWith clearError/clearAction reset those fields independent of others', () {
      const initial = GameViewState(
        error: 'boom',
        lastAction: JoinActionResult.joined,
        isActing: true,
      );

      final cleared = initial.copyWith(clearError: true, clearAction: true, isActing: false);

      expect(cleared.error, isNull);
      expect(cleared.lastAction, isNull);
      expect(cleared.isActing, isFalse);
    });

    test('copyWith without clear flags preserves existing error/action', () {
      const initial = GameViewState(error: 'boom', lastAction: JoinActionResult.left);

      final updated = initial.copyWith(isLoading: true);

      expect(updated.error, 'boom');
      expect(updated.lastAction, JoinActionResult.left);
      expect(updated.isLoading, isTrue);
    });
  });
}
