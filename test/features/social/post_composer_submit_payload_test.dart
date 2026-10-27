// KAN-639 R2: the CEO's exact repro goes through the real composer submit()
// and the real request-to-row mapping, and the row must satisfy every clause
// of posts_content_model_check (clauses quoted in post_content_model_test.dart).
import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/data/models/active_location.dart';
import 'package:dabbler/data/models/area.dart';
import 'package:dabbler/data/models/social/post.dart';
import 'package:dabbler/data/models/social/post_create_request.dart';
import 'package:dabbler/data/models/social/post_enums.dart';
import 'package:dabbler/data/repositories/post_repository.dart';
import 'package:dabbler/features/location/providers/active_location_provider.dart';
import 'package:dabbler/features/social/providers/post_composer_providers.dart';
import 'package:dabbler/features/social/providers/post_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../support/connectivity_overrides.dart';
import 'post_content_model_test.dart' show satisfiesContentModel;

final Post _post = Post(
  id: 'p1',
  authorProfileId: 'prof1',
  authorUserId: 'user1',
  allowReposts: true,
  authorDisplayName: 'Tester',
  kind: PostKind.original,
  visibility: PostVisibility.public,
  postType: PostType.dab,
  createdAt: DateTime(2026, 10, 24),
  updatedAt: DateTime(2026, 10, 24),
);

const Area _dubai = Area(
  id: 'a1',
  name: 'Dubai Marina',
  district: 'Dubai',
  city: 'Dubai',
  country: 'AE',
  centerLat: 25.08,
  centerLng: 55.14,
);

class _DeviceLocation extends ActiveLocationNotifier {
  @override
  Future<ActiveLocationState> build() async => ActiveLocationReady(
    const ActiveLocation(
      lat: 25.08,
      lng: 55.14,
      area: _dubai,
      source: ActiveLocationSource.gps,
    ),
  );
}

class _CapturingRepo implements PostRepository {
  PostCreateRequest? sent;

  @override
  Future<Result<Post, Failure>> createFullPost(
    PostCreateRequest request,
  ) async {
    sent = request;
    return Ok(_post);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test(
    'CEO repro: Dab, Public, Football + Motivated + venue, from Dubai',
    () async {
      final repo = _CapturingRepo();
      final c = ProviderContainer(
        overrides: [
          onlineConnectivity(),
          postRepositoryProvider.overrideWithValue(repo),
          activeLocationProvider.overrideWith(_DeviceLocation.new),
        ],
      );
      addTearDown(c.dispose);
      c.listen(postComposerProvider, (_, _) {});
      await c.read(activeLocationProvider.future);
      await Future<void>.delayed(Duration.zero);

      final n = c.read(postComposerProvider.notifier);
      n.setBody('playing football today?');
      n.setPostType(PostType.dab);
      n.setVisibility(PostVisibility.public);
      n.setSport(id: 'sport-football', name: 'Football');
      n.setVibe(id: 'vibe-motivated', label: 'Motivated');
      n.setVenue(
        id: 'venue-danube',
        name: 'Danube Sports World',
        lat: 25.1,
        lng: 55.2,
      );

      final result = await n.submit();
      expect(result.isSuccess, isTrue);

      final payload = repo.sent!.toInsertPayload(
        authorProfileId: 'prof1',
        authorUserId: 'user1',
      );
      expect(payload['origin_type'], 'manual');
      expect(payload['post_type'], 'dab');
      expect(payload['kind'], 'original');
      expect(payload['visibility'], 'public');
      expect(payload['venue_id'], 'venue-danube');
      expect(payload['sport_id'], 'sport-football');
      expect(payload['vibe_id'], 'vibe-motivated');
      expect(payload['posted_from_city'], 'Dubai');
      expect(satisfiesContentModel(payload), isTrue);
    },
  );
}
