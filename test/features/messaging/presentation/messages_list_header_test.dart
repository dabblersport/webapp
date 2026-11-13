import 'package:dabbler/features/messaging/data/fake_messaging_repository.dart';
import 'package:dabbler/features/messaging/domain/models/my_conversation.dart';
import 'package:dabbler/features/messaging/presentation/providers/messages_list_providers.dart';
import 'package:dabbler/features/messaging/presentation/providers/messaging_providers.dart';
import 'package:dabbler/features/messaging/presentation/screens/messages_list_screen.dart';
import 'package:dabbler/features/profile/presentation/screens/settings/header_collapse.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_backend.dart';

/// KAN-601: the Messages list header collapses like Settings and Profile,
/// tinted with `surfaceHeaderMessages` from the design system. Device and
/// keyboard behaviour is for Codex QA; this pins the logic and the token.
final _now = DateTime.utc(2026, 10, 15, 12);

List<MyConversation> _chats(int n) => [
  for (var i = 0; i < n; i++)
    MyConversation(
      conversationId: 'c$i',
      gameId: 'g$i',
      title: 'Game $i',
      sport: 'Tennis',
      startAt: DateTime.utc(2026, 10, 17, 19),
      endAt: DateTime.utc(2026, 10, 17, 21),
      state: MyConversationState.send,
      lastActivityAt: _now.subtract(Duration(minutes: i)),
    ),
];

Widget _app(
  FakeMessagingRepository repo, {
  Brightness brightness = Brightness.light,
  Locale locale = const Locale('en'),
}) => ProviderScope(
  overrides: [
    fakeMessagingBackend,
    fakeMessagingRepositoryProvider.overrideWithValue(repo),
    messagingClockProvider.overrideWithValue(() => _now),
    messagesListFlagsProvider.overrideWithValue((
      messaging: true,
      gameChat: true,
    )),
  ],
  child: MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: DabblerDesignSystemTheme.withTokens(
      brightness == Brightness.dark ? ThemeData.dark() : ThemeData.light(),
    ),
    home: const MessagesListScreen(),
  ),
);

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// The pinned bar's ground: the first animated container is the top bar's.
Color _barColor(WidgetTester tester) =>
    (tester
                .widget<AnimatedContainer>(find.byType(AnimatedContainer).first)
                .decoration
            as BoxDecoration)
        .color!;

DabblerColors _colors(WidgetTester tester) =>
    DabblerColors.of(tester.element(find.byType(MessagesListScreen)));

void main() {
  setUp(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.physicalSize = const Size(390 * 3, 844 * 3);
    view.devicePixelRatio = 3;
  });

  for (final b in Brightness.values) {
    for (final locale in const [Locale('en'), Locale('ar')]) {
      testWidgets('[${b.name} ${locale.languageCode}] bar and hero use the '
          'messages token at the top, the page ground once scrolled', (
        tester,
      ) async {
        final repo = FakeMessagingRepository()..seedMyConversations(_chats(20));
        await tester.pumpWidget(_app(repo, brightness: b, locale: locale));
        await _settle(tester);
        final colors = _colors(tester);

        expect(_barColor(tester), colors.surfaceHeaderMessages);
        final hero = tester.widget<DabblerSettingsHeader>(
          find.byType(DabblerSettingsHeader),
        );
        expect(hero.tint, colors.surfaceHeaderMessages);

        await tester.drag(find.byType(Scrollable).first, const Offset(0, -600));
        await _settle(tester);
        expect(_barColor(tester), colors.bgPrimary);

        await tester.drag(find.byType(Scrollable).first, const Offset(0, 900));
        await _settle(tester);
        expect(_barColor(tester), colors.surfaceHeaderMessages);
      });
    }
  }

  testWidgets('a scroll resting inside the hysteresis band does not flip', (
    tester,
  ) async {
    final repo = FakeMessagingRepository()..seedMyConversations(_chats(20));
    await tester.pumpWidget(_app(repo));
    await _settle(tester);
    final colors = _colors(tester);
    final scroll = tester.state<ScrollableState>(find.byType(Scrollable).first);
    final extent = tester.getSize(find.byType(DabblerSettingsHeader)).height;

    const h = HeaderCollapseController.hysteresis;

    // Inside the band above the edge: still expanded.
    scroll.position.jumpTo(extent + h - 1);
    await _settle(tester);
    expect(_barColor(tester), colors.surfaceHeaderMessages);

    // Past the band: collapsed.
    scroll.position.jumpTo(extent + h + 1);
    await _settle(tester);
    expect(_barColor(tester), colors.bgPrimary);

    // Back inside the band: stays collapsed, no flicker.
    scroll.position.jumpTo(extent + h - 1);
    await _settle(tester);
    expect(_barColor(tester), colors.bgPrimary);
    scroll.position.jumpTo(extent - h + 1);
    await _settle(tester);
    expect(_barColor(tester), colors.bgPrimary);

    // Past the band below the edge: expanded again.
    scroll.position.jumpTo(extent - h - 1);
    await _settle(tester);
    expect(_barColor(tester), colors.surfaceHeaderMessages);
  });

  testWidgets('an empty list still shows the hero and the rows list is gone', (
    tester,
  ) async {
    final repo = FakeMessagingRepository()..seedMyConversations(const []);
    await tester.pumpWidget(_app(repo));
    await _settle(tester);
    expect(find.byKey(MessagesListScreen.emptyKey), findsOneWidget);
    expect(find.byType(DabblerSettingsHeader), findsOneWidget);
    expect(_barColor(tester), _colors(tester).surfaceHeaderMessages);
  });
}
