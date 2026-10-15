import 'package:dabbler/features/messaging/data/messaging_wake_channel.dart';
import 'package:flutter_test/flutter_test.dart';

/// KAN-544: what a broadcast becomes. Only ids and a seq are read; a payload
/// that is not a wake is ignored.
void main() {
  const conv = '11111111-1111-4111-8111-111111111111';

  test(
    'a msg wake carries conversation id and seq (platform wraps it in payload)',
    () {
      final w = parseWake({
        'event': 'msg',
        'type': 'broadcast',
        'payload': {
          'type': 'msg',
          'conversation_id': conv,
          'seq': 7,
          'id': 'platform-id',
        },
      })!;
      expect(w.conversationId, conv);
      expect(w.seq, 7);
    },
  );

  test('a bare payload (no wrapper) is read too', () {
    final w = parseWake({'type': 'msg', 'conversation_id': conv, 'seq': 3})!;
    expect(w.seq, 3);
  });

  test('a sync wake has no seq', () {
    final w = parseWake({
      'payload': {'type': 'sync', 'conversation_id': conv},
    })!;
    expect(w.conversationId, conv);
    expect(w.seq, isNull);
  });

  test('a sync wake ignores a stray seq', () {
    expect(
      parseWake({
        'payload': {'type': 'sync', 'conversation_id': conv, 'seq': 9},
      })!.seq,
      isNull,
    );
  });

  for (final (name, payload) in <(String, Map<String, dynamic>)>[
    ('no conversation id', {'type': 'msg', 'seq': 1}),
    ('empty conversation id', {'type': 'msg', 'conversation_id': '', 'seq': 1}),
    (
      'non-string conversation id',
      {'type': 'msg', 'conversation_id': 5, 'seq': 1},
    ),
    ('unknown type', {'type': 'other', 'conversation_id': conv, 'seq': 1}),
    ('msg without a seq', {'type': 'msg', 'conversation_id': conv}),
    ('seq zero', {'type': 'msg', 'conversation_id': conv, 'seq': 0}),
    ('seq not a number', {'type': 'msg', 'conversation_id': conv, 'seq': 'x'}),
    ('empty', <String, dynamic>{}),
  ]) {
    test('ignored: $name', () {
      expect(parseWake({'payload': payload}), isNull);
    });
  }

  test(
    'no text field is ever read: only the two ids and the seq reach a wake',
    () {
      final w = parseWake({
        'payload': {
          'type': 'msg',
          'conversation_id': conv,
          'seq': 2,
          'body': 'hello',
          'sender': 'u',
        },
      })!;
      expect(w.conversationId, conv);
      expect(w.seq, 2);
    },
  );
}
