// KAN-612: the post create sends the request id and a retry never makes a
// second row. A fake server stands in for PostgREST: it keeps ONE post per
// (author, request_id) like the KAN-611 unique index, so a lost response
// (server created, client timed out) can be simulated without a database.
import 'dart:async';
import 'dart:convert';

import 'package:dabbler/core/data/supabase_error_mapper.dart';
import 'package:dabbler/core/data/supabase_remote_data_source.dart';
import 'package:dabbler/data/models/social/post_create_request.dart';
import 'package:dabbler/data/models/social/post_enums.dart';
import 'package:dabbler/data/repositories/post_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import '../../helpers/supabase_test_client.dart';

const String _rid = '11111111-2222-4333-8444-555555555555';

/// The fake PostgREST: posts keyed by request id, plus a log of what arrived.
class _Server {
  final Map<String, Map<String, dynamic>> byRequestId = {};
  final List<Map<String, dynamic>> posts = [];
  final List<Map<String, dynamic>> rpcBodies = [];
  int squadLinks = 0;

  /// When set, the next post INSERT is applied and then the response is lost.
  bool loseNextInsertResponse = false;

  /// The squad junction already exists (the first attempt linked it).
  bool squadAlreadyLinked = false;

  Map<String, dynamic> _row(Map<String, dynamic> body, int n) => {
    'id': 'post-$n',
    'author_profile_id': 'prof1',
    'author_user_id': 'u1',
    'kind': 'original',
    'post_type': 'dab',
    'visibility': 'public',
    'allow_reposts': true,
    'created_at': '2026-10-21T10:00:00Z',
    'updated_at': '2026-10-21T10:00:00Z',
    ...body,
  };

  Future<http.Response> handle(http.Request r) async {
    final path = r.url.path;
    http.Response json(Object body, [int status = 200]) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json'},
      request: r,
    );
    if (path.endsWith('/profiles')) {
      return json([
        {'id': 'prof1'},
      ]);
    }
    if (path.endsWith('/rpc/create_post')) {
      final body = jsonDecode(r.body) as Map<String, dynamic>;
      rpcBodies.add(body);
      final rid = body['p_request_id'] as String?;
      if (rid != null && byRequestId.containsKey(rid)) {
        return json(byRequestId[rid]!);
      }
      final row = _row({'visibility': 'circle'}, posts.length + 1);
      posts.add(row);
      if (rid != null) byRequestId[rid] = row;
      return json(row);
    }
    if (path.endsWith('/circle_members')) return json([], 201);
    if (path.endsWith('/post_squads')) {
      if (squadAlreadyLinked) {
        return json({'code': '23505', 'message': 'duplicate key'}, 409);
      }
      squadLinks++;
      squadAlreadyLinked = true;
      return json([], 201);
    }
    if (path.endsWith('/posts') && r.method == 'POST') {
      final body = jsonDecode(r.body) as Map<String, dynamic>;
      final rid = body['request_id'] as String?;
      if (rid != null && byRequestId.containsKey(rid)) {
        // The KAN-611 unique index on (author_profile_id, request_id).
        return json({
          'code': '23505',
          'message': 'duplicate key value violates unique constraint',
          'details': 'Key (author_profile_id, request_id) already exists.',
        }, 409);
      }
      final row = _row(body, posts.length + 1);
      posts.add(row);
      if (rid != null) byRequestId[rid] = row;
      if (loseNextInsertResponse) {
        loseNextInsertResponse = false;
        throw TimeoutException('response lost');
      }
      return json(row, 201);
    }
    if (path.endsWith('/posts') && r.method == 'GET') {
      final rid = r.url.queryParameters['request_id']?.replaceFirst('eq.', '');
      final hit = rid == null ? null : byRequestId[rid];
      return json(hit == null ? [] : [hit]);
    }
    return json([]);
  }
}

Future<(PostRepositoryImpl, _Server)> _repo() async {
  final server = _Server();
  final client = buildTestSupabaseClient(server.handle);
  await client.auth.setInitialSession(fakeSessionJson(userId: 'u1'));
  return (
    PostRepositoryImpl(SupabaseService(client, SupabaseErrorMapper())),
    server,
  );
}

