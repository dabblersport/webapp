import 'package:dabbler/features/games/presentation/providers/nearby_games_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('games list opens with no distance filter', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    expect(c.read(nearbyGamesFilterEnabledProvider), isFalse);
  });

  test('a picked distance stays applied', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    c.read(nearbyGamesFilterEnabledProvider.notifier).state = true;
    c.read(gamesRadiusProvider.notifier).state = 10000;
    expect(c.read(nearbyGamesFilterEnabledProvider), isTrue);
    expect(c.read(gamesRadiusProvider), 10000);
  });
}
