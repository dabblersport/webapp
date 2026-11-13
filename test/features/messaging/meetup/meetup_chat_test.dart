import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:dabbler/features/messaging/data/fake_messaging_repository.dart';
import 'package:dabbler/features/messaging/data/messaging_http_client.dart';
import 'package:dabbler/features/messaging/data/unavailable_messaging_repository.dart';
import 'package:dabbler/features/messaging/data/worker_messaging_repository.dart';
import 'package:dabbler/features/messaging/domain/models/conversation.dart';
import 'package:dabbler/features/messaging/domain/typed_reason.dart';
import 'package:dabbler/features/messaging/presentation/meetup_chat_route.dart';
import 'package:dabbler/features/messaging/presentation/providers/meetup_chat_providers.dart';
import 'package:dabbler/features/messaging/presentation/providers/messaging_providers.dart';
import 'package:dabbler/features/messaging/presentation/view_models/game_chat_view_state.dart';

import '../support/fake_backend.dart';

/// KAN-928: the meetup chat opens over `GET /v1/meetups/{id}/conversation`
/// (kind meetup, meetup_id in place of game_id) and is otherwise the game chat.
const _base = 'https://worker.example.invalid';

const _meetupJson = {
  'id': 'c9',
  'kind': 'meetup',
  'meetup_id': 'mt1',
  'writable': true,
  'muted': false,
  'last_seq': 2,
};

WorkerMessagingRepository _worker(
  http.Response Function(http.Request) handler,
  List<http.Request> seen,
) => WorkerMessagingRepository(
  http: MessagingHttpClient(
    client: MockClient((req) async {
      seen.add(req);
      return handler(req);
    }),
    tokenSupplier: () async => 'tok-1',
    baseUrl: _base,
    timeout: const Duration(milliseconds: 200),
  ),
  rpc: (fn, params) async => const <Object>[],
);

http.Response _json(int status, Object body) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);

void main() {
  group('Conversation.fromJson', () {
    test('a game conversation keeps game_id and no meetup', () {
      final c = Conversation.fromJson({
        'id': 'c1',
        'kind': 'game',
        'game_id': 'g1',
        'writable': true,
        'muted': false,
        'last_seq': 3,
      });
      expect(c.gameId, 'g1');
      expect(c.meetupId, isNull);
      expect(c.toJson()['kind'], 'game');
    });

    test('a meetup conversation reads meetup_id and has no game', () {
      final c = Conversation.fromJson(Map.of(_meetupJson));
      expect(c.meetupId, 'mt1');
      expect(c.gameId, '');
      expect(c.lastSeq, 2);
      final back = c.toJson();
      expect(back['kind'], 'meetup');
      expect(back['meetup_id'], 'mt1');
      expect(back.containsKey('game_id'), isFalse);
      expect(Conversation.fromJson(back), c);
    });

    test('a meetup payload without meetup_id is malformed', () {
      final bad = Map<String, dynamic>.of(_meetupJson)..remove('meetup_id');
      expect(() => Conversation.fromJson(bad), throwsFormatException);
    });
  });

  group('WorkerMessagingRepository.getMeetupConversation', () {
    test('GET /v1/meetups/{id}/conversation with the bearer; parses', () async {
      final seen = <http.Request>[];
      final repo = _worker((_) => _json(200, _meetupJson), seen);
      final r = await repo.getMeetupConversation('mt1');
      expect(r.isSuccess, isTrue, reason: '$r');
      expect(r.requireValue.meetupId, 'mt1');
      expect(r.requireValue.id, 'c9');
      final req = seen.single;
      expect(req.method, 'GET');
      expect(req.url.path, '/v1/meetups/mt1/conversation');
      expect(req.headers['Authorization'], 'Bearer tok-1');
    });

    test('403 not_a_member is the typed reason', () async {
      final repo = _worker(
        (_) => _json(403, {
          'error': {'reason': 'not_a_member'},
        }),
        [],
      );
      final r = await repo.getMeetupConversation('mt1');
      expect(
        (r.requireError as MessagingFailure).reason,
        MessagingReason.notAMember,
      );
    });

    test('the unavailable build answers not_in_pilot', () async {
      final r = await const UnavailableMessagingRepository()
          .getMeetupConversation('mt1');
      expect(
        (r.requireError as MessagingFailure).reason,
        MessagingReason.notInPilot,
      );
    });
  });

  group('MeetupChatController (fake)', () {
    ProviderContainer container(FakeMessagingRepository repo) {
      final c = ProviderContainer(
        overrides: [
          fakeMessagingBackend,
          fakeMessagingRepositoryProvider.overrideWithValue(repo),
          gameChatPollIntervalProvider.overrideWithValue(null),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    test('opens the meetup conversation with its messages', () async {
      final repo = FakeMessagingRepository()
        ..seedMeetupConversation('mt1', messageCount: 3);
      final c = container(repo);
      final view = await c.read(meetupChatControllerProvider('mt1').future);
      expect(view.status, GameChatStatus.ready);
      expect(view.conversation?.meetupId, 'mt1');
      expect(view.items.length, 3);
    });

    test('a sent message lands in the meetup conversation', () async {
      final repo = FakeMessagingRepository()..seedMeetupConversation('mt1');
      final c = container(repo);
      await c.read(meetupChatControllerProvider('mt1').future);
      await c.read(meetupChatControllerProvider('mt1').notifier).send('hi');
      final view = c.read(meetupChatControllerProvider('mt1')).requireValue;
      expect(view.items.single.body, 'hi');
      expect(view.conversation?.meetupId, 'mt1');
      final again = await repo.getMeetupConversation('mt1');
      expect(again.requireValue.lastSeq, 1);
      expect(again.requireValue.meetupId, 'mt1');
    });

    test('an unknown meetup is not found, never a game chat', () async {
      final repo = FakeMessagingRepository()..seedGameConversation('mt1');
      final c = container(repo);
      final view = await c.read(meetupChatControllerProvider('mt1').future);
      expect(view.status, isNot(GameChatStatus.ready));
      expect(view.reason, MessagingReason.notFound);
    });

    test('the route path and location', () {
      expect(meetupChatRoutePath, '/meetups/:meetupId/chat');
      expect(meetupChatLocation('mt1'), '/meetups/mt1/chat');
    });
  });
}
