import 'package:dabbler/features/messaging/presentation/messages_list_route.dart';
import 'package:dabbler/features/messaging/presentation/providers/messages_list_providers.dart';
import 'package:dabbler/features/social/providers/feed_notifier.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'home_test_harness.dart';

/// KAN-549: the Home header's Messages action.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(initHomeTestSupabase);

  final desktop = TargetPlatformVariant.only(TargetPlatform.macOS);

  Finder icon(String name) =>
      find.byWidgetPredicate((w) => w is DabblerIcon && w.name == name);

  Future<List<String>> pump(
    WidgetTester tester, {
    required bool messaging,
    required bool gameChat,
    Locale locale = const Locale('en'),
  }) async {
    final h = await pumpHome(
      tester,
      feedState: const FeedLoading(),
      locale: locale,
      overrides: [
        messagesListFlagsProvider.overrideWithValue((
          messaging: messaging,
          gameChat: gameChat,
        )),
      ],
    );
    return h.pushed;
  }

  for (final combo in const [
    (messaging: false, gameChat: false),
    (messaging: true, gameChat: false),
    (messaging: false, gameChat: true),
  ]) {
    testWidgets('absent when messaging=${combo.messaging} '
        'gameChat=${combo.gameChat}', (tester) async {
      await pump(tester, messaging: combo.messaging, gameChat: combo.gameChat);
      expect(icon('search-normal'), findsOneWidget);
      expect(icon('notification-bing'), findsOneWidget);
      expect(icon('messages'), findsNothing);
      expect(tester.takeException(), isNull);
    }, variant: desktop);
  }

  testWidgets('committed flags: absent', (tester) async {
    await pumpHome(tester, feedState: const FeedLoading());
    expect(icon('messages'), findsNothing);
  }, variant: desktop);

  for (final locale in const [Locale('en'), Locale('ar')]) {
    testWidgets('both flags on: present between search and notifications '
        '(${locale.languageCode})', (tester) async {
      final handle = tester.ensureSemantics();
      final pushed = await pump(
        tester,
        messaging: true,
        gameChat: true,
        locale: locale,
      );
      expect(icon('messages'), findsOneWidget);
      final search = tester.getCenter(icon('search-normal')).dx;
      final messages = tester.getCenter(icon('messages')).dx;
      final notif = tester.getCenter(icon('notification-bing')).dx;
      final rtl = locale.languageCode == 'ar';
      // Neighbours on the same row, in reading order, mirrored in RTL.
      expect(
        rtl
            ? search > messages && messages > notif
            : search < messages && messages < notif,
        isTrue,
        reason: 'search $search, messages $messages, notifications $notif',
      );
      expect(
        tester.getSize(icon('messages')),
        tester.getSize(icon('search-normal')),
      );
      expect(
        find.bySemanticsLabel(rtl ? 'الرسائل' : 'Messages'),
        findsOneWidget,
      );
      await tester.tap(icon('messages'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(pushed, contains(messagesListRoutePath));
      handle.dispose();
      expect(tester.takeException(), isNull);
    }, variant: desktop);
  }
}
