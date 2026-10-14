import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/features/messaging/data/fake_messaging_repository.dart';
import 'package:dabbler/features/messaging/domain/models/message_page.dart';
import 'package:dabbler/features/messaging/domain/models/report_category.dart';
import 'package:dabbler/features/messaging/domain/typed_reason.dart';
import 'package:flutter_test/flutter_test.dart';

MessagingReason reasonOf(Result<Object?, Object> r) =>
    (r.requireError as MessagingFailure).reason;

void main() {
  late FakeMessagingRepository repo;
  setUp(() => repo = FakeMessagingRepository());

  test('empty thread', () async {
    final c = repo.seedGameConversation('g1');
    final page = (await repo.listMessages(conversationId: c.id)).requireValue;
    expect(page.messages, isEmpty);
    expect(page.hasOlder, isFalse);
    expect(page.hasNewer, isFalse);
  });

  test('unknown game is not_found', () async {
    final r = await repo.getGameConversation('nope');
    expect(reasonOf(r), MessagingReason.notFound);
  });

  test('pagination older: every message once, no gaps or duplicates', () async {
    final c = repo.seedGameConversation('g1', messageCount: 23);
    final seen = <int>[];
    int? cursor;
    var pages = 0;
    while (true) {
      final p = (await repo.listMessages(
        conversationId: c.id,
        cursor: cursor,
        limit: 5,
      )).requireValue;
      pages++;
      seen.insertAll(0, p.messages.map((m) => m.seq));
      if (!p.hasOlder) break;
      cursor = p.olderCursor;
    }
    expect(pages, 5);
    expect(seen, List.generate(23, (i) => i + 1));
  });

  test('pagination newer from a cursor', () async {
    final c = repo.seedGameConversation('g1', messageCount: 12);
    final seen = <int>[];
    int? cursor = 0;
    while (true) {
      final p = (await repo.listMessages(
        conversationId: c.id,
        cursor: cursor,
        direction: MessageDirection.newer,
        limit: 5,
      )).requireValue;
      seen.addAll(p.messages.map((m) => m.seq));
      if (!p.hasNewer) break;
      cursor = p.newerCursor;
    }
    expect(seen, List.generate(12, (i) => i + 1));
  });

  test('default page size and limit validation', () async {
    final c = repo.seedGameConversation('g1', messageCount: 40);
    final p = (await repo.listMessages(conversationId: c.id)).requireValue;
    expect(p.messages.length, MessagingLimits.defaultPageSize);
    expect(p.messages.last.seq, 40);
    final tooBig = await repo.listMessages(
      conversationId: c.id,
      limit: MessagingLimits.maxPageSize + 1,
    );
    expect(reasonOf(tooBig), MessagingReason.invalidRequest);
  });

  test('send success appends with the next seq and deterministic id', () async {
    final c = repo.seedGameConversation('g1', messageCount: 2);
    final m = (await repo.sendTextMessage(
      conversationId: c.id,
      body: 'hi',
      idempotencyKey: 'k1',
    )).requireValue;
    expect(m.seq, 3);
    expect(m.clientKey, 'k1');
    expect(m.id, 'fake-3');
    expect(repo.storedMessages(c.id).length, 3);
  });

  test('failed send then retry with the same key does not duplicate', () async {
    final c = repo.seedGameConversation('g1');
    repo.failNext(FakeMessagingOp.sendTextMessage, MessagingReason.rateLimited);
    final first = await repo.sendTextMessage(
      conversationId: c.id,
      body: 'hi',
      idempotencyKey: 'k1',
    );
    expect(reasonOf(first), MessagingReason.rateLimited);
    expect((first.requireError as MessagingFailure).retryAfterSeconds, 30);
    final retry = (await repo.sendTextMessage(
      conversationId: c.id,
      body: 'hi',
      idempotencyKey: 'k1',
    )).requireValue;
    final again = (await repo.sendTextMessage(
      conversationId: c.id,
      body: 'hi',
      idempotencyKey: 'k1',
    )).requireValue;
    expect(again, retry);
    expect(repo.storedMessages(c.id).length, 1);
    expect(repo.sendAttempts, 3);
  });

  test('offline mode fails every operation with offline', () async {
    final c = repo.seedGameConversation('g1', messageCount: 1);
    repo.offline = true;
    expect(
      reasonOf(await repo.getGameConversation('g1')),
      MessagingReason.offline,
    );
    expect(
      reasonOf(await repo.listMessages(conversationId: c.id)),
      MessagingReason.offline,
    );
    expect(
      reasonOf(
        await repo.sendTextMessage(
          conversationId: c.id,
          body: 'x',
          idempotencyKey: 'k',
        ),
      ),
      MessagingReason.offline,
    );
    expect(
      reasonOf(await repo.muteConversation(c.id)),
      MessagingReason.offline,
    );
    repo.offline = false;
    expect((await repo.getGameConversation('g1')).isSuccess, isTrue);
  });

  test('read-only conversation refuses send with its reason', () async {
    final c = repo.seedGameConversation(
      'g1',
      writable: false,
      readOnlyReason: MessagingReason.gameEnded,
    );
    final r = await repo.sendTextMessage(
      conversationId: c.id,
      body: 'x',
      idempotencyKey: 'k',
    );
    expect(reasonOf(r), MessagingReason.gameEnded);
  });

  test('report, mute and unmute', () async {
    final c = repo.seedGameConversation('g1', messageCount: 1);
    final id = repo.storedMessages(c.id).single.id;
    expect(
      (await repo.reportMessage(
        messageId: id,
        reason: ReportCategory.spam,
      )).isSuccess,
      isTrue,
    );
    expect(repo.wasReported(id), isTrue);
    await repo.muteConversation(c.id);
    expect((await repo.getGameConversation('g1')).requireValue.muted, isTrue);
    await repo.unmuteConversation(c.id);
    expect((await repo.getGameConversation('g1')).requireValue.muted, isFalse);
  });

  group('every typed reason is scriptable on every operation', () {
    // Iterates the enum: a new reason is covered (or breaks) automatically.
    for (final reason in MessagingReason.values) {
      test(reason.wireName, () async {
        final c = repo.seedGameConversation('g1', messageCount: 1);
        final msgId = repo.storedMessages(c.id).single.id;
        for (final op in FakeMessagingOp.values) {
          repo.failNext(op, reason);
        }
        final results = <Result<Object?, Object>>[
          await repo.getGameConversation('g1'),
          await repo.listMessages(conversationId: c.id),
          await repo.sendTextMessage(
            conversationId: c.id,
            body: 'x',
            idempotencyKey: 'k',
          ),
          await repo.reportMessage(
            messageId: msgId,
            reason: ReportCategory.other,
          ),
          await repo.muteConversation(c.id),
          await repo.unmuteConversation(c.id),
        ];
        expect(results.length, FakeMessagingOp.values.length);
        for (final r in results) {
          expect(reasonOf(r), reason);
        }
        // failNext is one-shot: the next call succeeds.
        expect((await repo.getGameConversation('g1')).isSuccess, isTrue);
      });
    }
  });

  test('failAlways persists until clearFailures', () async {
    repo.seedGameConversation('g1');
    repo.failAlways(
      FakeMessagingOp.getGameConversation,
      MessagingReason.blocked,
    );
    expect(
      reasonOf(await repo.getGameConversation('g1')),
      MessagingReason.blocked,
    );
    expect(
      reasonOf(await repo.getGameConversation('g1')),
      MessagingReason.blocked,
    );
    repo.clearFailures();
    expect((await repo.getGameConversation('g1')).isSuccess, isTrue);
  });
}
