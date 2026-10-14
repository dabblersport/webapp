import 'dart:async';

import 'package:dabbler/features/messaging/data/fake_messaging_repository.dart';
import 'package:dabbler/features/messaging/domain/typed_reason.dart';
import 'package:dabbler/features/messaging/presentation/providers/messaging_providers.dart';
import 'package:dabbler/features/messaging/presentation/view_models/game_chat_view_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeMessagingRepository repo;
  late ProviderContainer container;

  setUp(() {
    repo = FakeMessagingRepository();
    var n = 0;
    container = ProviderContainer(
      overrides: [
        fakeMessagingRepositoryProvider.overrideWithValue(repo),
        messagingClientKeyGeneratorProvider.overrideWithValue(
          () => 'key-${++n}',
        ),
      ],
    );
  });
  tearDown(() => container.dispose());

  Future<GameChatViewState> load(String gameId) =>
      container.read(gameChatControllerProvider(gameId).future);

  test('provider defaults to the fake', () {
    expect(container.read(messagingRepositoryProvider), same(repo));
  });

  test('loading first', () {
    repo.seedGameConversation('g1');
    expect(
      container.read(gameChatControllerProvider('g1')),
      isA<AsyncLoading<GameChatViewState>>(),
    );
  });

  test('empty', () async {
    repo.seedGameConversation('g1');
    expect((await load('g1')).status, GameChatStatus.empty);
  });

  test('ready', () async {
    repo.seedGameConversation('g1', messageCount: 3);
    final s = await load('g1');
    expect(s.status, GameChatStatus.ready);
    expect(s.items.length, 3);
    expect(s.items.every((i) => i.state == OutgoingState.sent), isTrue);
  });

  test('sending then sent', () async {
    repo.seedGameConversation('g1');
    await load('g1');
    final notifier = container.read(gameChatControllerProvider('g1').notifier);
    final future = notifier.send('hi');
    final during = container
        .read(gameChatControllerProvider('g1'))
        .requireValue;
    expect(during.isSending, isTrue);
    expect(during.items.single.state, OutgoingState.sending);
    await future;
    final after = container.read(gameChatControllerProvider('g1')).requireValue;
    expect(after.items.single.state, OutgoingState.sent);
    expect(after.items.single.message?.clientKey, 'key-1');
  });

  test('failed with retry, same key, no duplicate', () async {
    final c = repo.seedGameConversation('g1');
    await load('g1');
    final notifier = container.read(gameChatControllerProvider('g1').notifier);
    repo.failNext(FakeMessagingOp.sendTextMessage, MessagingReason.offline);
    await notifier.send('hi');
    var s = container.read(gameChatControllerProvider('g1')).requireValue;
    expect(s.items.single.state, OutgoingState.failed);
    expect(s.items.single.failureReason, MessagingReason.offline);
    await notifier.retry('key-1');
    s = container.read(gameChatControllerProvider('g1')).requireValue;
    expect(s.items.single.state, OutgoingState.sent);
    expect(repo.storedMessages(c.id).length, 1);
  });

  test('read-only closed with reason', () async {
    repo.seedGameConversation(
      'g1',
      messageCount: 2,
      writable: false,
      readOnlyReason: MessagingReason.leftReadOnly,
    );
    final s = await load('g1');
    expect(s.status, GameChatStatus.readOnly);
    expect(s.reason, MessagingReason.leftReadOnly);
    expect(s.reasonKey, 'messagingReasonLeftReadOnly');
    expect(s.items.length, 2);
  });

  final expectedStatus = <MessagingReason, GameChatStatus>{
    MessagingReason.notInPilot: GameChatStatus.unavailable,
    MessagingReason.removed: GameChatStatus.removed,
    MessagingReason.offline: GameChatStatus.offline,
    MessagingReason.leftReadOnly: GameChatStatus.readOnly,
    MessagingReason.gameEnded: GameChatStatus.readOnly,
    MessagingReason.gameCancelled: GameChatStatus.readOnly,
  };

  for (final reason in MessagingReason.values) {
    test('load failure ${reason.wireName} -> state', () async {
      repo.seedGameConversation('g1');
      repo.failNext(FakeMessagingOp.getGameConversation, reason);
      final s = await load('g1');
      expect(s.status, expectedStatus[reason] ?? GameChatStatus.error);
      expect(s.reason, reason);
      expect(s.reasonKey, startsWith('messagingReason'));
    });
  }

  test('offline mode', () async {
    repo.seedGameConversation('g1');
    repo.offline = true;
    expect((await load('g1')).status, GameChatStatus.offline);
  });

  test('loadOlder prepends the previous page without gaps', () async {
    repo.seedGameConversation('g1', messageCount: 35);
    await load('g1');
    await container.read(gameChatControllerProvider('g1').notifier).loadOlder();
    final s = container.read(gameChatControllerProvider('g1')).requireValue;
    expect(
      s.items.map((i) => i.message!.seq).toList(),
      List.generate(35, (i) => i + 1),
    );
    expect(s.hasOlder, isFalse);
  });

  test('never throws: load completes for unknown game', () async {
    final s = await runZonedGuarded(
      () => load('missing'),
      (e, _) => fail('$e'),
    );
    expect(s!.status, GameChatStatus.error);
    expect(s.reason, MessagingReason.notFound);
  });
}
