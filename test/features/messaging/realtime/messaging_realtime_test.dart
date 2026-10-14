import 'dart:async';

import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/features/messaging/data/fake_messaging_repository.dart';
import 'package:dabbler/features/messaging/data/messaging_wake_channel.dart';
import 'package:dabbler/features/messaging/domain/models/message_page.dart';
import 'package:dabbler/features/messaging/presentation/providers/messaging_providers.dart';
import 'package:dabbler/features/messaging/presentation/providers/messaging_realtime_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_wake_channel.dart';

/// KAN-544: the Realtime wake-ups drive the game chat. A fake channel stands
/// in for Supabase; the repository is the in-memory fake. No network.

class _CountingRepo extends FakeMessagingRepository {
  int lists = 0;
  final calls = <({int? cursor, MessageDirection direction})>[];

  @override
  Future<Result<MessagePage, Failure>> listMessages({
    required String conversationId,
    int? cursor,
    MessageDirection direction = MessageDirection.older,
    int? limit,
  }) {
    lists++;
    calls.add((cursor: cursor, direction: direction));
    return super.listMessages(
      conversationId: conversationId,
      cursor: cursor,
      direction: direction,
      limit: limit,
    );
  }
}

const _conv = 'conv-g1';

Future<void> _settle() async {
  for (var i = 0; i < 6; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

void main() {
  late _CountingRepo repo;
  late StreamController<String?> user;
  late List<FakeWakeChannel> opened;
  late ProviderContainer container;

  ProviderContainer make({
    bool enabled = true,
    Duration? poll = const Duration(seconds: 15),
    Duration retry = const Duration(milliseconds: 40),
    WakeChannelStatus initial = WakeChannelStatus.connecting,
  }) {
    var n = 0;
    user = StreamController<String?>();
    return ProviderContainer(
      overrides: [
        fakeMessagingRepositoryProvider.overrideWithValue(repo),
        messagingClientKeyGeneratorProvider.overrideWithValue(
          () => 'key-${++n}',
        ),
        gameChatPollIntervalProvider.overrideWithValue(poll),
        messagingRealtimeEnabledProvider.overrideWithValue(enabled),
        messagingSyncRetryDelayProvider.overrideWithValue(retry),
        messagingUserIdProvider.overrideWith((ref) => user.stream),
        messagingWakeChannelFactoryProvider.overrideWithValue((uid) {
          final c = FakeWakeChannel(uid, status: initial);
          opened.add(c);
          return c;
        }),
      ],
    );
  }

  /// Signs in, opens the chat, and returns the channel.
  Future<FakeWakeChannel> openChat() async {
    container.listen(messagingWakeChannelProvider, (_, _) {});
    user.add('u1');
    await _settle();
    await container.read(gameChatControllerProvider('g1').future);
    container.read(gameChatControllerProvider('g1').notifier).setOpen(true);
    return opened.single;
  }

  /// Keeps the channel provider alive (as the open chat does), then lets the
  /// user id arrive.
  Future<void> signIn(String? id) async {
    container.listen(messagingWakeChannelProvider, (_, _) {});
    user.add(id);
    await _settle();
  }

  Future<void> addMessage(String key) => repo.sendTextMessage(
    conversationId: _conv,
    body: 'x',
    idempotencyKey: key,
  );

  int maxSeq() => container
      .read(gameChatControllerProvider('g1'))
      .requireValue
      .items
      .map((i) => i.message?.seq ?? 0)
      .reduce((a, b) => a > b ? a : b);

  setUp(() {
    repo = _CountingRepo()..seedGameConversation('g1', messageCount: 2);
    opened = [];
    container = make();
  });
  tearDown(() async {
    container.dispose();
    unawaited(user.close());
  });

  group('wake -> fetch', () {
    test(
      'a wake with a higher seq fetches only what is newer than my seq',
      () async {
        final ch = await openChat();
        repo.lists = 0;
        repo.calls.clear();
        await addMessage('k1');
        ch.emit(const MessagingWake(conversationId: _conv, seq: 3));
        await _settle();
        expect(maxSeq(), 3);
        expect(repo.lists, 1);
        // through the existing list call: newer than my max seq (2)
        expect(repo.calls.single, (
          cursor: 2,
          direction: MessageDirection.newer,
        ));
      },
    );

    test('a wake at or below my seq fetches nothing', () async {
      final ch = await openChat();
      repo.lists = 0;
      ch.emit(const MessagingWake(conversationId: _conv, seq: 2));
      ch.emit(const MessagingWake(conversationId: _conv, seq: 1));
      await _settle();
      expect(repo.lists, 0);
    });

    test('a wake for another conversation fetches nothing', () async {
      final ch = await openChat();
      repo.lists = 0;
      await addMessage('k1');
      ch.emit(const MessagingWake(conversationId: 'conv-other', seq: 99));
      await _settle();
      expect(repo.lists, 0);
      expect(maxSeq(), 2);
    });

    test('while the chat is closed a wake does nothing', () async {
      final ch = await openChat();
      container.read(gameChatControllerProvider('g1').notifier).setOpen(false);
      repo.lists = 0;
      await addMessage('k1');
      ch.emit(const MessagingWake(conversationId: _conv, seq: 3));
      await _settle();
      expect(repo.lists, 0);
      expect(maxSeq(), 2);
    });

    test(
      'two wakes in a row fetch one after the other and keep seq order',
      () async {
        final ch = await openChat();
        await addMessage('k1');
        await addMessage('k2');
        ch.emit(const MessagingWake(conversationId: _conv, seq: 3));
        ch.emit(const MessagingWake(conversationId: _conv, seq: 4));
        await _settle();
        final seqs = container
            .read(gameChatControllerProvider('g1'))
            .requireValue
            .items
            .map((i) => i.message!.seq)
            .toList();
        expect(seqs, [1, 2, 3, 4]);
      },
    );
  });

  group('sync wake (no seq)', () {
    test(
      'fetches now, and once more after the delay when nothing was new',
      () async {
        final ch = await openChat();
        repo.lists = 0;
        ch.emit(const MessagingWake(conversationId: _conv));
        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect(repo.lists, 1); // the fetch now
        await Future<void>.delayed(const Duration(milliseconds: 120));
        expect(repo.lists, 2); // the second look after the delay
      },
    );

    test('a new message on the first fetch means no second look', () async {
      final ch = await openChat();
      repo.lists = 0;
      await addMessage('k1');
      ch.emit(const MessagingWake(conversationId: _conv));
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(maxSeq(), 3);
      expect(repo.lists, 1);
    });

    test('the default delay is 2 seconds', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      expect(
        c.read(messagingSyncRetryDelayProvider),
        const Duration(seconds: 2),
      );
    });
  });

  group('poll cadence follows the channel status', () {
    Duration? cadence() => container.read(gameChatEffectivePollProvider);

    test(
      '15 s until SUBSCRIBED, 60 s while SUBSCRIBED, 15 s again when it drops',
      () async {
        final ch = await openChat();
        container.listen(gameChatEffectivePollProvider, (_, _) {});
        container.listen(messagingWakeStatusProvider, (_, _) {});
        expect(cadence(), const Duration(seconds: 15));
        ch.setStatus(WakeChannelStatus.subscribed);
        await _settle();
        expect(cadence(), const Duration(seconds: 60));
        ch.setStatus(WakeChannelStatus.closed);
        await _settle();
        expect(cadence(), const Duration(seconds: 15));
      },
    );

    test('a channel that is already SUBSCRIBED starts at 60 s', () async {
      container.dispose();
      container = make(initial: WakeChannelStatus.subscribed);
      container.listen(messagingWakeStatusProvider, (_, _) {});
      await signIn('u1');
      expect(cadence(), const Duration(seconds: 60));
    });

    test('a null base interval (tests) stays null', () async {
      container.dispose();
      container = make(poll: null);
      expect(cadence(), isNull);
    });
  });

  group('catch-up', () {
    test(
      'every (re)subscribe triggers one catch-up fetch of the newest page',
      () async {
        final ch = await openChat();
        repo.lists = 0;
        await addMessage('k1');
        ch.setStatus(WakeChannelStatus.subscribed);
        await _settle();
        expect(repo.lists, 1);
        expect(maxSeq(), 3);
        // drop, miss one, resubscribe
        ch.setStatus(WakeChannelStatus.closed);
        await addMessage('k2');
        ch.setStatus(WakeChannelStatus.subscribed);
        await _settle();
        expect(repo.lists, 2);
        expect(maxSeq(), 4);
      },
    );

    test(
      'a status that stays SUBSCRIBED does not refetch; a closed chat does not catch up',
      () async {
        final ch = await openChat();
        ch.setStatus(WakeChannelStatus.subscribed);
        await _settle();
        repo.lists = 0;
        ch.setStatus(WakeChannelStatus.subscribed);
        await _settle();
        expect(repo.lists, 0);
        container
            .read(gameChatControllerProvider('g1').notifier)
            .setOpen(false);
        ch.setStatus(WakeChannelStatus.closed);
        ch.setStatus(WakeChannelStatus.subscribed);
        await _settle();
        expect(repo.lists, 0);
      },
    );
  });

  group('flag off equals today\'s polling', () {
    test(
      'no channel, no Supabase, the base cadence, wakes cannot exist',
      () async {
        container.dispose();
        container = ProviderContainer(
          overrides: [
            fakeMessagingRepositoryProvider.overrideWithValue(repo),
            // reading these would throw: proves Supabase is never touched
            messagingUserIdProvider.overrideWith(
              (ref) => throw StateError('touched'),
            ),
            messagingWakeChannelFactoryProvider.overrideWithValue(
              (_) => throw StateError('opened'),
            ),
          ],
        );
        expect(container.read(messagingRealtimeEnabledProvider), isFalse);
        expect(container.read(messagingWakeChannelProvider), isNull);
        expect(
          container.read(gameChatEffectivePollProvider),
          const Duration(seconds: 15),
        );
        await container.read(gameChatControllerProvider('g1').future);
        repo.lists = 0;
        await container
            .read(gameChatControllerProvider('g1').notifier)
            .refreshNewest();
        expect(repo.lists, 1); // the poll path is unchanged
      },
    );
  });

  group('one private channel per user, removed on sign-out', () {
    test(
      'one channel for the signed-in user, however often it is read',
      () async {
        await signIn('u1');
        final a = container.read(messagingWakeChannelProvider);
        final b = container.read(messagingWakeChannelProvider);
        expect(a, same(b));
        expect(opened.length, 1);
        expect(opened.single.userId, 'u1');
        expect(opened.single.closed, isFalse);
      },
    );

    test('sign-out removes the channel and no new one opens', () async {
      await signIn('u1');
      final ch = opened.single;
      user.add(null);
      await _settle();
      expect(ch.closeCalls, 1);
      expect(container.read(messagingWakeChannelProvider), isNull);
      expect(opened.length, 1);
    });

    test(
      'a different user gets a new channel and the old one is removed',
      () async {
        await signIn('u1');
        user.add('u2');
        await _settle();
        expect(opened.map((c) => c.userId), ['u1', 'u2']);
        expect(opened.first.closed, isTrue);
        expect(opened.last.closed, isFalse);
      },
    );

    test('disposing the container removes the channel', () async {
      await signIn('u1');
      container.dispose();
      expect(opened.single.closeCalls, 1);
    });

    test('Realtime on but nobody signed in: no channel', () async {
      await signIn(null);
      expect(container.read(messagingWakeChannelProvider), isNull);
      expect(opened, isEmpty);
    });
  });
}
