import 'package:dabbler/features/messaging/domain/models/conversation.dart';
import 'package:dabbler/features/messaging/domain/models/message.dart';
import 'package:dabbler/features/messaging/domain/models/message_page.dart';
import 'package:dabbler/features/messaging/domain/models/view_boundary.dart';
import 'package:dabbler/features/messaging/domain/typed_reason.dart';
import 'package:flutter_test/flutter_test.dart';

const _id = '11111111-1111-4111-8111-111111111111';
const _conv = '22222222-2222-4222-8222-222222222222';
const _game = '33333333-3333-4333-8333-333333333333';
const _user = '44444444-4444-4444-8444-444444444444';
const _key = '55555555-5555-4555-8555-555555555555';

Map<String, dynamic> _message({int seq = 7, String kind = 'text'}) => {
  'id': _id,
  'conversation_id': _conv,
  'seq': seq,
  'sender_user_id': _user,
  'kind': kind,
  'body': 'hello',
  'client_key': _key,
  'created_at': '2026-10-13T10:00:00Z',
};

void main() {
  group('Message', () {
    test('round-trips through JSON', () {
      final m = Message.fromJson(_message());
      expect(m.seq, 7);
      expect(m.kind, MessageKind.text);
      expect(m.createdAt.isUtc, isTrue);
      expect(Message.fromJson(m.toJson()), m);
    });

    test('the payload carries exactly the contract fields: no delivery or '
        'view state', () {
      expect(Message.fromJson(_message()).toJson().keys.toSet(), {
        'id',
        'conversation_id',
        'seq',
        'sender_user_id',
        'kind',
        'body',
        'client_key',
        'created_at',
      });
    });

    test('a system line has no sender; an unknown kind is shown as system', () {
      final json = _message(kind: 'a_new_kind')..['sender_user_id'] = null;
      final m = Message.fromJson(json);
      expect(m.kind, MessageKind.system);
      expect(m.senderUserId, isNull);
    });

    test('a malformed payload throws a FormatException (the repository '
        'implementation turns it into a failure)', () {
      expect(
        () => Message.fromJson({'id': _id}),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('Conversation and the view boundary', () {
    Map<String, dynamic> conv({Object? boundary, Object? reason}) => {
      'id': _conv,
      'kind': 'game',
      'game_id': _game,
      'writable': reason == null,
      'read_only_reason': reason,
      'boundary': boundary,
      'muted': false,
      'last_seq': 12,
    };

    test('a writable conversation has no read-only reason and no boundary', () {
      final c = Conversation.fromJson(conv());
      expect(c.writable, isTrue);
      expect(c.readOnlyReason, isNull);
      expect(c.boundary, isNull);
      expect(Conversation.fromJson(c.toJson()), c);
    });

    test('the left_at_seq limit is a typed boundary from the server', () {
      final c = Conversation.fromJson(
        conv(
          reason: 'left_read_only',
          boundary: {'kind': 'left_at_seq', 'seq': 9},
        ),
      );
      expect(c.writable, isFalse);
      expect(c.readOnlyReason, MessagingReason.leftReadOnly);
      expect(
        c.boundary,
        const ViewBoundary(kind: ViewBoundaryKind.leftAtSeq, seq: 9),
      );
      expect(Conversation.fromJson(c.toJson()), c);
    });

    test(
      'an unknown boundary kind is ignored; an unknown reason is unknown',
      () {
        final c = Conversation.fromJson(
          conv(
            reason: 'a_new_reason',
            boundary: {'kind': 'tomorrow', 'seq': 1},
          ),
        );
        expect(c.boundary, isNull);
        expect(c.readOnlyReason, MessagingReason.unknown);
      },
    );

    test('game_ended and game_cancelled are read-only reasons', () {
      for (final r in ['game_ended', 'game_cancelled']) {
        final c = Conversation.fromJson(conv(reason: r));
        expect(c.writable, isFalse);
        expect(c.readOnlyReason!.wireName, r);
      }
    });
  });

  group('MessagePage', () {
    test('pages by seq cursor with both directions and a boundary', () {
      final page = MessagePage.fromJson({
        'messages': [_message(seq: 5), _message(seq: 6)],
        'older_cursor': 5,
        'newer_cursor': null,
        'has_older': true,
        'has_newer': false,
        'page_size': 30,
        'boundary': {'kind': 'left_at_seq', 'seq': 6},
      });
      expect(page.messages.map((m) => m.seq), [5, 6]);
      expect(page.olderCursor, 5);
      expect(page.newerCursor, isNull);
      expect(page.hasOlder, isTrue);
      expect(page.hasNewer, isFalse);
      expect(page.boundary!.seq, 6);
      expect(MessagePage.fromJson(page.toJson()), page);
    });

    test('limits match the contract', () {
      expect(MessagingLimits.defaultPageSize, 30);
      expect(MessagingLimits.maxPageSize, 50);
      expect(MessageDirection.values.map((d) => d.wireName), [
        'older',
        'newer',
      ]);
    });

    test('a malformed page throws a FormatException', () {
      expect(
        () => MessagePage.fromJson({'messages': 3}),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
