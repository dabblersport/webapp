import 'package:dabbler/features/messaging/data/fake_messaging_repository.dart';
import 'package:dabbler/features/messaging/data/receipts_transport.dart';
import 'package:dabbler/features/messaging/domain/receipt_summary.dart';
import 'package:dabbler/features/messaging/presentation/providers/messaging_providers.dart';
import 'package:dabbler/features/messaging/presentation/providers/receipts_providers.dart';
import 'package:dabbler/features/messaging/presentation/screens/game_chat_screen.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_backend.dart';

/// KAN-929: an open thread read `GET /receipts` once per frame, because the
/// screen refreshed receipts after every build and each answer rebuilt it.
/// Every answer here changes the counts, so the old loop never settles.
class _Counting implements ReceiptsTransport {
  int summariesCalls = 0;

  @override
  Future<bool> ack(String id, ReceiptState state, int throughSeq) async => true;

  @override
  Future<Map<int, ReceiptCounts>> summaries(String c, List<int> seqs) async {
    summariesCalls++;
    return {
      for (final s in seqs)
        s: ReceiptCounts(seen: 0, delivered: summariesCalls % 3, total: 3),
    };
  }

  @override
  Future<List<RecipientReceipt>?> recipients(String c, int s) async => null;
}

void main() {
  testWidgets('an open, idle thread reads receipts a bounded number of times '
      'in 60 s', (tester) async {
    final repo = FakeMessagingRepository(clock: () => DateTime(2026, 3, 3, 9))
      ..seedGameConversation('g1', messageCount: 2);
    final transport = _Counting();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          fakeMessagingBackend,
          fakeMessagingRepositoryProvider.overrideWithValue(repo),
          gameChatPollIntervalProvider.overrideWithValue(null),
          receiptsTransportProvider.overrideWithValue(transport),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: DabblerDesignSystemTheme.withFonts(
            DabblerDesignSystemTheme.withTokens(ThemeData.light()),
            locale: const Locale('en'),
          ),
          home: const GameChatScreen(gameId: 'g1'),
        ),
      ),
    );
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    final container = ProviderScope.containerOf(
      tester.element(find.byType(GameChatScreen)),
    );
    // The caller's own message, so there is something to read receipts for.
    await container.read(gameChatControllerProvider('g1').notifier).send('hi');
    for (var i = 0; i < 600; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    // Open + the new message + three 20 s polls; the old loop made ~600.
    expect(transport.summariesCalls, greaterThanOrEqualTo(1));
    expect(transport.summariesCalls, lessThanOrEqualTo(6));
    await tester.pumpWidget(const SizedBox());
  });

  group('ReceiptCountsNotifier', () {
    test('the same seqs are not re-read within minRepeat; later they are; '
        'new seqs always are', () async {
      var now = DateTime(2026, 11, 14, 12);
      final transport = _Counting();
      final n = ReceiptCountsNotifier(transport, 'c1', now: () => now);
      await n.refresh([1]);
      await n.refresh([1]);
      now = now.add(const Duration(seconds: 1));
      await n.refresh([1]);
      expect(transport.summariesCalls, 1);
      await n.refresh([1, 2]);
      expect(transport.summariesCalls, 2);
      now = now.add(ReceiptCountsNotifier.minRepeat);
      await n.refresh([1, 2]);
      expect(transport.summariesCalls, 3);
      n.dispose();
    });

    test('an unchanged answer does not replace the state', () async {
      var now = DateTime(2026, 11, 14, 12);
      final transport = _SameAnswer();
      final n = ReceiptCountsNotifier(transport, 'c1', now: () => now);
      var notified = 0;
      n.addListener((_) => notified++, fireImmediately: false);
      await n.refresh([1]);
      now = now.add(const Duration(seconds: 30));
      await n.refresh([1]);
      expect(transport.calls, 2);
      expect(notified, 1);
      n.dispose();
    });
  });
}

class _SameAnswer extends _Counting {
  int calls = 0;

  @override
  Future<Map<int, ReceiptCounts>> summaries(String c, List<int> seqs) async {
    calls++;
    return {
      for (final s in seqs) s: const ReceiptCounts(delivered: 1, total: 3),
    };
  }
}
