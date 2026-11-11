import 'dart:convert';

import 'package:dabbler/features/profile/services/export/media_location_collectors.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _userId = 'u-1';

SupabaseClient _client(MockClientHandler handler) => SupabaseClient(
  'http://fake.local',
  'anon-key',
  httpClient: MockClient(handler),
);

http.Response _json(http.Request req, Object body) => http.Response(
  jsonEncode(body),
  200,
  request: req,
  headers: {'content-type': 'application/json'},
);

SupabaseClient _throwing() =>
    _client((req) async => throw http.ClientException('down'));

void main() {
  group('collectMediaMetadata', () {
    test('two rows come back with the original keys', () async {
      final client = _client((req) async {
        expect(req.url.path, endsWith('/post_media'));
        expect(
          req.url.queryParameters['select'],
          'media_type,url,posts!inner(author)',
        );
        expect(req.url.queryParameters['posts.author'], 'eq.$_userId');
        return _json(req, [
          {
            'media_type': 'image',
            'url': 'a',
            'posts': {'author': _userId},
          },
          {
            'media_type': 'video',
            'url': 'b',
            'posts': {'author': _userId},
          },
        ]);
      });

      final rows = await collectMediaMetadata(client, _userId);

      expect(rows, hasLength(2));
      for (final r in rows!) {
        expect(r.keys.toSet(), {
          'media_type',
          'url',
          'posts',
          'data_source',
          'purpose',
          'legal_basis',
          'note',
        });
        expect(r['data_source'], 'post_media table (joined via posts.author)');
        expect(r['purpose'], 'Profile and content management');
        expect(r['legal_basis'], 'User consent');
        expect(
          r['note'],
          'Only media attached to your posts is included - metadata only, actual files not exported for security',
        );
      }
    });

    test('a failed read returns null and does not throw', () async {
      expect(await collectMediaMetadata(_throwing(), _userId), isNull);
    });
  });

  group('collectLocationData', () {
    test('two rows come back with the original keys', () async {
      final client = _client((req) async {
        expect(req.url.path, endsWith('/profile_locations'));
        expect(
          req.url.queryParameters['select'],
          'lat,lng,label,area_id,geo_location_id,is_primary',
        );
        expect(req.url.queryParameters['profile_id'], 'eq.$_userId');
        expect(req.url.queryParameters['order'], 'is_primary.desc.nullslast');
        Map<String, Object?> row(bool primary) => {
          'lat': 1.0,
          'lng': 2.0,
          'label': 'Home',
          'area_id': 'a',
          'geo_location_id': 'g',
          'is_primary': primary,
        };
        return _json(req, [row(true), row(false)]);
      });

      final rows = await collectLocationData(client, _userId);

      expect(rows, hasLength(2));
      for (final r in rows!) {
        expect(r.keys.toSet(), {
          'lat',
          'lng',
          'label',
          'area_id',
          'geo_location_id',
          'is_primary',
          'data_source',
          'purpose',
          'legal_basis',
          'note',
        });
        expect(r['data_source'], 'profile_locations table');
        expect(r['purpose'], 'Location-based game matching and services');
        expect(r['legal_basis'], 'User consent');
        expect(
          r['note'],
          'Only approximate locations stored - precise coordinates not retained',
        );
      }
    });

    test('a failed read returns null and does not throw', () async {
      expect(await collectLocationData(_throwing(), _userId), isNull);
    });
  });
}
