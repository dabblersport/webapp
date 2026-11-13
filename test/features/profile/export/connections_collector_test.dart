import 'dart:convert';

import 'package:dabbler/features/profile/services/export/connections_collector.dart';
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

void main() {
  test('2 follows and 1 block come back with the original keys', () async {
    final requested = <String>[];
    final client = _client((req) async {
      requested.add(req.url.path);
      if (req.url.path.endsWith('/profile_follows')) {
        expect(
          req.url.queryParameters['or'],
          '(follower_profile_id.eq.$_userId,following_profile_id.eq.$_userId)',
        );
        return http.Response(
          jsonEncode([
            {'follower_profile_id': _userId, 'following_profile_id': 'p2'},
            {'follower_profile_id': 'p3', 'following_profile_id': _userId},
          ]),
          200,
          request: req,
          headers: {'content-type': 'application/json'},
        );
      }
      if (req.url.path.endsWith('/user_blocks')) {
        expect(req.url.queryParameters['blocker_user_id'], 'eq.$_userId');
        expect(
          req.url.queryParameters['select'],
          '*,profiles!blocked_user_id(name)',
        );
        return http.Response(
          jsonEncode([
            {
              'blocker_user_id': _userId,
              'blocked_user_id': 'p9',
              'profiles': {'name': 'X'},
            },
          ]),
          200,
          request: req,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response('not found', 404);
    });

    final rows = await collectConnections(client, _userId);

    expect(requested, hasLength(2));
    expect(rows, isNotNull);
    expect(rows, hasLength(3));
    const provenance = {
      'data_source': 'profile_follows, user_blocks tables',
      'purpose': 'Social connection management',
      'legal_basis': 'User consent and contract performance',
    };
    final follows = rows!.where((r) => r['connection_type'] == 'follow');
    final blocks = rows.where((r) => r['connection_type'] == 'blocked');
    expect(follows, hasLength(2));
    expect(blocks, hasLength(1));
    expect(rows[0].keys.toSet(), {
      'follower_profile_id',
      'following_profile_id',
      'connection_type',
      ...provenance.keys,
    });
    expect(rows[2].keys.toSet(), {
      'blocker_user_id',
      'blocked_user_id',
      'profiles',
      'connection_type',
      ...provenance.keys,
    });
    for (final r in rows) {
      provenance.forEach((k, v) => expect(r[k], v));
    }
  });

  test('a failed read returns null and does not throw', () async {
    final client = _client((req) async => throw http.ClientException('down'));

    final rows = await collectConnections(client, _userId);

    expect(rows, isNull);
  });
}
