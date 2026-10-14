// KAN-492: a post persists the chosen place's name and its TRUE area; a post
// with no place carries no area (never the fixed Nad Al Sheba fallback).
// Drives the real PostComposerNotifier.submit() with a fake repository.
import 'dart:io';

import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/core/services/gps_service.dart';
import 'package:dabbler/data/models/area.dart';
import 'package:dabbler/data/models/social/post.dart';
import 'package:dabbler/data/models/social/post_create_request.dart';
import 'package:dabbler/data/repositories/area_repository_v2.dart';
import 'package:dabbler/data/repositories/post_repository.dart';
import 'package:dabbler/features/social/providers/post_composer_providers.dart';
import 'package:dabbler/features/social/providers/post_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import 'composer_locate_test.mocks.dart';

const _nasFallback = 'a0000000-0000-0000-0000-000000000007';

class _Repo implements PostRepository {
  PostCreateRequest? last;
  @override
  Future<Result<Post, Failure>> createFullPost(PostCreateRequest r) async {
    last = r;
    return const Err(Failure(category: FailureCode.validation, message: 'x'));
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

Area _area(String id, String name, double lat, double lng) => Area(
  id: id,
  name: name,
  district: 'Dubai',
  city: 'Dubai',
  country: 'AE',
  centerLat: lat,
  centerLng: lng,
);

final _nas = _area('area-nas', 'Nad Al Sheba', 25.15, 55.31);
final _marina = _area('area-marina', 'Dubai Marina', 25.08, 55.14);

late _Repo _repo;
late ProviderContainer _c;

PostComposerNotifier _setUp() {
  _repo = _Repo();
  final gps = MockGpsService();
  final areas = MockAreaRepository();
  when(gps.getCurrentLocation(cap: GpsService.fixCap)).thenAnswer(
    (_) async => LocationSuccess(lat: 25.08, lng: 55.14, accuracyMeters: 5),
  );
  when(areas.resolveNearest(25.08, 55.14)).thenAnswer((_) async => _marina);
  when(areas.resolveNearest(25.15, 55.31)).thenAnswer((_) async => _nas);
  _c = ProviderContainer(
    overrides: [
      postRepositoryProvider.overrideWithValue(_repo),
      gpsServiceProvider.overrideWithValue(gps),
      areaRepositoryV2Provider.overrideWithValue(areas),
    ],
  );
  addTearDown(_c.dispose);
  _c.listen(postComposerProvider, (_, __) {});
  return _c.read(postComposerProvider.notifier)..setBody('Padel tonight');
}

Future<Map<String, dynamic>> _submit(PostComposerNotifier n) async {
  await n.submit();
  final p = _repo.last!.toInsertPayload(
    authorProfileId: 'P',
    authorUserId: 'U',
  );
  expect(p.values, isNot(contains(_nasFallback)));
  return p;
}

void main() {
  test('(a) venue in Nad Al Sheba: name + the venue\'s own area', () async {
    final n = _setUp();
    n.setVenue(
      id: 'venue-nas',
      name: 'Nad Al Sheba Sports Complex',
      lat: 25.15,
      lng: 55.31,
      areaId: 'area-nas',
    );
    final p = await _submit(n);
    expect(p['location_name'], 'Nad Al Sheba Sports Complex');
    expect(p['venue_id'], 'venue-nas');
    expect(p['area_id'], 'area-nas');
  });

  test('(b) venue in Dubai Marina: name + Marina area, not NAS', () async {
    final n = _setUp();
    n.setVenue(
      id: 'venue-marina',
      name: 'Marina Padel Club',
      lat: 25.08,
      lng: 55.14,
      areaId: 'area-marina',
    );
    final p = await _submit(n);
    expect(p['location_name'], 'Marina Padel Club');
    expect(p['area_id'], 'area-marina');
  });

  test('(b2) venue without a client-side area resolves from its own '
      'coordinates', () async {
    final n = _setUp();
    n.setVenue(
      id: 'venue-marina',
      name: 'Marina Padel Club',
      lat: 25.08,
      lng: 55.14,
    );
    final p = await _submit(n);
    expect(p['area_id'], 'area-marina');
  });

  test('(c) use current location resolving to Dubai Marina', () async {
    final n = _setUp();
    await n.useCurrentLocation(fallbackName: 'Current location');
    final p = await _submit(n);
    expect(p['location_name'], 'Dubai Marina');
    expect(p['area_id'], 'area-marina');
    expect(p['location_tag_id'], 'area-marina');
    expect(p['geo_lat'], 25.08);
  });

  test(
    '(d) typed place without coordinates: name only, area key absent',
    () async {
      final n = _setUp();
      n.setRawLocation(name: 'JLT Cluster D');
      final p = await _submit(n);
      expect(p['location_name'], 'JLT Cluster D');
      expect(p.containsKey('area_id'), isFalse);
      expect(p.containsKey('geo_lat'), isFalse);
    },
  );

  test('(e) no place: no location keys and no area_id key', () async {
    final n = _setUp();
    final p = await _submit(n);
    for (final k in [
      'area_id',
      'location_name',
      'location_tag_id',
      'venue_id',
      'geo_lat',
      'geo_lng',
    ]) {
      expect(p.containsKey(k), isFalse, reason: k);
    }
  });

  test('(f) clearing the place after choosing one clears the area', () async {
    final n = _setUp();
    n.setVenue(
      id: 'venue-marina',
      name: 'Marina Padel Club',
      lat: 25.08,
      lng: 55.14,
      areaId: 'area-marina',
    );
    n.clearLocation();
    expect(_c.read(postComposerProvider).areaId, isNull);
    final p = await _submit(n);
    expect(p.containsKey('area_id'), isFalse);
    expect(p.containsKey('location_name'), isFalse);
  });

  test('(g) setRawLocation keeps the area/tag it is given, and a new place '
      'never inherits the previous area', () async {
    final n = _setUp();
    n.setRawLocation(
      name: 'Dubai Marina',
      areaId: 'area-marina',
      locationTagId: 'area-marina',
    );
    var s = _c.read(postComposerProvider);
    expect(s.areaId, 'area-marina');
    expect(s.locationTagId, 'area-marina');
    n.setRawLocation(name: 'JLT Cluster D');
    s = _c.read(postComposerProvider);
    expect(s.areaId, isNull);
    expect(s.locationTagId, isNull);
    n.setVenue(
      id: 'v',
      name: 'Nad Al Sheba Sports Complex',
      areaId: 'area-nas',
    );
    s = _c.read(postComposerProvider);
    expect(s.areaId, 'area-nas');
    expect(s.locationName, 'Nad Al Sheba Sports Complex');
  });

  test('no Nad Al Sheba fallback area id literal exists under lib/', () {
    final hits = <String>[];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is File && f.path.endsWith('.dart')) {
        if (f.readAsStringSync().contains(_nasFallback)) hits.add(f.path);
      }
    }
    expect(hits, isEmpty);
  });
}
