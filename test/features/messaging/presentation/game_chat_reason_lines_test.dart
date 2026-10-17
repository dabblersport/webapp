import 'dart:io';

import 'package:dabbler/features/messaging/data/fake_messaging_repository.dart';
import 'package:dabbler/features/messaging/domain/typed_reason.dart';
import 'package:dabbler/features/messaging/presentation/providers/messaging_providers.dart';
import 'package:dabbler/features/messaging/presentation/screens/game_chat_screen.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support/fake_backend.dart';

import '../../../support/render_mode.dart';

/// KAN-533: each of the eight typed reasons shows its existing
/// `messaging_reason_*` line (KAN-514), in English (LTR) and Arabic (RTL).
/// Fake repository only; no network, no database.

typedef _Line = String Function(AppLocalizations l10n);

/// The eight reasons and the existing string each must show.
final Map<MessagingReason, _Line> _lines = {
  MessagingReason.notAMember: (l) => l.messaging_reason_not_a_member,
  MessagingReason.leftReadOnly: (l) => l.messaging_reason_left_read_only,
  MessagingReason.blocked: (l) => l.messaging_reason_blocked,
  MessagingReason.suspended: (l) => l.messaging_reason_suspended,
  MessagingReason.rateLimited: (l) => l.messaging_reason_rate_limited,
  MessagingReason.notFound: (l) => l.messaging_reason_not_found,
  MessagingReason.invalidRequest: (l) => l.messaging_reason_invalid_request,
  MessagingReason.unknown: (l) => l.messaging_reason_unknown,
};

/// The load failures that reach the generic error state (AC1).
const List<MessagingReason> _loadReasons = [
  MessagingReason.notAMember,
  MessagingReason.blocked,
  MessagingReason.suspended,
  MessagingReason.notFound,
  MessagingReason.invalidRequest,
  MessagingReason.unknown,
];

const List<Locale> _locales = [Locale('en'), Locale('ar')];

