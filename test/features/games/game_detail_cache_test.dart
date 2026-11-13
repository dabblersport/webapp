import 'package:dabbler/core/cache/offline_cache.dart';
import 'package:dabbler/features/games/presentation/controllers/game_view_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/supabase_test_client.dart';
import '../home/home_test_harness.dart';

/// KAN-605: a game detail the viewer opened shows from the on-device cache
/// first; a failed refresh behind it is silent (no error page).
void main() {
  late OfflineCache cache;

  setUpAll(initHomeTestSupabase);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    cache = OfflineCache(prefs: prefs);
  });

  GameViewController open(String account) => GameViewController(
    supabase: buildTestSupabaseClient(
      (r) async => postgrestErrorResponse(
        message: 'offline',
        code: '500',
        status: 500,
        request: r,
      ),
    ),
    gameId: 'g1',
    currentUserId: account,
    cache: cache,
    accountId: account,
  );

  Future<void> seed(String account) async {
    await cache.write(account, 'game.detail.g1', {
      'id': 'g1',
      'title': 'Five-a-side',
      'start_at': '2026-10-25T17:00:00.000Z',
      'end_at': '2026-10-25T18:00:00.000Z',
      'capacity': 10,
      'roster_count': 1,
    });
    await cache.write(account, 'game.roster.g1', [
      {
        'profile_id': 'p1',
        'user_id': 'u1',
        'role': 'host',
        'profiles': {'display_name': 'Sam', 'username': 'sam'},
      },
    ]);
  }

  test('offline: the cached game and roster show, with no error', () async {
    await seed('A');
    final c = open('A');
    addTearDown(c.dispose);
    await pumpEventQueue(times: 50);
    expect(c.state.game?.title, 'Five-a-side');
    expect(c.state.roster.single.displayName, 'Sam');
    expect(c.state.error, isNull);
  });

  test('offline with nothing cached: the existing error shows', () async {
    final c = open('A');
    addTearDown(c.dispose);
    await pumpEventQueue(times: 50);
    expect(c.state.game, isNull);
    expect(c.state.error, isNotNull);
  });

  test('another account never sees the cached game', () async {
    await seed('A');
    final c = open('B');
    addTearDown(c.dispose);
    await pumpEventQueue(times: 50);
    expect(c.state.game, isNull);
  });
}
