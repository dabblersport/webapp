import 'package:dabbler/features/messaging/data/fake_messaging_repository.dart';
import 'package:dabbler/features/messaging/data/receipts_transport.dart';
import 'package:dabbler/features/messaging/presentation/providers/messaging_providers.dart';
import 'package:dabbler/features/messaging/presentation/providers/receipts_providers.dart';
import 'package:dabbler/features/messaging/presentation/screens/game_chat_screen.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_backend.dart';

/// KAN-580: the thread acknowledges the other people's messages, delivered on
/// receipt and seen while it is on screen, and sends nothing when there is
/// nothing to acknowledge.
class _Recording implements ReceiptsTransport {
  final List<(String, ReceiptState, int)> calls = [];

  @override
  Future<void> ack(String id, ReceiptState state, int throughSeq) async =>
      calls.add((id, state, throughSeq));
}

Future<_Recording> _open(
  WidgetTester tester, {
  required int messageCount,
}) async {
  final repo = FakeMessagingRepository(
    clock: () => DateTime(2026, 3, 3, 9),
    currentUserId: 'someone-else',
  )..seedGameConversation('g1', messageCount: messageCount);
  final transport = _Recording();
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
  return transport;
}

void main() {
  testWidgets('a thread with messages acknowledges the newest as seen', (
    tester,
  ) async {
    final t = await _open(tester, messageCount: 3);
    expect(t.calls, isNotEmpty);
    expect(t.calls.every((c) => c.$3 > 0), isTrue);
    // Foreground: the one ack is "seen" (it also raises delivered).
    expect(t.calls.map((c) => c.$2).toSet(), {ReceiptState.seen});
    // Monotonic: the same seq is never sent twice.
    expect(t.calls.map((c) => c.$3).toSet().length, t.calls.length);
  });

  testWidgets('backgrounding sends nothing new; returning does not repeat a seq', (
    tester,
  ) async {
    final t = await _open(tester, messageCount: 1);
    t.calls.clear();
    for (final s in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(s);
    }
    await tester.pump(const Duration(milliseconds: 100));
    // Nothing new while backgrounded.
    expect(t.calls, isEmpty);
    for (final s in [
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(s);
    }
    await tester.pump(const Duration(milliseconds: 100));
  });
}
