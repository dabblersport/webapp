import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/features/messaging/data/fake_messaging_repository.dart';
import 'package:dabbler/features/messaging/domain/models/my_conversation.dart';
import 'package:dabbler/features/messaging/domain/typed_reason.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> _row({
  Object? id = 'c1',
  Object? gameId = 'g1',
  Object? state = 'send',
}) => {
  'conversation_id': id,
  'game_id': gameId,
  'game_title': 'Friday football',
  'sport': 'Football',
  'start_at': '2026-10-17T19:00:00Z',
  'end_at': '2026-10-17T21:00:00Z',
  'state': state,
  'last_activity_at': '2026-10-15T11:55:00Z',
};

void main() {
  group('MyConversation.parse', () {
    test('a valid RPC row parses every field', () {
      final r = MyConversation.parse(_row());
      expect(r.isSuccess, isTrue);
      final c = r.requireValue;
      expect(c.conversationId, 'c1');
      expect(c.gameId, 'g1');
      expect(c.title, 'Friday football');
      expect(c.sport, 'Football');
      expect(c.startAt, DateTime.utc(2026, 10, 17, 19));
      expect(c.endAt, DateTime.utc(2026, 10, 17, 21));
      expect(c.state, MyConversationState.send);
      expect(c.lastActivityAt, DateTime.utc(2026, 10, 15, 11, 55));
      expect(MyConversation.parse(c.toJson()).requireValue, c);
    });

    test('all three states parse', () {
      expect(
        MyConversation.parse(_row(state: 'read_only')).requireValue.state,
        MyConversationState.readOnly,
      );
      expect(
        MyConversation.parse(_row(state: 'left')).requireValue.state,
        MyConversationState.left,
      );
    });

    test('malformed payloads return a Failure, never throw', () {
      for (final bad in <Object?>[
        null,
        'x',
        42,
        <String, Object?>{},
        _row(id: null),
        _row(id: ''),
        _row(id: 7),
        _row(gameId: null),
        _row(state: null),
        _row(state: 'kicked'),
      ]) {
        late Result<MyConversation, Object> r;
        expect(() => r = MyConversation.parse(bad), returnsNormally);
        expect(r.isFailure, isTrue, reason: '$bad');
        expect(r.requireError, isA<MessagingFailure>());
      }
    });

    test('optional fields are nullable-safe', () {
      final r = MyConversation.parse({
        'conversation_id': 'c1',
        'game_id': 'g1',
        'state': 'left',
        'game_title': null,
        'sport': 3,
        'start_at': 'not a date',
        'end_at': null,
      });
      final c = r.requireValue;
      expect(c.title, isNull);
      expect(c.sport, isNull);
      expect(c.startAt, isNull);
      expect(c.endAt, isNull);
      expect(c.lastActivityAt, isNull);
    });

    test('parseList keeps order; one malformed row fails the list', () {
      final ok = MyConversation.parseList([
        _row(id: 'a', gameId: 'ga'),
        _row(id: 'b', gameId: 'gb'),
      ]);
      expect(ok.requireValue.map((c) => c.gameId), ['ga', 'gb']);
      expect(
        MyConversation.parseList([_row(), _row(state: 'x')]).isFailure,
        isTrue,
      );
      expect(MyConversation.parseList({'a': 1}).isFailure, isTrue);
    });
  });

  group('FakeMessagingRepository.listMyConversations', () {
    MyConversation c(String id, DateTime? at) => MyConversation(
      conversationId: 'c-$id',
      gameId: id,
      state: MyConversationState.send,
      lastActivityAt: at,
    );

    test('newest activity first, nulls last, limited', () async {
      final repo = FakeMessagingRepository()
        ..seedMyConversations([
          c('a', DateTime.utc(2026, 1, 1)),
          c('n', null),
          c('b', DateTime.utc(2026, 3, 1)),
        ]);
      final all = (await repo.listMyConversations()).requireValue;
      expect(all.map((x) => x.gameId), ['b', 'a', 'n']);
      final one = (await repo.listMyConversations(limit: 1)).requireValue;
      expect(one.map((x) => x.gameId), ['b']);
    });

    test('failNext fails once, then succeeds', () async {
      final repo = FakeMessagingRepository()
        ..failNextMyConversations(MessagingReason.offline);
      expect((await repo.listMyConversations()).isFailure, isTrue);
      expect((await repo.listMyConversations()).requireValue, isEmpty);
      expect(repo.myConversationsCalls, 2);
    });
  });
}