Widget _app(FakeMessagingRepository repo, Locale locale) {
  var n = 0;
  return ProviderScope(
    overrides: [
      fakeMessagingBackend,
      fakeMessagingRepositoryProvider.overrideWithValue(repo),
      messagingClientKeyGeneratorProvider.overrideWithValue(() => 'key-${++n}'),
      gameChatPollIntervalProvider.overrideWithValue(null),
      messagingClockProvider.overrideWithValue(() => DateTime(2026, 3, 3, 20)),
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: DabblerDesignSystemTheme.withFonts(
        DabblerDesignSystemTheme.withTokens(renderThemeBase()),
        locale: locale,
      ),
      home: const GameChatScreen(gameId: 'g1'),
    ),
  );
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

TextDirection _direction(WidgetTester tester) =>
    Directionality.of(tester.element(find.byType(GameChatScreen)));

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

  for (final locale in _locales) {
    final l10n = lookupAppLocalizations(locale);
    final rtl = locale.languageCode == 'ar';
    final tag = locale.languageCode;

    group('[$tag] a rejected send shows the reason line (AC2, AC4)', () {
      for (final entry in _lines.entries) {
        final reason = entry.key;
        testWidgets('${reason.wireName}', (tester) async {
          final repo = FakeMessagingRepository(currentUserId: 'me')
            ..seedGameConversation('g1', messageCount: 2);
          await tester.pumpWidget(_app(repo, locale));
          await _settle(tester);
          expect(
            _direction(tester),
            rtl ? TextDirection.rtl : TextDirection.ltr,
          );

          repo.failNext(FakeMessagingOp.sendTextMessage, reason);
          await tester.enterText(find.byType(EditableText), 'hello');
          await tester.pump();
          await tester.tap(find.bySemanticsLabel(l10n.messaging_chat_send));
          await _settle(tester);

          // The exact existing string for this locale, shown once, with the
          // failed state and the Retry still there.
          expect(find.text(entry.value(l10n)), findsOneWidget);
          final thread = tester.widget<DabblerMessageThread>(
            find.byKey(GameChatScreen.threadKey),
          );
          final failed = thread.items.whereType<DabblerThreadMessage>().last;
          expect(failed.deliveryState, DabblerDeliveryState.failed);
          expect(find.text(l10n.messaging_chat_retry), findsOneWidget);

          // Retry works: the next attempt succeeds and the line goes away.
          await tester.tap(find.text(l10n.messaging_chat_retry));
          await _settle(tester);
          expect(find.text(entry.value(l10n)), findsNothing);
          expect(repo.sendAttempts, 2);
          expect(tester.takeException(), isNull);
        });
      }
    });

    group('[$tag] a load failure shows the reason line (AC1)', () {
      for (final reason in _loadReasons) {
        testWidgets('${reason.wireName}', (tester) async {
          final repo = FakeMessagingRepository()
            ..seedGameConversation('g1', messageCount: 2)
            ..failAlways(FakeMessagingOp.getGameConversation, reason);
          await tester.pumpWidget(_app(repo, locale));
          await _settle(tester);
          expect(
            _direction(tester),
            rtl ? TextDirection.rtl : TextDirection.ltr,
          );

          expect(find.byKey(GameChatScreen.errorKey), findsOneWidget);
          expect(find.text(_lines[reason]!(l10n)), findsOneWidget);
          // The generic line is replaced, the retry action is kept.
          expect(find.text(l10n.messaging_chat_error), findsNothing);
          expect(find.text(l10n.messaging_chat_offline_retry), findsOneWidget);

          // Retry after the failure is cleared loads the thread.
          repo.clearFailures();
          await tester.tap(find.text(l10n.messaging_chat_offline_retry));
          await _settle(tester);
          expect(find.byKey(GameChatScreen.errorKey), findsNothing);
          expect(find.byKey(GameChatScreen.threadKey), findsOneWidget);
          expect(tester.takeException(), isNull);
        });
      }
    });

    testWidgets('[$tag] left_read_only replaces the composer (AC3)', (
      tester,
    ) async {
      final repo = FakeMessagingRepository()
        ..seedGameConversation(
          'g1',
          messageCount: 3,
          writable: false,
          readOnlyReason: MessagingReason.leftReadOnly,
        );
      await tester.pumpWidget(_app(repo, locale));
      await _settle(tester);
      expect(_direction(tester), rtl ? TextDirection.rtl : TextDirection.ltr);

      expect(find.text(l10n.messaging_reason_left_read_only), findsOneWidget);
      expect(find.byKey(GameChatScreen.composerKey), findsNothing);
      expect(find.byType(EditableText), findsNothing);
      // Earlier messages stay readable.
      expect(find.byKey(GameChatScreen.threadKey), findsOneWidget);
      expect(find.text('m3'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  group('unchanged behaviour (AC5)', () {
    for (final r in [
      MessagingReason.gameEnded,
      MessagingReason.gameCancelled,
    ]) {
      testWidgets('${r.wireName} keeps the closed notice', (tester) async {
        final l10n = lookupAppLocalizations(const Locale('en'));
        final repo = FakeMessagingRepository()
          ..seedGameConversation(
            'g1',
            messageCount: 2,
            writable: false,
            readOnlyReason: r,
          );
        await tester.pumpWidget(_app(repo, const Locale('en')));
        await _settle(tester);
        expect(
          find.text(
            r == MessagingReason.gameCancelled
                ? l10n.messaging_chat_closed_cancelled
                : l10n.messaging_chat_closed_ended,
          ),
          findsOneWidget,
        );
        expect(find.text(l10n.messaging_reason_left_read_only), findsNothing);
      });
    }

    testWidgets('a failed send with offline shows no reason line', (
      tester,
    ) async {
      final l10n = lookupAppLocalizations(const Locale('en'));
      final repo = FakeMessagingRepository()
        ..seedGameConversation('g1', messageCount: 1);
      await tester.pumpWidget(_app(repo, const Locale('en')));
      await _settle(tester);
      repo.failNext(FakeMessagingOp.sendTextMessage, MessagingReason.offline);
      await tester.enterText(find.byType(EditableText), 'hi');
      await tester.pump();
      await tester.tap(find.bySemanticsLabel(l10n.messaging_chat_send));
      await _settle(tester);
      for (final line in _lines.values) {
        expect(find.text(line(l10n)), findsNothing);
      }
      expect(find.text(l10n.messaging_chat_retry), findsOneWidget);
    });
  });

  test('the suspended line is plain text: no link, route or support entry', () {
    for (final f in const [
      'lib/features/messaging/presentation/widgets/game_chat_reason_text.dart',
      'lib/features/messaging/presentation/screens/game_chat_screen.dart',
      'lib/features/messaging/presentation/widgets/game_chat_thread_items.dart',
    ]) {
      final src = File(f).readAsStringSync();
      expect(src, isNot(contains('/help')), reason: f);
      expect(src, isNot(contains('ContactSupport')), reason: f);
      expect(src, isNot(contains('launchUrl')), reason: f);
    }
  });
}
