import 'dart:io';
import 'dart:ui' as ui;

import 'package:dabbler/features/messaging/data/fake_messaging_repository.dart';
import 'package:dabbler/features/messaging/domain/typed_reason.dart';
import 'package:dabbler/features/messaging/presentation/game_chat_route.dart';
import 'package:dabbler/features/messaging/presentation/providers/messaging_providers.dart';
import 'package:dabbler/features/messaging/presentation/screens/game_chat_screen.dart';
import 'package:dabbler/features/messaging/presentation/widgets/game_chat_access_state.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/l10n/app_localizations_ar.dart';
import 'package:dabbler/l10n/app_localizations_en.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../support/render_mode.dart';

typedef _Variant = ({String name, Locale locale, double scale});

const List<_Variant> _variants = [
  (name: 'ltr', locale: Locale('en'), scale: 1.0),
  (name: 'rtl', locale: Locale('ar'), scale: 1.0),
  (name: 'ltr-200', locale: Locale('en'), scale: 2.0),
  (name: 'rtl-200', locale: Locale('ar'), scale: 2.0),
];

final _boundary = GlobalKey();

/// Home, then the chat route pushed on top (so the action pops back home).
/// Both flags are passed true explicitly here, test-only, so the screen's own
/// typed-reason path runs; the committed flags are untouched.
Widget _app(FakeMessagingRepository repo, _Variant v, GoRouter router) =>
    ProviderScope(
      overrides: [
        fakeMessagingRepositoryProvider.overrideWithValue(repo),
        gameChatPollIntervalProvider.overrideWithValue(null),
      ],
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        routerConfig: router,
        locale: v.locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: DabblerDesignSystemTheme.withFonts(
          DabblerDesignSystemTheme.withTokens(renderThemeBase()),
          locale: v.locale,
        ),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(v.scale)),
          child: RepaintBoundary(key: _boundary, child: child),
        ),
      ),
    );

GoRouter _router({bool enabled = true}) => GoRouter(
  initialLocation: RoutePaths.home,
  routes: [
    GoRoute(
      path: RoutePaths.home,
      builder: (c, s) => const SizedBox(key: ValueKey('home')),
    ),
    gameChatRoute(messaging: enabled, gameChat: enabled),
  ],
);