PostCreateRequest _request({
  String? requestId,
  PostVisibility visibility = PostVisibility.public,
  String? circleId,
  String? squadId,
}) => PostCreateRequest(
  visibility: visibility,
  body: 'Padel tonight',
  circleId: circleId,
  squadId: squadId,
  requestId: requestId,
);

void main() {
  group('what is sent', () {
    test('the insert payload carries request_id; absent without one', () {
      final withId = _request(
        requestId: _rid,
      ).toInsertPayload(authorProfileId: 'p', authorUserId: 'u');
      expect(withId['request_id'], _rid);
      final without = _request().toInsertPayload(
        authorProfileId: 'p',
        authorUserId: 'u',
      );
      expect(without.containsKey('request_id'), isFalse);
    });

    test('the create_post RPC params carry p_request_id; absent without', () {
      Map<String, dynamic> params({String? id}) => buildCreatePostRpcParams(
        kind: 'original',
        postType: 'dab',
        originType: 'manual',
        media: const [],
        tags: const [],
        circleId: 'c1',
        requestId: id,
      );
      expect(params(id: _rid)['p_request_id'], _rid);
      expect(params().containsKey('p_request_id'), isFalse);
    });

    test('a circle post sends p_request_id to create_post', () async {
      final (repo, server) = await _repo();
      final r = await repo.createFullPost(
        _request(
          requestId: _rid,
          visibility: PostVisibility.circle,
          circleId: 'c1',
        ),
      );
      expect(r.isSuccess, isTrue);
      expect(server.rpcBodies.single['p_request_id'], _rid);
    });
  });

  group('lost response, then retry', () {
    test('a public post: the retry returns the first post, one row', () async {
      final (repo, server) = await _repo();
      server.loseNextInsertResponse = true;

      final first = await repo.createFullPost(_request(requestId: _rid));
      expect(first.isFailure, isTrue, reason: 'the client got a timeout');
      expect(server.posts, hasLength(1), reason: 'the server did create it');

      final retry = await repo.createFullPost(_request(requestId: _rid));
      expect(retry.isSuccess, isTrue);
      expect(retry.requireValue.id, 'post-1');
      expect(server.posts, hasLength(1), reason: 'no second post');
    });

    test('a squad post: the retry is one post and does not fail on the '
        'already-made link', () async {
      final (repo, server) = await _repo();
      server.loseNextInsertResponse = true;
      final req = _request(
        requestId: _rid,
        visibility: PostVisibility.squad,
        squadId: 's1',
      );

      final first = await repo.createFullPost(req);
      expect(first.isFailure, isTrue);
      // The first attempt made the post and then lost its response before
      // the link; the retry links it once.
      final retry = await repo.createFullPost(req);
      expect(retry.isSuccess, isTrue);
      expect(server.posts, hasLength(1));
      expect(server.squadLinks, 1);

      // A second retry finds the link already made and still succeeds.
      final again = await repo.createFullPost(req);
      expect(again.isSuccess, isTrue);
      expect(server.posts, hasLength(1));
    });

    test('a circle post: the same request id replays the first post', () async {
      final (repo, server) = await _repo();
      final req = _request(
        requestId: _rid,
        visibility: PostVisibility.circle,
        circleId: 'c1',
      );
      final first = await repo.createFullPost(req);
      final retry = await repo.createFullPost(req);
      expect(retry.requireValue.id, first.requireValue.id);
      expect(server.posts, hasLength(1));
    });

    test(
      'with no request id the unique index never applies: two posts',
      () async {
        final (repo, server) = await _repo();
        await repo.createFullPost(_request());
        await repo.createFullPost(_request());
        expect(server.posts, hasLength(2));
      },
    );

    test('a different server error is not swallowed as a replay', () async {
      final server = _Server();
      final client = buildTestSupabaseClient((r) async {
        if (r.url.path.endsWith('/posts') && r.method == 'POST') {
          return postgrestErrorResponse(
            message: 'check violation',
            code: '23514',
            status: 400,
            request: r,
          );
        }
        return server.handle(r);
      });
      await client.auth.setInitialSession(fakeSessionJson(userId: 'u1'));
      final repo = PostRepositoryImpl(
        SupabaseService(client, SupabaseErrorMapper()),
      );
      final r = await repo.createFullPost(_request(requestId: _rid));
      expect(r.isFailure, isTrue);
    });
  });
}
