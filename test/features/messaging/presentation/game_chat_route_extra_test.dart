import 'package:dabbler/features/messaging/data/fake_messaging_repository.dart';
import 'package:dabbler/features/messaging/domain/typed_reason.dart';
import 'package:dabbler/features/messaging/presentation/game_chat_route.dart';
import 'package:dabbler/features/messaging/presentation/providers/messaging_providers.dart';
import 'package:dabbler/features/messaging/presentation/screens/game_chat_screen.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../support/fake_backend.dart';

/// KAN-572: a push tap opens /messaging/game/:gameId with no `extra`. A
/// missing (or non-DateTime) endAt is treated as open; only the conversation's
/// own writable/read_only_reason makes the chat read-only.
final _now = DateTime(2026, 3, 3, 20);

GoRouter _router() => GoRouter(
  initialLocation: '/start',
  routes: [
    GoRoute(path: '/start', builder: (c, s) => const SizedBox()),
    gameChatRoute(messaging: true, gameChat: true),
  ],
);

Widget _app(GoRouter router, FakeMessagingRepository repo, Locale locale) =>
    ProviderScope(
      overrides: [
        fakeMessagingBackend,
        fakeMessagingRepositoryProvider.overrideWithValue(repo),
        gameChatPollIntervalProvider.overrideWithValue(null),
        messagingClockProvider.overrideWithValue(() => _now),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: DabblerDesignSystemTheme.withTokens(ThemeData.light()),
      ),
    );

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

FakeMessagingRepository _repo({bool writable = true}) =>
    FakeMessagingRepository(clock: () => DateTime(2026, 3, 3, 10))
      ..seedGameConversation(
        'g1',
        messageCount: 3,
        writable: writable,
        readOnlyReason: writable ? null : MessagingReason.leftReadOnly,
      );

List<String> _systemTexts(WidgetTester tester) => [
  for (final i
      in tester
          .widget<DabblerMessageThread>(find.byKey(GameChatScreen.threadKey))
          .items)
    if (i is DabblerThreadSystem) i.text,
];

void main() {
  for (final locale in const [Locale('en'), Locale('ar')]) {
    group('[${locale.languageCode}]', () {
      final l10n = lookupAppLocalizations(locale);

      for (final extra in const <Object?>[null, 'not-a-date']) {
        testWidgets('extra=$extra: writable chat renders open with composer', (
          tester,
        ) async {
          final router = _router();
          await tester.pumpWidget(_app(router, _repo(), locale));
          router.go('/messaging/game/g1', extra: extra);
          await _settle(tester);
          expect(tester.takeException(), isNull);
          final screen = tester.widget<GameChatScreen>(
            find.byType(GameChatScreen),
          );
          expect(screen.gameEndAt, isNull);
          expect(find.byKey(GameChatScreen.threadKey), findsOneWidget);
          expect(find.byKey(GameChatScreen.composerKey), findsOneWidget);
          expect(
            _systemTexts(tester),
            isNot(contains(l10n.messaging_chat_game_finished)),
          );
          expect(find.text(l10n.messaging_reason_left_read_only), findsNothing);
        });
      }

      testWidgets('no extra, read-only conversation: read-only from repo', (
        tester,
      ) async {
        final router = _router();
        await tester.pumpWidget(_app(router, _repo(writable: false), locale));
        router.go('/messaging/game/g1');
        await _settle(tester);
        expect(tester.takeException(), isNull);
        expect(find.byKey(GameChatScreen.threadKey), findsOneWidget);
        expect(find.byKey(GameChatScreen.composerKey), findsNothing);
        expect(
          _systemTexts(tester),
          isNot(contains(l10n.messaging_chat_game_finished)),
        );
      });

      testWidgets('endAt supplied: passed through, finished line drawn', (
        tester,
      ) async {
        final endAt = DateTime(2026, 3, 3, 12);
        final router = _router();
        await tester.pumpWidget(_app(router, _repo(), locale));
        router.go('/messaging/game/g1', extra: endAt);
        await _settle(tester);
        expect(tester.takeException(), isNull);
        expect(
          tester.widget<GameChatScreen>(find.byType(GameChatScreen)).gameEndAt,
          endAt,
        );
        expect(
          _systemTexts(tester),
          contains(l10n.messaging_chat_game_finished),
        );
      });
    });
  }
}
