import 'dart:async';

import 'package:dabbler/features/messaging/data/fake_messaging_repository.dart';
import 'package:dabbler/features/messaging/data/messaging_wake_channel.dart';
import 'package:dabbler/features/messaging/presentation/providers/messaging_providers.dart';
import 'package:dabbler/features/messaging/presentation/providers/messaging_realtime_providers.dart';
import 'package:dabbler/features/messaging/presentation/screens/game_chat_screen.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/render_mode.dart';
import 'fake_wake_channel.dart';

/// KAN-544: the open chat shows a message as soon as its wake arrives (no wait
/// for the 15 s poll), and a closed chat ignores wakes. Fake channel and fake
/// repository only.
void main() {
  setUpAll(() async {
    await loadRenderFonts();
  });

  setUp(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.physicalSize = const Size(390 * 3, 844 * 3);
    view.devicePixelRatio = 3;
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets(
    'a wake shows the new message at once; a closed chat ignores it',
    (tester) async {
      final repo = FakeMessagingRepository()
        ..seedGameConversation('g1', messageCount: 2);
      final user = StreamController<String?>();
      addTearDown(() => unawaited(user.close()));
      late FakeWakeChannel channel;
      final container = ProviderContainer(
        overrides: [
          fakeMessagingRepositoryProvider.overrideWithValue(repo),
          gameChatPollIntervalProvider.overrideWithValue(
            const Duration(seconds: 15),
          ),
          messagingRealtimeEnabledProvider.overrideWithValue(true),
          messagingUserIdProvider.overrideWith((ref) => user.stream),
          messagingWakeChannelFactoryProvider.overrideWithValue(
            (uid) => channel = FakeWakeChannel(uid),
          ),
        ],
      );
      addTearDown(container.dispose);
      final channelListener = container.listen(
        messagingWakeChannelProvider,
        (_, _) {},
      );
      addTearDown(channelListener.close);
      user.add('u1');
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );

      Widget app({required bool chatOpen}) => UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: DabblerDesignSystemTheme.withFonts(
            DabblerDesignSystemTheme.withTokens(renderThemeBase()),
            locale: const Locale('en'),
          ),
          home: chatOpen
              ? const GameChatScreen(gameId: 'g1')
              : const Scaffold(body: SizedBox()),
        ),
      );

      await tester.pumpWidget(app(chatOpen: true));
      await settle(tester);
      expect(find.text('m2'), findsOneWidget);
      expect(find.text('m3'), findsNothing);

      // Subscribed: the screen polls at the 60 s safety cadence now.
      channel.setStatus(WakeChannelStatus.subscribed);
      await settle(tester);
      expect(
        container.read(gameChatEffectivePollProvider),
        const Duration(seconds: 60),
      );

      // A message arrives; its wake shows it well before any poll.
      await repo.sendTextMessage(
        conversationId: 'conv-g1',
        body: 'arrived by wake',
        idempotencyKey: 'k-1',
      );
      channel.emit(const MessagingWake(conversationId: 'conv-g1', seq: 3));
      await settle(tester);
      expect(find.text('arrived by wake'), findsOneWidget);

      // The chat closes: a later wake fetches nothing.
      await tester.pumpWidget(app(chatOpen: false));
      await settle(tester);
      await repo.sendTextMessage(
        conversationId: 'conv-g1',
        body: 'sent while closed',
        idempotencyKey: 'k-2',
      );
      channel.emit(const MessagingWake(conversationId: 'conv-g1', seq: 4));
      await settle(tester);
      final items = container
          .read(gameChatControllerProvider('g1'))
          .requireValue
          .items
          .map((i) => i.body);
      expect(items, isNot(contains('sent while closed')));
    },
  );
}
