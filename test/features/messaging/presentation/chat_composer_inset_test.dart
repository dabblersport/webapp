// KAN-578: the chat composer's bottom safe-area spacing.
//
// The composer is the bottom bar of a DabblerPage. Measured with
// tester.getRect against the 390x844 screen and the keyboard top.
import 'package:dabbler/features/messaging/data/fake_messaging_repository.dart';
import 'package:dabbler/features/messaging/presentation/providers/messaging_providers.dart';
import 'package:dabbler/features/messaging/presentation/screens/game_chat_screen.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/render_mode.dart';
import '../support/fake_backend.dart';

const double _screenH = 844;

/// One device inset situation. [keyboard] is viewInsets.bottom; padding is
/// derived as Flutter does on a device: max(viewPadding - keyboard, 0), unless
/// [rawPadding] forces the padding to stay (the stricter case).
class _Insets {
  const _Insets(this.safe, {this.keyboard = 0, this.rawPadding = false});
  final double safe;
  final double keyboard;
  final bool rawPadding;

  MediaQueryData apply(MediaQueryData d) {
    final padding = rawPadding
        ? safe
        : (safe - keyboard).clamp(0, double.infinity).toDouble();
    return d.copyWith(
      padding: d.padding.copyWith(bottom: padding),
      viewPadding: d.viewPadding.copyWith(bottom: safe),
      viewInsets: d.viewInsets.copyWith(bottom: keyboard),
    );
  }
}

Widget _app(
  FakeMessagingRepository repo,
  ValueNotifier<_Insets> insets, {
  Locale locale = const Locale('en'),
  double scale = 1,
}) {
  var n = 0;
  return ProviderScope(
    overrides: [
      fakeMessagingBackend,
      fakeMessagingRepositoryProvider.overrideWithValue(repo),
      messagingClientKeyGeneratorProvider.overrideWithValue(() => 'key-${++n}'),
      gameChatPollIntervalProvider.overrideWithValue(null),
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
      builder: (context, child) => ValueListenableBuilder<_Insets>(
        valueListenable: insets,
        builder: (context, i, _) => MediaQuery(
          data: i.apply(
            MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
          ),
          child: child!,
        ),
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

Rect _composer(WidgetTester tester) =>
    tester.getRect(find.byKey(GameChatScreen.composerKey));

/// The text field's box inside the composer (the visible input pill).
Rect _field(WidgetTester tester) => tester.getRect(
  find
      .descendant(
        of: find.byKey(GameChatScreen.composerKey),
        matching: find.byType(EditableText),
      )
      .first,
);

void main() {
  setUpAll(() async {
    await loadRenderFonts();
  });

  setUp(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.physicalSize = const Size(390 * 3, _screenH * 3);
    view.devicePixelRatio = 3;
  });

  const keyboardClosed = <String, double>{
    'no inset': 0,
    'android gesture': 24,
    'ios home indicator': 34,
    'android three-button': 48,
  };

  const variants = [
    (name: 'ltr', locale: Locale('en'), scale: 1.0),
    (name: 'rtl', locale: Locale('ar'), scale: 1.0),
    (name: 'ltr-200', locale: Locale('en'), scale: 2.0),
  ];

  for (final v in variants) {
    group('[${v.name}]', () {
      for (final e in keyboardClosed.entries) {
        testWidgets('keyboard closed, ${e.key} (${e.value})', (tester) async {
          final repo = FakeMessagingRepository(currentUserId: 'me')
            ..seedGameConversation('g1', messageCount: 3);
          final insets = ValueNotifier(_Insets(e.value));
          await tester.pumpWidget(
            _app(repo, insets, locale: v.locale, scale: v.scale),
          );
          await _settle(tester);
          final composerGap = _screenH - _composer(tester).bottom;
          final fieldGap = _screenH - _field(tester).bottom;
          // ignore: avoid_print
          print(
            'KAN-578 [${v.name}] closed safe=${e.value}: '
            'composerGap=$composerGap fieldGap=$fieldGap',
          );
          // The composer box clears the system inset exactly (no doubling).
          expect(composerGap, e.value);
          // The input keeps a comfortable gap above the system UI.
          expect(
            fieldGap,
            greaterThanOrEqualTo(e.value + DabblerSpacing.space4),
          );
          expect(tester.takeException(), isNull);
        });
      }

      testWidgets('keyboard open: composer sits on the keyboard', (
        tester,
      ) async {
        final repo = FakeMessagingRepository(currentUserId: 'me')
          ..seedGameConversation('g1', messageCount: 3);
        final insets = ValueNotifier(const _Insets(34, keyboard: 300));
        await tester.pumpWidget(
          _app(repo, insets, locale: v.locale, scale: v.scale),
        );
        await _settle(tester);
        final kbTop = _screenH - 300;
        final gap = kbTop - _composer(tester).bottom;
        // ignore: avoid_print
        print('KAN-578 [${v.name}] keyboard open safe=34: composerGap=$gap');
        expect(gap, 0);
        expect(tester.takeException(), isNull);
      });
    });
  }

  testWidgets('keyboard open with padding not yet cleared: still no gap', (
    tester,
  ) async {
    final repo = FakeMessagingRepository(currentUserId: 'me')
      ..seedGameConversation('g1', messageCount: 3);
    final insets = ValueNotifier(
      const _Insets(34, keyboard: 300, rawPadding: true),
    );
    await tester.pumpWidget(_app(repo, insets));
    await _settle(tester);
    final gap = (_screenH - 300) - _composer(tester).bottom;
    // ignore: avoid_print
    print('KAN-578 keyboard open, raw padding 34: composerGap=$gap');
    expect(gap, 0);
  });

  testWidgets('draft and latest message survive the keyboard opening', (
    tester,
  ) async {
    final repo = FakeMessagingRepository(currentUserId: 'me')
      ..seedGameConversation('g1', messageCount: 35);
    final insets = ValueNotifier(const _Insets(34));
    await tester.pumpWidget(_app(repo, insets));
    await _settle(tester);
    await tester.enterText(
      find.descendant(
        of: find.byKey(GameChatScreen.composerKey),
        matching: find.byType(EditableText),
      ),
      'draft',
    );
    await tester.pump();

    insets.value = const _Insets(34, keyboard: 300);
    await _settle(tester);

    expect(
      tester
          .widget<EditableText>(
            find.descendant(
              of: find.byKey(GameChatScreen.composerKey),
              matching: find.byType(EditableText),
            ),
          )
          .controller
          .text,
      'draft',
    );
    // The newest message is drawn above the composer, not under it.
    final latest = tester.getRect(find.text('m35').last);
    expect(latest.bottom, lessThanOrEqualTo(_composer(tester).top));
    expect(latest.top, greaterThanOrEqualTo(0));

    insets.value = const _Insets(34);
    await _settle(tester);
    expect(_screenH - _composer(tester).bottom, 34);
    expect(
      tester.getRect(find.text('m35').last).bottom,
      lessThanOrEqualTo(_composer(tester).top),
    );
  });
}
