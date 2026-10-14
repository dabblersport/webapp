import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:dabbler/data/repositories/post_repository_impl.dart';

void main() {
  group('buildCreatePostRpcParams (KAN-525)', () {
    test('sends the chosen place as the six p_ place keys', () {
      final params = buildCreatePostRpcParams(
        kind: 'moment',
        postType: 'moment',
        originType: 'manual',
        body: 'hello',
        media: <dynamic>[],
        tags: <String>[],
        circleId: 'circle-1',
        venueId: 'venue-1',
        locationName: 'Court A',
        geoLat: 25.2,
        geoLng: 55.3,
        locationTagId: 'tag-1',
        areaId: 'area-1',
      );
      expect(params['p_venue_id'], 'venue-1');
      expect(params['p_location_name'], 'Court A');
      expect(params['p_geo_lat'], 25.2);
      expect(params['p_geo_lng'], 55.3);
      expect(params['p_location_tag_id'], 'tag-1');
      expect(params['p_area_id'], 'area-1');
    });

    test('without a place sends exactly the previous map', () {
      final params = buildCreatePostRpcParams(
        kind: 'moment',
        postType: 'moment',
        originType: 'manual',
        body: 'hello',
        sportKey: 'padel',
        media: <dynamic>[],
        tags: <String>['x'],
        primaryVibeId: 'vibe-1',
        circleId: 'circle-1',
      );
      final previous = <String, dynamic>{
        'p_kind': 'moment',
        'p_visibility': 'circle',
        'p_post_type': 'moment',
        'p_origin_type': 'manual',
        'p_body': 'hello',
        'p_sport': 'padel',
        'p_media': <dynamic>[],
        'p_tags': <String>['x'],
        'p_primary_vibe_id': 'vibe-1',
        'p_vibe_ids': <String>['vibe-1'],
        'p_circle_ids': <String>['circle-1'],
      };
      expect(params, equals(previous));
      expect(params.keys.toList(), previous.keys.toList());

      final minimal = buildCreatePostRpcParams(
        kind: 'moment',
        postType: 'moment',
        originType: 'manual',
        media: <dynamic>[],
        tags: <String>[],
        circleId: 'c',
      );
      expect(minimal, {
        'p_kind': 'moment',
        'p_visibility': 'circle',
        'p_post_type': 'moment',
        'p_origin_type': 'manual',
        'p_media': <dynamic>[],
        'p_tags': <String>[],
        'p_vibe_ids': <String>[],
        'p_circle_ids': <String>['c'],
      });
    });

    test('both circle create_post call sites use the helper', () {
      final src = File(
        'lib/data/repositories/post_repository_impl.dart',
      ).readAsStringSync();
      final uses = RegExp(
        r"'create_post',\s*params:\s*buildCreatePostRpcParams\(",
      ).allMatches(src).length;
      expect(uses, 2);
      // No inline circle map remains.
      expect(src.contains("'p_visibility': 'circle'"), isTrue);
      expect(
        RegExp(r"'p_visibility': 'circle'").allMatches(src).length,
        1,
        reason: 'only the helper may build the circle create_post map',
      );
      expect(src.contains("'p_circle_ids': [request.circleId!]"), isFalse);
    });
  });
}
