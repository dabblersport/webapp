// KAN-592: the author's posting city and the place a post is about are two
// independent things. Helpers, composer submit gate and request payload.
import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/data/models/active_location.dart';
import 'package:dabbler/data/models/area.dart';
import 'package:dabbler/data/models/social/post.dart';
import 'package:dabbler/data/models/social/post_create_request.dart';
import 'package:dabbler/data/models/social/post_enums.dart';
import 'package:dabbler/data/repositories/post_repository.dart';
import 'package:dabbler/features/location/providers/active_location_provider.dart';
import 'package:dabbler/features/social/domain/posted_from.dart';
import 'package:dabbler/features/social/providers/post_composer_providers.dart';
import 'package:dabbler/features/social/providers/post_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Post _post({
  String? locationName,
  String? postedFromCity,
  String? postedFromArea,
}) => Post(
  id: 'p1',
  authorProfileId: 'prof1',
  authorUserId: 'user1',
  allowReposts: true,
  authorDisplayName: 'Suraj Mehta',
  kind: PostKind.original,
  visibility: PostVisibility.public,
  postType: PostType.dab,
  locationName: locationName,
  postedFromCity: postedFromCity,
  postedFromArea: postedFromArea,
  createdAt: DateTime(2026, 10, 20),
  updatedAt: DateTime(2026, 10, 20),
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

ActiveLocationReady _ready() => ActiveLocationReady(
  const ActiveLocation(
    lat: 25.08,
    lng: 55.14,
    area: _marina,
    source: ActiveLocationSource.gps,
  ),
);

class _DeviceLocation extends ActiveLocationNotifier {
  _DeviceLocation(this._value);
  final ActiveLocationState _value;

  @override
  Future<ActiveLocationState> build() async => _value;
}

/// Records the request the composer sends; never touches a database.
class _FakeRepo implements PostRepository {
  PostCreateRequest? sent;

  @override
  Future<Result<Post, Failure>> createFullPost(
    PostCreateRequest request,
  ) async {
    sent = request;
    return Ok(_post());
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<(ProviderContainer, _FakeRepo)> _composer(
  ActiveLocationState device,
) async {
  final repo = _FakeRepo();
  final c = ProviderContainer(
    overrides: [
      postRepositoryProvider.overrideWithValue(repo),
      activeLocationProvider.overrideWith(() => _DeviceLocation(device)),
    ],
  );
  addTearDown(c.dispose);
  c.listen(postComposerProvider, (_, _) {});
  await c.read(activeLocationProvider.future);
  c.read(postComposerProvider.notifier).setBody('Padel tonight');
  return (c, repo);
}

void main() {
  group('header label and place tag', () {
    test('area and city', () {
      final p = _post(postedFromCity: 'Dubai', postedFromArea: 'Dubai Marina');
      expect(postedFromHeaderLabel(p), 'Dubai Marina, Dubai');
    });

    test('city alone when no area is known; none is invented', () {
      expect(
        postedFromHeaderLabel(_post(postedFromCity: 'Sharjah')),
        'Sharjah',
      );
      expect(
        postedFromHeaderLabel(
          _post(postedFromCity: 'Sharjah', postedFromArea: '  '),
        ),
        'Sharjah',
      );
    });

    test('an area equal to the city is not repeated', () {
      expect(
        postedFromHeaderLabel(
          _post(postedFromCity: 'Ajman', postedFromArea: 'Ajman'),
        ),
        'Ajman',
      );
    });

    test(
      'legacy post (never recorded) reads Dubai, rows are not rewritten',
      () {
        final legacy = _post();
        expect(isLegacyPost(legacy), isTrue);
        expect(postedFromHeaderLabel(legacy), 'Dubai');
        expect(postedFromHeaderLabel(legacy, legacyCity: 'دبي'), 'دبي');
        expect(isLegacyPost(_post(postedFromCity: '   ')), isTrue);
        expect(isLegacyPost(_post(postedFromCity: 'Dubai')), isFalse);
      },
    );

    test(
      'tag and posting city never mix: Abu Dhabi venue, posted from Dubai',
      () {
        final p = _post(
          locationName: 'Zayed Sports City, Abu Dhabi',
          postedFromCity: 'Dubai',
          postedFromArea: 'Dubai Marina',
        );
        expect(postedFromHeaderLabel(p), 'Dubai Marina, Dubai');
        expect(postPlaceTagLabel(p), 'Zayed Sports City, Abu Dhabi');
        expect(postedFromHeaderLabel(p), isNot(contains('Abu Dhabi')));
      },
    );

    test(
      'a stored tag on a legacy post is kept; the header is still Dubai',
      () {
        final p = _post(locationName: 'Marina Padel Club');
        expect(postedFromHeaderLabel(p), 'Dubai');
        expect(postPlaceTagLabel(p), 'Marina Padel Club');
      },
    );

    test('no tag, blank tag: no pill, and never the posting city', () {
      expect(postPlaceTagLabel(_post(postedFromCity: 'Dubai')), isNull);
      expect(
        postPlaceTagLabel(_post(locationName: '  ', postedFromCity: 'Dubai')),
        isNull,
      );
    });
  });

  group('device location to posting origin', () {
    test('ready: area and city', () {
      expect(
        postedFromOfActive(_ready()),
        const PostedFrom(city: 'Dubai', area: 'Dubai Marina'),
      );
    });

    test('city-only: the city, no area', () {
      expect(
        postedFromOfActive(ActiveLocationCityOnly('Sharjah')),
        const PostedFrom(city: 'Sharjah'),
      );
    });

    test('denied, loading, error, null: nothing', () {
      expect(postedFromOfActive(ActiveLocationDenied()), isNull);
      expect(postedFromOfActive(ActiveLocationLoading()), isNull);
      expect(postedFromOfActive(ActiveLocationError('x')), isNull);
      expect(postedFromOfActive(null), isNull);
    });
  });

  group('composer submit', () {
    test('TC1 city known: posting city defaults from the device', () async {
      final (c, repo) = await _composer(_ready());
      final result = await c.read(postComposerProvider.notifier).submit();
      expect(result.isSuccess, isTrue);
      expect(repo.sent!.postedFromCity, 'Dubai');
      expect(repo.sent!.postedFromArea, 'Dubai Marina');
    });

    test('city-only device state posts with the city and no area', () async {
      final (c, repo) = await _composer(ActiveLocationCityOnly('Sharjah'));
      await c.read(postComposerProvider.notifier).submit();
      expect(repo.sent!.postedFromCity, 'Sharjah');
      expect(repo.sent!.postedFromArea, isNull);
    });

    test('TC2 denied: nothing is sent, the draft is untouched, a city is asked '
        'for', () async {
      final (c, repo) = await _composer(ActiveLocationDenied());
      final n = c.read(postComposerProvider.notifier);
      n.setRawLocation(name: 'Zayed Sports City');
      final result = await n.submit();
      expect(result.isFailure, isTrue);
      expect(result.requireError.message, kPostedFromRequired);
      expect(repo.sent, isNull);
      final s = c.read(postComposerProvider);
      expect(s.body, 'Padel tonight');
      expect(s.locationName, 'Zayed Sports City');
      expect(s.error, isNull);
      expect(s.isSubmitting, isFalse);
    });

    test('after choosing a city the same draft posts with it', () async {
      final (c, repo) = await _composer(ActiveLocationDenied());
      final n = c.read(postComposerProvider.notifier);
      await n.submit();
      n.setPostedFrom(const PostedFrom(city: 'Abu Dhabi'));
      final result = await n.submit();
      expect(result.isSuccess, isTrue);
      expect(repo.sent!.postedFromCity, 'Abu Dhabi');
      expect(repo.sent!.body, 'Padel tonight');
    });

    test('an explicit city wins over the device city', () async {
      final (c, repo) = await _composer(_ready());
      final n = c.read(postComposerProvider.notifier);
      n.setPostedFrom(const PostedFrom(city: 'Sharjah'));
      await n.submit();
      expect(repo.sent!.postedFromCity, 'Sharjah');
      expect(repo.sent!.postedFromArea, isNull);
    });

    test('TC3 Abu Dhabi venue tag while posted from Dubai: both are sent, '
        'separately', () async {
      final (c, repo) = await _composer(_ready());
      final n = c.read(postComposerProvider.notifier);
      n.setRawLocation(name: 'Zayed Sports City, Abu Dhabi');
      await n.submit();
      expect(repo.sent!.locationName, 'Zayed Sports City, Abu Dhabi');
      expect(repo.sent!.postedFromCity, 'Dubai');
      expect(repo.sent!.postedFromArea, 'Dubai Marina');
    });

    test('TC4 removing the tag leaves the posting city unchanged', () async {
      final (c, repo) = await _composer(_ready());
      final n = c.read(postComposerProvider.notifier);
      n.setPostedFrom(const PostedFrom(city: 'Sharjah'));
      n.setRawLocation(name: 'Zayed Sports City, Abu Dhabi');
      n.clearLocation();
      expect(c.read(postComposerProvider).locationName, isNull);
      expect(n.resolvePostedFrom(), const PostedFrom(city: 'Sharjah'));
      await n.submit();
      expect(repo.sent!.locationName, isNull);
      expect(repo.sent!.postedFromCity, 'Sharjah');
    });

    test('tagging a place never sets the posting city', () async {
      final (c, _) = await _composer(ActiveLocationDenied());
      final n = c.read(postComposerProvider.notifier);
      n.setRawLocation(name: 'Zayed Sports City, Abu Dhabi');
      expect(n.resolvePostedFrom(), isNull);
    });
  });

  group('insert payload', () {
    test('posting city and tagged place are separate columns', () {
      final payload = const PostCreateRequest(
        visibility: PostVisibility.public,
        locationName: 'Zayed Sports City, Abu Dhabi',
        postedFromCity: 'Dubai',
        postedFromArea: 'Dubai Marina',
      ).toInsertPayload(authorProfileId: 'prof', authorUserId: 'user');
      expect(payload['location_name'], 'Zayed Sports City, Abu Dhabi');
      expect(payload['posted_from_city'], 'Dubai');
      expect(payload['posted_from_area'], 'Dubai Marina');
    });

    test('no city, no keys: an old row shape is not invented', () {
      final payload = const PostCreateRequest(
        visibility: PostVisibility.public,
      ).toInsertPayload(authorProfileId: 'prof', authorUserId: 'user');
      expect(payload.containsKey('posted_from_city'), isFalse);
      expect(payload.containsKey('posted_from_area'), isFalse);
    });
  });
}
