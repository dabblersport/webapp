import 'package:dabbler/data/models/social/post_enums.dart';
import 'package:dabbler/features/social/providers/post_composer_providers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('KAN-592: a tagged venue keeps a manual dab post manual', () {
    final o = resolveComposerOrigin(
      originType: OriginType.manual,
      originId: null,
      postType: PostType.dab,
      gameId: null,
      venueId: 'venue-1',
    );
    expect(o.type, OriginType.manual);
    expect(o.id, isNull);
  });

  test('KAN-592: a linked game keeps a manual moment post manual', () {
    final o = resolveComposerOrigin(
      originType: OriginType.manual,
      originId: null,
      postType: PostType.moment,
      gameId: 'game-1',
      venueId: null,
    );
    expect(o.type, OriginType.manual);
  });

  test('an allocated post still takes the venue origin', () {
    final o = resolveComposerOrigin(
      originType: OriginType.manual,
      originId: null,
      postType: PostType.allocated,
      gameId: null,
      venueId: 'venue-1',
    );
    expect(o.type, OriginType.venue);
    expect(o.id, 'venue-1');
  });
}
