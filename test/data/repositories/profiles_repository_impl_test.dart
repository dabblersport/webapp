import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:dabbler/data/repositories/profiles_repository_impl.dart';
import 'package:dabbler/data/models/profile.dart';
import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/features/misc/data/datasources/supabase_remote_data_source.dart';
import 'package:dabbler/features/misc/data/datasources/supabase_error_mapper.dart';

import '../../helpers/supabase_test_client.dart';

Map<String, dynamic> profileJson({
  String id = 'p1',
  String userId = 'u1',
  String username = 'jane',
}) {
  return {
    'id': id,
    'user_id': userId,
    'profile_type': 'main',
    'username': username,
    'display_name': 'Jane Doe',
    'bio': null,
    'avatar_url': null,
    'city': null,
    'country': null,
    'language': null,
    'verified': false,
    'is_active': true,
    'created_at': '2026-08-20T10:00:00Z',
    'updated_at': '2026-08-20T10:00:00Z',
    'latitude': null,
    'longitude': null,
    'intention': null,
    'gender': null,
    'age': null,
    'preferred_sport': null,
    'interests': null,
  };
}

void main() {
  ProfilesRepositoryImpl buildRepo(
    Future<http.Response> Function(http.Request) handler,
  ) {
    final client = buildTestSupabaseClient(handler);
    final svc = SupabaseService(client, SupabaseErrorMapper());
    return ProfilesRepositoryImpl(svc);
  }

  group('getMyProfile', () {
    test('fails with AuthFailure when signed out', () async {
      final repo = buildRepo((request) async {
        fail('should not make a network call when signed out');
      });

      final result = await repo.getMyProfile();

      expect(result.isFailure, isTrue);
      expect(result.requireError, isA<AuthFailure>());
    });

    test('returns the profile for the signed-in user', () async {
      late Uri capturedUri;
      final client = buildTestSupabaseClient((request) async {
        capturedUri = request.url;
        return jsonListResponse([profileJson(userId: 'u1')], request: request);
      });
      await client.auth.setInitialSession(fakeSessionJson(userId: 'u1'));
      final repo = ProfilesRepositoryImpl(SupabaseService(client, SupabaseErrorMapper()));

      final result = await repo.getMyProfile();

      expect(result.isSuccess, isTrue);
      expect(result.requireValue.userId, 'u1');
      expect(capturedUri.queryParameters['user_id'], 'eq.u1');
      expect(capturedUri.queryParameters['is_active'], 'eq.true');
    });

    test('returns NotFoundFailure when no active profile row exists', () async {
      final client = buildTestSupabaseClient((request) async {
        return jsonListResponse(const [], request: request);
      });
      await client.auth.setInitialSession(fakeSessionJson(userId: 'u1'));
      final repo = ProfilesRepositoryImpl(SupabaseService(client, SupabaseErrorMapper()));

      final result = await repo.getMyProfile();

      expect(result.isFailure, isTrue);
      expect(result.requireError, isA<NotFoundFailure>());
    });
  });

  group('getByUserId', () {
    test('returns the profile for the given user id', () async {
      final repo = buildRepo((request) async {
        return jsonListResponse([profileJson(userId: 'other-user')], request: request);
      });

      final result = await repo.getByUserId('other-user');

      expect(result.isSuccess, isTrue);
      expect(result.requireValue.username, 'jane');
    });
  });

  group('getPublicByUsername', () {
    test('queries by username and is_active', () async {
      late Uri capturedUri;
      final repo = buildRepo((request) async {
        capturedUri = request.url;
        return jsonListResponse([profileJson(username: 'jane')], request: request);
      });

      final result = await repo.getPublicByUsername('jane');

      expect(result.isSuccess, isTrue);
      expect(result.requireValue?.username, 'jane');
      expect(capturedUri.queryParameters['username'], 'eq.jane');
      expect(capturedUri.queryParameters['is_active'], 'eq.true');
    });

    test('returns null (not a Failure) when no such username exists', () async {
      final repo = buildRepo((request) async {
        return jsonListResponse(const [], request: request);
      });

      final result = await repo.getPublicByUsername('ghost');

      expect(result.isSuccess, isTrue);
      expect(result.requireValue, isNull);
    });
  });

  group('upsert', () {
    test('rejects upserting another user\'s profile before hitting the network', () async {
      final client = buildTestSupabaseClient((request) async {
        fail('should not make a network call for a permission violation');
      });
      await client.auth.setInitialSession(fakeSessionJson(userId: 'u1'));
      final repo = ProfilesRepositoryImpl(SupabaseService(client, SupabaseErrorMapper()));

      final result = await repo.upsert(
        Profile(
          id: 'p2',
          userId: 'someone-else',
          profileType: 'main',
          username: 'x',
          displayName: 'X',
        ),
      );

      expect(result.isFailure, isTrue);
      expect(result.requireError, isA<PermissionFailure>());
    });

    test('upserts the signed-in user\'s own profile', () async {
      late http.Request captured;
      final client = buildTestSupabaseClient((request) async {
        captured = request;
        return emptyOkResponse(request: request);
      });
      await client.auth.setInitialSession(fakeSessionJson(userId: 'u1'));
      final repo = ProfilesRepositoryImpl(SupabaseService(client, SupabaseErrorMapper()));

      final result = await repo.upsert(
        Profile(
          id: 'p1',
          userId: 'u1',
          profileType: 'main',
          username: 'jane',
          displayName: 'Jane Doe',
        ),
      );

      expect(result.isSuccess, isTrue);
      expect(captured.method, 'POST');
      expect(captured.headers['Prefer'], contains('resolution=merge-duplicates'));
    });
  });

  group('deactivateMe / reactivateMe', () {
    test('deactivateMe sets is_active=false for the signed-in user', () async {
      late http.Request captured;
      final client = buildTestSupabaseClient((request) async {
        captured = request;
        return emptyOkResponse(request: request);
      });
      await client.auth.setInitialSession(fakeSessionJson(userId: 'u1'));
      final repo = ProfilesRepositoryImpl(SupabaseService(client, SupabaseErrorMapper()));

      final result = await repo.deactivateMe();

      expect(result.isSuccess, isTrue);
      expect(captured.method, 'PATCH');
      expect(captured.body, contains('"is_active":false'));
      expect(captured.url.queryParameters['user_id'], 'eq.u1');
    });

    test('reactivateMe sets is_active=true for the signed-in user', () async {
      late http.Request captured;
      final client = buildTestSupabaseClient((request) async {
        captured = request;
        return emptyOkResponse(request: request);
      });
      await client.auth.setInitialSession(fakeSessionJson(userId: 'u1'));
      final repo = ProfilesRepositoryImpl(SupabaseService(client, SupabaseErrorMapper()));

      final result = await repo.reactivateMe();

      expect(result.isSuccess, isTrue);
      expect(captured.body, contains('"is_active":true'));
    });

    test('deactivateMe fails with AuthFailure when signed out', () async {
      final repo = buildRepo((request) async {
        fail('should not make a network call when signed out');
      });

      final result = await repo.deactivateMe();

      expect(result.isFailure, isTrue);
      expect(result.requireError, isA<AuthFailure>());
    });
  });

  group('deleteSoft', () {
    test('rejects deleting another user\'s profile', () async {
      final client = buildTestSupabaseClient((request) async {
        fail('should not make a network call for a permission violation');
      });
      await client.auth.setInitialSession(fakeSessionJson(userId: 'u1'));
      final repo = ProfilesRepositoryImpl(SupabaseService(client, SupabaseErrorMapper()));

      final result = await repo.deleteSoft('someone-else');

      expect(result.isFailure, isTrue);
      expect(result.requireError, isA<PermissionFailure>());
    });
  });
}
