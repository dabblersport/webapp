import 'dart:async';

import 'package:dabbler/features/messaging/data/messaging_wake_channel.dart';
import 'package:dabbler/features/messaging/domain/typing.dart';
import 'package:dabbler/features/messaging/presentation/providers/messaging_realtime_providers.dart';
import 'package:dabbler/features/messaging/presentation/providers/typing_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'typing_fakes.dart';

/// KAN-579: ephemeral typing presence. The sender's throttle, the receiver's
/// roster and expiry, and two clients talking through a model of the server.
/// Lets riverpod's scheduler (a zero-length timer) and the user-id stream run.
Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 5));
}

void main() {
  group('parseTypingSignal', () {
    Map<String, dynamic> wrap(Map<String, dynamic> body) => {
      'event': 'typing',
      'type': 'broadcast',
      'payload': body,
    };

    test('reads the four keys inside the platform envelope', () {
      final s = parseTypingSignal(
        wrap({
          'type': 'typing',
          'conversation_id': 'c1',
          'user_id': 'u1',
          'on': true,
        }),
      );
      expect(
        s,
        const TypingSignal(conversationId: 'c1', userId: 'u1', on: true),
      );
    });

    test('a bare body also parses; a stop parses as on = false', () {
      expect(
        parseTypingSignal({
          'type': 'typing',
          'conversation_id': 'c1',
          'user_id': 'u1',
          'on': false,
        })?.on,
        isFalse,
      );
    });

    test('anything else is not a signal', () {
      for (final bad in <Map<String, dynamic>>[
        {},
        {'type': 'msg', 'conversation_id': 'c1', 'seq': 1},
        {'type': 'typing', 'user_id': 'u1', 'on': true},
        {'type': 'typing', 'conversation_id': 'c1', 'on': true},
        {'type': 'typing', 'conversation_id': 'c1', 'user_id': 'u1'},
        {'type': 'typing', 'conversation_id': 'c1', 'user_id': 'u1', 'on': 1},
        {'type': 'typing', 'conversation_id': '', 'user_id': 'u1', 'on': true},
      ]) {
        expect(parseTypingSignal(wrap(bad)), isNull, reason: '$bad');
      }
    });

    test('the signal keeps ids and a flag only, never text', () {
      final s = parseTypingSignal(
        wrap({
          'type': 'typing',
          'conversation_id': 'c1',
          'user_id': 'u1',
          'on': true,
          'body': 'secret draft',
        }),
      )!;
      expect(
        '${s.conversationId}${s.userId}${s.on}',
        isNot(contains('secret')),
      );
    });
  });

  group('TypingPublisher (sender)', () {
    late List<bool> sent;
    late DateTime now;

    TypingPublisher make({Future<void> Function(bool)? send}) =>
        TypingPublisher(send: send ?? (t) async => sent.add(t), now: () => now);

    setUp(() {
      sent = [];
      now = DateTime(2026, 10, 20, 12);
    });

    testWidgets(
      'the first non-blank text sends typing once; blank sends nothing',
      (tester) async {
        final p = make();
        p.draftChanged('');
        p.draftChanged('   ');
        expect(sent, isEmpty);
        p.draftChanged('h');
        expect(sent, [true]);
        p.dispose();
      },
    );

    testWidgets('keys inside the interval are throttled; one more after it', (
      tester,
    ) async {
      final p = make();
      p.draftChanged('h');
      for (var i = 0; i < 20; i++) {
        now = now.add(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 100));
        p.draftChanged('h' * (i + 2));
      }
      // 2 s of fast typing: still one signal.
      expect(sent, [true]);
      now = now.add(const Duration(seconds: 2));
      await tester.pump(
        const Duration(seconds: 2) - const Duration(milliseconds: 1),
      );
      p.draftChanged('more');
      // 4 s since the first signal (>= 3 s interval): a second "typing".
      expect(sent, [true, true]);
      p.dispose();
    });

    testWidgets(
      'clearing the field sends one stop; clearing again sends none',
      (tester) async {
        final p = make();
        p.draftChanged('hello');
        p.draftChanged('');
        p.draftChanged('');
        expect(sent, [true, false]);
        expect(p.active, isFalse);
        p.dispose();
      },
    );

    testWidgets(
      'send / blur / background all call stop(): one stop, then nothing',
      (tester) async {
        final p = make();
        p.draftChanged('hello');
        p.stop();
        p.stop();
        expect(sent, [true, false]);
        p.dispose();
        expect(sent, [true, false]);
      },
    );

    testWidgets('no key for the idle window sends a stop by itself', (
      tester,
    ) async {
      final p = make();
      p.draftChanged('hello');
      await tester.pump(typingIdleStop - const Duration(milliseconds: 1));
      expect(sent, [true]);
      await tester.pump(const Duration(milliseconds: 1));
      expect(sent, [true, false]);
      expect(p.active, isFalse);
      p.dispose();
    });

    testWidgets('a key restarts the idle window', (tester) async {
      final p = make();
      p.draftChanged('a');
      await tester.pump(const Duration(seconds: 3));
      now = now.add(const Duration(seconds: 3));
      p.draftChanged('ab');
      await tester.pump(const Duration(seconds: 3));
      expect(sent.last, isTrue, reason: 'still inside the new window');
      await tester.pump(const Duration(seconds: 1));
      expect(sent.last, isFalse);
      p.dispose();
    });

    testWidgets(
      'leaving the chat (dispose) ends typing; later keys do nothing',
      (tester) async {
        final p = make();
        p.draftChanged('hello');
        p.dispose();
        p.draftChanged('after');
        expect(sent, [true, false]);
      },
    );

    testWidgets('a failing sender never throws or retries', (tester) async {
      var calls = 0;
      final p = make(
        send: (t) {
          calls++;
          return Future<void>.error(StateError('offline'));
        },
      );
      p.draftChanged('hello');
      p.stop();
      await settle(tester);
      expect(calls, 2);
      p.dispose();
    });
  });

  group('TypingRoster (receiver)', () {
    final t0 = DateTime(2026, 10, 20, 12);
    TypingSignal on(String u) =>
        TypingSignal(conversationId: 'c1', userId: u, on: true);
    TypingSignal off(String u) =>
        TypingSignal(conversationId: 'c1', userId: u, on: false);

    test(
      'typers appear in the order they started; a repeat keeps its place',
      () {
        final r = TypingRoster();
        expect(r.apply(on('a'), t0), isTrue);
        expect(r.apply(on('b'), t0), isTrue);
        expect(r.apply(on('a'), t0.add(const Duration(seconds: 3))), isFalse);
        expect(r.ids, ['a', 'b']);
      },
    );

    test('a stop removes only that typer', () {
      final r = TypingRoster()
        ..apply(on('a'), t0)
        ..apply(on('b'), t0);
      expect(r.apply(off('a'), t0), isTrue);
      expect(r.ids, ['b']);
      expect(r.apply(off('a'), t0), isFalse);
    });

    test('an entry expires exactly at the TTL and not before', () {
      final r = TypingRoster()..apply(on('a'), t0);
      expect(
        r.expire(t0.add(typingReceiverTtl - const Duration(milliseconds: 1))),
        isFalse,
      );
      expect(r.expire(t0.add(typingReceiverTtl)), isTrue);
      expect(r.isEmpty, isTrue);
    });

    test('a refresh extends the TTL from the latest signal', () {
      final r = TypingRoster()..apply(on('a'), t0);
      r.apply(on('a'), t0.add(const Duration(seconds: 3)));
      expect(r.expire(t0.add(const Duration(seconds: 7))), isFalse);
      expect(r.expire(t0.add(const Duration(seconds: 9))), isTrue);
    });

    test('remove (their message arrived) and clear (disconnect)', () {
      final r = TypingRoster()
        ..apply(on('a'), t0)
        ..apply(on('b'), t0);
      expect(r.remove('a'), isTrue);
      expect(r.remove('a'), isFalse);
      expect(r.clear(), isTrue);
      expect(r.clear(), isFalse);
    });
  });

  group('two clients through a model of the server', () {
    const conv = 'conv-1';
    late TypingRelay relay;
    late DateTime now;

    /// Client B: a provider container holding B's wake channel and presence.
    ({ProviderContainer container, List<List<String>> seen}) clientB() {
      final channels = <FakeTypingChannel>[];
      final container = ProviderContainer(
        overrides: [
          messagingRealtimeEnabledProvider.overrideWithValue(true),
          messagingUserIdProvider.overrideWith((ref) => Stream.value('B')),
          messagingWakeChannelFactoryProvider.overrideWithValue((uid) {
            final c = FakeTypingChannel(
              uid,
              status: WakeChannelStatus.subscribed,
            );
            channels.add(c);
            relay.channels[uid] = c;
            return c;
          }),
          typingClockProvider.overrideWithValue(() => now),
        ],
      );
      final seen = <List<String>>[];
      container.listen(messagingWakeChannelProvider, (_, _) {});
      container.listen<List<String>>(
        typingPresenceProvider(conv),
        (_, next) => seen.add(next),
        fireImmediately: false,
      );
      return (container: container, seen: seen);
    }

    Future<void> advance(WidgetTester tester, Duration d) async {
      var left = d;
      const step = Duration(milliseconds: 500);
      while (left > Duration.zero) {
        final s = left < step ? left : step;
        now = now.add(s);
        await tester.pump(s);
        left -= s;
      }
    }

    setUp(() {
      relay = TypingRelay()..members[conv] = {'A', 'B', 'C'};
      now = DateTime(2026, 10, 20, 12);
    });

    testWidgets('TC1: A types, B sees A at once; A clears, B sees nobody', (
      tester,
    ) async {
      final b = clientB();
      await settle(tester);
      final a = TypingPublisher(
        send: (t) => relay.transportFor('A').send(conv, t),
        now: () => now,
      );
      a.draftChanged('hi');
      expect(b.container.read(typingPresenceProvider(conv)), ['A']);
      a.draftChanged('');
      expect(b.container.read(typingPresenceProvider(conv)), isEmpty);
      a.dispose();
      b.container.dispose();
    });

    testWidgets(
      'TC2: send ends typing (stop), so the row is gone when the message lands',
      (tester) async {
        final b = clientB();
        await settle(tester);
        final a = TypingPublisher(
          send: (t) => relay.transportFor('A').send(conv, t),
          now: () => now,
        );
        a.draftChanged('hello');
        expect(b.container.read(typingPresenceProvider(conv)), ['A']);
        a.stop(); // the screen calls this before it sends
        expect(b.container.read(typingPresenceProvider(conv)), isEmpty);
        a.dispose();
        b.container.dispose();
      },
    );

    testWidgets(
      'TC2b: a message from the typer clears them even if the stop was lost',
      (tester) async {
        final b = clientB();
        await settle(tester);
        relay.offline.add('A'); // the stop will not arrive
        b.container
            .read(wakeChannelOf)
            .emitTyping(
              const TypingSignal(conversationId: conv, userId: 'A', on: true),
            );
        expect(b.container.read(typingPresenceProvider(conv)), ['A']);
        b.container.read(typingPresenceProvider(conv).notifier).clearFor('A');
        expect(b.container.read(typingPresenceProvider(conv)), isEmpty);
        b.container.dispose();
      },
    );

    testWidgets(
      'TC3: two typers in a group; the order is the order they started',
      (tester) async {
        final b = clientB();
        await settle(tester);
        final a = TypingPublisher(
          send: (t) => relay.transportFor('A').send(conv, t),
          now: () => now,
        );
        final c = TypingPublisher(
          send: (t) => relay.transportFor('C').send(conv, t),
          now: () => now,
        );
        a.draftChanged('x');
        c.draftChanged('y');
        expect(b.container.read(typingPresenceProvider(conv)), ['A', 'C']);
        a.stop();
        expect(b.container.read(typingPresenceProvider(conv)), ['C']);
        a.dispose();
        c.dispose();
        b.container.dispose();
      },
    );

    testWidgets(
      'TC4: A goes offline mid-typing; B clears by itself at the TTL, not before',
      (tester) async {
        final b = clientB();
        await settle(tester);
        final a = TypingPublisher(
          send: (t) => relay.transportFor('A').send(conv, t),
          now: () => now,
        );
        a.draftChanged('typing then airplane mode');
        expect(b.container.read(typingPresenceProvider(conv)), ['A']);
        relay.offline.add(
          'A',
        ); // airplane mode / backgrounded: nothing more arrives
        await advance(
          tester,
          typingReceiverTtl - const Duration(milliseconds: 500),
        );
        expect(b.container.read(typingPresenceProvider(conv)), ['A']);
        await advance(tester, const Duration(seconds: 1));
        expect(b.container.read(typingPresenceProvider(conv)), isEmpty);
        a.dispose();
        b.container.dispose();
      },
    );

    testWidgets(
      'keeps showing while A keeps typing (refresh every few seconds)',
      (tester) async {
        final b = clientB();
        await settle(tester);
        final a = TypingPublisher(
          send: (t) => relay.transportFor('A').send(conv, t),
          now: () => now,
        );
        var text = 'a';
        for (var i = 0; i < 12; i++) {
          text += 'a';
          a.draftChanged(text);
          await advance(tester, const Duration(seconds: 1));
          expect(b.container.read(typingPresenceProvider(conv)), [
            'A',
          ], reason: 'second ${i + 1}');
        }
        // 12 s of typing sent only a handful of signals, not one per key.
        expect(relay.calls.where((c) => c.on).length, lessThanOrEqualTo(5));
        a.dispose();
        b.container.dispose();
      },
    );

    testWidgets(
      'reconnect: a drop clears B; nothing stale returns; new signals show',
      (tester) async {
        final b = clientB();
        await settle(tester);
        final ch = b.container.read(wakeChannelOf);
        ch.emitTyping(
          const TypingSignal(conversationId: conv, userId: 'A', on: true),
        );
        expect(b.container.read(typingPresenceProvider(conv)), ['A']);
        ch.setStatus(WakeChannelStatus.closed); // disconnect
        expect(b.container.read(typingPresenceProvider(conv)), isEmpty);
        ch.setStatus(WakeChannelStatus.connecting);
        ch.setStatus(WakeChannelStatus.subscribed); // reconnect
        expect(
          b.container.read(typingPresenceProvider(conv)),
          isEmpty,
          reason: 'the old signal is not resurrected',
        );
        await advance(tester, const Duration(seconds: 30));
        expect(b.container.read(typingPresenceProvider(conv)), isEmpty);
        ch.emitTyping(
          const TypingSignal(conversationId: conv, userId: 'A', on: true),
        );
        expect(b.container.read(typingPresenceProvider(conv)), ['A']);
        b.container.dispose();
      },
    );

    testWidgets('TC5: a removed member types; nobody is told', (tester) async {
      final b = clientB();
      await settle(tester);
      relay.members[conv]!.remove('A'); // A was removed from the group
      final a = TypingPublisher(
        send: (t) => relay.transportFor('A').send(conv, t),
        now: () => now,
      );
      a.draftChanged('still typing');
      expect(relay.calls.single.from, 'A'); // the call was made...
      expect(
        b.container.read(typingPresenceProvider(conv)),
        isEmpty,
      ); // ...and went nowhere
      a.dispose();
      b.container.dispose();
    });

    testWidgets('signals of another conversation, and B\'s own, are ignored', (
      tester,
    ) async {
      final b = clientB();
      await settle(tester);
      final ch = b.container.read(wakeChannelOf);
      ch.emitTyping(
        const TypingSignal(conversationId: 'other', userId: 'A', on: true),
      );
      ch.emitTyping(
        const TypingSignal(conversationId: conv, userId: 'B', on: true),
      );
      expect(b.container.read(typingPresenceProvider(conv)), isEmpty);
      b.container.dispose();
    });

    testWidgets('Realtime off: no channel, so no one is ever shown', (
      tester,
    ) async {
      final container = ProviderContainer(
        overrides: [messagingRealtimeEnabledProvider.overrideWithValue(false)],
      );
      expect(container.read(typingPresenceProvider(conv)), isEmpty);
      await settle(tester);
      container.dispose();
    });
  });
}

/// B's channel, typed.
final wakeChannelOf = Provider<FakeTypingChannel>(
  (ref) => ref.watch(messagingWakeChannelProvider)! as FakeTypingChannel,
);
