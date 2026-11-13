import 'package:dabbler/data/models/social/post_create_request.dart';
import 'package:dabbler/data/models/social/post_enums.dart';
import 'package:dabbler/features/social/providers/post_composer_providers.dart';
import 'package:flutter_test/flutter_test.dart';

/// The rules of `posts_content_model_check`, read from the live schema
/// (pg_get_constraintdef, KAN-592 rework). A row passes when ANY branch holds.
bool satisfiesContentModel(Map<String, dynamic> row) {
  final origin = row['origin_type'];
  final type = row['post_type'];
  final kind = row['kind'];
  return (origin == 'manual' &&
          const ['moment', 'dab', 'kick_in'].contains(type) &&
          kind == 'original') ||
      (origin == 'system' &&
          type == 'allocated' &&
          const [
            'news',
            'announcement',
            'alert',
            'highlight',
            'general',
            'feature',
          ].contains(kind)) ||
      (origin == 'venue' &&
          type == 'allocated' &&
          const ['announcement', 'commercial'].contains(kind)) ||
      (origin == 'game' &&
          type == 'allocated' &&
          const ['general', 'highlight'].contains(kind)) ||
      (origin == 'repost' && kind == 'original');
}

/// The insert payload the composer builds: the same resolver and request that
/// `PostComposerNotifier.submit` uses.
Map<String, dynamic> composerPayload({
  required PostType postType,
  String? venueId,
  String? gameId,
  String? locationName,
}) {
  final origin = resolveComposerOrigin(originType: OriginType.manual);
  return PostCreateRequest(
    visibility: PostVisibility.public,
    postType: postType,
    body: 'Great session',
    venueId: venueId,
    gameId: gameId,
    locationName: locationName,
    postedFromCity: 'Dubai',
    originType: origin.type,
    originId: origin.id,
  ).toInsertPayload(authorProfileId: 'profile-1', authorUserId: 'user-1');
}

void main() {
  test(
    'KAN-592: Dubai origin + Abu Dhabi venue tag satisfies posts_content_model_check',
    () {
      for (final type in [PostType.moment, PostType.dab, PostType.kickIn]) {
        final p = composerPayload(
          postType: type,
          venueId: 'abu-dhabi-padel-hub',
          locationName: 'Abu Dhabi Padel Hub',
        );
        expect(satisfiesContentModel(p), isTrue, reason: '${type.name}: $p');
        expect(p['origin_type'], 'manual');
        expect(p['kind'], 'original');
        // Both concepts travel in the same row, independently.
        expect(p['posted_from_city'], 'Dubai');
        expect(p['venue_id'], 'abu-dhabi-padel-hub');
        expect(p['location_name'], 'Abu Dhabi Padel Hub');
      }
    },
  );

  test('KAN-592: a tagged place and a linked game also satisfy the check', () {
    final p = composerPayload(
      postType: PostType.dab,
      venueId: 'v1',
      gameId: 'g1',
      locationName: 'Abu Dhabi Padel Hub',
    );
    expect(satisfiesContentModel(p), isTrue, reason: '$p');
  });

  test('the model rejects the pairing that failed before the fix', () {
    expect(
      satisfiesContentModel({
        'origin_type': 'venue',
        'post_type': 'dab',
        'kind': 'original',
      }),
      isFalse,
    );
  });
}
