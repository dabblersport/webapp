// KAN-618: the post composer owns one client request id per create attempt.
// It is held and exposed only; the repository call is unchanged.
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

final Post _post = Post(
  id: 'p1',
  authorProfileId: 'prof1',
  authorUserId: 'user1',
  allowReposts: true,
  authorDisplayName: 'Suraj Mehta',
  kind: PostKind.original,
  visibility: PostVisibility.public,
  postType: PostType.dab,
  createdAt: DateTime(2026, 10, 21),
  updatedAt: DateTime(2026, 10, 21),
);

const Area _marina = Area(
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
      area: _marina,
      source: ActiveLocationSource.gps,
    ),
  );
}

/// Records the composer's request id at each call; fails while [fail] is set.
class _FakeRepo implements PostRepository {
  _FakeRepo(this._requestId);
  final String? Function() _requestId;
  final List<String?> ids = <String?>[];
  bool fail = false;

  @override
  Future<Result<Post, Failure>> createFullPost(
    PostCreateRequest request,
  ) async {
    ids.add(_requestId());
    if (fail) {
      return const Err(
        Failure(category: FailureCode.noInternet, message: 'No internet'),
      );
    }
    return Ok(_post);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<(ProviderContainer, _FakeRepo)> _composer() async {
  late ProviderContainer c;
  final repo = _FakeRepo(() => c.read(postComposerProvider.notifier).requestId);
  c = ProviderContainer(
    overrides: [
      postRepositoryProvider.overrideWithValue(repo),
      activeLocationProvider.overrideWith(_DeviceLocation.new),
    ],
  );
  addTearDown(c.dispose);
  c.listen(postComposerProvider, (_, _) {});
  await c.read(activeLocationProvider.future);
  c.read(postComposerProvider.notifier).setBody('Padel tonight');
  return (c, repo);
}

void main() {
  test('the id is null until the first Create tap, then exposed', () async {
    final (c, repo) = await _composer();
    final n = c.read(postComposerProvider.notifier);
    expect(n.requestId, isNull);
    await n.submit();
    // Success cleared it; the repository saw one id during the call.
    expect(repo.ids.single, isNotNull);
    expect(n.requestId, isNull);
  });

  test('criterion 3: after a failure the retry reuses the same id', () async {
    final (c, repo) = await _composer();
    final n = c.read(postComposerProvider.notifier);
    repo.fail = true;
    final failed = await n.submit();
    expect(failed.isFailure, isTrue);
    final first = n.requestId;
    expect(first, isNotNull);
    // The form is kept.
    expect(c.read(postComposerProvider).body, 'Padel tonight');

    await n.submit();
    expect(repo.ids, [first, first]);
    expect(n.requestId, first);
  });

  test('criterion 4: success clears the id; the next create is new', () async {
    final (c, repo) = await _composer();
    final n = c.read(postComposerProvider.notifier);
    repo.fail = true;
    await n.submit();
    final failedId = n.requestId;

    repo.fail = false;
    final ok = await n.submit();
    expect(ok.isSuccess, isTrue);
    expect(repo.ids.last, failedId);
    expect(n.requestId, isNull);

    await n.submit();
    expect(repo.ids.last, isNotNull);
    expect(repo.ids.last, isNot(failedId));
  });

  test(
    'criterion 5: editing the form after a failure gives a new id',
    () async {
      final (c, repo) = await _composer();
      final n = c.read(postComposerProvider.notifier);
      repo.fail = true;
      await n.submit();
      final first = n.requestId;

      n.setBody('Padel tomorrow');
      expect(n.requestId, isNull);
      await n.submit();
      expect(repo.ids.last, isNotNull);
      expect(repo.ids.last, isNot(first));
    },
  );

  test('criterion 5: a rebuilt field edit also ends the attempt', () async {
    final (c, repo) = await _composer();
    final n = c.read(postComposerProvider.notifier);
    repo.fail = true;
    await n.submit();
    final first = n.requestId;

    n.setSport(id: 'sport-1', name: 'Padel');
    n.clearSport();
    expect(n.requestId, isNull);
    await n.submit();
    expect(repo.ids.last, isNot(first));
  });

  test('criterion 5: discarding the composer clears the id', () async {
    final (c, repo) = await _composer();
    final n = c.read(postComposerProvider.notifier);
    repo.fail = true;
    await n.submit();
    expect(n.requestId, isNotNull);

    n.discard();
    expect(n.requestId, isNull);
  });

  test(
    'closing the composer disposes the notifier; a new one has a new id',
    () async {
      final (c, repo) = await _composer();
      repo.fail = true;
      final first = c.read(postComposerProvider.notifier);
      await first.submit();
      final firstId = first.requestId;
      expect(firstId, isNotNull);

      c.invalidate(postComposerProvider);
      final second = c.read(postComposerProvider.notifier);
      expect(second.requestId, isNull);
      second.setBody('Padel tonight');
      await second.submit();
      expect(repo.ids.last, isNot(firstId));
    },
  );

  test(
    'criterion 6: two Create taps in one frame make one submission',
    () async {
      final (c, repo) = await _composer();
      final n = c.read(postComposerProvider.notifier);
      final first = n.submit();
      final second = n.submit();
      final results = await Future.wait([first, second]);
      expect(repo.ids, hasLength(1));
      expect(results[0].isSuccess, isTrue);
      expect(results[1].isFailure, isTrue);
      expect(results[1].requireError.category, FailureCode.cancelled);
    },
  );

  test('isSubmitting and error changes are not edits', () async {
    final (c, repo) = await _composer();
    final n = c.read(postComposerProvider.notifier);
    repo.fail = true;
    await n.submit();
    final first = n.requestId;
    // submit() itself flipped isSubmitting and error; the id survived both.
    expect(c.read(postComposerProvider).error, 'No internet');
    expect(first, isNotNull);
  });
}
