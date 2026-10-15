import 'package:flutter_test/flutter_test.dart';

import 'package:dabbler/features/messaging/data/fake_messaging_repository.dart';
import 'package:dabbler/features/messaging/domain/dm_failure.dart';
import 'package:dabbler/features/messaging/domain/models/my_conversation.dart';
import 'package:dabbler/features/messaging/domain/typed_reason.dart';

// KAN-562: the fake's DM operations.
MyConversation _dm(String id, String other, {bool muted = false}) =>
    MyConversation(
      conversationId: id,
      kind: MyConversationKind.dm,
      state: MyConversationState.send,
      counterpartUserId: other,
      counterpartName: 'Name $other',
      muted: muted,
      lastActivityAt: DateTime.utc(2026, 10, 15),
    );

void main() {
  late FakeMessagingRepository repo;
  setUp(() => repo = FakeMessagingRepository());

  test(
    'startDm creates a DM row the list returns; same pair reuses it',
    () async {
      final id = (await repo.startDm('u2')).requireValue;
      expect(repo.startDmCalls, 1);
      final rows = (await repo.listMyConversations()).requireValue;
      expect(rows.single.conversationId, id);
      expect(rows.single.isDm, isTrue);
      expect(rows.single.counterpartUserId, 'u2');
      expect((await repo.startDm('u2')).requireValue, id);
      expect((await repo.listMyConversations()).requireValue, hasLength(1));
    },
  );

  test('startDm with a seeded DM returns its id; self is invalid', () async {
    repo.seedMyConversations([_dm('d1', 'u9')]);
    expect((await repo.startDm('u9')).requireValue, 'd1');
    expect(
      (repo.startDm(repo.currentUserId)),
      completion(predicate((r) => (r as dynamic).isFailure == true)),
    );
  });

  test('scripted dm_cap_reached, then success', () async {
    repo.failNextDmCapReached();
    final f = (await repo.startDm('u2')).requireError;
    expect(f, isA<DmCapReachedFailure>());
    expect((f as DmCapReachedFailure).httpStatus, 429);
    expect((await repo.startDm('u2')).isSuccess, isTrue);
    expect(repo.startDmCalls, 2);
  });

  for (final reason in MessagingReason.values) {
    test(
      'every typed reason is scriptable on both DM ops: ${reason.wireName}',
      () async {
        repo.seedMyConversations([_dm('d1', 'u9')]);
        repo.failNextDm(FakeDmOp.startDm, reason);
        repo.failNextDm(FakeDmOp.setMuted, reason);
        final a = (await repo.startDm('u2')).requireError as MessagingFailure;
        final b =
            (await repo.setMuted('d1', true)).requireError as MessagingFailure;
        expect(a.reason, reason);
        expect(b.reason, reason);
      },
    );
  }

  test('setMuted updates the row; unknown id is not_found; offline', () async {
    repo.seedMyConversations([_dm('d1', 'u9')]);
    expect((await repo.setMuted('d1', true)).isSuccess, isTrue);
    expect(
      (await repo.listMyConversations()).requireValue.single.muted,
      isTrue,
    );
    expect((await repo.setMuted('d1', false)).isSuccess, isTrue);
    expect(
      (await repo.listMyConversations()).requireValue.single.muted,
      isFalse,
    );
    final nf =
        (await repo.setMuted('nope', true)).requireError as MessagingFailure;
    expect(nf.reason, MessagingReason.notFound);
    repo.offline = true;
    final off = (await repo.startDm('u2')).requireError as MessagingFailure;
    expect(off.reason, MessagingReason.offline);
    expect(repo.setMutedCalls, 3);
  });
}
