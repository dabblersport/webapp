// KAN-597: shared-item links. Pure unit tests: no network, no Supabase, no account. Ids are placeholders.
import 'package:dabbler/features/auth_onboarding/presentation/providers/auth_providers.dart'
    show routerRefreshNotifier;
import 'package:dabbler/utils/helpers/deep_links.dart';
import 'package:flutter_test/flutter_test.dart';

const _id = '3f1c2a9e-8b7d-4c6e-9a5f-0d1e2b3c4d5e';
const _sp = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const _prod = 'https://app.dabbler.pro';
const _alpha = 'https://alpha.dabbler.pro';

void main() {
  group('share links are built for the running environment', () {
    test('an Alpha build or web app shares an Alpha link, not production', () {
      expect(
        DeepLinks.resolveOrigin(configured: _alpha, fallback: _prod),
        _alpha,
      );
      expect(
        DeepLinks.resolveOrigin(
          configured: '',
          webOrigin: _alpha,
          fallback: _prod,
        ),
        _alpha,
      );
      // The browser's own origin wins over a stale configured value.
      expect(
        DeepLinks.resolveOrigin(
          configured: _prod,
          webOrigin: _alpha,
          fallback: _prod,
        ),
        _alpha,
      );
    });

    test(
      'nothing configured falls back to production; a trailing slash is stripped',
      () {
        expect(DeepLinks.resolveOrigin(configured: '', fallback: _prod), _prod);
        expect(
          DeepLinks.resolveOrigin(configured: '$_alpha/', fallback: _prod),
          _alpha,
        );
      },
    );

    test('a foreign, insecure or malformed origin is never used', () {
      for (final bad in [
        'https://evil.example',
        'http://app.dabbler.pro',
        'https://dabbler.pro.evil.example',
        'javascript:alert(1)',
        'not a url',
      ]) {
        expect(
          DeepLinks.resolveOrigin(
            configured: bad,
            webOrigin: bad,
            fallback: _prod,
          ),
          _prod,
          reason: bad,
        );
      }
    });

    test(
      'all five types build a link with the validated sharing profile id',
      () {
        const expected = {
          SharedItemType.game: 'game',
          SharedItemType.post: 'post',
          SharedItemType.venue: 'venue',
          SharedItemType.meetup: 'meetups',
          SharedItemType.profile: 'u',
        };
        for (final e in expected.entries) {
          expect(
            DeepLinks.link(
              origin: _alpha,
              type: e.key,
              id: _id,
              sharerProfileId: _sp,
            ),
            '$_alpha/${e.value}/$_id?sp=$_sp',
          );
          expect(
            DeepLinks.link(origin: _alpha, type: e.key, id: _id),
            '$_alpha/${e.value}/$_id',
          );
        }
      },
    );

    test(
      'an invalid sharer is dropped, an odd item id is escaped; no token ever appears',
      () {
        expect(
          DeepLinks.link(
            origin: _prod,
            type: SharedItemType.game,
            id: _id,
            sharerProfileId: 'eyJhbGciOi.token.value',
          ),
          '$_prod/game/$_id',
        );
        // An odd item id is escaped, not trusted, and the receiving side rejects it.
        final odd = DeepLinks.link(
          origin: _prod,
          type: SharedItemType.game,
          id: '../etc',
        );
        expect(odd, '$_prod/game/..%2Fetc');
        expect(DeepLinks.parse(Uri.parse(odd)), isNull);
      },
    );
  });

  group('incoming links are validated', () {
    test('each public link resolves to its in-app destination', () {
      expect(
        DeepLinks.resolve(
          Uri.parse('$_prod/game/$_id'),
          malformedFallback: '/home',
        ),
        '/sports/games/$_id',
      );
      expect(
        DeepLinks.resolve(
          Uri.parse('$_prod/venue/$_id'),
          malformedFallback: '/home',
        ),
        '/sports/venues/$_id',
      );
      expect(
        DeepLinks.resolve(
          Uri.parse('$_prod/meetups/$_id'),
          malformedFallback: '/home',
        ),
        '/meetups/$_id',
      );
      expect(
        DeepLinks.resolve(
          Uri.parse('$_prod/post/$_id'),
          malformedFallback: '/home',
        ),
        '/social-post-detail/$_id',
      );
      expect(
        DeepLinks.resolve(
          Uri.parse('$_prod/u/$_id'),
          malformedFallback: '/home',
        ),
        '/user-profile/$_id?profileId=$_id',
      );
    });

    test('the custom scheme resolves the same way as the https link', () {
      expect(
        DeepLinks.resolve(
          Uri.parse('dabbler://app/game/$_id'),
          malformedFallback: '/home',
        ),
        '/sports/games/$_id',
      );
    });

    test('the sharer rides along as attribution only, and only when valid', () {
      expect(
        DeepLinks.resolve(
          Uri.parse('$_prod/game/$_id?sp=$_sp'),
          malformedFallback: '/home',
        ),
        '/sports/games/$_id?sp=$_sp',
      );
      expect(
        DeepLinks.resolve(
          Uri.parse('$_prod/game/$_id?sp=not-a-uuid'),
          malformedFallback: '/home',
        ),
        '/sports/games/$_id',
      );
      // Unknown parameters (including anything token-like) are not carried.
      expect(
        DeepLinks.resolve(
          Uri.parse('$_prod/game/$_id?access_token=abc&sp=$_sp'),
          malformedFallback: '/home',
        ),
        '/sports/games/$_id?sp=$_sp',
      );
    });

    test('malformed or encoded destinations fall back safely', () {
      for (final bad in [
        '$_prod/game/',
        '$_prod/game/not-a-uuid',
        '$_prod/game/%2e%2e%2f%2e%2e',
        '$_prod/game/$_id%2f..%2fadmin',
        '$_prod/game/$_id/extra',
        '$_prod/post/%00',
        '$_prod/u/${_id}x',
        '$_prod/venue/$_id%20',
      ]) {
        expect(
          DeepLinks.resolve(Uri.parse(bad), malformedFallback: '/home'),
          '/home',
          reason: bad,
        );
      }
    });

    test('a path that is not a shared-item link is not claimed', () {
      expect(
        DeepLinks.resolve(
          Uri.parse('$_prod/settings'),
          malformedFallback: '/home',
        ),
        isNull,
      );
      expect(
        DeepLinks.resolve(Uri.parse(_prod), malformedFallback: '/home'),
        isNull,
      );
    });
  });

  group('the stashed link survives a login and expires if abandoned', () {
    test('a stashed link is replayed once, then gone', () {
      routerRefreshNotifier.consumePendingDeepLink();
      routerRefreshNotifier.setPendingDeepLink('/sports/games/$_id');
      expect(routerRefreshNotifier.hasPendingDeepLink, isTrue);
      expect(
        routerRefreshNotifier.consumePendingDeepLink(),
        '/sports/games/$_id',
      );
      expect(routerRefreshNotifier.hasPendingDeepLink, isFalse);
      expect(routerRefreshNotifier.consumePendingDeepLink(), isNull);
    });

    test(
      'a cancelled login leaves it available for a short while, then it expires',
      () {
        var now = DateTime.utc(2026, 10, 20, 9);
        routerRefreshNotifier.clock = () => now;
        addTearDown(() {
          routerRefreshNotifier.clock = DateTime.now;
          routerRefreshNotifier.consumePendingDeepLink();
        });
        routerRefreshNotifier.setPendingDeepLink('/meetups/$_id');
        now = now.add(const Duration(minutes: 10));
        expect(routerRefreshNotifier.hasPendingDeepLink, isTrue);
        now = now.add(const Duration(minutes: 25));
        expect(routerRefreshNotifier.hasPendingDeepLink, isFalse);
        expect(routerRefreshNotifier.consumePendingDeepLink(), isNull);
      },
    );
  });
}
