import 'package:dabbler/features/messaging/data/fake_messaging_repository.dart';
import 'package:dabbler/features/messaging/presentation/providers/messaging_providers.dart';
import 'package:dabbler/features/messaging/presentation/screens/game_chat_screen.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_backend.dart';

/// KAN-928: the meetup chat screen opens the meetup's conversation and is
/// titled with the meetup's title; without one it keeps the generic title.
Future<void> _open(
  WidgetTester tester,
  GameChatScreen screen, {
  int messageCount = 2,
}) async {
  final repo = FakeMessagingRepository(clock: () => DateTime(2026, 3, 3, 9))
    ..seedMeetupConversation('mt1', messageCount: messageCount)
    ..seedGameConversation('g1');
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        fakeMessagingBackend,
        fakeMessagingRepositoryProvider.overrideWithValue(repo),
        gameChatPollIntervalProvider.overrideWithValue(null),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: DabblerDesignSystemTheme.withFonts(
          DabblerDesignSystemTheme.withTokens(ThemeData.light()),
          locale: const Locale('en'),
        ),
        home: screen,
      ),
    ),
  );
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets('titled with the meetup; shows its messages', (tester) async {
    await _open(
      tester,
      const GameChatScreen.meetup(meetupId: 'mt1', title: 'Sunrise run'),
    );
    expect(find.text('Sunrise run'), findsOneWidget);
    expect(find.text('m1'), findsOneWidget);
    expect(find.byKey(GameChatScreen.composerKey), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('no title: the generic chat title', (tester) async {
    await _open(tester, const GameChatScreen.meetup(meetupId: 'mt1'));
    final l = AppLocalizations.of(tester.element(find.byType(GameChatScreen)));
    expect(find.text(l.messaging_chat_title), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('empty meetup chat: meetup wording, not game wording', (
    tester,
  ) async {
    await _open(
      tester,
      const GameChatScreen.meetup(meetupId: 'mt1'),
      messageCount: 0,
    );
    final l = AppLocalizations.of(tester.element(find.byType(GameChatScreen)));
    expect(find.byKey(GameChatScreen.emptyKey), findsOneWidget);
    expect(find.text(l.messaging_meetup_chat_empty), findsOneWidget);
    expect(find.text(l.messaging_chat_empty_body), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('empty game chat: keeps the game wording', (tester) async {
    await _open(tester, const GameChatScreen(gameId: 'g1'), messageCount: 0);
    final l = AppLocalizations.of(tester.element(find.byType(GameChatScreen)));
    expect(find.byKey(GameChatScreen.emptyKey), findsOneWidget);
    expect(find.text(l.messaging_chat_empty_body), findsOneWidget);
    expect(find.text(l.messaging_meetup_chat_empty), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}
