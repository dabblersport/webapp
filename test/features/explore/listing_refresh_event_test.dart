import 'dart:async';

import 'package:dabbler/data/models/games/game_model.dart';
import 'package:dabbler/features/explore/presentation/widgets/listing_refresh.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// KAN-755: an event title/time/location/cancel change reaches the open
/// list/detail through one coalesced refetch; reconnect converges; a disposed
/// session never refetches. The signal carries no payload, so no private data
/// can be rendered from it, and nothing here issues a write.
void main() {
  const window = Duration(milliseconds: 50);

  test('a burst of changes costs exactly one refetch', () async {
    var fetches = 0;
    final s = ListingChangeSignal(() async => fetches++, window: window);
    for (var i = 0; i < 5; i++) {
      s.changed(); // title, time, location, cancel, title again
    }
    await Future<void>.delayed(const Duration(milliseconds: 120));
    expect(fetches, 1);
    s.dispose();
  });

  test('a change during a running refetch costs one follow-up, no more',
      () async {
    var fetches = 0;
    final gate = Completer<void>();
    final s = ListingChangeSignal(() async {
      fetches++;
      if (fetches == 1) await gate.future;
    }, window: window);
    s.changed();
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(fetches, 1); // running, held
    s.changed();
    s.changed();
    s.changed();
    gate.complete();
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(fetches, 2);
    s.dispose();
  });

  test('a reconnect converges with one refetch', () async {
    var fetches = 0;
    final s = ListingChangeSignal(() async => fetches++, window: window);
    s.reconnected();
    s.reconnected();
    await Future<void>.delayed(const Duration(milliseconds: 120));
    expect(fetches, 1);
    s.dispose();
  });

  test('a failing refetch never escapes and the next change still runs',
      () async {
    var fetches = 0;
    final s = ListingChangeSignal(() async {
      fetches++;
      throw StateError('boom');
    }, window: window);
    s.changed();
    await Future<void>.delayed(const Duration(milliseconds: 120));
    s.changed();
    await Future<void>.delayed(const Duration(milliseconds: 120));
    expect(fetches, 2);
    s.dispose();
  });

  test('a disposed session drops pending and late signals', () async {
    var fetches = 0;
    final s = ListingChangeSignal(() async => fetches++, window: window);
    s.changed();
    s.dispose(); // account switch before the timer fires
    s.changed();
    s.reconnected();
    await Future<void>.delayed(const Duration(milliseconds: 150));
    expect(fetches, 0);
  });

  test('the provider disposes its signal with the scope (account switch)',
      () async {
    var fetches = 0;
    final container = ProviderContainer();
    final signal = container.read(
      listingChangeSignalProvider(
        ListingChangeSignalArgs(
          'games',
          () async => fetches++,
          window: window,
        ),
      ),
    );
    signal.changed();
    container.dispose();
    await Future<void>.delayed(const Duration(milliseconds: 150));
    expect(fetches, 0);
  });

  test('a record with null title/end/sport parses; id fields keep meaning', () {
    final game = GameModel.fromJson({
      'id': 'g-1',
      'title': null,
      'sport': null,
      'start_at': '2026-11-05T10:00:00Z',
      'end_at': null,
      'capacity': null,
      'creator_profile_id': 'p-1',
      'listing_visibility': 'public',
      'is_cancelled': true,
    });
    expect(game.id, 'g-1');
    expect(game.organizerId, 'p-1');
  });
}
