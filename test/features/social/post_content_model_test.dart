// KAN-639: the composer's insert payload must satisfy the database's
// posts_content_model_check. Read from Supabase (project wtncuzcskpigqpmnxwws,
// read-only) on 2026-10-24:
//
//   CHECK (
//     (origin_type = 'manual' AND post_type IN ('moment','dab','kick_in')
//        AND kind = 'original')
//     OR (origin_type = 'system' AND post_type = 'allocated'
//        AND kind IN ('news','announcement','alert','highlight','general','feature'))
//     OR (origin_type = 'venue' AND post_type = 'allocated'
//        AND kind IN ('announcement','commercial'))
//     OR (origin_type = 'game' AND post_type = 'allocated'
//        AND kind IN ('general','highlight'))
//     OR (origin_type = 'repost' AND kind = 'original'))
import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/data/models/social/post_create_request.dart';
import 'package:dabbler/data/models/social/post_enums.dart';
import 'package:dabbler/features/social/providers/post_composer_providers.dart';
import 'package:flutter_test/flutter_test.dart';

bool satisfiesContentModel(Map<String, dynamic> p) {
  final origin = p['origin_type'];
  final type = p['post_type'];
  final kind = p['kind'];
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

/// What the composer builds in submit(): origin through the resolver, the rest
/// as the request defaults.
Map<String, dynamic> composerPayload({
  String? body,
  String? venueId,
  String? gameId,
  String? sportId,
  String? vibeId,
  List<dynamic>? media,
  PostType postType = PostType.dab,
}) {
  final origin = resolveComposerOrigin(originType: OriginType.manual);
  return PostCreateRequest(
    visibility: PostVisibility.public,
    postType: postType,
    body: body,
    media: media,
    sportId: sportId,
    vibeId: vibeId,
    venueId: venueId,
    gameId: gameId,
    originType: origin.type,
    originId: origin.id,
    postedFromCity: 'Dubai',
  ).toInsertPayload(authorProfileId: 'p', authorUserId: 'u');
}

void main() {
  postFailureTextTests();
  test(
    'repro post (Dab, Public, Football, Motivated, venue) fits the check',
    () {
      final p = composerPayload(
        body: 'playing football today?',
        sportId: 'sport',
        vibeId: 'vibe',
        venueId: 'venue',
      );
      expect(p['origin_type'], 'manual');
      expect(p['post_type'], 'dab');
      expect(p['kind'], 'original');
      expect(p['venue_id'], 'venue');
      expect(satisfiesContentModel(p), isTrue);
    },
  );

  test('before the fix a venue made the origin venue and broke the check', () {
    final old = composerPayload(body: 'x', venueId: 'venue')
      ..['origin_type'] = 'venue';
    expect(satisfiesContentModel(old), isFalse);
  });

  test('text-only, text+media, game-linked and every user post type fit', () {
    for (final t in [PostType.moment, PostType.dab, PostType.kickIn]) {
      expect(
        satisfiesContentModel(
          composerPayload(body: 'hello there', postType: t),
        ),
        isTrue,
        reason: t.name,
      );
    }
    expect(
      satisfiesContentModel(
        composerPayload(
          body: 'hello there',
          media: [
            {'url': 'u', 'type': 'image'},
          ],
        ),
      ),
      isTrue,
    );
    expect(
      satisfiesContentModel(composerPayload(body: 'hi there', gameId: 'g')),
      isTrue,
    );
  });
}

void postFailureTextTests() {
  test('a database refusal is not shown as raw text', () {
    const raw = Failure(
      category: FailureCode.validation,
      message:
          'new row for relation "posts" violates check constraint '
          '"posts_content_model_check"',
    );
    expect(composerFailureText(raw), kPostFailed);
    expect(
      composerFailureText(
        const Failure(
          category: FailureCode.unknown,
          message: 'PostgrestException(...)',
        ),
      ),
      kPostFailed,
    );
  });

  test('a connection failure keeps its own words', () {
    const f = Failure(category: FailureCode.noInternet, message: 'No internet');
    expect(composerFailureText(f), 'No internet');
  });
}
