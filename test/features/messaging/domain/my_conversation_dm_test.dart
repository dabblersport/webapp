import 'package:flutter_test/flutter_test.dart';

import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/features/messaging/domain/models/my_conversation.dart';
import 'package:dabbler/features/messaging/domain/typed_reason.dart';

// KAN-562: msg_my_conversations v2 (KAN-555) columns.
Map<String, Object?> _dm({
  Object? kind = 'dm',
  Object? counterpart = 'u2',
  Object? state = 'send',
  Object? muted = true,
}) => {
  'conversation_id': 'd1',
  'game_id': null,
  'game_title': null,
  'sport': null,
  'start_at': null,
  'end_at': null,
  'state': state,
  'last_activity_at': '2026-10-15T11:55:00Z',
  'kind': kind,
  'counterpart_user_id': counterpart,
  'counterpart_name': 'Layla',
  'counterpart_avatar': 'https://img.example.invalid/a.png',
  'muted': muted,
};

void main() {
  test('a DM row parses every v2 field and round-trips', () {
    final c = MyConversation.parse(_dm()).requireValue;
    expect(c.kind, MyConversationKind.dm);
    expect(c.isDm, isTrue);
    expect(c.gameId, isNull);
    expect(c.counterpartUserId, 'u2');
    expect(c.counterpartName, 'Layla');
    expect(c.counterpartAvatar, 'https://img.example.invalid/a.png');
    expect(c.muted, isTrue);
    expect(c.isDmReadOnly, isFalse);
    expect(c.lastActivityAt, DateTime.utc(2026, 10, 15, 11, 55));
    expect(MyConversation.parse(c.toJson()).requireValue, c);
  });

  test('a read_only DM is the blocked/unavailable marker', () {
    final c = MyConversation.parse(_dm(state: 'read_only')).requireValue;
    expect(c.isDmReadOnly, isTrue);
  });

  test('a v2 game row keeps the game fields; v1 row (no kind) is a game', () {
    final v2 = MyConversation.parse({
      'conversation_id': 'c1',
      'game_id': 'g1',
      'state': 'send',
      'kind': 'game',
      'counterpart_user_id': null,
      'counterpart_name': null,
      'counterpart_avatar': null,
      'muted': false,
    }).requireValue;
    expect(v2.kind, MyConversationKind.game);
    expect(v2.gameId, 'g1');
    expect(v2.isDmReadOnly, isFalse);
    final v1 = MyConversation.parse({
      'conversation_id': 'c1',
      'game_id': 'g1',
      'state': 'send',
    }).requireValue;
    expect(v1.kind, MyConversationKind.game);
    expect(v1.muted, isFalse);
  });

  test('optional DM fields are nullable-safe', () {
    final c = MyConversation.parse({
      ..._dm(muted: 'yes'),
      'counterpart_name': 4,
      'counterpart_avatar': null,
    }).requireValue;
    expect(c.counterpartName, isNull);
    expect(c.counterpartAvatar, isNull);
    expect(c.muted, isFalse);
  });

  test('malformed DM payloads are a Failure, never a throw', () {
    for (final bad in <Object?>[
      _dm(kind: 'squad'),
      _dm(kind: 3),
      _dm(counterpart: null),
      _dm(counterpart: ''),
      _dm(counterpart: 5),
      _dm(state: 'kicked'),
      {..._dm(), 'kind': 'game'}, // a game row without game_id
    ]) {
      late Result<MyConversation, Object> r;
      expect(() => r = MyConversation.parse(bad), returnsNormally);
      expect(r.isFailure, isTrue, reason: '$bad');
      expect(r.requireError, isA<MessagingFailure>());
    }
  });

  test('parseList keeps mixed order and fails whole on one bad row', () {
    final list = MyConversation.parseList([
      _dm(),
      {
        'conversation_id': 'c1',
        'game_id': 'g1',
        'state': 'send',
        'kind': 'game',
      },
    ]).requireValue;
    expect(list.map((c) => c.kind), [
      MyConversationKind.dm,
      MyConversationKind.game,
    ]);
    expect(MyConversation.parseList([_dm(), _dm(kind: 'x')]).isFailure, isTrue);
  });
}
