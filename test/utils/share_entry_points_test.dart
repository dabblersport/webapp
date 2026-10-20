// KAN-597 (CEO test on alpha.dabbler.pro): copying a post copied its bare id, and sharing a venue said "coming soon".
// Every share/copy entry point must produce the full web link that the KAN-597 routes open. Pure unit tests.
import 'dart:io';

import 'package:dabbler/utils/helpers/deep_links.dart';
import 'package:dabbler/utils/helpers/share_links.dart';
import 'package:flutter_test/flutter_test.dart';

const _id = '3f1c2a9e-8b7d-4c6e-9a5f-0d1e2b3c4d5e';
const _sp = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';

String _read(String path) => File(path).readAsStringSync();

void main() {
  group('ShareLinks builds a full https link for every shared item type', () {
    final origin = ShareLinks.origin();
    test('the origin is an allowed Dabbler https origin', () {
      expect(DeepLinks.isAllowedOrigin(origin), isTrue);
    });

    test('post, venue, game, meetup and profile', () {
      expect(ShareLinks.post(_id), '$origin/post/$_id');
      expect(ShareLinks.venue(_id), '$origin/venue/$_id');
      expect(ShareLinks.game(_id), '$origin/game/$_id');
      expect(ShareLinks.meetup(_id), '$origin/meetups/$_id');
      expect(ShareLinks.profile(_id), '$origin/u/$_id');
    });

    test('the sharer rides along as attribution, only when it is a UUID', () {
      expect(
        ShareLinks.post(_id, sharerProfileId: _sp),
        '$origin/post/$_id?sp=$_sp',
      );
      expect(
        ShareLinks.post(_id, sharerProfileId: 'not-a-uuid'),
        '$origin/post/$_id',
      );
    });

    test('every produced link parses back to the same item', () {
      final uri = Uri.parse(ShareLinks.post(_id, sharerProfileId: _sp));
      final item = DeepLinks.parse(uri)!;
      expect(item.type, SharedItemType.post);
      expect(item.id, _id);
      expect(item.sharerProfileId, _sp);
    });
  });

  group('no share/copy entry point hands out a bare id or a stub', () {
    test('post detail copies the full link, never post.id', () {
      final src = _read(
        'lib/features/social/presentation/screens/post_detail_screen.dart',
      );
      expect(src, isNot(contains('ClipboardData(text: post.id)')));
      expect(src, contains('ShareLinks.post('));
    });

    test('venue detail shares the venue link, not "coming soon"', () {
      final src = _read(
        'lib/features/venues/presentation/screens/venue_detail_screen.dart',
      );
      expect(src, isNot(contains('Sharing coming soon')));
      expect(src, contains('ShareLinks.venue('));
    });

    test('the other profile offers a copy-link built by ShareLinks.profile', () {
      final src = _read(
        'lib/features/profile/presentation/screens/profile/user_profile_screen.dart',
      );
      expect(src, contains('ShareLinks.profile('));
    });

    test('game and meetup share through the environment-aware builders', () {
      for (final f in [
        'lib/features/games/presentation/screens/join_game/game_detail_screen.dart',
        'lib/features/games/presentation/widgets/games_listing_card.dart',
        'lib/features/meetups/presentation/screens/meetup_detail_screen.dart',
        'lib/features/meetups/presentation/widgets/meetup_listing_card.dart',
      ]) {
        expect(
          _read(f),
          anyOf(
            contains('RoutePaths.gameLink('),
            contains('RoutePaths.meetupLink('),
          ),
          reason: f,
        );
      }
    });
  });
}
