import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/core/cache/cache_providers.dart';
import 'package:dabbler/core/cache/offline_cache.dart';
import 'package:dabbler/features/messaging/data/chat_cache.dart';
import 'package:dabbler/features/messaging/data/fake_messaging_repository.dart';
import 'package:dabbler/features/messaging/domain/models/my_conversation.dart';
import 'package:dabbler/features/messaging/presentation/providers/messages_list_providers.dart';
import 'package:dabbler/features/messaging/presentation/providers/messaging_providers.dart';
import 'package:dabbler/features/messaging/presentation/view_models/game_chat_view_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_backend.dart';

/// KAN-607: message history loaded on the device reads offline, per account,
/// and never sends offline.
void main() {
  late OfflineCache cache;
  late FakeMessagingRepository repo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    cache = OfflineCache(prefs: await SharedPreferences.getInstance());
    repo = FakeMessagingRepository();
  });

  ProviderContainer containerFor(String? account) {
    final c = ProviderContainer(
      overrides: [
        fakeMessagingBackend,
        fakeMessagingRepositoryProvider.overrideWithValue(repo),
        offlineCacheProvider.overrideWithValue(cache),
        cacheAccountIdProvider.overrideWith(
          (ref) => CacheAccountNotifier.fixed(account),
        ),
        messagingClientKeyGeneratorProvider.overrideWithValue(() => 'k'),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  Future<GameChatViewState> open(ProviderContainer c, String game) =>
      c.read(gameChatControllerProvider(game).future);

  test('a thread seen online opens offline from the device copy', () async {
    repo.seedGameConversation('g1', messageCount: 3);
    await open(containerFor('A'), 'g1');
    await Future<void>.delayed(Duration.zero);

    repo.offline = true;
    final c = containerFor('A');
    final s = await open(c, 'g1');
    expect(s.fromCache, isTrue);
    expect(s.status, GameChatStatus.ready);
    expect(s.items.length, 3);
    expect(s.hasOlder, isFalse);

    // Sending is refused; nothing is queued.
    await c.read(gameChatControllerProvider('g1').notifier).send('hello');
    expect(
      c.read(gameChatControllerProvider('g1')).requireValue.items.length,
      3,
    );
    expect(repo.sendAttempts, 0);
  });

  test('another account never reads the first account\'s thread', () async {
    repo.seedGameConversation('g1', messageCount: 2);
    await open(containerFor('A'), 'g1');
    await Future<void>.delayed(Duration.zero);

    repo.offline = true;
    final s = await open(containerFor('B'), 'g1');
    expect(s.status, GameChatStatus.offline);
    expect(s.items, isEmpty);
  });

  test('a successful refresh leaves the device copy behind', () async {
    repo.seedGameConversation('g1', messageCount: 2);
    await open(containerFor('A'), 'g1');
    await Future<void>.delayed(Duration.zero);
    repo.offline = true;
    final c = containerFor('A');
    await open(c, 'g1');
    repo.offline = false;
    await c.read(gameChatControllerProvider('g1').notifier).refreshNewest();
    expect(
      c.read(gameChatControllerProvider('g1')).requireValue.fromCache,
      isFalse,
    );
  });

  test('only the newest N messages are kept', () async {
    repo.seedGameConversation(
      'g1',
      messageCount: ChatCache.maxMessagesPerThread + 10,
    );
    final first = await open(containerFor('A'), 'g1');
    await Future<void>.delayed(Duration.zero);
    final stored = await ChatCache(
      cache,
      'A',
    ).loadThread(ChatCache.gameThreadKey('g1'));
    expect(
      stored!.items.length,
      lessThanOrEqualTo(ChatCache.maxMessagesPerThread),
    );
    expect(first.items, isNotEmpty);
  });

  test('the Messages list reads offline from the device copy', () async {
    repo.seedMyConversations([
      const MyConversation(
        conversationId: 'c1',
        gameId: 'g1',
        state: MyConversationState.send,
      ),
    ]);
    final online = await containerFor('A').read(messagesListProvider.future);
    expect(online.requireValue.length, 1);
    await Future<void>.delayed(Duration.zero);

    repo.offline = true;
    final off = await containerFor('A').read(messagesListProvider.future);
    expect(off.requireValue.single.conversationId, 'c1');

    final other = await containerFor('B').read(messagesListProvider.future);
    expect(other, isA<Err<List<MyConversation>, Failure>>());
  });
}
