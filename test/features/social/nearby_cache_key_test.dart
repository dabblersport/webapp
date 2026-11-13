import 'package:dabbler/features/social/providers/tab_feed_notifier.dart';
import 'package:flutter_test/flutter_test.dart';

/// KAN-588: the Nearby first page is cached per city, so a change of city
/// never shows the previous city's cached posts while the new one loads.
void main() {
  test('no city keeps the plain key', () {
    expect(nearbyCacheKey(null), 'feed.nearby');
    expect(nearbyCacheKey('  '), 'feed.nearby');
  });

  test('each city has its own key under the feed. prefix', () {
    expect(nearbyCacheKey('Dubai'), 'feed.nearby.Dubai');
    expect(nearbyCacheKey('Doha'), isNot(nearbyCacheKey('Dubai')));
    expect(nearbyCacheKey('Dubai').startsWith('feed.'), isTrue);
  });
}
