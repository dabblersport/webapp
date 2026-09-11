import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:dabbler/features/notifications/data/notifications_repository_impl.dart';

import '../../../helpers/supabase_test_client.dart';

void main() {
  group('NotificationsRepositoryImpl.getPage', () {
    test('maps a successful page of rows to AppNotification list', () async {
      late Uri capturedUri;
      final client = buildTestSupabaseClient((request) async {
        capturedUri = request.url;
        return jsonListResponse([
          {
            'id': 'n1',
            'to_user_id': 'u1',
            'kind_key': 'games.joined',
            'title': 'You joined a game',
            'body': null,
            'action_route': null,
            'context': null,
            'priority': 'normal',
            'ai_score': null,
            'is_read': false,
            'read_at': null,
            'clicked_at': null,
            'interaction_count': 0,
            'created_at': '2026-08-20T10:00:00Z',
          },
        ], request: request);
      });

      final repo = NotificationsRepositoryImpl(client);
      final result = await repo.getPage(limit: 20);

      expect(result.isSuccess, isTrue);
      final page = result.requireValue;
      expect(page, hasLength(1));
      expect(page.first.id, 'n1');
      expect(page.first.isRead, isFalse);
      expect(capturedUri.path, contains('/notifications'));
      expect(capturedUri.queryParameters['order'], 'created_at.desc.nullslast');
      expect(capturedUri.queryParameters['limit'], '20');
    });

    test('applies the keyset cursor as a created_at lt filter', () async {
      late Uri capturedUri;
      final client = buildTestSupabaseClient((request) async {
        capturedUri = request.url;
        return jsonListResponse(const [], request: request);
      });

      final repo = NotificationsRepositoryImpl(client);
      final cursor = DateTime.utc(2026, 8, 20, 10);
      await repo.getPage(cursor: cursor);

      expect(capturedUri.queryParameters['created_at'], 'lt.2026-08-20T10:00:00.000Z');
    });

    test('a server error is mapped to a Failure instead of throwing', () async {
      final client = buildTestSupabaseClient((request) async {
        return postgrestErrorResponse(
          message: 'relation does not exist',
          status: 500,
          request: request,
        );
      });

      final repo = NotificationsRepositoryImpl(client);
      final result = await repo.getPage();

      expect(result.isFailure, isTrue);
      expect(result.requireError.message, contains('relation does not exist'));
    });
  });

  group('NotificationsRepositoryImpl.getUnreadCount', () {
    test('returns the row count for is_read = false', () async {
      final client = buildTestSupabaseClient((request) async {
        expect(request.url.queryParameters['is_read'], 'eq.false');
        return jsonListResponse([
          {'id': 'a'},
          {'id': 'b'},
          {'id': 'c'},
        ], request: request);
      });

      final repo = NotificationsRepositoryImpl(client);
      final result = await repo.getUnreadCount();

      expect(result.isSuccess, isTrue);
      expect(result.requireValue, 3);
    });
  });

  group('NotificationsRepositoryImpl.markAsRead', () {
    test('PATCHes is_read=true and read_at for the given id', () async {
      late http.Request captured;
      final client = buildTestSupabaseClient((request) async {
        captured = request;
        return emptyOkResponse(request: request);
      });

      final repo = NotificationsRepositoryImpl(client);
      final result = await repo.markAsRead('n1');

      expect(result.isSuccess, isTrue);
      expect(captured.method, 'PATCH');
      expect(captured.url.queryParameters['id'], 'eq.n1');
      expect(captured.body, contains('"is_read":true'));
    });
  });

  group('NotificationsRepositoryImpl.markClicked', () {
    test('calls the increment-interaction RPC with the notification id', () async {
      late http.Request captured;
      final client = buildTestSupabaseClient((request) async {
        captured = request;
        return emptyOkResponse(status: 200, request: request);
      });

      final repo = NotificationsRepositoryImpl(client);
      final result = await repo.markClicked('n1');

      expect(result.isSuccess, isTrue);
      expect(captured.method, 'POST');
      expect(captured.url.path, contains('/rpc/increment_notification_interaction'));
      expect(captured.body, contains('"p_id":"n1"'));
    });
  });

  group('NotificationsRepositoryImpl.markAllRead', () {
    test('fails fast when there is no authenticated user', () async {
      final client = buildTestSupabaseClient((request) async {
        fail('should not make a network call when signed out');
      });

      final repo = NotificationsRepositoryImpl(client);
      final result = await repo.markAllRead();

      expect(result.isFailure, isTrue);
      expect(result.requireError.message, contains('not authenticated'));
    });

    test('PATCHes is_read=true scoped to the current user when signed in', () async {
      late http.Request captured;
      final client = buildTestSupabaseClient((request) async {
        captured = request;
        return emptyOkResponse(request: request);
      });
      await client.auth.setInitialSession(fakeSessionJson(userId: 'u1'));

      final repo = NotificationsRepositoryImpl(client);
      final result = await repo.markAllRead();

      expect(result.isSuccess, isTrue);
      expect(captured.method, 'PATCH');
      expect(captured.url.queryParameters['to_user_id'], 'eq.u1');
      expect(captured.url.queryParameters['is_read'], 'eq.false');
    });
  });
}