Future<void> _open(WidgetTester tester, GoRouter router) async {
  router.push('/messaging/game/g1');
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _shot(WidgetTester tester, String name) async {
  final boundary =
      _boundary.currentContext?.findRenderObject() as RenderRepaintBoundary?;
  if (boundary == null) return;
  await tester.runAsync(() async {
    final ui.Image image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (bytes == null) return;
    final file = File('$kShotsRoot/kan518/$name.png');
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(bytes.buffer.asUint8List());
  });
}

/// One icon, ONE line, ONE action; nothing about the conversation; none of the
/// out-of-scope surfaces.
void _expectShape(WidgetTester tester, String icon, String line) {
  final empty = tester.widget<DabblerEmptyState>(
    find.byType(DabblerEmptyState),
  );
  expect(empty.icon, icon);
  expect(empty.title, line);
  expect(empty.text, isNull);
  expect(empty.size, DabblerEmptyStateSize.page);
  expect(find.byType(DabblerButton), findsOneWidget);
  final top = tester.widget<DabblerNavigationTopBar>(
    find.byType(DabblerNavigationTopBar),
  );
  expect(top.title, isNull);
  expect(top.actions, isEmpty);
  expect(find.byKey(GameChatScreen.threadKey), findsNothing);
  expect(find.byKey(GameChatScreen.composerKey), findsNothing);
  expect(find.byType(DabblerChatComposer), findsNothing);
  expect(find.byType(DabblerTypingIndicator), findsNothing);
  final icons = tester
      .widgetList<DabblerIcon>(find.byType(DabblerIcon))
      .map((i) => i.name);
  expect(icons, isNot(contains('tick-circle')));
  for (final s in const ['24 hours', 'Leave', 'Try again', 'Retry']) {
    expect(find.textContaining(s), findsNothing);
  }
  expect(tester.takeException(), isNull);
}

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

  for (final v in _variants) {
    final l10n = v.locale.languageCode == 'ar'
        ? AppLocalizationsAr()
        : AppLocalizationsEn();
    group('[${v.name}]', () {
      testWidgets('not_in_pilot shows unavailable; action goes back', (
        tester,
      ) async {
        final repo = FakeMessagingRepository()
          ..seedGameConversation('g1', messageCount: 3)
          ..failAlways(
            FakeMessagingOp.getGameConversation,
            MessagingReason.notInPilot,
          );
        final router = _router();
        await tester.pumpWidget(_app(repo, v, router));
        await _open(tester, router);
        expect(find.byKey(GameChatAccessState.unavailableKey), findsOneWidget);
        _expectShape(
          tester,
          'info-circle',
          l10n.messaging_chat_unavailable_line,
        );
        expect(
          find.text(l10n.messaging_chat_unavailable_action),
          findsOneWidget,
        );
        await _shot(tester, 'unavailable-${v.name}');
        await tester.tap(find.byKey(GameChatAccessState.actionKey));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('home')), findsOneWidget);
        expect(find.byKey(GameChatAccessState.unavailableKey), findsNothing);
      });

      testWidgets('flags false: deep link shows unavailable', (tester) async {
        final repo = FakeMessagingRepository()
          ..seedGameConversation('g1', messageCount: 3);
        final router = _router(enabled: false);
        await tester.pumpWidget(_app(repo, v, router));
        await _open(tester, router);
        expect(find.byKey(GameChatAccessState.unavailableKey), findsOneWidget);
        expect(find.byType(GameChatScreen), findsNothing);
        _expectShape(
          tester,
          'info-circle',
          l10n.messaging_chat_unavailable_line,
        );
      });

      testWidgets('removed shows the removed state; action goes back', (
        tester,
      ) async {
        final repo = FakeMessagingRepository()
          ..seedGameConversation('g1', messageCount: 3)
          ..failAlways(
            FakeMessagingOp.getGameConversation,
            MessagingReason.removed,
          );
        final router = _router();
        await tester.pumpWidget(_app(repo, v, router));
        await _open(tester, router);
        expect(find.byKey(GameChatAccessState.removedKey), findsOneWidget);
        _expectShape(tester, 'lock', l10n.messaging_chat_removed_line);
        await _shot(tester, 'removed-${v.name}');
        await tester.tap(find.byKey(GameChatAccessState.actionKey));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('home')), findsOneWidget);
      });
    });
  }

  testWidgets('removed while inside the thread swaps the thread out', (
    tester,
  ) async {
    final repo = FakeMessagingRepository()
      ..seedGameConversation('g1', messageCount: 3);
    final router = _router();
    await tester.pumpWidget(_app(repo, _variants.first, router));
    await _open(tester, router);
    expect(find.byKey(GameChatScreen.threadKey), findsOneWidget);
    repo.failAlways(FakeMessagingOp.listMessages, MessagingReason.removed);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(GameChatScreen)),
    );
    await container
        .read(gameChatControllerProvider('g1').notifier)
        .refreshNewest();
    await tester.pump();
    expect(find.byKey(GameChatAccessState.removedKey), findsOneWidget);
    expect(find.byKey(GameChatScreen.threadKey), findsNothing);
    expect(
      container.read(gameChatControllerProvider('g1')).value!.items,
      isEmpty,
    );
  });

  test('removed copy says nothing about why or by whom (EN and AR)', () {
    const forbiddenEn = [
      'removed',
      'kick',
      'block',
      'ban',
      'report',
      'organiser',
      'organizer',
      ' by ',
      'because',
      'reason',
    ];
    const forbiddenAr = [
      'أزال',
      'إزالة',
      'طرد',
      'حظر',
      'بلاغ',
      'المنظم',
      'بسبب',
      'بواسطة',
    ];
    final en = AppLocalizationsEn();
    final ar = AppLocalizationsAr();
    for (final s in [
      en.messaging_chat_removed_line,
      en.messaging_chat_removed_action,
    ]) {
      for (final w in forbiddenEn) {
        expect(s.toLowerCase(), isNot(contains(w)), reason: '"$s" has "$w"');
      }
    }
    for (final s in [
      ar.messaging_chat_removed_line,
      ar.messaging_chat_removed_action,
    ]) {
      for (final w in forbiddenAr) {
        expect(s, isNot(contains(w)), reason: '"$s" has "$w"');
      }
    }
    for (final s in [
      en.messaging_chat_unavailable_line,
      ar.messaging_chat_unavailable_line,
    ]) {
      expect(s.toLowerCase(), isNot(contains('pilot')));
    }
    expect(
      en.messaging_chat_removed_line,
      isNot(ar.messaging_chat_removed_line),
    );
  });
}
